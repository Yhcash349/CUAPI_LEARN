#include <cuda_runtime.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

// 沿用 Ch03 的 host 端检查；执行错误在同步和回读时继续检查。
static void check_cuda(cudaError_t status, const char* api, const char* file, int line) {
    if (status != cudaSuccess) {
        std::fprintf(stderr, "%s:%d: %s failed: %s (%s)\n", file, line, api,
                     cudaGetErrorName(status), cudaGetErrorString(status));
        std::exit(EXIT_FAILURE);
    }
}
#define CUDA_CHECK(call) check_cuda((call), #call, __FILE__, __LINE__)

constexpr int kSide = 32;
constexpr int kTileElements = kSide * kSide;
constexpr int kN = 1 << 22;  // 4194304 个 float；每个 GPU 数组 16 MiB。
constexpr int kBlock = 256;
constexpr int kWarmup = 10;
constexpr int kSamples = 21;
constexpr int kBatch = 5;
static_assert(kN % kTileElements == 0 && kN % kBlock == 0 && kBlock % 32 == 0);

// 本章唯一练习：改变读取下标。mode=0 连续读，mode=1 在每个 32x32 小片内按列读。
// 输入 i 是全局输出下标；返回对应输入下标。两种模式都必须恰好读取每项一次。
__device__ __forceinline__ int input_index(int i, int mode) {
    if (mode == 0) return i;
    const int base = (i / kTileElements) * kTileElements;
    const int row = (i - base) / kSide;
    const int col = (i - base) % kSide;
    // 在当前小片内交换行列；相邻线程沿一列读取，同时保留小片起点以避免重复访问。
    return base + col * kSide + row;
}

// 每线程一次 float 读取、一次加法、一次连续写出；只改变读地址安排。
// mode 对本次 launch 的所有线程相同，不制造 Ch06 的 warp 内路径分歧。
__global__ void access_pattern(const float* input, float* output, int n, int mode) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    const int j = input_index(i, mode);
    output[i] = input[j] + 1.0f;
}

// CPU 独立按 32x32 行列遍历生成期望值，不调用 GPU 练习中的索引函数。
// 这里的小片只是全局数组的索引分组，没有分配 shared memory。
static std::vector<float> make_reference(const std::vector<float>& input, int mode) {
    std::vector<float> reference(kN);
    for (int base = 0; base < kN; base += kTileElements) {
        for (int row = 0; row < kSide; ++row) {
            for (int col = 0; col < kSide; ++col) {
                const int dst = base + row * kSide + col;
                const int src = mode == 0 ? dst : base + col * kSide + row;
                reference[dst] = input[src] + 1.0f;
            }
        }
    }
    return reference;
}

// 检查全部输出，拒绝 NaN/Inf；本章输入与加法均可被 float 精确表示。
static bool validate(const std::vector<float>& output, const std::vector<float>& reference,
                     const char* name, bool verbose) {
    int errors = 0;
    double max_error = 0.0;
    for (int i = 0; i < kN; ++i) {
        const double error = std::fabs(static_cast<double>(output[i]) - reference[i]);
        if (!std::isfinite(output[i]) || error != 0.0) ++errors;
        max_error = !std::isfinite(error) ? INFINITY : std::max(max_error, error);
    }
    if (verbose || errors != 0) {
        std::printf("%s correctness=%s checked=%d mismatches=%d max_abs_error=%.9g\n",
                    name, errors == 0 ? "PASS" : "FAIL", kN, errors, max_error);
    }
    return errors == 0;
}

static double median(std::vector<double> values) {
    std::sort(values.begin(), values.end());
    return values[values.size() / 2];
}

