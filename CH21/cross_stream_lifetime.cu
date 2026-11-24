#include <cuda_runtime.h>
#include <cuda_profiler_api.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

static void check_cuda(cudaError_t status, const char* api, const char* file, int line) {
    if (status != cudaSuccess) {
        std::fprintf(stderr, "%s:%d: %s: %s (%s)\n", file, line, api,
                     cudaGetErrorName(status), cudaGetErrorString(status));
        std::exit(EXIT_FAILURE);
    }
}
#define CUDA_CHECK(call) check_cuda((call), #call, __FILE__, __LINE__)

using Clock = std::chrono::steady_clock;
constexpr int kN = 1000, kBlock = 128, kGrid = (kN + kBlock - 1) / kBlock;
constexpr int kSteps = 32, kWarmup = 3, kSamples = 21;
constexpr size_t kBytes = kN * sizeof(float), kAllBytes = kSteps * kBytes;

// 索引和运算沿用Ch20，本章只修改两个跨stream依赖。
__global__ void vector_add(const float* a, const float* b, float* c, int n) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) c[i] = a[i] + b[i];
}

struct Buffers { float* a = nullptr; float* b = nullptr; float* c = nullptr; };
struct Queues {
    cudaStream_t owner = nullptr, worker = nullptr;
    // 每轮独立标记，避免把Event重复record的语义引入本节。
    cudaEvent_t ready[kSteps]{}, done[kSteps]{};
};
struct Result {
    double host_batch_us = 0.0;
    int mallocs = 0, frees = 0, host_waits = 0, device_waits = 0;
};

// ready记录在owner分配和上传之后，worker等它完成再访问数组。
static void wait_until_ready(cudaStream_t worker, cudaEvent_t ready) {
    CUDA_CHECK(cudaStreamWaitEvent(worker, ready, 0));
}

// done记录在worker回读之后，owner等它完成再释放数组。
static void wait_until_unused(cudaStream_t owner, cudaEvent_t done) {
    CUDA_CHECK(cudaStreamWaitEvent(owner, done, 0));
}

// 两种策略都用异步分配，固定由owner负责；API次数不是物理分配次数。
static void allocate(Buffers& b, cudaStream_t owner, Result& r) {
    CUDA_CHECK(cudaMallocAsync(&b.a, kBytes, owner)); ++r.mallocs;
    CUDA_CHECK(cudaMallocAsync(&b.b, kBytes, owner)); ++r.mallocs;
    CUDA_CHECK(cudaMallocAsync(&b.c, kBytes, owner)); ++r.mallocs;
}

static void release(Buffers& b, cudaStream_t owner, Result& r) {
    CUDA_CHECK(cudaFreeAsync(b.c, owner)); ++r.frees;
    CUDA_CHECK(cudaFreeAsync(b.b, owner)); ++r.frees;
    CUDA_CHECK(cudaFreeAsync(b.a, owner)); ++r.frees;
    // 清空CPU变量不影响此前已提交的地址参数；之后不再提交旧地址的访问。
    b = {};
}

// owner: 申请/H2D → ready → 等done → 释放；worker: 等ready → 计算/D2H → done。
// CPU等待与Event等待保护相同的两条边；本例不以跨轮GPU重叠为目标。
static void run_batch(bool event, const float* a, const float* b, float* out,
                      const Queues& q, Result& r) {
    r = {};
    CUDA_CHECK(cudaStreamSynchronize(q.owner));
    CUDA_CHECK(cudaStreamSynchronize(q.worker));
    const auto t0 = Clock::now();
    for (int step = 0; step < kSteps; ++step) {
        Buffers buffers;
        const size_t offset = static_cast<size_t>(step) * kN;
        allocate(buffers, q.owner, r);
        CUDA_CHECK(cudaMemcpyAsync(buffers.a, a + offset, kBytes,
                                   cudaMemcpyHostToDevice, q.owner));
        CUDA_CHECK(cudaMemcpyAsync(buffers.b, b + offset, kBytes,
                                   cudaMemcpyHostToDevice, q.owner));
        CUDA_CHECK(cudaEventRecord(q.ready[step], q.owner));
        if (event) {
            wait_until_ready(q.worker, q.ready[step]);
            ++r.device_waits;
        } else {
            CUDA_CHECK(cudaEventSynchronize(q.ready[step]));
            ++r.host_waits;
        }
        CUDA_CHECK(cudaMemsetAsync(buffers.c, 0xff, kBytes, q.worker));
        vector_add<<<kGrid, kBlock, 0, q.worker>>>(buffers.a, buffers.b, buffers.c, kN);
        CUDA_CHECK(cudaGetLastError());
        CUDA_CHECK(cudaMemcpyAsync(out + offset, buffers.c, kBytes,
                                   cudaMemcpyDeviceToHost, q.worker));
        CUDA_CHECK(cudaEventRecord(q.done[step], q.worker));
        if (event) {
            wait_until_unused(q.owner, q.done[step]);
            ++r.device_waits;
        } else {
            CUDA_CHECK(cudaEventSynchronize(q.done[step]));
            ++r.host_waits;
        }
        release(buffers, q.owner, r);
    }
    // 最后统一等待：回读、跨队列访问、异步释放均须完成才可校验host输出。
    CUDA_CHECK(cudaStreamSynchronize(q.owner));
    CUDA_CHECK(cudaStreamSynchronize(q.worker));
    r.host_batch_us = std::chrono::duration<double, std::micro>(Clock::now() - t0).count();
}

