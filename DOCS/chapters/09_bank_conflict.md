# Ch09：shared memory 的 bank conflict 与 padding

bank 可以先理解为 shared memory 中能并行服务的存储通道。同一个 warp 访问不同地址，却挤进同一个 bank 时，访问需要拆开处理，这就是本章要观察的 bank conflict。给每行末尾留一个空位，让下一行错开一个 bank，称为 padding。

本章对应 [PLAN](../PLAN.md) 阶段 B，计划 45～60 分钟，源码为 [CH09/bank_conflict.cu](../../CH09/bank_conflict.cu)。复用 Ch08 的 shared 写入、barrier 和伙伴读取，复用 Ch07 的 NCU 采集方法；只改变 shared tile 的行跨度 32/33，学习 bank 映射与 padding 两个紧密相关的概念。前章个人解释待验收继续保留，进度和工作量只在 [RECORD](../RECORD.md) 维护。

2026-10-23 已按用户要求由 Codex 补全唯一的地址 TODO，当前正式源码使用 `row*stride+col`，可直接执行下文 check、bench 与 NCU 命令。以下练习说明保留作复习，原占位版及 10 月 22 日临时版结果属于历史预检；个人解释仍待验收。

## 先预测：为什么多留一个位置可能有用

用约 5 分钟看这个任务：输入为 1024 个独立的 32×32 小矩阵，每片单独转置，即 output[b,r,c]=input[b,c,r]。这不是把所有小片拼成一个大矩阵再转置。两种布局必须得到完全相同的结果。

每个 block 处理一片，block=(32,8)，共 256 个线程、8 个 warp。`threadIdx.x` 先变化，因此一个 warp 中 x=0..31、y 固定；每线程用四次循环处理 4 项。写入时 warp 沿一行放数据，barrier 后沿一列取数据，再连续写到 global 输出。

假设一个 warp 读取逻辑第 0 列，先预测下面两种布局的 bank 分布，再预测两模式的数值是否应该不同：

| 布局 | lane 0、1、2、31 读取的 float 下标 | bank 编号，按 float 下标模 32 |
| --- | --- | --- |
| 行跨度 32 | 0、32、64、992 | 先自行计算 |
| 行跨度 33 | 0、33、66、1023 | 先自行计算 |

