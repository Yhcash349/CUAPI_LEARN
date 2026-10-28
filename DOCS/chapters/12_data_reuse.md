# Ch12：把一份输入交给多个线程复用

矩阵乘法中，相邻的输出经常需要同一份输入。让 block 合作搬一小块输入到 shared，再让多个线程反复读取，就能减少程序中重复的 global 读取。这种分块计算叫 tiling：一次只处理大矩阵中的一小块。

本章对应 [PLAN](../PLAN.md) 阶段 B 的最后一章，计划 45～60 分钟。源码为 [CH12/tiled_gemm.cu](../../CH12/tiled_gemm.cu)，复用前章的错误检查、全量校验与同 stream Event 骨架。需要回看 Ch02 索引、Ch08 shared/barrier、Ch11 每 block 资源；本章只增加“矩阵乘法的数据流”和“单层 shared 复用”。2026-10-28 已按用户要求由 Codex 补全装载与累加两处 TODO，当前 check/bench 均应 PASS、退出 0。下文练习路线保留供复习；学习验收与工作量只在 [RECORD](../RECORD.md) 维护。

## 先预测：同一个数为什么反复读取

先用约 5 分钟看数学定义。GEMM 在这里就是普通矩阵乘法，不额外加入缩放或旧 C：`C=A×B`。A 的形状为 `[M,K]`，B 为 `[K,N]`，C 为 `[M,N]`；输出的一行取自 A 的一行，输出的一列取自 B 的一列。

```text
C[row,col] = Σ A[row,p] × B[p,col]，p=0..K-1
行连续存储：A[row,p] → a[row*K+p]；B[p,col] → b[p*N+col]

CPU 输入 / double reference
    ↓ H2D
naive：global A/B → 每线程的 sum → global C
tiled：global A/B → block 的 shared tile → 每线程的 sum → global C
    ↓ D2H
CPU 全量比较
```

主实验固定 `M=N=K=256`、float32、block=`(16,16)`、grid=`(16,16)`。block 的 x 方向对应输出列，y 方向对应输出行；一个 block 负责一块 `16×16` 输出，一个线程始终负责其中一个输出。两种实现保持输入、输出、block/grid、有效乘加工作量一致，主要变量是有无显式 shared 复用。

读 `gemm_naive()`：线程 `(ty,tx)=(2,3)`、block `(x,y)=(1,0)` 负责 `C[2,19]`。它遍历 `p`，累加 `A[2,p]*B[p,19]`。同一 block 中负责 `C[2,16..31]` 的 16 个线程都需要 A 的第 2 行；负责 `C[0..15,19]` 的线程都需要 B 的第 19 列。因此存在复用机会，不需要让每个输出都独自取相同输入。

运行前预测：共享输入会不会改变 C 的值？每个 tile 中，一个 A 元素和一个 B 元素分别能供多少个输出使用？减少源码中的 global 读取，是否保证 DRAM 读取或总耗时同比下降？先写自己的预测，最后核对。

## 读一轮 tile 的线程合作

用约 10 分钟读 `gemm_tiled()` 的框架。两块 `__shared__ float[16][16]` 共占 `2×16×16×4=2048` 字节，每个 block 都有自己的一份。与 Ch11 只预留额外空间不同，这里真的读写静态 shared；启动不需要第三个动态字节参数。`sum` 是每线程自己的标量累加值，编译器通常放在寄存器中，不是 block 公用的变量。

`base=0,16,...,240` 沿 K 移动。每一轮，256 个线程各取一个 A 元素和一个 B 元素，填满两块 shared；所有线程等装载完成，再用当前 tile 累加 16 项，最后等所有读取完成后才能覆盖这两块 shared。整个 K 处理完才写 C，不把每轮片段写回 global。

```text
线程 (ty,tx) 每轮负责搬：
    A[row,base+tx] → a_tile[ty][tx]
    B[base+ty,col] → b_tile[ty][tx]
                 ↓ 所有线程 barrier
线程 (2,3) 计算当前输出的 16 项：
    a_tile[2][p] × b_tile[p][3]，p=0..15
                 ↓ 所有线程 barrier
    下一轮 base += 16，覆盖相同 shared buffer
```

