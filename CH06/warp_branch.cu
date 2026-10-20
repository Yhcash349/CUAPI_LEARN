#include <cuda_runtime.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

// 复用 Ch03 的错误检查；GPU 执行错误仍在同步或回读处检查。
static void check_cuda(cudaError_t status, const char* api, const char* file, int line) {
    if (status != cudaSuccess) {
        std::fprintf(stderr, "%s:%d: %s failed: %s (%s)\n", file, line, api,
                     cudaGetErrorName(status), cudaGetErrorString(status));
        std::exit(EXIT_FAILURE);
    }
}
#define CUDA_CHECK(call) check_cuda((call), #call, __FILE__, __LINE__)

constexpr int kBlock = 256;  // 完整 warp；两种模式中 A/B 线程总数相同。
constexpr int kN = 65536;
constexpr int kIterations = 256;
constexpr int kWarmup = 10;
constexpr int kSamples = 21;
constexpr int kBatch = 5;

// 只启动一个 block 的 64 个线程，输出边界附近的 8 项。
// 数组记录全部结果，由 CPU 校验；printf 顺序不代表线程执行顺序。
__global__ void probe_warps(int* lanes, int* warps) {
    const int t = threadIdx.x;
    // 一维 block 中，每 warpSize 个相邻线程组成一个 warp：取余得组内位置，整除得组号。
    const int lane = t % warpSize;
    const int warp_in_block = t / warpSize;
    lanes[t] = lane;
    warps[t] = warp_in_block;
    if (t == 0 || t == 15 || t == 16 || t == 31 ||
        t == 32 || t == 47 || t == 48 || t == 63) {
        printf("thread=%d warp_in_block=%d lane=%d\n", t, warp_in_block, lane);
    }
}

// 唯一实验变量：mode=0 在 warp 内分两路；mode=1 按 warp 分路。
// true 选 A，false 选 B。索引是 block 内编号，不是全局元素编号。
__device__ __forceinline__ bool choose_path_a(int mode, int thread_in_block) {
    const int lane = thread_in_block % warpSize;
    const int warp_in_block = thread_in_block / warpSize;
    // 本章已核验 warpSize=32；mode=0 将同一 warp 的前后半组分到 A/B。
    if (mode == 0) return lane < 16;
    // mode=1 按完整 warp 分路：偶数组全走 A，奇数组全走 B。
    return warp_in_block % 2 == 0;
}

// 教学方提供两条有数据依赖的计算路径，防止简单 if 被合并成同一条计算。
// __noinline__ 是编译提示；是否保留两路，以当前编译产物预检为准。
// uint32_t 按模 2^32 运算，CPU/GPU 可以逐位精确比较。
__device__ __noinline__ std::uint32_t path_a(std::uint32_t x, int iterations) {
    for (int j = 0; j < iterations; ++j) {
        x = x * 1664525u + 1013904223u;
        x ^= x >> 13;
    }
    return x;
}

__device__ __noinline__ std::uint32_t path_b(std::uint32_t x, int iterations) {
    for (int j = 0; j < iterations; ++j) {
        x = x * 22695477u + 1u;
        x ^= x >> 11;
    }
    return x;
}

// 输入和输出地址始终连续；每个线程只读取并写回一个独立元素。
// 计时 kernel 没有 printf、线程间交换或同步教学内容。
__global__ void branch_work(const std::uint32_t* input, std::uint32_t* output,
                            int n, int iterations, int mode) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    std::uint32_t x = input[i];
    if (choose_path_a(mode, threadIdx.x)) {
        x = path_a(x, iterations);
    } else {
        x = path_b(x, iterations);
    }
    output[i] = x;
}

// CPU reference 独立按全局下标计算期望路由，不调用练习中的 helper。
static std::vector<std::uint32_t> make_reference(
    const std::vector<std::uint32_t>& input, int mode) {
    std::vector<std::uint32_t> reference(input.size());
    for (size_t i = 0; i < input.size(); ++i) {
        const bool take_a = mode == 0 ? i % 32 < 16 : (i / 32) % 2 == 0;
        std::uint32_t x = input[i];
        for (int j = 0; j < kIterations; ++j) {
            if (take_a) {
                x = x * 1664525u + 1013904223u;
                x ^= x >> 13;
            } else {
                x = x * 22695477u + 1u;
                x ^= x >> 11;
            }
        }
        reference[i] = x;
    }
    return reference;
}

static int mismatches(const std::vector<std::uint32_t>& output,
                      const std::vector<std::uint32_t>& reference) {
    int count = 0;
    for (size_t i = 0; i < output.size(); ++i) count += output[i] != reference[i];
    return count;
}

static double median(std::vector<double> values) {
    std::sort(values.begin(), values.end());
    return values[values.size() / 2];
}