这里限定本机 SM75、每线程一次 32-bit float shared 访问：相邻 float 映射到相邻 bank，共 32 个 bank；bank 编号可由 shared 字节地址除以 4 后模 32 得到。本例 tile 从 bank 0 对齐开始，可直接用 tile 的 float 下标模 32。多个线程读取**同一个 32-bit 字**可以广播；本章读的是同列的不同行，地址不同，不属于这种情况。[CUDA 12.9：Shared Memory and Memory Banks](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-best-practices-guide/index.html#shared-memory-and-memory-banks)

## 读程序，理解原 TODO 的实现

原练习用约 10 分钟阅读 `shared_transpose()`，再用约 15 分钟修改 `shared_index()`。它输入逻辑 row、col 和每行占用的 float 数 stride，输出 shared 数组下标。当前实现为 `row*stride+col`：先找到该行起点，再加列偏移。global 地址、CPU reference、循环次数和 barrier 均沿用原设计。

```text
CPU 输入 [1024,32,32] → H2D
  → tile[row,x] 按行写入 → __syncthreads()
  → tile[x,col] 按列读取 → 连续 global 写出
  → 等待完成 → D2H → 与 CPU 转置结果逐项比较
```

`base` 是当前小片在 global 数组中的起点；`x` 是 warp 内 lane 对应的列编号，`y` 是 warp 所在行组。写入循环中 row=y+j；读取循环中 col=y+j、row=x。注意 `output[base+col*32+x]` 对应输出的第 col 行、第 x 列，读取的是输入的第 x 行、第 col 列。因此 global 输入和输出在每个 warp 内都连续，两个布局的 global 地址也完全相同。

`shared_transpose<32>` 和 `<33>` 是同一段 kernel 按不同编译期常量生成的两个版本，只需理解为两种布局。二者都预留 `32*33*sizeof(float)=4224` 字节 shared，避免把预留资源大小也变成实验变量；stride 32 只用前 1024 个槽位，stride 33 则每行末尾留一个空位。padding 不属于逻辑矩阵，不参与写出，也不用初始化。

历史占位实现固定使用行跨度 32、忽略 stride，所以**修改前 check 也会两模式 PASS**。这是因为转置数据流已提供，当时尚未完成的是布局对照。`stride_arg=33` 只表示请求的参数，不单独证明实际寻址已经改变。当前已移除 `(void)stride` 并使用传入 stride，让写入和读取共用同一个地址转换入口；padding 是否生效仍结合 NCU 计数确认。

`volatile` 是为本微基准保留可观察的 shared 访问；它不能代替 `__syncthreads()`。这里有跨 warp 交接，必须保留写后读 barrier；读取后不再覆盖复用 tile，所以不需要再加一轮 barrier。源码/SASS 核验由 Codex 完成，不作为本章新练习。

## 重新编译与校验

以下命令在项目根目录执行，每次修改后重新编译，避免运行旧程序：

```bash
mkdir -p build/CH09
nvcc -std=c++17 -O2 -arch=sm_75 -lineinfo -Xcompiler=-Wall,-Wextra \
  CH09/bank_conflict.cu -o build/CH09/bank_conflict && \
  ./build/CH09/bank_conflict check
```

每模式检查全部 1,048,576 项，要求 mismatches=0、max_abs_error=0、退出 0。输入为 input[i]=i*0.25f，第一片中 output[1]=8、output[32]=0.25。这里只移动可精确表示的数，不需要浮点容差。host 每轮先将 output 填为 NaN 哨兵，再启动 kernel，避免上一模式的结果掩盖遗漏写出。

先确认访问和同步正确，再采集计数器。这些工具仍检查程序错误，不能代替下一步的性能证据：

```bash
compute-sanitizer --tool memcheck --padding 32 --error-exitcode 99 \
  ./build/CH09/bank_conflict check
compute-sanitizer --tool racecheck --error-exitcode 99 \
  ./build/CH09/bank_conflict check
```

## 用 NCU 检查 padding 是否生效

用约 20 分钟完成校验和这次采集。check 正好启动两个目标 kernel，先 `<32>` 后 `<33>`，没有 warmup 或计时 launch。沿用 Ch07 的过滤，只读 shared load/store 两个冲突计数：

```bash
mkdir -p reports/CH09
ncu --kernel-name 'regex:shared_transpose' --launch-count 2 \
  --metrics l1tex__data_bank_conflicts_pipe_lsu_mem_shared_op_ld.sum,l1tex__data_bank_conflicts_pipe_lsu_mem_shared_op_st.sum \
  -o reports/CH09/user-bank-01 ./build/CH09/bank_conflict check
ncu --import reports/CH09/user-bank-01.ncu-rep --page details
```

每次保存换一个新文件名，保留自己的输出。带 `-o` 的采集主要打印进度与报告路径，第二条命令读取报告中的指标；也可用 NCU GUI 打开，但 GUI 操作不是必需验收。内核 replay passes 是工具内部重复采集，不是更多种布局。[Nsight Compute CLI：Quickstart](https://docs.nvidia.com/nsight-compute/NsightComputeCli/index.html#quickstart)

`...shared_op_ld.sum` 表示 shared 读取的 bank conflict 累计计数，`...shared_op_st.sum` 对应写入，sum 汇总本次 kernel 的各硬件实例。它们不是错误数、不是 global sector 数，也不是 DRAM 字节数。完整指标名已用本机 NCU 2025.2.1 查询，并与其安装文档的 shared_ld_bank_conflict/shared_st_bank_conflict 映射核对。

补全后，warp 按列读取时，stride 32 的 bank 为 `(lane*32+col)%32=col`，32 个不同地址挤在一个 bank；stride 33 为 `(lane*33+col)%32=(lane+col)%32`，分散到全部 bank。按行写入始终是相邻 x 访问相邻 float，预计两种写入都无冲突。若两模式数值 PASS、读取冲突却同样高，先检查 TODO 是否仍忽略 stride、是否重新编译，以及读写是否都调用同一个 helper。

这与 Ch07 的 global 合并访存发生在不同位置：本章没有改变 global 的 warp 地址分布。它也与 Ch08 缺 barrier 的 race 不同：bank conflict 是正确访问的服务效率问题，不能靠增加 barrier 消除；race 是线程间读写缺少顺序保证，padding 不能修复它。

## 可选计时与自己的解释

还有时间再独立运行 `./build/CH09/bank_conflict bench`。先完整校验两布局，再各预热 10 次；每个 Event 区间启动 5 次，共 21 个样本，归一化为每次启动时间后取中位数。区间不含分配、传输和 CPU 校验，包含 kernel 中的 global/shared 访问、barrier 及可能的 host 提交间隙。工具采集与普通 bench 分开，NCU 内部时间不混入普通样本。

最后约 10 分钟，用自己的代码与报告解释：为什么同一个 warp 按行写入没有冲突，按列读取却受 stride 影响；多留一列如何改变 bank；为什么两个布局必须输出相同结果，以及为什么正确性 PASS 不能证明 padding 已生效。

验收需要 TODO 生效、全量校验和 memcheck/racecheck 通过、NCU 两个结果能对应读取冲突变化，以及自己的解释。性能没有固定加速比要求，32 路冲突也不等于整个 kernel 必须慢 32 倍。到一小时仍未完成就记录阻塞，不追加 SASS 优化、其他 stride 扫描或 occupancy 专题。本章的布局直觉会用于后续 tiled GEMM。

## Codex 预检：2026-10-22

本次复核 NVCC 12.9.86、NCU/Compute Sanitizer 2025.2.1.0、GTX 1650 / CC 7.5 / warpSize=32 / 4096 MiB、驱动 610.88。shape=[1024,32,32]、float32、grid=1024、block=(32,8)，输入/输出各 4 MiB；两布局实际 shared 均为 4224 字节，寄存器均为 20/thread，未使用 local memory。

正式骨架与临时补全版均编译无警告，check/bench 全量 PASS、最大误差 0；两版各自的 check 经 memcheck（padding=32）、racecheck、synccheck 均零错误/警告，退出 0。临时版只替换 helper 中的占位寻址，未修改其他数据流。

| 版本 / stride_arg | shared load bank conflicts | shared store bank conflicts | 普通 Event 中位数 μs/次 |
| --- | --- | --- | --- |
| 正式骨架 / 32 | 1,015,808 | 0 | 189.760005 |
| 正式骨架 / 33，仍按 32 寻址 | 1,015,808 | 0 | 193.075204 |
| 临时补全版 / 32 | 1,015,808 | 0 | 195.417595 |
| 临时补全版 / 33 | 0 | 0 | 69.984001 |

这些是教学方预检，不是用户完成证据。临时补全版普通计时的本轮比值约 2.792，只适用于本次设备、输入和测量边界；不把骨架与补全版的不同运行作性能 A/B，也不把该比值推成通用 padding 收益。

教学方保存并检查 SASS：两种临时布局均有四条标量 STS、一个 BAR.SYNC、四条标量 LDS.U，目标 shared 访问保留；结合 NCU 动态计数确认对照成立。LDS.U 的名字不能单独证明各 lane 地址一致或没有 bank conflict，不要求学生解读指令后缀。

原始命令、输出、源码 SHA-256 和资源报告见 [preflight-2026-10-22.txt](../../reports/CH09/preflight-2026-10-22.txt)。对应 NCU 报告为 [skeleton](../../reports/CH09/skeleton-2026-10-22.ncu-rep) 和 [completed](../../reports/CH09/completed-2026-10-22.ncu-rep)，SASS 为 [skeleton](../../reports/CH09/skeleton-2026-10-22.sass.txt) 和 [completed](../../reports/CH09/completed-2026-10-22.sass.txt)。临时补全源码及二进制验证后清理，当日正式 build 对应保留 TODO 的骨架；10 月 23 日已更新为正式补全版。该历史预检 NSYS、GUI 均 NOT RUN，无新增依赖。

## 正式补全与验证：2026-10-23

按用户要求，Codex 将 `shared_index()` 改为 `return row * stride + col;`，移除占位代码及过时的 TODO 提示。kernel 的主要功能为每个 block 转置一个 32×32 小矩阵：先把输入按原行列写入 shared，整个 block 写完后同步，再把 shared 的第 x 行、第 col 列写到输出的第 col 行、第 x 列。1024 个 block 分别处理各自的小片，不交换小片位置。

环境复核与 10 月 22 日预检版本一致，shape/dtype、grid/block 和 shared 预留保持不变。正式编译无警告，check/bench 各模式全量 1048576 项 PASS、最大误差 0；memcheck（padding=32）、racecheck、synccheck 的 check 均零错误，racecheck 零 warnings，退出 0。NCU 采集两个目标 launch，stride 32/33 的读取冲突分别为 1015808/0，写入冲突均为 0，确认正式 padding 对照生效。

独立普通 bench 使用 warmup=10、samples=21、batch=5，Event 批次平均每次启动中位数分别为 189.683199/68.320000 μs，本轮比值约 2.776，仅适用于当前设备和输入；不与历史预检跨运行比较。原始命令、输出、退出码及源码 SHA-256 见 [completed-2026-10-23.txt](../../reports/CH09/completed-2026-10-23.txt)，NCU 报告为 [completed-2026-10-23.ncu-rep](../../reports/CH09/completed-2026-10-23.ncu-rep)，两行指标摘要为 [completed-metrics-2026-10-23.csv](../../reports/CH09/completed-metrics-2026-10-23.csv)。本次 NSYS、GUI、SASS 均 NOT RUN，无临时源码或新依赖；实现和验证由 Codex 完成，用户独立解释待验收。
