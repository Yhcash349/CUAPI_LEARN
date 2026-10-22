# Ch08：shared memory 与 block 同步

shared memory 可以理解为同一 block 内线程共用的一小块工作台：每人放一份数据，再取走其他人放的数据。本章让每个 block 内的线程交换数据，只对照“读取前有无 block barrier”。barrier 是集合点，让线程等到大家写好后再继续。计划 45～60 分钟，对应 [PLAN](../PLAN.md) 阶段 B；源码在 [CH08/shared_exchange.cu](../../CH08/shared_exchange.cu)，进度与工作量只在 [RECORD](../RECORD.md) 维护。

复用 Ch02 的索引与边界、Ch03 的错误检查和全量校验。Ch07 已讲解并由 Codex 按要求补全，用户个人运行、采集和部分解释仍待验收；按本次明确请求准备 Ch08，不自动补记前章完成。Codex 提供 host、输入、CPU reference、shared 写入和校验骨架。原练习保留两处 TODO：block barrier 和伙伴槽位读取；2026-10-22 已按用户要求由 Codex 补全，当前正式源码无 TODO，用户个人解释待验收。不引入 bank conflict、归约或 NCU 新指标。

## 先预测：线程把数据交给谁

用约 5 分钟看下面的任务。固定 N=1000、float32、block=128、grid=8，每个 block 将自己处理的那一段反序，**不是把整个 1000 项数组反序**。完整片段 128 项，最后一片从 896 开始，只有 104 项有效。

```text
第一个 block：线程 t       0    1    2   ...  126  127
先写入自己的 shared 槽位   0    1    2   ...  126  127
随后读取的 shared 槽位   127  126  125   ...    1    0

最后一个 block：有效 t     0    1    2   ...  102  103
随后读取的 shared 槽位   103  102  101   ...    1    0
线程 t=104～127 不写 output，但仍参加本例的集合点。
```

输入为 `input[i]=i*0.25f`。先预测 output[0]、output[127]、output[896] 和 output[999] 应该是多少，再想一想：线程 0 读取线程 127 的数据时，能否假定另一个 warp 已经写完？去掉集合点，是否一定会数值 FAIL？先写预测再运行，不用“最后所有线程都会执行”代替读写顺序保证。

## 读 kernel，理解两处关键实现

约 10 分钟阅读 `exchange_block()`、`make_reference()` 和 `main()`。程序沿用前章的数据流：

```text
CPU 准备输入与 reference → 分配 GPU 内存 → H2D
  → 每线程写 tile[t] → block 集合点 → 读取伙伴的槽位 → 写 output[i]
  → 等待 kernel 完成 → D2H → 全量校验 → 释放内存
```