static bool run_probe() {
    constexpr int threads = 64;
    int *d_lanes = nullptr, *d_warps = nullptr;
    CUDA_CHECK(cudaMalloc(&d_lanes, threads * sizeof(int)));
    CUDA_CHECK(cudaMalloc(&d_warps, threads * sizeof(int)));
    probe_warps<<<1, threads>>>(d_lanes, d_warps);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());
    std::vector<int> lanes(threads), warps(threads);
    CUDA_CHECK(cudaMemcpy(lanes.data(), d_lanes, threads * sizeof(int), cudaMemcpyDeviceToHost));
    CUDA_CHECK(cudaMemcpy(warps.data(), d_warps, threads * sizeof(int), cudaMemcpyDeviceToHost));
    int errors = 0;
    for (int t = 0; t < threads; ++t) {
        errors += lanes[t] != t % 32 || warps[t] != t / 32;
    }
    CUDA_CHECK(cudaFree(d_warps));
    CUDA_CHECK(cudaFree(d_lanes));
    std::printf("Probe %s: checked=64 mismatches=%d\n", errors == 0 ? "PASS" : "FAIL", errors);
    return errors == 0;
}

// check 只校验；bench 在两路全量校验通过后才进行预热和 Event 计时。
static bool run_branch(bool timing) {
    constexpr size_t bytes = kN * sizeof(std::uint32_t);
    constexpr int grid = kN / kBlock;
    const char* names[] = {"within_warp", "between_warps"};
    std::vector<std::uint32_t> input(kN), output(kN);
    for (int i = 0; i < kN; ++i) input[i] = static_cast<std::uint32_t>(i) * 17u + 3u;
    const std::vector<std::uint32_t> reference[] = {
        make_reference(input, 0), make_reference(input, 1)};
    std::uint32_t *d_input = nullptr, *d_output = nullptr;
    CUDA_CHECK(cudaMalloc(&d_input, bytes));
    CUDA_CHECK(cudaMalloc(&d_output, bytes));
    CUDA_CHECK(cudaMemcpy(d_input, input.data(), bytes, cudaMemcpyHostToDevice));
    auto launch = [&](int mode) {
        branch_work<<<grid, kBlock>>>(d_input, d_output, kN, kIterations, mode);
        CUDA_CHECK(cudaGetLastError());
    };
    auto validate = [&](int mode) {
        CUDA_CHECK(cudaMemcpy(output.data(), d_output, bytes, cudaMemcpyDeviceToHost));
        return mismatches(output, reference[mode]);
    };
    bool correct = true;
    std::printf("N=%d dtype=uint32 grid=%d block=%d iterations=%d A_threads=%d B_threads=%d\n",
                kN, grid, kBlock, kIterations, kN / 2, kN / 2);
    std::puts("A_threads/B_threads describe the expected completed exercise.");
    for (int mode = 0; mode < 2; ++mode) {
        // 填充不计时；避免未写输出偶然沿用上一模式的正确结果。
        CUDA_CHECK(cudaMemset(d_output, 0, bytes));
        launch(mode);
        CUDA_CHECK(cudaDeviceSynchronize());
        const int errors = validate(mode);
        std::printf("%s correctness=%s mismatches=%d\n", names[mode], errors == 0 ? "PASS" : "FAIL", errors);
        correct &= errors == 0;
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
            // 成对采样并轮换顺序，减少固定先后顺序的影响。
            for (int turn = 0; turn < 2; ++turn) {
                const int mode = (s + turn) % 2;
                CUDA_CHECK(cudaEventRecord(start, 0));
                for (int j = 0; j < kBatch; ++j) launch(mode);
                CUDA_CHECK(cudaEventRecord(stop, 0));
                CUDA_CHECK(cudaEventSynchronize(stop));
                float ms = 0.0f;
                CUDA_CHECK(cudaEventElapsedTime(&ms, start, stop));
                correct &= std::isfinite(ms) && ms > 0.0f && validate(mode) == 0;
                elapsed[mode].push_back(ms * 1000.0 / kBatch);
            }
        }
        if (correct) {
            std::printf("warmup_per_mode=%d samples_per_mode=%d event_batch=%d\n", kWarmup, kSamples, kBatch);
            for (int mode = 0; mode < 2; ++mode) {
                std::printf("%s event_batch_per_launch_median_us=%.6f\n", names[mode], median(elapsed[mode]));
            }
            std::puts("Timing PASS: compare observations; no fixed slowdown is required.");
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

// CPU 入口：三个模式分开打印观察、正确性和正常计时。
int main(int argc, char** argv) {
    const char* mode = argc == 1 ? "probe" : argv[1];
    if (argc > 2 || (std::strcmp(mode, "probe") != 0 &&
                    std::strcmp(mode, "check") != 0 && std::strcmp(mode, "bench") != 0)) {
        std::fprintf(stderr, "Usage: %s [probe|check|bench]\n", argv[0]);
        return EXIT_FAILURE;
    }
    cudaDeviceProp prop{};
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    std::printf("GPU=%s CC=%d.%d warpSize=%d mode=%s\n", prop.name, prop.major, prop.minor, prop.warpSize, mode);
    if (prop.warpSize != 32) {
        std::fputs("This chapter requires warpSize=32.\n", stderr);
        return EXIT_FAILURE;
    }
    const bool pass = std::strcmp(mode, "probe") == 0 ? run_probe() : run_branch(std::strcmp(mode, "bench") == 0);
    return pass ? EXIT_SUCCESS : EXIT_FAILURE;
}
