# Ch07：合并访存与 NCU

合并访存的直觉是：同一 warp 的线程需要的数据挨得越近，GPU 越容易用较少的内存访问单元把数据取齐。本章写一个读取索引，对比连续读取与跨步读取，再用 Nsight Compute（NCU）的两个计数器解释差异。计划 45～60 分钟，对应 [PLAN](../PLAN.md) 阶段 B；源码为 [CH07/memory_access.cu](../../CH07/memory_access.cu)，学习进度和工作量只在 [RECORD](../RECORD.md) 维护。

复用 Ch02 的全局索引、Ch03 的错误检查、Ch04/06 的预热与 Event 计时。Ch06 的个人解释仍待验收，本次按用户明确请求准备 Ch07，不将前章自动标为完成。此前主动接触过 NCU 分支观察，本章正式学习的是访存计数；不要求先掌握 Source/SASS、shared memory、bank conflict 或完整缓存体系。

Codex 提供 host、输入、独立 CPU reference、连续模式、校验和计时骨架。原练习为 `input_index()` 中跨步模式的一处 TODO，2026-10-21 已按用户要求由 Codex 补全。当前正式源码可直接运行，两模式应全量 PASS；索引实现与验证由 Codex 完成，用户个人解释待验收。历史占位版的预期 FAIL 见下方 10 月 20 日预检。

## 先预测：一个 warp 需要多少块数据

花约 5 分钟看第一组 32 个线程的读取位置。float32 每项 4 字节，连续模式读取 0～31 项，总共 128 字节；跨步模式读取 0、32、64……992 项，相邻线程的读取地址相隔 128 字节。两种模式始终连续写 `output[i]`，每线程都只做一次读取、一次 `+1.0f` 和一次写出。

```text
lane                  0    1    2    3   ...   31
连续读取的 input 下标   0    1    2    3   ...   31
跨步读取的 input 下标   0   32   64   96   ...  992
两者的 output 下标     0    1    2    3   ...   31
```

