#include <cuda_runtime.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <vector>

// 复用 Ch00 的检查方式；Ch03 再学习错误分类与检查宏。
static void check_cuda(cudaError_t status, const char* api) {
    if (status != cudaSuccess) {
        std::fprintf(stderr, "%s failed: %s\n", api, cudaGetErrorString(status));
        std::exit(EXIT_FAILURE);
    }
}

// GPU 入口：输入 a、b，输出 c；固定一个 block，每个线程负责一个元素。
// 本章只启动 256 个线程处理 256 个元素，多 block 和边界保护留到 Ch02。
__global__ void vector_add(const float* a, const float* b, float* c) {
    const int i = threadIdx.x;
    // 每个线程读取自己负责的两项输入，将和写入对应输出位置。
    c[i] = a[i] + b[i];
}

// CPU 入口：准备输入和参考结果，完成 H2D → kernel → D2H，并逐元素校验。
int main() {
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
    check_cuda(cudaMalloc(&d_a, bytes), "cudaMalloc(d_a)");
    check_cuda(cudaMalloc(&d_b, bytes), "cudaMalloc(d_b)");
    check_cuda(cudaMalloc(&d_c, bytes), "cudaMalloc(d_c)");
    check_cuda(cudaMemcpy(d_a, h_a.data(), bytes, cudaMemcpyHostToDevice), "H2D a");
    check_cuda(cudaMemcpy(d_b, h_b.data(), bytes, cudaMemcpyHostToDevice), "H2D b");
    // 预填非答案，漏写输出时也能被校验发现，不依赖未初始化显存。
    check_cuda(cudaMemset(d_c, 0, bytes), "cudaMemset(d_c)");

    vector_add<<<1, n>>>(d_a, d_b, d_c);
    check_cuda(cudaGetLastError(), "vector_add launch");
    // 提交不等于完成；此处明确等待 GPU，异步细节到 Ch13 再展开。
    check_cuda(cudaDeviceSynchronize(), "vector_add execution");
    check_cuda(cudaMemcpy(h_c.data(), d_c, bytes, cudaMemcpyDeviceToHost), "D2H c");

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

    check_cuda(cudaFree(d_c), "cudaFree(d_c)");
    check_cuda(cudaFree(d_b), "cudaFree(d_b)");
    check_cuda(cudaFree(d_a), "cudaFree(d_a)");
    if (mismatches != 0) {
        std::puts("FAIL: check vector_add and the reported values.");
        return EXIT_FAILURE;
    }
    std::puts("PASS: all elements match the CPU reference.");
    return EXIT_SUCCESS;
}
