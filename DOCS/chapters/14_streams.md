# Ch14：把两个独立任务放进同一条或两条队列

stream 可以先理解为 GPU 工作的有序队列：同一条队列里的工作按提交顺序执行；放到两条队列后，两个任务有机会重叠，但不能据此假定谁先完成。本章从 Ch13 的“CPU 提交与 GPU 完成不同步”继续，观察两个 kernel 之间的顺序。

对应 [PLAN](../PLAN.md) 阶段 C，计划 45～60 分钟。源码为 [CH14/streams.cu](../../CH14/streams.cu)，2026-11-02 已按用户要求由 Codex 补全两处 TODO；下文保留原练习路线供复习，进度、辅助程度与验收统一在 [RECORD](../RECORD.md)。复用 Ch13 的逐元素累加、Ch03 的错误检查和 Ch05 的 NSYS 阅读方法，本章只增加显式 stream 的使用与并发条件。跨 stream Event 依赖、pinned memory 和传输流水留到 Ch15。

## 先预测：CPU 先提交 A，GPU 就一定先完成 A 吗

花约 5 分钟预测以下两种提交方式。A、B 使用同一个 kernel，处理各自的输入和输出，没有数据依赖；图只表示顺序关系，不是按比例绘制的实际时间线。

```text
same： CPU：提交 A 到 s0 → 提交 B 到 s0 → 等待 s0
       s0：A → B

split：CPU：提交 A 到 s0 → 提交 B 到 s1 → 等待 s0 → 等待 s1
       s0：A
       s1：B    （可能重叠，也可能先后执行）
```

预测同 stream 的两次 kernel 是否会重叠，不同 stream 是否一定更快；CPU 先等待 s0，再等待 s1，会不会让 GPU 的 B 必须等 A 完成才开始？再想想，创建两条 stream 是否等于把 GPU 的 SM 分成两组。

