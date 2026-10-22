#include <cuda_runtime.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

// 沿用 Ch03：统一检查 host API；启动后检查提交错误，同步后检查执行错误。
static void check_cuda(cudaError_t status, const char* api, const char* file, int line) {
    if (status != cudaSuccess) {
        std::fprintf(stderr, "%s:%d: %s failed: %s (%s)\n", file, line, api,
                     cudaGetErrorName(status), cudaGetErrorString(status));
        std::exit(EXIT_FAILURE);
    }
}
#define CUDA_CHECK(call) check_cuda((call), #call, __FILE__, __LINE__)

constexpr int kN = 1000;
constexpr int kBlock = 128;  // 四个 warp；交换会跨 warp，不能只依赖 warp 内同步。
constexpr int kGrid = (kN + kBlock - 1) / kBlock;
constexpr int kWarmup = 10;
constexpr int kSamples = 21;
constexpr int kBatch = 10;

// 输入一维数组，输出每个 block 对应片段的反序结果；最后一片只反转有效元素。
// use_barrier 在一次 launch 内完全一致；false 仅用于故意缺同步的 race 诊断。
__global__ void exchange_block(const float* input, float* output, int n, bool use_barrier) {
    __shared__ float tile[kBlock];  // 每个 block 各有一份，128 个 float 共 512 字节。
    const int t = threadIdx.x;
    const int base = blockIdx.x * blockDim.x;
    const int i = base + t;
    const bool valid = i < n;
    const int count = n - base < kBlock ? n - base : kBlock;

    // 每个线程写自己的槽位；无效尾部线程也参加 block 协作，不提前 return。
    tile[t] = valid ? input[i] : 0.0f;
    if (use_barrier) {
        // 整个 block 写完后再读取伙伴数据；尾部无效线程也经过这个集合点。
        __syncthreads();
    }
    if (valid) {
        const int peer = count - 1 - t;
        // 读取伙伴线程的 shared 槽位，按当前片段的有效项数完成反序。
        output[i] = tile[peer];
    }
}

// CPU 从片段首尾向内填充，独立生成期望值，不读取 GPU shared buffer。
static std::vector<float> make_reference(const std::vector<float>& input) {
    std::vector<float> reference(kN);
    for (int begin = 0; begin < kN; begin += kBlock) {
        const int end = std::min(begin + kBlock, kN);
        int src = end - 1;
        for (int dst = begin; dst < end; ++dst, --src) reference[dst] = input[src];
    }
    return reference;
}

// 全量校验，拒绝 NaN/Inf；本章只有搬运，要求误差为零。
static bool validate(const std::vector<float>& output, const std::vector<float>& reference,
                     bool verbose) {
    int errors = 0;
    double max_error = 0.0;
    for (int i = 0; i < kN; ++i) {
        const double error = std::fabs(static_cast<double>(output[i]) - reference[i]);
        if (!std::isfinite(output[i]) || error != 0.0) ++errors;
        max_error = !std::isfinite(error) ? INFINITY : std::max(max_error, error);
    }
    if (verbose || errors != 0) {
        std::printf("correctness=%s checked=%d mismatches=%d max_abs_error=%.9g\n",
                    errors == 0 ? "PASS" : "FAIL", kN, errors, max_error);
    }
    return errors == 0;
}

static void launch(const float* input, float* output, bool use_barrier) {
    exchange_block<<<kGrid, kBlock>>>(input, output, kN, use_barrier);
    CUDA_CHECK(cudaGetLastError());
}

