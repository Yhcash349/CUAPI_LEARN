# Ch06：warp 怎样执行分支

warp 可以先理解为 GPU 调度的一组 32 个线程，lane 是线程在这组里的位置。本章通过编号输出和两种分支安排认识这种分组，计划 45～60 分钟，对应 [PLAN](../PLAN.md) 阶段 B；独立源码为 [CH06/warp_branch.cu](../../CH06/warp_branch.cu)，进度和工作量只记在 [RECORD](../RECORD.md)。

复用 Ch02 的索引、Ch03 的错误检查与 Ch04 的同 stream Event 计时。Codex 已提供输入、CPU reference、校验、计算路径和计时框架；原练习为两处 TODO，2026-10-14 按用户要求补全编号计算（TODO 1），2026-10-20 按用户要求补全分路条件（TODO 2）。当前正式源码可直接编译运行，两处实现均由 Codex 完成，个人解释待验收。Ch05 的个人解释及更早待验收项继续保留。本章不学习 NCU、shared memory 或 warp 同步接口。

## 先看编号：block、warp、lane

花约 10 分钟读 `probe_warps()`。它只启动一个 block、64 个线程，把每个线程的 lane 和 block 内 warp 编号写入两个数组，CPU 回读并校验全部 64 项；GPU 只打印边界附近的 8 项。这里是固定的一维 block，因此相邻的 32 个 `threadIdx.x` 组成一个 warp。

```text
block 0：64 个线程
  warp 0：threadIdx.x =  0～31，lane = 0～31
  warp 1：threadIdx.x = 32～63，lane = 0～31
```

`warp_in_block` 只给当前 block 内的 warp 编号，每个 block 都从 0 开始。它不说明 warp 在哪个 SM 上运行，也不说明执行先后。lane 不是全局数组下标，例如线程 32 的全局下标在本次 probe 中为 32，lane 却重新从 0 开始。

先花 5 分钟预测线程 15、16、31、32、63 的 warp/lane。原 TODO 1 已由 Codex 补全：`t = threadIdx.x`，用 `t % warpSize` 得到组内位置，用 `t / warpSize` 得到 block 内组号。本机程序会核验 `warpSize=32`。当前正式版 probe 应输出 `Probe PASS: checked=64 mismatches=0`；历史占位版的 64 项不符是练习未填的预期结果，见下方 10 月 8 日预检。

打印顺序即使看起来整齐，也不能证明线程依次执行或 64 个线程同时执行。验收看编号值和全量校验，不看屏幕行的先后。

## 主实验：只改变谁走 A、谁走 B

分支分歧（divergence）的直觉是：同一 warp 中有人走 A、有人走 B，GPU 需要分别执行这些路径，并让不属于当前路径的线程暂时不参与。不同 warp 可以各自走不同路径，不构成这个意义上的 warp 内分歧。

本章保持同一 kernel、相同输入、N=65536、block=256、grid=256，每个线程处理一个 `uint32` 元素并迭代 256 次。两种模式都应有 32768 个线程走 A、32768 个线程走 B；每个线程仍读取 `input[i]`、写入 `output[i]`，地址安排不变。主要变量是分支条件的分组方式。

| 模式 | block 内的 warp 0 | block 内的 warp 1 | 一个 warp 内是否分两路 |
| --- | --- | --- | --- |
| `within_warp`，mode=0 | lane 0～15 走 A，16～31 走 B | lane 0～15 走 A，16～31 走 B | 是 |
| `between_warps`，mode=1 | 全部走 A | 全部走 B | 否 |

后面的 warp 继续按同样规律分配。计时 block 有 8 个完整 warp，偶数 warp 走 A、奇数 warp 走 B 时，整个 block 两路的线程数仍相等。不要把条件写成 `threadIdx.x < 16`，否则只会让 block 的前 16 个线程走 A；也不要按 block 奇偶分配，那会改变本章的比较。

原 TODO 2 已由 Codex 补全：`choose_path_a()` 的输入是模式和 block 内线程编号，返回 `true` 选 A、`false` 选 B。用取余求 lane、整除求 block 内 warp 编号，mode=0 返回 `lane < 16`；mode=1 返回 `warp_in_block % 2 == 0`。先在纸上填写线程 0、15、16、31、32、48 在两种模式中的路径，再对照实现；其余 host、计算路径和计时配置保持不变。

