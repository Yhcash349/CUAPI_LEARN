#include <cuda_runtime.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

static void check_cuda(cudaError_t status, const char* api, const char* file, int line) {
    if (status != cudaSuccess) {
        std::fprintf(stderr, "%s:%d: %s failed: %s (%s)\n", file, line, api,
                     cudaGetErrorName(status), cudaGetErrorString(status));
        std::exit(EXIT_FAILURE);
    }
}
#define CUDA_CHECK(call) check_cuda((call), #call, __FILE__, __LINE__)

constexpr int kTile = 16;
constexpr int kWarmup = 10;
constexpr int kSamples = 21;
constexpr int kBatch = 5;
constexpr double kAtol = 1e-4;
constexpr double kRtol = 1e-4;

struct Shape { int m, n, k; };
constexpr Shape kMain{256, 256, 256};
constexpr Shape kTail{37, 53, 29};
enum class Method { Naive, Tiled };
static const char* name(Method method) { return method == Method::Naive ? "naive" : "tiled"; }

// A[M,K]、B[K,N]、C[M,N] 均按行连续；一个线程独立算一个 C[row,col]。
__global__ void gemm_naive(const float* a, const float* b, float* c, int m, int n, int k) {
    const int row = blockIdx.y * kTile + threadIdx.y;
    const int col = blockIdx.x * kTile + threadIdx.x;
    if (row >= m || col >= n) return;
    float sum = 0.0f;
    for (int p = 0; p < k; ++p) sum += a[row * k + p] * b[p * n + col];
    c[row * n + col] = sum;
}

// 同样一个线程算一个输出；block 沿 K 每次合作装入两个 16x16 tile。
// 所有线程均参与两次 barrier，越界线程仍负责装载/填零，最后才按边界写出。
__global__ void gemm_tiled(const float* a, const float* b, float* c, int m, int n, int k) {
    __shared__ float a_tile[kTile][kTile];
    __shared__ float b_tile[kTile][kTile];
    const int ty = threadIdx.y;
    const int tx = threadIdx.x;
    const int row = blockIdx.y * kTile + ty;
    const int col = blockIdx.x * kTile + tx;
    float sum = 0.0f;
    for (int base = 0; base < k; base += kTile) {
        // 每线程装入一个 A 元素和一个 B 元素，供本 block 的多个输出复用。
        // A 的 global 坐标为 (row, base+tx)，B 为 (base+ty, col)。
        // 分别检查各自两维边界；越界写 0，不能提前 return 或跳过 barrier。
        a_tile[ty][tx] = (row < m && base + tx < k) ? a[row * k + base + tx] : 0.0f;
        b_tile[ty][tx] = (base + ty < k && col < n) ? b[(base + ty) * n + col] : 0.0f;
        __syncthreads();  // 当前 tile 的所有写入完成，才允许其他线程读取。
        for (int p = 0; p < kTile; ++p) {
            // 每线程从 shared 读取 A 的一行与 B 的一列，累加当前 tile 的贡献。
            sum += a_tile[ty][p] * b_tile[p][tx];
        }
        __syncthreads();  // 所有人读完本轮，才能覆盖同一对 shared buffer。
    }
    if (row < m && col < n) c[row * n + col] = sum;
}

// 查询/计时/校验均走同一启动入口，固定 block、grid 与默认 stream。
static void launch(Method method, const float* a, const float* b, float* c, Shape s) {
    const dim3 block(kTile, kTile);
    const dim3 grid((s.n + kTile - 1) / kTile, (s.m + kTile - 1) / kTile);
    if (method == Method::Naive) gemm_naive<<<grid, block>>>(a, b, c, s.m, s.n, s.k);
    else gemm_tiled<<<grid, block>>>(a, b, c, s.m, s.n, s.k);
    CUDA_CHECK(cudaGetLastError());
}

// 非对称且含正负值的确定输入，避免全 1 掩盖索引错误；不依赖外部库。
static void make_inputs(std::vector<float>& a, std::vector<float>& b, Shape s) {
    for (int row = 0; row < s.m; ++row)
        for (int col = 0; col < s.k; ++col)
            a[row * s.k + col] = static_cast<float>((row * 13 + col * 7 + 3) % 23 - 11) / 16.0f;
    for (int row = 0; row < s.k; ++row)
        for (int col = 0; col < s.n; ++col)
            b[row * s.n + col] = static_cast<float>((row * 5 + col * 11 + 1) % 19 - 9) / 16.0f;
}

