# Ch10：从 shared 树形求和到 warp shuffle

归约就是把许多输入逐步合成一个结果，比如把 256 个数合成一个和。前章让线程交换数据，本章让线程交换并合并已有的片段和；warp shuffle 可以让同一个 warp 的线程直接取得彼此手里的值，减少通过 shared 中转和等待整个 block 的次数。

本章对应 [PLAN](../PLAN.md) 阶段 B，计划 45～60 分钟，源码为 [CH10/reduction.cu](../../CH10/reduction.cu)。复用 Ch08 的 shared/barrier、Ch06 的 warp/lane 和前章的校验、Event 骨架。只对照求和的协作方式，不改变输入、block、每线程读取数或输出含义。前章待验收继续保留，状态与工作量只在 [RECORD](../RECORD.md) 维护。

2026-10-27 已按用户先后要求由 Codex 补全 TODO(1) 和 TODO(2)，当前源码可直接执行两方法 check 与 bench。下文练习步骤保留作复习；当前 check 应为 shared/shuffle 均 PASS、整体退出 0，个人解释仍待验收。

## 先预测：谁最终拿到一个 block 的和

用约 5 分钟看任务：输入是 262144 个 float32，grid=1024、block=256，每个线程读一项，每个 block 负责连续的 256 项，写出一个 partial。GPU 输出 1024 个片段和，再由 CPU 汇总总和；本章没有实现一个 kernel 内跨 block 归约，也不学习 atomic 或第二级 GPU kernel。

```text
CPU 输入 262144 项 → H2D
  → 1024 个 block 各自把 256 项合为 1 项
  → D2H 回读 1024 个 partial → 逐片对照 CPU reference → CPU 汇总总和
```

先想一个 8 项缩小例子，输入为 1..8。把前一半与后一半配对：第一轮留下 6、8、10、12，第二轮留下 16、20，第三轮留下 36。预测完整 256 项需要几轮，为什么只看线程 0 的原始输入不能得到整个 block 的和，以及两种实现是否必须输出相同结果。

## 先完成 shared 版本

原练习用约 10 分钟阅读 `block_sum_shared()` 和 main 的数据流，再用约 10 分钟完成 TODO(1)，当前已实现 `tile[tid] += tile[tid + stride];`。`tile[tid]` 初始存该线程读到的数；stride 从 128 依次减半到 1。每轮 `tid < stride` 的线程把自己负责的片段和与距离 stride 的另一个片段和合并，写回自身槽位。练习只改合并语句，不改循环、reference 或同步。

以线程 0 为例，stride=128 时合并输入 0 与 128；stride=64 时读取的 tile[64] 已经是输入 64 与 192 的和。因此本轮依赖的可能是其他线程在上一轮刚写出的结果。`__syncthreads()` 留在 if 外，所有线程每轮都到达；即使某线程不再做加法，也不能提前 return 或跳过 barrier。最后只有线程 0 将 tile[0] 写出，其他线程的槽位不代表完整 block 和。