`path_a()` 与 `path_b()` 是已提供的两套整数计算。每轮都有乘加、右移与异或，后一次依赖前一次结果；两路使用不同常数。这里的整数运算只用于产生可校验且不会轻易被消除的工作，不要求学习随机数算法或位运算优化。无符号 32 位运算的溢出按模 2^32 处理，CPU/GPU 逐位比较，不用浮点容差。

两种模式同一个下标可能走不同路径，所以输出数组不要求彼此相等；它们分别与自己的 CPU reference 比较。reference 独立按下标生成，不能为了 PASS 而把 reference 一起改成自己的条件。历史占位版全部走 A，会在两种模式各发现 32768 项不符并跳过计时；当前正式完成版应两种模式均为 `mismatches=0`。

## 保存、重新编译、按顺序运行

以下命令在项目根目录执行。当前两处 TODO 已补全，先编译并运行 `probe`，观察编号并确认 Probe PASS，再运行分路校验与计时。

```bash
mkdir -p build/CH06 reports/CH06
nvcc -std=c++17 -O2 -arch=sm_75 -lineinfo \
  -Xcompiler=-Wall,-Wextra CH06/warp_branch.cu -o build/CH06/warp_branch \
  && ./build/CH06/warp_branch probe
```

每次修改后都是“保存源码 → 重新编译 → 运行”。`&&` 确保编译成功后才运行，避免误用旧二进制。预计约 15 分钟完成运行对照：先做正确性检查，成功后才进入正常计时。

```bash
./build/CH06/warp_branch check && ./build/CH06/warp_branch bench
```

| 模式 | 行为与应检查的输出 |
| --- | --- |
| `probe`（默认） | GPU 少量编号打印；全部 64 项检查，要求 `Probe PASS` |
| `check` | 两种分支模式全部元素校验，要求各自 `mismatches=0`；不计时 |
| `bench` | 先校验；通过后每种模式预热 10 次、取 21 个样本，每个样本含 5 次 kernel 启动 |

`bench` 不调用有 printf 的 probe kernel。两种模式成对采样，轮换先后顺序；每批回读校验在计时区间外。输出 `event_batch_per_launch_median_us` 表示每个 Event 区间除以 5，再对该模式的 21 个值取中位数，单位为 μs。

Event 起止标记和 kernel 都在默认 stream 0；等待 stop 完成才读耗时。区间不含输入准备、分配、H2D、D2H、CPU 校验或释放，但可能包含 CPU 提交不及时导致的 GPU 空闲间隔。它是批次平均每次启动时间，与 Ch05 时间线上的单个 kernel duration、端到端 host elapsed 的范围不同。两种模式的条件计算也不同，不能把总耗时差全部当成分歧的纯开销。

想保留自己的普通输出，可换一个未使用的文件名：

```bash
./build/CH06/warp_branch bench > reports/CH06/user_bench_01.txt
cat reports/CH06/user_bench_01.txt
```

先预测哪种更可能慢，再记实际结果。如果没有明显差异或出现波动，同样记录，不挑最快一次、不为得到预定比例临时增加优化任务。正常计时不要套 Sanitizer、NSYS 或 NCU。

## 怎样解释，解释到哪里

最后花约 10 分钟用自己的话说明：32 线程一组怎样从编号中看出来？为什么两种模式的 A/B 总人数相同，warp 内的安排却不同？哪一种存在 warp 内分歧，你的计时是否符合预测？指出源码的分支条件、实际输出和计时边界即可。

不能把“GPU 线程运行同一份 kernel”理解成所有线程在每个时刻严格同步。GTX 1650 属于支持 Independent Thread Scheduling 的架构；先记住线程可分歧、不能靠隐式同步交换数据，相关协作在后续章节再学。warp 也不是固定对应某个 SM 的编号。

源码中的 `if` 可能被编译器变成其他形式，短分支不保证产生真实跳转。本章用较长的两条计算路径及 `__noinline__` 提示，并由 Codex 检查当前编译产物；修改计算体、编译选项或切换工具链后需要重新预检。`__noinline__` 不能单独作为证据。没有 NCU 动态分支计数，不能仅从两次耗时反推出精确的分歧比例或硬件利用率。

验收需要 Probe PASS、两种模式全量正确、正常计时的有效样本及个人解释；没有“必须慢两倍”的要求。代码由你填关键两处，框架和预检由 Codex 提供，如实记录辅助程度。到一小时仍未完成，留下阻塞和实际输出，不追加 SASS/NCU 教学。与推理 kernel 的联系是：总工作量相似时，同组线程的执行路径安排仍可能影响效率。

## 观察实验：普通计时与 NSYS 时间线

