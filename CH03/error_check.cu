#include <cuda_runtime.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

// CPU 检查入口：失败时打印调用、源码位置和错误名称，然后结束当前案例进程。
static void check_cuda(cudaError_t status, const char* api,
                       const char* file, int line) {
    if (status != cudaSuccess) {
        std::fprintf(stderr, "%s:%d: %s failed: %s (%s)\n",
                     file, line, api, cudaGetErrorName(status), cudaGetErrorString(status));
        std::exit(EXIT_FAILURE);
    }
}

// TODO(CH03-1)：把固定描述替换成宏参数 call 的源码文字；提示：预处理器的 #call。
// 当前宏仍会执行和检查 API，但报错不能显示具体调用。call 只应求值一次。
#define CUDA_CHECK(call) check_cuda((call), "TODO: CUDA expression", __FILE__, __LINE__)

// GPU 入口：复用 Ch01 的单 block 相加，oob 模式额外制造一次边界外写入。
__global__ void vector_add(const float* a, const float* b, float* c, int n, bool oob) {
    const int i = threadIdx.x;
    if (i < n) {
        c[i] = a[i] + b[i];
    }
    if (oob && i == 0) {
        // 故意错误：只分配 n 项，有效下标是 0 到 n-1。
        // TODO(CH03-3)：完成错误采集后，删除这条额外写入，再用 memcheck 验证修复。
        c[n] = 123.0f;
    }
}

// CPU 入口：准备输入和参考结果，完成 H2D → kernel → D2H，并逐元素校验。
int main(int argc, char** argv) {
    const char* mode = argc == 2 ? argv[1] : "ok";
    if (argc > 2 || (std::strcmp(mode, "ok") != 0 &&
                     std::strcmp(mode, "launch") != 0 && std::strcmp(mode, "oob") != 0)) {
        std::fprintf(stderr, "Usage: %s [ok|launch|oob]\n", argv[0]);
        return 2;
    }
    const bool bad_launch = std::strcmp(mode, "launch") == 0;
    const bool oob = std::strcmp(mode, "oob") == 0;
    constexpr int n = 256;
    constexpr size_t bytes = n * sizeof(float);
    constexpr float tolerance = 1e-6f;
    std::vector<float> h_a(n), h_b(n), h_c(n), reference(n);
    for (int i = 0; i < n; ++i) {
        h_a[i] = 0.5f * i;
        h_b[i] = 1.0f + 0.25f * (i % 7);
        reference[i] = h_a[i] + h_b[i];
    }

    float* d_a = nullptr;
    float* d_b = nullptr;
    float* d_c = nullptr;
    // h_ 表示 CPU 内存，d_ 表示 GPU 内存；分配大小的单位是字节。
    CUDA_CHECK(cudaMalloc(&d_a, bytes));
    CUDA_CHECK(cudaMalloc(&d_b, bytes));
    CUDA_CHECK(cudaMalloc(&d_c, bytes));
    CUDA_CHECK(cudaMemcpy(d_a, h_a.data(), bytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_b, h_b.data(), bytes, cudaMemcpyHostToDevice));
    // 预填非答案，漏写输出时也能被校验发现，不依赖未初始化显存。
    CUDA_CHECK(cudaMemset(d_c, 0, bytes));

    cudaDeviceProp prop{};
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    const int threads = bad_launch ? prop.maxThreadsPerBlock + 1 : n;
    std::printf("mode=%s N=%d dtype=float32 grid=1 block=%d maxThreadsPerBlock=%d\n",
                mode, n, threads, prop.maxThreadsPerBlock);
    std::fflush(stdout);
    vector_add<<<1, threads>>>(d_a, d_b, d_c, n, oob);
    // TODO(CH03-2)：将下面两条旧式检查改成 CUDA_CHECK(...)，保留各自检查的 API。
    check_cuda(cudaGetLastError(), "vector_add launch", __FILE__, __LINE__);
    std::puts("Launch check passed; this does not prove execution completed.");
    std::fflush(stdout);
    check_cuda(cudaDeviceSynchronize(), "vector_add execution", __FILE__, __LINE__);
    std::puts("Synchronization check passed; use memcheck to check allocation bounds.");
    CUDA_CHECK(cudaMemcpy(h_c.data(), d_c, bytes, cudaMemcpyDeviceToHost));

    int mismatches = 0;
    float max_abs_error = 0.0f;
    for (int i = 0; i < n; ++i) {
        const float error = std::fabs(h_c[i] - reference[i]);
        // 单独拒绝 NaN/Inf，避免 NaN 的比较行为造成假通过。
        if (!std::isfinite(h_c[i]) || error > tolerance) {
            if (mismatches < 4) {
                std::printf("Mismatch i=%d: got=%g expected=%g\n", i, h_c[i], reference[i]);
            }
            ++mismatches;
        }
        if (std::isfinite(h_c[i])) {
            max_abs_error = std::max(max_abs_error, error);
        } else {
            max_abs_error = INFINITY;
        }
    }
    for (int i = 0; i < 4; ++i) {
        std::printf("i=%d: a=%g b=%g GPU=%g CPU=%g\n", i, h_a[i], h_b[i], h_c[i], reference[i]);
    }
    std::printf("N=%d dtype=float32 grid=1 block=%d tolerance=%g\n", n, n, tolerance);
    std::printf("mismatches=%d max_abs_error=%g\n", mismatches, max_abs_error);

    CUDA_CHECK(cudaFree(d_c));
    CUDA_CHECK(cudaFree(d_b));
    CUDA_CHECK(cudaFree(d_a));
    if (mismatches != 0) {
        std::puts("FAIL: check vector_add and the reported values.");
        return EXIT_FAILURE;
    }
    std::puts("PASS: all elements match the CPU reference.");
    if (oob) {
        std::puts("OOB experiment: numeric PASS is not memory-safety evidence; inspect memcheck.");
    }
    return EXIT_SUCCESS;
}
