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