// check 各模式只启动一次，便于 NCU 一一对应；bench 先全量校验，再预热和成对采样。
static bool run(bool timing) {
    constexpr size_t bytes = kN * sizeof(float);
    constexpr int grid = kN / kBlock;
    const char* names[] = {"contiguous", "strided"};
    std::vector<float> input(kN), output(kN);
    for (int i = 0; i < kN; ++i) input[i] = static_cast<float>(i) * 0.25f;
    const std::vector<float> reference[] = {make_reference(input, 0), make_reference(input, 1)};
    float *d_input = nullptr, *d_output = nullptr;
    CUDA_CHECK(cudaMalloc(&d_input, bytes));
    CUDA_CHECK(cudaMalloc(&d_output, bytes));
    CUDA_CHECK(cudaMemcpy(d_input, input.data(), bytes, cudaMemcpyHostToDevice));
    auto launch = [&](int mode) {
        access_pattern<<<grid, kBlock>>>(d_input, d_output, kN, mode);
        CUDA_CHECK(cudaGetLastError());
    };
    auto read_and_check = [&](int mode, bool verbose) {
        CUDA_CHECK(cudaMemcpy(output.data(), d_output, bytes, cudaMemcpyDeviceToHost));
        return validate(output, reference[mode], names[mode], verbose);
    };

    std::printf("N=%d dtype=float32 grid=%d block=%d tile=%dx%d bytes_per_array=%zu\n",
                kN, grid, kBlock, kSide, kSide, bytes);
    bool correct = true;
    for (int mode = 0; mode < 2; ++mode) {
        CUDA_CHECK(cudaMemset(d_output, 0, bytes));
        launch(mode);
        CUDA_CHECK(cudaDeviceSynchronize());
        // 分别执行两种模式的校验，不因前一种失败而短路跳过后一种。
        const bool pass = read_and_check(mode, true);
        correct &= pass;
    }
    if (correct && timing) {
        for (int j = 0; j < kWarmup; ++j) {
            launch(0);
            launch(1);
        }
        CUDA_CHECK(cudaDeviceSynchronize());
        cudaEvent_t start, stop;
        CUDA_CHECK(cudaEventCreate(&start));
        CUDA_CHECK(cudaEventCreate(&stop));
        std::vector<double> elapsed[2];
        for (int s = 0; s < kSamples && correct; ++s) {
            for (int turn = 0; turn < 2; ++turn) {
                const int mode = (s + turn) % 2;
                CUDA_CHECK(cudaEventRecord(start, 0));
                for (int j = 0; j < kBatch; ++j) launch(mode);
                CUDA_CHECK(cudaEventRecord(stop, 0));
                CUDA_CHECK(cudaEventSynchronize(stop));
                float ms = 0.0f;
                CUDA_CHECK(cudaEventElapsedTime(&ms, start, stop));
                const bool pass = read_and_check(mode, false);  // 回读和校验在 Event 区间外。
                correct &= pass && std::isfinite(ms) && ms > 0.0f;
                elapsed[mode].push_back(ms * 1000.0 / kBatch);
            }
        }
        if (correct) {
            std::printf("warmup_per_mode=%d samples_per_mode=%d event_batch=%d\n", kWarmup, kSamples, kBatch);
            for (int mode = 0; mode < 2; ++mode) {
                std::printf("%s event_batch_per_launch_median_us=%.6f\n", names[mode], median(elapsed[mode]));
            }
            std::puts("Timing PASS: no fixed speedup or slowdown is required.");
        } else {
            std::puts("Timing FAIL: invalid Event sample or output mismatch.");
        }
        CUDA_CHECK(cudaEventDestroy(stop));
        CUDA_CHECK(cudaEventDestroy(start));
    } else {
        std::puts(correct ? "Timing NOT RUN: check mode." : "Timing NOT RUN: correctness check failed.");
    }
    CUDA_CHECK(cudaFree(d_output));
    CUDA_CHECK(cudaFree(d_input));
    return correct;
}

// host 入口：默认只检查正确性，普通计时和 NCU 采集由不同命令启动。
int main(int argc, char** argv) {
    const char* mode = argc == 1 ? "check" : argv[1];
    if (argc > 2 || (std::strcmp(mode, "check") != 0 && std::strcmp(mode, "bench") != 0)) {
        std::fprintf(stderr, "Usage: %s [check|bench]\n", argv[0]);
        return EXIT_FAILURE;
    }
    cudaDeviceProp prop{};
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    std::printf("GPU=%s CC=%d.%d warpSize=%d L2_bytes=%d mode=%s\n",
                prop.name, prop.major, prop.minor, prop.warpSize, prop.l2CacheSize, mode);
    if (prop.warpSize != 32) {
        std::fputs("This chapter requires warpSize=32.\n", stderr);
        return EXIT_FAILURE;
    }
    return run(std::strcmp(mode, "bench") == 0) ? EXIT_SUCCESS : EXIT_FAILURE;
}
