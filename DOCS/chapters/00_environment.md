# Ch00：环境与设备查询

目标：编译运行一个设备查询程序，分清 GPU、Driver、Toolkit，认识设备属性与资源上限。无需旧章，计划 45～60 分钟。源码为 [device_probe.cu](../../CH00/device_probe.cu)，学习进度统一在 [RECORD](../RECORD.md)。

## 先认识程序在做什么

GPU 是计算硬件；Driver 是程序使用 GPU 所需的驱动；Toolkit 是包含 `nvcc`、头文件和库的开发工具包。Runtime 是程序调用的 CUDA 运行时接口。本程序在 CPU 上调用查询 API，读取 GPU 属性，不启动计算 kernel。

SM 可以先理解成 GPU 内安排线程执行的计算单元；warp 是共同执行指令的一组线程。本章只认识数量与含义。计算能力（如 7.5）描述硬件功能等级，与 Toolkit 版本分开看。block 是程序组织的一组线程，共享内存是这组线程可协作使用的存储；本章只看上限，具体使用留到后续。

## 预测、编译与练习

运行前先预测：驱动支持的 CUDA 版本会与 `nvcc` 版本相同吗？查询设备属性需要自己写 GPU kernel 吗？写下猜测即可。

在项目根目录执行：

```bash
nvcc --version
nvidia-smi
mkdir -p build/CH00
nvcc -std=c++17 -arch=sm_75 -Xcompiler=-Wall,-Wextra CH00/device_probe.cu -o build/CH00/device_probe
./build/CH00/device_probe
```

`nvcc` 把源码编译为可执行程序；`-arch=sm_75` 沿用本机课程目标，本程序尚无 GPU kernel。`build/` 保存本地产物，不提交 Git。

原始骨架以两处 TODO 练习属性读取。用户随后要求直接完成作业，当前源码已由 Codex 补全，运行会显示 SM 数量与 warp 大小。退出码为 0 表示程序检查通过，不代表用户已掌握。

当前 `print_student_properties()` 通过 `prop.multiProcessorCount` 和 `prop.warpSize` 读取 SM 数量与 warp 线程数，没有硬编码 14 或 32。可对照本机头文件 `/usr/local/cuda-12.9/include/driver_types.h` 的 `cudaDeviceProp` 定义复习，再编译运行观察输出；不做性能对照。

`check_cuda` 已提供：查询失败时打印原因并退出。本章会调用即可，不要求实现错误处理框架。

## 怎样读结果

`CUDA headers` 是编译时头文件版本。CUDA 12.9 下，`cudaRuntimeGetVersion` 返回编译期的 Toolkit 版本常量，不能用它判断系统里所有 CUDA 库的版本。`cudaDriverGetVersion` 查询驱动支持的 CUDA 版本，和 `nvidia-smi` 的驱动包版本号（如 610.88）不是同一编号。

显存输出使用 GiB，表示设备属性中的总量，不是当前空闲显存。最大 block 线程数、默认每 block shared memory 都是资源上限，不代表当前占用或最佳配置。

完成时应能指出查询属性的 API，解释 SM 数量与 warp 大小分别数的是什么，并说明为什么 Driver 支持版本和 Toolkit 版本可以不同。本次完整代码由 Codex 提供，已有程序验证；待用户解释后评估本章 DONE，辅助程度始终记为完整答案。

## 官方资料与核对依据

查阅 CUDA Runtime API 12.9 的 [Device Management](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART__DEVICE.html) 与 [Version Management](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART____VERSION.html)，按函数名定位即可。本次也核对本机 Toolkit 12.9 的 `cuda_runtime_api.h` 和 `driver_types.h`；网页归档展示版本可能不一致，签名与本机行为以对应安装头文件和实际运行共同核实。

与后续推理分析的连接：记录清楚硬件和工具版本，是解释同一程序在不同环境中表现差异的起点。

## 预检结果

2026-09-20，Codex 使用上述命令编译，无编译警告；正式骨架退出 0，查询成功并明确显示练习 TODO。实测：NVCC 12.9.86，headers/Runtime 查询 12.9，Driver 支持 CUDA 13.3，驱动包 610.88；可见 GPU 1 块，NVIDIA GeForce GTX 1650，计算能力 7.5，总显存 4.00 GiB，最大 block 线程数 1024，默认每 block shared memory 48 KiB。

另在临时副本填写两处 TODO 后编译运行，通过断言核对 SM 数量 14、warp 大小 32；副本随后清理，正式源码保留练习。以 `CUDA_VISIBLE_DEVICES= ./build/CH00/device_probe` 验证无设备情况，打印 `cudaGetDeviceCount failed: no CUDA-capable device is detected` 并退出 1，符合预期。

这些是 Codex 骨架预检，不是用户完成证据。正式二进制在 `build/CH00/device_probe`；无 profiler 报告，输入 shape/dtype、误差、GPU 计时均不适用：本章只查询属性。用户实际运行与解释待验收。

## 完整作业验证（2026-09-20）

按用户要求补全正式源码后，使用上方命令重新编译运行，无警告，退出 0。正式输出新增 `SM count: 14`、`Warp size: 32 threads`，其余属性与上述预检一致。代码与验证由 Codex 完成，用户解释待验收。前述“源码保留练习”仅描述早期骨架状态。
