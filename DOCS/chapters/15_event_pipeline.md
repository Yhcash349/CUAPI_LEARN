# Ch15：用 Event 接力，让下一块上传与当前块计算重叠

Event 可以先理解为 GPU 队列中的完成标记：上传队列经过标记后，计算队列才允许使用这一块输入。上一章的两个任务完全独立，本章给拷贝和计算加上必要的依赖，再让不同数据块有机会重叠。

对应 [PLAN](../PLAN.md) 阶段 C，计划 45～60 分钟。独立源码为 [CH15/event_pipeline.cu](../../CH15/event_pipeline.cu)，2026-11-03 已按用户要求由 Codex 补全两处关键 TODO；下文保留原练习路线供复习。host 分配、输入、CPU reference、双缓冲和计时均已提供；不需要从零写流水框架。状态、辅助程度与学习验收统一在 [RECORD](../RECORD.md)。

## 先预测：什么能重叠，什么必须等待

先花约 5 分钟看这条数据流。每个数据块都必须完成 H2D，kernel 才能读它；kernel 写完，D2H 才能回读。一个块内的这三个步骤仍然有先后，流水利用的是不同块之间的独立性。

```text
一块：H2D(j) → ready(j) → kernel(j) → D2H(j) → done(j)

serial：块0整块完成 → 块1整块完成 → 块2整块完成 → …

pipeline 的可行关系（不是实测比例图）：
upload ：H2D(0) → H2D(1) → 等 done(0) → H2D(2) → …
compute：等 ready(0) → kernel(0) → D2H(0)
                     → 等 ready(1) → kernel(1) → D2H(1) → …
```

预测 `H2D(1)` 能否与 `kernel(0)` 重叠；`H2D(0)` 能否与读取这份输入的 `kernel(0)` 重叠；如果块 2 覆盖槽 0 时块 0 的 kernel 尚未读完，会发生什么？最后想想：去掉每块的 CPU 等待后，GPU 为什么仍会遵守依赖？

两种调度使用相同的 pinned host 数组、两条 nonblocking stream、两个 device 槽位和同样的拷贝/kernel。**唯一对照变量是 `run_batch()` 中每块结束后是否额外让 CPU 等待 `done`**。serial 等，pipeline 连续提交，最后统一等待。不是把某一块有依赖的三步强行并发。

## 从一个线程和一个槽位读代码

约 10 分钟阅读 `Slot`、`repeated_add()` 和 `run_batch()`。固定 8 块输入，每块 N=262147、float32、block=256、grid=1025，每项加 256 次 0.125。每块 H2D 和 D2H 各 1048588 字节，最后一个 block 只有 3 个有效线程。不同块输入带有不同偏移，便于发现误读旧数据。CPU 用 double 计算 reference，全量检查 2097176 项；本输入的 /16 数及累加过程可以精确表示，因此要求误差为零，这不是通用浮点容差。

例如块 2 的 block 0/thread 3，局部 `i=3`，读 `slots[0].input[3]`，计算后写 `slots[0].output[3]`，最终回到 `host_output[2*kN+3]`，即第 524297 项。块 0 和块 2 的 host 地址不同，但 `chunk % 2` 让它们轮流使用同一对 device 数组。必须先保护旧块的使用期，才能复用这块显存。

`Slot` 的 input/output 是 global memory，供不同 kernel 和拷贝任务使用，不是 block 内的 shared memory。两个槽位合计 device 分配 4194352 字节。host 端为全部输入和输出各保留 8388704 字节，合计约 16 MiB；整批完成前 CPU 不修改输入、不读写输出。这里固定完整 host 数组是为了把练习集中在 device 槽位复用，不要求实现 CPU 生产者/消费者。