每个 block 的 shared 数组独立，`__syncthreads()` 只协调本 block。host 上的 `cudaDeviceSynchronize()` 负责等 kernel 完成，无法修复 kernel 内缺失的轮间顺序。[CUDA 12.9：Synchronization Functions](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#synchronization-functions)

原分阶段练习只完成 TODO(1) 时为 shared PASS、shuffle FAIL、整体退出 1；当前两处均已实现，不再预期该阶段性失败。

## 再完成 shuffle 版本

原练习再用约 10 分钟读 `warp_sum()` 与 `block_sum_shuffle()`，完成 TODO(2)，当前已实现 `value += __shfl_down_sync(0xffffffffu, value, offset);`。`__shfl_down_sync(mask, value, offset)` 返回同一 warp 中 lane+offset 当前持有的 value；它不会自动求和，还需把取回的值加到自己的 value。循环 offset=16、8、4、2、1，每一轮都交换本轮开始时的值，只有最后的 lane 0 保证得到完整 warp 和。

例如只看前两轮，lane 0 先合并输入 0 和 16；接着取得 lane 8 已合并的输入 8 和 24，于是手里包含四项。后续继续合并互不重叠的分组。逻辑上源 lane 超过 31 时返回调用者自己的值，并不自动补零；这些高 lane 的最终结果不用于输出，lane 0 的完整和不依赖那些越界来源结果。

本章使用固定 `mask=0xffffffffu`，表示完整 32 个 lane 参与。参与线程必须执行同一个 intrinsic，使用相同 mask；读取未参与线程的值无定义。本章不做非完整 warp、动态 mask 或任意 N 的泛化。[CUDA 12.9：Warp Shuffle Functions](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#warp-shuffle-functions)

一个 block 有 8 个 warp。第一阶段每个 warp 的 lane 0 把自己的 32 项和写入 `warp_partial[warp]`，然后整个 block 同步。第二阶段只让 warp 0 工作，但这个 warp 的全部 32 个 lane 都调用 warp_sum：lane 0..7 读取 8 个片段和，lane 8..31 输入 0，最后 lane 0 写出 256 项的和。不要把条件改成 `lane < 8` 后才调用 shuffle；那会让 full mask 指向未参与的线程。

shuffle 交换的是线程手里的值，不提供 shared memory 的内存顺序保证，也不能越过 warp 边界。8 个 warp 通过 shared 交接的那次 `__syncthreads()` 必须保留。[CUDA 12.9：Warp Shuffle Functions](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#warp-shuffle-functions)

## 编译、校验与观察

用约 15 分钟完成重新编译、校验与普通计时。在项目根目录执行，每次改源码都重新编译：

```bash
mkdir -p build/CH10
nvcc -std=c++17 -O2 -arch=sm_75 -lineinfo -Xcompiler=-Wall,-Wextra \
  CH10/reduction.cu -o build/CH10/reduction && \
  ./build/CH10/reduction check
```

最初未填 TODO 的骨架两方法均 FAIL，只补 TODO(1) 时 shared PASS、shuffle FAIL；这些是历史阶段行为。当前两处已补全，应各检查 1024 个 partial，mismatches=0、max_abs_error=0、total=expected_total=-184，第一片为 -189，整体退出 0。host 每模式先填 NaN 哨兵，避免上一方法的正确输出掩盖遗漏写出。只校验总和可能漏掉片段间相互抵消的错误，所以逐片校验也必须通过。

输入为 `((i*17+(i/256)*13)%101)-50`，包含正、负数和零，用 float 保存小整数。中间和的绝对值不会超过可精确表示的整数范围，因此这里要求误差 0。一般浮点输入改变加法顺序可能改变舍入，不能把本例的精确相等推广到任意浮点归约。

完成 TODO 后执行以下检查。数值 PASS 与访问、同步正确是不同证据：

```bash
compute-sanitizer --tool memcheck --padding 32 --error-exitcode 99 \
  ./build/CH10/reduction check
compute-sanitizer --tool racecheck --error-exitcode 99 \
  ./build/CH10/reduction check
compute-sanitizer --tool synccheck --error-exitcode 99 \
  ./build/CH10/reduction check
./build/CH10/reduction bench
```

bench 先全量校验两种方法，都通过才各预热 10 次，采 21 个样本，每个同 stream Event 区间启动 10 次，除以 10 后取中位数。计时含 kernel 的 global/shared 访问、计算、同步及可能的 host 提交间隙，不含分配、H2D/D2H、CPU reference 或 CPU 汇总，不是端到端总和耗时。不把 Sanitizer 或 profiler 内的耗时混入普通样本。

shared 版本源码有初始 barrier 加 8 轮 barrier，预留 256 个 float；shuffle 版本只用 8 个 float 交接和一次 block barrier。它们是协作方式带来的实现差别；Event 耗时本身不能把差值全部归因于某一种指令。本章没有固定加速比要求，也不要求新增 NCU 指标、SASS 学习或 occupancy 调参。

## 用自己的话解释

最后约 10 分钟，结合源码解释 stride=64 时线程 0 读取的是谁已更新的结果，为什么 barrier 必须放在 if 外；再解释 256 项如何经 8 个 warp 和 warp 0 合成一个 block 和，为什么只有 8 个有效 partial 时仍让 32 个 lane 参加最后一轮 shuffle。

验收需要两处 TODO 生效、逐片与总和校验通过、三种 Sanitizer 零错误，以及上述独立解释；计时无固定收益门槛。到一小时仍未完成就记录阻塞，不追加任意长度归约或 GPU 全局归约。本章的局部合并方式以后可用于统计量、softmax 等计算，只在这里建立协作直觉。

## Codex 预检：2026-10-26

现场复核 GTX 1650 / CC 7.5 / warpSize=32 / 4096 MiB、驱动 610.88，NVCC 12.9.86、Compute Sanitizer 2025.2.1.0。shape=[262144]、float32、grid=1024、block=256，输入 1 MiB、输出 4 KiB。正式骨架与只改 TODO 的临时补全版均编译无警告。

正式骨架两方法各有 1014 个 partial 不匹配，最大误差 232、总和 -11，check 和 bench 均按预期退出 1，bench 跳过计时。只补 TODO(1) 的临时阶段版 shared PASS、shuffle FAIL；两处补全后两方法各检查全部 1024 个 partial，最大误差 0、总和 -184，第一片 -189，check/bench 退出 0。

正式骨架和临时补全版各自经过 memcheck（padding=32）、racecheck、synccheck，均零工具错误，racecheck 零 warnings。骨架因数值校验失败退出 1，工具显示 Target application returned an error；这不等于 Sanitizer 检出了访问错误。临时补全版均退出 0。

独立普通 bench 的 shared/shuffle Event 批次平均每次启动中位数为 49.526399/29.548800 μs，本轮比值 1.676，仅适用于本次设备、输入和计时边界。临时补全版编译资源分别为 shared=1024/32 字节、寄存器=12/14 个每线程，均无 spill。教学方查看 SASS 确认保留 shuffle 与 block barrier，不把静态指令数当动态计数或完整因果证明。

原始命令、源码 SHA-256、输出、退出码、资源信息和 SASS 见 [preflight-2026-10-26.txt](../../reports/CH10/preflight-2026-10-26.txt)。临时补全源码与二进制已清理，当日正式 `build/CH10/reduction` 对应保留两处 TODO 的骨架；10 月 27 日先更新为只完成 TODO(1)，随后又按要求补全 TODO(2) 并重新编译。NCU、NSYS、GUI 均 NOT RUN，无新增依赖。这些是教学预检，不是个人完成或掌握证据。


## TODO(1) 正式补全与验证：2026-10-27

按用户要求，Codex 补全 shared 的片段和累加，保留 TODO(2)。正式重编译无警告，shared 全部 1024 个 partial PASS、误差 0、总和 -184、第一片 -189；shuffle 仍 FAIL，整体 check 预期退出 1。memcheck（padding=32）、racecheck、synccheck 均零工具错误，racecheck 零 warnings，因目标程序 shuffle 校验失败同样退出 1。本次未运行 bench、NCU、NSYS 或 GUI，未新增临时源码或二进制；命令与证据见 [shared-completed-2026-10-27.txt](../../reports/CH10/shared-completed-2026-10-27.txt)。实现和验证由 Codex 完成，个人解释待验收。


## TODO(2) 正式补全与验证：2026-10-27

按用户要求，Codex 在 warp_sum 中实现 shuffle 取值后累加，并移除最后一处 TODO。固定完整 warp 和原有跨 warp barrier，正式编译无警告；shared/shuffle 各自全部 1024 个 partial PASS、误差 0、总和 -184、第一片 -189。memcheck（padding=32）、racecheck、synccheck 均零错误，racecheck 零 warnings，check、工具检查及 bench 均退出 0。

独立普通 bench 为 warmup=10、samples=21、batch=10，shared/shuffle 的 Event 批次平均每次启动中位数为 29.046401/16.640000 μs，本轮比值 1.746；计时边界沿用上文，不与历史轮次作优化 A/B，也不推断普遍收益。本次 NCU、NSYS、GUI 均 NOT RUN，无临时源码或二进制；原始命令、源码 SHA-256、输出和退出码见 [completed-2026-10-27.txt](../../reports/CH10/completed-2026-10-27.txt)。两处实现均由 Codex 完成，个人运行与独立解释待验收。
