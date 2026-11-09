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
constexpr int kN = 4099;  // 末 block 只有 3 项有效，保留尾部边界检查。
constexpr int kBlock = 256;
constexpr int kGrid = (kN + kBlock - 1) / kBlock;
constexpr int kChains = 64;
constexpr int kWarmup = 3;
constexpr int kSamples = 21;
constexpr size_t kBytes = static_cast<size_t>(kN) * sizeof(float);

// 每线程只处理自己的一项；三个阶段分开启动，便于在时间线上数 kernel。
__global__ void add_one(const float* input, float* output, int n) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) output[i] = input[i] + 1.0f;
}

__global__ void scale_two(const float* input, float* output, int n) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) output[i] = input[i] * 2.0f;
}

__global__ void subtract_half(const float* input, float* output, int n) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) output[i] = input[i] - 0.5f;
}

struct Buffers {
    float* input = nullptr;
    float* tmp0 = nullptr;
    float* tmp1 = nullptr;
    float* output = nullptr;
};

// 同一 stream 中的顺序保证 tmp0/tmp1 先写后读；这里没有 host 等待。
static void launch_chain(const Buffers& b, cudaStream_t stream) {
    add_one<<<kGrid, kBlock, 0, stream>>>(b.input, b.tmp0, kN);
    CUDA_CHECK(cudaGetLastError());
    scale_two<<<kGrid, kBlock, 0, stream>>>(b.tmp0, b.tmp1, kN);
    CUDA_CHECK(cudaGetLastError());
    subtract_half<<<kGrid, kBlock, 0, stream>>>(b.tmp1, b.output, kN);
    CUDA_CHECK(cudaGetLastError());
}

// 只录一条三阶段链；分配、预热、同步和计时 Event 均留在 capture 外。
static bool capture_chain(const Buffers& b, cudaStream_t stream,
                          cudaGraph_t& graph, cudaGraphExec_t& exec) {
    CUDA_CHECK(cudaStreamBeginCapture(stream, cudaStreamCaptureModeGlobal));
    launch_chain(b, stream);  // 此时记录三个 kernel 及顺序，不执行这条链。
    CUDA_CHECK(cudaStreamEndCapture(stream, &graph));
    CUDA_CHECK(cudaGraphInstantiate(&exec, graph, 0));  // 生成可重复启动的对象。
    return true;
}

// 重放已实例化的图；API 返回仍不等于设备执行完成。
static bool replay_chain(cudaGraphExec_t exec, cudaStream_t stream) {
    CUDA_CHECK(cudaGraphLaunch(exec, stream));
    return true;  // 只说明提交成功，整批完成等待仍由 run_batch 负责。
}

// host 提交、host 完成与同 stream Event 区间分别保留，不互相相减。
struct Timing {
    double submit_us = 0.0;
    double complete_us = 0.0;
    double event_us = 0.0;
};

// 一批重复相同的链 64 次，每次从同一 input 读取，不把 output 作为下轮输入。
// 路径检查保留安全回退：回退时返回 false，拒绝将普通启动发布为 Graph 计时。
static bool run_batch(const Buffers& b, cudaStream_t stream, cudaGraphExec_t exec,
                      bool graph_mode, cudaEvent_t start, cudaEvent_t stop, Timing& time) {
    CUDA_CHECK(cudaStreamSynchronize(stream));
    CUDA_CHECK(cudaMemsetAsync(b.tmp0, 0xff, kBytes, stream));
    CUDA_CHECK(cudaMemsetAsync(b.tmp1, 0xff, kBytes, stream));
    CUDA_CHECK(cudaMemsetAsync(b.output, 0xff, kBytes, stream));
    CUDA_CHECK(cudaStreamSynchronize(stream));  // NaN 哨兵准备在计时外。

    CUDA_CHECK(cudaEventRecord(start, stream));
    bool path_ok = true;
    const auto t0 = Clock::now();
    for (int chain = 0; chain < kChains; ++chain) {
        if (graph_mode) {
            const bool replayed = exec != nullptr && replay_chain(exec, stream);
            if (!replayed) launch_chain(b, stream);
            path_ok = replayed && path_ok;
        } else {
            launch_chain(b, stream);
        }
    }
    const auto t1 = Clock::now();
    CUDA_CHECK(cudaEventRecord(stop, stream));
    CUDA_CHECK(cudaStreamSynchronize(stream));
    const auto t2 = Clock::now();
    float elapsed_ms = 0.0f;
    CUDA_CHECK(cudaEventElapsedTime(&elapsed_ms, start, stop));
    time.submit_us = std::chrono::duration<double, std::micro>(t1 - t0).count();
    time.complete_us = std::chrono::duration<double, std::micro>(t2 - t0).count();
    time.event_us = elapsed_ms * 1000.0;
    return path_ok;
}

