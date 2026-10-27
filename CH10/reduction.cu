#include <cuda_runtime.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

// 沿用前章检查方式，分别检查提交错误与执行完成错误。
static void check_cuda(cudaError_t status, const char* api, const char* file, int line) {
    if (status != cudaSuccess) {
        std::fprintf(stderr, "%s:%d: %s failed: %s (%s)\n", file, line, api,
                     cudaGetErrorName(status), cudaGetErrorString(status));
        std::exit(EXIT_FAILURE);
    }
}
#define CUDA_CHECK(call) check_cuda((call), #call, __FILE__, __LINE__)

constexpr int kWarp = 32;
constexpr int kBlock = 256;
constexpr int kWarps = kBlock / kWarp;
constexpr int kBlocks = 1024;
constexpr int kN = kBlock * kBlocks;
constexpr int kWarmup = 10;
constexpr int kSamples = 21;
constexpr int kBatch = 10;
static_assert(kBlock % kWarp == 0 && (kBlock & (kBlock - 1)) == 0);
static_assert(kN % kBlock == 0 && kWarps <= kWarp);

// 输入为连续 float32；一个 block 负责连续 256 项，只写出一个片段和。
// 每轮前半部分线程合并两个已有和；所有线程参与轮间 barrier。
__global__ void block_sum_shared(const float* input, float* partial) {
    __shared__ float tile[kBlock];
    const int tid = threadIdx.x;
    tile[tid] = input[blockIdx.x * kBlock + tid];
    __syncthreads();
    for (int stride = kBlock / 2; stride > 0; stride /= 2) {
        if (tid < stride) {
            // 合并两份片段和；下一轮由更少的线程继续合并。
            tile[tid] += tile[tid + stride];
        }
        // 必须位于 if 外：下轮读到的应是本轮已经更新的片段和。
        __syncthreads();
    }
    if (tid == 0) partial[blockIdx.x] = tile[0];
}

// 输入是完整 warp 每个 lane 手里的一个值；只有返回后的 lane 0 持有全 warp 和。
// 调用约定：32 个 lane 全部执行相同的 shuffle，不能只让 lane 0 调用。
__device__ __forceinline__ float warp_sum(float value) {
    for (int offset = kWarp / 2; offset > 0; offset /= 2) {
        // 完整 32 lanes 同时取回伙伴的当前片段和，再累加到自身值。
        // offset 逐轮减半；最终仅 lane 0 的结果用于完整 warp 求和。
        value += __shfl_down_sync(0xffffffffu, value, offset);
    }
    return value;
}

// warp 内用 shuffle 合并；8 个 warp 的 lane 0 通过 shared 交给第一个 warp。
// 最后一轮虽只有 8 个有效和，仍由完整 32 lanes 参与，其余 lane 输入 0。
__global__ void block_sum_shuffle(const float* input, float* partial) {
    __shared__ float warp_partial[kWarps];
    const int tid = threadIdx.x;
    const int lane = tid % kWarp;
    const int warp = tid / kWarp;
    float value = warp_sum(input[blockIdx.x * kBlock + tid]);
    if (lane == 0) warp_partial[warp] = value;
    __syncthreads();  // 跨 warp 的 shared 交接仍需 block barrier。
    if (warp == 0) {
        value = lane < kWarps ? warp_partial[lane] : 0.0f;
        value = warp_sum(value);
        if (lane == 0) partial[blockIdx.x] = value;
    }
}

// CPU 用 double 顺序生成每片 reference；不复用 GPU 的树形归约逻辑。
static std::vector<double> make_reference(const std::vector<float>& input) {
    std::vector<double> reference(kBlocks, 0.0);
    for (int i = 0; i < kN; ++i) reference[i / kBlock] += input[i];
    return reference;
}

// 检查所有片段，另汇总总和；只看总和可能漏掉相互抵消的片段错误。
static bool validate(const std::vector<float>& partial, const std::vector<double>& reference,
                     const char* method, bool verbose) {
    int errors = 0;
    double max_error = 0.0, total = 0.0, expected_total = 0.0;
    for (int b = 0; b < kBlocks; ++b) {
        const double error = std::fabs(static_cast<double>(partial[b]) - reference[b]);
        if (!std::isfinite(partial[b]) || error != 0.0) ++errors;
        max_error = !std::isfinite(error) ? INFINITY : std::max(max_error, error);
        total += partial[b];
        expected_total += reference[b];
    }
    const bool correct = errors == 0 && std::isfinite(total) && total == expected_total;
    if (verbose || !correct) {
        std::printf("method=%s correctness=%s checked_partials=%d mismatches=%d "
                    "max_abs_error=%.9g total=%.0f expected_total=%.0f\n",
                    method, correct ? "PASS" : "FAIL", kBlocks, errors, max_error,
                    total, expected_total);
    }
    return correct;
}

static void launch(const float* input, float* partial, bool shuffle) {
    if (shuffle) block_sum_shuffle<<<kBlocks, kBlock>>>(input, partial);
    else block_sum_shared<<<kBlocks, kBlock>>>(input, partial);
    CUDA_CHECK(cudaGetLastError());
}

