# 学习笔记

教学范围与章节顺序以 [PLAN.md](PLAN.md) 为准；任务进度和工作量（含实际学习状态与用时）仅在 [RECORD.md](RECORD.md) 更新。本文件服务于理解和复习，不记录编辑器、agent 配置或工程迁移流水。

## 学习背景与起点（2026-09-20）

学习目的是从小程序认识 CUDA 与 NVIDIA GPU 的执行、存储和调度，再为 Runtime/Driver 追踪及推理框架分析建立基础。用户明确希望每章最多约 1 小时，每个必要知识点都能指向代码或实验现象，不先背大量架构术语。

初始阶段只完成了课程讨论与 Codex 环境预检；后续已讲解 Ch00 并按用户要求提供完整代码，仍没有用户独立掌握的验收证据。后续解释从具体 shape、线程或一次数据流开始，先给直觉，再给术语，避免因为这里出现名词就跳过教学。

## 首轮贯穿的观察问题

| 观察问题 | 将使用的程序证据 |
| --- | --- |
| CPU 与 GPU 分别做了什么？ | vector add 的拷贝、launch、回读及 NSYS timeline |
| 为什么需要线程分组与合作？ | 索引覆盖、warp 分支、shared 交换、归约 |
| 为什么访问和复用方式会影响效率？ | 连续/跨步、shared padding、分块 GEMM 对照 |
| 为什么资源更多不一定更快？ | block shared 用量、驻留数量与实际计时 |
| 为什么提交完成不等于计算完成？ | CPU timer、Event、stream 依赖、Graph 对照 |
| 框架下方的执行链是什么？ | 同一 kernel 的源码、cubin、Runtime/Driver 启动和内存复用 |

这些是待学习的问题，不是已完成的学习成果。每节结束只保留实际讲解且用户接触过的核心内容；有解释但没有独立练习时如实注明。

## 后续记录规则

采用 `## YYYY-MM-DD ChXX：主题`，依次记录“今日完成任务、基本概念、踩坑记录、八股自测”。任务说明用户实际写了什么、使用了多少骨架或完整答案；基本概念联系代码，重要结论用 `<mark>...</mark>`；问题与误解只记录用户实际提出的内容，不编造学习经历。用户主动问题使用：

```html
<span style="color:red">用户提问：原问题或忠实摘要</span>
```

自测围绕本章一两个关键问题，不拓展为面试题库。实验数据引用 DOCS 中的章节记录与报告路径，不重复维护进度或工程日志。

## 2026-09-20 Ch00：设备查询程序

### 今日完成任务

<span style="color:red">用户提问：device_probe.cu 的作用和实现的功能。</span>

已讲解程序的执行顺序与辅助函数。用户随后要求直接完成作业，Codex 提供完整实现并编译运行；无用户独立代码修改或个人解释证据。运行数据见 [章节记录](chapters/00_environment.md)。

### 基本概念

<mark>程序在 CPU 上调用 CUDA API 查询设备属性，本章没有启动计算 kernel。</mark> `cudaGetDeviceProperties(&prop, device)` 把指定设备的信息填入 `prop`；返回值表示调用是否成功，输出参数承载查到的数据。`check_cuda` 检查返回值，失败时输出原因并退出。

`prop.multiProcessorCount` 是 SM 数量，`prop.warpSize` 是每个 warp 的线程数。SM 是安排线程执行的计算单元，warp 是共同执行指令的一组线程。总显存不等于当前空闲显存，资源上限不代表最佳配置。

<mark>GPU 计算能力、Toolkit 版本、驱动支持的 CUDA 版本是不同概念。</mark> `print_version` 把整数版本拆为主次版本；例如 12090 对应 12.9。程序末尾的提示只证明属性已输出，不能代替用户解释验收。

GPU 是计算硬件，Driver 让软件能够使用 GPU，Toolkit 提供 nvcc、头文件和库。程序流程是“查询版本 → 查询可见设备数量 → 逐个填充 cudaDeviceProp → 打印属性”。本次完整作业实测 GTX 1650、计算能力 7.5、4.00 GiB、14 个 SM、warp 32 线程；Toolkit 12.9 与驱动支持 CUDA 13.3 可以同时出现。数值引用章节验证记录，本次总结没有重新测量。

<span style="color:red">用户提问：修改后的 cu 文件如何编译，如何运行可执行文件？</span>

<mark>保存源码 → nvcc 编译 → 运行可执行文件；每次修改源码后都需重新编译。</mark> 在项目根目录执行：

