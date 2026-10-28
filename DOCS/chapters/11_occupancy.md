# Ch11：shared 预留量如何限制 SM 驻留

一个 SM 可以容纳多个 block，但它们要共享有限的线程槽位、寄存器和 shared memory。每个 block 占的资源越多，同时放得下的 block 就可能越少。occupancy 在这里表示“驻留 warp 数占该 SM 最大 warp 数的比例”，不是 GPU 利用率，也不是正在做加法的线程比例。

本章对应 [PLAN](../PLAN.md) 阶段 B，计划 45～60 分钟，源码为 [CH11/occupancy.cu](../../CH11/occupancy.cu)。复用 Ch10 已实现的 shuffle 求和和 Event 骨架，只改每个 block 额外预留的 dynamic shared 字节数。两处 TODO 在 host 查询和启动处，不重写归约。前章待验收保留，学习进度与工作量统一见 [RECORD](../RECORD.md)。

2026-10-28 已按用户先后要求由 Codex 补全 TODO(1) 的 occupancy 查询和 TODO(2) 的动态预留启动参数。当前三组实际预留量与查询量一致，check 和 bench 均应 PASS、退出 0。下文两处练习路线保留作复习；个人运行与独立解释仍待验收。

## 先预测：同样的计算为什么能少放几个 block

约 5 分钟看数据流。输入 N=262144、float32，grid=1024、block=256；每个 block 的 8 个 warp 合作求出 256 项的和，GPU 输出 1024 个 partial，CPU 逐片校验后汇总。输入、读写、算术、barrier、grid、block 和同一个 kernel 均固定。

```text
CPU 输入 → H2D → 同一个 block_sum_shuffle → D2H → CPU reference
                           ↑
             每 block 额外预留 0 / 16384 / 32768 字节
```

