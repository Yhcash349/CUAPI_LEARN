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
constexpr int kN = 65539;  // 故意不是 block 的整数倍，继续保留尾部保护。
constexpr int kBlock = 256;
constexpr int kRepeats = 2048;
constexpr int kWarmup = 3;
constexpr int kSamples = 21;

// 复用 vector add 数据流；重复累加仅放大执行时间，便于看清 CPU/GPU 边界。
// 每线程只写自己的输出，无线程间依赖；本章不引入 shared 或多 stream。
__global__ void repeated_add(const float* a, const float* b, float* c, int n) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    float sum = a[i];
    for (int r = 0; r < kRepeats; ++r) sum += b[i];
    c[i] = sum;
}

static void launch(const float* a, const float* b, float* c) {
    repeated_add<<<(kN + kBlock - 1) / kBlock, kBlock>>>(a, b, c, kN);
    CUDA_CHECK(cudaGetLastError());  // 检查 launch 错误，不等待 GPU 执行完成。
}

// CPU 等到当前设备此前提交的工作完成，返回状态由调用方检查。
static cudaError_t wait_on_host() {
    return cudaDeviceSynchronize();
}

static double us(Clock::time_point begin, Clock::time_point end) {
    return std::chrono::duration<double, std::micro>(end - begin).count();
}

// 小范围 /16 输入使本例所有中间累加都能被 FP32 精确表示；非任意 FP32 的保证。
static void make_inputs(std::vector<float>& a, std::vector<float>& b,
                        std::vector<double>& reference) {
    for (int i = 0; i < kN; ++i) {
        a[i] = static_cast<float>((i * 7 + 3) % 29 - 14) / 16.0f;
        b[i] = static_cast<float>((i * 11 + 1) % 23 - 11) / 16.0f;
        reference[i] = static_cast<double>(a[i]) + kRepeats * static_cast<double>(b[i]);
    }
}

// 独立 CPU 公式全量校验，NaN 哨兵可暴露漏写，不只比较两个 GPU 输出。
static bool validate(const std::vector<float>& output, const std::vector<double>& reference,
                     bool verbose) {
    int mismatches = 0;
    double max_abs = 0.0;
    for (int i = 0; i < kN; ++i) {
        const double error = std::fabs(static_cast<double>(output[i]) - reference[i]);
        const bool finite = std::isfinite(error);
        if (!finite || error != 0.0) ++mismatches;
        max_abs = finite ? std::max(max_abs, error) : INFINITY;
    }
    if (verbose || mismatches != 0)
        std::printf("checked=%d correctness=%s mismatches=%d max_abs_error=%.9g\n",
                    kN, mismatches == 0 ? "PASS" : "FAIL", mismatches, max_abs);
    return mismatches == 0;
}

struct Times { double launch_us, complete_us, event_us; };

// 同一次 launch 的两个 CPU 终点；Event 仍在默认 stream 中包住同一个 kernel。
// 等待位于 t_complete 之前，因此 CPU 完成区间确实包含完成等待。
static bool measure(const float* a, const float* b, float* c,
                    cudaEvent_t start, cudaEvent_t stop, Times& result) {
    CUDA_CHECK(cudaDeviceSynchronize());  // 清空前序工作，不计入当前样本。
    CUDA_CHECK(cudaEventRecord(start, 0));
    const auto t0 = Clock::now();
    launch(a, b, c);
    const auto t_submit = Clock::now();
    CUDA_CHECK(cudaEventRecord(stop, 0));
    const cudaError_t wait_status = wait_on_host();
    const auto t_complete = Clock::now();

    CUDA_CHECK(wait_status);  // 执行阶段的错误可能在同步时才报告。
    // 额外采样等待返回附近的完成状态；它不能代替对等待 API 实现的检查。
    const cudaError_t completion = cudaEventQuery(stop);
    if (completion == cudaErrorNotReady) {
        CUDA_CHECK(cudaDeviceSynchronize());
        std::puts("Wait FAIL: stop event was not complete at the claimed completion boundary.");
        return false;
    }
    CUDA_CHECK(completion);
    float ms = 0.0f;
    CUDA_CHECK(cudaEventElapsedTime(&ms, start, stop));
    result = {us(t0, t_submit), us(t0, t_complete), ms * 1000.0};
    return std::isfinite(result.launch_us) && std::isfinite(result.complete_us) &&
           std::isfinite(result.event_us) && result.launch_us >= 0.0 &&
           result.complete_us >= result.launch_us && result.event_us > 0.0;
}

static double median(std::vector<double> values) {
    std::sort(values.begin(), values.end());
    return values[values.size() / 2];
}

