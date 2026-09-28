#include <cuda_runtime.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <limits>
#include <vector>

// 沿用 Ch03：检查返回值，不用检查函数本身代替 GPU 同步。
static void check_cuda(cudaError_t status, const char* api, const char* file, int line) {
    if (status != cudaSuccess) {
        std::fprintf(stderr, "%s:%d: %s failed: %s (%s)\n", file, line, api,
                     cudaGetErrorName(status), cudaGetErrorString(status));
        std::exit(EXIT_FAILURE);
    }
}
#define CUDA_CHECK(call) check_cuda((call), #call, __FILE__, __LINE__)
using Clock = std::chrono::steady_clock;

// 复用 Ch02 的索引和尾部保护；本章只改变计时，不改变计算。
__global__ void vector_add(const float* a, const float* b, float* c, int n) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) c[i] = a[i] + b[i];
}

// CPU 对照入口；禁止内联，配合每次计时后的全量读取，避免重复计算被消除。
__attribute__((noinline)) static void cpu_add(const float* a, const float* b, float* c, int n) {
    for (int i = 0; i < n; ++i) c[i] = a[i] + b[i];
}

// 校验在计时区间外；NaN/Inf 也判失败。返回本轮最大绝对误差。
static float validate(const std::vector<float>& result, const std::vector<float>& reference) {
    float max_error = 0.0f;
    for (size_t i = 0; i < result.size(); ++i) {
        const float error = std::fabs(result[i] - reference[i]);
        if (!std::isfinite(result[i]) || error > 1e-6f) {
            std::fprintf(stderr, "FAIL i=%zu got=%g expected=%g\n", i, result[i], reference[i]);
            std::exit(EXIT_FAILURE);
        }
        max_error = std::max(max_error, error);
    }
    return max_error;
}

static double median(std::vector<double> values) {
    std::sort(values.begin(), values.end());
    return values[values.size() / 2];  // 本例固定 21 个样本。
}

