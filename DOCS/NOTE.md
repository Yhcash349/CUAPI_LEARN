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

## 2026-09-21 Ch02：线程索引与越界保护

### 今日完成任务

用户要求生成本章并随后要求“完成今日作业”，Codex 补全 [thread_index.cu](../CH02/thread_index.cu) 的全局索引和边界判断，完成编译、数值校验与内存检查。使用 8 个 block、每 block 128 个线程，对 1000 项 float32 输入逐元素相加。正式程序全部通过，最大绝对误差 0，memcheck 零错误；证据见 [章节记录](chapters/02_thread_index.md) 与 `reports/CH02/completed.txt`。本次总结引用已有结果，没有重新运行；尚无用户独立实现或个人解释证据。

### 基本概念

<mark>本章解决两个问题：每个线程负责哪一项，以及多出的线程如何避免越界。</mark> Ch01 只有一个 block，组内编号即可对应数组索引；Ch02 有多个 block，每组的线程编号都会从零开始，所以还需加上该组在整个数组中的起点。

block 是一组线程，grid 是一次启动中的全部 block。`vector_add<<<8, 128>>>(...)` 表示启动 8 组、每组 128 个线程；这不表示 1024 个线程物理上同时执行，也不表示组号就是 SM 编号。

| 标识 | 直觉含义 | 本章取值 |
| --- | --- | --- |
| `blockIdx.x` | 当前组号 | 0～7 |
| `blockDim.x` | 每组线程数 | 128 |
| `threadIdx.x` | 当前线程的组内编号 | 0～127 |

<mark>全局索引 = 组号 × 每组线程数 + 组内编号。</mark> 核心代码为：

```cpp
const int i = blockIdx.x * blockDim.x + threadIdx.x;
if (i < n) {
    c[i] = a[i] + b[i];
}
```

例如 block 1 的线程 3 处理 `1 * 128 + 3 = 131` 号元素。只写 `threadIdx.x` 会让每组都访问前 128 项，产生重复写入，其余元素没有线程负责。

host 使用 `(n + threads_per_block - 1) / threads_per_block` 向上取整计算组数。本章 `1000 / 128` 的整数结果是 7，但 7 组只能覆盖 896 项，所以要启动 8 组，共 1024 个线程。最后一组覆盖索引 896～1023，其中 896～999 是 104 个有效元素，1000～1023 对应 24 个多余线程。

<mark>保护条件必须放在所有数组读取和写入之前。</mark> block 7 的线程 103 得到索引 999，可以执行加法；线程 104 得到索引 1000，不满足 `i < n`，跳过整个加法语句。不能先读取 `a[i]` 再判断，也不能把“不崩溃”当作没有越界的证明。

CPU 准备输入、H2D 拷贝、启动 kernel、等待、D2H 回读与全量校验沿用 Ch01。本次通过证明当前输入的正确性，没有计时，不能据此比较 CPU/GPU 速度。修改源码后仍需重新编译：

```bash
mkdir -p build/CH02
nvcc -std=c++17 -arch=sm_75 -lineinfo -Xcompiler=-Wall,-Wextra CH02/thread_index.cu -o build/CH02/thread_index && ./build/CH02/thread_index
```

### 追问复盘（2026-09-22 整理）

<span style="color:red">用户提问：所有 blocks 是同时启动的吗？</span>

<mark>一次 kernel 调用提交整个 grid，但不保证所有 block 同时开始执行，也不保证按组号执行。</mark> SM 是 GPU 上执行线程组的计算单元；GPU 根据可用资源安排 block，一个 SM 在资源允许时可以容纳多个 block，未能驻留的 block 等待资源。block 编号不是 SM 编号。本章各线程独立处理自己的元素，不依赖 block 的执行先后。未采集本章 block 调度证据，不能根据启动配置、SM 数量或 PASS 推断实际同时开始。

<span style="color:red">用户提问：为什么只用 threadIdx.x 不够？为什么需要 8 组，却只有 1000 个线程执行加法？</span>

每组的 `threadIdx.x` 都是 0～127，单独使用它会让 8 组重复访问前 128 项；加上 `blockIdx.x * blockDim.x` 才能区分各组负责的区间。7 组只有 896 个线程，覆盖不足，故向上取整到 8 组。<mark>1024 个线程都被启动；从源码逻辑看，它们计算索引并判断条件，只有 1000 个有效线程执行数组相加。</mark> 其余 24 个线程跳过加法和数组访问，不是没有启动。这里解释的是程序逻辑，未检查编译后的机器指令。

### 踩坑记录

用户已就 block 是否同时启动及索引、尾部线程行为提问，已作上述解释；尚无用户自行复述，不据此认定掌握。未收到用户实际运行错误。初始骨架的 `i = n` 和 `if (false)` 刻意跳过计算，数值 FAIL 是预设的未完成状态；完整实现已通过验证，不记为用户犯错。

### 八股自测

为什么多个 block 时只使用 `threadIdx.x` 不够？N=1000、每 block 128 线程时，为什么需要 8 个 block，最后一组哪些线程应跳过数组访问？待用户自行解释。

## 2026-09-22 Ch03：CUDA 错误检查与 Sanitizer 定位

### 今日完成任务

围绕 [error_check.cu](../CH03/error_check.cu) 阅读 host 检查与三种实验模式。用户在 Codex 讲解和代码示例辅助下修改检查宏及两处检查点，并贴出非法启动、memcheck 越界的终端输出。现场源码已使用 `#call` 和两处 `CUDA_CHECK`，故意越界写入仍保留；尚无修复后用户运行结果或个人复述，不记为完全独立实现。实验依据及待办见 [RECORD](RECORD.md) 的同日 Ch03 条目。

### 基本概念

<span style="color:red">用户提问：为什么 include 这些头文件？check_cuda 如何实现？call 到底怎么理解？</span>

`#include` 引入函数和类型等声明或定义。`cuda_runtime.h` 提供 CUDA 接口；`algorithm` 用于 `std::max`；`cmath` 用于绝对误差和有限值检查；`cstdio` 用于打印与刷新输出；`cstdlib` 用于退出程序；`cstring` 用于比较模式字符串；`vector` 保存 CPU 端数组。

`check_cuda` 在 CPU 上检查传入的 `cudaError_t`：成功则返回，失败则打印调用、文件、行号和错误文字，随后 `std::exit(EXIT_FAILURE)` 结束程序。它不会自动等待 GPU，能检查什么由传入 API 的返回值决定。

```cpp
#define CUDA_CHECK(call) check_cuda((call), #call, __FILE__, __LINE__)
```

<mark>`call` 是宏参数名，代表传入的代码；`(call)` 执行该调用，`#call` 将同一段代码转换为报错用的字符串。</mark> 例如传入 `cudaMalloc(&d_a, bytes)`，实际调用只求值一次，字符串不执行。`__FILE__` 和 `__LINE__` 标记宏调用位置。`cudaGetErrorName(status)` 将状态码转为名称，`cudaGetErrorString(status)` 给出英文说明，最终由 `fprintf` 拼接打印。

<span style="color:red">用户提问：模式选择、设备属性查询和结果输出各在做什么？</span>

`argc` 包含程序名，`argv[1]` 是用户传入的模式；不传时默认 `ok`，`strcmp` 返回 0 表示相等。`ok` 用 256 个线程处理 256 项；`launch` 将 block 线程数设为设备上限加 1；`oob` 在正常计算之外额外写 `c[n]`。`fflush(stdout)` 刷新 CPU 输出，不等待 GPU。程序校验全部 256 项，前四项打印仅便于观察，末尾 `cudaFree` 释放 GPU 数组。

<mark>启动检查通过不代表执行完成；数值校验通过也不代表没有越界。</mark> `cudaGetLastError()` 读取并清除当前 host 线程对应 Runtime 的最后错误记录，不等待 GPU，且可能报告之前异步调用的错误；`cudaDeviceSynchronize()` 等待 GPU 并检查返回值。报错所在 API 是发现错误的检查点，未必是故障源头。参考 [CUDA Runtime API 12.9：Error Handling](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART__ERROR.html)。

<span style="color:red">用户提问：Compute Sanitizer 做什么，命令参数是什么意思，与 nsys 有什么区别，还有哪些工具？</span>

```bash
compute-sanitizer --tool memcheck --padding 32 --error-exitcode 99 ./build/CH03/error_check oob
```

该命令在工具监测下运行程序的 `oob` 模式。`--tool memcheck` 选择内存检查；`--padding 32` 为分配添加 32 字节保护间隔，这些字节不属于程序可合法使用的空间；`--error-exitcode 99` 让应用成功退出但工具发现错误的情况也以非零码返回。`99` 是此命令指定的退出码，不是报告中 CUDA 错误码 `999`。