// check 验证一次完成边界；bench 先校验、预热，再取 21 个独立样本；trace 只观测一次。
int main(int argc, char** argv) {
    const char* mode = argc == 1 ? "check" : argv[1];
    if (argc > 2 || (std::strcmp(mode, "check") != 0 && std::strcmp(mode, "bench") != 0 &&
                     std::strcmp(mode, "trace") != 0)) {
        std::fprintf(stderr, "Usage: %s [check|bench|trace]\n", argv[0]);
        return EXIT_FAILURE;
    }
    CUDA_CHECK(cudaSetDevice(0));
    cudaDeviceProp prop{};
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    std::printf("GPU=%s CC=%d.%d SMs=%d mode=%s N=%d dtype=float32 block=%d grid=%d repeats=%d\n",
                prop.name, prop.major, prop.minor, prop.multiProcessorCount, mode,
                kN, kBlock, (kN + kBlock - 1) / kBlock, kRepeats);
    const char* blocking = std::getenv("CUDA_LAUNCH_BLOCKING");
    std::printf("CUDA_LAUNCH_BLOCKING=%s\n", blocking ? blocking : "unset");
    if (blocking && std::strcmp(blocking, "0") != 0) {
        std::fputs("Use unset CUDA_LAUNCH_BLOCKING or value 0 for this asynchronous experiment.\n", stderr);
        return EXIT_FAILURE;
    }
    std::vector<float> a(kN), b(kN), output(kN);
    std::vector<double> reference(kN);
    make_inputs(a, b, reference);
    float *d_a = nullptr, *d_b = nullptr, *d_c = nullptr;
    const size_t bytes = kN * sizeof(float);
    CUDA_CHECK(cudaMalloc(&d_a, bytes));
    CUDA_CHECK(cudaMalloc(&d_b, bytes));
    CUDA_CHECK(cudaMalloc(&d_c, bytes));
    CUDA_CHECK(cudaMemcpy(d_a, a.data(), bytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_b, b.data(), bytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemset(d_c, 0xff, bytes));
    launch(d_a, d_b, d_c);
    CUDA_CHECK(cudaDeviceSynchronize());  // 已提供的数值预检，不是练习的计时边界。
    CUDA_CHECK(cudaMemcpy(output.data(), d_c, bytes, cudaMemcpyDeviceToHost));
    bool correct = validate(output, reference, true);
    bool complete = false;
    cudaEvent_t start, stop;
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));
    if (correct) {
        for (int i = 0; i < kWarmup; ++i) launch(d_a, d_b, d_c);
        CUDA_CHECK(cudaDeviceSynchronize());
        Times trial{};
        complete = measure(d_a, d_b, d_c, start, stop, trial);
        // 此次回读永远在 CPU 计时结束后；D2H 不能替代练习中的等待。
        CUDA_CHECK(cudaMemcpy(output.data(), d_c, bytes, cudaMemcpyDeviceToHost));
        correct = validate(output, reference, true);
        if (complete && correct && std::strcmp(mode, "trace") == 0)
            std::printf("Trace observation only: host_launch_us=%.6f host_complete_us=%.6f event_us=%.6f\n",
                        trial.launch_us, trial.complete_us, trial.event_us);
        if (complete && correct && std::strcmp(mode, "bench") == 0) {
            std::vector<double> host_launch, host_complete, gpu_event;
            for (int i = 0; i < kSamples && complete && correct; ++i) {
                Times sample{};
                complete = measure(d_a, d_b, d_c, start, stop, sample);
                CUDA_CHECK(cudaMemcpy(output.data(), d_c, bytes, cudaMemcpyDeviceToHost));
                correct = validate(output, reference, false);
                if (complete && correct) {
                    host_launch.push_back(sample.launch_us);
                    host_complete.push_back(sample.complete_us);
                    gpu_event.push_back(sample.event_us);
                }
            }
            if (complete && correct)
                std::printf("warmup=%d samples=%d batch=1 host_launch_median_us=%.6f "
                            "host_complete_median_us=%.6f event_median_us=%.6f Timing PASS\n",
                            kWarmup, kSamples, median(host_launch), median(host_complete), median(gpu_event));
        }
    }
    if (!correct || !complete) std::puts("Timing NOT RUN/REJECTED: correctness or completion boundary failed.");
    else if (std::strcmp(mode, "check") == 0) std::puts("Completion boundary PASS; timing NOT RUN: check mode.");
    CUDA_CHECK(cudaEventDestroy(stop));
    CUDA_CHECK(cudaEventDestroy(start));
    CUDA_CHECK(cudaFree(d_c));
    CUDA_CHECK(cudaFree(d_b));
    CUDA_CHECK(cudaFree(d_a));
    std::printf("Experiment %s\n", correct && complete ? "PASS" : "INCOMPLETE/FAIL");
    return correct && complete ? EXIT_SUCCESS : EXIT_FAILURE;
}
