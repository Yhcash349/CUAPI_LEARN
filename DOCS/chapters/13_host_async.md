# Ch13：CPU 提交完，不等于 GPU 算完

CPU 把工作交给 GPU 后，可以先继续执行自己的代码，而 GPU 仍在处理刚才的任务。这就是本章要观察的 host 异步：这里的 host 指 CPU，异步描述 CPU 调用返回与 GPU 工作完成之间的关系。

本章对应 [PLAN](../PLAN.md) 阶段 C，计划 45～60 分钟。源码是 [CH13/host_async.cu](../../CH13/host_async.cu)，复用 Ch02 的向量索引、Ch03 的错误检查、Ch04 的 CPU/Event 计时和 Ch05 的 NSYS 读图方法。只增加“提交与完成的区别”和“host 等待的位置”，不提前讲多 stream、pinned memory 或拷贝重叠。2026-10-29 已按用户要求由 Codex 补全 `wait_on_host()`，当前正式 check/bench 应 PASS、退出 0。下文保留原练习路线供复习；进度和验收统一写在 [RECORD](../RECORD.md)。

## 先预测：哪个终点才包含 GPU 计算

先花约 5 分钟看下列顺序。图中的 CPU 与 GPU 行不是按字符长度绘制的时间比例图。

```text
CPU：t0 → launch → t_submit → 记录 stop Event → 等待完成 → t_complete → 回读/校验
GPU：             start Event → repeated_add → stop Event

CPU launch 段：     t_submit - t0
CPU 完成边界：     t_complete - t0
GPU Event 区间：   start Event → stop Event
```

两个 CPU 区间观察同一次 kernel 启动，只改变计时终点。预测：若 launch 很快返回，能说 kernel 很快算完吗？CPU 在什么位置停下来等待？GPU 很短或系统很忙时，两个 CPU 时间是否一定明显不同？先保留自己的答案，再运行对照。