2026-10-20 用户要求提供可直观对照耗时的指令。当前对照单位是两种分路安排：两种模式都包含 path_a/path_b，只改变哪些线程走哪条路径。先预测 within_warp 是否更慢，再按上方命令重新编译，运行：

```bash
./build/CH06/warp_branch check && ./build/CH06/warp_branch bench
```

比较输出的 `within_warp` 和 `between_warps` 两行 `event_batch_per_launch_median_us`。它们覆盖一次 kernel 的读输入、分路计算与写输出，并按批次计时归一化，仍可能包含提交间隙；不含分配、H2D、D2H、CPU reference/校验及程序初始化。当前程序没有按模式单独统计含拷贝的 host 端到端时间，程序启动到退出也包含两种模式，不能作为其中一种模式的耗时。

如果要直观看 CPU 提交、GPU kernel 和回读的先后关系，在普通运行之后单独采集一次：

```bash
/home/yhc23/.local/bin/nsys profile \
  --trace=cuda --sample=none --cpuctxsw=none \
  -o reports/CH06/user_observe_01 ./build/CH06/warp_branch bench
```

使用已核验的 CLI 2026.4.1 显式路径，避免旧入口。重复采集换为 `user_observe_02`，保留旧报告。在 Windows Nsight Systems 2026.4.1 GUI 打开新生成的 `.nsys-rep`，展开 CUDA API 和 GPU Kernels/Memory，并将 `branch_work` 按开始时间排序。两种模式共用一个 kernel 名称，path_a/path_b 是内部设备函数，此处不会形成两个独立的 kernel 时间条。

固定当前参数且完整成功运行时，共有 232 次 branch_work：第 1～2 次为两模式初始校验，第 3～22 次为预热；第 23～27 次是首轮 within_warp 的 5 次启动，第 28～32 次是首轮 between_warps 的 5 次启动。放大这两批，比较 GPU 时间条宽度；后续采样轮交替模式顺序，不能一直按固定先后猜模式。这个对应关系来自当前源码顺序，改变预热/批次/样本参数后要重新核对。性能比较以工具外的 Event 结果为准，工具内观察只用于时间线理解。

CLI 阅读可用 `nsys stats --report cuda_gpu_trace <报告路径.nsys-rep>`；首次导出后得到同名前缀 SQLite。若工具因 SQLite 比主报告时间戳早而拒绝再次读取，可对本次刚导出的同名 `.sqlite` 运行 stats，无需重新采集。

Codex 已在当前完整源码上验证这套流程：普通 check 两模式全量正确，bench 每模式 10 次预热、21 个样本、每批 5 次，within_warp=116.083205 μs、between_warps=71.097600 μs。另一次 NSYS 采集运行正确、生成报告，确认 232 次 branch_work、1 次 H2D、44 次 D2H、2 次 memset。汇总按 kernel 名称合并两种模式，其平均值不能当成某一模式的结果。GUI 人工操作本次 NOT RUN，模式定位已通过逐条 CSV 与源码顺序核对。

证据为 [observe-preflight-2026-10-20.txt](../../reports/CH06/observe-preflight-2026-10-20.txt)、[NSYS 报告](../../reports/CH06/observe-preflight-2026-10-20.nsys-rep)、[SQLite](../../reports/CH06/observe-preflight-2026-10-20.sqlite) 与 [GPU trace CSV](../../reports/CH06/observe-preflight-2026-10-20.csv)。首次 CSV 读取因派生 SQLite 时间戳被拒绝，改读本次 SQLite 后退出 0；诊断已保留在文本日志。此次没有修改源码，不增加新的计时边界、NVTX 或 NCU 要求，用户自己运行与解释待验收。

## 可选：用 NCU 观察动态分支分歧

2026-10-20 用户主动询问如何用 NSYS/NCU 判断 warp divergence，本节为可选观察，不替代 Ch07 的正式 NCU 教学。NSYS 观察 CPU/GPU 时间关系和 kernel 长短；判断本例是否出现动态分支分歧，使用 NCU 的 Source Counters 和分歧目标计数，不能仅凭耗时差下结论。

先按上方章节命令重新编译（保留 `-lineinfo`），普通运行 check 通过后，在根目录执行：

```bash
/home/yhc23/.local/bin/ncu \
  --kernel-name-base function --kernel-name branch_work --launch-count 2 \
  --section SourceCounters \
  --metrics smsp__sass_branch_targets_threads_divergent.sum,smsp__thread_inst_executed_per_inst_executed.ratio \
  --import-source yes -o reports/CH06/user_divergence_01 \
  ./build/CH06/warp_branch check

/home/yhc23/.local/bin/ncu --import reports/CH06/user_divergence_01.ncu-rep --page details
```

