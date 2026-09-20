#include <cuda_runtime.h>

#include <cstdio>
#include <cstdlib>

// 骨架 helper：查询失败就报告 API、错误原因并退出，避免继续读取无效结果。
// 本章只需会使用它，错误处理机制到 Ch03 再学习。
static void check_cuda(cudaError_t status, const char* api) {
    if (status != cudaSuccess) {
        std::fprintf(stderr, "%s failed: %s\n", api, cudaGetErrorString(status));
        std::exit(EXIT_FAILURE);
    }
}

// CUDA 版本编码为 major * 1000 + minor * 10；不等同于驱动包版本号。
static void print_version(const char* label, int version) {
    std::printf("%s: %d.%d (raw=%d)\n", label,
                version / 1000, (version % 1000) / 10, version);
}

// 输入是 API 已填好的设备属性；读取实际硬件字段，不硬编码本机实测数字。
static bool print_student_properties(const cudaDeviceProp& prop) {
    const int sm_count = prop.multiProcessorCount;  // GPU 中 SM 的数量。
    const int warp_threads = prop.warpSize;         // 每个 warp 包含的线程数。

    if (sm_count <= 0 || warp_threads <= 0) {
        std::fputs("Invalid SM count or warp size.\n", stderr);
        return false;
    }
    std::printf("SM count: %d\n", sm_count);
    std::printf("Warp size: %d threads\n", warp_threads);
    return true;
}

// 入口：查询版本和所有可见设备，打印属性；本章不启动计算 kernel。
int main() {
    int runtime_version = 0;
    int driver_version = 0;
    check_cuda(cudaRuntimeGetVersion(&runtime_version), "cudaRuntimeGetVersion");
    check_cuda(cudaDriverGetVersion(&driver_version), "cudaDriverGetVersion");
    print_version("CUDA headers", CUDART_VERSION);
    print_version("CUDA Runtime version query", runtime_version);
    print_version("CUDA version supported by driver", driver_version);

    int device_count = 0;
    check_cuda(cudaGetDeviceCount(&device_count), "cudaGetDeviceCount");
    std::printf("Visible CUDA devices: %d\n", device_count);
    if (device_count == 0) {
        std::fputs("No visible CUDA device; check the driver and CUDA_VISIBLE_DEVICES.\n", stderr);
        return EXIT_FAILURE;
    }

    bool exercises_ready = true;
    for (int device = 0; device < device_count; ++device) {
        cudaDeviceProp prop{};
        check_cuda(cudaGetDeviceProperties(&prop, device), "cudaGetDeviceProperties");
        std::printf("\nDevice %d: %s\n", device, prop.name);
        std::printf("Compute capability: %d.%d\n", prop.major, prop.minor);
        std::printf("Global memory: %.2f GiB\n",
                    static_cast<double>(prop.totalGlobalMem) / (1024.0 * 1024.0 * 1024.0));
        const bool ready = print_student_properties(prop);
        exercises_ready = exercises_ready && ready;

        // 这些是资源上限，不是程序当前正在使用的数量，也不是建议的配置值。
        std::printf("Max threads per block: %d\n", prop.maxThreadsPerBlock);
        std::printf("Default shared memory per block: %.0f KiB\n",
                    static_cast<double>(prop.sharedMemPerBlock) / 1024.0);
    }

    std::puts("\nDevice query: OK");
    if (!exercises_ready) {
        return EXIT_FAILURE;
    }
    std::puts("Exercise values printed; explain the output to finish Ch00.");
    return EXIT_SUCCESS;
}
