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
constexpr size_t kBytes = kN * sizeof(float);
constexpr size_t kAllBytes = kSteps * kBytes;

// 复用已学过的索引、尾部保护与加法，本章不修改kernel。
__global__ void vector_add(const float* a, const float* b, float* c, int n) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) c[i] = a[i] + b[i];
}

struct Buffers { float* a = nullptr; float* b = nullptr; float* c = nullptr; };
// 计数是本程序成功发出的Runtime调用，不是物理分配次数。
struct Calls { int mallocs = 0, frees = 0; };
struct Result { double host_batch_us = 0.0; Calls calls; };

static void allocate_sync(Buffers& b, Calls& calls) {
    CUDA_CHECK(cudaMalloc(&b.a, kBytes)); ++calls.mallocs;
    CUDA_CHECK(cudaMalloc(&b.b, kBytes)); ++calls.mallocs;
    CUDA_CHECK(cudaMalloc(&b.c, kBytes)); ++calls.mallocs;
}

// 调用者已确认相关stream完成，才可普通释放并清空host指针。
static void release_sync(Buffers& b, Calls& calls) {
    if (b.c) { CUDA_CHECK(cudaFree(b.c)); ++calls.frees; b.c = nullptr; }
    if (b.b) { CUDA_CHECK(cudaFree(b.b)); ++calls.frees; b.b = nullptr; }
    if (b.a) { CUDA_CHECK(cudaFree(b.a)); ++calls.frees; b.a = nullptr; }
}

// 输入空b和工作stream；输出三块可供该stream后续操作使用的地址。
static void allocate_async(Buffers& b, Calls& calls, cudaStream_t stream) {
    // CUDA将地址写回b；同一stream随后提交的工作按顺序使用这些分配。
    CUDA_CHECK(cudaMallocAsync(&b.a, kBytes, stream));
    ++calls.mallocs;
    CUDA_CHECK(cudaMallocAsync(&b.b, kBytes, stream));
    ++calls.mallocs;
    CUDA_CHECK(cudaMallocAsync(&b.c, kBytes, stream));
    ++calls.mallocs;
}

// 本轮D2H已经提交；释放也应排在同一stream，之后不再使用旧地址。
static void release_async(Buffers& b, Calls& calls, cudaStream_t stream) {
    // 清空的是CPU变量，已提交的任务仍按原顺序执行。
    CUDA_CHECK(cudaFreeAsync(b.c, stream));
    ++calls.frees;
    b.c = nullptr;
    CUDA_CHECK(cudaFreeAsync(b.b, stream));
    ++calls.frees;
    b.b = nullptr;
    CUDA_CHECK(cudaFreeAsync(b.a, stream));
    ++calls.frees;
    b.a = nullptr;
}

// 固定同一数据流：H2D两次→输出哨兵→vector_add→D2H。
// pinned host数组保证异步拷贝的输入/输出在整批完成前一直有效。
static void enqueue_work(const Buffers& b, const float* a, const float* input_b,
                         float* out, cudaStream_t stream) {
    CUDA_CHECK(cudaMemcpyAsync(b.a, a, kBytes, cudaMemcpyHostToDevice, stream));
    CUDA_CHECK(cudaMemcpyAsync(b.b, input_b, kBytes, cudaMemcpyHostToDevice, stream));
    CUDA_CHECK(cudaMemsetAsync(b.c, 0xff, kBytes, stream));
    vector_add<<<kGrid, kBlock, 0, stream>>>(b.a, b.b, b.c, kN);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaMemcpyAsync(out, b.c, kBytes, cudaMemcpyDeviceToHost, stream));
}

// 两种策略每轮都完成后再开始下一轮，固定CPU等待频率，不引入跨轮流水。
// sync：工作→等待→普通释放；async：工作→排入释放→等待。
// host_batch涵盖全部32轮的申请、传输、kernel提交、释放及完成等待。
static void run_batch(bool async, const float* a, const float* b, float* out,
                      cudaStream_t stream, Result& result) {
    result = {};
    CUDA_CHECK(cudaStreamSynchronize(stream));
    const auto t0 = Clock::now();
    for (int step = 0; step < kSteps; ++step) {
        Buffers buffers;
        if (async) {
            allocate_async(buffers, result.calls, stream);
        } else {
            allocate_sync(buffers, result.calls);
        }
        const size_t offset = static_cast<size_t>(step) * kN;
        enqueue_work(buffers, a + offset, b + offset, out + offset, stream);
        if (async) {
            release_async(buffers, result.calls, stream);
        }
        CUDA_CHECK(cudaStreamSynchronize(stream));
        if (!async) release_sync(buffers, result.calls);
    }
    result.host_batch_us = std::chrono::duration<double, std::micro>(Clock::now() - t0).count();
}