// 全量校验每轮输入对应的输出，漏写、旧值和NaN都判失败。
static bool validate(bool event, const float* a, const float* b, const float* out,
                     const Result& r, bool verbose) {
    int mismatches = 0;
    double max_abs = 0.0;
    for (int i = 0; i < kSteps * kN; ++i) {
        const double error = std::abs(static_cast<double>(out[i]) -
                                     (static_cast<double>(a[i]) + b[i]));
        if (!std::isfinite(error) || error > 1e-6) ++mismatches;
        max_abs = std::isfinite(error) ? std::max(max_abs, error) : INFINITY;
    }
    const int expected_host_waits = event ? 0 : 2 * kSteps;
    const int expected_device_waits = event ? 2 * kSteps : 0;
    const bool counts_ok = r.mallocs == 3 * kSteps && r.frees == 3 * kSteps &&
                           r.host_waits == expected_host_waits &&
                           r.device_waits == expected_device_waits;
    if (verbose || mismatches || !counts_ok)
        std::printf("policy=%s checked=%d mismatches=%d max_abs_error=%.9g "
                    "malloc/free=%d/%d host_waits=%d device_waits=%d counts=%s correctness=%s\n",
                    event ? "event" : "host", kSteps * kN, mismatches, max_abs,
                    r.mallocs, r.frees, r.host_waits, r.device_waits,
                    counts_ok ? "PASS" : "FAIL", mismatches == 0 ? "PASS" : "FAIL");
    return mismatches == 0 && counts_ok;
}

static void print_pool(cudaMemPool_t pool, const char* phase) {
    std::uint64_t used = 0, reserved = 0;
    CUDA_CHECK(cudaMemPoolGetAttribute(pool, cudaMemPoolAttrUsedMemCurrent, &used));
    CUDA_CHECK(cudaMemPoolGetAttribute(pool, cudaMemPoolAttrReservedMemCurrent, &reserved));
    std::printf("pool phase=%s used_bytes=%llu reserved_bytes=%llu\n", phase,
                static_cast<unsigned long long>(used), static_cast<unsigned long long>(reserved));
}

static double median(std::vector<double> values) {
    std::sort(values.begin(), values.end());
    return values[values.size() / 2];
}

