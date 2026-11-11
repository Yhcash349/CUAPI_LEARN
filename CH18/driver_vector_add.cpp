#include <cuda.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <vector>
#include <unistd.h>

// Driver API 返回 CUresult；和此前的 cudaError_t / CUDA_CHECK 分开处理。
static void check_driver(CUresult status, const char* api, const char* file, int line) {
    if (status != CUDA_SUCCESS) {
        const char* name = "unknown";
        const char* message = "unknown";
        cuGetErrorName(status, &name);
        cuGetErrorString(status, &message);
        std::fprintf(stderr, "%s:%d: %s failed: %s (%s)\n", file, line, api,
                     name ? name : "unknown", message ? message : "unknown");
        std::exit(EXIT_FAILURE);
    }
}
#define CU_CHECK(call) check_driver((call), #call, __FILE__, __LINE__)

// 只读教学探针：打印句柄值，并通过公开 API 查询当前线程的绑定和 primary 状态。
// CUcontext 是不透明句柄，不能解引用查看驱动内部结构；active 也不表示 GPU 正在计算。
static void print_context_probe(const char* stage, CUdevice device,
                                CUcontext previous, CUcontext context) {
    CUcontext current = nullptr;
    unsigned primary_flags = 0;
    int primary_active = 0;
    CU_CHECK(cuCtxGetCurrent(&current));
    CU_CHECK(cuDevicePrimaryCtxGetState(device, &primary_flags, &primary_active));
    std::printf("[ctx-probe:%s] cpu_tid=%ld previous=%p context=%p current=%p "
                "primary_active=%d primary_flags=0x%x\n",
                stage, static_cast<long>(gettid()), static_cast<void*>(previous),
                static_cast<void*>(context), static_cast<void*>(current),
                primary_active, primary_flags);
    if (current) {
        CUdevice current_device = 0;
        unsigned current_flags = 0;
        CU_CHECK(cuCtxGetDevice(&current_device));
        CU_CHECK(cuCtxGetFlags(&current_flags));
        std::printf("  current_device=%d current_flags=0x%x\n", current_device, current_flags);
    } else {
        std::printf("  current_device=<none> current_flags=<none>\n");
    }
}

// 输入为外部 cubin 路径；输出 module 及其中名为 vector_add 的入口句柄。
// 两次 API 调用均成功后返回 true；失败由 CU_CHECK 报错并退出。
static bool load_vector_add(const char* path, CUmodule* module, CUfunction* function) {
    CU_CHECK(cuModuleLoad(module, path));
    // module 指向输出变量；*module 才是加载后得到的模块句柄。
    CU_CHECK(cuModuleGetFunction(function, *module, "vector_add"));
    return true;
}

// 输入是 device 地址值与 n；按 kernel 的 a/b/c/n 顺序传参，提交单次启动。
// 本函数只提交工作，完成等待统一留在 main 的 cuCtxSynchronize。
static bool launch_vector_add(CUfunction function, CUdeviceptr d_a, CUdeviceptr d_b,
                              CUdeviceptr d_c, int n, unsigned grid, unsigned block) {
    // Driver 从这些 host 变量中复制参数值；kernel 收到的前三项仍是 GPU 地址。
    void* args[] = {&d_a, &d_b, &d_c, &n};
    CU_CHECK(cuLaunchKernel(function, grid, 1, 1, block, 1, 1,
                            0, nullptr, args, nullptr));
    return true;
}

