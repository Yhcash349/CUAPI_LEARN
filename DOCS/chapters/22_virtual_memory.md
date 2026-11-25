# Ch22 用 VMM 保持基地址并扩容

**45～60 分钟。** 承接 [Ch18 的 Driver context](18_driver_launch.md) 和 [Ch21 的内存生命周期](21_cross_stream_lifetime.md)。本章要回答一个问题：数组从一段长到两段时，能不能保留原来的指针和数据？

## 先预测再运行

设最小分配粒度为 `G` 字节，`B` 是预留地址区间的起点。先占住 `2G` 的地址位置，再按需接入显存。GPU 最初只能读写前半段，扩容时只给后半段接入新显存。

```text
                   B                   B + G                B + 2G
地址刚预留          | 未映射              | 未映射              |
第一段映射并授权     | 第 1 块显存，可读写   | 未映射              |
第二段映射并授权     | 第 1 块显存，可读写   | 第 2 块显存，可读写   |
```

先写下两个预测。仅执行映射，GPU 是否已经能写那段地址？扩容后如果 kernel 只写后半段，从原基地址一次回读整个数组，前半段会是什么结果？

## 沿源码读一遍

从 [vmm_grow.cu](../../CH22/vmm_grow.cu) 的 `main()` 进入 `run()`，再看 `make_writable()` 和 `release_window()`。`main()` 查询设备是否支持 VMM。CUDA 12.9 的 `cudaSetDevice(0)` 初始化并绑定该设备的 primary context，本章用 Driver API 管理映射和回读，用熟悉的 `<<<...>>>` 启动 kernel。[CUDA Runtime 设备管理](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-runtime-api/group__CUDART__DEVICE.html)

| 调用 | 在本章中做什么 |
| --- | --- |
| `cuMemGetAllocationGranularity` | 根据设备本地分配的属性查询最小粒度 `G` |
| `cuMemAddressReserve` | 预留 `2G` 字节虚拟地址，把起点写入 CPU 变量 `window.base` |
| `cuMemCreate` | 申请 `G` 字节设备内存，把物理分配的句柄写入 `chunk.handle` |
| `cuMemMap` | 在指定虚拟地址绑定这块设备内存。按本例的分配粒度对齐，句柄内部偏移为 0 |
| `cuMemSetAccess` | 给指定设备对这块映射设置读写权限。随后用 `cuMemGetAccess` 查询 |

以本机的 `G = 2 MiB` 为例，`uint32_t` 每项 4 字节，前半段有 `524288` 项。第一次 kernel 用 `base` 写索引 `0…524287`。扩容后的第二次 kernel 仍传 `base`，第一个线程改写 `base[524288]`，实际地址就是 `B + 2097152`。后半段从第二个句柄的第 0 字节开始。这里的连续性发生在虚拟地址上，两段显存分别由独立句柄表示。

两次 `fill()` 都等待 GPU 写完。第一次只回读前 `G` 字节。第二次只写新增段，随后 `verify()` 从同一个基地址回读 `2G` 字节并逐项比对，两段的数据规则分别是 `i + 1000` 和 `i + 2000`。完成回读后，`release_window()` 按各次映射的范围分别调用 `cuMemUnmap`，对各自的句柄调用 `cuMemRelease`，最后用 `cuMemAddressFree` 归还整个 `2G` 的地址预留。[CUDA Driver VMM 接口](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-driver-api/group__CUDA__VA.html)

## 编译与运行

从项目根目录运行。

```bash
bash CH22/compile.sh
./build/CH22/vmm_grow probe
./build/CH22/vmm_grow check
compute-sanitizer --tool memcheck --leak-check full --error-exitcode 99 \
    ./build/CH22/vmm_grow check
```

`probe` 成功时打印一块物理分配和 `mapped_bytes=0`，随后清理。`check` 执行两段映射和回读。VMM 属性为 0 时两个模式均报告 `NOT RUN` 并返回 77。

2026-11-25 按用户要求补全 `map_chunk()` 和 `grant_access()`。`cuMemMap` 将 `chunk.handle` 从分配内的偏移 0 开始映射到 `chunk.address`，成功才把 `chunk.mapped` 设为 `true`。第二段的目标地址是 `base + G`，它使用另一块显存，所以句柄内偏移仍为 0。`cuMemSetAccess` 给已映射的那段地址应用目标 GPU 的读写权限，`&access` 指向一份描述符，第四个参数为 1。`make_writable()` 查询授权前后的权限，确认可读写后才进入 kernel。[CUDA Driver VMM 接口](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-driver-api/group__CUDA__VA.html)

## 验收

核对两个映射目标相差 `G`，每段授权前后分别为 `0x0` 和 `0x3`。比较 `prefix` 与 `grown` 两行的 `base`，确认它们相同且逐项校验均为零偏差，并记录边界两侧的值和清理结果。最后用自己的话解释 `cuMemCreate` 返回什么、`cuMemMap` 将它接到哪里、为什么第二段仍从自己的句柄偏移 0 开始，以及退出时为什么先等 GPU 再解除映射。

**本机预检（2026-11-24）。** WSL2、GTX 1650 / SM75、驱动 610.88、Toolkit 12.9.86。正式骨架的 `probe` 通过，初始 `check` 按预期停在 TODO(1)。只补映射的隔离副本查询到 `0x0 → 0x0`，停在 TODO(2)。完整隔离副本查询到两段权限均为 `0x0 → 0x3`，扩容前校验 524,288 项，扩容后从原基地址校验 1,048,576 项，均零偏差。边界左值保持 525,287，右值为 526,288。Compute Sanitizer memcheck 报告零错误、零泄漏。本章验收使用权限和数据校验，计时、NSYS、NCU 均为 NOT RUN。[预检日志](../../reports/CH22/preflight-2026-11-24.txt)

**正式验证（2026-11-25）。** 本机 GTX 1650 上 `probe` 与 `check` 均通过。`check` 两段权限都是 `0x0 → 0x3`，`prefix` 和 `grown` 使用相同基地址，分别检查 524,288 和 1,048,576 项，均零偏差。两段交界处的元素分别是 525,287 和 526,288，前者与扩容前一致。清理成功，Compute Sanitizer memcheck 报告零错误、零泄漏。[正式验证日志](../../reports/CH22/completed-2026-11-25.txt)