// CPU double reference 按数学定义逐输出计算，不复用 GPU tiling。
static std::vector<double> make_reference(const std::vector<float>& a,
                                          const std::vector<float>& b, Shape s) {
    std::vector<double> reference(s.m * s.n, 0.0);
    for (int row = 0; row < s.m; ++row)
        for (int col = 0; col < s.n; ++col)
            for (int p = 0; p < s.k; ++p)
                reference[row * s.n + col] += static_cast<double>(a[row * s.k + p]) * b[p * s.n + col];
    return reference;
}

// 全量比较，明确拒绝 NaN/Inf；abs/rel 混合容差适用于接近零的输出。
static bool validate(const std::vector<float>& output, const std::vector<double>& reference,
                     Shape s, Method method, bool verbose) {
    int mismatches = 0;
    double max_abs = 0.0, max_rel = 0.0;
    for (size_t i = 0; i < output.size(); ++i) {
        const double error = std::fabs(static_cast<double>(output[i]) - reference[i]);
        const bool finite = std::isfinite(output[i]) && std::isfinite(error);
        if (!finite || error > kAtol + kRtol * std::fabs(reference[i])) ++mismatches;
        max_abs = !finite ? INFINITY : std::max(max_abs, error);
        max_rel = !finite ? INFINITY : std::max(max_rel, error / std::max(std::fabs(reference[i]), 1e-12));
    }
    if (verbose || mismatches != 0) {
        std::printf("method=%s M=%d N=%d K=%d checked=%zu correctness=%s mismatches=%d "
                    "max_abs_error=%.9g max_rel_error=%.9g atol=%g rtol=%g\n",
                    name(method), s.m, s.n, s.k, output.size(), mismatches == 0 ? "PASS" : "FAIL",
                    mismatches, max_abs, max_rel, kAtol, kRtol);
    }
    return mismatches == 0;
}

// 沿用 Ch11 的同 stream Event 骨架；每批 5 次，区间外回读校验，取 21 批中位数。
static bool benchmark(Method method, const float* a, const float* b, float* c, Shape s,
                      std::vector<float>& output, const std::vector<double>& reference,
                      double& median_us) {
    for (int i = 0; i < kWarmup; ++i) launch(method, a, b, c, s);
    CUDA_CHECK(cudaDeviceSynchronize());
    cudaEvent_t start, stop;
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));
    std::vector<double> elapsed;
    bool correct = true;
    for (int sample = 0; sample < kSamples && correct; ++sample) {
        CUDA_CHECK(cudaEventRecord(start, 0));
        for (int i = 0; i < kBatch; ++i) launch(method, a, b, c, s);
        CUDA_CHECK(cudaEventRecord(stop, 0));
        CUDA_CHECK(cudaEventSynchronize(stop));
        float ms = 0.0f;
        CUDA_CHECK(cudaEventElapsedTime(&ms, start, stop));
        CUDA_CHECK(cudaMemcpy(output.data(), c, output.size() * sizeof(float), cudaMemcpyDeviceToHost));
        correct = validate(output, reference, s, method, false) && std::isfinite(ms) && ms > 0.0f;
        elapsed.push_back(ms * 1000.0 / kBatch);
    }
    if (correct) {
        std::sort(elapsed.begin(), elapsed.end());
        median_us = elapsed[elapsed.size() / 2];
        std::printf("method=%s M=%d N=%d K=%d warmup=%d samples=%d event_batch=%d "
                    "event_batch_per_launch_median_us=%.6f\n", name(method), s.m, s.n, s.k,
                    kWarmup, kSamples, kBatch, median_us);
    }
    CUDA_CHECK(cudaEventDestroy(stop));
    CUDA_CHECK(cudaEventDestroy(start));
    return correct;
}

