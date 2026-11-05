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
constexpr int kN = 262147;  // 每块约 1 MiB，尾部 block 只有 3 个有效线程。
constexpr int kChunks = 8;
constexpr int kSlots = 2;
constexpr int kBlock = 256;
constexpr int kRepeats = 256;
constexpr int kWarmup = 3;
constexpr int kSamples = 21;
constexpr size_t kBytes = static_cast<size_t>(kN) * sizeof(float);
constexpr size_t kTotal = static_cast<size_t>(kChunks) * kN;

// 复用逐元素重复加法；输入值按块变化，便于发现读到了上一轮的槽位内容。
__global__ void repeated_add(const float* input, float* output, int n) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    float value = input[i];
    for (int r = 0; r < kRepeats; ++r) value += 0.125f;
    output[i] = value;
}

struct Slot {
    float* input = nullptr;
    float* output = nullptr;
    cudaEvent_t ready = nullptr;  // upload 已完成本块 H2D。
    cudaEvent_t done = nullptr;   // compute 已完成本块 kernel 和 D2H。
};

// 给 compute 后续工作加上输入就绪依赖；CPU 无需先等待 H2D 完成。
static bool wait_for_input(cudaStream_t compute, cudaEvent_t ready) {
    CUDA_CHECK(cudaStreamWaitEvent(compute, ready, 0));
    return true;
}

// 给 upload 后续工作加上旧槽位完成依赖，防止新 H2D 过早覆盖旧输入。
static bool wait_for_slot(cudaStream_t upload, cudaEvent_t done) {
    CUDA_CHECK(cudaStreamWaitEvent(upload, done, 0));
    return true;
}

// 整块 H2D -> ready -> kernel -> D2H -> done，不改变块内的数据依赖。
// serial 每块额外等待 done；pipeline 只在整批结尾等待，槽位由 Event 保护。
static bool run_batch(const float* host_input, float* host_output, Slot (&slots)[kSlots],
                      cudaStream_t upload, cudaStream_t compute, bool pipeline,
                      double& host_us) {
    CUDA_CHECK(cudaStreamSynchronize(upload));
    CUDA_CHECK(cudaStreamSynchronize(compute));
    std::memset(host_output, 0xff, kTotal * sizeof(float));
    for (auto& slot : slots)
        CUDA_CHECK(cudaMemsetAsync(slot.output, 0xff, kBytes, compute));
    CUDA_CHECK(cudaStreamSynchronize(compute));  // 哨兵准备不计时。

    bool device_waits = true;
    const auto t0 = Clock::now();
    for (int chunk = 0; chunk < kChunks; ++chunk) {
        Slot& slot = slots[chunk % kSlots];
        const size_t offset = static_cast<size_t>(chunk) * kN;
        if (chunk >= kSlots) {  // 首次使用不等未 record 的 done。
            const bool inserted = wait_for_slot(upload, slot.done);
            device_waits = inserted && device_waits;
        }
        CUDA_CHECK(cudaMemcpyAsync(slot.input, host_input + offset, kBytes,
                                   cudaMemcpyHostToDevice, upload));
        CUDA_CHECK(cudaEventRecord(slot.ready, upload));
        const bool inserted = wait_for_input(compute, slot.ready);
        device_waits = inserted && device_waits;
        repeated_add<<<(kN + kBlock - 1) / kBlock, kBlock, 0, compute>>>(
            slot.input, slot.output, kN);
        CUDA_CHECK(cudaGetLastError());
        CUDA_CHECK(cudaMemcpyAsync(host_output + offset, slot.output, kBytes,
                                   cudaMemcpyDeviceToHost, compute));
        CUDA_CHECK(cudaEventRecord(slot.done, compute));
        if (!pipeline) CUDA_CHECK(cudaEventSynchronize(slot.done));
    }
    CUDA_CHECK(cudaStreamSynchronize(compute));  // 最后一块 D2H 也已完成。
    CUDA_CHECK(cudaStreamSynchronize(upload));
    const auto t1 = Clock::now();
    host_us = std::chrono::duration<double, std::micro>(t1 - t0).count();
    return device_waits;
}

// CPU double reference 全量检查；输入为 /16 数，256 次 +1/8 在本范围精确。
static bool validate(const float* output, const float* input, const char* layout,
                     bool verbose) {
    size_t mismatches = 0;
    double max_abs = 0.0;
    for (size_t j = 0; j < kTotal; ++j) {
        const double expected = static_cast<double>(input[j]) + kRepeats * 0.125;
        const double error = std::fabs(static_cast<double>(output[j]) - expected);
        const bool finite = std::isfinite(error);
        if (!finite || error != 0.0) ++mismatches;
        max_abs = finite ? std::max(max_abs, error) : INFINITY;
    }
    if (verbose || mismatches != 0)
        std::printf("layout=%s checked=%zu correctness=%s mismatches=%zu max_abs_error=%.9g\n",
                    layout, kTotal, mismatches == 0 ? "PASS" : "FAIL", mismatches, max_abs);
    return mismatches == 0;
}

static double median(std::vector<double> values) {
    std::sort(values.begin(), values.end());
    return values[values.size() / 2];
}