例如 `base=16` 时，上述线程搬 `A[2,19]` 与 `B[18,19]`，却要先从 shared 读取 `A[2,16]`、`B[16,19]` 做 `p=0` 的乘加。它们分别由 `(2,0)` 和 `(0,3)` 装载。装载坐标与计算坐标的区别正是合作的关键：线程搬的两个数并非只供自己使用。

每轮第一处 `__syncthreads()` 保证写完才读；第二处保证读完才覆盖。即使某个线程的输出坐标越界，它仍可能负责其他有效输出需要的装载，且必须参与 block barrier，所以不能照抄 naive 的提前 `return`。矩阵分块与线程合作的官方例子见 [CUDA 12.9：Shared Memory](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#shared-memory)，本章额外提供了边界骨架。

## 完成两处练习

用约 15～20 分钟完成 TODO(1)。把两条零占位赋值换成正确的 global 读取，A 检查 `row<M` 和 `base+tx<K`，B 检查 `base+ty<K` 和 `col<N`；越界位置写零。A 的一行长度为 K，B 的一行长度为 N，不能混用步长。不要把整个循环包进 `if (row<M && col<N)`。

然后完成 TODO(2)：将零乘占位改成 shared 中 A 的第 ty 行和 B 的第 tx 列对应元素的乘加。`p` 是当前 tile 内的位置，`base` 只参与 global 装载，不加到 shared 的下标中。保留已给出的两次 barrier、循环范围和最终带边界的写出，不改 naive baseline。

最初骨架可编译运行，但 tiled 输出是零，校验 FAIL，整个程序退出 1，bench 拒绝计时。只填装载仍不能通过，不能用“无 CUDA 报错”代替结果正确。当前两处均已补全，两种实现分别对 CPU double reference 全量通过后程序退出 0。

host 还会检查 `M=37,N=53,K=29`，专门覆盖行、列与 K 都不满 16 的尾部。该用例的参考计算、越界填零框架由 Codex 提供，属于同一算法的正确性检查，不是第二个性能变量。主实验检查 65536 个输出，尾部检查 1961 个输出；每次启动前填 NaN 哨兵，遗漏写出也会被发现。

## 编译、校验与计时

接下来约 15 分钟，在项目根目录执行；每次编辑都要重新编译。

```bash
mkdir -p build/CH12 reports/CH12
nvcc -std=c++17 -O2 -arch=sm_75 -lineinfo -Xcompiler=-Wall,-Wextra -Xptxas=-v \
  CH12/tiled_gemm.cu -o build/CH12/tiled_gemm && \
  ./build/CH12/tiled_gemm check
```

校验条件为 `abs(gpu-ref) <= 1e-4 + 1e-4*abs(ref)`，NaN/Inf 直接失败。打印全量 mismatch、最大绝对误差和最大相对误差；接近零的 reference 下相对误差可能很大，不能单看这一项。这里输入是 /16 的小数，有限长度累加可能恰好精确，不将本实验误差 0 推广为任意 FP32 GEMM 都应精确相等。

```bash
compute-sanitizer --tool memcheck --padding 32 --error-exitcode 99 \
  ./build/CH12/tiled_gemm check
compute-sanitizer --tool racecheck --error-exitcode 99 \
  ./build/CH12/tiled_gemm check
compute-sanitizer --tool synccheck --error-exitcode 99 \
  ./build/CH12/tiled_gemm check
./build/CH12/tiled_gemm bench
```

先数值正确，再用 memcheck 检查访问、racecheck 检查 shared 竞争、synccheck 检查同步。骨架工具报告零错误而目标程序退出 1，表示练习尚未补全；工具检查本身不会证明数学计算正确。

bench 先检查两种 shape，两种算法均通过才计时；仅为主 shape 测普通 Event。每种方法预热 10 次，测 21 批、每批启动 5 次，批次 Event 时间除以 5 后取中位数，打印 naive/tiled 比值。计时只包同一默认 stream 上的 kernel 批次，不含分配、H2D/D2H、CPU reference 和校验，可能含 host 提交间隙；两组是顺序测量，系统负载和频率可能影响结果。此处没有测端到端耗时，不以加速比作为通过门槛。

## 用计数器核对复用（可选）

核心验收用源码数据流、正确性与普通计时即可；有余力时沿用 Ch07 的 NCU 读数方式，只采 check 最前面的主 shape 两次 launch。当前两处 TODO 已补全；若复原零占位做练习，需先补全再采集，否则编译器可能把零计算消掉，测不到要观察的装载。

```bash
ncu --section LaunchStats --section Occupancy \
  --metrics l1tex__t_requests_pipe_lsu_mem_global_op_ld.sum,l1tex__t_sectors_pipe_lsu_mem_global_op_ld.sum,dram__bytes_read.sum \
  --kernel-name 'regex:gemm_(naive|tiled)' --launch-count 2 \
  -o reports/CH12/reuse ./build/CH12/tiled_gemm check
```

第一个指标是 L1/TEX global load 请求数，第二个是该层读取的 sector 数，第三个是 DRAM 读取字节数；它们处在不同位置。只比较同一主 shape 下 naive/tiled 的相同指标。LaunchStats 核对线程、shared 与寄存器，Occupancy 仅连接 Ch11 的资源概念，不追加调参任务。

对于一个完整 block 的一轮 K tile，按源码的标量读取需求计，naive 是 `256×16×2=8192` 项，tiled 合作装载是 `256×2=512` 项，减少为 1/16；全主 shape 对应 33554432 与 2097152 项。它没有计算 warp 请求合并、广播、缓存命中和编译器变换，因此不是 DRAM 流量的预测，也不保证硬件请求正好减少 16 倍。更多 shared 访问和每轮两次 barrier 也有成本。

缓存可以满足部分 global 读取，shared 可显式安排复用；两者不能按“global 每次都访问显存”理解。官方的复用说明见 [CUDA 12.9：Shared Memory in Matrix Multiplication](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-best-practices-guide/index.html#shared-memory-in-matrix-multiplication-c-ab)，指标口径见 [Nsight Compute：Metrics Guide](https://docs.nvidia.com/nsight-compute/ProfilingGuide/index.html#metrics-guide)。本章不照搬文档中其他 GPU 的性能数值。

## 用自己的话验收

最后约 10 分钟，不看提示指出一个线程算哪个输出、每轮搬哪两个元素、累加从谁装载的 shared 位置取值。解释第一处和第二处 barrier 分别防止什么问题，为什么输出越界的线程仍不能提前退出，以及一份 A/B 元素在当前 block 内如何被 16 个输出复用。

验收要求两处练习生效、两种 shape 的全量结果与 Sanitizer 检查通过、能说明普通 Event 的范围，并用自己的话解释上述数据流。没有固定加速门槛，也不要求 NCU、cuBLAS、完整 Roofline、Tensor Core、寄存器多输出 tiling 或双缓冲。到一小时仍未完成则记录阻塞。推理中的线性层也需要矩阵乘法，这里先认识输入复用，不扩建框架环境。

## Codex 教学预检：2026-10-28（补全前的历史结果）

现场复核 GTX 1650 / CC 7.5 / 14 SM / warpSize=32 / 4096 MiB、驱动 610.88，NVCC 12.9.86、NCU/Compute Sanitizer 2025.2.1.0。正式骨架与仅替换两处 TODO 占位的临时版均编译无警告、无 spill；naive 使用每线程 53 个寄存器、0 字节 shared，tiled 骨架为 31 个寄存器，临时补全版为 39 个，两版 tiled 的静态 shared 均为 2048 字节。寄存器数字来自编译报告；NCU 分配后的数值为 naive 56、tiled 40，口径分别保留。

正式骨架的 naive 两种 shape 均 PASS；tiled 主 shape 的 65536 项与尾部 1961 项均 FAIL，最大绝对误差分别为 3.4921875 与 1.3125，check/bench 预期退出 1，bench 拒绝计时。这是零占位的教学状态。临时补全版四组全量校验均 PASS，最大绝对/相对误差均 0，check/bench 退出 0。两版均运行 memcheck（padding=32）、racecheck、synccheck：零工具错误，racecheck 零 warnings；骨架因目标程序练习未完成继承退出 1，补全版均退出 0。

以下只对应临时补全版主 shape `M=N=K=256`，两种算法的 block/grid 均 `(16,16)`；输入 A/B 各 256 KiB，输出 C 为 256 KiB。Event 与 Sanitizer/NCU 分开运行，计时边界、预热与批次沿用上文。

| 本轮证据 | naive | tiled |
| --- | --- | --- |
| 普通 Event 中位数 μs/次 | 155.961597 | 106.156802 |
| L1/TEX global load 请求数 | 1048576 | 65536 |
| L1/TEX global load sectors | 2097152 | 261594 |
| DRAM 读取字节 | 537728 | 528000 |
| NCU 理论 occupancy | 100% | 100% |
| NCU achieved occupancy | 91.85% | 92.86% |

本轮普通 Event 的 naive/tiled 比值约 1.469。请求数确实减少 16 倍，sector 约减少 8 倍，但 DRAM 字节接近；这说明不能把 global load 请求直接当显存读取，也不能由请求倍数推断性能倍数。缓存、请求合并、shared 访问与同步等均可能影响结果，这组指标没有拆分所有耗时来源。NCU 使用默认 kernel replay/缓存控制，各 kernel 采 3 passes，其读数不表示普通预热 Event 的缓存状态。NCU CSV 中 Kbyte 为十进制，例如 537.728 Kbyte 是 537728 字节，不按 KiB 换算。上述结果只用于本机、本输入、本轮观察，不泛化固定加速比。

原始命令、两版源码 SHA-256、临时补全差异、编译资源、全量校验、工具输出与退出码见 [预检日志](../../reports/CH12/preflight-2026-10-28.txt)，可打开的报告见 [NCU](../../reports/CH12/preflight-2026-10-28.ncu-rep)，原始指标见 [CSV](../../reports/CH12/preflight-metrics-2026-10-28.csv)。临时补全源码与二进制已清理，当时的 `build/CH12/tiled_gemm` 对应保留 TODO 的骨架，现已被下文正式补全版替代。NSYS、GUI、SASS 均 NOT RUN，无新增依赖。个人完成两处练习、运行和独立解释仍待验收；这些结果仅为 Codex 教学准备。

## 两处 TODO 正式补全与验证：2026-10-28

按用户要求，Codex 正式实现两处练习。装载时各线程分别检查 A 的行/K 边界和 B 的 K/列边界，取有效输入或填零；计算时累加 `a_tile[ty][p]*b_tile[p][tx]`，两次 block barrier 继续分别保护写后读和读后覆盖。移除零占位、unused 参数处理及过时提示；naive、shape、block/grid、输入、容差与计时方式不变。当前正式源码和 build 均已补全。

本轮现场复核 GTX 1650 / CC 7.5 / 14 SM / 4096 MiB、驱动 610.88，NVCC 12.9.86、Compute Sanitizer 2025.2.1.0。正式编译无警告、无 spill；naive/tiled 使用每线程 53/39 个寄存器、0/2048 字节静态 shared。主 shape M=N=K=256 的 65536 项与尾部 M=37,N=53,K=29 的 1961 项，两种方法均全量 PASS，最大绝对/相对误差均 0。memcheck（padding=32）、racecheck、synccheck 均零错误，racecheck 零 warnings；check、工具命令、bench 均退出 0。

普通 Event 仍为 warmup=10、samples=21、batch=5，仅测主 shape；naive/tiled 中位数为 157.452798/107.673597 μs/次，比值 1.462316。区间不含分配、传输及 CPU reference/校验，可能含 host 提交间隙；与工具检查分开运行，不与历史预检作优化 A/B，不推广固定加速比。本轮 NCU、NSYS、GUI、SASS 均 NOT RUN，上节 NCU 只作为历史临时版证据。

命令、正式源码 SHA-256、编译资源、输出与退出码见 [正式补全日志](../../reports/CH12/completed-2026-10-28.txt)。本轮未创建临时补全源码或二进制，无新增依赖或计划偏离；实现与验证均为 Codex 辅助完成，个人运行及独立解释待验收。
