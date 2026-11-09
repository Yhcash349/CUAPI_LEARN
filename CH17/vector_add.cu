#include <cuda_runtime.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <vector>

static void check_cuda(cudaError_t status, const char* api, const char* file, int line) {
    if (status != cudaSuccess) {
        std::fprintf(stderr, "%s:%d: %s failed: %s (%s)\n", file, line, api,
                     cudaGetErrorName(status), cudaGetErrorString(status));
        std::exit(EXIT_FAILURE);
    }
}
#define CUDA_CHECK(call) check_cuda((call), #call, __FILE__, __LINE__)

// GPU 入口：a、b、c 各有 n 个 float；每个有效线程计算 c[i] = a[i] + b[i]。
// extern "C" 保留易查找的 vector_add 符号，供 PTX/cubin 观察及 Ch18 按名加载。
// 它不改变 kernel 在 GPU 执行的属性，也不把 kernel 变成普通 CPU 函数。
extern "C" __global__ void vector_add(const float* a, const float* b, float* c, int n) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) c[i] = a[i] + b[i];
}

// CPU 入口只用于 Runtime 校验；nvcc --ptx / --cubin 会丢弃 host 代码。
// 本章已知算法保持完整，练习在 compile.sh 的两个编译阶段，不新增计时实验。
int main() {
    constexpr int n = 1000;
    constexpr int block = 128;
    constexpr int grid = (n + block - 1) / block;
    constexpr size_t bytes = static_cast<size_t>(n) * sizeof(float);
    constexpr double tolerance = 1e-6;

    int device = 0, runtime = 0, driver = 0;
    cudaDeviceProp prop{};
    CUDA_CHECK(cudaGetDevice(&device));
    CUDA_CHECK(cudaGetDeviceProperties(&prop, device));
    CUDA_CHECK(cudaRuntimeGetVersion(&runtime));
    CUDA_CHECK(cudaDriverGetVersion(&driver));
    std::printf("GPU=%s CC=%d.%d SMs=%d Runtime=%d DriverAPI=%d\n",
                prop.name, prop.major, prop.minor, prop.multiProcessorCount, runtime, driver);
    std::printf("n=%d dtype=float32 grid=%d block=%d bytes_per_array=%zu\n",
                n, grid, block, bytes);

    std::vector<float> a(n), b(n), c(n);
    std::vector<double> reference(n);
    for (int i = 0; i < n; ++i) {
        a[i] = static_cast<float>(i % 101 - 50) / 8.0f;
        b[i] = static_cast<float>(i % 29 - 14) / 16.0f;
        reference[i] = static_cast<double>(a[i]) + static_cast<double>(b[i]);
    }

    float* d_a = nullptr;
    float* d_b = nullptr;
    float* d_c = nullptr;
    CUDA_CHECK(cudaMalloc(&d_a, bytes));
    CUDA_CHECK(cudaMalloc(&d_b, bytes));
    CUDA_CHECK(cudaMalloc(&d_c, bytes));
    CUDA_CHECK(cudaMemcpy(d_a, a.data(), bytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_b, b.data(), bytes, cudaMemcpyHostToDevice));
    // 按字节填 0xff，产生 NaN 哨兵；漏写输出也会被非有限值检查发现。
    CUDA_CHECK(cudaMemset(d_c, 0xff, bytes));
    vector_add<<<grid, block>>>(d_a, d_b, d_c, n);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());
    CUDA_CHECK(cudaMemcpy(c.data(), d_c, bytes, cudaMemcpyDeviceToHost));

    int mismatches = 0;
    double max_abs_error = 0.0;
    for (int i = 0; i < n; ++i) {
        const bool finite = std::isfinite(c[i]);
        const double error = std::abs(static_cast<double>(c[i]) - reference[i]);
        if (finite) max_abs_error = std::max(max_abs_error, error);
        if (!finite || error > tolerance) {
            if (mismatches < 5) {
                std::fprintf(stderr, "i=%d got=%g expected=%g\n", i, c[i], reference[i]);
            }
            ++mismatches;
        }
    }
    std::printf("checked=%d mismatches=%d max_abs_error=%.9g tolerance=%.1g\n",
                n, mismatches, max_abs_error, tolerance);
    std::printf("%s\n", mismatches == 0 ? "PASS" : "FAIL");

    CUDA_CHECK(cudaFree(d_c));
    CUDA_CHECK(cudaFree(d_b));
    CUDA_CHECK(cudaFree(d_a));
    return mismatches == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