// CPU 入口：先验证，再预热，最后分别测 CPU、含传输总时间和 Event 区间。
int main() {
    constexpr int n = 1000;
    constexpr int block = 128;
    constexpr int grid = (n + block - 1) / block;
    constexpr size_t bytes = n * sizeof(float);
    constexpr int samples = 21;
    constexpr int batch = 100;
    // 先完整预热 10 次；预热结果校验，但耗时不计入正式样本。
    int warmup = 10;
    std::vector<float> a(n), b(n), c(n), cpu(n), reference(n);
    for (int i = 0; i < n; ++i) {
        a[i] = 0.5f * i;
        b[i] = 1.0f + 0.25f * (i % 7);
        reference[i] = a[i] + b[i];
    }
    float *d_a = nullptr, *d_b = nullptr, *d_c = nullptr;
    CUDA_CHECK(cudaMalloc(&d_a, bytes));
    CUDA_CHECK(cudaMalloc(&d_b, bytes));
    CUDA_CHECK(cudaMalloc(&d_c, bytes));
    cudaEvent_t start, stop;
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));

    // 一次完整路径：普通 CPU 内存 H2D → kernel → D2H → 等待完成。
    // 本章全部使用默认 stream 0，不创建其他 stream。
    auto full_path = [&]() {
        CUDA_CHECK(cudaMemcpy(d_a, a.data(), bytes, cudaMemcpyHostToDevice));
        CUDA_CHECK(cudaMemcpy(d_b, b.data(), bytes, cudaMemcpyHostToDevice));
        vector_add<<<grid, block>>>(d_a, d_b, d_c, n);
        CUDA_CHECK(cudaGetLastError());
        CUDA_CHECK(cudaMemcpy(c.data(), d_c, bytes, cudaMemcpyDeviceToHost));
        CUDA_CHECK(cudaDeviceSynchronize());
    };
    auto cleanup = [&]() {
        CUDA_CHECK(cudaEventDestroy(stop));
        CUDA_CHECK(cudaEventDestroy(start));
        CUDA_CHECK(cudaFree(d_c));
        CUDA_CHECK(cudaFree(d_b));
        CUDA_CHECK(cudaFree(d_a));
    };

    CUDA_CHECK(cudaMemset(d_c, 0, bytes));
    full_path();
    const float initial_error = validate(c, reference);
    cpu_add(a.data(), b.data(), cpu.data(), n);
    validate(cpu, reference);
    cudaDeviceProp prop{};
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    std::printf("GPU=%s N=%d dtype=float32 grid=%d block=%d tolerance=1e-6\n",
                prop.name, n, grid, block);
    std::printf("Correctness PASS: all %d elements, max_abs_error=%g\n", n, initial_error);
    if (warmup < 3) {
        std::puts("Timing NOT RUN: warmup must be >= 3.");
        cleanup();
        return EXIT_FAILURE;  // 正确性通过，但配置不足以执行本章计时。
    }
    for (int i = 0; i < warmup; ++i) {
        full_path();
        validate(c, reference);
        cpu_add(a.data(), b.data(), cpu.data(), n);
        validate(cpu, reference);
    }

    std::vector<double> cpu_us, total_us, event_us;
    bool event_complete = true;
    float max_error = 0.0f;
    for (int s = 0; s < samples; ++s) {
        const auto cpu_begin = Clock::now();
        cpu_add(a.data(), b.data(), cpu.data(), n);
        const auto cpu_end = Clock::now();
        cpu_us.push_back(std::chrono::duration<double, std::micro>(cpu_end - cpu_begin).count());
        max_error = std::max(max_error, validate(cpu, reference));

        // 排除先前 GPU 工作；截止点前 full_path 已等到输出可用。
        CUDA_CHECK(cudaDeviceSynchronize());
        const auto host_begin = Clock::now();
        full_path();
        const auto host_end = Clock::now();
        total_us.push_back(std::chrono::duration<double, std::micro>(host_end - host_begin).count());
        max_error = std::max(max_error, validate(c, reference));

        float elapsed_ms = std::numeric_limits<float>::quiet_NaN();
        // 起止标记和 kernel 都在 stream 0，按队列顺序界定整批工作。
        CUDA_CHECK(cudaEventRecord(start, 0));
        for (int j = 0; j < batch; ++j) {
            vector_add<<<grid, block>>>(d_a, d_b, d_c, n);
            CUDA_CHECK(cudaGetLastError());
        }
        CUDA_CHECK(cudaEventRecord(stop, 0));
        // CPU 等结束标记执行完再读取毫秒差；无需再做一次全设备同步。
        CUDA_CHECK(cudaEventSynchronize(stop));
        CUDA_CHECK(cudaEventElapsedTime(&elapsed_ms, start, stop));
        CUDA_CHECK(cudaMemcpy(c.data(), d_c, bytes, cudaMemcpyDeviceToHost));
        max_error = std::max(max_error, validate(c, reference));
        if (std::isfinite(elapsed_ms) && elapsed_ms > 0.0f) {
            event_us.push_back(elapsed_ms * 1000.0 / batch);
        } else {
            event_complete = false;
        }
    }
    std::printf("warmup=%d samples=%d event_batch=%d max_abs_error=%g\n",
                warmup, samples, batch, max_error);
    std::printf("cpu_add_host_median_us=%.6f\n", median(cpu_us));
    std::printf("gpu_with_copies_host_median_us=%.6f\n", median(total_us));
    if (event_complete) {
        std::printf("gpu_event_batch_per_launch_median_us=%.6f\n", median(event_us));
        std::puts("Timing PASS: interpret each timing boundary before comparing.");
    } else {
        std::puts("Timing FAIL: Event elapsed time must be finite and positive.");
    }
    cleanup();
    return event_complete ? EXIT_SUCCESS : EXIT_FAILURE;
}
