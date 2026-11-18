#include <cuda_runtime.h>
#include <cuda_profiler_api.h>

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
constexpr int kN = 1000;
constexpr int kBlock = 128;
constexpr int kGrid = (kN + kBlock - 1) / kBlock;
constexpr int kSteps = 32;
constexpr int kWarmup = 3;
constexpr int kSamples = 21;
constexpr size_t kBytes = static_cast<size_t>(kN) * sizeof(float);

// 复用 Ch17 的算法和尾部保护；本章只改变 a/b/c 存储空间的生命周期。
__global__ void vector_add(const float* a, const float* b, float* c, int n) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) c[i] = a[i] + b[i];
}

struct Buffers {
    float* a = nullptr;
    float* b = nullptr;
    float* c = nullptr;
};

// 计数只代表本程序通过 helper 发出的成功 Runtime 调用，不推断驱动内部行为。
struct Calls {
    int mallocs = 0;
    int frees = 0;
};

static void allocate_buffers(Buffers& b, Calls& calls) {
    CUDA_CHECK(cudaMalloc(&b.a, kBytes)); ++calls.mallocs;
    CUDA_CHECK(cudaMalloc(&b.b, kBytes)); ++calls.mallocs;
    CUDA_CHECK(cudaMalloc(&b.c, kBytes)); ++calls.mallocs;
}

// 清空 host 指针避免悬空值；释放前，run_step 已完成等待和 D2H。
static void release_buffers(Buffers& b, Calls& calls) {
    if (b.c) { CUDA_CHECK(cudaFree(b.c)); ++calls.frees; b.c = nullptr; }
    if (b.b) { CUDA_CHECK(cudaFree(b.b)); ++calls.frees; b.b = nullptr; }
    if (b.a) { CUDA_CHECK(cudaFree(b.a)); ++calls.frees; b.a = nullptr; }
}

// 输入空的 b，输出可供整个循环使用的三块 device 空间；只在循环前调用一次。
static bool prepare_reuse_buffers(Buffers& b, Calls& calls) {
    // 三块空间在循环前统一分配，全部轮次完成后再由 run_batch 释放。
    allocate_buffers(b, calls);
    return true;
}

struct Timing {
    double host_loop_us = 0.0;
    double host_lifecycle_us = 0.0;
    double event_sum_us = 0.0;
};

struct Result {
    Timing time;
    Calls total;
    Calls loop;
};

