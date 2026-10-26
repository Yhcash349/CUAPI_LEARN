#include <cuda_runtime.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

// 沿用前章的 host API 检查；提交检查与执行完成检查分开。
static void check_cuda(cudaError_t status, const char* api, const char* file, int line) {
    if (status != cudaSuccess) {
        std::fprintf(stderr, "%s:%d: %s failed: %s (%s)\n", file, line, api,
                     cudaGetErrorName(status), cudaGetErrorString(status));
        std::exit(EXIT_FAILURE);
    }
}
#define CUDA_CHECK(call) check_cuda((call), #call, __FILE__, __LINE__)

constexpr int kSide = 32;
constexpr int kRows = 8;
constexpr int kTileElements = kSide * kSide;
constexpr int kTiles = 1024;
constexpr int kN = kTiles * kTileElements;
constexpr int kSharedElements = kSide * (kSide + 1);
constexpr int kWarmup = 10;
constexpr int kSamples = 21;
constexpr int kBatch = 5;

// 把逻辑行列转换为 shared 中的 float 下标，stride 的单位是 float。
// 按行跨度寻找行首，再加列偏移；stride=33 时，每行末尾留一个 padding 槽位。
__device__ __forceinline__ int shared_index(int row, int col, int stride) {
    return row * stride + col;
}

// 输入/输出均为 [1024,32,32] 的连续 float32 小片；每片单独转置。
// 两种布局 global 地址、工作量、block、barrier 和 shared 预留大小完全相同。
template <int Stride>
__global__ void shared_transpose(const float* input, float* output) {
    // volatile 保留本微基准的 shared 标量访问，不提供同步语义；交接仍依赖 barrier。
    __shared__ volatile float tile[kSharedElements];
    const int x = threadIdx.x;
    const int y = threadIdx.y;
    const int base = blockIdx.x * kTileElements;

    // block=(32,8)，每个 warp 固定 y，x=0..31：按行连续装载，每线程写 4 项。
    #pragma unroll
    for (int j = 0; j < kSide; j += kRows) {
        const int row = y + j;
        tile[shared_index(row, x, Stride)] = input[base + row * kSide + x];
    }
    __syncthreads();
    // 同一 warp 固定 col=y+j，沿 shared 的一列读取；global 输出仍连续。
    #pragma unroll
    for (int j = 0; j < kSide; j += kRows) {
        const int col = y + j;
        output[base + col * kSide + x] = tile[shared_index(x, col, Stride)];
    }
}

// CPU 独立从源矩阵行列生成转置，不调用 shared_index，不读取 padding。
static std::vector<float> make_reference(const std::vector<float>& input) {
    std::vector<float> reference(kN);
    for (int b = 0; b < kTiles; ++b) {
        for (int r = 0; r < kSide; ++r) {
            for (int c = 0; c < kSide; ++c) {
                reference[b * kTileElements + c * kSide + r] =
                    input[b * kTileElements + r * kSide + c];
            }
        }
    }
    return reference;
}

// 搬运与转置不引入舍入，要求每项精确相等；拒绝 NaN/Inf。
static bool validate(const std::vector<float>& output, const std::vector<float>& reference,
                     int stride, bool verbose) {
    int errors = 0;
    double max_error = 0.0;
    for (int i = 0; i < kN; ++i) {
        const double error = std::fabs(static_cast<double>(output[i]) - reference[i]);
        if (!std::isfinite(output[i]) || error != 0.0) ++errors;
        max_error = !std::isfinite(error) ? INFINITY : std::max(max_error, error);
    }
    if (verbose || errors != 0) {
        std::printf("stride_arg=%d correctness=%s checked=%d mismatches=%d max_abs_error=%.9g\n",
                    stride, errors == 0 ? "PASS" : "FAIL", kN, errors, max_error);
    }
    return errors == 0;
}

static void launch(const float* input, float* output, int stride) {
    if (stride == 32) shared_transpose<32><<<kTiles, dim3(kSide, kRows)>>>(input, output);
    else shared_transpose<33><<<kTiles, dim3(kSide, kRows)>>>(input, output);
    CUDA_CHECK(cudaGetLastError());
}