int main(int argc, char** argv) {
    const char* mode = argc > 1 ? argv[1] : "check";
    const char* selection = argc > 2 ? argv[2] : "both";
    if (argc > 3 || (std::strcmp(mode, "check") && std::strcmp(mode, "bench") &&
                     std::strcmp(mode, "trace")) ||
        (std::strcmp(selection, "host") && std::strcmp(selection, "event") &&
         std::strcmp(selection, "both")) ||
        (!std::strcmp(mode, "trace") && !std::strcmp(selection, "both"))) {
        std::fprintf(stderr, "Usage: %s [check|bench|trace] [host|event|both]\n"
                             "trace requires one policy.\n", argv[0]);
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
    int supported = 0, runtime = 0, driver = 0;
    CUDA_CHECK(cudaDeviceGetAttribute(&supported, cudaDevAttrMemoryPoolsSupported, 0));
    CUDA_CHECK(cudaRuntimeGetVersion(&runtime));
    CUDA_CHECK(cudaDriverGetVersion(&driver));
    std::printf("GPU=%s CC=%d.%d Runtime=%d DriverAPI=%d memory_pools_supported=%d\n",
                prop.name, prop.major, prop.minor, runtime, driver, supported);
    std::printf("mode=%s selection=%s n=%d dtype=float32 grid=%d block=%d steps=%d "
                "bytes_per_array=%zu CUDA_LAUNCH_BLOCKING=%s\n", mode, selection,
                kN, kGrid, kBlock, kSteps, kBytes, blocking ? blocking : "unset");
    if (!supported) {
        std::fputs("NOT RUN: device/environment does not support memory pools.\n", stderr);
        return 2;
    }
    Queues q;
    CUDA_CHECK(cudaStreamCreateWithFlags(&q.owner, cudaStreamNonBlocking));
    CUDA_CHECK(cudaStreamCreateWithFlags(&q.worker, cudaStreamNonBlocking));
    for (int step = 0; step < kSteps; ++step) {
        CUDA_CHECK(cudaEventCreateWithFlags(&q.ready[step], cudaEventDisableTiming));
        CUDA_CHECK(cudaEventCreateWithFlags(&q.done[step], cudaEventDisableTiming));
    }
    cudaMemPool_t pool = nullptr;
    std::uint64_t old_threshold = 0, threshold = 64ULL * 1024 * 1024;
    CUDA_CHECK(cudaDeviceGetMemPool(&pool, 0));
    CUDA_CHECK(cudaMemPoolGetAttribute(pool, cudaMemPoolAttrReleaseThreshold, &old_threshold));
    CUDA_CHECK(cudaMemPoolSetAttribute(pool, cudaMemPoolAttrReleaseThreshold, &threshold));
    std::printf("pool release_threshold_bytes=%llu (same for both policies)\n",
                static_cast<unsigned long long>(threshold));
    float *a = nullptr, *b = nullptr, *out = nullptr;
    CUDA_CHECK(cudaMallocHost(&a, kAllBytes));
    CUDA_CHECK(cudaMallocHost(&b, kAllBytes));
    CUDA_CHECK(cudaMallocHost(&out, kAllBytes));
    for (int step = 0; step < kSteps; ++step) {
        for (int i = 0; i < kN; ++i) {
            const int index = step * kN + i;
            a[index] = static_cast<float>(i % 101 - 50 + step) / 8.0f;
            b[index] = static_cast<float>(i % 29 - 14 + step) / 16.0f;
        }
    }
    std::vector<int> policies;
    if (std::strcmp(selection, "event")) policies.push_back(0);
    if (std::strcmp(selection, "host")) policies.push_back(1);
    auto execute = [&](int policy, bool verbose, Result& r) {
        std::memset(out, 0xff, kAllBytes);
        run_batch(policy != 0, a, b, out, q, r);
        return validate(policy != 0, a, b, out, r, verbose);
    };
    int status = 0;
    Result result;
    for (int policy : policies) {
        if (!execute(policy, true, result)) { status = 2; break; }
    }
    if (status == 0 && std::strcmp(mode, "check")) {
        for (int warmup = 0; warmup < kWarmup && status == 0; ++warmup)
            for (int policy : policies)
                if (!execute(policy, false, result)) { status = 2; break; }
        if (status == 0 && !std::strcmp(mode, "trace")) {
            CUDA_CHECK(cudaProfilerStart());
            if (!execute(policies.front(), true, result)) status = 2;
            CUDA_CHECK(cudaProfilerStop());
            std::puts("Trace covers one warmed batch; profiler timing is not a normal benchmark.");
        } else if (status == 0) {
            std::vector<double> timings[2];
            for (int sample = 0; sample < kSamples && status == 0; ++sample) {
                if (sample) std::reverse(policies.begin(), policies.end());
                for (int policy : policies) {
                    if (!execute(policy, false, result)) { status = 2; break; }
                    timings[policy].push_back(result.host_batch_us);
                }
            }
            if (status == 0)
                for (int policy : policies)
                    std::printf("policy=%s warmup=%d samples=%d median_host_batch_us=%.3f\n",
                                policy ? "event" : "host", kWarmup, kSamples, median(timings[policy]));
        }
    }
    CUDA_CHECK(cudaStreamSynchronize(q.owner));
    CUDA_CHECK(cudaStreamSynchronize(q.worker));
    print_pool(pool, "after_selected_work");
    CUDA_CHECK(cudaMemPoolTrimTo(pool, 0));
    print_pool(pool, "after_trim");
    CUDA_CHECK(cudaMemPoolSetAttribute(pool, cudaMemPoolAttrReleaseThreshold, &old_threshold));
    CUDA_CHECK(cudaFreeHost(out));
    CUDA_CHECK(cudaFreeHost(b));
    CUDA_CHECK(cudaFreeHost(a));
    for (int step = 0; step < kSteps; ++step) {
        CUDA_CHECK(cudaEventDestroy(q.done[step]));
        CUDA_CHECK(cudaEventDestroy(q.ready[step]));
    }
    CUDA_CHECK(cudaStreamDestroy(q.worker));
    CUDA_CHECK(cudaStreamDestroy(q.owner));
    if (status == 0) std::puts("PASS (selected policies only; learner explanation still pending)");
    return status;
}
