# Ch16：固定 kernel 链的 capture 与 replay

Graph 的直觉是：把一组固定的 GPU 工作和先后关系先录下来，以后用一次提交重放这一组工作。本章沿用 Ch13 的计时边界和 Ch14 的单 stream 顺序，观察 CPU 提交方式改变后，GPU 上的三个 kernel 是否仍然存在。

预计 45～60 分钟，只学习 capture/实例化与 replay。源码在 [CH16/graph_replay.cu](../../CH16/graph_replay.cu)。host、三个 kernel、校验和计时由 Codex 提供；两处 Graph API 练习已于2026-11-06按用户要求由Codex补全，原始练习路线保留供复习。不要求从零重写 host，也不扩展多 stream capture、图更新、动态图或框架内存池。真实推理中也会反复运行固定的小算子链，本章先认识这种提交方式。

## 先沿一项数据走完程序

固定 N=4099、float32、block=256、grid=17。每个数组 16396 字节，共四个 device 数组；最后一个 block 只有前三个线程有效。三个阶段都由同一 stream 提交：

```text
input[i] -> add_one -> tmp0[i] -> scale_two -> tmp1[i] -> subtract_half -> output[i]
              +1                   ×2                       -0.5
```

例如 block 0/thread 3 负责第 3 项。按输入生成公式，它读到 input[3]=-6.6875，先写 tmp0[3]=-5.6875，下一个 kernel 写 tmp1[3]=-11.375，最后写 output[3]=-11.875。各 kernel 自己读写一项；第二个阶段要等第一个 kernel 完成，第三个阶段也依赖第二个。单 stream 的顺序已提供这种保证，无需在三个阶段之间让 CPU 同步。

一条链的 CPU reference 为 `(input[i]+1)*2-0.5`。一批重复同一条链 64 次，每次都从原始 input 开始，覆盖同一组 tmp/output；不是把 output 累积 64 轮，也不是 64 个独立数组。所有链在同一 stream 上顺序执行，因此复用地址不会让后链过早覆盖前链的中间结果。

唯一实验变量是提交方式：

| 方式 | 每条链的 host 提交 | 每批提交主计算的 API 次数 | 每批 GPU kernel 数 |
| --- | --- | --- | --- |
| direct | 调用 launch_chain，分别启动三个 kernel | 192 次 kernel launch | 192 |
| graph | 重放提前录好并实例化的一条链 | 64 次 cudaGraphLaunch | 192 |

这里的次数只统计提交主计算的 launch，不含错误查询、计时 Event、同步和计时外传输。它是待用 trace 核对的预期，不能凭 printf 的路径名称就认定已发生。Graph 不把这三个 kernel 自动融合为一个，链内的数据依赖也仍然存在。

先用约 5 分钟预测：哪种方式的 CPU 提交次数更少？GPU 上还应看到几个 kernel？如果 Graph 没有更快，是否仍能完成本章验收？把预测写下，再运行对照。

## 原始练习路线（两处现已补全）

约 10 分钟先读 `launch_chain()`、`capture_chain()`、`replay_chain()` 和 `run_batch()`。main 先分配四个 device 数组并上传 input，创建显式 nonblocking stream，再普通执行一条链并等待完成，预热三个函数。地址、shape、启动配置及参数在本实验中不变，所有分配都活到最后一次 replay 完成之后。

capture 期间，CPU 仍会走过 `launch_chain()`，但这些可捕获的工作被记入图，不在该时刻排队执行。`cudaGraph_t` 保存工作和依赖的描述，`cudaGraphExec_t` 是经过实例化、可供重复启动的对象；录完图还要实例化，之后 replay 不会重新跑那段 host C++ 代码。

原始练习预算约20分钟，下面保留两处任务及提示；当前实现已完成，可对照源码复习。其余 kernel、参数、计时与等待位置保持不变。

**TODO(1)：完成 capture_chain。** 在传入的 stream 上开始 capture，使用 `cudaStreamCaptureModeGlobal`；调用现成的 `launch_chain(b, stream)` 录入一条三阶段链；在同一 stream 结束 capture，把图写入引用参数 graph；再实例化到引用参数 exec，成功后返回 true。所有 CUDA API 都用 CUDA_CHECK 检查。