按 CUDA 12.9 的 [API synchronization behavior：Kernel Launches](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/api-sync-behavior.html#kernel-launches)，kernel launch 相对 host 异步；这不保证每次调用都以固定微秒数返回，也不保证返回时 GPU 必然还没完成。首次加载、运行环境和任务长度都会影响观察。异步也不自动代表多个 kernel 并发，本章始终只有默认 stream。

## 从一条输出读程序

用约 10 分钟读 `repeated_add()`、`launch()` 和 `measure()`。固定 `N=65539`、float32、block=256、grid=257，末尾 block 只有 3 个有效线程，其余线程经索引保护退出。三个 device 数组各 `65539×4=262156` 字节，总量远小于本机显存容量。

线程 i 从 `a[i]` 开始，把 `b[i]` 加 2048 次，最后写自己的 `c[i]`。例如 i=0 时，a=-11/16、b=-10/16，输出应为 `a+2048*b=-1280.6875`。CPU 用 double 的直接公式独立生成 reference，检查全部输出；输入特意使用小范围 /16 数，所有中间和都能精确表示，因此本例要求误差为零，不推广到任意 FP32 运算。

重复加法只是把 GPU 工作拉长，便于观察时间边界，并非第二个调参变量，也不是向量加法优化方法。输入、重复次数、grid/block 在三个时间口径中完全相同，不用主动等待若干毫秒的 kernel，不引入线程间合作。

`launch()` 启动 kernel 并执行 `cudaGetLastError()`。后者用于检查启动错误，不等待 GPU 完成；执行阶段错误可能到同步时才报告。主程序先运行一次完整数值预检，再预热 3 次，之后才进入练习的时间边界。

`measure()` 先在计时外清空前序工作，把 start Event 放入默认 stream，再记录 CPU 的 t0。launch 返回后立即记 t_submit，接着提交 stop Event，调用 `wait_on_host()`，最后记录 t_complete。Event 的含义沿用 Ch04：GPU 在同一 stream 中依次经过 start、kernel、stop，CPU 随后读取两点之间的时间。

## 动手：在正确的位置等待

原骨架要求用约 10～15 分钟完成 `wait_on_host()` 中唯一的 `TODO(1)`（现已补全）：把 `return cudaErrorNotReady;` 换成 host 侧设备同步函数的调用及返回。查本机 `cuda_runtime_api.h` 的 `cudaDeviceSynchronize(void)` 签名，确认它无参数、返回 `cudaError_t`；不需要再改 kernel 或计时器。

[CUDA Runtime：cudaDeviceSynchronize](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART__DEVICE.html) 规定该调用等待设备此前请求的工作完成，并能报告此前任务失败。本章从 CPU 调用它；不要与 Ch08 的 `__syncthreads()` 混淆，后者安排一个 block 内的线程协作，无法让 CPU 等待整个 kernel。

原骨架返回的 `cudaErrorNotReady` 是主动设置的“练习未完成”占位，以下描述补全前的行为；当前正式版已移除占位及对应分支。遇到它，程序会在 t_complete 之后安全等待、回读并校验，但拒绝发布计时，退出 1。这样既不会遗留未完成工作，也不会把区间外的收尾冒充区间内等待。不能只把占位改成 `cudaSuccess`：它是状态值，不能让 GPU 完成。骨架还用 `cudaEventQuery(stop)` 采样等待返回附近的完成状态；这个查询只观察、不等待，不能证明任意替代实现都具有等待语义，不要求本章另外掌握 Event 查询 API。

即使省略显式等待，后面的同步 D2H 回读仍可能让最终数值正确。**输出正确只能说明结果已安全取回，不能证明此前 CPU 计时包含 GPU 完成。** 同理，打印文字、固定 sleep 或把等待放到 t_complete 后面，都不能修复已经结束的时间区间。

## 编译、校验，再计时

从项目根目录执行，每次修改源码后都重新编译：

```bash
mkdir -p build/CH13
nvcc -std=c++17 -O2 -arch=sm_75 -lineinfo -Xcompiler=-Wall,-Wextra -Xptxas=-v CH13/host_async.cu -o build/CH13/host_async
./build/CH13/host_async check
```

原骨架未补 TODO 时，数值应 PASS，但显示 `Wait INCOMPLETE` 和 `Experiment INCOMPLETE/FAIL`、退出 1。这是补全前的预期行为。当前正式版 check 应输出 `Completion boundary PASS`、`Experiment PASS`、退出 0。继续运行：

```bash
compute-sanitizer --tool memcheck --padding 32 --error-exitcode 99 ./build/CH13/host_async check
./build/CH13/host_async bench
```

memcheck 检查本例 global 读写的内存安全；没有 shared 交换或 barrier，不为覆盖工具而加 racecheck/synccheck 门槛。检查工具与普通计时分开运行。程序会显示 `CUDA_LAUNCH_BLOCKING`；若它不是 unset 或 0，先 `unset CUDA_LAUNCH_BLOCKING` 再启动程序，否则调试用的强制等待会改变实验前提。

bench 在全量数值预检、3 次预热和一次完成边界试运行后，收集 21 个单次启动样本。每个样本开始前等待前序工作结束，回读/校验放在样本末端之外，避免不断堆积队列。三列分别取各自的中位数：

| 输出 | 包含什么 | 如何解读 |
| --- | --- | --- |
| `host_launch_median_us` | CPU launch 和紧随其后的错误检查 | 提交这一段的 host elapsed，不能当成 kernel 执行时间 |
| `host_complete_median_us` | 同一起点到等待返回，还包含 stop Event 提交及 host 调用开销 | CPU 走到 GPU 完成边界所需时间 |
| `event_median_us` | 默认 stream 中两 Event 之间的 GPU elapsed | 与 Ch04 相同，短任务可能受 host 提交间隙影响，不是严格的纯指令耗时 |

分配、H2D/D2H、CPU reference 和校验都不在这些区间内。start Event 的 CPU 提交位于 t0 之前；CPU 与 GPU 时钟、采样端点不同，因此两种口径不必相等。三列中位数未必来自同一样本，不把中位数差额当成精确的“等待耗时”，更不能用“launch 比完成快多少倍”声称 GPU 加速了多少倍。这里运行的始终是同一个 kernel。

## 用 NSYS 对应 CPU 与 GPU

约 10～15 分钟完成运行和读图；trace 模式只有数值预检、3 次预热和 1 次测量，共 5 次 kernel。补全、编译、check 通过后，另开一次 profiler 运行，使用尚不存在的输出名：

```bash
mkdir -p reports/CH13
nsys profile --trace=cuda --sample=none --cpuctxsw=none -o reports/CH13/host_async_01 ./build/CH13/host_async trace
nsys stats --report cuda_api_sum,cuda_gpu_kern_sum,cuda_gpu_trace reports/CH13/host_async_01.nsys-rep
nsys-ui reports/CH13/host_async_01.nsys-rep
```

在 GUI 中找到最后一次 `repeated_add`，用 Correlation ID 对应 CPU 的 `cudaLaunchKernel`。比较 CPU launch API 的短条、GPU kernel 条和之后的 `cudaDeviceSynchronize` 等待；同一个 kernel 的 CPU 提交区间与 GPU 执行区间是不同活动。不要把第一轮加载/初始化开销混进稳态结论，也不要把 API 汇总表中所有 synchronize 时间都归给最后一次测量。trace 的程序输出只作此次观察，普通性能数值使用独立 bench。

## 用自己的话验收

最后约 10 分钟，不看答案指出 t0、t_submit、t_complete 分别在何处，解释为何 launch 后读取 CPU 时钟可能漏掉 GPU 执行，为什么回读后数值 PASS 仍不能证明旧计时正确。再说明 `cudaGetLastError()`、host 同步与 block barrier 各做什么，以及 Event 时间为什么与 CPU 完成时间不必相等。

验收需要 TODO 生效、全量正确性及 memcheck 通过，并能对应代码或 timeline 解释“提交返回与执行完成”。没有固定耗时比门槛；一次短任务可能来不及观察到明显差距。到一小时仍未完成则记录阻塞，不扩展多队列/传输重叠。本章的实际联系是：推理框架调用返回得快，并不能单凭这一点推断 GPU 运算耗时短。

## Codex 教学预检：2026-10-28

现场环境为 GTX 1650 / CC 7.5 / 14 SM / 4096 MiB，KMD 610.88，NVCC 12.9.86、Compute Sanitizer 2025.2.1.0、NSYS 2026.4.1；`CUDA_LAUNCH_BLOCKING` unset。正式骨架及仅补等待 API 的临时版均编译无警告、无 spill，编译报告每线程 10 个寄存器、0 个 barrier。两版均对全部 65539 项校验通过、最大绝对误差 0；memcheck（padding=32）均零工具错误。骨架 check/bench/工具运行退出 1，原因是练习未完成，并非 memcheck 检出错误。临时补全版均退出 0。

独立普通 bench，warmup=3、samples=21、batch=1：

| 时间口径 | 中位数 μs |
| --- | --- |
| CPU launch 段 | 15.018000 |
| CPU 到完成边界 | 228.564000 |
| 同 stream GPU Event | 205.311999 |

本轮 CPU 很快提交，但等到 GPU 完成需要更久，与本章异步语义相符；不将数值比值称为算法加速。只适用于本机、本 shape、本轮运行，不承诺固定延迟。

NSYS 单独采临时补全版 trace，5 次 kernel；最后一次 Correlation ID=141，CPU launch API 长 10.309 μs，GPU kernel 长 160.161 μs，后续同步 API 长 193.057 μs。该 WSL 报告的 CPU/GPU 绝对时间端点存在约 8 μs 的错位（同步返回与 GPU 结束），不据此推断同步提前返回，也不把两条轨迹端点相减当成精确等待时间。以上按 API/kernel 各自持续时间和 correlation 阅读；普通 bench 与 profiler 不作性能 A/B。GUI 本次 NOT RUN，CLI/SQLite 读取已验证。NCU、racecheck、synccheck 均 NOT RUN，不增加本章门槛。

原始命令、两版 SHA-256、补全差异、编译信息、输出和退出码见 [预检日志](../../reports/CH13/preflight-2026-10-28.txt)，可重读 [NSYS 报告](../../reports/CH13/preflight-2026-10-28.nsys-rep)、[SQLite](../../reports/CH13/preflight-2026-10-28.sqlite) 和 [时间关联摘要](../../reports/CH13/preflight-timeline-2026-10-28.csv)。临时补全源码及二进制已清理，当时正式 build 对应保留 TODO 的骨架，现已由下文的正式补全版替代。用户个人运行与独立解释待验收；Codex 预检不代表用户已掌握。


## TODO 正式补全与验证：2026-10-29

按用户要求，Codex 将 wait_on_host() 实现为 `return cudaDeviceSynchronize();`，CPU 在 t_complete 之前等待当前设备此前请求的工作完成，调用方检查返回状态。移除 TODO 标记、主动返回 NotReady 的占位及对应“未完成”收尾分支；保留 stop Event 查询作为额外观察。kernel、输入、grid/block、计时端点和校验算法不变，前文原练习路线及历史预检保留供复习。

现场复核 GTX 1650 / CC 7.5 / 14 SM / 4096 MiB、KMD 610.88、NVCC 12.9.86、Compute Sanitizer 2025.2.1.0，CUDA_LAUNCH_BLOCKING unset。正式编译无警告、无 spill，每线程 10 个寄存器、无 barrier；65539 项全量正确、最大绝对误差 0，完成边界 PASS；memcheck（padding=32）零错误。check、工具检查及 bench 全部退出 0。

独立普通 bench 为 warmup=3、samples=21、batch=1，CPU launch 段 / CPU 到完成边界 / GPU Event 中位数分别为 15.950000 / 228.193000 / 203.263998 μs。计时边界仍按上表，不含分配、传输和 CPU 校验，不将独立三列中位数相减视为精确等待时间，也不与历史预检作性能 A/B。本轮 NSYS、NCU、GUI、racecheck、synccheck 均 NOT RUN；此前 NSYS 属于历史临时版预检。

原始命令、正式源码 SHA-256、编译信息、输出与退出码见 [正式补全日志](../../reports/CH13/completed-2026-10-29.txt)。正式 build 已更新，无临时补全文件。实现与验证由 Codex 完成，个人运行及关于 CPU 提交/完成、GPU Event 和 host/block 同步的独立解释待验收。


## 正式实验重跑与数据解释：2026-11-02

用户要求真实实验记录及其对本章内容的解释。本轮重读正式源码及 2026-10-29 正式日志，SHA-256 相同（44ea65865be61a073c50589b8ba36f63c09a640da9e776a1cc56eb6b34c41a83）；未修改 CUDA 源码，重新编译后执行 check、memcheck、普通 bench，并单独采集 NSYS trace，所有命令退出 0。

环境实测 GTX 1650 / CC 7.5 / 14 SM / 4096 MiB、KMD 610.88，NVCC 12.9.86、Compute Sanitizer 2025.2.1.0、NSYS 2026.4.1，CUDA_LAUNCH_BLOCKING unset。固定 N=65539、float32、block=256、grid=257、每线程2048次加法；编译无警告、无 spill，10 个寄存器/线程。全部65539项正确、最大绝对误差0，完成边界 PASS，memcheck（padding=32）零错误。普通 bench 先做数值预检、预热3次和一次试测，再收集21个单次样本，逐样本在计时外回读校验。

| 普通 bench 时间口径 | 中位数 μs |
| --- | --- |
| CPU launch 段：t_submit−t0 | 14.818000 |
| CPU 到完成边界：t_complete−t0 | 234.205000 |
| GPU Event：start→stop | 209.376007 |

CPU 走过 launch 段后可以继续执行，但 GPU Event 区间明显更长；只在 launch 后停止 CPU 计时会漏掉完成等待。complete 已包含 launch，两者不是互斥阶段；GPU 同时推进自己的队列，Event 也不能再作为独立阶段加到 complete 上。分配、H2D/D2H、CPU reference/校验均在计时外，complete 不是程序端到端耗时。三列中位数分别计算，不用相减给出精确等待时间，也不将时间比当算法加速比。

以下来自另外一次 NSYS trace 的同一个测量样本，仅用于对应活动，不能与普通 bench 混算。trace 共5个 kernel，最后一次 kernel 的 Correlation ID=141；源码中的两个 EventRecord 分别由 launch 前最后一次和 launch 后第一次 EventRecord 对应，本程序仅一个 host 线程。

| 该 trace 的观测 | 时间 μs |
| --- | --- |
| CPU 调用 cudaEventRecord(start,0) 的持续时间 | 25.679 |
| CPU 调用 cudaLaunchKernel 的持续时间 | 64.132 |
| CPU 调用 cudaEventRecord(stop,0) 的持续时间 | 13.516 |
| 从 CPU 开始调用 start Record 到 stop Record 返回 | 119.928 |
| GPU repeated_add 的执行持续时间 | 159.713 |
| 程序打印的 GPU Event 区间 | 250.943989 |
| CPU 调用 cudaDeviceSynchronize 的持续时间 | 180.693 |

该 trace 程序自己的 host_launch/host_complete 为66.326/261.487 μs，与表内单个 API 的范围不同。NSYS GPU kernel 159.713 μs，而 Event 区间250.944 μs，说明 Event 区间不必严格等于纯 kernel 执行；源码提交间隙、GPU 调度/排队及标记边界等可以包含在内，本次未量化各因素贡献。profiler 运行单独观察，不把这组数与普通 bench 作性能 A/B，也不推广固定延迟。

最直接回应“为什么 stop 没等 kernel 就提交”：CPU stop Record 调用13.516 μs便返回，但设备 Event 区间仍为250.944 μs，且该报告中 stop Record 返回早于 GPU kernel 结束178.232 μs。提交标记请求和设备到达标记是不同动作；同一 stream 保持 start→kernel→stop 的执行顺序，GPU 在 kernel 完成后才到达 stop。[CUDA 12.9 Event 语义](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART__EVENT.html)

这里使用 report 内各活动时间和 correlation 阅读；最后一次 CPU 同步返回比 GPU kernel 结束晚2.812 μs，但不把跨轨迹微小端点差作为精确硬件因果分解。本次导出的 GPU 表没有单独列出两个 Event 的时间戳，不能把 CPU EventRecord 调用端点冒充 GPU Event 时间戳。成功同步后的 cudaEventQuery 返回0，即 cudaSuccess；它用于观察完成状态，不是第二次计时。

完整命令、环境、源码哈希、原始输出和退出码见 [本轮实验日志](../../reports/CH13/experiment-2026-11-02.txt)。保留 [NSYS 报告](../../reports/CH13/experiment-2026-11-02.nsys-rep)、[SQLite](../../reports/CH13/experiment-2026-11-02.sqlite) 与 [时间关联 CSV](../../reports/CH13/experiment-2026-11-02-timeline.csv)，均来自本轮正式版。GUI、NCU、racecheck、synccheck 本轮 NOT RUN，无临时补全产物或新依赖；个人运行及独立解释仍待验收。


## NSYS GUI 阅读路线：2026-11-02

用户希望在 GUI 查看 CPU 提交区间、GPU kernel 区间和 GPU Event 区间的实际位置。现场核验：默认 nsys-ui 经 /usr/local/cuda-12.9/bin/nsys-ui 启动 GUI 2025.1.3，而采集 CLI 为2026.4.1；必须使用2026.4.1或更新 GUI 打开本章新报告，不能用旧 GUI 判断GPU活动缺失。[官方报告版本要求](https://docs.nvidia.com/nsight-systems/UserGuide/index.html#opening-command-line-results-files-for-visualization)

先在匹配版本 GUI 的 File > Open 打开 `reports/CH13/experiment-2026-11-02.nsys-rep`，切换 Timeline View。展开进程主线程下 CUDA API 行，以及 GPU0 / CUDA HW / Context / Stream 相关行（具体层级显示随版本变化）。该报告共5个 repeated_add，最后一个是测量样本，前面是数值预检和预热。

定位最后一个 GPU repeated_add。可以右击 GPU kernel/stream 行选 Show in Events View，在底部 Events View 按名称或时间找最后一个 repeated_add，再双击该项定位时间线；悬停读取 Start/End/Duration 和 Correlation ID。该 kernel 的 Correlation ID=141，Duration=159.713 μs；点击它会突出关联 CPU launch。在 Timeline Options 中可打开 correlation arrows；也可右击 CUDA API 和目标GPU行选 Pin row，方便上下对齐观察。[官方 GUI 阅读说明](https://docs.nvidia.com/nsight-systems/UserGuide/index.html#reading-your-report-in-gui)

原报告中，围绕该 launch 的 CPU API 顺序如下：

```text
cudaEventRecord(start) → cudaLaunchKernel → cudaEventRecord(stop) → cudaDeviceSynchronize
correlation: 140             141                 143                      144
```

这里 start/stop 是根据源码位置对应的名字，GUI 不一定显示 C++ 变量名。start Record 的 CPU Start=2.389910487 s；stop Record 的 CPU End=2.390030415 s，End−Start=119.928 μs。GUI 可通过两个条目的 tooltip/Events View 读端点后相减；在时间轴选区拖出这段可看近似长度，准确值以事件端点为准。单条CPU launch API为64.132 μs，后续同步API为180.693 μs，分别读取各自Duration，不能用其中一条替代整个区间。

原采集命令未启用 --cuda-event-trace，当前CLI默认false。因此原报告没有两个设备端 Event 完成标记，250.943989 μs来自当时程序输出，不能从CPU两条Record的端点重建。要直观看GPU标记，另采以下报告（已实际生成并验证）：

```bash
nsys profile --trace=cuda --cuda-event-trace=true --sample=none --cpuctxsw=none --force-overwrite=false -o reports/CH13/events-2026-11-02 ./build/CH13/host_async trace
```

该命令仅增加采集功能，未改源码；check/trace的65539项全量结果PASS、误差0、程序及工具退出0。新报告为 [events-2026-11-02.nsys-rep](../../reports/CH13/events-2026-11-02.nsys-rep)，原始命令和输出见 [日志](../../reports/CH13/events-2026-11-02.txt)，标记数据见 [CSV](../../reports/CH13/events-2026-11-02-markers.csv)。Windows GUI 的 File > Open 可填写：

```text
\\wsl.localhost\Ubuntu-24.04\home\yhc23\PROJECT\CUAPI_LEARN\reports\CH13\events-2026-11-02.nsys-rep
```

在新报告展开 CUDA HW / stream 的设备 Event 标记（悬停名称中查找 CUDA Event/completion），start 的 eventId=1、correlation=140，stop 的 eventId=2、correlation=143；中间 repeated_add 的 correlation=141。设备start timestamp=1.789570357 s，stop=1.789740526 s，差为170.169 μs；kernel Duration=160.029 μs。程序同一次Event API读数为171.552002 μs，host_launch/complete=15.900/303.307 μs。设备标记差与API读数相近但并非逐小数位一致，不要求其精确相等；这些都属于新一次采集，不能用来复现原报告的250.944 μs。

特别注意：这份新采集的CPU同步与查询均返回成功，但其CPU同步返回时间戳比GPU kernel结束时间戳早95.177 μs，跨轨迹时间对齐存在不一致。本次只用新报告查看同GPU轨迹的Event标记和kernel区间，不用它推断严格CPU/GPU完成顺序；不能把显示异常解释为同步API提前返回。CUDA Event Trace有额外采集开销，不作为普通bench性能结果。[官方 CUDA Event Trace 说明](https://docs.nvidia.com/nsight-systems/UserGuide/index.html#cuda-event-trace)

原始Clock::now()的t0/t_submit/t_complete并没有单独被NSYS记录，不能在GUI逐点精确定位完整host_launch/host_complete；CPU launch API Duration也不等于含错误检查和计时调用开销的host_launch_us。普通bench的21样本中位数同样不对应trace中的某一根条形。本次未修改程序添加NVTX，也未安装/升级GUI；仅核验现有版本、CLI采集和SQLite内容，匹配版本GUI中的实际交互仍待用户操作。