// check 校验两种调度；bench 普通计时；trace 单独采集，最后 8 次 kernel 为目标批次。
int main(int argc, char** argv) {
    const char* mode = argc > 1 ? argv[1] : "check";
    const char* selection = argc > 2 ? argv[2] : "both";
    if (argc > 3 || (std::strcmp(mode, "check") != 0 && std::strcmp(mode, "bench") != 0 &&
                     std::strcmp(mode, "trace") != 0) ||
        (std::strcmp(selection, "serial") != 0 && std::strcmp(selection, "pipeline") != 0 &&
         std::strcmp(selection, "both") != 0)) {
        std::fprintf(stderr, "Usage: %s [check|bench|trace] [serial|pipeline|both]\n", argv[0]);
        return EXIT_FAILURE;
    }
    CUDA_CHECK(cudaSetDevice(0));
    cudaDeviceProp prop{};
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    std::printf("GPU=%s CC=%d.%d SMs=%d asyncEngineCount=%d concurrentKernels=%d\n",
                prop.name, prop.major, prop.minor, prop.multiProcessorCount,
                prop.asyncEngineCount, prop.concurrentKernels);
    std::printf("mode=%s selection=%s chunks=%d slots=%d N_per_chunk=%d dtype=float32 "
                "block=%d grid=%d repeats=%d bytes_per_copy=%zu\n",
                mode, selection, kChunks, kSlots, kN, kBlock,
                (kN + kBlock - 1) / kBlock, kRepeats, kBytes);
    const char* blocking = std::getenv("CUDA_LAUNCH_BLOCKING");
    std::printf("CUDA_LAUNCH_BLOCKING=%s\n", blocking ? blocking : "unset");
    if (blocking && std::strcmp(blocking, "0") != 0) {
        std::fputs("Use unset CUDA_LAUNCH_BLOCKING or value 0 for this experiment.\n", stderr);
        return EXIT_FAILURE;
    }

    // pinned memory：固定在内存中的 host 缓冲，供异步 H2D/D2H 使用。
    // 各块 host 地址互不重叠，整批完成前 CPU 不改 input、不读写 output。
    float *host_input = nullptr, *host_output = nullptr;
    CUDA_CHECK(cudaMallocHost(&host_input, kTotal * sizeof(float)));
    CUDA_CHECK(cudaMallocHost(&host_output, kTotal * sizeof(float)));
    for (int chunk = 0; chunk < kChunks; ++chunk)
        for (int i = 0; i < kN; ++i)
            host_input[static_cast<size_t>(chunk) * kN + i] =
                static_cast<float>((i * 7 + chunk * 13) % 257 - 128) / 16.0f;

    cudaStream_t upload = nullptr, compute = nullptr;
    CUDA_CHECK(cudaStreamCreateWithFlags(&upload, cudaStreamNonBlocking));
    CUDA_CHECK(cudaStreamCreateWithFlags(&compute, cudaStreamNonBlocking));
    Slot slots[kSlots];
    for (auto& slot : slots) {
        CUDA_CHECK(cudaMalloc(&slot.input, kBytes));
        CUDA_CHECK(cudaMalloc(&slot.output, kBytes));
        CUDA_CHECK(cudaEventCreateWithFlags(&slot.ready, cudaEventDisableTiming));
        CUDA_CHECK(cudaEventCreateWithFlags(&slot.done, cudaEventDisableTiming));
    }

    bool all_ok = true;
    for (int variant = 0; variant < 2; ++variant) {
        const bool pipeline = variant == 1;
        const char* layout = pipeline ? "pipeline" : "serial";
        if (std::strcmp(selection, "both") != 0 && std::strcmp(selection, layout) != 0) continue;
        double host_us = 0.0;
        const bool waits_ok = run_batch(host_input, host_output, slots, upload, compute,
                                        pipeline, host_us);
        const bool correct = validate(host_output, host_input, layout, true);
        bool ready = waits_ok && correct;
        std::printf("layout=%s device_event_waits=%s\n", layout,
                    waits_ok ? "PASS (verify implementation/timeline)" : "INCOMPLETE");
        if (ready && std::strcmp(mode, "check") != 0) {
            for (int i = 0; i < kWarmup; ++i) {
                const bool waits = run_batch(host_input, host_output, slots, upload, compute,
                                              pipeline, host_us);
                const bool valid = validate(host_output, host_input, layout, false);
                ready = waits && valid && ready;
            }
            const bool bench = std::strcmp(mode, "bench") == 0;
            const int samples = bench ? kSamples : 1;
            std::vector<double> times;
            for (int i = 0; i < samples && ready; ++i) {
                const bool waits = run_batch(host_input, host_output, slots, upload, compute,
                                              pipeline, host_us);
                const bool valid = validate(host_output, host_input, layout, false);
                ready = waits && valid && std::isfinite(host_us) && host_us > 0.0;
                if (ready) times.push_back(host_us);
            }
            if (ready)
                std::printf("layout=%s warmup=%d samples=%d batch_chunks=%d host_batch_%s_us=%.6f %s\n",
                            layout, kWarmup, samples, kChunks, bench ? "median" : "trace",
                            median(times), bench ? "Timing PASS" : "Trace observation only");
        }
        if (!ready)
            std::puts("Timing NOT RUN/REJECTED: finish both device Event waits and pass correctness.");
        all_ok = ready && all_ok;
    }

    // run_batch 已等待所有使用者，销毁和释放均在计时外。
    for (auto& slot : slots) {
        CUDA_CHECK(cudaEventDestroy(slot.done));
        CUDA_CHECK(cudaEventDestroy(slot.ready));
        CUDA_CHECK(cudaFree(slot.output));
        CUDA_CHECK(cudaFree(slot.input));
    }
    CUDA_CHECK(cudaStreamDestroy(compute));
    CUDA_CHECK(cudaStreamDestroy(upload));
    CUDA_CHECK(cudaFreeHost(host_output));
    CUDA_CHECK(cudaFreeHost(host_input));
    std::printf("Experiment %s\n", all_ok ? "PASS" : "INCOMPLETE/FAIL");
    return all_ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
