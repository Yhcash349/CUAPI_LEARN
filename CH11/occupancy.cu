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

constexpr int kWarp = 32;
constexpr int kBlock = 256;
constexpr int kWarps = kBlock / kWarp;
constexpr int kBlocks = 1024;
constexpr int kN = kBlock * kBlocks;
constexpr int kWarmup = 10;
constexpr int kSamples = 21;
constexpr int kBatch = 10;
constexpr size_t kReservations[] = {0, 16 * 1024, 32 * 1024};
static_assert(kBlock % kWarp == 0 && kWarps <= kWarp);

// 直接复用 Ch10 的完整 warp 求和；本章不改变 kernel 的计算或数据访问。
__device__ __forceinline__ float warp_sum(float value) {
    for (int offset = kWarp / 2; offset > 0; offset /= 2) {
        value += __shfl_down_sync(0xffffffffu, value, offset);
    }
    return value;
}

// 每 block 读取连续 256 个 float，输出一个片段和；静态 shared 仅 32 字节。
// 额外 dynamic shared 只在启动时预留，故意不读写，不需要 extern __shared__ 数组。
__global__ void block_sum_shuffle(const float* input, float* partial) {
    __shared__ float warp_partial[kWarps];
    const int tid = threadIdx.x;
    const int lane = tid % kWarp;
    const int warp = tid / kWarp;
    float value = warp_sum(input[blockIdx.x * kBlock + tid]);
    if (lane == 0) warp_partial[warp] = value;
    __syncthreads();
    if (warp == 0) {
        value = lane < kWarps ? warp_partial[lane] : 0.0f;
        value = warp_sum(value);
        if (lane == 0) partial[blockIdx.x] = value;
    }
}

// 输入目标动态预留字节数；输出此 kernel 在固定 block 下每 SM 的理论驻留 block 数。
// 这是 host 查询，不启动 kernel；静态 shared 由 API 自动计入。
static int active_blocks_per_sm(size_t dynamic_bytes) {
    int blocks = 0;
    CUDA_CHECK(cudaOccupancyMaxActiveBlocksPerMultiprocessor(
        &blocks, block_sum_shuffle, kBlock, dynamic_bytes));
    return blocks;
}

// 按请求量预留每 block 的动态 shared，并返回实际传入 launch 的字节数供 host 核对。
static size_t launch(const float* input, float* partial, size_t requested_bytes) {
    // 第三个启动参数只计动态部分，kernel 自带的静态 shared 另外占用资源。
    const size_t launch_bytes = requested_bytes;
    block_sum_shuffle<<<kBlocks, kBlock, launch_bytes>>>(input, partial);
    CUDA_CHECK(cudaGetLastError());
    return launch_bytes;
}

// CPU 顺序生成每片 double reference，不复用 GPU 的树形算法。
static std::vector<double> make_reference(const std::vector<float>& input) {
    std::vector<double> reference(kBlocks, 0.0);
    for (int i = 0; i < kN; ++i) reference[i / kBlock] += input[i];
    return reference;
}

// 所有片段逐一校验，再核对总和；输入为小整数，本例允许精确比较。
static bool validate(const std::vector<float>& partial, const std::vector<double>& reference,
                     size_t requested_bytes, bool verbose) {
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
        std::printf("requested_dynamic_bytes=%zu correctness=%s checked_partials=%d "
                    "mismatches=%d max_abs_error=%.9g total=%.0f expected_total=%.0f\n",
                    requested_bytes, correct ? "PASS" : "FAIL", kBlocks, errors, max_error,
                    total, expected_total);
    }
    return correct;
}

// 沿用前章同 stream Event：每批 10 次启动，区间外回读校验，报告 21 批的中位数。
static bool benchmark(const float* input, float* partial, size_t dynamic_bytes,
                      const std::vector<double>& reference, std::vector<float>& host_partial) {
    for (int j = 0; j < kWarmup; ++j) launch(input, partial, dynamic_bytes);
    CUDA_CHECK(cudaDeviceSynchronize());
    cudaEvent_t start, stop;
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));
    std::vector<double> elapsed;
    bool correct = true;
    for (int s = 0; s < kSamples && correct; ++s) {
        CUDA_CHECK(cudaEventRecord(start, 0));
        for (int j = 0; j < kBatch; ++j) launch(input, partial, dynamic_bytes);
        CUDA_CHECK(cudaEventRecord(stop, 0));
        CUDA_CHECK(cudaEventSynchronize(stop));
        float ms = 0.0f;
        CUDA_CHECK(cudaEventElapsedTime(&ms, start, stop));
        CUDA_CHECK(cudaMemcpy(host_partial.data(), partial, kBlocks * sizeof(float),
                              cudaMemcpyDeviceToHost));
        correct = validate(host_partial, reference, dynamic_bytes, false) &&
                  std::isfinite(ms) && ms > 0.0f;
        elapsed.push_back(ms * 1000.0 / kBatch);
    }
    if (correct) {
        std::sort(elapsed.begin(), elapsed.end());
        std::printf("dynamic_bytes=%zu warmup=%d samples=%d event_batch=%d "
                    "event_batch_per_launch_median_us=%.6f\n",
                    dynamic_bytes, kWarmup, kSamples, kBatch, elapsed[elapsed.size() / 2]);
    }
    CUDA_CHECK(cudaEventDestroy(stop));
    CUDA_CHECK(cudaEventDestroy(start));
    return correct;
}