// 同 stream Event 测一批 launch，回读/校验在区间外；每次写出而不累加旧输出。
static bool benchmark(const float* input, float* partial, bool shuffle,
                      const std::vector<double>& reference, std::vector<float>& host_partial,
                      double& median_us) {
    const char* method = shuffle ? "shuffle" : "shared";
    for (int j = 0; j < kWarmup; ++j) launch(input, partial, shuffle);
    CUDA_CHECK(cudaDeviceSynchronize());
    cudaEvent_t start, stop;
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));
    std::vector<double> elapsed;
    bool correct = true;
    for (int s = 0; s < kSamples && correct; ++s) {
        CUDA_CHECK(cudaEventRecord(start, 0));
        for (int j = 0; j < kBatch; ++j) launch(input, partial, shuffle);
        CUDA_CHECK(cudaEventRecord(stop, 0));
        CUDA_CHECK(cudaEventSynchronize(stop));
        float ms = 0.0f;
        CUDA_CHECK(cudaEventElapsedTime(&ms, start, stop));
        CUDA_CHECK(cudaMemcpy(host_partial.data(), partial, kBlocks * sizeof(float),
                              cudaMemcpyDeviceToHost));
        correct = validate(host_partial, reference, method, false) && std::isfinite(ms) && ms > 0.0f;
        elapsed.push_back(ms * 1000.0 / kBatch);
    }
    if (correct) {
        std::sort(elapsed.begin(), elapsed.end());
        median_us = elapsed[elapsed.size() / 2];
        std::printf("method=%s warmup=%d samples=%d event_batch=%d "
                    "event_batch_per_launch_median_us=%.6f\n",
                    method, kWarmup, kSamples, kBatch, median_us);
    }
    CUDA_CHECK(cudaEventDestroy(stop));
    CUDA_CHECK(cudaEventDestroy(start));
    return correct;
}

// check 各启动一次目标 kernel；bench 只在两种方法均通过全量校验后计时。
// GPU 输出 1024 个 block 和，CPU 最后汇总；本章不实现跨 block 同步或 atomic。
int main(int argc, char** argv) {
    const char* mode = argc == 1 ? "check" : argv[1];
    if (argc > 2 || (std::strcmp(mode, "check") != 0 && std::strcmp(mode, "bench") != 0)) {
        std::fprintf(stderr, "Usage: %s [check|bench]\n", argv[0]);
        return EXIT_FAILURE;
    }
    const bool timing = std::strcmp(mode, "bench") == 0;
    cudaDeviceProp prop{};
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    if (prop.warpSize != kWarp || prop.maxThreadsPerBlock < kBlock) {
        std::fputs("This experiment requires warpSize=32 and block=256 support.\n", stderr);
        return EXIT_FAILURE;
    }
    cudaFuncAttributes shared_attr{}, shuffle_attr{};
    CUDA_CHECK(cudaFuncGetAttributes(&shared_attr, block_sum_shared));
    CUDA_CHECK(cudaFuncGetAttributes(&shuffle_attr, block_sum_shuffle));
    std::printf("GPU=%s CC=%d.%d warpSize=%d mode=%s\n",
                prop.name, prop.major, prop.minor, prop.warpSize, mode);
    std::printf("shape=[%d] dtype=float32 grid=%d block=%d partials=%d "
                "shared_bytes_shared=%zu shared_bytes_shuffle=%zu\n",
                kN, kBlocks, kBlock, kBlocks,
                shared_attr.sharedSizeBytes, shuffle_attr.sharedSizeBytes);
    std::puts("Compare shared-tree and warp-shuffle block sums against the CPU reference.");
    std::vector<float> input(kN), partial(kBlocks);
    // 混合正负小整数；所有片段和及中间整数均可由 float 精确表示。
    for (int i = 0; i < kN; ++i) {
        input[i] = static_cast<float>((i * 17 + (i / kBlock) * 13) % 101 - 50);
    }
    const auto reference = make_reference(input);
    constexpr size_t input_bytes = kN * sizeof(float);
    constexpr size_t partial_bytes = kBlocks * sizeof(float);
    float *d_input = nullptr, *d_partial = nullptr;
    CUDA_CHECK(cudaMalloc(&d_input, input_bytes));
    CUDA_CHECK(cudaMalloc(&d_partial, partial_bytes));
    CUDA_CHECK(cudaMemcpy(d_input, input.data(), input_bytes, cudaMemcpyHostToDevice));
    bool correct = true;
    for (bool shuffle : {false, true}) {
        CUDA_CHECK(cudaMemset(d_partial, 0xff, partial_bytes)); // NaN 哨兵发现遗漏写出。
        launch(d_input, d_partial, shuffle);
        CUDA_CHECK(cudaDeviceSynchronize());
        CUDA_CHECK(cudaMemcpy(partial.data(), d_partial, partial_bytes, cudaMemcpyDeviceToHost));
        correct = validate(partial, reference, shuffle ? "shuffle" : "shared", true) && correct;
        std::printf("first_partial=%.0f expected=%.0f\n", partial[0], reference[0]);
    }
    if (correct && timing) {
        double shared_us = 0.0, shuffle_us = 0.0;
        correct = benchmark(d_input, d_partial, false, reference, partial, shared_us);
        if (correct) correct = benchmark(d_input, d_partial, true, reference, partial, shuffle_us);
        if (correct) std::printf("Timing PASS: observed_shared_over_shuffle=%.3f\n", shared_us / shuffle_us);
        else std::puts("Timing FAIL: invalid Event sample or output mismatch.");
    } else std::puts(timing ? "Timing NOT RUN: correctness check failed." : "Timing NOT RUN: check mode.");
    CUDA_CHECK(cudaFree(d_partial));
    CUDA_CHECK(cudaFree(d_input));
    return correct ? EXIT_SUCCESS : EXIT_FAILURE;
}