// 只给正确的同步版本计时；回读/校验放在 Event 区间外，计时不作为本章速度对照。
static bool benchmark(const float* input, float* output,
                      const std::vector<float>& reference, std::vector<float>& host_output) {
    for (int j = 0; j < kWarmup; ++j) launch(input, output, true);
    CUDA_CHECK(cudaDeviceSynchronize());
    cudaEvent_t start, stop;
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));
    std::vector<double> elapsed;
    bool correct = true;
    for (int s = 0; s < kSamples && correct; ++s) {
        CUDA_CHECK(cudaEventRecord(start, 0));
        for (int j = 0; j < kBatch; ++j) launch(input, output, true);
        CUDA_CHECK(cudaEventRecord(stop, 0));
        CUDA_CHECK(cudaEventSynchronize(stop));
        float ms = 0.0f;
        CUDA_CHECK(cudaEventElapsedTime(&ms, start, stop));
        CUDA_CHECK(cudaMemcpy(host_output.data(), output, kN * sizeof(float), cudaMemcpyDeviceToHost));
        correct = validate(host_output, reference, false) && std::isfinite(ms) && ms > 0.0f;
        elapsed.push_back(ms * 1000.0 / kBatch);
    }
    if (correct) {
        std::sort(elapsed.begin(), elapsed.end());
        std::printf("warmup=%d samples=%d event_batch=%d event_batch_per_launch_median_us=%.6f\n",
                    kWarmup, kSamples, kBatch, elapsed[elapsed.size() / 2]);
        std::puts("Timing PASS: synchronized version only; no speedup comparison.");
    } else {
        std::puts("Timing FAIL: invalid Event sample or output mismatch.");
    }
    CUDA_CHECK(cudaEventDestroy(stop));
    CUDA_CHECK(cudaEventDestroy(start));
    return correct;
}

// host 入口：check 为正确性检查，bench 为可选计时，race 为故意缺同步的错误对照。
int main(int argc, char** argv) {
    const char* mode = argc == 1 ? "check" : argv[1];
    if (argc > 2 || (std::strcmp(mode, "check") != 0 && std::strcmp(mode, "bench") != 0 &&
                     std::strcmp(mode, "race") != 0)) {
        std::fprintf(stderr, "Usage: %s [check|bench|race]\n", argv[0]);
        return EXIT_FAILURE;
    }
    const bool unsafe = std::strcmp(mode, "race") == 0;
    const bool timing = std::strcmp(mode, "bench") == 0;
    cudaDeviceProp prop{};
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    std::printf("GPU=%s CC=%d.%d warpSize=%d sharedMemPerBlock=%zu mode=%s\n",
                prop.name, prop.major, prop.minor, prop.warpSize, prop.sharedMemPerBlock, mode);
    std::printf("N=%d dtype=float32 grid=%d block=%d tail_count=%d shared_bytes_per_block=%zu\n",
                kN, kGrid, kBlock, kN % kBlock, kBlock * sizeof(float));
    if (unsafe) std::puts("Intentional missing-barrier diagnostic: numerical PASS does not imply race freedom.");

    std::vector<float> input(kN), output(kN);
    for (int i = 0; i < kN; ++i) input[i] = static_cast<float>(i) * 0.25f;
    const auto reference = make_reference(input);
    constexpr size_t bytes = kN * sizeof(float);
    float *d_input = nullptr, *d_output = nullptr;
    CUDA_CHECK(cudaMalloc(&d_input, bytes));
    CUDA_CHECK(cudaMalloc(&d_output, bytes));
    CUDA_CHECK(cudaMemcpy(d_input, input.data(), bytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemset(d_output, 0, bytes));
    launch(d_input, d_output, !unsafe);
    CUDA_CHECK(cudaDeviceSynchronize());
    CUDA_CHECK(cudaMemcpy(output.data(), d_output, bytes, cudaMemcpyDeviceToHost));
    bool correct = validate(output, reference, true);
    std::printf("examples: output[0]=%.2f expected=%.2f output[896]=%.2f expected=%.2f\n",
                output[0], reference[0], output[896], reference[896]);
    if (correct && timing) {
        correct = benchmark(d_input, d_output, reference, output);
    } else {
        std::puts(timing ? "Timing NOT RUN: correctness check failed."
                         : "Timing NOT RUN: check/race mode.");
    }
    CUDA_CHECK(cudaFree(d_output));
    CUDA_CHECK(cudaFree(d_input));
    // race 的数值仅是观测；返回 0 让 Sanitizer 在发现 hazard 时能用 --error-exitcode 99。
    if (unsafe) {
        std::puts("Diagnostic finished; use racecheck findings, not this exit status, to judge hazards.");
        return EXIT_SUCCESS;
    }
    return correct ? EXIT_SUCCESS : EXIT_FAILURE;
}