// 独立 host 程序：不包含 __global__ 定义或 Runtime API；GPU 程序来自 Ch17 cubin。
// 用法：./build/CH18/driver_vector_add [cubin_path]，相对路径以调用时目录为准。
int main(int argc, char** argv) {
    if (argc > 2) {
        std::fprintf(stderr, "Usage: %s [cubin_path]\n", argv[0]);
        return 2;
    }
    const char* path = argc == 2 ? argv[1] : "build/CH17/vector_add.cubin";
    constexpr int n = 1000;
    constexpr unsigned block = 128;
    constexpr unsigned grid = (n + block - 1) / block;
    constexpr size_t bytes = static_cast<size_t>(n) * sizeof(float);
    constexpr double tolerance = 1e-6;

    CU_CHECK(cuInit(0));
    CUdevice device = 0;
    CU_CHECK(cuDeviceGet(&device, 0));
    char name[256]{};
    int major = 0, minor = 0, sms = 0, driver = 0;
    CU_CHECK(cuDeviceGetName(name, sizeof(name), device));
    CU_CHECK(cuDeviceGetAttribute(&major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, device));
    CU_CHECK(cuDeviceGetAttribute(&minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, device));
    CU_CHECK(cuDeviceGetAttribute(&sms, CU_DEVICE_ATTRIBUTE_MULTIPROCESSOR_COUNT, device));
    CU_CHECK(cuDriverGetVersion(&driver));
    std::printf("GPU=%s CC=%d.%d SMs=%d DriverAPI=%d\n", name, major, minor, sms, driver);
    std::printf("module=%s entry=vector_add n=%d dtype=float32 grid=%u block=%u bytes_per_array=%zu\n",
                path, n, grid, block, bytes);

    // retain 保持本进程对 primary context 的使用；它不会自动设为当前线程的 context。
    // 保存并恢复此前的 current context，不调用 reset/destroy 破坏共享的 primary context。
    CUcontext previous = nullptr, context = nullptr;
    // &previous / &context 是 main 中两个 host 变量的地址；其内容是可变的句柄值。
    std::printf("[ctx-probe:variables] &previous=%p &context=%p sizeof(CUcontext)=%zu\n",
                static_cast<void*>(&previous), static_cast<void*>(&context), sizeof(CUcontext));
    print_context_probe("before_get", device, previous, context);
    CU_CHECK(cuCtxGetCurrent(&previous));
    print_context_probe("after_get", device, previous, context);
    CU_CHECK(cuDevicePrimaryCtxRetain(&context, device));
    print_context_probe("after_retain", device, previous, context);
    CU_CHECK(cuCtxSetCurrent(context));
    print_context_probe("after_set", device, previous, context);
    CUmodule module = nullptr;
    CUfunction function = nullptr;
    if (!load_vector_add(path, &module, &function)) {
        if (module) CU_CHECK(cuModuleUnload(module));
        CU_CHECK(cuCtxSetCurrent(previous));
        CU_CHECK(cuDevicePrimaryCtxRelease(device));
        return 2;
    }
    std::printf("module loaded; function found\n");

    // 保持与 Ch17 相同输入；double reference 和 NaN 哨兵同时发现错算与漏写。
    std::vector<float> a(n), b(n), c(n);
    std::vector<double> reference(n);
    for (int i = 0; i < n; ++i) {
        a[i] = static_cast<float>(i % 101 - 50) / 8.0f;
        b[i] = static_cast<float>(i % 29 - 14) / 16.0f;
        reference[i] = static_cast<double>(a[i]) + static_cast<double>(b[i]);
    }
    CUdeviceptr d_a = 0, d_b = 0, d_c = 0;
    CU_CHECK(cuMemAlloc(&d_a, bytes));
    CU_CHECK(cuMemAlloc(&d_b, bytes));
    CU_CHECK(cuMemAlloc(&d_c, bytes));
    CU_CHECK(cuMemcpyHtoD(d_a, a.data(), bytes));
    CU_CHECK(cuMemcpyHtoD(d_b, b.data(), bytes));
    CU_CHECK(cuMemsetD8(d_c, 0xff, bytes));

    const bool launched = launch_vector_add(function, d_a, d_b, d_c, n, grid, block);
    int mismatches = 0;
    if (launched) {
        // launch 返回只说明提交情况；等待完成后才能据回读结果作验收。
        CU_CHECK(cuCtxSynchronize());
        CU_CHECK(cuMemcpyDtoH(c.data(), d_c, bytes));
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
    }

    // 完成校验后释放本程序拥有的资源，再恢复此前的 current context。
    CU_CHECK(cuMemFree(d_c));
    CU_CHECK(cuMemFree(d_b));
    CU_CHECK(cuMemFree(d_a));
    CU_CHECK(cuModuleUnload(module));
    CU_CHECK(cuCtxSetCurrent(previous));
    print_context_probe("after_restore", device, previous, context);
    CU_CHECK(cuDevicePrimaryCtxRelease(device));
    // release 不会改写这个局部变量；主动清空，避免保留可能已经失效的句柄。
    context = nullptr;
    print_context_probe("after_release", device, previous, context);
    if (!launched) return 2;
    return mismatches == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