// 全量 CPU double reference；/16 输入及本例三步运算可精确表示。
static bool validate(const Buffers& b, const std::vector<float>& input,
                     std::vector<float>& output, const char* layout, bool verbose) {
    CUDA_CHECK(cudaMemcpy(output.data(), b.output, kBytes, cudaMemcpyDeviceToHost));
    int mismatches = 0;
    double max_abs = 0.0;
    for (int i = 0; i < kN; ++i) {
        const double expected = (static_cast<double>(input[i]) + 1.0) * 2.0 - 0.5;
        const double error = std::fabs(static_cast<double>(output[i]) - expected);
        const bool finite = std::isfinite(error);
        if (!finite || error != 0.0) ++mismatches;
        max_abs = finite ? std::max(max_abs, error) : INFINITY;
    }
    if (verbose || mismatches != 0)
        std::printf("layout=%s checked=%d correctness=%s mismatches=%d max_abs_error=%.9g\n",
                    layout, kN, mismatches == 0 ? "PASS" : "FAIL", mismatches, max_abs);
    return mismatches == 0;
}

static double median(std::vector<double> values) {
    std::sort(values.begin(), values.end());
    return values[values.size() / 2];
}

// check 检查路径与数值；bench 普通计时；trace 的最后 192 个 GPU kernel 是目标批次。
int main(int argc, char** argv) {
    const char* mode = argc > 1 ? argv[1] : "check";
    const char* selection = argc > 2 ? argv[2] : "both";
    if (argc > 3 || (std::strcmp(mode, "check") != 0 && std::strcmp(mode, "bench") != 0 &&
                     std::strcmp(mode, "trace") != 0) ||
        (std::strcmp(selection, "direct") != 0 && std::strcmp(selection, "graph") != 0 &&
         std::strcmp(selection, "both") != 0)) {
        std::fprintf(stderr, "Usage: %s [check|bench|trace] [direct|graph|both]\n", argv[0]);
        return EXIT_FAILURE;
    }
    CUDA_CHECK(cudaSetDevice(0));
    cudaDeviceProp prop{};
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    int runtime = 0, driver = 0;
    CUDA_CHECK(cudaRuntimeGetVersion(&runtime));
    CUDA_CHECK(cudaDriverGetVersion(&driver));
    std::printf("GPU=%s CC=%d.%d SMs=%d Runtime=%d DriverAPI=%d\n",
                prop.name, prop.major, prop.minor, prop.multiProcessorCount, runtime, driver);
    std::printf("mode=%s selection=%s N=%d dtype=float32 block=%d grid=%d "
                "chains_per_batch=%d kernels_per_chain=3 bytes_per_array=%zu\n",
                mode, selection, kN, kBlock, kGrid, kChains, kBytes);
    const char* blocking = std::getenv("CUDA_LAUNCH_BLOCKING");
    std::printf("CUDA_LAUNCH_BLOCKING=%s\n", blocking ? blocking : "unset");
    if (blocking && std::strcmp(blocking, "0") != 0) {
        std::fputs("Use unset CUDA_LAUNCH_BLOCKING or value 0 for this experiment.\n", stderr);
        return EXIT_FAILURE;
    }

    std::vector<float> input(kN), output(kN);
    for (int i = 0; i < kN; ++i) input[i] = static_cast<float>((i * 7) % 257 - 128) / 16.0f;
    Buffers b;
    CUDA_CHECK(cudaMalloc(&b.input, kBytes));
    CUDA_CHECK(cudaMalloc(&b.tmp0, kBytes));
    CUDA_CHECK(cudaMalloc(&b.tmp1, kBytes));
    CUDA_CHECK(cudaMalloc(&b.output, kBytes));
    CUDA_CHECK(cudaMemcpy(b.input, input.data(), kBytes, cudaMemcpyHostToDevice));
    cudaStream_t stream = nullptr;
    CUDA_CHECK(cudaStreamCreateWithFlags(&stream, cudaStreamNonBlocking));
    cudaEvent_t start = nullptr, stop = nullptr;
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));

    launch_chain(b, stream);  // capture 前预热三个函数；所有地址直到清理时保持有效。
    CUDA_CHECK(cudaStreamSynchronize(stream));
    cudaGraph_t graph = nullptr;
    cudaGraphExec_t exec = nullptr;
    bool graph_ready = false;
    if (std::strcmp(selection, "direct") != 0) {
        const bool captured = capture_chain(b, stream, graph, exec);
        size_t count = 0;
        bool kernel_nodes = false;
        if (graph != nullptr && exec != nullptr) {
            CUDA_CHECK(cudaGraphGetNodes(graph, nullptr, &count));
            std::vector<cudaGraphNode_t> nodes(count);
            CUDA_CHECK(cudaGraphGetNodes(graph, nodes.data(), &count));
            kernel_nodes = count == 3;
            for (auto node : nodes) {
                cudaGraphNodeType type{};
                CUDA_CHECK(cudaGraphNodeGetType(node, &type));
                kernel_nodes = type == cudaGraphNodeTypeKernel && kernel_nodes;
            }
        }
        graph_ready = captured && graph != nullptr && exec != nullptr && kernel_nodes;
        std::printf("capture_and_instantiate=%s graph_nodes=%zu expected_kernel_nodes=3\n",
                    graph_ready ? "PASS" : "INCOMPLETE/FAIL", count);
    }

    bool all_ok = true;
    for (int variant = 0; variant < 2; ++variant) {
        const bool graph_mode = variant == 1;
        const char* layout = graph_mode ? "graph" : "direct";
        if (std::strcmp(selection, "both") != 0 && std::strcmp(selection, layout) != 0) continue;
        Timing time;
        const bool path_ok = run_batch(b, stream, exec, graph_mode, start, stop, time);
        const bool correct = validate(b, input, output, layout, true);
        bool ready = path_ok && correct && (!graph_mode || graph_ready);
        std::printf("layout=%s submission_path=%s\n", layout,
                    path_ok ? (graph_mode ? "graph_replay" : "direct") : "INCOMPLETE (direct fallback)");
        if (ready && std::strcmp(mode, "check") != 0) {
            for (int i = 0; i < kWarmup; ++i) {
                const bool path = run_batch(b, stream, exec, graph_mode, start, stop, time);
                const bool valid = validate(b, input, output, layout, false);
                ready = path && valid && ready;
            }
            const bool bench = std::strcmp(mode, "bench") == 0;
            const int samples = bench ? kSamples : 1;
            std::vector<double> submit, complete, event;
            for (int i = 0; i < samples && ready; ++i) {
                const bool path = run_batch(b, stream, exec, graph_mode, start, stop, time);
                const bool valid = validate(b, input, output, layout, false);
                ready = path && valid && std::isfinite(time.submit_us) && time.submit_us > 0.0 &&
                        std::isfinite(time.complete_us) && time.complete_us >= time.submit_us &&
                        std::isfinite(time.event_us) && time.event_us > 0.0;
                if (ready) {
                    submit.push_back(time.submit_us);
                    complete.push_back(time.complete_us);
                    event.push_back(time.event_us);
                }
            }
            if (ready)
                std::printf("layout=%s warmup=%d samples=%d chains=%d statistic=%s "
                            "host_submit_us=%.6f host_complete_us=%.6f event_span_us=%.6f %s\n",
                            layout, kWarmup, samples, kChains, bench ? "median" : "trace",
                            median(submit), median(complete), median(event),
                            bench ? "Timing PASS" : "Trace observation only");
        }
        if (!ready)
            std::puts("Timing NOT RUN/REJECTED: finish capture/instantiate and replay; pass correctness.");
        all_ok = ready && all_ok;
    }

    // 设备使用结束后先销毁可执行图及图，再释放捕获的地址，全部在计时外。
    CUDA_CHECK(cudaStreamSynchronize(stream));
    if (exec != nullptr) CUDA_CHECK(cudaGraphExecDestroy(exec));
    if (graph != nullptr) CUDA_CHECK(cudaGraphDestroy(graph));
    CUDA_CHECK(cudaEventDestroy(stop));
    CUDA_CHECK(cudaEventDestroy(start));
    CUDA_CHECK(cudaStreamDestroy(stream));
    CUDA_CHECK(cudaFree(b.output));
    CUDA_CHECK(cudaFree(b.tmp1));
    CUDA_CHECK(cudaFree(b.tmp0));
    CUDA_CHECK(cudaFree(b.input));
    std::printf("Experiment %s\n", all_ok ? "PASS" : "INCOMPLETE/FAIL");
    return all_ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
