#include <cuda.h>
#include <cuda_runtime.h>

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <stdexcept>
#include <vector>

namespace {

constexpr unsigned kBlock = 128;
constexpr uint32_t kFirstBias = 1000;
constexpr uint32_t kSecondBias = 2000;
constexpr int kUnsupported = 77;

bool driver_ok(CUresult status, const char* call) {
    if (status == CUDA_SUCCESS) {
        return true;
    }
    const char* name = nullptr;
    cuGetErrorName(status, &name);
    std::fprintf(stderr, "%s failed: %s (%d)\n", call, name ? name : "unknown", status);
    return false;
}

void check_driver(CUresult status, const char* call) {
    if (!driver_ok(status, call)) {
        throw std::runtime_error("Driver API call failed");
    }
}
#define CU_CHECK(call) check_driver((call), #call)

void check_runtime(cudaError_t status, const char* call) {
    if (status != cudaSuccess) {
        std::fprintf(stderr, "%s failed: %s\n", call, cudaGetErrorString(status));
        throw std::runtime_error("Runtime API call failed");
    }
}
#define CUDA_CHECK(call) check_runtime((call), #call)

struct Chunk {
    CUdeviceptr address = 0;
    CUmemGenericAllocationHandle handle{};
    bool created = false;
    bool mapped = false;
};

struct Window {
    CUdeviceptr base = 0;
    size_t chunk_bytes = 0;
    Chunk chunks[2];
};

// 一次申请产生一个物理分配句柄，目标虚拟地址已由调用者填入 chunk。
void create_backing(Chunk& chunk, size_t bytes, const CUmemAllocationProp& prop) {
    CU_CHECK(cuMemCreate(&chunk.handle, bytes, &prop, 0));
    chunk.created = true;
    std::printf("backing: bytes=%zu target_va=0x%llx\n",
                bytes, static_cast<unsigned long long>(chunk.address));
}

void map_chunk(Chunk& chunk, size_t bytes) {
    // 每段使用独立句柄，从该分配的第 0 字节开始映射。
    CU_CHECK(cuMemMap(chunk.address, bytes, 0, chunk.handle, 0));
    chunk.mapped = true;
}

void grant_access(CUdeviceptr address, size_t bytes, const CUmemAccessDesc& access) {
    // access 描述目标 GPU 及其权限，本例只传一份描述符。
    CU_CHECK(cuMemSetAccess(address, bytes, &access, 1));
}

// 查询同一地址在授权前后的权限，确认目标 GPU 可读写后再启动 kernel。
void make_writable(Chunk& chunk, size_t bytes, const CUmemAccessDesc& access) {
    map_chunk(chunk, bytes);
    unsigned long long before = 0;
    unsigned long long after = 0;
    CU_CHECK(cuMemGetAccess(&before, &access.location, chunk.address));
    grant_access(chunk.address, bytes, access);
    CU_CHECK(cuMemGetAccess(&after, &access.location, chunk.address));
    std::printf("access: va=0x%llx bytes=%zu before=0x%llx after=0x%llx\n",
                static_cast<unsigned long long>(chunk.address), bytes, before, after);
    if (after != CU_MEM_ACCESS_FLAGS_PROT_READWRITE) {
        throw std::runtime_error("mapped range is missing GPU read/write access");
    }
}

__global__ void fill_range(uint32_t* base, size_t begin, size_t end, uint32_t bias) {
    const size_t i = begin + static_cast<size_t>(blockIdx.x) * blockDim.x + threadIdx.x;
    if (i < end) {
        base[i] = static_cast<uint32_t>(i) + bias;
    }
}

// 两次 launch 都用同一个 base。begin/end 是元素索引，映射 API 使用字节。
void fill(CUdeviceptr base, size_t begin, size_t end, uint32_t bias) {
    const auto grid = static_cast<unsigned>((end - begin + kBlock - 1) / kBlock);
    fill_range<<<grid, kBlock>>>(reinterpret_cast<uint32_t*>(base), begin, end, bias);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());
}

bool verify(CUdeviceptr base, size_t first_count, size_t count, const char* stage) {
    std::vector<uint32_t> host(count);
    CU_CHECK(cuMemcpyDtoH(host.data(), base, count * sizeof(uint32_t)));
    size_t mismatches = 0;
    for (size_t i = 0; i < count; ++i) {
        const uint32_t expected = static_cast<uint32_t>(i) +
                                  (i < first_count ? kFirstBias : kSecondBias);
        if (host[i] != expected) {
            if (mismatches == 0) {
                std::printf("first mismatch: i=%zu got=%u expected=%u\n", i, host[i], expected);
            }
            ++mismatches;
        }
    }
    std::printf("%s: base=0x%llx checked=%zu mismatches=%zu boundary_left=%u",
                stage, static_cast<unsigned long long>(base), count, mismatches,
                host[first_count - 1]);
    if (count > first_count) {
        std::printf(" boundary_right=%u", host[first_count]);
    }
    std::putchar('\n');
    return mismatches == 0;
}

