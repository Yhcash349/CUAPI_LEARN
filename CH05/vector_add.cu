// Ch05 NSYS 实验：由 Ch02 vector add 复制，供本章独立编译、采集和复习。
// 讲义与命令：DOCS/chapters/05_nsys.md；观察 API、memcpy 与 kernel 三类轨迹。
#include <cuda_runtime.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <vector>

// Ch05：沿用前章错误检查，采集失败或计算失败时立即报告。
static void check_cuda(cudaError_t status, const char* api) {
    if (status != cudaSuccess) {
        std::fprintf(stderr, "%s failed: %s\n", api, cudaGetErrorString(status));
        std::exit(EXIT_FAILURE);
    }
}

// GPU 入口：输入长度为 n 的 a、b，输出 c；每个有效线程负责一个元素。
__global__ void vector_add(const float* a, const float* b, float* c, int n) {
    // 先跨过前面 block 的元素，再加上本 block 内的线程偏移。
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    // 最后一个 block 的多余线程跳过所有数组读写，避免访问 n 及之后的位置。
    if (i < n) {
        c[i] = a[i] + b[i];
    }
}

// CPU 入口：准备输入和参考结果，完成 H2D → kernel → D2H，并逐元素校验。
int main() {
    constexpr int n = 1000;
    constexpr int threads_per_block = 128;
    // 向上取整，保证最后不足一个 block 的数据也有线程负责。
    constexpr int blocks = (n + threads_per_block - 1) / threads_per_block;
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

    vector_add<<<blocks, threads_per_block>>>(d_a, d_b, d_c, n);
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
    for (int i : {0, 127, 128, 895, 896, 999}) {
        std::printf("i=%d: a=%g b=%g GPU=%g CPU=%g\n", i, h_a[i], h_b[i], h_c[i], reference[i]);
    }
    std::printf("N=%d dtype=float32 grid=%d block=%d launched=%d extra=%d tolerance=%g\n",
                n, blocks, threads_per_block, blocks * threads_per_block,
                blocks * threads_per_block - n, tolerance);
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