```bash
mkdir -p build/CH00
nvcc -std=c++17 -arch=sm_75 CH00/device_probe.cu -o build/CH00/device_probe && ./build/CH00/device_probe
```

`-o` 指定输出文件，`-arch=sm_75` 指定本机课程目标架构，`&&` 确保编译成功后才运行，避免编译失败时误跑旧程序。

### 踩坑记录

未收到用户运行错误或具体误解；不据此推定已掌握。

### 八股自测

为什么这份 `.cu` 程序不需要自己写 GPU kernel？`cudaGetDeviceProperties` 的返回值与 `prop` 各承载什么信息？待用户自行解释。

## 2026-09-20 Ch01：第一个计算 kernel

### 今日完成任务

用户要求生成 Ch01 内容，随后明确要求“解题并编译”。Codex 提供并补全 [vector_add.cu](../CH01/vector_add.cu)，完成编译和运行，用户尚未提供独立实现或个人解释。程序对两个长度为 256 的 float32 数组逐元素相加，全部元素与 CPU reference 一致，最大绝对误差为 0。结果见 [章节记录](chapters/01_first_kernel.md)，本次总结不重复运行实验。

### 基本概念

<mark>本章的核心是 CPU 准备数据、GPU 执行计算、CPU 回读并验证结果。</mark> host 指 CPU 一侧，device 指 GPU 一侧。程序中的 `h_a/h_b/h_c` 保存 CPU 数据，`d_a/d_b/d_c` 指向 GPU 分配的空间；这些前缀是命名约定。完整流程为：

```text
CPU 准备输入与参考答案
  → cudaMalloc 分配 GPU 空间
  → cudaMemcpy（H2D）拷贝输入
  → 启动 vector_add kernel
  → cudaDeviceSynchronize 等待完成
  → cudaMemcpy（D2H）回读输出
  → CPU 逐元素校验
  → cudaFree 释放 GPU 空间
```

kernel 是交给 GPU 线程执行的函数。本程序的 `main()` 和普通循环在 CPU 上运行，`__global__` 标记的 `vector_add()` 在 GPU 上运行。启动代码 `vector_add<<<1, n>>>(d_a, d_b, d_c)` 使用一个 block、256 个线程；block 先理解成一组线程。传入的是 GPU 数组指针，与本程序显式分配和拷贝的方式对应。

```cpp
__global__ void vector_add(const float* a, const float* b, float* c) {
    const int i = threadIdx.x;
    c[i] = a[i] + b[i];
}
```

<mark>每个线程执行同一段代码，通过不同的编号处理不同元素。</mark> `threadIdx.x` 是线程在当前 block 内的 x 方向编号，本章为 0～255。线程 3 计算 `a[3] + b[3] = 1.5 + 1.75`，写入 `c[3] = 3.25`。无需在 kernel 中写一个遍历全部元素的循环；也不能由此推定 256 个线程物理上同时执行。

当前索引只适用于本章固定的一个 block、256 个元素与 256 个线程配置。多个 block 的索引及越界保护留到 Ch02，不直接增大启动规模套用这份代码。

`cudaMalloc` 和 `cudaMemcpy` 的大小参数以字节计，256 个 float 对应 1024 字节。`cudaMemcpy` 的参数顺序为目标、来源、字节数、方向。本程序通过 `cudaDeviceSynchronize` 显式等待计算结束，再回读结果；提交 kernel 不等于计算已经完成，详细异步机制留到后续。

<mark>运行不报错还不够，要把 GPU 结果与 CPU 参考答案逐元素比较。</mark> 本程序检查全部 256 项，前四项打印仅用于观察，容限为 `1e-6`，NaN/Inf 也判失败。此次 PASS 证明当前输入的计算正确；没有计时，不能据此判断 GPU 比 CPU 快。

修改源码后需重新编译。在项目根目录执行：

```bash
mkdir -p build/CH01
nvcc -std=c++17 -arch=sm_75 -Xcompiler=-Wall,-Wextra CH01/vector_add.cu -o build/CH01/vector_add && ./build/CH01/vector_add
```

### 踩坑记录

未收到用户运行错误或具体误解。教学预检中的原始骨架把输出写为零，因此校验 FAIL，是预设的未完成练习状态；随后补全计算后 PASS，不属于环境故障，也不记为用户犯错。

### 八股自测

从 CPU 准备输入到 CPU 验证输出，数据经过哪些步骤，哪个函数在 GPU 上执行？同一段 kernel 代码如何让线程 3 与线程 4 分别处理不同元素？待用户用自己的话解释。