// 每个样本测一批同 stream launch，归一化为每次启动时间；校验和回读在区间外。
static bool benchmark(const float* input, float* output, int stride,
                      const std::vector<float>& reference, std::vector<float>& host_output,
                      double& median_us) {
    for (int j = 0; j < kWarmup; ++j) launch(input, output, stride);
    CUDA_CHECK(cudaDeviceSynchronize());
    cudaEvent_t start, stop;
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));
    std::vector<double> elapsed;
    bool correct = true;
    for (int s = 0; s < kSamples && correct; ++s) {
        CUDA_CHECK(cudaEventRecord(start, 0));
        for (int j = 0; j < kBatch; ++j) launch(input, output, stride);
        CUDA_CHECK(cudaEventRecord(stop, 0));
        CUDA_CHECK(cudaEventSynchronize(stop));
        float ms = 0.0f;
        CUDA_CHECK(cudaEventElapsedTime(&ms, start, stop));
        CUDA_CHECK(cudaMemcpy(host_output.data(), output, kN * sizeof(float), cudaMemcpyDeviceToHost));
        correct = validate(host_output, reference, stride, false) && std::isfinite(ms) && ms > 0.0f;
        elapsed.push_back(ms * 1000.0 / kBatch);
    }
    if (correct) {
        std::sort(elapsed.begin(), elapsed.end());
        median_us = elapsed[elapsed.size() / 2];
        std::printf("stride_arg=%d warmup=%d samples=%d event_batch=%d "
                    "event_batch_per_launch_median_us=%.6f\n",
                    stride, kWarmup, kSamples, kBatch, median_us);
    }
    CUDA_CHECK(cudaEventDestroy(stop));
    CUDA_CHECK(cudaEventDestroy(start));
    return correct;
}

// check 正好启动两次目标 kernel，便于 NCU --launch-count 2；bench 才预热和重复计时。
int main(int argc, char** argv) {
    const char* mode = argc == 1 ? "check" : argv[1];
    if (argc > 2 || (std::strcmp(mode, "check") != 0 && std::strcmp(mode, "bench") != 0)) {
        std::fprintf(stderr, "Usage: %s [check|bench]\n", argv[0]);
        return EXIT_FAILURE;
    }
    const bool timing = std::strcmp(mode, "bench") == 0;
    cudaDeviceProp prop{};
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    cudaFuncAttributes attr32{}, attr33{};
    CUDA_CHECK(cudaFuncGetAttributes(&attr32, shared_transpose<32>));
    CUDA_CHECK(cudaFuncGetAttributes(&attr33, shared_transpose<33>));
    std::printf("GPU=%s CC=%d.%d warpSize=%d mode=%s\n",
                prop.name, prop.major, prop.minor, prop.warpSize, mode);
    std::printf("shape=[%d,%d,%d] dtype=float32 N=%d grid=%d block=(%d,%d) "
                "shared_bytes_stride32=%zu shared_bytes_stride33=%zu\n",
                kTiles, kSide, kSide, kN, kTiles, kSide, kRows,
                attr32.sharedSizeBytes, attr33.sharedSizeBytes);
    std::puts("Layouts use shared strides 32/33; use NCU counters to verify bank conflicts.");

    std::vector<float> input(kN), output(kN);
    for (int i = 0; i < kN; ++i) input[i] = static_cast<float>(i) * 0.25f;
    const auto reference = make_reference(input);
    constexpr size_t bytes = kN * sizeof(float);
    float *d_input = nullptr, *d_output = nullptr;
    CUDA_CHECK(cudaMalloc(&d_input, bytes));
    CUDA_CHECK(cudaMalloc(&d_output, bytes));
    CUDA_CHECK(cudaMemcpy(d_input, input.data(), bytes, cudaMemcpyHostToDevice));
    bool correct = true;
    // 先完整校验两种布局，任何一种失败都不计时；每轮用哨兵避免旧输出掩盖遗漏写出。
    for (int stride : {32, 33}) {
        CUDA_CHECK(cudaMemset(d_output, 0xff, bytes));
        launch(d_input, d_output, stride);
        CUDA_CHECK(cudaDeviceSynchronize());
        CUDA_CHECK(cudaMemcpy(output.data(), d_output, bytes, cudaMemcpyDeviceToHost));
        correct = validate(output, reference, stride, true) && correct;
        std::printf("examples: output[1]=%.2f expected=%.2f output[32]=%.2f expected=%.2f\n",
                    output[1], reference[1], output[32], reference[32]);
    }
    if (correct && timing) {
        double us32 = 0.0, us33 = 0.0;
        correct = benchmark(d_input, d_output, 32, reference, output, us32);
        if (correct) correct = benchmark(d_input, d_output, 33, reference, output, us33);
        if (correct) {
            std::printf("Timing PASS: observed_stride32_over_stride33=%.3f; "
                        "use NCU counters to verify bank conflicts.\n", us32 / us33);
        } else std::puts("Timing FAIL: invalid Event sample or output mismatch.");
    } else std::puts(timing ? "Timing NOT RUN: correctness check failed." : "Timing NOT RUN: check mode.");
    CUDA_CHECK(cudaFree(d_output));
    CUDA_CHECK(cudaFree(d_input));
    return correct ? EXIT_SUCCESS : EXIT_FAILURE;
}