重采集换用 `user_divergence_02`，保留已有报告。选择 check 是为了只运行两次 kernel：第一个结果是 within_warp（mode=0），第二个是 between_warps（mode=1）；这次只观察动态执行计数，不是预热后的性能采样。NCU 可能重放 kernel，工具下的执行耗时不作普通计时依据。`--import-source yes` 把编译行号关联到的源码保存在报告内，便于复查。

本机 NCU 2025.2.1、GTX 1650 / SM75 的正式完成版实测：

| 指标 | within_warp | between_warps |
| --- | --- | --- |
| 分歧分支目标总计数 `smsp__sass_branch_targets_threads_divergent.sum` | 2048 | 0 |
| 每条指令平均参与线程数 `smsp__thread_inst_executed_per_inst_executed.ratio` | 16.40 | 32 |
| Branch Efficiency（活跃线程目标一致的分支比例） | 98.08% | 100% |

第一种模式出现非零分歧目标计数，结合每 warp 的半组分路和平均参与线程数，得到实际执行中的分歧证据。平均参与线程数低也可能来自尾部线程或提前退出，不能单独将其当作分歧证明；本例输入使用完整 warp。Branch Efficiency 会合计 kernel 中大量一致的循环等分支，98.08% 不表示只损失 1.92% 性能，也不表示没有明显分歧。

用兼容的 Nsight Compute GUI 打开 `.ncu-rep`，在 Details 中比较两次结果的 Source Counters；进入 Source，选择 CUDA/SASS 关联视图，查看 Divergent Branches 和 Avg. Threads Executed 列。分路指令处看前者，A/B 计算体处看后者。已通过 CLI source 导出核对：分路 BRA（kernel 内偏移 0x270）在 mode=0 的 Divergent Branches=2048、mode=1 为 0；两条计算体中的相关执行指令分别为 16 与 32 个参与线程。动态计数支持本例结论，不等同于固定减速比例、GPU 利用率或逐周期硬件轨迹。GUI 人工操作本次 NOT RUN。

实测采集每次 launch 5 passes，两种模式全量校验仍通过，采集和报告读取均退出 0。未改源码，不增加实验变量或依赖。证据为 [ncu-divergence-2026-10-20.ncu-rep](../../reports/CH06/ncu-divergence-2026-10-20.ncu-rep)、[执行日志](../../reports/CH06/ncu-divergence-2026-10-20.txt)、[Details](../../reports/CH06/ncu-divergence-2026-10-20-details.txt)、[Raw CSV](../../reports/CH06/ncu-divergence-2026-10-20-raw.csv) 与 [Source](../../reports/CH06/ncu-divergence-2026-10-20-source.txt)。字段名按本机 `SourceCounters.section` 与 metric 查询核对，不把不同版本的 source metric 名称直接当成可采集的 launch metric。