// check 按 0/16/32 KiB 顺序各启动一次；bench 仅在配置和数值均通过后计时。
int main(int argc, char** argv) {
    const char* mode = argc == 1 ? "check" : argv[1];
    if (argc > 2 || (std::strcmp(mode, "check") != 0 && std::strcmp(mode, "bench") != 0)) {
        std::fprintf(stderr, "Usage: %s [check|bench]\n", argv[0]);
        return EXIT_FAILURE;
    }
    const bool timing = std::strcmp(mode, "bench") == 0;
    CUDA_CHECK(cudaSetDevice(0));
    cudaDeviceProp prop{};
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    cudaFuncAttributes attr{};
    CUDA_CHECK(cudaFuncGetAttributes(&attr, block_sum_shuffle));
    if (prop.warpSize != kWarp || prop.maxThreadsPerBlock < kBlock ||
        prop.maxThreadsPerMultiProcessor < kBlock ||
        kReservations[2] + attr.sharedSizeBytes > prop.sharedMemPerBlock ||
        kReservations[2] > static_cast<size_t>(attr.maxDynamicSharedSizeBytes)) {
        std::fputs("Unsupported device/resource limits for this fixed experiment.\n", stderr);
        return EXIT_FAILURE;
    }
    std::printf("GPU=%s CC=%d.%d SMs=%d warpSize=%d mode=%s\n", prop.name,
                prop.major, prop.minor, prop.multiProcessorCount, prop.warpSize, mode);
    std::printf("max_threads_per_sm=%d max_warps_per_sm=%d max_blocks_per_sm=%d "
                "shared_bytes_per_sm=%zu shared_bytes_per_block=%zu registers_per_sm=%d\n",
                prop.maxThreadsPerMultiProcessor, prop.maxThreadsPerMultiProcessor / kWarp,
                prop.maxBlocksPerMultiProcessor, prop.sharedMemPerMultiprocessor,
                prop.sharedMemPerBlock, prop.regsPerMultiprocessor);
    std::printf("shape=[%d] dtype=float32 grid=%d block=%d warps_per_block=%d "
                "static_shared_bytes=%zu registers_per_thread=%d\n",
                kN, kBlocks, kBlock, kWarps, attr.sharedSizeBytes, attr.numRegs);
    std::puts("Compare occupancy queries and actual launches with the same dynamic shared byte counts.");
    std::vector<float> input(kN), partial(kBlocks);
    for (int i = 0; i < kN; ++i) {
        input[i] = static_cast<float>((i * 17 + (i / kBlock) * 13) % 101 - 50);
    }
    const auto reference = make_reference(input);
    float *d_input = nullptr, *d_partial = nullptr;
    CUDA_CHECK(cudaMalloc(&d_input, kN * sizeof(float)));
    CUDA_CHECK(cudaMalloc(&d_partial, kBlocks * sizeof(float)));
    CUDA_CHECK(cudaMemcpy(d_input, input.data(), kN * sizeof(float), cudaMemcpyHostToDevice));
    bool correct = true;
    bool configured = true;
    for (size_t requested : kReservations) {
        const int blocks = active_blocks_per_sm(requested);
        CUDA_CHECK(cudaMemset(d_partial, 0xff, kBlocks * sizeof(float)));
        const size_t launched = launch(d_input, d_partial, requested);
        const bool ready = blocks > 0 && launched == requested;
        configured = ready && configured;
        std::printf("requested_dynamic_bytes=%zu launched_dynamic_bytes=%zu "
                    "resource_configuration=%s\n", requested, launched, ready ? "PASS" : "INCOMPLETE");
        if (blocks > 0) {
            const double occupancy = 100.0 * blocks * kWarps /
                                     (prop.maxThreadsPerMultiProcessor / kWarp);
            std::printf("api_blocks_per_sm=%d theoretical_active_warps_per_sm=%d "
                        "theoretical_occupancy_pct=%.2f\n", blocks, blocks * kWarps, occupancy);
        } else std::puts("Occupancy unavailable for this configuration.");
        CUDA_CHECK(cudaDeviceSynchronize());
        CUDA_CHECK(cudaMemcpy(partial.data(), d_partial, kBlocks * sizeof(float), cudaMemcpyDeviceToHost));
        correct = validate(partial, reference, requested, true) && correct;
    }
    if (timing && correct && configured) {
        for (size_t requested : kReservations) {
            correct = benchmark(d_input, d_partial, requested, reference, partial) && correct;
            if (!correct) break;
        }
        std::puts(correct ? "Timing PASS" : "Timing FAIL");
    } else std::puts(timing ? "Timing NOT RUN: incomplete resource configuration or incorrect output."
                           : "Timing NOT RUN: check mode.");
    std::printf("Experiment %s\n", correct && configured ? "PASS" : "INCOMPLETE/FAIL");
    CUDA_CHECK(cudaFree(d_partial));
    CUDA_CHECK(cudaFree(d_input));
    return correct && configured ? EXIT_SUCCESS : EXIT_FAILURE;
}