sector 可以理解为这里统计访存时使用的 32 字节小块。对本章对齐的连续访问，一个完整 warp 需要 4 个 sector；上述跨步访问则涉及 32 个不同 sector。先写下预测：哪个模式每次请求涉及的 sector 更多，哪个可能更慢？这里的 4/32 是访问形状的推断，后面要和实际计数核对。[CUDA 12.9 合并访存说明](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-best-practices-guide/index.html#coalesced-access-to-global-memory)

合并发生在同一 warp 的一次内存指令上。不能只看整个 kernel 最终读到的地址集合是否连续，也不能说“一个 warp 的读取总能合成一次传输”。

## 读代码并理解读取索引

约 10 分钟阅读 `access_pattern()`、`input_index()` 和 `run()`，再用约 15 分钟手算下标并对照已补全的实现。程序流程沿用前章：

```text
CPU 准备输入与两套 reference → 分配和 H2D
  → contiguous 启动、回读、全量校验
  → strided 启动、回读、全量校验
  → bench 模式且两者通过时：预热、Event 成对采样
  → 释放 GPU 内存
```

本章固定 N=4194304、float32、block=256、grid=16384。GPU 输入和输出各 16 MiB，总计 32 MiB；没有为跨步模式扩建一个稀疏大数组。把一维输入按每 1024 项分组，每组想象成按行存放的 32×32 小表格。这里只是计算下标，没有使用 shared memory。

连续模式按行读取，小片内的线程编号对应 `(row, col)`；跨步模式读取同一小片的 `(col, row)`。第一个 warp 读第 0 列，第二个 warp 读第 1 列，直到第 32 个 warp 读第 31 列，再进入下一个小片。这样两种模式都恰好读取原数组的每项一次，只改变同一 warp 内地址的排列。

原 TODO 位于 `input_index(i, mode)`。`i` 是全局输出下标；mode=0 直接返回 i，mode=1 先用 `(i / kTileElements) * kTileElements` 定位小片起点 base，再对片内偏移 `i-base` 整除/取余 kSide 得到 row/col，最后返回 `base + col * kSide + row`。保留 base 可使不同小片各自读取自己的元素；不要修改 CPU reference 来迁就错误实现。

先手算以下对应关系，再对照代码，检查没有漏掉小片起点：

| 输出下标 i | 连续模式输入下标 | 跨步模式输入下标 |
| --- | --- | --- |
| 0 | 0 | 0 |
| 1 | 1 | 32 |
| 31 | 31 | 992 |
| 32 | 32 | 1 |
| 1023 | 1023 | 1023 |
| 1024 | 1024 | 1024 |
| 1025 | 1025 | 1056 |

不能直接写 `i * 32`，那会超出当前数组，也不能用 `(i * 32) % N`，那会重复读取部分元素。目标是每个小片内的行列交换。两种输出顺序不同，所以分别对照自己的 reference，不要求两种输出数组彼此相等。

`input[i]=i*0.25f` 让不同位置拥有不同且可精确表示的值，输出统一加 1；全量校验要求最大绝对误差为 0，并拒绝 NaN/Inf。`mode` 在一次 launch 内对所有线程相同，本例的主要对照是读取地址，不是 Ch06 的 warp 内分路。

## 编译、校验和普通计时

以下命令在项目根目录执行。当前索引已补全，编译后先校验两模式；今后修改源码需保存并重新编译。编译成功后才运行，避免执行旧二进制：

```bash
mkdir -p build/CH07 reports/CH07
nvcc -std=c++17 -O2 -arch=sm_75 -lineinfo \
  -Xcompiler=-Wall,-Wextra CH07/memory_access.cu -o build/CH07/memory_access \
  && ./build/CH07/memory_access check
```

当前完成版两者都应 `mismatches=0`、`max_abs_error=0`、退出 0。历史原骨架的 contiguous PASS、strided FAIL、计时 NOT RUN 和退出 1 是占位的预期，不适用于当前完成版。校验通过后再运行普通计时：

```bash
./build/CH07/memory_access check && ./build/CH07/memory_access bench
```

`check` 是默认模式，每种访问各启动一次，不预热、不计时。`bench` 先校验，每种模式预热 10 次、取 21 个样本，每个样本在同一 stream 的 Event 之间连续启动 5 次；轮换两个模式的采样顺序，每批回读校验放在计时区间外。

比较两行 `event_batch_per_launch_median_us`：每个 Event 批次耗时除以 5，再对 21 个样本取中位数，单位 μs。不含分配、传输、CPU reference、校验或释放，仍可能包含 host 提交间隙；不是含传输的 host 端到端时间。两种模式的地址计算与缓存复用也不同，耗时差不能全部归为某一次显存传输的成本。正常计时不要套 NCU 或 Sanitizer。

若自己的索引校验失败或需要确认没有越界，可独立运行已有的内存检查命令；不要拿这次工具下的时间比较性能：

```bash
compute-sanitizer --tool memcheck --padding 32 --error-exitcode 99 \
  ./build/CH07/memory_access check
```

## 正式用一次 NCU 采集解释访问

约 15 分钟完成计时和采集对照。NCU 用来查看单次 kernel 的硬件计数；本章只看“发了多少读取请求”和“这些请求涉及多少 sector”。先确保普通 `check` 通过，再单独采集它的两次启动：

```bash
ncu --kernel-name access_pattern --launch-count 2 \
  --metrics l1tex__t_requests_pipe_lsu_mem_global_op_ld.sum,l1tex__t_sectors_pipe_lsu_mem_global_op_ld.sum \
  --import-source yes --export reports/CH07/user_coalescing_01 \
  ./build/CH07/memory_access check
```

`--kernel-name` 只选目标 kernel，`--launch-count 2` 只采集两次启动。按当前 `check` 的代码顺序，第一个结果为 contiguous（mode=0），第二个为 strided（mode=1）；不是两个不同的 kernel 名称。`--metrics` 只点名本章的两个计数器，`--export` 生成 `.ncu-rep`，`--import-source yes` 保存源码以便回看。重复采集换一个未使用的文件名，不覆盖旧报告。

采集应显示两次 `access_pattern`，程序两模式仍须全量 PASS。每次 launch 可能显示若干 `passes`，这是工具为收集指标进行的重放，不是程序主动启动次数，也不是学习时需要调优的参数。NCU 耗时受到采集和重放影响，性能比较使用前面的普通 `bench`。[NCU CLI 参数](https://docs.nvidia.com/nsight-compute/NsightComputeCli/index.html)

先用 CLI 读取，完成实验不依赖 GUI：

```bash
ncu --import reports/CH07/user_coalescing_01.ncu-rep \
  --page details --print-units base
```

每个结果先确认 grid=(16384,1,1)、block=(256,1,1)，再读两个指标。GUI 可打开同一报告，在 Results 中按顺序切换两个结果，到 Details 的 `Command line profiler metrics` 查看；本章不要求读 SASS。

| 指标 | 本章解释 |
| --- | --- |
| `l1tex__t_requests_pipe_lsu_mem_global_op_ld.sum` | 经 L1/TEX 路径处理的 global load 请求总数 |
| `l1tex__t_sectors_pipe_lsu_mem_global_op_ld.sum` | 这些 global load 请求涉及的 32 字节 sector 总数 |

用第二个数除以第一个数，得到平均每次读取请求涉及的 sector 数。当前 kernel 每线程读一个 float，且无尾部不完整 warp，预期每个 warp 发一次读取请求。两模式请求数应接近或等于 N/32，跨步模式的 sector/request 更大。若不同，先查编译后的版本、参数、launch 对应和是否正确补完，不为了匹配预期改计数。

这些计数描述 L1/TEX 处理的访问，**不是到 DRAM 的实际字节数**。不同 warp 可能访问同一 sector 的不同元素，后续读取可以命中缓存。因此 sector/request 从 4 到 32，不等于显存流量一定增加 8 倍，也不等于程序一定慢 8 倍；本章不额外测量或推断 DRAM 流量。[NCU Memory Tables 指标口径](https://docs.nvidia.com/nsight-compute/ProfilingGuide/index.html#memory-tables)

## 解释与验收

最后约 10 分钟，把自己的正常计时输出和两次 NCU 结果对应起来，说明第一个 warp 在两个模式下各读哪些地址，为什么请求数可相同而 sector 数不同，以及为什么计数比值不能直接当作减速倍数。指出索引实现、全量正确性输出、两个原始计数和 Event 时间边界即可。

验收需两种模式全量 PASS、普通计时有效、NCU 两结果可对应，以及你自己的解释；不要求固定加速比。代码练习、采集和个人解释未完成前不记 DONE。到一小时仍有问题，保留当前输出和阻塞，不追加缓存策略或 SASS 深挖。与推理 kernel 的联系是：相邻线程如何分配张量元素，会影响同一次读取能否高效合并。

## Codex 预检：2026-10-20

以下是 10 月 20 日教学方对临时补全版的历史预检，当时正式 TODO 尚未完成，不代表用户已掌握。正式练习版和临时补全版均使用上述 nvcc 选项编译，无警告；NVCC 12.9.86、NCU 2025.2.1.0、Compute Sanitizer 2025.2.1.0，GTX 1650 / CC 7.5 / warpSize=32 / 4096 MiB，驱动 610.88；程序查询 L2=1048576 字节。输入 shape=[4194304]、float32，grid=16384、block=256、每片 32×32。

当日正式占位版的 check/bench 都为 contiguous PASS，strided FAIL（4063232 项不符、最大误差 240.25），计时 NOT RUN、退出 1。临时补全版 check/bench 两模式各 4194304 项全量通过、误差 0；单独 memcheck 零错误，均退出 0。当日正式源码保留唯一 TODO，随后于 10 月 21 日按用户要求补全。

普通计时每模式 warmup=10、samples=21、batch=5；Event 批次平均每次启动中位数如下。NCU 在另一次 check 运行中只采两次 launch、每次 3 passes，应用仍全量通过；下表明确分开两种运行的结果：

| 观察 | contiguous | strided |
| --- | --- | --- |
| 普通 Event 中位数（μs） | 317.452788 | 684.985590 |
| NCU global load requests（sum） | 131072 | 131072 |
| NCU global load sectors（sum） | 524288 | 4194304 |
| sectors / request | 4 | 32 |

本机此次跨步模式较慢，动态计数与地址预测一致；不据此承诺其他输入、缓存条件或架构的性能比例。教学方检查临时完成版 SASS，保留一次 `LDG`、一次 `FADD` 和一次 `STG`，读取未被优化消除；该静态排查不属于用户必学内容。

原始命令与输出见 [preflight-2026-10-20.txt](../../reports/CH07/preflight-2026-10-20.txt)，NCU [报告](../../reports/CH07/ncu-preflight-2026-10-20.ncu-rep)、[Details](../../reports/CH07/ncu-preflight-2026-10-20-details.txt)、[Raw CSV](../../reports/CH07/ncu-preflight-2026-10-20-raw.csv) 和 [SASS](../../reports/CH07/completed-2026-10-20-sm75.sass.txt) 保留复盘。Raw CSV 为宽表，含独立单位行，核对结果 ID 0/1 后再计算比值。临时补全源码与二进制在预检核对后清理，当日正式 build 为保留 TODO 的练习版，10 月 21 日已重编译为正式完成版；预检报告导入的仍是临时补全版源码。GUI 人工打开与本章 NSYS 采集 NOT RUN。

## 正式 TODO 补全与验证：2026-10-21

用户要求“完成todo”，Codex 补全 `input_index()` 的小片定位和行列交换，并将校验失败时的计时提示改为正确性检查失败。输入、CPU reference、kernel 读写和计时配置沿用原实现。当前正式源码已无 TODO，个人解释待验收。

复核 NVCC 12.9.86、Compute Sanitizer 2025.2.1.0、GTX 1650 / CC 7.5 / warpSize=32 / 4096 MiB、驱动 610.88。按上述 nvcc 命令编译无警告，正式 check/bench 两模式各 4194304 项全量 PASS、mismatches=0、最大绝对误差 0；独立 memcheck 零错误，均退出 0。普通计时使用相同 shape/dtype、grid/block 和 warmup=10、samples=21、batch=5，Event 批次平均每次启动中位数 contiguous=317.593598 μs、strided=689.043188 μs，Timing PASS。仅为本机本次结果，不与历史预检作优化 A/B，不推断固定性能比例。

本次未重新运行 NCU、NSYS、SASS 导出或 GUI，前一节计数仍属于 10 月 20 日临时补全版，不能当作本次采集。命令、输出和源码 SHA-256 见 [completed-2026-10-21.txt](../../reports/CH07/completed-2026-10-21.txt)。实现和验证由 Codex 完成，用户运行、NCU 采集及个人解释待验收。
