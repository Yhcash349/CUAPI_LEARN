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