dynamic shared 是启动时决定的每 block shared 预留空间，单位是字节。它与 kernel 内 `__shared__ float warp_partial[8]` 的 32 字节静态 shared 相加。这里故意只预留、不访问额外空间，使主要变量落在资源用量上；以后真正用动态数组时才需要 `extern __shared__` 声明，本章无需添加数组或读写。第三个启动参数决定预留量的语义见 [CUDA 12.9：Execution Configuration](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#execution-configuration)。

先预测三组输出是否改变，预留量增加后每 SM 放得下的 block 会怎样，以及耗时是否一定按 occupancy 的倒数变化。预测不必正确，运行后再用证据修正。

## 从一个 SM 的资源算起

用约 10 分钟读 main 的属性输出和 `block_sum_shuffle()`。SM 是 GPU 上执行线程组的处理单元；block 被安排到某个 SM 后，其线程在该 SM 上执行。驻留表示 block 已占用所需执行资源，并不保证其全部 warp 在同一时刻发射指令。1024 个 block 是全 GPU 总工作量，不是每个 SM 同时拥有 1024 个 block，也不由 `blockIdx.x` 指定某个 SM。

本机本轮查询为 14 个 SM，每 SM 最多 1024 线程，即 32 个 warp；固定 block=256，因此每 block 有 8 个 warp。即使 shared 很小，线程槽位也只允许最多 1024/256=4 个此类 block 驻留。

每 SM 有 65536 字节 shared。若增加 16384 字节动态预留，一个 block 还要加静态的 32 字节，4 个 block 已需 `4*(16384+32)=65664` 字节，超过上限；增加 32768 字节时，两个 block 也超限。因此不要用 `64 KiB/16 KiB=4` 忽略静态部分。简单除法只是直觉，实际还受分配粒度、资源配置、寄存器、线程与 block 上限等约束，以 API 和 NCU 核对。本章不同时调寄存器或 block 大小。

```text
理论 occupancy = 每 SM 理论驻留 block 数 × 每 block warp 数 / 每 SM 最大 warp 数
本例：4×8/32=100%，3×8/32=75%，1×8/32=25%
```

API 计算的是资源允许的理论上限，不说明运行时始终达到它，也不执行 kernel。相应官方示例将驻留 block 换算成 warp 比例，见 [CUDA 12.9：Occupancy Calculator](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#occupancy-calculator)。

## 完成两处 host 练习

用约 15～20 分钟完成 `active_blocks_per_sm()` 的 TODO(1)。查 [CUDA Runtime API 12.9：Occupancy](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART__OCCUPANCY.html) 中 `cudaOccupancyMaxActiveBlocksPerMultiprocessor` 的参数：输出地址、kernel、每 block 线程数、每 block 动态 shared 字节数。用 `CUDA_CHECK` 检查调用，将结果写入局部变量 blocks。动态参数只填额外预留量，静态 shared 已由 kernel 属性计入，不能重复加上 32。

然后完成 `launch()` 的 TODO(2)，让 `launch_bytes` 使用当前请求量。已提供的 `<<<kBlocks, kBlock, launch_bytes>>>` 将其作为第三个启动参数传入；不要修改求和 kernel、输入或 block 大小。查询使用的动态字节数和实际 launch 必须一致，否则比较的是两种配置。

最初骨架保留占位：blocks=-1，launch_bytes=0，求和正确但打印 `Occupancy NOT QUERIED`，三组配置均 INCOMPLETE。只完成 TODO(1) 时，0 字节配置通过，另外两组因实际没有预留而 INCOMPLETE，整体退出 1，bench 不计时。当前两处均已补全，三组应数值与资源配置均 PASS。数值 PASS 只能证明求和，还需核对实际 launch 资源。

## 编译、运行与 NCU 对照

用约 15 分钟完成以下操作。每次修改源码后重新编译，在项目根目录执行：

```bash
mkdir -p build/CH11 reports/CH11
nvcc -std=c++17 -O2 -arch=sm_75 -lineinfo -Xcompiler=-Wall,-Wextra -Xptxas=-v \
  CH11/occupancy.cu -o build/CH11/occupancy && \
  ./build/CH11/occupancy check
```

两处补全后，三组 `requested_dynamic_bytes` 与 `launched_dynamic_bytes` 应一致；每组 1024 个 partial 均 PASS、最大误差 0、总和 -184，`Experiment PASS`、退出 0。本例输入和中间和均为 float 可精确表示的小整数，不推广为任意浮点求和必须精确相等。每组运行前填 NaN 哨兵，防止遗漏写出被旧输出掩盖。

```bash
compute-sanitizer --tool memcheck --padding 32 --error-exitcode 99 \
  ./build/CH11/occupancy check
compute-sanitizer --tool racecheck --error-exitcode 99 \
  ./build/CH11/occupancy check
compute-sanitizer --tool synccheck --error-exitcode 99 \
  ./build/CH11/occupancy check
./build/CH11/occupancy bench
ncu --section LaunchStats --section Occupancy \
  --kernel-name regex:block_sum_shuffle --launch-count 3 \
  -o reports/CH11/occupancy ./build/CH11/occupancy check
```

memcheck、racecheck、synccheck 分别核对访问、shared 数据竞争与同步问题，不能只靠数值校验。本章不引入新的同步方式，工具检查由骨架复用。`-Xptxas=-v` 显示寄存器、静态 shared 和 spill；动态空间由 launch 决定，不会因为改启动参数就出现在静态 smem 编译报告里。寄存器只读报告，不额外调参。

NCU 采 check 的三次 launch，顺序对应 0、16、32 KiB；若 TODO 未完成，三次实际预留都为 0，不能用请求标签代替 LaunchStats。查看 Launch Statistics 的动态/静态 shared 和 Occupancy 的 `Block Limit Shared Mem`、`Theoretical Active Warps per SM`、`Theoretical Occupancy`、`Achieved Occupancy`。GUI 可打开报告后逐次选择 launch，CLI 也能直接看表。工具版本与字段若变化，先用 `ncu --list-sections` 核对。

理论 occupancy 是容量上限；achieved occupancy 是采集期间实际 active warp 的平均比例，会受启动/收尾、工作量和执行状态等影响。等待数据的驻留 warp 仍不等于正在发射指令的 warp。高 occupancy 能提供更多可选择的 warp，但不能保证性能更好，见 [NCU：Occupancy](https://docs.nvidia.com/nsight-compute/ProfilingGuide/index.html#occupancy)。若额外 shared 改变了硬件的 shared/L1 配置，耗时还可能受缓存分配影响；本章不把时间差全部归因于驻留数量。

bench 先校验三组资源配置与输出，再每组预热 10 次，测 21 批、每批 10 次 kernel，以同 stream Event 归一化到每次启动后取中位数。区间不含分配、H2D/D2H 和 CPU 校验/汇总，可能含 host 提交间隙。普通计时与 NCU、Sanitizer 分开运行，不用 profiler 时间替代普通 Event 结果，也不预设固定加速比或单调关系。

## 用自己的话解释

最后约 10 分钟，指出两处修改分别影响查询还是实际启动；用 256 线程、32 warp/SM 计算 4、3、1 个 block 对应的比例，并解释为什么要同时考虑静态和动态 shared。再解释 GPU 有 14 个 SM 与单个 SM 的 32 warp 上限是什么关系，为什么只有求和 PASS 仍不能验收资源实验，以及理论 occupancy、achieved occupancy 与 Event 耗时分别说明什么。

验收为两处 TODO 生效、三组全量数值和 Sanitizer 通过、API 与 NCU 的资源变化相互对应，以及上述独立解释；性能无固定收益门槛。到一小时仍未完成就记录阻塞，不追加 spill 调优、完整延迟隐藏分析或 occupancy 自动调参。以后实现 tiled GEMM 时，shared 复用的收益就需要与驻留资源代价一起考虑。

## Codex 预检：2026-10-27

现场复核 GTX 1650 / CC 7.5 / 14 SM / warpSize=32 / 4096 MiB，驱动 610.88、NVCC 12.9.86、NCU/Compute Sanitizer 2025.2.1.0。固定 shape=[262144]、float32、grid=1024、block=256，输入 1 MiB、输出 4 KiB。正式骨架及只补两处 TODO 的临时版均编译无警告，均使用每线程 14 个寄存器、32 字节静态 shared、无 spill。

骨架三组求和均 PASS，但查询未完成、实际动态预留均 0，check/bench 预期退出 1，bench 拒绝计时。临时补全版三组各 1024 个片段均 PASS、最大误差 0、总和 -184，check/bench 退出 0。

| 每 block 额外动态预留 | API 驻留 block/SM | API / NCU 理论 occupancy | NCU achieved occupancy | 普通 Event 中位数 μs/次 |
| --- | --- | --- | --- | --- |
| 0 字节 | 4 | 100% / 100% | 73.49% | 31.251201 |
| 16384 字节 | 3 | 75% / 75% | 51.84% | 33.695999 |
| 32768 字节 | 1 | 25% / 25% | 19.42% | 75.939202 |

NCU 的三次 launch 确认实际 dynamic shared 为 0/16384/32768 字节、static shared 均为 32 字节；`Block Limit Warps` 均为 4，`Block Limit Shared Mem` 为 128/3/1，说明基线主要受线程/warp 容量约束，增加预留后 shared 成为更紧约束。基线的 shared 限制 128 不表示真能驻留 128 个 block，需要同时满足其余限制。NCU 显示 shared 配置大小从 32768 变为 65536 字节；故不能声称硬件缓存配置也完全不变，或把耗时差单独归因于 warp 数。编译器与 Runtime 属性报告每线程 14 个寄存器，NCU LaunchStats 报告分配后为 16；这里分别保留口径，不作为额外调参练习。NCU 表里的 Kbyte 使用十进制，16.38 Kbyte 对应本例 16384 字节，不要按 KiB 再乘 1024。

正式骨架和临时补全版各经 memcheck（padding=32）、racecheck、synccheck，均零工具错误、racecheck 零 warnings。骨架继承程序退出 1，`Target application returned an error` 是练习未完成；补全版工具命令均退出 0。普通 Event 数据与工具运行分开，不与 Ch10 或历史结果作优化 A/B，不将当前耗时比例泛化到其他设备、输入或 kernel。

原始命令、源码 SHA-256、退出码、编译资源、Sanitizer 与 NCU 表见 [preflight-2026-10-27.txt](../../reports/CH11/preflight-2026-10-27.txt)，可打开的报告为 [preflight-2026-10-27.ncu-rep](../../reports/CH11/preflight-2026-10-27.ncu-rep)，完整原始指标见 [CSV](../../reports/CH11/preflight-metrics-2026-10-27.csv)。临时补全源码和二进制已清理，正式 `build/CH11/occupancy` 对应保留两处 TODO 的骨架；保留报告供复盘。NSYS、GUI、SASS 均 NOT RUN，无新增依赖。这些结果是教学预检，不是用户实现或独立解释证据。


## TODO(1) 正式补全与验证：2026-10-28

按用户要求，Codex 在 active_blocks_per_sm 中用 CUDA_CHECK 包裹 cudaOccupancyMaxActiveBlocksPerMultiprocessor，将 blocks 的地址、block_sum_shuffle、kBlock 和 dynamic_bytes 传入，移除 TODO(1) 占位并更新过时提示。TODO(2)、kernel、输入与 grid/block 保持原样。核对本机 CUDA 12.9 头文件后正式编译，无警告。

本轮 GTX 1650 / CC 7.5、NVCC 12.9.86、Compute Sanitizer 2025.2.1.0，固定 N=262144、float32、grid=1024、block=256。API 对目标预留 0/16384/32768 字节返回 4/3/1 blocks/SM，即理论 occupancy 100%/75%/25%；实际 launch 仍均为 0 字节。三组各 1024 个 partial 校验 PASS、最大误差 0、总和 -184；0 字节配置 PASS，另外两组配置 INCOMPLETE，check 预期退出 1。memcheck（padding=32）、racecheck、synccheck 均零工具错误、racecheck 零 warnings，因目标程序练习未完成均退出 1；不是 Sanitizer 检出错误。bench、NCU、NSYS、GUI 本轮均 NOT RUN。命令、正式源码 SHA-256、输出及退出码见 [query-completed-2026-10-28.txt](../../reports/CH11/query-completed-2026-10-28.txt)。实现与验证由 Codex 完成，个人解释仍待验收。


## TODO(2) 正式补全与验证：2026-10-28

按用户要求，Codex 将 launch_bytes 设为 requested_bytes，通过第三个启动参数按每 block 预留动态 shared，移除最后一处 TODO、无用占位及过时提示。kernel 的计算、静态 shared、输入与 grid/block 均保持不变，两处实现均为 Codex 辅助完成。

本轮 GTX 1650 / CC 7.5 / 14 SM / 4096 MiB、驱动 610.88，NVCC 12.9.86、NCU/Compute Sanitizer 2025.2.1.0；N=262144、float32、grid=1024、block=256。正式重编译无警告，使用每线程 14 个寄存器、32 字节静态 shared、无 spill。三组资源配置 PASS，各 1024 个 partial 校验 PASS、最大误差 0、总和 -184。memcheck（padding=32）、racecheck、synccheck 均零错误、racecheck 零 warnings，check、工具检查与 bench 均退出 0。

| 动态 shared 字节/block | API 驻留 block/SM | API / NCU 理论 occupancy | NCU achieved occupancy | 普通 Event 中位数 μs/次 |
| --- | --- | --- | --- | --- |
| 0 | 4 | 100% / 100% | 73.66% | 29.926401 |
| 16384 | 3 | 75% / 75% | 51.41% | 30.604801 |
| 32768 | 1 | 25% / 25% | 19.43% | 45.705599 |

NCU LaunchStats 已核对实际 dynamic shared 为 0/16384/32768 字节、static shared 均为 32 字节；shared 配置为 32768/65536/65536 字节，因此仍不能把耗时差全部归因于 occupancy。Event 测量为预热 10 次、21 批、每批 10 次启动后归一化；边界沿用上文，与 Sanitizer/NCU 分开，不与历史预检作优化 A/B，不泛化固定性能比例。

原始命令、正式源码 SHA-256、输出、退出码及指标摘要见 [completed-2026-10-28.txt](../../reports/CH11/completed-2026-10-28.txt)，报告为 [completed-2026-10-28.ncu-rep](../../reports/CH11/completed-2026-10-28.ncu-rep)，原始指标见 [CSV](../../reports/CH11/completed-metrics-2026-10-28.csv)。本轮 NSYS、GUI、SASS 均 NOT RUN，未创建临时补全源码或二进制，无新增依赖；个人运行及独立解释仍待验收。