// 一组 shape 的输入/显存/reference 独立准备；两种算法先全量校验，全部正确才允许计时。
static bool run_case(Shape s, bool timing) {
    std::printf("shape: A=[%d,%d] B=[%d,%d] C=[%d,%d] dtype=float32 "
                "block=[%d,%d] grid=[%d,%d]\n", s.m, s.k, s.k, s.n, s.m, s.n,
                kTile, kTile, (s.n + kTile - 1) / kTile, (s.m + kTile - 1) / kTile);
    std::vector<float> a(s.m * s.k), b(s.k * s.n), output(s.m * s.n);
    make_inputs(a, b, s);
    const auto reference = make_reference(a, b, s);
    float *d_a = nullptr, *d_b = nullptr, *d_c = nullptr;
    CUDA_CHECK(cudaMalloc(&d_a, a.size() * sizeof(float)));
    CUDA_CHECK(cudaMalloc(&d_b, b.size() * sizeof(float)));
    CUDA_CHECK(cudaMalloc(&d_c, output.size() * sizeof(float)));
    CUDA_CHECK(cudaMemcpy(d_a, a.data(), a.size() * sizeof(float), cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_b, b.data(), b.size() * sizeof(float), cudaMemcpyHostToDevice));
    bool correct = true;
    for (Method method : {Method::Naive, Method::Tiled}) {
        // NaN 哨兵防止漏写；同一输入与同一 reference，避免只让两种错误结果互相比较。
        CUDA_CHECK(cudaMemset(d_c, 0xff, output.size() * sizeof(float)));
        launch(method, d_a, d_b, d_c, s);
        CUDA_CHECK(cudaDeviceSynchronize());
        CUDA_CHECK(cudaMemcpy(output.data(), d_c, output.size() * sizeof(float), cudaMemcpyDeviceToHost));
        correct = validate(output, reference, s, method, true) && correct;
    }
    if (timing && correct) {
        double naive_us = 0.0, tiled_us = 0.0;
        correct = benchmark(Method::Naive, d_a, d_b, d_c, s, output, reference, naive_us);
        if (correct) correct = benchmark(Method::Tiled, d_a, d_b, d_c, s, output, reference, tiled_us);
        if (correct) std::printf("naive_over_tiled_event_ratio=%.6f Timing PASS\n", naive_us / tiled_us);
    } else std::puts(timing ? "Timing NOT RUN: incorrect output."
                           : "Timing NOT RUN: check mode.");
    CUDA_CHECK(cudaFree(d_c));
    CUDA_CHECK(cudaFree(d_b));
    CUDA_CHECK(cudaFree(d_a));
    return correct;
}

// check 顺序为主 shape naive/tiled、尾部 shape naive/tiled，便于 NCU 只采前两次。
// bench 先校验两种 shape；通过后仅为主 shape 计时，不将尾部处理设为性能变量。
int main(int argc, char** argv) {
    const char* mode = argc == 1 ? "check" : argv[1];
    if (argc > 2 || (std::strcmp(mode, "check") != 0 && std::strcmp(mode, "bench") != 0)) {
        std::fprintf(stderr, "Usage: %s [check|bench]\n", argv[0]);
        return EXIT_FAILURE;
    }
    CUDA_CHECK(cudaSetDevice(0));
    cudaDeviceProp prop{};
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    if (prop.maxThreadsPerBlock < kTile * kTile || prop.maxThreadsDim[0] < kTile ||
        prop.maxThreadsDim[1] < kTile || prop.sharedMemPerBlock < 2 * kTile * kTile * sizeof(float)) {
        std::fputs("Unsupported device limits for a 16x16 tile.\n", stderr);
        return EXIT_FAILURE;
    }
    cudaFuncAttributes attr{};
    CUDA_CHECK(cudaFuncGetAttributes(&attr, gemm_tiled));
    std::printf("GPU=%s CC=%d.%d SMs=%d warpSize=%d mode=%s tiled_static_shared_bytes=%zu "
                "tiled_registers_per_thread=%d\n", prop.name, prop.major, prop.minor,
                prop.multiProcessorCount, prop.warpSize, mode, attr.sharedSizeBytes, attr.numRegs);
    bool correct = run_case(kMain, false);
    correct = run_case(kTail, false) && correct;
    if (std::strcmp(mode, "bench") == 0) {
        if (correct) correct = run_case(kMain, true);
        else std::puts("Timing NOT RUN: correctness failed.");
    }
    std::printf("Experiment %s\n", correct ? "PASS" : "INCOMPLETE/FAIL");
    return correct ? EXIT_SUCCESS : EXIT_FAILURE;
}