| 工具 | 本轮需要知道的检查范围 |
| --- | --- |
| `memcheck` | 越界、未对齐访问等；泄漏检查需按选项启用 |
| `racecheck` | shared memory 数据访问冲突，不是通用 global memory 竞争检测器 |
| `initcheck` | GPU global memory 未初始化读取 |
| `synccheck` | 同步原语的非法使用 |

一次 `--tool` 选择一种检查，不会自动运行全部工具。<mark>Compute Sanitizer 查执行正确性，Nsight Systems 查时间花在哪里以及 CPU/GPU 如何配合。</mark> nsys 可观察 API、kernel、拷贝时间线与重叠，不能替代逐次访存合法性检查；Sanitizer 有运行开销，不用其运行耗时衡量性能。零错误仅覆盖本次执行和所选工具的检查范围，算法结果仍需 reference 校验。工具边界参考 [Compute Sanitizer](https://docs.nvidia.com/compute-sanitizer/ComputeSanitizer/index.html) 与 [Nsight Systems](https://docs.nvidia.com/nsight-systems/UserGuide/index.html)，本日未实际运行其余三种检查或 nsys。

### 踩坑记录

<span style="color:red">用户提问：cudaErrorInvalidConfiguration 从哪里来？越界报告如何帮助定位？</span>

用户贴出的 `launch` 输出为 block=1025、设备上限=1024。非法配置导致 Runtime 记录错误，`cudaGetLastError()` 取出状态码，检查函数打印 `cudaErrorInvalidConfiguration (invalid configuration argument)`；不是第 77 行检查函数自己制造了错误。

用户贴出的 memcheck 报告指向 `error_check.cu:33`、block 0 的线程 0、4 字节 global 写入，对应 `c[256] = 123.0f`。数组只有 256 个 float，共 1024 字节，合法下标为 0～255。访问地址 `0x603401000` 正好等于起点 `0x603400c00 + 0x400`；“1 bytes after”指访问起点位于最后合法字节之后，不代表只写了 1 字节。

后续 `cudaDeviceSynchronize()` 报 `cudaErrorUnknown (999)`，此次 `ERROR SUMMARY: 2 errors` 对应非法写入及随后 API 报错，不证明有两处独立越界。<mark>先读第一条具体错误，再找源码行、线程和地址范围；修复根因后重新编译、重新检查。</mark> 这是预设故障实验，不记为用户无意写错，也不能将本次错误名称推广为所有越界的固定返回值。

### 八股自测

`CUDA_CHECK(cudaMalloc(...))` 中调用文字、实际返回值和源码位置分别从哪里来？为什么 launch 检查通过后，memcheck 仍能报告越界，且同步处可能再次报错？待用户用自己的话解释。

## 2026-10-08 Ch05：NSYS 采集与 CPU/GPU 时间线

### 今日完成任务

使用独立的 [CH05/vector_add.cu](../CH05/vector_add.cu)，固定 N=1000、float32、grid=8、block=128。源码由 Codex 从 Ch02 复制并提供，本章用户练习为采集、读图与源码对应，没有新增 kernel 实现要求。

用户生成 `user_20261008_01.nsys-rep` 和 `user_20261008_02.nsys-rep`，在 Windows Nsight Systems 2026.4.1 中打开新版报告、展开 CPU/GPU 轨道、显示 Events View、放大时间轴并提供截图。Codex 检查用户 `_02` 报告，验证 1 次 vector_add、2 次 H2D、1 次 D2H 和 1 次 memset，辅助解释启动名称、拷贝方向和时间边界。证据为 [用户报告](../reports/CH05/user_20261008_02.nsys-rep) 与 [同名 SQLite](../reports/CH05/user_20261008_02.sqlite)，工程验证与剩余验收见 [RECORD](RECORD.md)。用户已实际采集和操作 GUI；主动提问与接受讲解不等于独立解释验收。

### 基本概念

<mark>NSYS 把 CPU 的接口调用与 GPU 的计算、数据搬运放在同一时间轴上，帮助对应源码与实际活动。</mark> 本程序的数据流为：

```text
CPU 准备输入和参考答案 → 分配 GPU 数组
  → H2D(a) → H2D(b) → memset(c) → vector_add
  → 等待 GPU 完成 → D2H(c) → CPU 校验 → 释放
```

<span style="color:red">用户提问：这两个编译与采集指令分别是什么意思？</span>

保存源码后重新编译，在根目录执行；先普通运行确认 PASS，再采集。本次使用的命令如下，重复采集时更换报告前缀，保留原证据：

```bash
mkdir -p build/CH05 reports/CH05
nvcc -std=c++17 -O2 -arch=sm_75 -lineinfo \
  -Xcompiler=-Wall,-Wextra CH05/vector_add.cu -o build/CH05/vector_add \
  && ./build/CH05/vector_add

/home/yhc23/.local/bin/nsys profile \
  --trace=cuda --sample=none --cpuctxsw=none \
  -o reports/CH05/user_20261008_02 ./build/CH05/vector_add
```

`nvcc` 编译 CUDA C++；`-std=c++17` 指定语言标准，`-O2` 开启优化，`-arch=sm_75` 指定课程目标 GPU 架构，`-lineinfo` 保留源码行号，`-Xcompiler=-Wall,-Wextra` 开启 host 编译警告，`-o` 指定二进制路径，`&&` 保证编译成功才运行。行末单个 `\` 表示续行。

`nsys profile` 在工具监测下启动程序；`--trace=cuda` 记录 CUDA API 与 GPU 活动，`--sample=none`、`--cpuctxsw=none` 关闭 CPU 指令位置采样和调度追踪，仍保留 CUDA API；`-o` 指定报告前缀，产物为 `.nsys-rep`。

<span style="color:red">用户提问：时间轴每一行代表什么？CUDA HW 是 GPU，Threads 是 CPU 吗？</span>

| 轨道 | 本例的含义 |
| --- | --- |
| `CUDA HW → Kernels → vector_add` | GPU 上执行加法的活动，不逐个展示 GPU 线程 |
| `CUDA HW → Memory` | GPU 的拷贝与清零活动 |
| `HtoD memcpy` / `DtoH memcpy` | CPU→GPU 输入 / GPU→CPU 输出 |
| `Threads → [6664] vector_add → CUDA API` | CPU 线程 6664 调用 CUDA API；此处 vector_add 是程序/线程名称 |
| `CUDA Overhead` / `Profiler overhead` | CUDA 额外工作（例如加载）/ 工具自身的工作 |

父级行汇总子行，同一活动可在不同层级重复显示，不算额外操作。横向位置表示发生时间，横向宽度表示持续时间，行的位置区分执行方与活动类别；1000 ns = 1 μs。本例 `Kernels 22.4%` 与 `Memory 77.6%` 是 GPU 已记录活动时间的分类比例，子级百分比使用相应分组范围；不能当成整个程序的 GPU 利用率。

<span style="color:red">用户提问：为什么只看到很少几个环节，是不是要缩放才能看到所有 API？cudaLaunchKernel 为什么没找到？</span>

程序只做一次小型加法，微秒级活动在秒级全局视图中像细线。先核对活动标签确实为 `_02`，在 `CUDA API` 行右键选择 `Show in Events View`，列出当前可见时间范围内的事件，再定位并放大目标区域。右上角 `1x` 滑块调整轨道高度，横向时间缩放另有操作，可通过键盘图标查看帮助。列表适合逐项查调用，时间线适合看顺序与时间关系；采集范围不会因放大而增加。

<mark>GUI 的 CPU 启动事件也可能显示 kernel 名称，需要结合轨道判断。</mark> 用户截图中 API 列表第 8 行 `vector_add(...)` 的 450.575 μs，对应 CLI 的 `cudaLaunchKernel` 和源码第 56 行；GPU kernel 轨道中的同名事件为 2.176 μs，对应源码第 20 行的函数执行。两者关联编号均为 124。前者包含启动及此次显示的模块/函数加载工作，后者为 GPU 执行活动；不将两个耗时当成同一测量。

<span style="color:red">用户提问：两个 cudaMemcpy 怎样区分 HtoD/DtoH？要先了解源码吗？A、B 都是输入，为什么一个长、一个短？</span>

方向先看 GPU 的 `HtoD memcpy`、`DtoH memcpy` 行，再选中 CPU API，通过关联高亮或 Correlation ID 对应 GPU 事件。报告说明方向和大小，源码说明是哪一个变量：第 51 行拷贝 A、第 52 行拷贝 B、第 60 行回读 C。源码与报告互相核对，不凭 CPU 行中通用的 `cudaMemcpy` 名称或颜色猜方向。

| 数据 | 方向 | Correlation ID | 字节数 | CPU API 耗时 | GPU 拷贝耗时 |
| --- | --- | --- | --- | --- | --- |
| A | HtoD | 121 | 4000 | 454.982 μs | 2.208 μs |
| B | HtoD | 122 | 4000 | 57.448 μs | 1.344 μs |
| C | DtoH | 127 | 4000 | 73.237 μs | 2.656 μs |

数值来自本日已核查的用户 `_02` 报告，本次总结未重测。<mark>CPU API 耗时包含接口内的准备、提交、可能的等待等工作；GPU 拷贝时长记录传输活动，两者边界不同。</mark> 普通 CPU 内存到 GPU 的传输可能经过中转；首次准备、内部资源和工具开销可能影响调用时长。该报告没有逐项拆分这些原因，不能确定第一次较慢的单一原因，也不能用一次采集宣称固定带宽或优化效果。

<span style="color:red">用户提问：CPU 发起后，要等 CPU 进程结束 GPU 才动吗？绿色条有长有短表示什么？</span>

<mark>API 返回、GPU 工作完成、CPU 进程退出是不同时间点；CPU/GPU 可以在同一时间段做不同工作。</mark> 本例第一次 GPU HtoD 的时间区间与 CPU 第二次 cudaMemcpy 调用重叠，可由两层的起止时间确认。CPU 仍会继续提交计算、等待、回读和校验。绿色 GPU HtoD 条的宽度表示拷贝时长，不直接表示数据量；本例 A/B 字节数相同，实际时长仍不同。颜色解释必须结合轨道和事件信息，不泛化成所有绿色均是同一种操作。

图形操作与关联规则参考 [Nsight Systems User Guide](https://docs.nvidia.com/nsight-systems/UserGuide/index.html#reading-your-report-in-gui)；CPU 拷贝调用语义参考 [CUDA Runtime API 12.9：API synchronization behavior](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/api-sync-behavior.html)。本章停留在识别与解释三类轨迹，异步细节和多 stream 继续按 PLAN 后续章节学习。

### 踩坑记录

用户第一次尝试在 WSL 启动 GUI 出现 OpenGL/ZINK/EGL 报错，本机 GUI 入口是旧版 2025.1.3，CLI 新版为 2026.4.1。原 `_01` 报告有 CPU API，却缺少 GPU 数据，诊断含旧版采集对当前驱动不支持的警告。不能把“报告生成了”当成数据齐全。后续用户 `_02` 数据完整，并在 Windows 2026.4.1 GUI 提供可读截图；以新版报告作为本章读图证据。

读图中实际遇到的疑问已在上面保留：旧报告标签未切换、短事件被全局缩放压成细线、API 启动事件显示 kernel 名称、误把 CPU API 条长当成 GPU 搬运时长、认为 GPU 要等 CPU 进程结束。这些问题已讲解，仍需个人复述，不据主动提问自动认定掌握。

### 八股自测

拿自己的 `_02` 报告说明：CPU 的 vector_add 启动事件与 GPU 的 vector_add 执行事件如何区分、怎样对应源码？两个相同大小的输入拷贝为什么不能只比较 CPU 红色条就判断 GPU 搬运速度，哪个时间区间说明 CPU 与 GPU 可以重叠工作？待用户用自己的话解释。

## 2026-10-20 Ch06：warp 分组、分支分歧与实验观察

### 今日完成任务

本条为本章汇总，覆盖 10 月 8 日内容准备、10 月 14 日编号练习及后续代码讲解、10 月 20 日分路补全与观察，不把跨日会话间隔当成学习用时。源码为 [CH06/warp_branch.cu](../CH06/warp_branch.cu)，完整操作与历史验证见 [章节讲义](chapters/06_warp_execution.md)，进度、辅助程度及验收只在 [RECORD](RECORD.md) 维护。

框架、TODO 1 的 lane/warp 计算、TODO 2 的分路条件均由 Codex 按用户要求实现并验证。用户逐段阅读和提问，并实际用 NCU GUI 打开 `ncu-divergence-2026-10-20.ncu-rep`，提供左侧 CUDA Source、右侧 SASS 及分歧/线程参与指标的截图。源码与指令的对应已有用户操作证据；没有将 Codex 编译、采集或用户提问写成用户独立实现与完整解释验收。

### 基本概念

<span style="color:red">用户提问：Ch06 主要讲什么，程序的组织结构怎样，为什么比前章多了很多函数？</span>

<mark>本章主要观察：相同的 A/B 总工作量，放在同一 warp 内分路，或让不同 warp 分别走完整路径，执行情况可能不同。</mark> warp 是 GPU 调度的一组 32 个线程，lane 是线程在组内的位置。这里使用一维 block，连续的 32 个 block 内线程编号组成一个 warp；不能据此认为所有 GPU 线程在每个时刻严格同步。

```cpp
const int t = threadIdx.x;
const int lane = t % warpSize;
const int warp_in_block = t / warpSize;
```

线程 31 是 warp 0、lane 31；线程 32 是 warp 1、lane 0；线程 63 是 warp 1、lane 31。`warp_in_block` 在每个 block 中重新从 0 编号，不是 SM 编号。数组访问则用全局下标 `i = blockIdx.x * blockDim.x + threadIdx.x`，不要将 lane、block 内编号和全局下标混为一谈。

程序分工围绕实验流程展开：

```text
CPU main：选择模式、查询设备、返回成功或失败
  ├─ probe → run_probe → GPU probe_warps → 回读并校验 64 项编号
  ├─ check → run_branch(false) → 两种分路模式各运行一次并校验
  └─ bench → run_branch(true) → 校验、预热、重复计时、输出中位数

GPU branch_work：读 input[i] → choose_path_a → path_a 或 path_b → 写 output[i]
```

`make_reference` 在 CPU 生成两套正确答案，`mismatches` 统计错误元素，`median` 取计时中位数。`run_branch` 内的 `launch`、`validate` 是 lambda，即当前函数内部起名的小函数，`[&]` 允许其引用外层变量；前者由 CPU 提交 kernel，后者回读并校验。函数变多是为了分开编号观察、两路计算、校验和计时，核心修改仍是编号和分路两处。

`run_probe` 先在 GPU 分配两个数组，64 个 GPU 线程各写自己的 lane/warp 编号，再回读到 CPU 的两个 vector。GPU 只打印 8 项边界值，CPU 检查全部 64 项；printf 的输出先后不证明线程执行顺序。`errors += 条件1 || 条件2` 中，只要任一编号错误就给该线程计 1 项，两个字段都错也只加 1。

<span style="color:red">用户提问：这些参数是做什么的，constexpr 是什么意思？</span>

| 参数 | 本章作用 |
| --- | --- |
| `kBlock=256` | 计时 kernel 每个 block 256 个线程，含 8 个完整 warp |
| `kN=65536` | 每线程处理一项，共 256 个 block |
| `kIterations=256` | 每个线程在所选路径中循环计算 256 次 |
| `kWarmup=10` | 每种模式正式计时前先运行 10 次 |
| `kSamples=21` | 每种模式获取 21 个样本并取中位数 |
| `kBatch=5` | 每个 Event 样本连续启动 5 次 kernel，再将整批时间除以 5 |

<mark>Iterations 是一次 kernel 内的循环次数，Batch 是一次计时内 kernel 的启动次数。</mark> `probe` 的一个 block、64 个线程独立配置，不使用计时 kernel 的 `kBlock`。`constexpr` 变量要求初始化值在编译时能确定，且初始化后不可修改；`const` 只要求初始化后不可修改，初值可以运行时才得到。变量名前的 `k` 只是常量命名习惯。

<span style="color:red">用户提问：__device__ 是什么意思，path_a 与 path_b 有什么区别？</span>

`__device__` 表示函数在 GPU 上执行，供 GPU 代码调用；本程序由 CPU 用 `<<<...>>>` 启动 `__global__` kernel，当前 GPU 线程再调用选中的 device 函数。调用 `path_a` 不会创建新线程，也不是重新提交一次 kernel。

两条路径都接收 `x`、循环 `iterations` 次、返回最终值，区别是乘加常数及右移位数不同：A 右移 13 位，B 右移 11 位。`x ^= x >> 13` 等价于 `x = x ^ (x >> 13)`，用移位和按位异或混合数值中的位。`uint32_t` 的运算按模 2^32 处理，CPU/GPU 可以精确比较结果；无需把这些常数扩展成算法学习任务。

`__noinline__` 是尽量保留独立函数调用的编译提示，不单独保证真实分支存在。两条有数据依赖的计算体用于形成不同且可校验的工作，实际控制流还需由编译产物及动态指标核对。

两种模式都包含 A、B，总人数各 32768，输入和输出地址始终按全局下标连续访问：

| 模式 | 选 A 的条件 | warp 内的安排 |
| --- | --- | --- |
| `within_warp`，mode=0 | `lane < 16` | 每个 warp 的前半组走 A、后半组走 B |
| `between_warps`，mode=1 | `warp_in_block % 2 == 0` | 偶数 warp 全走 A、奇数 warp 全走 B |

<mark>分支分歧发生在同一 warp 的线程选择不同执行路径时；不同 warp 各自选择不同路径不构成这个意义上的 warp 内分歧。</mark> 不属于当前路径的线程暂不参与相关指令。两种模式的同一下标可能走不同路径，输出无需相互相等，应各自与对应的 CPU reference 比较。编译器可能改写简单分支，本机一次结果也不能推广成所有分支固定慢几倍。

<span style="color:red">用户提问：CUDA 自己没有错误码吗，为什么需要 check_cuda，必须显式写这个函数吗？</span>

CUDA API 本身返回 `cudaError_t`，成功为 `cudaSuccess`。`check_cuda` 是项目自己的辅助函数，将判断状态、输出 API 名称/源码位置/错误说明、退出程序统一起来，并非 CUDA 必须提供的函数。可以逐次写 `if (status != cudaSuccess)` 自行处理；返回错误码不会自动替应用完成所有错误处理。当前程序选择失败时退出，不把这一处理策略当成 API 要求。

<span style="color:red">用户追问：GPU 异步执行，和 cudaGetLastError 是否等待 GPU 完成有什么关系？</span>

CPU 提交 kernel 后能够继续运行，此时 GPU 可能尚未执行到会出错的位置。`cudaGetLastError()` 读取并清除当前 host 线程的 Runtime 错误记录，不等待 GPU；它也可能读到此前异步工作留下的错误，检查点不是故障发生点的保证。

```cpp
branch_work<<<grid, block>>>(...);      // CPU 提交 GPU 工作
CUDA_CHECK(cudaGetLastError());        // 读取此刻已有的错误记录
CUDA_CHECK(cudaDeviceSynchronize());   // 等待此前设备工作完成，并检查返回状态
```

<mark>启动后的检查没有读到错误，不代表 GPU 后续执行一定成功；等待完成后再检查，才能覆盖执行结束这一时间边界。</mark> 需要精确检查越界等内存访问仍使用 Sanitizer，不能把数值 PASS 当作内存安全证明。

<span style="color:red">用户提问：给出观察两条 path 整个流程耗时差异的指令。</span>

这里的对照单位是两种线程分路安排，当前没有分别启动一个“全 A kernel”和一个“全 B kernel”。普通 `check` 先检查正确性，`bench` 通过后再预热并采集 Event 样本；起止 Event 与 kernel 在同一 stream，等待 stop 完成再读时间。两种模式成对采样并轮换先后，每批回读校验在计时区间外。

`event_batch_per_launch_median_us` 是 Event 毫秒差乘 1000、除以 5，再对每模式 21 个样本取中位数。它不含分配、H2D、D2H、CPU reference/校验和初始化，仍可能包含 CPU 提交间隙；不能冒充含传输的端到端时间或 profiler 上某一次 kernel 的 duration。

本章 10 月 20 日普通观察运行得到 within_warp=116.083205 μs、between_warps=71.097600 μs，参数为 GTX 1650、N=65536、uint32、grid/block=256、iterations=256、warmup=10、samples=21、batch=5。数值引自 [普通运行及 NSYS 预检日志](../reports/CH06/observe-preflight-2026-10-20.txt) 中工具外的 bench；本次总结未重测。它支持本机本次“warp 内分路较慢”的观察，不把总差值全部解释为纯分歧开销。

<span style="color:red">用户提问：如何用 NSYS 或 Nsight Compute 观察是否存在 warp divergence？</span>

NSYS 记录 CPU 提交、GPU kernel 与内存活动的时间关系。两种模式都显示为 `branch_work`，内部 device 函数 A/B 不会各自变成 kernel 时间条；时间较长本身不独立证明分歧。用户主动提出的 NCU 观察为本章可选扩展，正式 NCU 课程仍按 Ch07 推进。

NCU 在本机采集 `SourceCounters`、分歧分支目标总计数与每条指令平均参与线程数，得到以下动态证据：

| 指标 | within_warp | between_warps |
| --- | --- | --- |
| 分歧分支目标计数（sum） | 2048 | 0 |
| 每条指令平均参与线程数 | 16.40 | 32 |
| Branch Efficiency | 98.08% | 100% |

来源为 [NCU 报告](../reports/CH06/ncu-divergence-2026-10-20.ncu-rep) 与 [Details 文本](../reports/CH06/ncu-divergence-2026-10-20-details.txt)，本次只核对已有证据。第一种模式的非零分歧目标计数，结合条件分路和半组线程参与，支持实际发生分歧。Branch Efficiency 汇总大量一致的循环等分支，98.08% 不代表仅损失 1.92% 性能。低参与线程数也可能来自尾部线程或提前退出，不能单独作为分歧证明。

<span style="color:red">用户提问：在 NCU Source 选择 Divergent Branches 和 Avg. Threads Executed，就能定位源码，并与旁边 SASS 对照吗？</span>

可以。用户截图中，第 80 行 if 对应右侧偏移 0x270 的条件 BRA；第 81、83 行 A/B 调用各有 16 个参与线程，第 85 行写出恢复为 32。SASS 是 GPU 机器指令的汇编表示，Source 页面借助编译时的 `-lineinfo` 将指标与 CUDA/SASS 位置关联；`--import-source yes` 把相关源码保存在报告中，便于跨机器查看。

<mark>一行 CUDA 可能关联多条 SASS，源码行的聚合值不等于每条指令的值。</mark> 用户截图里 Divergent Branches 的 100.0 是相对显示，表示相应范围内的分歧计数集中在这一处；可用工具栏 `%` 切换绝对值，该处原始计数为 2048。它不是 100 次分歧，也不是 100% 时间损失或 Branch Efficiency=100%。

<span style="color:red">用户提问：NCU report 怎样组织，为什么只有两次 branch_work，实验不是重复了很多次吗，能只采集某几次吗？</span>

在本次默认 kernel 采集方式下，一份 report 包含多个执行结果，每个结果对应一次选中的 kernel 启动，并包含该次配置、Details 指标、Source/SASS 关联等；顶部 Result 切换结果，不是切换源码中的两个不同函数。实际采集末尾参数为 `check`，只主动提交 mode=0/1 两次启动；`bench` 才会提交 2 次初始校验＋20 次预热＋21×2×5 次正式启动，共 232 次。

`--kernel-name branch_work` 筛选名称，`--launch-count 2` 限制采集数量，`--launch-skip` 跳过指定数量的匹配启动。它按启动次数计数，不自动识别模式；例如对当前 bench 跳过 22 次后采集 1 次对应第 23 次 within_warp，跳过 27 次后采集 1 次对应第 28 次 between_warps。改参数后需要重新核对顺序。

日志的 `5 passes` 是 NCU 为收集不同指标对同一次启动进行的多轮采集，最终合成一个结果，不会因此在 GUI 生成 5 个 Result。<mark>程序循环次数、筛选出的启动次数、工具内部 replay passes 是三个不同层次。</mark> 本次 NCU 采集 check 用于观察动态计数，不是预热性能采样，工具下耗时与普通 bench 分开解释。

相关语义见 [CUDA 12.9 错误处理](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART__ERROR.html)、[NCU Source 页面](https://docs.nvidia.com/nsight-compute/NsightCompute/index.html#source-page)、[NCU CLI](https://docs.nvidia.com/nsight-compute/NsightComputeCli/index.html) 与 [Replay](https://docs.nvidia.com/nsight-compute/ProfilingGuide/index.html#replay)。完整命令集中在章节讲义，不在笔记重复维护多套实验入口。

### 踩坑记录

本章真实追问集中在三个理解边界：CUDA 已返回状态码，为何还需自定义检查；GPU 异步执行，为何错误查询成功不保证后续成功；bench 明明重复很多次，为何 NCU 报告只有两个结果。相应原因与调用顺序已在上文保留，不将这些问题写成用户发生了编译或运行故障。

用户实际提供了 NCU Source/SASS 关联截图；显示中的 100.0 需要区分相对值与绝对计数，行级聚合也需区分单条指令。第二结果的 GUI 对比尚未收到截图，两个模式的动态数值来自 Codex 已采集报告；不把建议用户进行的操作写成已经完成。代码、常量设置和工具细节已讲解，仍不据此推定独立掌握。

### 八股自测

必做复述：线程 32 的 warp/lane 是什么？两种模式 A/B 总人数相同，为什么 mode=0 会发生 warp 内分歧，而 mode=1 不会？结合条件代码和普通计时结果，说明本次测量包含哪些工作、没有覆盖哪些端到端环节。

可选复述：拿 NCU Source/SASS 说明分歧定位、16/32 个参与线程与相对 100.0 的含义，再解释 report 的两次结果和 5 passes 为什么不矛盾。该项用于复习主动询问过的工具观察，不新增课程必修门槛。

## 2026-10-21 Ch07：合并访存、读取索引与 NCU sector

### 今日完成任务

围绕 [CH07/memory_access.cu](../CH07/memory_access.cu) 阅读连续/跨步读取索引、host 实验流程、校验与 Event 计时，学习用 NCU 对应读取请求数和 sector 数。原骨架及预检于 10 月 20 日准备，今天用户要求补全唯一 TODO，Codex 完成正式实现、编译、全量校验、memcheck 和普通 bench；用户随后逐段阅读、提问并用自己的话复述了两种地址安排。完整命令与验证见 [章节讲义](chapters/07_coalescing_ncu.md)，工程进度和工作量只在 [RECORD](RECORD.md) 维护。

用户的复述已抓住主要变量：把 1024 项想象成 32×32 表格，通过交换行列让相邻线程读取不相邻的位置，比较访问效率与耗时。补充澄清“按顺序”指地址下标相邻，不表示线程一个接一个执行；1024 项只是一个小片，完整输入含 4194304 项。尚未收到用户自己的 check/bench 输出或本章 NCU 报告/截图；实现与工具验证不写成用户独立完成。

### 基本概念

**从线程编号到读取地址**

<span style="color:red">用户提问：本章主要讲什么，怎样阅读这个 CU 文件，input_index() 中这一段是什么意思？</span>

<mark>本章保持每线程一次读取、一次加法和一次连续写出，只改变同一 warp 中线程的读取地址排列。</mark> GPU kernel 的核心是：

```cpp
const int j = input_index(i, mode);
output[i] = input[j] + 1.0f;
```

`i` 是全局输出下标，决定写在哪里；`j` 是输入下标，决定从哪里读。连续模式返回 i；跨步模式把每个小片内的 `(row, col)` 映射到 `(col, row)`：

```cpp
const int base = (i / kTileElements) * kTileElements;
const int row = (i - base) / kSide;
const int col = (i - base) % kSide;
return base + col * kSide + row;
```

`kSide=32`、`kTileElements=1024`。base 是当前小片起点；对片内偏移整除 32 得行号，取余得列号。返回时保留 base，保证不同小片各自处理自己的数据。比如 i=35 对应 `(1,3)`，跨步读 j=97，即 `(3,1)`，结果仍写 output[35]。两种模式都恰好读取全部输入各一次，输出顺序可不同，应分别和各自的 CPU reference 比较。

```text
同一个 warp 的 lane：   0   1   2   3  ……  31
连续读取 input 下标：    0   1   2   3  ……  31
跨步读取 input 下标：    0  32  64  96  …… 992
两者写入 output 下标：  0   1   2   3  ……  31
```

这张 32×32 表格只是理解一维数组下标的方法，没有分配 shared memory。直接 `i*32` 会超出当前数组，简单取模又可能重复读部分元素，均不是本章要求的片内行列交换。

**run() 的组织与遇到的 C++ 语法**

<span style="color:red">用户提问：讲解 run()；read_and_check 和 const char* names[] 分别是什么语法，为什么读不懂？</span>

`run(bool timing)` 在 CPU 上组织“准备输入和两套 reference → GPU 分配/H2D → 两种模式分别计算和校验 → 按需预热与计时 → 释放内存”。timing 控制是否计时，mode=0/1 控制读取方式。`correct &= pass` 保留任一模式失败的结果；两个模式的校验分别执行，不因前者失败就跳过后者。

`const char* names[] = {"contiguous", "strided"};` 是含两个元素的字符指针数组，指向只读字符串；names[mode] 取得对应模式的名称。const 修饰所指字符，不表示指针数组本身不可修改。

`auto read_and_check = [&](int mode, bool verbose) { ... };` 是 lambda 表达式，可以先理解为在 run() 内起名的局部小函数。auto 让编译器推断变量类型，`[&]` 允许通过引用使用外层局部变量，括号中是调用参数，花括号中是执行内容。它在 CPU 上回读 GPU 输出，再调用 validate，返回 bool；调用形式是 `read_and_check(1, true)`。verbose 控制是否打印正常校验结果，出错时即使 false 也会打印。另一个 lambda launch 负责向 GPU 提交 kernel，它自身仍在 CPU 上执行。

**内联标记的用途**

<span style="color:red">用户提问：__forceinline__ 是什么意思，什么时候用 forceinline，什么时候用 noinline，有什么讲究？</span>

内联是编译器把被调用函数的计算展开到调用位置，省去独立调用和返回，并可能进一步优化。`__device__` 表示函数在 GPU 上执行，`__forceinline__` 要求编译器内联；本章短小的 input_index 使用该标记。普通代码可以先交给编译器自行决定，不因看到短函数就要求手工标记。

`__noinline__` 是尽可能保留独立函数调用的提示，可用于控制重复展开或构造实验；Ch06 的 path_a/path_b 用它帮助保留两条计算路径。它不禁止函数内部其他优化，也不单独保证最终分支形态。强制内联大函数可能使代码膨胀，不能承诺更快；两标记不能同时用于同一函数。语义见 [CUDA 12.9 内联说明](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#noinline-and-forceinline)。

**普通 bench 测量了什么**

<span style="color:red">用户提问：最后 bench 跑出来的数据差异是什么？</span>

先全量校验，再每模式预热 10 次；取 21 轮样本，每轮两模式交替先后，每个 Event 区间连续启动同模式 kernel 5 次。等待 stop 完成后读毫秒差，乘 1000 转为微秒、除以 5 得批次平均每次启动时间，最后对每模式 21 个值取中位数。每批回读校验在 Event 区间外。

正式完成版的 GTX 1650、float32、N=4194304、grid=16384、block=256 运行结果如下，原始证据为 [completed-2026-10-21.txt](../reports/CH07/completed-2026-10-21.txt)：

| 读取方式 | Event 批次平均每次启动的中位数 |
| --- | --- |
| contiguous 连续 | 317.593598 μs |
| strided 跨步 | 689.043188 μs |

跨步耗时约为连续的 2.17 倍，多约 371.45 μs。两模式各 4194304 项全量正确、误差 0，独立 memcheck 零错误。<mark>时间不含分配、H2D/D2H、CPU reference 或校验，仍可能包含 host 提交间隙；这是本机本次对照，不是固定减速比例。</mark> 本条总结重读已有日志，没有重新计时。

**NCU 的 sector 与缓存层次**

<span style="color:red">用户提问：如何用 NCU 查看读取请求涉及多少个 32 字节数据块，什么是数据块？L1/TEX 层面的访问是什么意思，为什么 sector 多 8 倍不代表显存传输或耗时多 8 倍？</span>

sector 是这里按 32 字节边界划分的访存单位，容纳 8 个 float；它与 kernel 的线程组 block 不同。本章对齐的第一个 warp 连续读 0～31 项，集中在 4 个 sector；跨步读 0、32……992 项，涉及 32 个不同 sector。合并访存关注的是同一 warp 一次读取所需数据的分布，不只是整个 kernel 最后有没有遍历完整数组。

NCU 对本例只选 access_pattern 的两次 check 启动，第一个结果为连续、第二个为跨步。采集 `l1tex__t_requests_pipe_lsu_mem_global_op_ld.sum`（读取请求总数）和 `l1tex__t_sectors_pipe_lsu_mem_global_op_ld.sum`（请求涉及的 sector 总数），用后者除以前者得到平均每次请求涉及的 sector 数。对当前 kernel，一个完整 warp 执行一次 global load 产生一次请求，不是每个线程各算一次请求。

10 月 20 日教学方临时补全版的 [NCU Details](../reports/CH07/ncu-preflight-2026-10-20-details.txt) 已有实测：

| 模式 | requests | sectors | sectors/request |
| --- | --- | --- | --- |
| 连续 | 131072 | 524288 | 4 |
| 跨步 | 131072 | 4194304 | 32 |

这组计数与上面的 10 月 21 日正式 bench 来自不同运行、不同日期；今天没有重采 NCU。完整采集、CLI 导入和 GUI Details 查看方法集中在 [讲义 NCU 小节](chapters/07_coalescing_ncu.md#正式用一次-ncu-采集解释访问)，不重复维护另一套命令。

缓存可以理解为靠近计算单元、临时保留已取回数据的快速存储。本章普通读取的简化请求路径是“线程 → L1/TEX → 未命中才继续到 L2 → 仍未命中才继续到显存 DRAM”。命中缓存的 sector 访问也计入 L1/TEX 指标；同一 sector 被不同请求访问会重复计数，不是全程序访问过的不同 sector 数量。

例如两组 warp 的请求分别包含 input[0]/input[1]、input[32]/input[33]，每对元素属于同一 sector。若相关数据仍在可用缓存中，后来的请求可能复用已有内容，不必每次从 DRAM 重取；这不假定 warp 编号决定执行先后，也不保证所有请求均命中 L1。<mark>L1/TEX sector 访问次数、缓存未命中次数、实际显存传输字节数、kernel 总耗时，是不同层次的量。</mark> 即便显存字节数增加，访存并行、地址计算和不变的输出写入等因素也会影响总耗时，不能直接同比换算。

本章没有测量 L1/L2 命中率和 DRAM 流量，因此缓存复用是解释可能机制的例子，不是已经测出缓存抵消多少流量；也不能把 2.17 倍耗时精确归因于某一级缓存。指标口径见 [NCU Memory Tables](https://docs.nvidia.com/nsight-compute/ProfilingGuide/index.html#memory-tables)。

### 踩坑记录

本章真实疑问集中在读取索引拆分、内联标记、lambda 与字符串指针数组，以及 sector、缓存与显存流量的区别。用户已主动复述地址排列的主要变量，尚需结合自己的运行结果解释计数和时间边界；不把提问本身当作所有概念已独立掌握。

没有收到用户实际编译、运行或 NCU 采集失败的输出。历史骨架 strided FAIL 是 TODO 占位的预期，今天正式完成版已通过，不记成用户误写。NCU 运行下的耗时不用于替代普通 bench，理论 4/32 也不换算成固定 8 倍减速。缓存、SASS 和内联优化的进一步调优不新增为本章必修。

### 八股自测

给出 i=35 和 i=1025 的跨步输入下标，解释为什么必须保留 base，以及为什么两个模式都读遍所有输入但输出可以不同。再用同一 warp 的地址分布说明连续为 4、跨步为 32 个 sector。

结合一次自己的 check/bench 与 NCU 两结果，说明读取请求数为何可以相同、sector 数为何不同，sector 8 倍为何不等于显存流量或耗时 8 倍，并指出 Event 计时包含和排除的工作。以上为后续验收入口，不把建议操作写成已经完成。

## 2026-10-22 Ch08：shared 数据交换与 block 同步

### 今日完成任务

围绕 [CH08/shared_exchange.cu](../CH08/shared_exchange.cu) 阅读实验参数、main 数据流、kernel 的对称读取，以及 benchmark 的 Event 批次采样。骨架在 10 月 21 日生成，今天按用户“完成两个todo”的要求，由 Codex 补全 barrier 与伙伴槽位读取，完成正式编译、全量校验、Sanitizer 检查和普通计时；随后直接运行已有可执行文件，观察同步/缺同步模式。运行命令集中在 [章节讲义](chapters/08_shared_sync.md)，工程进度和工作量只在 [RECORD](RECORD.md) 维护。

用户主动复述了“每个 block 内线程去读取与自己对称的 shared 位置”，这是对 kernel 功能的局部理解证据。用户随后追问 barrier 是否就是最后的同步，以及不同线程只是取不同位置为何仍会冲突；已结合写入阶段和跨 warp 例子讲解。实现和工具运行由 Codex 完成，尚未收到用户自己的运行输出或对同步依赖的独立复述，不据此认定整章掌握。

### 基本概念

**shared 是 block 内共用的暂存区**

shared memory 可以理解为同一个 block 共用的工作台：每个线程先放上自己的数据，再取走伙伴放的数据。`__shared__ float tile[kBlock]` 在每个 block 内各有一份，128 个 float 共 512 字节，生存期随该 block；本例的 tile 用于 block 内交换。main 的 cudaMalloc 分配输入/输出 global memory，tile 则在 kernel 内声明。

<span style="color:red">用户提问：这个 kernel 的功能，就是每个 block 内的线程读取该 block 中与自己对称的 shared 位置吗？</span>

是。固定 N=1000、block=128、grid=8，七个完整 block 各处理 128 项，最后一个处理 104 项。`t` 是 block 内线程编号，`base` 是本片段起点，`i=base+t` 是全局下标，`count` 是本片段有效项数，`peer=count-1-t` 是伙伴槽位编号。<mark>输出为每个 block 对应的有效片段分别反序。</mark>

```cpp
tile[t] = valid ? input[i] : 0.0f;
if (use_barrier) {
    __syncthreads();
}
if (valid) {
    const int peer = count - 1 - t;
    output[i] = tile[peer];
}
```

完整 block 中线程 0 读取 tile[127]、线程 127 读取 tile[0]；尾部线程 0 读取 tile[103]。无效尾部线程 t=104～127 写零、参加本例的集合点，但不读取越界 input，也不写 output。输入为 input[i]=i*0.25f，因此 output[0]=input[127]=31.75，output[896]=input[999]=249.75。

**barrier 建立写入与伙伴读取的先后关系**

<span style="color:red">用户提问：barrier 是什么，就是最后的同步吗？本次实验是否对照加同步和不加同步？只是让不同线程取对称位置，为什么会与其他线程冲突？</span>

barrier 是集合点。本例的 `__syncthreads()` 位于 shared 写入之后、伙伴读取之前，等待同一 block 的线程到达，并让此前写入对 block 内线程可见。`use_barrier` 在一次 launch 内取值一致，所有线程选择同一分支；不能将本例集合点移入只有部分线程满足的 if(valid)。128 个线程含四个 warp，伙伴交接跨越 warp，不能用单个 warp 的同步覆盖全部依赖。

<mark>不同线程的读取彼此不冲突，但读取的槽位由另一个线程负责写入；必须保证伙伴先写好，自己再读取。</mark> 输入已从 CPU 传入 global memory，也不代表线程已经把它搬到了 shared。以下只是一种可能的错误执行顺序，用于理解风险，不是本次工具还原的实际执行轨迹：

```text
线程 0：   写 tile[0]
线程 0：   读 tile[127]  ← 伙伴可能尚未写好
线程 127： 写 tile[127]
```

这里的风险是线程 0 对 tile[127] 的读取与线程 127 对同一槽位的写入缺少顺序保证。本例先写一轮、再读一轮，读完不覆盖复用 shared，所以一个写后读 barrier 足够；循环复用时是否需要额外同步留到后续实际程序。

| 同步位置 | 谁在等待 | 本例作用 |
| --- | --- | --- |
| kernel 中间的 `__syncthreads()` | 同一 block 的线程 | 保证写完 shared 后再互相读取 |
| main 的 `cudaDeviceSynchronize()` | CPU 调用线程 | 等待此前 GPU 工作完成，再回读结果 |

<mark>kernel 完成后的 host 等待，不能补救 kernel 内部已发生的过早读取。</mark> 语义参考 [CUDA 12.9 Synchronization Functions](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#synchronization-functions)。

**main 组织 CPU 与 GPU 数据流**

<span style="color:red">用户提问：如何阅读当前 cu 文件，main 函数整个是什么流程？</span>

建议先看参数，再沿 main→launch→exchange_block 阅读执行流程，随后用 make_reference/validate 理解校验，最后看 benchmark。main 和 launch 在 CPU 上执行，exchange_block 在 GPU 上执行。main 的流程是：选择模式、打印配置、CPU 准备输入与 reference、GPU 分配和 H2D、启动 kernel、等待完成、D2H、全量校验、按需计时、释放内存和返回状态。

`argc==1` 表示只有程序名，默认 check；否则从 argv[1] 取得模式。`strcmp(a,b)==0` 表示字符串内容相同。check 启用 barrier，bench 先校验再计时，race 传入 false 跳过 barrier。`!unsafe` 因此是启动时的 use_barrier 参数。`reference` 是 CPU 按每片首尾反向生成的正确答案，不调用 kernel 的 shared 实现；validate 检查全部 1000 项，示例打印不替代全量校验。

**benchmark 测的是同步版本的批次平均时间**

<span style="color:red">用户指定 benchmark() 代码段要求讲解，并要求根据生成的可执行文件说明实验现象。</span>

benchmark 的 input/output 指向 GPU 数组，reference/host_output 是 CPU 数组；后两者按引用传入，const reference 只读。先以 use_barrier=true 预热 10 次，等待完成，再创建 start/stop Event。每个样本在同一默认 stream 中依次记录 start、提交 10 次 kernel、记录 stop；等待 stop 完成后取得毫秒差，乘 1000 转微秒、除以 10，得到本批平均每次启动时间。

一共最多采 21 个样本，每批结束回读并校验最后一次启动留下的输出，同时要求时间有限且大于零；失败则停止后续采样，不打印有效中位数。全部通过后排序，取第 11 个值，最后销毁 Event。每次仍读相同 input、覆盖相同 output，不把前次反序结果当作下次输入。

<mark>最终统计是“21 个批次平均每次启动时间的中位数”。</mark> 预热、分配、H2D/D2H、CPU reference 和回读校验不在 Event 区间内；短 kernel 的区间仍可能包含 host 提交间隙。本章只测同步版本，不拿缺同步版本作速度比较。

**实验现象：缺同步可以数值 PASS，但仍有读写竞争**

以下引自 10 月 22 日已有 [observe 日志](../reports/CH08/observe-2026-10-22.txt)，本次总结只重读证据，没有重新运行。环境为 GTX 1650 / CC 7.5，N=1000、float32、grid=8、block=128。

| 模式 | 数值结果 | racecheck 结果 |
| --- | --- | --- |
| check，有 barrier | 全部 1000 项 PASS，误差 0 | 零冲突，退出 0 |
| race，无 barrier | 本次也全部 PASS，误差 0 | 检出 shared 第 38 行写与第 46 行读的冲突，退出 99 |

racecheck 将 4000 个字节级 hazards 合并为 1 条 error 分析，不能当作 4000 个独立 bug。<mark>数值 PASS 只说明本次结果符合 reference，不能证明读写顺序可靠。</mark> race 模式的应用退出码故意为 0，让工具在检测错误时通过 --error-exitcode 99 报告检查失败，因此应用退出成功也不是无竞争证明。工具职责见 [Compute Sanitizer](https://docs.nvidia.com/compute-sanitizer/ComputeSanitizer/index.html#racecheck-tool)。

同一 observe 日志中，普通 bench 的 Event 中位数为 14.627200 μs/次；这是与 racecheck 分开的普通运行。更早的 [正式完成版验证](../reports/CH08/completed-2026-10-22.txt) 已有 check 的 memcheck、racecheck、synccheck 零错误，以及另一轮 bench 的 12.102400 μs/次。它们来自不同运行，不作优化 A/B，不推断时间波动原因或 shared 固定加速比。

### 踩坑记录

本章实际疑问是把“读取位置不同”理解为没有线程间冲突，以及把 block 内 barrier 与最后的 host 等待混淆。关键是补上 shared 的写入阶段：自己要读的槽位由伙伴写入，需要明确先写后读；同一 block 的线程进度不能靠猜。已经讲解这一边界，但尚未收到用户对它的独立复述。

用户已经准确复述对称读取的功能，不能笼统写成没有理解证据。代码两处补全、正式编译及工具运行由 Codex 完成；没有用户独立实现、个人运行输出或工具操作截图，不虚构用户发生过编译、运行故障。缺同步数值仍 PASS 是本例真实观测，不是要求通过多跑几次制造 FAIL。bank conflict、归约和底层指令优化不扩展为本章内容。

### 八股自测

用自己的话解释线程 0 读取 tile[127] 时依赖谁的写入，以及为什么 main 最后的 cudaDeviceSynchronize 不能代替 kernel 内的 __syncthreads。结合现有 check/race 两结果，说明为什么两者数值都 PASS，racecheck 却不同。

再解释最后一个 block 为什么使用 count=104、线程 0 为什么读 tile[103]、无效线程为什么仍参加本例集合点，并说明 14.627200 μs 的统计方式与不包含的工作。以上用于后续验收，不将已讲解视为已独立掌握。

## 2026-10-26 Ch09：shared 布局、bank conflict 与 NCU 计数

### 今日完成任务

按用户“总结本章内容”的要求，汇总本章源码阅读与提问。围绕 [CH09/bank_conflict.cu](../CH09/bank_conflict.cu)，已讲解参数、二维线程坐标与 warp 分组、shared 寻址、转置读写、template、volatile、循环展开，以及 NCU 冲突指标的位置、分批服务和大数值的来源。运行命令与教学任务见 [章节讲义](chapters/09_bank_conflict.md)，进度和工作量只在 [RECORD](RECORD.md) 维护。

骨架在 10 月 22 日生成；10 月 23 日按用户要求，由 Codex 完成唯一的 shared_index 地址 TODO 并验证正式程序。本次只重读源码及已有报告，没有重新运行实验。用户明确表示不理解 x/y、warp 归属与循环赋值，并继续追问 bank conflict；这些是实际理解难点，尚未收到用户独立实现、个人运行/采集输出或完整解释，不据提问推定已经掌握。

### 基本概念

**程序任务与参数：每个 block 转置一个小矩阵**

<span style="color:red">用户提问：先讲解一下参数设置含义；完成 TODO，并告诉我这里整个 kernel 主要是什么功能。</span>

输入为 1024 个独立的 32×32 float32 小矩阵，输出将每片分别转置，即交换行列。kSide=32、kTileElements=1024、kTiles=1024、kN=1048576；输入和输出各占 4 MiB。每个 block 负责一个小片，base=blockIdx.x*1024 定位当前片段，不交换小片的位置。

kRows=8 决定 block=(32,8)，每个 block 有 256 个线程、8 个 warp，每线程搬运 4 项，合计覆盖 1024 项。kRows 是线程组织高度，矩阵仍有 32 行。kSharedElements=32*33=1056 个 float，每个 block 两种布局均预留 4224 字节；stride 32 使用前 1024 个槽位，stride 33 每行末尾留一个空位，空位不属于逻辑矩阵。

普通 bench 的 kWarmup=10、kSamples=21、kBatch=5：先预热 10 次，每个 Event 区间连续启动 5 次，区间时间除以 5 得到每次启动的批次平均值，再对 21 个样本取中位数。分配、传输及 CPU 校验不在 Event 区间中，可能的 host 提交间隙仍可能影响结果。check 则只分别启动两种布局，不执行预热与重复计时。

**二维坐标先转一维编号，再组成 warp**

<span style="color:red">用户提问：不太懂 x、y 有什么区别，也不懂“每个 warp 固定 y，x=0..31”；warp 到底如何组织，怎么知道哪些线程属于一个 warp？</span>

可以把当前 block 逻辑上看成 8 排、每排 32 个座位。每个线程同时具有 x 和 y：x 是排内座位号，y 是排号，这不是 GPU 上的物理座位布局。CUDA 按 x 优先增加的顺序编号，二维 block 中：

```cpp
int tid = threadIdx.x + blockDim.x * threadIdx.y;
int warp_in_block = tid / 32;
int lane = tid % 32;
```

同一 block 内连续 32 个编号组成一个 warp，不跨 block。本例 tid=x+32*y，因此 y=0、x=0..31 是 warp 0，y=1、x=0..31 是 warp 1，以此类推。线程 (x=3,y=2) 的 tid=67，属于 warp 2、lane 3。

<mark>“同一个 warp 固定 y”来自本例 blockDim.x=32，并不是任意二维 block 都成立。</mark> 若 block=(16,16)，warp 0 会包含 y=0 和 y=1 的各 16 个线程。归属按编号计算，不能根据线程碰巧何时运行来判断。[CUDA Thread Hierarchy](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#thread-hierarchy) / [SIMT Architecture](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#simt-architecture)

**两轮循环：先按行搬入，再按列读出**

<span style="color:red">用户提问：这个循环里面的赋值逻辑不太懂；output[base + col * kSide + x] 是什么意思？</span>

每个线程独立执行循环，j=0、8、16、24。第一轮 row=y+j，线程将输入第 row 行、第 x 列放到 shared 的同一逻辑位置；例如 (x=3,y=2) 负责第 2、10、18、26 行的第 3 列。同一个 warp 的 x 覆盖 0..31，所以每轮沿完整的一行连续搬运。

```cpp
tile[shared_index(row, x, Stride)] = input[base + row * 32 + x];
__syncthreads();  // 实际源码位于整个写入循环之后，等待所有线程完成四项写入。
```

整个写入循环结束后执行 block barrier，再进入读取循环。第二轮 col=y+j，读取 shared 的第 x 行、第 col 列，写到输出第 col 行、第 x 列：

```cpp
output[base + col * 32 + x] = tile[shared_index(x, col, Stride)];
```

这里 col 沿用输入列号，转置后成为输出行号。base 找到当前小矩阵，col*32 跳过输出的 col 整行，x 再定位该行中的列。例如 base=0、col=2、x=3 时写 output[67]，即输出第 2 行、第 3 列，数据来自输入第 3 行、第 2 列。同一个 warp 的 global 写出仍连续。

**shared_index 与 padding：位置改变，逻辑数据保持一致**

<span style="color:red">用户提问：stride 如何通过 shared_index 影响实验结果，如何体现 shared memory bank conflict？</span>

当前 helper 为 `return row*stride+col;`，stride 的单位是 float 槽位。它先找到行起点，再加列偏移；写入和读取共用同一个映射，因此 padding 后仍能找到原来的逻辑数据。global 地址、工作量、barrier 和 shared 预留大小都保持不变，转置输出应一致。历史占位版固定使用行跨度 32，数值也能 PASS，所以正确性本身不能证明 padding 已生效。

本机本例的 tile 按 bank 0 对齐，每线程每条读取处理一个 32-bit float，可用 float 槽位下标模 32 得到 bank 编号。按行写入的下标为 row*Stride+x，warp 中相邻 x 落在不同 bank；按列读取的下标为 x*Stride+col，同一个 warp 中 col 固定：

| 行跨度 | col=0 时线程 0、1、2、31 的 shared 下标 | 对应 bank |
| --- | --- | --- |
| 32 | 0、32、64、992 | 0、0、0、0 |
| 33 | 0、33、66、1023 | 0、1、2、31 |

<mark>stride 32 使同列的不同地址挤在一个 bank；stride 33 通过每行空一个位置，把这些访问分散到全部 bank。</mark> 多线程读取同一个 32-bit 字可以广播，不属于本例的不同地址冲突。Ch07 的 global 合并访存关注数据落在哪些 sector；本章关注 shared 地址落在哪些 bank，二者不能混为同一个指标。[CUDA 12.9：Shared Memory and Memory Banks](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-best-practices-guide/index.html#shared-memory-and-memory-banks)

**template、volatile 与循环展开的作用**

<span style="color:red">用户提问：template 模板什么作用？volatile 什么作用？#pragma unroll 什么作用？</span>

`template<int Stride>` 让一份源码按编译期整数生成不同版本，`shared_transpose<32>` 和 `<33>` 的地址计算分别使用固定的 32 和 33。调用中的 `<32>` 选择模板版本，`<<<...>>>` 指定 grid/block，`(input,output)` 传运行时数据。

`__shared__` 决定 tile 放在 shared memory，`volatile` 限制部分读写优化，帮助本微基准保留希望观察的访问。它不保证源码访问与硬件访问严格一一对应，也不提供线程间同步；写后读交接仍需要 `__syncthreads()`。不能把 volatile 当成消除数据竞争的办法。[CUDA 12.9：Volatile Qualifier](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#volatile-qualifier)

`#pragma unroll` 作用于紧随其后的循环；本例循环次数在编译期固定，展开后逻辑上相当于直接写出 j=0、8、16、24 四份搬运操作，便于减少循环控制及优化固定偏移。每个线程依然处理四项，线程数不变，不保证四份操作同时执行，也不预设一定更快。[CUDA 12.9：pragma unroll](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#pragma-unroll)

**bank conflict 的分批服务与 NCU 大计数**

<span style="color:red">用户提问：发生 bank conflict 时是怎样分批的？在 NCU 哪里看指标？Bank Conflicts 是什么，为什么数字这么大？</span>

可以把 bank 看成并行服务窗口。本例一次 warp 标量读取中，每个 bank 在一批中服务一个不同的 float，不同 bank 可并行；同 bank 的不同 float 需要分批。这类服务批次在 NCU 中称为 wavefront。stride 32 的同列读取需要 32 批，stride 33 可一批完成；若 32 个请求均匀分布到 16 个 bank、每个 bank 有两个不同 float，则两批、每批服务 16 个 bank。warp 成员不变，实际先服务哪个线程不保证按 lane 编号，不能把示意顺序当成硬件轨迹。

本章 [正式 NCU 报告](../reports/CH09/completed-2026-10-23.ncu-rep) 只专门采集冲突指标，优先在 GUI 的 Raw 页筛选 bank_conflicts。`l1tex__data_bank_conflicts_pipe_lsu_mem_shared_op_ld.sum` 对应 shared 读取，`..._st.sum` 对应写入；sum 汇总本次 kernel 各硬件实例。若采集完整访存表，可在 Details 的 Memory Workload Analysis Tables → Shared Memory 看 Bank Conflicts 列。显示约 1.02 M 可能是 1015808 的缩写。[NCU Raw Page](https://docs.nvidia.com/nsight-compute/NsightCompute/index.html#raw-page)

对本例的 32-bit 标量读取，无冲突时每请求一批；32 路冲突时每请求 32 批，额外 31 批。每个 kernel 的 1024 个 block、每 block 8 个 warp、每 warp 4 次 shared 读取，合计 32768 次请求，因此：

```text
1024 × 8 × 4 × (32 - 1) = 1,015,808
```

这一推导与本机本例的读取冲突实测完全一致，不泛化为任意访问宽度或任意 kernel 的计数恒等式。两种 kernel 分别计数，普通 bench 的预热和 21×5 次重复不计入这次 NCU check 结果。<mark>Bank Conflicts 是累计访问效率计数，不是 bank 数量、不同地址个数、内存错误数或总耗时倍数。</mark> 32 路冲突也不直接推出整个 kernel 慢 32 倍。[NCU Shared Memory](https://docs.nvidia.com/nsight-compute/ProfilingGuide/index.html#shared-memory) / [Compute Triage Guide](https://docs.nvidia.com/nsight-compute/ComputeTriage/)

**正式结果与证据边界**

以下重读 10 月 23 日已有 [正式验证日志](../reports/CH09/completed-2026-10-23.txt) 和 [指标 CSV](../reports/CH09/completed-metrics-2026-10-23.csv)，环境为 GTX 1650 / CC 7.5、NVCC 12.9.86、NCU/Compute Sanitizer 2025.2.1.0，shape/dtype 与上文一致。本次总结未重新运行。

| 布局 | 数值校验 | shared 读取冲突 | shared 写入冲突 | 普通 Event 中位数 μs/次 |
| --- | --- | --- | --- | --- |
| stride 32 | 1048576 项 PASS，误差 0 | 1015808 | 0 | 189.683199 |
| stride 33 | 1048576 项 PASS，误差 0 | 0 | 0 | 68.320000 |

两模式 memcheck、racecheck、synccheck 均零错误，racecheck 零 warnings。普通计时与工具运行分开，统计为 21 个批次平均每次启动时间的中位数；本轮比值约 2.776，仅用于当前设备、输入与测量边界，不与 10 月 22 日的临时版或骨架跨运行比较，也不保证所有 GPU 有相同收益。<mark>barrier 保证交接顺序，padding 改善 bank 分布；数据竞争和 bank conflict 分别属于正确性与访问效率问题。</mark>

### 踩坑记录

用户明确暴露的难点是二维线程编号、warp 如何分组、循环中谁负责哪些元素，以及输出一维下标为何对应转置。已用 (x=3,y=2)、block=(16,16) 反例和输入/输出行列对应关系解释，不将这些已讲解例子写成用户独立复述。

用户还追问了限定符、循环展开、硬件分批与大冲突计数。复习时应分清线程组织、shared 逻辑布局、物理 bank 和工具累计口径；避免把每行 32 个线程当成任意 block 的固有规则，把 volatile 当同步，或把 1015808 当成错误数。正式 helper 由 Codex 按要求补全，没有用户误写、编译失败或个人 GUI 操作的证据；不编造这些经历。更深的 bank 调度电路、SASS 后缀与性能归因不新增为首轮门槛。

### 八股自测

不用查看答案，说明本章线程 (x=3,y=2) 的 tid、warp、lane，以及第一轮循环读哪四个输入位置；再解释把 block 换成 (16,16) 时，为什么同一 warp 的 y 可以不同。结合读写代码，说明 output[base+col*32+x] 的行列含义，以及 stride 改变后为什么输出数据保持相同。

手算同一 warp 读取第 0 列时 stride 32/33 的 bank 分布，解释额外 31 批的来源，并用启动规模推导 1015808；指出 NCU 的查看入口、冲突计数与普通计时的区别，以及 volatile、barrier、padding 各自负责什么。以上为后续验收问题，不把已有讲解或 Codex 验证计为个人掌握。