本机 CUDA 12.9 的相关参数形式是 `cudaStreamBeginCapture(stream, mode)`、`cudaStreamEndCapture(stream, &graph)` 和 `cudaGraphInstantiate(&exec, graph, 0)`；最后一个 0 是实例化 flags。这里的 Global 是 capture 的约束模式，不是 global memory，也不是将所有 stream 自动录入。首轮只用这一种模式。

capture 中只保留这条链的启动与错误检查，不加入 cudaMalloc/cudaFree、同步 memcpy、stream/device 同步或 Event 计时。尤其不能同步正在 capture 的 stream：此时是在描述工作，还不是等待已提交工作执行完。分配、上传、预热、哨兵、同步、计时和回读已放在 capture 外。

**TODO(2)：完成 replay_chain。** 把传入的可执行图 exec 提交到 stream，检查 `cudaGraphLaunch` 的返回状态，成功后返回 true。这里不增加同步；整批提交后由 `run_batch()` 等待。调用返回不代表三个 GPU kernel 已完成。

main 会检查录得的图是否包含三个 kernel 节点。这个检查只核对节点数与类型，具体运算及依赖仍需结合源码、数值与 trace 确认，不把教学 bool 当成实现正确性的证明。

## 编译、先检查，再计时

在项目根目录执行：

```bash
mkdir -p build/CH16
nvcc -std=c++17 -O2 -arch=sm_75 -lineinfo -Xcompiler=-Wall,-Wextra -Xptxas=-v,-warn-spills CH16/graph_replay.cu -o build/CH16/graph_replay
./build/CH16/graph_replay check
```

**当前两处 TODO 已补全，正式版应退出0。** 生成时的原骨架曾让graph安全回退到普通启动，虽然数值正确，仍提示 `capture_and_instantiate=INCOMPLETE/FAIL`、`submission_path=INCOMPLETE (direct fallback)`，拒绝Graph计时并退出1；这些是历史练习行为，不是当前正式版的预期输出。

重新编译后，check 两条路径应全量检查 4099 项、mismatches=0、max_abs_error=0，Graph 还应显示三个 kernel 节点和 graph_replay 路径，最终退出 0。先完成 check，再用约 15 分钟运行：

```bash
compute-sanitizer --tool memcheck --padding 32 --error-exitcode 99 ./build/CH16/graph_replay check
./build/CH16/graph_replay bench
```

memcheck 用于本例 global 访问及尾部内存检查；零错误不等于所有 Graph 语义都已证明。当前 kernel 没有 shared 交换或 block barrier，不新增 racecheck/synccheck 作为必修。本例 CPU reference 使用 double；输入是 /16 的数，三个运算在该范围内可精确表示，同时检查非有限值以发现 NaN 哨兵残留。每批只回读最终 output，验证该批最终结果；不能单靠最终数值证明全部 192 次 kernel 都执行了，次数另查 trace。

bench 两条路径各先校验一批，再预热 3 批、测 21 批；每批 64 条链，完成后在计时外回读并全量校验。打印三组各自的中位数，全部以“一批”为单位，不除以 192 冒充单 kernel 时间。

| 输出 | 程序边界 | 如何解释 |
| --- | --- | --- |
| host_submit_us | t0 到最后一次链提交返回后的 t1 | CPU 侧提交循环，含错误检查和可能的 API 阻塞，不是 GPU 计算时间 |
| host_complete_us | 同一个 t0 到 stream 等待完成后的 t2 | 含提交、stop Event 提交及最终等待，已经包含 host_submit |
| event_span_us | 同一 stream 的 start/stop Event | GPU 队列覆盖整批的区间，包含 kernel 间隙，可能包含等待 host 继续供给工作，不是 kernel 耗时之和 |

start Event 的 host 提交在 t0 前，stop Event 的 host 提交在 t1 后；Event 与 CPU timer 的边界并不完全相同。不要把三组时间相加，或直接相减推算某个精确开销。输入上传、分配、capture/实例化、哨兵准备、回读及 CPU 校验在计时外；Graph 首次启动发生在首个检查批次，后续再预热。该对照只比较稳态，不回答只用一遍能否抵回建图成本。