指标语义参考 [NCU Source Metrics](https://docs.nvidia.com/nsight-compute/ProfilingGuide/index.html#source-metrics)、[Source 页面指标说明](https://docs.nvidia.com/nsight-compute/NsightCompute/index.html#source-page) 与 [NCU CLI](https://docs.nvidia.com/nsight-compute/NsightComputeCli/index.html)。

## 官方依据

warp 分组、SIMT 分支行为和 Independent Thread Scheduling 参考 [CUDA C++ Programming Guide 12.9：SIMT Architecture](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#simt-architecture)；编译提示参考 [同版 Guide：__noinline__ and __forceinline__](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#noinline-and-forceinline)。只查本章相关段落，不要求读整本指南。

Event 调用沿用 Ch04，语义参考 [CUDA Runtime API 12.9：Event Management](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART__EVENT.html)。正式源码的调用签名已在本机 Toolkit 12.9 编译验证。

## 2026-10-08 工程预检

Codex 复核 GTX 1650 / CC 7.5 / warpSize=32 / 4096 MiB、驱动 610.88、NVCC 12.9.86、Compute Sanitizer 2025.2.1.0。正式练习版与临时补全版均编译无警告。正式版 `probe` 64 项不符，`check`/`bench` 两种模式各 32768 项不符、计时 NOT RUN，三种模式均退出 1，符合占位预期。

临时补全版 Probe 64 项全部正确，两种分支模式各 65536 项全部正确、整数误差为 0；`probe`、`check`、`bench` 均退出 0。对临时版 probe/check 分别运行 `compute-sanitizer --tool memcheck --padding 32 --error-exitcode 99`，均零错误、退出 0；这只覆盖本次输入和工具范围。Sanitizer 与正常计时分开运行。

| 模式 | 本机预检 Event 批次平均每次启动中位数 |
| --- | --- |
| `within_warp` | 109.081602 μs |
| `between_warps` | 65.171200 μs |

参数为 N=65536、uint32、block=256、grid=256、iterations=256、warmup=10、samples=21、batch=5。本次 warp 内分路较慢，只是本机当前教学微基准的一次观察，不要求学生复现固定比值，不推广到所有分支或架构。

`cuobjdump --dump-sass` 检查临时补全版，`branch_work` 在偏移 `0x340` 保留条件 `BRA`，两路分别在 `0x360` 和 `0x3a0` 调用不同计算体；两路保留整数乘加、移位、循环回边，结果经 `STG` 写出。结合正确性检查确认本次计算与两路控制流未被消除；这是静态产物检查，未采集动态分歧计数，不是逐周期调度证明。学生不必学习这些指令。

原始命令、输出、退出码见 [preflight-2026-10-08.txt](../../reports/CH06/preflight-2026-10-08.txt)，编译产物文本见 [completed-sm75.sass.txt](../../reports/CH06/completed-sm75.sass.txt)。临时补全源码和可执行文件已清理，正式源码保留两处 TODO；报告与正式 build 按已有规则留在本地。NSYS、NCU 本章 NOT RUN；没有用户练习或个人解释验收，不记 DONE。

## 2026-10-14 TODO 1 正式补全与验证

用户指定 `probe_warps()` 并要求完成 TODO、解释功能。Codex 将 lane 改为 `t % warpSize`，warp_in_block 改为 `t / warpSize`，补充一维 block 的分组注释；数组写入与边界打印沿用原框架。线程 31 得到 warp=0、lane=31，线程 32 得到 warp=1、lane=0，线程 63 得到 warp=1、lane=31；CPU 校验全部 64 项。

NVCC 12.9.86、GTX 1650 / CC 7.5 / warpSize=32；正式源码编译无警告，probe 输出 `Probe PASS: checked=64 mismatches=0`、退出 0；正式 probe 的 memcheck 零错误、退出 0。命令与输出见 [probe-completed-2026-10-14.txt](../../reports/CH06/probe-completed-2026-10-14.txt)。本次仅完成编号练习，TODO 2 仍保留；check/bench、计时和 profiler 本次 NOT RUN。Codex 补全不代表用户独立实现或解释通过，章节未记 DONE。

## 2026-10-20 TODO 2 正式补全与验证

按用户要求补全 `choose_path_a()`：mode=0 让每个 warp 的 lane 0～15 走 A、16～31 走 B；mode=1 让 block 内偶数 warp 全走 A、奇数 warp 全走 B。移除占位返回值，并将正确性失败时的计时提示改为检查失败，不再提示补全已完成的 TODO。输入、reference、计算体和计时配置沿用原实现。

NVCC 12.9.86、GTX 1650 / CC 7.5 / warpSize=32 / 4096 MiB、驱动 610.88；正式源码编译无警告，probe 的 64 项校验通过，check/bench 两种模式各 65536 项全部正确、mismatches=0，均退出 0。正式 check 的 memcheck 零错误、退出 0；工具检查与正常计时分开。

N=65536、uint32、grid=256、block=256、iterations=256，每模式 warmup=10、samples=21、batch=5。Event 批次平均每次启动中位数：within_warp=113.785601 μs，between_warps=65.478402 μs，Timing PASS。仅作本机本次微基准观察，仍包含条件计算和可能的提交间隙，不推算纯分歧成本，不与历史运行作优化 A/B。

检查正式完成版 SASS：branch_work 在 0x270 保留条件 BRA，0x290/0x2d0 分别调用两条计算体，结果经 0x320 的 STG 写出；计算体仍保留整数计算和循环，未消除两路对照。它是静态产物证据，不是动态分歧计数。命令与输出见 [completed-2026-10-20.txt](../../reports/CH06/completed-2026-10-20.txt)，编译产物文本见 [completed-2026-10-20-sm75.sass.txt](../../reports/CH06/completed-2026-10-20-sm75.sass.txt)。本次未运行 NSYS/NCU；两处练习均由 Codex 按要求补全并验证，个人解释待验收，未记 DONE。
