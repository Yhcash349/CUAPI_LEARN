#include <cuda_runtime.h>

#include <algorithm>
#include <chrono>
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

using Clock = std::chrono::steady_clock;
constexpr int kN = 4099;  // 每个任务各有 4099 项；最后一个 block 只有 3 项有效。
constexpr int kBlock = 256;
constexpr int kRepeats = 8192;
constexpr int kWarmup = 3;
constexpr int kSamples = 21;

// 与 Ch13 相同的逐元素累加；每个任务读写自己的数组片段，彼此没有数据依赖。
// 固定较小 grid，便于观察两个任务；不在本章调整工作量或 block 大小。
__global__ void repeated_add(const float* a, const float* b, float* c, int n) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    float sum = a[i];
    for (int r = 0; r < kRepeats; ++r) sum += b[i];
    c[i] = sum;
}

// 输入是 handle 的地址，成功后应写入一个显式创建的 stream。
static cudaError_t create_work_stream(cudaStream_t* stream) {
    // 创建不与 legacy 默认 stream 隐式同步的队列，由调用方检查状态并负责销毁。
    return cudaStreamCreateWithFlags(stream, cudaStreamNonBlocking);
}

// 返回实际使用的队列，供骨架拒绝“传了 stream 却仍启动到默认队列”的配置。
static cudaStream_t launch(const float* a, const float* b, float* c, cudaStream_t stream) {
    // 第四个启动参数决定本次 kernel 的队列；创建 stream 本身不会改变启动目标。
    const cudaStream_t target = stream;
    repeated_add<<<(kN + kBlock - 1) / kBlock, kBlock, 0, target>>>(a, b, c, kN);
    CUDA_CHECK(cudaGetLastError());
    return target;
}

// 两个任务的输入不同；小范围 /16 数保证本实验的全部中间和可被 FP32 精确表示。
static void make_inputs(std::vector<float>& a, std::vector<float>& b,
                        std::vector<double>& reference) {
    for (int task = 0; task < 2; ++task) {
        for (int i = 0; i < kN; ++i) {
            const int j = task * kN + i;
            a[j] = static_cast<float>((i * 7 + task * 5 + 3) % 29 - 14) / 16.0f;
            b[j] = static_cast<float>((i * 11 + task * 3 + 1) % 23 - 11) / 16.0f;
            reference[j] = static_cast<double>(a[j]) + kRepeats * static_cast<double>(b[j]);
        }
    }
}

// 全量检查两个任务，NaN 哨兵暴露漏写；不只比较两种调度的输出。
static bool validate(const std::vector<float>& output, const std::vector<double>& reference,
                     const char* layout, bool verbose) {
    int mismatches = 0;
    double max_abs = 0.0;
    for (int j = 0; j < 2 * kN; ++j) {
        const double error = std::fabs(static_cast<double>(output[j]) - reference[j]);
        const bool finite = std::isfinite(error);
        if (!finite || error != 0.0) ++mismatches;
        max_abs = finite ? std::max(max_abs, error) : INFINITY;
    }
    if (verbose || mismatches != 0)
        std::printf("layout=%s checked=%d correctness=%s mismatches=%d max_abs_error=%.9g\n",
                    layout, 2 * kN, mismatches == 0 ? "PASS" : "FAIL", mismatches, max_abs);
    return mismatches == 0;
}

// 只改变第二个 kernel 的 stream；在两个 launch 之间不插 host 等待。
// 等待实际提交到的两个队列，再安全回读；等待包含在 host 计时内。
static bool run_pair(const float* a, const float* b, float* c,
                     cudaStream_t s0, cudaStream_t s1, bool split, double& host_us) {
    CUDA_CHECK(cudaDeviceSynchronize());  // 计时外清空前序工作。
    CUDA_CHECK(cudaMemset(c, 0xff, 2 * kN * sizeof(float)));
    CUDA_CHECK(cudaDeviceSynchronize());  // 哨兵写入也在计时外完成。
    const cudaStream_t requested_b = split ? s1 : s0;
    const auto t0 = Clock::now();
    const cudaStream_t used_a = launch(a, b, c, s0);
    const cudaStream_t used_b = launch(a + kN, b + kN, c + kN, requested_b);
    CUDA_CHECK(cudaStreamSynchronize(used_a));
    if (used_b != used_a) CUDA_CHECK(cudaStreamSynchronize(used_b));
    const auto t1 = Clock::now();
    host_us = std::chrono::duration<double, std::micro>(t1 - t0).count();
    return s0 != nullptr && s1 != nullptr && s0 != s1 &&
           used_a == s0 && used_b == requested_b;
}

static double median(std::vector<double> values) {
    std::sort(values.begin(), values.end());
    return values[values.size() / 2];
}