int run(Window& window, CUdevice device, bool probe_only) {
    CUmemAllocationProp prop{};
    prop.type = CU_MEM_ALLOCATION_TYPE_PINNED;
    prop.location = {CU_MEM_LOCATION_TYPE_DEVICE, device};
    CU_CHECK(cuMemGetAllocationGranularity(&window.chunk_bytes, &prop,
                                           CU_MEM_ALLOC_GRANULARITY_MINIMUM));
    const size_t bytes = window.chunk_bytes;
    CU_CHECK(cuMemAddressReserve(&window.base, 2 * bytes, bytes, 0, 0));
    Chunk& first = window.chunks[0];
    Chunk& second = window.chunks[1];
    first.address = window.base;
    second.address = window.base + bytes;
    std::printf("reserve: base=0x%llx bytes=%zu granularity=%zu\n",
                static_cast<unsigned long long>(window.base), 2 * bytes, bytes);

    create_backing(first, bytes, prop);
    if (probe_only) {
        std::puts("PROBE PASS: created one backing allocation, mapped_bytes=0");
        return 0;
    }
    const CUmemAccessDesc access{prop.location, CU_MEM_ACCESS_FLAGS_PROT_READWRITE};
    const size_t count = bytes / sizeof(uint32_t);
    make_writable(first, bytes, access);
    fill(window.base, 0, count, kFirstBias);
    if (!verify(window.base, count, count, "prefix")) {
        return 1;
    }

    // 保留第一段的映射与数据，只为原先空着的后半段接上第二块物理内存。
    create_backing(second, bytes, prop);
    make_writable(second, bytes, access);
    fill(window.base, count, 2 * count, kSecondBias);
    if (!verify(window.base, count, 2 * count, "grown")) {
        return 1;
    }
    std::puts("CHECK PASS: same base, original prefix and new suffix verified");
    return 0;
}

// GPU 使用已在 fill 内同步完成。按各次映射的原大小分别解除映射，再归还整段 VA。
bool release_window(const Window& window) {
    bool ok = true;
    for (const Chunk& chunk : window.chunks) {
        if (chunk.mapped) {
            ok = driver_ok(cuMemUnmap(chunk.address, window.chunk_bytes), "cuMemUnmap") && ok;
        }
        if (chunk.created) {
            ok = driver_ok(cuMemRelease(chunk.handle), "cuMemRelease") && ok;
        }
    }
    if (window.base != 0) {
        ok = driver_ok(cuMemAddressFree(window.base, 2 * window.chunk_bytes),
                       "cuMemAddressFree") && ok;
        if (ok) {
            std::puts("cleanup: backing handles released, VA reservation freed");
        }
    }
    return ok;
}

}  // namespace

int main(int argc, char** argv) {
    if (argc != 2 || (std::strcmp(argv[1], "probe") != 0 && std::strcmp(argv[1], "check") != 0)) {
        std::fprintf(stderr, "Usage: %s {probe|check}\n", argv[0]);
        return 2;
    }
    Window window{};
    int result = 1;
    try {
        CU_CHECK(cuInit(0));
        CUdevice device{};
        CU_CHECK(cuDeviceGet(&device, 0));
        int supported = 0;
        CU_CHECK(cuDeviceGetAttribute(&supported,
                    CU_DEVICE_ATTRIBUTE_VIRTUAL_MEMORY_MANAGEMENT_SUPPORTED, device));
        int driver_version = 0;
        int runtime_version = 0;
        CU_CHECK(cuDriverGetVersion(&driver_version));
        CUDA_CHECK(cudaRuntimeGetVersion(&runtime_version));
        std::printf("device=%d vmm_supported=%d driver_api=%d runtime=%d\n",
                    device, supported, driver_version, runtime_version);
        if (!supported) {
            std::puts("NOT RUN: VMM is unsupported on this device.");
            return kUnsupported;
        }
        // CUDA 12.9 中 cudaSetDevice 初始化并绑定 primary context，随后两套 API 共用它。
        CUDA_CHECK(cudaSetDevice(0));
        result = run(window, device, std::strcmp(argv[1], "probe") == 0);
    } catch (const std::exception& error) {
        std::fprintf(stderr, "CH22 failed: %s\n", error.what());
    }
    return release_window(window) ? result : 1;
}