// 输入每轮独立的 host 片段；输出回读到对应片段。两种策略执行完全相同的数据流。
// Event 只包住本轮 kernel；H2D、NaN 哨兵和 D2H 都在 Event 区间外。
static double run_step(const Buffers& b, const float* a, const float* input_b,
                       float* output, cudaEvent_t start, cudaEvent_t stop) {
    CUDA_CHECK(cudaMemcpy(b.a, a, kBytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(b.b, input_b, kBytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemset(b.c, 0xff, kBytes));
    // default stream 保序；先确认准备完成，避免把准备工作计入 Event。
    CUDA_CHECK(cudaDeviceSynchronize());
    CUDA_CHECK(cudaEventRecord(start));
    vector_add<<<kGrid, kBlock>>>(b.a, b.b, b.c, kN);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaEventRecord(stop));
    CUDA_CHECK(cudaEventSynchronize(stop));
    float elapsed_ms = 0.0f;
    CUDA_CHECK(cudaEventElapsedTime(&elapsed_ms, start, stop));
    CUDA_CHECK(cudaMemcpy(output, b.c, kBytes, cudaMemcpyDeviceToHost));
    return elapsed_ms * 1000.0;
}

// loop 时间包含每轮传输、初始化、Event 操作与完成等待；lifecycle 还包括循环外分配释放。
// trace 仅采集循环：复用路径的 setup/cleanup 明确放在采集区间外。
static bool run_batch(bool reuse, const std::vector<float>& a, const std::vector<float>& b,
                      std::vector<float>& output, cudaEvent_t start, cudaEvent_t stop,
                      bool trace, Result& result) {
    result = {};
    Buffers buffers;
    CUDA_CHECK(cudaDeviceSynchronize());
    const auto life0 = Clock::now();
    if (reuse && !prepare_reuse_buffers(buffers, result.total)) {
        release_buffers(buffers, result.total);
        std::fputs("reuse NOT RUN: buffer preparation failed.\n", stderr);
        return false;
    }
    if (reuse && (!buffers.a || !buffers.b || !buffers.c)) {
        release_buffers(buffers, result.total);
        std::fputs("reuse NOT RUN: buffer preparation did not provide three buffers.\n", stderr);
        return false;
    }
    const Calls before_loop = result.total;
    if (trace) CUDA_CHECK(cudaProfilerStart());
    const auto t0 = Clock::now();
    for (int step = 0; step < kSteps; ++step) {
        if (!reuse) allocate_buffers(buffers, result.total);
        const size_t offset = static_cast<size_t>(step) * kN;
        result.time.event_sum_us += run_step(buffers, a.data() + offset, b.data() + offset,
                                             output.data() + offset, start, stop);
        if (!reuse) release_buffers(buffers, result.total);
    }
    const auto t1 = Clock::now();  // 每轮已等 kernel 并完成 D2H，没有待完成的计算。
    if (trace) CUDA_CHECK(cudaProfilerStop());
    result.loop = {result.total.mallocs - before_loop.mallocs,
                   result.total.frees - before_loop.frees};
    if (reuse) release_buffers(buffers, result.total);
    const auto life1 = Clock::now();
    result.time.host_loop_us = std::chrono::duration<double, std::micro>(t1 - t0).count();
    result.time.host_lifecycle_us = std::chrono::duration<double, std::micro>(life1 - life0).count();
    return true;
}

// 全量检查全部 32 轮，既查数值也查调用位置；reference 用 double，非有限值判失败。
static bool validate(bool reuse, const std::vector<float>& a, const std::vector<float>& b,
                     const std::vector<float>& output, const Result& result, bool verbose) {
    int mismatches = 0;
    double max_abs = 0.0;
    for (size_t i = 0; i < output.size(); ++i) {
        const double expected = static_cast<double>(a[i]) + static_cast<double>(b[i]);
        const double error = std::abs(static_cast<double>(output[i]) - expected);
        if (!std::isfinite(error) || error > 1e-6) ++mismatches;
        max_abs = std::isfinite(error) ? std::max(max_abs, error) : INFINITY;
    }
    const int expected_total = reuse ? 3 : 3 * kSteps;
    const int expected_loop = reuse ? 0 : 3 * kSteps;
    const bool counts_ok = result.total.mallocs == expected_total &&
        result.total.frees == expected_total && result.loop.mallocs == expected_loop &&
        result.loop.frees == expected_loop;
    if (verbose || mismatches || !counts_ok) {
        std::printf("policy=%s checked=%zu mismatches=%d max_abs_error=%.9g "
                    "total_malloc/free=%d/%d loop_malloc/free=%d/%d counts=%s correctness=%s\n",
                    reuse ? "reuse" : "per_step", output.size(), mismatches, max_abs,
                    result.total.mallocs, result.total.frees, result.loop.mallocs, result.loop.frees,
                    counts_ok ? "PASS" : "FAIL", mismatches == 0 ? "PASS" : "FAIL");
    }
    return mismatches == 0 && counts_ok;
}

static double median(std::vector<double> values) {
    std::sort(values.begin(), values.end());
    return values[values.size() / 2];
}

// check 先验收；bench 正常计时；trace 预热后用 profiler API 只采集一批循环。
// 用法：memory_reuse [check|bench|trace] [per_step|reuse|both]。
int main(int argc, char** argv) {
    const char* mode = argc > 1 ? argv[1] : "check";
    const char* selection = argc > 2 ? argv[2] : "both";
    if (argc > 3 || (std::strcmp(mode, "check") && std::strcmp(mode, "bench") &&
                     std::strcmp(mode, "trace")) ||
        (std::strcmp(selection, "per_step") && std::strcmp(selection, "reuse") &&
         std::strcmp(selection, "both")) ||
        (!std::strcmp(mode, "trace") && !std::strcmp(selection, "both"))) {
        std::fprintf(stderr, "Usage: %s [check|bench|trace] [per_step|reuse|both]\n"
                             "trace requires a single policy.\n", argv[0]);
        return 2;
    }
    const char* blocking = std::getenv("CUDA_LAUNCH_BLOCKING");
    if (blocking && std::strcmp(blocking, "0")) {
        std::fputs("Unset CUDA_LAUNCH_BLOCKING before this experiment.\n", stderr);
        return 2;
    }
    CUDA_CHECK(cudaSetDevice(0));
    cudaDeviceProp prop{};
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    int runtime = 0, driver = 0;
    CUDA_CHECK(cudaRuntimeGetVersion(&runtime));
    CUDA_CHECK(cudaDriverGetVersion(&driver));
    std::printf("GPU=%s CC=%d.%d Runtime=%d DriverAPI=%d\n", prop.name,
                prop.major, prop.minor, runtime, driver);
    std::printf("mode=%s selection=%s n=%d dtype=float32 grid=%d block=%d steps=%d "
                "bytes_per_array=%zu CUDA_LAUNCH_BLOCKING=%s\n", mode, selection,
                kN, kGrid, kBlock, kSteps, kBytes, blocking ? blocking : "unset");

    std::vector<float> a(kSteps * kN), b(kSteps * kN), output(kSteps * kN);
    // 每轮输入不同，但两种策略使用相同输入；旧内容未更新会被全量校验发现。
    for (int step = 0; step < kSteps; ++step) {
        for (int i = 0; i < kN; ++i) {
            const size_t index = static_cast<size_t>(step) * kN + i;
            a[index] = static_cast<float>(i % 101 - 50 + step) / 8.0f;
            b[index] = static_cast<float>(i % 29 - 14 - step) / 16.0f;
        }
    }
    cudaEvent_t start = nullptr, stop = nullptr;
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));
    std::vector<int> policies;
    if (std::strcmp(selection, "reuse")) policies.push_back(0);
    if (std::strcmp(selection, "per_step")) policies.push_back(1);
    auto execute = [&](int policy, bool trace, bool verbose, Result& result) {
        return run_batch(policy != 0, a, b, output, start, stop, trace, result) &&
               validate(policy != 0, a, b, output, result, verbose);
    };
    int status = 0;
    Result result;
    for (int policy : policies) {
        if (!execute(policy, false, true, result)) { status = 2; break; }
    }
    if (status == 0 && std::strcmp(mode, "check")) {
        for (int warmup = 0; warmup < kWarmup && status == 0; ++warmup) {
            for (int policy : policies) {
                if (!execute(policy, false, false, result)) { status = 2; break; }
            }
        }
        if (status == 0 && !std::strcmp(mode, "trace")) {
            if (!execute(policies.front(), true, true, result)) status = 2;
            std::puts("Trace timing is not a normal benchmark; capture covers only the loop.");
        } else if (status == 0) {
            std::vector<double> loops[2], lifecycles[2], events[2];
            for (int sample = 0; sample < kSamples && status == 0; ++sample) {
                // 成对测量时交替策略顺序，减小固定先后顺序的影响。
                if (sample > 0) std::reverse(policies.begin(), policies.end());
                for (int policy : policies) {
                    if (!execute(policy, false, false, result)) { status = 2; break; }
                    loops[policy].push_back(result.time.host_loop_us);
                    lifecycles[policy].push_back(result.time.host_lifecycle_us);
                    events[policy].push_back(result.time.event_sum_us);
                }
            }
            if (status == 0) {
                for (int policy : policies) {
                    std::printf("policy=%s warmup=%d samples=%d median_host_loop_us=%.3f "
                                "median_host_lifecycle_us=%.3f median_event_sum_us=%.3f\n",
                                policy ? "reuse" : "per_step", kWarmup, kSamples,
                                median(loops[policy]), median(lifecycles[policy]), median(events[policy]));
                }
            }
        }
    }
    CUDA_CHECK(cudaEventDestroy(stop));
    CUDA_CHECK(cudaEventDestroy(start));
    if (status == 0) std::puts("PASS (selected policies only; learner explanation still pending)");
    return status;
}