`__shared__ float tile[kBlock]` 每个 block 各有一份，占 512 字节，生存期随该 block。相同的 tile[0] 在不同 block 中对应不同存储；本例不用于跨 block 交换。[CUDA 12.9：__shared__](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#shared)

`base` 是本 block 的数组起点，`t` 是 block 内编号，`i=base+t` 是全局编号。`count` 是本片段有效项数，因此伙伴编号 `peer=count-1-t` 只在 valid 线程内使用。完整 block 的线程 0/127 互换，尾部线程 0/103 互换；不能在尾部仍按 127-t 读取。

接下来约 20 分钟对照原来的两处练习理解当前实现：第一处在统一的 `if (use_barrier)` 内调用 `__syncthreads()`；第二处使用 `output[i] = tile[peer]` 读取伙伴的 shared 槽位，并移除了占位 `(void)peer`。CPU reference、shape 和 host 校验沿用原设计。

`__syncthreads()` 等待 block 内线程到达集合点，并使此前的 shared/global 访问对 block 内线程可见。本例将它放在 shared 写入之后、伙伴读取之前。`use_barrier` 是 host 传入的统一参数，一次启动中所有线程取值相同；不要把 barrier 移入只有部分线程满足的 `if (valid)`。本例所有 128 个线程都沿相同控制路径经过集合点，无效线程只写入零，不读取越界 input，也不输出。[CUDA 12.9：Synchronization Functions](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#synchronization-functions)

只在一个 warp 内同步覆盖不了这里跨 warp 的交换。host 的 `cudaDeviceSynchronize()` 则在 kernel 提交后等待整体完成，无法补上 kernel 内“先写后读”的依赖。本例只写入 shared 一轮，读取后不覆盖复用，所以只需这一个写后读的集合点；循环复用的额外同步留给后章。

## 编译并校验

以下命令在项目根目录运行。当前两处实现已补全，编译后应全量 PASS；以后每次修改源码，都需保存并重新编译：

```bash
mkdir -p build/CH08
nvcc -std=c++17 -O2 -arch=sm_75 -lineinfo -Xcompiler=-Wall,-Wextra \
  CH08/shared_exchange.cu -o build/CH08/shared_exchange && \
  ./build/CH08/shared_exchange check
```

历史占位版只读回自己的值，没有完成交换，退出 1、mismatches=1000，这是当时待完成练习的预期输出。当前正式版要求 checked=1000、mismatches=0、max_abs_error=0、退出 0。由于只是搬运可精确表示的数，本章不需要浮点误差容限。

手算核对：output[0]=31.75、output[127]=0、output[896]=249.75、output[999]=224。程序打印其中两项，但验收始终检查全部 1000 项，包含最后不足整 block 的片段。

## 用 racecheck 对照有无 barrier

约 15 分钟完成以下检查。当前源码已有伙伴读取，可以直接观察目标错误。`check` 和 `race` 使用同一个 kernel，前者传入 use_barrier=true，后者传 false；对照只改变这一个条件。错误模式不做计时，也不要求数值一定出错。

先检查访问范围，再检查 shared 读写之间有没有必要的同步。memcheck 和 racecheck 的检查目标不同，racecheck 不替代访问越界检查。[Compute Sanitizer：Racecheck](https://docs.nvidia.com/compute-sanitizer/ComputeSanitizer/index.html#racecheck-tool)

```bash
compute-sanitizer --tool memcheck --padding 32 --error-exitcode 99 \
  ./build/CH08/shared_exchange check
compute-sanitizer --tool racecheck --error-exitcode 99 \
  ./build/CH08/shared_exchange check
compute-sanitizer --tool racecheck --error-exitcode 99 \
  ./build/CH08/shared_exchange race
```

正确版本应全量 PASS 且两种工具零错误。错误版本关注 `Race reported between Write access ... and Read access ...` 以及源码位置：一个线程尚未通过同步把写入交接给另一个线程，就发生了伙伴读取。RAW 是 read-after-write，表示这里要检查的写后读依赖。报告可能将许多字节级 hazards 合并成一条分析，不能把括号中的 hazards 数直接当成独立程序错误数。[Racecheck analysis reports](https://docs.nvidia.com/compute-sanitizer/ComputeSanitizer/index.html#understanding-racecheck-analysis-reports)

`race` 是故意缺同步的诊断：数值 PASS 或 FAIL 都只是一条观测，不能证明没有数据竞争。它故意返回应用退出码 0，让 Sanitizer 在检测到错误时用指定的 99 表达检查失败；不能拿直接运行 race 的退出 0 当正确性验收。若工具没有报告，先核对重新编译、伙伴读取和参数，不反过来认定缺同步安全。

如果需要保存个人输出，可用 `mkdir -p reports/CH08` 创建目录，并在 Sanitizer 命令中加 `--log-file reports/CH08/user-race-01.txt`；每次换新文件名。该选项保存工具诊断，应用自身的正确性输出仍在终端，二者一起用于复盘。

## 可选：沿用计时与同步检查

本章不以性能差异验收，有余力再运行，不为这些可选项超过一小时。先通过 check 再进行普通计时；工具采集与普通 bench 分开执行：

```bash
./build/CH08/shared_exchange bench
compute-sanitizer --tool synccheck --error-exitcode 99 \
  ./build/CH08/shared_exchange check
```

bench 只测正确的同步版本：预热 10 次，每个 Event 区间连续启动 10 次，共 21 个样本，等待 stop 后读取时间，换算批次平均每次启动时间，再取中位数。分配、H2D/D2H、CPU reference 与全量校验不在 Event 区间内，短 kernel 仍可能包含 host 提交间隙。不测缺同步版本的“加速比”，也不把 shared 自动等同于更快。synccheck 检查同步原语用法，不能替代 racecheck 的读写冲突检查。[Compute Sanitizer 工具职责](https://docs.nvidia.com/compute-sanitizer/ComputeSanitizer/index.html#compute-sanitizer-tools)

## 解释与验收

最后约 10 分钟，用自己的代码和输出解释：为什么每个 block 有独立的 tile，线程 0 如何得到另一个 warp 的数据，为什么尾部按 104 项反序，以及 barrier 为什么放在写入和伙伴读取之间。再用 racecheck 的写/读位置解释“缺同步但数值 PASS”为什么不矛盾。

完成标准为两处 TODO 正确、1000 项全量通过、memcheck/racecheck 正确版本零错误、缺同步版本有可对应的冲突证据，以及你自己的解释；不要求任何固定性能收益。Codex 预检不替代用户练习与解释；超过一小时则记录当前阻塞，不追加 bank conflict 或底层指令排查。本章的线程间交接会在后面的归约和 tiled GEMM 中继续使用。

## Codex 预检：2026-10-21

以下为 10 月 21 日的历史预检，当时正式源码保留两处 TODO；临时补全版只补 barrier 和伙伴读取，用于教学方核验，不计用户完成。编译选项与上文一致，环境为 NVCC 12.9.86、Compute Sanitizer 2025.2.1.0、GTX 1650 / CC 7.5 / warpSize=32 / 4096 MiB、驱动 610.88；程序查询默认每 block shared 上限 49152 字节。本例 shape=[1000]、float32、grid=8、block=128、tail_count=104、shared=512 字节/block，输入与输出各 4000 字节。

正式骨架 check/bench 的数值校验均为预期 FAIL：1000 项不符、最大误差 31.75，退出 1，计时跳过。最终骨架及临时补全版均编译无警告。临时补全版 check/bench 全量 PASS、最大误差 0；memcheck、racecheck、synccheck 的 check 均零错误。缺 barrier 的 race 模式另经 memcheck 零错误，racecheck 报出 shared 写入与伙伴读取冲突，返回 99；本次数值仍为 PASS。工具摘要显示 1 条 error 分析，合并 4000 个字节级 hazards，不解读为 4000 个独立 bug。

正常 bench 的结果及全部命令、原始输出、正式和临时源码 SHA-256 见 [preflight-2026-10-21.txt](../../reports/CH08/preflight-2026-10-21.txt)，与 Sanitizer 分开运行，不作无同步性能对照。日志前半部分保留初版占位未读取 tile 的编译警告；`FINAL SKELETON` 段对应当日最终骨架，已改为读自己的 shared 槽位并重新预检，不存在该警告。临时源码、二进制已清理，当日正式 build 仍有 TODO，10 月 22 日已更新为补全版。该历史预检的 NCU、NSYS 和 GUI 均 NOT RUN。

## 正式 TODO 补全与验证：2026-10-22

按用户要求，Codex 补全 `__syncthreads()` 与 `output[i] = tile[peer]`，移除占位语句，并更新错误提示。当前正式源码无 TODO，可直接执行上面的 check/bench 和 Sanitizer 命令；实现及验证由 Codex 完成，个人解释仍待验收。

本次复核 NVCC 12.9.86、Compute Sanitizer 2025.2.1.0、GTX 1650 / CC 7.5 / warpSize=32 / 4096 MiB、驱动 610.88。shape/dtype、grid/block、shared 和尾部设置沿用原实验，编译无警告，check/bench 全部 1000 项 PASS、最大误差 0；check 的 memcheck、racecheck、synccheck 均零错误，退出 0。缺同步的 race 运行 memcheck 零错误，racecheck 报出第 38 行 shared 写入与第 46 行读取冲突，返回 99，合并 4000 个字节级 hazards 为 1 条 error 分析；数值本次仍 PASS。

普通同步版 bench 与工具运行分开，warmup=10、samples=21、batch=10，Event 批次平均每次启动中位数 12.102400 μs，Timing PASS；不与历史预检比较性能，不据此推断 shared 的加速效果。命令、原始输出及源码 SHA-256 见 [completed-2026-10-22.txt](../../reports/CH08/completed-2026-10-22.txt)。本次 NCU、NSYS 和 GUI 均 NOT RUN，未生成临时源码或额外依赖。