// 校验全部轮次；二进制分数输入可精确相加，旧输入或漏写由数值/NaN检查发现。
static bool validate(bool async, const float* a, const float* b, const float* out,
                     const Result& result, bool verbose) {
    int mismatches = 0;
    double max_abs = 0.0;
    for (int i = 0; i < kSteps * kN; ++i) {
        const double error = std::abs(static_cast<double>(out[i]) -
                                     (static_cast<double>(a[i]) + b[i]));
        if (!std::isfinite(error) || error > 1e-6) ++mismatches;
        max_abs = std::isfinite(error) ? std::max(max_abs, error) : INFINITY;
    }
    const bool counts_ok = result.calls.mallocs == 3 * kSteps &&
                           result.calls.frees == 3 * kSteps;
    if (verbose || mismatches || !counts_ok)
        std::printf("policy=%s checked=%d mismatches=%d max_abs_error=%.9g "
                    "malloc/free=%d/%d counts=%s correctness=%s\n", async ? "async" : "sync",
                    kSteps * kN, mismatches, max_abs, result.calls.mallocs, result.calls.frees,
                    counts_ok ? "PASS" : "FAIL", mismatches == 0 ? "PASS" : "FAIL");
    return mismatches == 0 && counts_ok;
}

// 在同步之后读取pool的当前用量，不用nvidia-smi总显存替代pool统计。
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
        (std::strcmp(selection, "sync") && std::strcmp(selection, "async") &&
         std::strcmp(selection, "both")) ||
        (!std::strcmp(mode, "trace") && !std::strcmp(selection, "both"))) {
        std::fprintf(stderr, "Usage: %s [check|bench|trace] [sync|async|both]\n"
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
    const bool needs_pool = std::strcmp(selection, "sync") != 0;
    if (needs_pool && !supported) {
        std::fputs("async NOT RUN: device/environment does not support memory pools.\n", stderr);
        return 2;
    }
    cudaStream_t stream = nullptr;
    CUDA_CHECK(cudaStreamCreateWithFlags(&stream, cudaStreamNonBlocking));
    cudaMemPool_t pool = nullptr;
    std::uint64_t old_threshold = 0;
    if (needs_pool) {
        CUDA_CHECK(cudaDeviceGetMemPool(&pool, 0));
        CUDA_CHECK(cudaMemPoolGetAttribute(pool, cudaMemPoolAttrReleaseThreshold, &old_threshold));
        // 本机预检观察到32MiB储备，固定64MiB使这份储备可在同步后保留。
        // 阈值控制同步时何时尝试归还空闲显存，实际保有量看reserved统计。
        std::uint64_t threshold = 64ULL * 1024 * 1024;
        CUDA_CHECK(cudaMemPoolSetAttribute(pool, cudaMemPoolAttrReleaseThreshold, &threshold));
        std::printf("pool release_threshold_bytes=%llu (fixed for this process)\n",
                    static_cast<unsigned long long>(threshold));
        print_pool(pool, "before");
    }
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
    if (std::strcmp(selection, "async")) policies.push_back(0);
    if (needs_pool) policies.push_back(1);
    auto execute = [&](int policy, bool verbose, Result& result) {
        std::memset(out, 0xff, kAllBytes);
        run_batch(policy != 0, a, b, out, stream, result);
        return validate(policy != 0, a, b, out, result, verbose);
    };
    int status = 0;
    Result result;
    // 先全量验证，再预热和计时。两种策略分别检查输出与调用数。
    for (int policy : policies) {
        if (!execute(policy, true, result)) { status = 2; break; }
        if (policy) print_pool(pool, "after_async_check");
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
                                policy ? "async" : "sync", kWarmup, kSamples, median(timings[policy]));
        }
    }
    CUDA_CHECK(cudaStreamSynchronize(stream));
    if (needs_pool) {
        print_pool(pool, "after_selected_work");
        CUDA_CHECK(cudaMemPoolTrimTo(pool, 0));
        print_pool(pool, "after_trim");
        CUDA_CHECK(cudaMemPoolSetAttribute(pool, cudaMemPoolAttrReleaseThreshold, &old_threshold));
    }
    CUDA_CHECK(cudaFreeHost(out));
    CUDA_CHECK(cudaFreeHost(b));
    CUDA_CHECK(cudaFreeHost(a));
    CUDA_CHECK(cudaStreamDestroy(stream));
    if (status == 0) std::puts("PASS (selected policies only; learner explanation still pending)");
    return status;
}