// check 默认检查两种调度；trace 可只采一种，最后两个 kernel 为目标样本。
int main(int argc, char** argv) {
    const char* mode = argc > 1 ? argv[1] : "check";
    const char* selection = argc > 2 ? argv[2] : "both";
    if (argc > 3 || (std::strcmp(mode, "check") != 0 && std::strcmp(mode, "bench") != 0 &&
                     std::strcmp(mode, "trace") != 0) ||
        (std::strcmp(selection, "same") != 0 && std::strcmp(selection, "split") != 0 &&
         std::strcmp(selection, "both") != 0)) {
        std::fprintf(stderr, "Usage: %s [check|bench|trace] [same|split|both]\n", argv[0]);
        return EXIT_FAILURE;
    }
    CUDA_CHECK(cudaSetDevice(0));
    cudaDeviceProp prop{};
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    std::printf("GPU=%s CC=%d.%d SMs=%d memory_MiB=%zu concurrentKernels=%d\n",
                prop.name, prop.major, prop.minor, prop.multiProcessorCount,
                prop.totalGlobalMem / (1024 * 1024), prop.concurrentKernels);
    std::printf("mode=%s selection=%s tasks=2 N_per_task=%d dtype=float32 block=%d grid=%d repeats=%d\n",
                mode, selection, kN, kBlock, (kN + kBlock - 1) / kBlock, kRepeats);
    const char* blocking = std::getenv("CUDA_LAUNCH_BLOCKING");
    std::printf("CUDA_LAUNCH_BLOCKING=%s\n", blocking ? blocking : "unset");
    if (blocking && std::strcmp(blocking, "0") != 0) {
        std::fputs("Use unset CUDA_LAUNCH_BLOCKING or value 0 for this experiment.\n", stderr);
        return EXIT_FAILURE;
    }

    std::vector<float> a(2 * kN), b(2 * kN), output(2 * kN);
    std::vector<double> reference(2 * kN);
    make_inputs(a, b, reference);
    const size_t bytes = 2 * kN * sizeof(float);
    float *d_a = nullptr, *d_b = nullptr, *d_c = nullptr;
    CUDA_CHECK(cudaMalloc(&d_a, bytes));
    CUDA_CHECK(cudaMalloc(&d_b, bytes));
    CUDA_CHECK(cudaMalloc(&d_c, bytes));
    CUDA_CHECK(cudaMemcpy(d_a, a.data(), bytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_b, b.data(), bytes, cudaMemcpyHostToDevice));
    cudaStream_t s0 = nullptr, s1 = nullptr;
    CUDA_CHECK(create_work_stream(&s0));
    CUDA_CHECK(create_work_stream(&s1));
    bool streams_ready = s0 != nullptr && s1 != nullptr && s0 != s1;
    if (streams_ready) {
        unsigned int flags0 = 0, flags1 = 0;
        CUDA_CHECK(cudaStreamGetFlags(s0, &flags0));
        CUDA_CHECK(cudaStreamGetFlags(s1, &flags1));
        streams_ready = flags0 == cudaStreamNonBlocking && flags1 == cudaStreamNonBlocking;
    }
    std::printf("Explicit nonblocking streams %s\n", streams_ready ? "PASS" : "INCOMPLETE");

    bool all_ok = true;
    for (int variant = 0; variant < 2; ++variant) {
        const bool split = variant == 1;
        const char* layout = split ? "split" : "same";
        if (std::strcmp(selection, "both") != 0 && std::strcmp(selection, layout) != 0) continue;
        double trial_us = 0.0;
        const bool routed = run_pair(d_a, d_b, d_c, s0, s1, split, trial_us);
        CUDA_CHECK(cudaMemcpy(output.data(), d_c, bytes, cudaMemcpyDeviceToHost));
        bool correct = validate(output, reference, layout, true);
        bool ready = streams_ready && routed && correct;
        std::printf("layout=%s stream_routing=%s\n", layout, ready ? "PASS" : "INCOMPLETE/FAIL");
        if (ready && std::strcmp(mode, "check") != 0) {
            for (int i = 0; i < kWarmup; ++i) {
                const bool route_ok = run_pair(d_a, d_b, d_c, s0, s1, split, trial_us);
                CUDA_CHECK(cudaMemcpy(output.data(), d_c, bytes, cudaMemcpyDeviceToHost));
                correct = validate(output, reference, layout, false);
                ready = ready && route_ok && correct;
            }
            const bool bench = std::strcmp(mode, "bench") == 0;
            const int samples = bench ? kSamples : 1;
            std::vector<double> times;
            for (int i = 0; i < samples && ready; ++i) {
                double host_us = 0.0;
                const bool route_ok = run_pair(d_a, d_b, d_c, s0, s1, split, host_us);
                CUDA_CHECK(cudaMemcpy(output.data(), d_c, bytes, cudaMemcpyDeviceToHost));
                correct = validate(output, reference, layout, false);
                ready = route_ok && correct && std::isfinite(host_us) && host_us > 0.0;
                if (ready) times.push_back(host_us);
            }
            if (ready)
                std::printf("layout=%s warmup=%d samples=%d batch=1 host_pair_%s_us=%.6f %s\n",
                            layout, kWarmup, samples, bench ? "median" : "trace",
                            median(times), bench ? "Timing PASS" : "Trace observation only");
        }
        if (!ready) std::puts("Timing NOT RUN/REJECTED: finish stream creation/routing and pass correctness.");
        all_ok = all_ok && ready;
    }
    if (s1 != nullptr && s1 != s0) CUDA_CHECK(cudaStreamDestroy(s1));
    if (s0 != nullptr) CUDA_CHECK(cudaStreamDestroy(s0));
    CUDA_CHECK(cudaFree(d_c));
    CUDA_CHECK(cudaFree(d_b));
    CUDA_CHECK(cudaFree(d_a));
    std::printf("Experiment %s\n", all_ok ? "PASS" : "INCOMPLETE/FAIL");
    return all_ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