[CUDA Programming Guide 12.9：Streams](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#streams) 规定同 stream 保序，不同 stream 之间可能乱序或并发，但不能依赖这种可能性保证正确性。CPU 调用的先后本身没有为两个独立 stream 建立设备端完成依赖。若 B 要读 A 的结果，就需要明确依赖；本章通过独立数据避开这个额外问题。

## 从一个线程读数据流

约 10 分钟阅读 `repeated_add()`、`launch()` 和 `run_pair()`。每个任务固定 N=4099、float32、block=256、grid=17，每个线程把自己的 b 加 8192 次。末尾 block 只有 3 个有效线程，其余通过边界保护退出。选择较小 grid 是为了留下观察并发的机会；不要在对照时同时改 shape、block 或重复次数。

host 分配 a、b、c 三个 device 数组，每个数组长 8198。任务 A 使用前 4099 项，任务 B 的指针整体向后移动 4099 项。例如 B 的 block 0/thread 3 仍算局部 i=3，但写的是整个 c 数组的第 4102 项；A 的相同线程写第 3 项。二者既不读对方的输出，也不写同一位置。三个 device 数组合计 98376 字节，输入和回读全部放在实验计时之外。

CPU reference 用 double 直接算 `a + 8192*b`，全量检查两个任务的 8198 项。输入为小范围的 /16 数，本实验中所有中间累加可被 FP32 精确表示，因此要求误差为零；这不是任意浮点加法的通用误差标准。每次运行前给输出写 NaN 哨兵，以暴露漏写。

两种调度都创建 s0、s1 两条显式队列，只改变第二个 kernel 的目标：same 使用 s0，split 使用 s1。`run_pair()` 先连续提交两个 kernel，再让 CPU 等实际使用的 stream 完成。**等 s0 时，已提交给 s1 的工作仍可在 GPU 上推进；这不是“先做完 A，才提交 B”。** 若把等待插到两个 launch 中间，就会改变实验。

stream 是提交顺序与依赖的组织方式，不是固定的一组 SM。GPU 调度 kernel 的 block，资源、任务长度、提交间隙与环境都会影响是否看到重叠。`concurrentKernels=1` 只表明设备具有并发 kernel 的能力，不保证本程序一定并发。[官方并发能力说明](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#concurrent-kernel-execution)

## 动手：创建队列，再把 kernel 放进去

原练习约 15～20 分钟完成两处 TODO，无需改 kernel 或输入；当前两处均已补全。

`TODO(1)` 位于 `create_work_stream()`：使用 `cudaStreamCreateWithFlags`，将 handle 写到传入的地址，flag 选择 `cudaStreamNonBlocking`，并返回 API 状态。main 已负责调用两次、检查返回值、最终销毁队列。本机头文件签名为：

```cpp
cudaError_t cudaStreamCreateWithFlags(cudaStream_t* pStream, unsigned int flags);
```

这里 `cudaStreamNonBlocking` 表示新队列不与 legacy 默认 stream 隐式同步，不表示 kernel 必然并发，也不会让后面的 `cudaStreamSynchronize()` 变成不等待。骨架在两个 launch 之间不做分配、拷贝或默认 stream 操作；准备阶段的同步都在计时之前。[CUDA Runtime 12.9：Stream Management](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART__STREAM.html)

`TODO(2)` 位于 `launch()`：把 `target` 改为调用方传入的 `stream`。启动配置的第四项指定队列，第三项仍是动态 shared 字节数 0：

```cpp
repeated_add<<<grid, block, 0, target>>>(...);
```

只创建 stream 并不会自动改变 kernel 的目标。骨架返回实际使用的 `target` 来检查路由，再用 `cudaStreamSynchronize(target)` 等该队列此前提交的工作完成并检查执行错误。`cudaGetLastError()` 仍只检查启动错误，不能代替完成等待。

原骨架未补全时，nullptr 是默认 stream 占位，两个任务仍会完成数值计算；程序检查到尚未创建两条显式 nonblocking stream，或启动目标不匹配时，打印 `INCOMPLETE/FAIL`、拒绝计时并退出 1。只补其中一处也不能通过。当前正式版已移除占位。数值 PASS 不能证明用了两条队列，数值 PASS 与 memcheck 零错误也不能证明两个 kernel 重叠。

## 编译、校验与普通计时

在项目根目录执行，每次修改后重新编译：

```bash
mkdir -p build/CH14
nvcc -std=c++17 -O2 -arch=sm_75 -lineinfo -Xcompiler=-Wall,-Wextra -Xptxas=-v CH14/streams.cu -o build/CH14/streams
./build/CH14/streams check
```

原骨架未补 TODO 时预期为数值 PASS、配置 INCOMPLETE、退出 1；当前两处已补全，same/split 的数值及路由均应 PASS，程序退出 0。若 `CUDA_LAUNCH_BLOCKING` 非 unset 或 0，程序主动拒绝运行；先 `unset CUDA_LAUNCH_BLOCKING`，避免强制同步改变实验前提。然后执行：

```bash
compute-sanitizer --tool memcheck --padding 32 --error-exitcode 99 ./build/CH14/streams check
./build/CH14/streams bench
```

memcheck 检查本例 global 访问的内存安全；两个任务无共享地址，不引入 shared-memory racecheck 或 block-barrier synccheck 作为本章门槛。工具检查与普通 bench 分开运行。

bench 每种配置先全量检查一次、预热 3 次，再测 21 个独立样本，每个样本包含一对 kernel。`host_pair_median_us` 是 CPU 从第一次 launch 前到两条实际使用队列均等待完成后的耗时中位数，**不是单个 kernel 的 GPU 时间，也不是整个程序耗时**。它包含两次提交、错误检查和 host 等待开销；分配、输入传输、哨兵准备、D2H 和逐样本 CPU 校验在范围之外。

Ch04 的同 stream Event 不能直接拿一条队列的 stop 来代表另一条队列也完成。本章用等待两条队列后的 host elapsed 观察整对工作，用 NSYS 看 GPU 区间；跨 stream Event 接力到 Ch15。比较耗时可以描述本机这次运行的表现，不能单靠它证明设备端重叠或固定的加速比例。

## 用 NSYS 找同队列顺序与不同队列的重叠

约 10～15 分钟完成运行和读图。补全、重新编译并通过 check 后，独立采集两份报告，使用尚不存在的输出名：

```bash
mkdir -p reports/CH14
nsys profile --trace=cuda --sample=none --cpuctxsw=none --force-overwrite=false -o reports/CH14/same_01 ./build/CH14/streams trace same
nsys profile --trace=cuda --sample=none --cpuctxsw=none --force-overwrite=false -o reports/CH14/split_01 ./build/CH14/streams trace split
nsys stats --report cuda_api_sum,cuda_gpu_kern_sum,cuda_gpu_trace reports/CH14/split_01.nsys-rep
```

每份 trace 各有 10 次 `repeated_add`：数值预检 2 次、三轮预热 6 次、目标样本 2 次。**只看最后两次**，用 Correlation ID 将 CPU 的两个 launch 对应到 GPU kernel，展开 CUDA HW 下的 stream 行。same 的两个目标 kernel 应在同一条 stream 上依次执行；split 应分属两条 stream，检查它们的 GPU Start/End 是否交叠。两个同名 kernel 是两次调用，任务 A/B 的身份按 launch 顺序和所属 stream 对应。

若记录为区间 `[startA,endA]`、`[startB,endB]`，交集长度为 `max(0, min(endA,endB)-max(startA,startB))`。这只能证明该次采集的 GPU 执行区间是否重叠，不说明每个时刻有多少 SM 同时服务两个 kernel。两个 CPU launch 条不重叠，也不能据此断定 GPU kernel 不重叠。

若 split 没重叠，先确认目标 stream 不同、两个 launch 之间没有 host 等待、调试强制同步已关闭，再如实记录结果；不为追求加速不断调参数。profiler 有额外开销，其程序打印的时间不作为普通 bench 性能结果。当前本机 CLI 为 NSYS 2026.4.1，默认 Linux GUI 曾核验为 2025.1.3；请用 2026.4.1 或更新 GUI 打开本章报告，参见 [环境记录](../ENVIRONMENT.md#2026-11-02-ch13-gui-与设备-event-trace-核验)。本章不追加 GUI 安装任务。

## 用自己的话验收

最后约 10 分钟，指出两处 TODO 怎样共同决定 kernel 的队列，再用 B 的 block 0/thread 3 解释为什么两个任务没有读写依赖。结合源码说明同 stream 的顺序保证、不同 stream 的并发机会，以及为何 CPU 按顺序等待两条队列不会撤销已经提交的 B。

实际运行并校验，通过 memcheck，在 timeline 指出最后两个 kernel 的 stream 和是否重叠；解释 `concurrentKernels=1` 为何不保证并发、stream 为何不固定对应 SM，以及 host_pair 的计时边界。不要求特定加速比，到一小时仍有阻塞就记录，不扩展成资源调优或流水项目。推理框架也用 stream 组织任务，但有依赖的算子不能仅靠换队列就安全并行。

## Codex 教学预检：2026-11-02（生成时的历史记录）

本轮实测 GTX 1650 / CC 7.5 / 14 SM，设备属性总显存约 4095 MiB（nvidia-smi 显示 4096 MiB）、concurrentKernels=1、KMD 610.88；NVCC 12.9.86、Compute Sanitizer 2025.2.1.0、NSYS 2026.4.1，CUDA_LAUNCH_BLOCKING unset。正式骨架和仅补两处练习的临时版均编译无警告、无 spill，kernel 每线程 10 个寄存器、0 个 barrier。

正式骨架的 same/split 各检查 8198 项，数值 PASS、最大绝对误差 0；memcheck（padding=32）零错误。由于 TODO 未完成，check、bench、memcheck 命令均退出 1，且 bench 拒绝发布计时；这是程序的预期教学状态，不是工具检出内存错误。单独只补创建或只补路由也验证为数值 PASS、实验 INCOMPLETE、退出 1。

临时补全版的 same/split 全量数值、stream 配置与路由通过，最大绝对误差 0；memcheck 零错误，所有完整预检命令退出 0。独立普通 bench 为 warmup=3、samples=21、batch=1，每个样本一对 kernel，host_pair 中位数 same=177.898 μs、split=135.919 μs。这是本机当前配置的一轮测量，包含 host 提交与等待开销，不据此断定性能差全部来自并发。

另行采集两份 NSYS，均包含 10 次 kernel。下表来自各报告的最后两个 GPU kernel，区间的原始时间戳与 correlation 保存在 CSV 中；两份报告属于不同运行，不能把它们的绝对时间轴拼在一起。

| 配置 | A/B 的 stream ID | A/B 的 Correlation ID | A/B GPU 持续时间 μs | 两 GPU 区间交集 μs | 首个开始至最后结束 μs |
| --- | --- | --- | --- | --- | --- |
| same | 13 / 13 | 168 / 170 | 69.276 / 69.020 | 0 | 144.760 |
| split | 13 / 14 | 172 / 174 | 69.823 / 99.039 | 65.919 | 102.943 |

same 在同一 stream 顺序执行；split 的两个 GPU 区间确有重叠。这是该次 trace 的直接观察，不保证每次都重叠或加速，也不意味着每个 SM 都同时运行两个 kernel。表内 GPU 区间与普通 bench 的 host_pair 范围不同，不相加或混算；本章只比较同 GPU 轨迹内的端点，不做跨 CPU/GPU 时钟的精确延迟分解。

完整命令、两版源码 SHA-256、原始编译/检查/计时输出和退出码见 [预检日志](../../reports/CH14/preflight-2026-11-02.txt)。报告为 [same NSYS](../../reports/CH14/preflight-same-2026-11-02.nsys-rep) 与 [split NSYS](../../reports/CH14/preflight-split-2026-11-02.nsys-rep)，对应 [same SQLite](../../reports/CH14/preflight-same-2026-11-02.sqlite)、[split SQLite](../../reports/CH14/preflight-split-2026-11-02.sqlite) 及 [目标区间 CSV](../../reports/CH14/preflight-2026-11-02-timeline.csv)。这些报告使用临时补全版采集；生成时正式 build 对应保留 TODO 的源码，当前正式版验证见下节。临时补全文件已清理；该轮 GUI、NCU、racecheck、synccheck NOT RUN，预检不代表用户个人实现、运行、读图或独立解释通过。

## 正式补全与验证：2026-11-02

按用户“完成TODO1和TODO2”的要求，Codex 已将 `create_work_stream()` 改为返回 `cudaStreamCreateWithFlags(stream, cudaStreamNonBlocking)` 的状态；`launch()` 将传入的 stream 赋给 target，用作第四个启动参数，并返回这个实际目标供检查。已移除源码 TODO 和占位注释，重新编译正式 build。kernel、输入、两种调度和计时边界不变。

本轮正式环境为 GTX1650 / CC7.5 / 14SM、KMD610.88、NVCC12.9.86、Compute Sanitizer2025.2.1.0，CUDA_LAUNCH_BLOCKING unset。编译无警告、无 spill，仍为10 registers/thread、0 barriers。same/split 均为显式 nonblocking stream 配置及启动路由 PASS，全部8198项数值正确、最大绝对误差0；memcheck（padding=32）零错误，check/工具检查/bench均退出0。

独立普通 bench 为 warmup=3、samples=21、batch=1，host_pair 中位数 same=173.116 μs、split=129.053 μs。该时间包含两次 host 提交与完成等待，不是单 kernel GPU 时间，不能单凭它证明重叠；不将其与历史临时版结果作性能 A/B。本轮 NSYS、NCU、GUI、racecheck、synccheck 均 NOT RUN，前节 trace 保持为历史预检证据。

完整命令、正式源码 SHA-256、原始输出和退出码见 [正式补全日志](../../reports/CH14/completed-2026-11-02.txt)。本轮无临时补全文件或新依赖。两处实现和验证由 Codex 完成，个人运行、采集/读图与独立解释待验收，Ch14 仍为 RUNNING。