## 用 NSYS 核对提交次数和 GPU 间隙

补全并通过 check 后，单独采集 direct/graph。trace 模式本身不启动 profiler，也不用于普通性能报告。本机 CLI 2026.4.1 的 Graph trace 默认可能按整图聚合，这里明确使用 `--cuda-graph-trace=node`，才能数内部的 kernel；node 模式会增加采集开销。

```bash
mkdir -p reports/CH16
nsys profile --trace=cuda --cuda-graph-trace=node --sample=none --cpuctxsw=none --force-overwrite=false -o reports/CH16/direct_01 ./build/CH16/graph_replay trace direct
nsys profile --trace=cuda --cuda-graph-trace=node --sample=none --cpuctxsw=none --force-overwrite=false -o reports/CH16/graph_01 ./build/CH16/graph_replay trace graph
nsys stats --report cuda_api_sum,cuda_gpu_kern_sum reports/CH16/direct_01.nsys-rep
nsys stats --report cuda_api_sum,cuda_gpu_kern_sum reports/CH16/graph_01.nsys-rep
```

已有同名文件时换后缀，保留旧证据。如 stats 遇到已有 SQLite 的时间戳检查，可直接将该 .sqlite 路径作为输入，核对它确实对应本份报告。GUI 需匹配报告版本；此前默认 Linux GUI 2025.1.3 与 CLI 2026.4.1 不匹配，见 [环境记录](../ENVIRONMENT.md#2026-11-02-ch13-gui-与设备-event-trace-核验)，本章不要求安装 GUI。

每份完整 trace 的 GPU kernel 预期为 963 次：capture 前普通预热 3 次，加上检查、三批预热及目标批次共 5×192 次。capture 中的三个启动调用只构图，不额外产生三次 GPU 执行。graph 完整 trace 的 cudaGraphLaunch 预期 320 次，但这些全程汇总包含检查与预热，不能拿来当目标一批的调用数。

**选择每份报告最后 192 个目标 GPU kernel，以及对应的最后 192 次普通 launch 或最后 64 次 graph launch。** 比较 CPU CUDA API 行：direct 每条链三次 kernel launch，graph 每条链一次 Graph launch。再看 CUDA HW：两份都应保留 64 组 add_one→scale_two→subtract_half，每组仍有三个 kernel。Graph 内多个 node 可以关联同一次 Graph launch，不要求 CPU API 与 GPU 活动严格一一对应；报告里的 stream 编号也不当作固定 SM。

对同一报告内前后两个目标 kernel，GPU 间隙是“后一个开始减前一个结束”，整批 GPU 跨度是“最后一个结束减第一个开始”。可比较两模式的间隙分布，尤其链内与链间是否不同；不预设每个间隙都变小，也不把间隙差值全归因于某一项硬件机制。不能用 CPU API 条的宽度代替 GPU kernel 时间，不能把普通 bench 与采集时间拼在一起或跨报告相减。Graph 提交次数减少、普通计时变化和本次 GPU 端点各回答不同问题。

## 用自己的话验收

最后约 10 分钟，实际运行并指出两处 API 修改，沿 thread 3 解释中间数组的先写后读；说明 capture、实例化与 replay 分别做什么、为什么 capture 中不能等待 stream、为什么捕获地址要活到最后一次 replay 完成。

再用自己的 trace 解释“192 次普通启动变成 64 次 Graph 启动，但 GPU 仍有 192 个 kernel”，指出同一条链的三个阶段和实际间隙；区分三种计时边界，以及稳态计时未包含的一次性准备成本。没有固定加速比要求，没加速也如实记录。到一小时仍未完成就记录阻塞；Codex 预检不替代个人操作或独立解释，状态保持 RUNNING。

## 官方资料

已按本机 CUDA 12.9 头文件核对签名，语义参考 [CUDA 12.9.1 Programming Guide：CUDA Graphs](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-c-programming-guide/index.html#cuda-graphs)、[Stream Capture](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-c-programming-guide/index.html#creating-a-graph-using-stream-capture)、[capture 限制](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-c-programming-guide/index.html#prohibited-and-unhandled-operations)、[Runtime Graph API](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-runtime-api/group__CUDART__GRAPH.html) 与 [Runtime Stream API](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-runtime-api/group__CUDART__STREAM.html)。NSYS node 参数按现场 `nsys profile --help` 核对。

## Codex 教学预检：2026-11-05（生成时的历史记录）

现场 GTX1650 / CC7.5 / 14SM，Runtime12090、DriverAPI13030、KMD610.88，NVCC12.9.86、Compute Sanitizer2025.2.1.0、NSYS2026.4.1，CUDA_LAUNCH_BLOCKING unset。正式骨架及仅补两个 helper 的临时版编译均无警告、无 spill，三个 kernel 的 ptxas 报告均为10 registers/thread、0 barriers。

正式骨架两路径均全量检查4099项、数值PASS、最大绝对误差0，但graph实际回退到direct；check both、bench graph和memcheck命令退出1，是练习未完成导致的应用状态。memcheck报告零错误，不能把“Target application returned an error”读成工具检出了内存错误；单独check direct退出0。临时补全版检查三个kernel节点通过，两路径数值PASS、最大误差0，check/memcheck/bench/两份NSYS采集、导出和stats均退出0，memcheck零错误。

临时版独立普通bench预热3批、测21批，每批64条链，三组各自中位数如下，单位μs：

| 方式 | host_submit | host_complete | Event span |
| --- | --- | --- | --- |
| direct | 2190.224 | 2388.791 | 2347.872 |
| graph | 1002.935 | 1049.644 | 1015.904 |

本轮Graph稳态提交及完成区间较短，不能推广到所有工作负载，也没有测建图成本的回本次数。以下是另外两次NSYS采集，不用其跨度计算普通bench加速比。

| NSYS目标批次 | direct | graph |
| --- | --- | --- |
| CPU提交主计算的API次数 | 192次cudaLaunchKernel | 64次cudaGraphLaunch |
| GPU kernel数 | 192（每阶段64） | 192（每阶段64） |
| 每个目标launch关联的GPU kernel数 | 1 | 3 |
| GPU首kernel开始至末kernel结束 | 7712.763μs | 824.593μs |
| 链内GPU间隙中位数（128个间隙） | 6.032μs | 0.320μs |
| 链间GPU间隙中位数（63个间隙） | 6.848μs | 2.528μs |

两份完整trace各963次GPU kernel，目标为最后192次，均按add_one→scale_two→subtract_half循环64组、stream ID为13，GPU端点没有前后交叠。direct完整trace有963次普通launch；graph有320次Graph launch和6次普通launch，这6次包含预热及capture时的host启动调用，不能当作6次额外GPU执行。

以graph目标首链第一个GPU开始为零，三个区间分别为0～1.728μs、2.048～3.776μs、4.064～5.824μs，三者均关联同一次cudaGraphLaunch，Correlation ID=453。该实例直接展示一次API对应三个GPU活动，同时保留三个kernel及必要依赖。本次链内间隙较短；单次端点和采集开销不支持对全部耗时差做硬件因果分解。两个报告分别归零，不拼成同一次运行。

完整命令、源码SHA-256、临时补全的两个helper实现、编译/运行输出与退出码见 [预检日志](../../reports/CH16/preflight-2026-11-05.txt)。保留 [direct NSYS](../../reports/CH16/preflight-direct-2026-11-05.nsys-rep)、[graph NSYS](../../reports/CH16/preflight-graph-2026-11-05.nsys-rep)、对应 [direct SQLite](../../reports/CH16/preflight-direct-2026-11-05.sqlite)/[graph SQLite](../../reports/CH16/preflight-graph-2026-11-05.sqlite)、[目标活动CSV](../../reports/CH16/preflight-2026-11-05-timeline.csv)、[摘要JSON](../../reports/CH16/preflight-2026-11-05-summary.json) 与 [提取脚本](../../reports/CH16/preflight-2026-11-05-analysis.py)。报告为本机产物，默认不进Git。

上述性能与Graph trace均来自当时的临时补全版；生成时正式源码和build保留两处TODO，当前正式补全见下节。临时源码及可执行文件已清理。该轮GUI、NCU、racecheck、synccheck均NOT RUN；没有新增依赖或扩展首轮范围。当时Ch16保持RUNNING，用户实现、个人运行/读图及独立解释待验收，实际学习及工程执行耗时未记录。

## 正式补全与验证：2026-11-06

按用户要求，Codex完成两处练习。capture_chain用cudaStreamBeginCapture开启Global模式，在传入stream上调用launch_chain录入三个阶段，再cudaStreamEndCapture生成graph，cudaGraphInstantiate生成exec；replay_chain用cudaGraphLaunch(exec,stream)提交可执行图。各API均检查状态，成功后返回true。capture期间不增加同步，整批完成仍由run_batch等待；移除源码TODO和无用占位，保留路径检查及安全回退。kernel、参数、固定地址、输入、reference与计时边界不变，正式build已重编译。

现场GTX1650 / CC7.5 / 14SM、Runtime12090、DriverAPI13030、KMD610.88、NVCC12.9.86、Compute Sanitizer2025.2.1.0，CUDA_LAUNCH_BLOCKING unset。编译无警告、无spill，三个kernel的ptxas报告均为10 registers/thread、0 barriers。捕获检查得到3个kernel节点，direct/graph各4099项全量正确、最大绝对误差0，graph实际使用graph_replay路径；memcheck（padding32）零错误。编译、check、memcheck、bench均退出0。

普通bench预热3批、测21批，每批64条链，三组各自中位数如下，单位μs：

| 方式 | host_submit | host_complete | Event span |
| --- | --- | --- | --- |
| direct | 1158.311 | 1534.156 | 1497.024 |
| graph | 359.904 | 627.443 | 595.744 |

本轮只说明本机该配置下的稳态时间，不将三种时间相加或直接相减，也不把与历史预检的差异解释成代码优化收益。NSYS、NCU、GUI、racecheck、synccheck本轮均NOT RUN；上节NSYS只保留为历史临时版证据，没有冒充正式版新采集。

完整命令、正式源码SHA-256、版本、原始输出及退出码见 [正式补全日志](../../reports/CH16/completed-2026-11-06.txt)。实现和验证由Codex完成，个人运行/读图与独立解释待验收，Ch16保持RUNNING，实际学习及工程执行耗时未记录。未创建临时实现文件，没有新依赖、计划偏离或额外Claude审阅需要。

## 正式 NSYS 间隙对照与 GUI 阅读路线：2026-11-09

按用户“能不能在NSYS里面直观对比出两种模式kernel间隙开销”的要求，使用当前正式源码重新编译、检查并采集direct/graph；源码SHA-256与11月6日正式补全日志一致。现场GTX1650 / CC7.5 / 14SM、Runtime12090、DriverAPI13030、NVCC12.9.86、NSYS CLI2026.4.1，CUDA_LAUNCH_BLOCKING unset。编译无警告、无spill，三个kernel各10 registers/thread、0 barriers，普通check两路径各4099项全量正确、最大误差0。本轮没有重跑普通bench和Compute Sanitizer。

两次采集明确使用 `--cuda-graph-trace=node`；该选项把Graph内部各节点显示为GPU活动，避免只显示整张图。参数已按现场help与 [NSYS CUDA Graph Trace说明](https://docs.nvidia.com/nsight-systems/UserGuide/#cuda-graph-trace)核对，node trace会增加采集开销。原始 [direct报告](../../reports/CH16/experiment-direct-2026-11-09.nsys-rep) 和 [graph报告](../../reports/CH16/experiment-graph-2026-11-09.nsys-rep) 均保留，没有覆盖11月5日临时版报告。

![正式版两种模式的实测GPU时间线，含整批与前三条链局部对照](../../reports/CH16/experiment-2026-11-09-timeline.png)

本图由Python/Matplotlib从两份NSYS SQLite重绘，不是NSYS GUI截图。上面是各192个kernel的目标整批，下面是各自前3条链、共9个kernel；A/B/C分别表示add_one/scale_two/subtract_half，数字表示链编号。同一面板的两行使用相同横轴刻度，每份报告分别以目标首kernel开始归零，矩形位置/宽度来自实际GPU端点。灰色是该stream上相邻目标kernel之间的空档，不单独证明整张GPU完全空闲。

| 本次正式版NSYS目标批次 | direct | graph |
| --- | --- | --- |
| GPU kernel数 | 192，每阶段64 | 192，每阶段64 |
| 提交主计算的API次数 | 192次cudaLaunchKernel | 64次cudaGraphLaunch |
| kernel执行耗时合计 | 330.048μs | 332.736μs |
| GPU首kernel开始至末kernel结束 | 1365.216μs | 751.394μs |
| 191个相邻kernel空档合计 | 1035.168μs | 418.658μs |
| 链内128个空档中位数 | 2.016μs | 0.320μs |
| 链间63个空档中位数 | 1.920μs | 2.144μs |
| 目标GPU区间内memcpy/memset活动数 | 0 / 0 | 0 / 0 |

本次图上同链内的衔接明显紧凑；Graph仍有链间空档，链间中位数也没有降低。不能从该图声称所有间隙都消失，或把所有空档归为某一种CPU/Driver开销。两份报告的kernel自身耗时合计接近，数量相同，整批跨度变化与间隙变化相符；本轮profiler结果不与11月6日普通bench混算，也不沿用历史临时版的6.032μs间隙作为本轮数据。

**在NSYS GUI中看同一证据：**

1. 用2026.4.1或更新的GUI分别打开两份原始报告。当前本机默认nsys-ui现场查询仍为2025.1.3.140，未升级或实际打开GUI；版本命令有WSL/OpenGL回退提示，但成功返回版本。不要把旧GUI无法读新报告当作采集失败。
2. 展开CUDA HW下的GPU和stream轨迹，找到stream ID13上的三个kernel；目标是最后一批192个kernel、64组A→B→C。完整报告各963个kernel，其他包括capture前预热、检查与三批预热。对照两份报告时使用相同的可见时间跨度，先看整批，再放大到几个kernel。
3. 对同一条链的相邻GPU色块，读前一个的End和后一个的Start，间隙为 `后一个Start - 前一个End`。例如目标首链direct的A为0～1.760μs、B为4.000～5.696μs，空档2.240μs；graph的A为0～1.728μs、B为2.048～3.744μs，空档0.320μs。这些都是各自报告内GPU端点相减，不能改用CPU API条的宽度。
4. 再看CPU的CUDA API行，direct目标192次kernel launch，graph目标64次Graph launch。Graph首链三个GPU节点的Correlation ID均为453，对应同一次Graph提交；direct首链依次1719/1721/1723。关联用于确认提交方式，不用跨CPU/GPU轨迹精确端点差推算Driver等待。

若需要按导出数据定位，SQLite目标GPU区间为direct1056.732899～1058.098115ms、graph889.901010～890.652404ms；如果GUI显示零点不同，以最后192个GPU kernel及Correlation ID定位为准。CPU API表示提交，CUDA HW表示GPU执行；只有后者相邻kernel之间的端点差才是这里讨论的GPU间隙。

完整命令、版本、源码哈希、check/采集/导出/stats输出及退出码见 [实验日志](../../reports/CH16/experiment-2026-11-09.txt)，均退出0。另保留 [direct SQLite](../../reports/CH16/experiment-direct-2026-11-09.sqlite)、[graph SQLite](../../reports/CH16/experiment-graph-2026-11-09.sqlite)、[目标CSV](../../reports/CH16/experiment-2026-11-09-timeline.csv)、[摘要JSON](../../reports/CH16/experiment-2026-11-09-summary.json)、[提取绘图脚本](../../reports/CH16/experiment-2026-11-09-analysis.py)、[PNG](../../reports/CH16/experiment-2026-11-09-timeline.png)及同名SVG。没有修改CUDA源码、创建临时实现或引入依赖；Ch16保持RUNNING，Codex采集和绘图不计个人操作/读图验收。