**pinned memory 是固定在内存中的 host 缓冲，使 CUDA 能直接安排异步传输。** 骨架用 `cudaMallocHost` 分配、`cudaFreeHost` 释放。它没有把数组放进显存，也不会自动建立依赖。普通 `std::vector` 的 pageable 内存不能直接当作本实验可靠的异步重叠前提；`cudaMemcpyAsync` 的名字也不保证任何场景下 CPU 调用都立即返回。[CUDA 12.9：拷贝与计算重叠条件](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#overlap-of-data-transfer-and-kernel-execution)

## 两个方向的 Event 接力

原练习约 15～20 分钟完成两个 helper，不改 kernel、shape 或分配逻辑；当前均已补全。本机 Toolkit 12.9 的签名是：

```cpp
cudaError_t cudaEventRecord(cudaEvent_t event, cudaStream_t stream = 0);
cudaError_t cudaStreamWaitEvent(cudaStream_t stream, cudaEvent_t event,
                               unsigned int flags = 0);
cudaError_t cudaEventSynchronize(cudaEvent_t event);
```

`Record` 把标记提交到指定 stream，覆盖这次调用之前已提交到该 stream 的工作。CPU 的 Record 返回并不代表设备已到达标记。`StreamWaitEvent` 给目标 stream 后续工作加上设备依赖；CPU 不需要先同步到 Event 完成，再提交后续工作。`EventSynchronize` 则让 CPU 等到 Event 覆盖的工作完成。这三者的角色不同。[CUDA Runtime 12.9：Event](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART__EVENT.html)、[Stream](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART__STREAM.html)

原 `TODO(1)` 在 `wait_for_input(compute, ready)`：把 `cudaEventSynchronize` 安全占位改成目标 stream 对 Event 的等待，flag 用 0，通过 `CUDA_CHECK` 检查状态后返回 true。当前实现为 `CUDA_CHECK(cudaStreamWaitEvent(compute, ready, 0))`。这里的目标是 compute，标记是 ready。host 已经在 upload 提交 `H2D → Record(ready)`，所以 compute 的 kernel 只有在输入搬完后才执行。kernel 后的 D2H 与它在同一 stream，无需再加 Event。

原 `TODO(2)` 在 `wait_for_slot(upload, done)`：用同一个 API，目标换成 upload，标记是 done，检查状态后返回 true。当前实现为 `CUDA_CHECK(cudaStreamWaitEvent(upload, done, 0))`。done 放在旧块 D2H 后面，表示这个槽位整块工作已结束；后续 H2D 才能覆盖槽位。只要等 kernel 读完就足以保护 input，本骨架统一等到 D2H 结束，以整槽生命周期组织双缓冲，避免引入更多标记。首次使用槽位时没有旧块，不能依赖一个尚未 record 的 Event 来保护旧工作。

把块 0～2 代入循环：块 0 使用槽 0，块 1 使用槽 1；提交块 2 的 H2D 前，upload 先等槽 0 的旧 done。每次 **Record 已在 CPU 调用顺序上发生，才提交相应 Wait**；Wait 绑定调用时最近一次 Record 覆盖的工作，后续重录同一个 Event 不会把已提交的等待改成等待未来一轮。这使两个槽位可以循环使用，不需要每块创建新 Event。[Event 重录与等待语义](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART__EVENT.html)

ready/done 都用 `cudaEventDisableTiming` 创建，本章用它们表达依赖，不调用 `cudaEventElapsedTime`。不要用一条 stream 上的两个标记直接代表另一条 stream 的全部工作；本章整批耗时用完成边界明确的 host timer，GPU 是否重叠看 NSYS。

原来未补 TODO 的骨架用 CPU 等待保证数据安全，因此数值仍应 PASS；但两个 helper 返回 false，程序打印 INCOMPLETE、退出 1，并拒绝计时。只补一处同样不能通过。当前正式版已替换两处占位。返回 true 是练习完成声明，不能单独证明正确调用了 API；需核对实现和 timeline。不要只改返回值或直接删掉等待，也不要以“这次算对”证明依赖足够。

## 编译、检查与计时

约 10～15 分钟执行以下命令。修改后重新编译；如果设置过强制同步，先执行 `unset CUDA_LAUNCH_BLOCKING`，程序会拒绝非 unset/0 的设置。

```bash
mkdir -p build/CH15
nvcc -std=c++17 -O2 -arch=sm_75 -lineinfo -Xcompiler=-Wall,-Wextra -Xptxas=-v CH15/event_pipeline.cu -o build/CH15/event_pipeline
./build/CH15/event_pipeline check
```

原骨架预期为两种调度全量数值 PASS、device_event_waits INCOMPLETE、退出 1；当前两处已补全，应全部 PASS、退出 0。通过后再运行：

```bash
compute-sanitizer --tool memcheck --padding 32 --error-exitcode 99 ./build/CH15/event_pipeline check
./build/CH15/event_pipeline bench
```

memcheck 检查本例 global 访问的内存安全；其零错误不证明跨 stream 没有逻辑竞争。依赖还需结合源码和队列顺序核对。没有 shared-memory 交换和 block barrier，不把 racecheck/synccheck 加作本章必修证据。

bench 每种调度先校验一次、预热 3 次，再测 21 个独立整批样本，每批处理 8 块；每次完成后在计时外全量校验。`host_batch_median_us` 从提交本批第一个操作之前，测到两条 stream 都等待完成之后，**包括 H2D、kernel、D2H、Event 操作、CPU 提交与完成等待**。分配、输入生成、哨兵准备和 CPU 校验在外；不除以 8 冒充单 kernel 时间，也不称作整个程序耗时。即使两种调度没有加速，只要正确、依赖完整并能解释 trace，就是有效实验。

## 用 NSYS 看不同数据块的重叠

补全并通过 check 后，独立采集两份报告。下面输出名需尚不存在，已有同名文件时改后缀，不覆盖历史证据。

```bash
mkdir -p reports/CH15
nsys profile --trace=cuda --sample=none --cpuctxsw=none --force-overwrite=false -o reports/CH15/serial_01 ./build/CH15/event_pipeline trace serial
nsys profile --trace=cuda --sample=none --cpuctxsw=none --force-overwrite=false -o reports/CH15/pipeline_01 ./build/CH15/event_pipeline trace pipeline
nsys stats --report cuda_api_sum,cuda_gpu_kern_sum,cuda_gpu_mem_time_sum,cuda_gpu_trace reports/CH15/pipeline_01.nsys-rep
```

每份 trace 共 40 次 kernel、40 次 H2D 和 40 次 D2H：正确性批次 8 次、三批预热 24 次、最后目标批次 8 次。**只看最后 8 次 kernel 及对应的最后 8 次 H2D/D2H**；其他 memset 是计时外哨兵准备。在 CUDA HW 的 stream 行找上传队列和计算队列，借助 Correlation ID 对应 CPU 拷贝/launch 与 GPU 活动。每条队列内部均保序，因此各自末尾 8 个同类活动依次对应块 0～7。

先确认每块的 `H2D(j)` 结束后 `kernel(j)` 才开始，`kernel(j)` 结束后 `D2H(j)` 才开始。再比较 `H2D(j+1)` 与 `kernel(j)` 的 GPU 区间是否相交；串行应没有跨块重叠，流水可能有。对同一槽位还要核对 `D2H(j)` 完成后 `H2D(j+2)` 才开始。各块 kernel 在同一个 compute stream，所以本实验不追求 kernel 与 kernel 重叠；D2H 也在 compute，不承诺完整三阶段并发。

两个区间 `[s1,e1]`、`[s2,e2]` 的交集为 `max(0,min(e1,e2)-max(s1,s2))`。只在同一报告的 GPU 活动之间比较端点；不把 CPU API 条的时长当作拷贝时间，不做跨 CPU/GPU 时钟的精确延迟分解。profiler 增加开销，trace 模式打印的时间不能当普通 bench 结果。

`asyncEngineCount>0` 和 pinned memory 提供重叠条件，不保证本例每对活动都重叠。没有重叠时核对两处等待的目标、是否残留每块 CPU 同步、强制同步开关与实际 stream；如实记录，不为得到预设加速扩展调参。本机曾核验 CLI NSYS 2026.4.1 与默认 Linux GUI 2025.1.3 不匹配，需用 2026.4.1 或更新 GUI 打开新报告，见 [环境说明](../ENVIRONMENT.md#2026-11-02-ch13-gui-与设备-event-trace-核验)。本章不追加 GUI 安装。

## 用自己的话验收

最后约 10 分钟，沿块 0～2 解释 ready 与 done 的记录位置、哪个 stream 等待谁，以及块 2 为什么不能直接覆盖槽 0。指出两处 TODO 和 serial/pipeline 对照的唯一开关，再用块 2 的 block 0/thread 3 解释 device 槽位与 host 地址。

实际运行并全量检查，通过 memcheck，在 timeline 指出同一块的必要顺序与不同块是否重叠；说明 pinned memory、Event、CPU 同步各解决什么问题，普通 host_batch 覆盖哪些工作。到一小时仍未完成就记录阻塞，不要求特定加速比，不扩展 CPU 线程池、三阶段流水、Graph 或框架工程。Codex 教学预检不代替个人运行和独立解释。

## Codex 教学预检：2026-11-02（生成时的历史记录）

现场复核 GTX 1650 / CC 7.5 / 14 SM、asyncEngineCount=2、concurrentKernels=1、KMD 610.88、NVCC 12.9.86、Compute Sanitizer 2025.2.1.0、NSYS 2026.4.1，CUDA_LAUNCH_BLOCKING unset。正式骨架与仅补两处 helper 的临时版均编译无警告、无 spill；ptxas 报告 kernel 每线程 8 registers、0 barriers。

两版 serial/pipeline 均全量检查 2097176 项，数值 PASS、最大绝对误差 0；memcheck（padding=32）均零错误。正式骨架 check、bench 和 memcheck 命令退出 1，因为两处 TODO 保留、程序主动拒绝实验计时；工具的 `Target application returned an error` 对应应用退出 1，并非检出了内存错误。临时补全版将两个 helper 改为检查 `cudaStreamWaitEvent(target,event,0)` 并返回 true，check、memcheck、bench 和两份 NSYS 采集/导出均退出 0。

临时版独立普通 bench：warmup=3、samples=21、每样本整批 8 块，host_batch 中位数 serial=4481.916 μs、pipeline=2990.141 μs。此范围包含 H2D、kernel、D2H、Event 操作及 host 提交/等待；只描述本机该次测量，不把差值全部归因于拷贝重叠。

两份独立 NSYS 报告各含 40 次 kernel、40 次 H2D、40 次 D2H，目标均为各类活动最后 8 次。GPU 端点和 Correlation ID 已导出 CSV；下表各行属于不同运行，绝对时间轴不能拼接，时间也不能与普通 bench 混算。

| 目标批次 | H2D / compute stream ID | H2D(下一块) 与 kernel(当前块) 相交次数 | 这 7 对区间的交集总和 μs | 第一块 H2D 开始到末块 D2H 结束 μs |
| --- | --- | --- | --- | --- |
| serial | 13 / 14 | 0 / 7 | 0 | 4743.324 |
| pipeline | 13 / 14 | 7 / 7 | 632.193 | 3654.726 |

pipeline 这 7 对的交集依次为 82.400、92.608、91.841、92.480、88.640、92.064、92.160 μs；本次确实出现了不同块的上传与计算重叠。另有 H2D/D2H 区间交集总和 51.040 μs，不将它与前述数值相加冒充总加速。两种调度全部 8 块都满足 H2D 结束≤kernel 开始、kernel 结束≤D2H 开始，6 次复用都满足旧 D2H 结束≤同槽新 H2D 开始。这些端点是本次 trace 的观察，依赖保证来自源码 Event 链，不能用单次图替代语义证明。

两份完整 trace 各有 70 次 `cudaStreamWaitEvent`，即 5 批 ×（8 次输入等待+6 次槽位等待）；serial 另有 40 次 `cudaEventSynchronize`，pipeline 为 0，符合对照开关。pipeline 的 Event 仍约束设备顺序，但没有让 CPU 逐块同步。

原始命令、源码 SHA-256、编译/校验/计时输出、退出码和时间线核对摘要见 [预检日志](../../reports/CH15/preflight-2026-11-02.txt)。保留 [serial NSYS](../../reports/CH15/preflight-serial-2026-11-02.nsys-rep)、[pipeline NSYS](../../reports/CH15/preflight-pipeline-2026-11-02.nsys-rep)、对应 [serial SQLite](../../reports/CH15/preflight-serial-2026-11-02.sqlite)、[pipeline SQLite](../../reports/CH15/preflight-pipeline-2026-11-02.sqlite) 与 [目标批次 CSV](../../reports/CH15/preflight-2026-11-02-timeline.csv)。`nsys stats` 读取 rep 时因导出文件时间戳检查拒绝已有 SQLite，改为直接读取同一 `.sqlite` 后成功；原文件均保留。

上述 profiler 与普通性能数据来自当时的临时补全版；生成时正式源码及 build 保留两处学习 TODO，当前正式补全见下节。临时源码、可执行文件与路径指示文件已清理。该轮 GUI、NCU、racecheck、synccheck NOT RUN；未引入新依赖或调整课程范围，Ch15 保持 RUNNING，个人学习用时未记录。

## 正式补全与验证：2026-11-03

按用户要求，Codex 已完成两处练习：`wait_for_input()` 检查 `cudaStreamWaitEvent(compute, ready, 0)`，让 compute 后续工作等输入就绪；`wait_for_slot()` 检查 `cudaStreamWaitEvent(upload, done, 0)`，让 upload 后续工作等旧槽位用完。两者成功后返回 true，移除源码 TODO 与 CPU 等待占位。serial 的每块 CPU 等待、整批完成等待、kernel、输入和计时范围均保持原设计，正式 build 已重新编译。

正式环境为 GTX1650 / CC7.5 / 14SM、asyncEngineCount=2、concurrentKernels=1、KMD610.88、NVCC12.9.86、Compute Sanitizer2025.2.1.0，CUDA_LAUNCH_BLOCKING unset。编译无警告、无 spill，ptxas 为8 registers/thread、0 barriers。两种调度的设备等待状态及各2097176项全量数值均PASS、最大绝对误差0；memcheck（padding=32）零错误，编译/check/工具检查/bench均退出0。

独立普通 bench 为 warmup=3、samples=21、每批8块，host_batch 中位数 serial=4410.856μs、pipeline=2938.147μs。仍包含传输、计算、Event操作和host提交/等待，不是单kernel GPU时间；不凭耗时单独证明重叠，不与历史临时版作性能A/B。本轮NSYS、NCU、GUI、racecheck、synccheck均NOT RUN，前节报告只保留为历史预检证据。

正式源码SHA-256、完整命令、输出和退出码见 [正式补全日志](../../reports/CH15/completed-2026-11-03.txt)。实现与验证由Codex完成，无新依赖或临时实现文件；个人运行/读图与独立解释待验收，Ch15仍RUNNING，实际学习与工程执行耗时未记录。

## 正式实验与流水证据：2026-11-05

本次使用当前正式源码重新编译和运行，SHA-256与11月3日补全版一致。现场GTX1650 / CC7.5 / 14SM、asyncEngineCount=2、concurrentKernels=1、KMD610.88、NVCC12.9.86、NSYS2026.4.1，CUDA_LAUNCH_BLOCKING unset；输入、kernel、两个slot和两条stream均保持本章配置。全量2097176项，两种调度均数值PASS、最大绝对误差0；编译无警告、无spill，kernel为8 registers/thread、0 barriers。

独立普通bench先校验、预热3批，再测21批并逐批校验，host_batch中位数serial=4473.431μs、pipeline=3000.325μs，耗时减少32.930%，串行/流水耗时比1.491。每批8块，包含host提交、Event操作、H2D、计算、D2H和完成等待；不把它当单kernel GPU时间。下面NSYS数据来自另外两次独立采集，不能与普通bench混算。

![当前正式版GPU时间线，H为上传、K为计算、D为回读，数字及颜色表示chunk](../../reports/CH15/experiment-2026-11-05-timeline.png)

图中的矩形直接来自NSYS导出的GPU起止时间。每个报告分别以目标批次首个H2D开始为零；上图串行，下图流水，H/K/D后的数字为chunk编号。compute行同时包含kernel和D2H，D2H带斜线；两个slot按chunk奇偶复用，不对应图中两行，两行表示固定的upload/compute stream。

| 目标批次指标 | serial | pipeline |
| --- | --- | --- |
| upload / compute stream ID | 13 / 14 | 13 / 14 |
| 当前块kernel与下一块H2D相交次数 | 0/7 | 7/7 |
| 上述交集总和 | 0μs | 617.060μs |
| 首块H2D开始至末块D2H结束的GPU跨度 | 4635.592μs | 3097.683μs |
| 每块必要先后顺序 | 8/8符合 | 8/8符合 |
| 同槽位覆盖前旧块完成 | 6/6符合 | 6/6符合 |

以pipeline的chunk0和chunk1为例，kernel0位于234.145～326.082μs，H2D1位于161.761～321.762μs，交集为234.145～321.762μs，长87.617μs。kernel0读取slot0，同时H2D1写slot1，两个地址空间不同，因而可以同时推进。serial中kernel0位于202.783～292.574μs，H2D1要到554.717μs才开始，无交集。这是本次流水重叠的直接设备端证据。

再看slot0复用：pipeline的D2H0在543.843μs结束，H2D2在610.372μs才开始，符合旧done完成后新上传才能覆盖同槽位的要求。所有8个chunk均满足H2D完成后kernel才开始、kernel完成后D2H才开始，所有6次槽位复用也符合旧D2H完成后新H2D开始。ready连接同一个chunk的上传与计算，done保护不同chunk对同一个slot的复用；它们保留了必要顺序，流水利用不同chunk之间的独立性。

两份trace各有40次kernel、40次H2D、40次D2H；目标为各类最后8次。每份都有70次cudaStreamWaitEvent，对应5批×（8次ready等待+6次done等待）；serial另有40次CPU cudaEventSynchronize，pipeline为0。取消逐块CPU等待让后续块能提前提交，Event仍约束GPU执行。所有kernel都在同一compute队列，不能把本例解释为两个kernel并行或完整三阶段同时执行。

本次617.060μs的上传/计算交集，不能直接当作普通bench节省的1473.106μs：两者属于不同运行，普通host范围还包括提交和等待间隙等开销。此次实际测到加速和重叠，只对本GPU、本输入与这轮测量负责，不承诺每轮或其他GPU有相同比例。

完整命令、版本、源码哈希和原始输出见 [实验日志](../../reports/CH15/experiment-2026-11-05.txt)；可复查 [serial NSYS](../../reports/CH15/experiment-serial-2026-11-05.nsys-rep)、[pipeline NSYS](../../reports/CH15/experiment-pipeline-2026-11-05.nsys-rep)、[目标活动CSV](../../reports/CH15/experiment-2026-11-05-timeline.csv)、[摘要JSON](../../reports/CH15/experiment-2026-11-05-summary.json) 与 [提取绘图脚本](../../reports/CH15/experiment-2026-11-05-analysis.py)。PNG另附同名SVG，两个SQLite导出也保留。没有修改CUDA源码或覆盖历史报告；本轮GUI、NCU、memcheck、racecheck、synccheck NOT RUN，11月3日同哈希源码的memcheck零错误仅作既有证据。所有本轮命令退出0；实验与图形均由Codex完成，个人操作和独立解释待验收，Ch15保持RUNNING。
