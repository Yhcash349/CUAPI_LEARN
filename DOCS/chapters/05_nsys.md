# Ch05：用 NSYS 看见 CPU 与 GPU 的工作

本章把已有 vector add 的运行过程画到同一条时间轴上：CPU 什么时候调用 CUDA，GPU 什么时候拷贝和计算。计划 45～60 分钟，对应 [PLAN](../PLAN.md) 阶段 A；源码为 [CH05/vector_add.cu](../../CH05/vector_add.cu)，由 Ch02 复制并独立保存，学习进度与用时只记在 [RECORD](../RECORD.md)。

本章沿用前章的 kernel，在独立的 `CH05/` 目录中编译和查看。你的练习是亲手执行采集命令、找到三类轨迹，再把它们对应到源码。Ch04 已有大量计时循环，初次看图时先用 Ch02 的单次调用看清数据流；Ch04 关于“CPU 时间与 GPU 时间边界不同”的认识继续沿用。前章待验收项不会因准备本章而自动完成。

## 先读程序，再预测

Nsight Systems（命令 `nsys`）像一份 CPU/GPU 工作日志。timeline 就是按时间排列这些工作的图；同一横轴上的不同轨道，分别表示 CPU 调用和 GPU 活动。

先花 10 分钟打开源码，从 `main()` 中找到这段顺序：

```text
CPU 准备数组与参考答案
  → cudaMalloc 三次
  → cudaMemcpy：a、b 从 CPU 到 GPU
  → cudaMemset：把 c 清零
  → vector_add<<<blocks, threads_per_block>>>(...)
  → cudaGetLastError + cudaDeviceSynchronize
  → cudaMemcpy：c 从 GPU 到 CPU
  → CPU 校验全部元素 → cudaFree 三次
```

固定 N=1000、float32、grid=8、block=128，每个数组 4000 字节。唯一对照是“普通运行”与“在工具下运行”，不改输入、索引或启动配置。

用 5 分钟写下预测：GPU 上有几次 H2D、几次 D2H、几次 `vector_add`？`cudaLaunchKernel` 的 CPU 时间条与 `vector_add` 的 GPU 时间条是否表示同一件事？先写自己的判断，再看报告。本章另外会出现 `memset`，它是清零，不算一次 H2D/D2H。

## 编译并确认计算正确

以下命令均在项目根目录执行。编译本章独立源码，输出到 `build/CH05/`。

```bash
mkdir -p build/CH05 reports/CH05
nvcc -std=c++17 -O2 -arch=sm_75 -lineinfo -Xcompiler=-Wall,-Wextra CH05/vector_add.cu -o build/CH05/vector_add && ./build/CH05/vector_add
```

必须先看到 `mismatches=0 max_abs_error=0` 与 `PASS`，再往下采集。若修改源码，仍是“保存 → 重新编译 → 运行”；编译失败时不要继续采集旧二进制。

这里没有新增计时循环，也没有预热。本次只辨认一次完整运行的活动和顺序，包含初始化与清理，**不是稳态性能测试**。若要测速度，回到 Ch04 的预热、重复和计时边界，并与 profiler 分开运行。

## 亲手采集一次报告

预计 10 分钟。先确认版本，再执行采集；下方命令会重新启动一次程序。

```bash
nsys --version
nsys profile --trace=cuda --sample=none --cpuctxsw=none \
  -o reports/CH05/user_run_01 ./build/CH05/vector_add
```

| 参数 | 本章用途 |
| --- | --- |
| `profile` | 启动程序并采集报告 |
| `--trace=cuda` | 采集 CUDA API 和相应 GPU 活动 |
| `--sample=none` | 关闭本章不需要的 CPU 指令位置采样 |
| `--cpuctxsw=none` | 关闭本章不需要的 CPU 线程调度追踪 |
| `-o reports/CH05/user_run_01` | 设置输出前缀，主报告为 `.nsys-rep` |
| `./build/CH05/vector_add` | 被工具启动的可执行程序 |

关闭 CPU 采样并不等于关闭 CPU 侧 CUDA API 追踪。采集时仍应看到程序的数值 `PASS`，并确认工具实际生成了 `reports/CH05/user_run_01.nsys-rep`。再次采集时把前缀改为 `user_run_02`，保留第一次证据；不需要强制覆盖。

参数已与本机 NSYS 2026.4.1 的 `nsys profile --help` 核对。官方说明见 [Nsight Systems User Guide：Profiling from the CLI](https://docs.nvidia.com/nsight-systems/UserGuide/index.html#profiling-from-the-cli)；在线文档可能更新，当前安装版本的帮助用于核对选项。

## 看报告：先数量，再时间线

预计 20 分钟。先在终端读汇总，确认采集到了目标活动：

```bash
nsys stats --report cuda_api_sum,cuda_gpu_kern_sum,cuda_gpu_mem_size_sum \
  reports/CH05/user_run_01.nsys-rep
```

首次运行会生成同名 `.sqlite`，它是工具用于分析的数据文件，本章不需要学习 SQL。三张表分别看 API 调用、kernel 次数、内存操作方向与大小。`Num Calls` 和 `Instances` 都是相应表中的计数；MB 列的 `0.004` 对应本例每个数组的 4000 字节。

| 观察位置 | 应对应到的源码 | 需要解释的区别 |
| --- | --- | --- |
| CPU 的 CUDA API 轨道：`cudaMemcpy`、`cudaLaunchKernel` 等 | `main()` 中的调用与 `<<<...>>>` 启动语句 | 表示 CPU 在接口内的时间，可能包括等待 |
| GPU 的 memory 轨道：HtoD/DtoH 或 Host-to-Device/Device-to-Host | 两个输入拷贝、一个输出回读 | 表示 GPU 侧记录到的传输活动 |
| GPU 的 kernel 轨道：`vector_add(...)` | `__global__ void vector_add(...)` | 表示 GPU 上执行 kernel 的时间 |

使用与采集版本兼容的 Nsight Systems GUI 打开 `.nsys-rep`（优先同版本 2026.4.1）。如果本机 `nsys-ui` 的版本兼容，可执行：

```bash
nsys-ui reports/CH05/user_run_01.nsys-rep
```

2026-10-08 排查发现：本机 `nsys-ui` 入口实际启动 2025.1.3，`/home/yhc23/.local/bin/nsys` 则为 2026.4.1，两者版本不同。新 CLI 采集的报告应使用兼容的 GUI（优先同版），可在 Windows 打开；不能仅因命令存在就认定其兼容。若 GUI 启动出现 ZINK/EGL 错误，可临时使用 `LIBGL_ALWAYS_SOFTWARE=true GALLIUM_DRIVER=llvmpipe nsys-ui <报告路径>`，以 CPU 软件渲染界面；本次启动探测退出 0、原 ZINK/EGL 警告未再出现，但未人工确认窗口与报告显示。软件渲染依据 [Mesa 环境变量说明](https://docs.mesa3d.org/envvars.html)。

用户的 `user_20261008_01.nsys-rep` 诊断显示采集时加载 2025.1.3 库，并提示当前驱动版本不受支持；该报告有 CPU API 数据，但没有 GPU kernel/memcpy 数据。Codex 使用 `/home/yhc23/.local/bin/nsys` 2026.4.1 重新采集 [repair-20261008.nsys-rep](../../reports/CH05/repair-20261008.nsys-rep)，GPU kernel 与拷贝数据均已验证。用户在自己的终端采集时可显式使用该 CLI 路径，避免 PATH 选到旧版本。

也可在 Windows 的兼容 GUI 中通过“打开文件”选择该报告。先展开进程/线程下的 CUDA API 行，再展开 GPU 下的 kernel 与 memory 行；具体标签随 GUI 版本变化。定位 `vector_add`，放大它附近的时间区域，选中事件查看名称、起点与持续时间。默认缩放可能让微秒级 kernel 小到像一根线，不代表没有执行。

找到输入拷贝、kernel、回读后，回到 CPU API 行对应启动与拷贝调用。工具若提供关联事件跳转，可用它核对；不要只凭两条时间条靠得近就判断对应关系。CUDA API 名称和 GPU 活动名称属于不同层次，`cudaLaunchKernel` 不是另一个计算 kernel。

注意 GUI 的 CPU 启动事件可能直接显示 kernel 名称。2026-10-08 用户 `_02` 截图中，CUDA API 的 Events View 第 8 行显示 `vector_add(...)`，Start=1.24279 s、Duration=450.575 μs；同报告 CLI 的 `cuda_api_trace` 确认它是 `cudaLaunchKernel`，关联编号 124。GPU 轨道中的 `vector_add` 也关联到 124，但 Duration=2.176 μs。通过所在轨道、时间和关联编号区分 CPU 启动与 GPU 执行，不能只搜索显示名称。本图的 `Threads → [6664] vector_add` 是 CPU 线程/程序名称，不是 GPU kernel 轨道。

**没有可用 GUI 时**，用下面的逐条记录完成顺序练习，不把汇总表冒充时间线：

```bash
nsys stats --report cuda_api_trace,cuda_gpu_trace \
  reports/CH05/user_run_01.nsys-rep
```

`cuda_api_trace` 查看 CPU API，`cuda_gpu_trace` 按起始时间列出 GPU 工作。先读 `Start`、`Duration` 和 `Name`；时间单位按表头，本机为 ns，1000 ns = 1 μs。`CorrId` 是关联编号，可核对本例 kernel 与 launch 的对应项；本章不推广为所有 API 与 GPU 活动严格一一对应。`GrdX=8`、`BlkX=128` 可与源码核对。`Strm` 是工具记录的 stream 标识，不要因它显示为非零就认定源码使用了自建 stream。

本章只需确认 GPU 顺序为“两次 H2D → 清零 → vector_add → D2H”，并指出对应 CPU 调用。CPU API 与 GPU 活动可能在时间上重叠，不能将两层耗时直接相加；不要求此时展开多 stream、NVTX、NCU 或 CUPTI。

## 不要从这张图得出什么

API 汇总里的 `Time (%)` 是该表统计范围内的占比，不是 GPU 利用率。kernel 表只有一个 kernel 时占比为 100%，也不表示整段程序都在计算。首次 `cudaMalloc` 很长可能包含初始化工作，本次没有拆分这些开销，不能说每次分配都这么慢。

启动 API 的耗时与 GPU kernel 的耗时边界不同。工具下的一次短 kernel 时长不能替代 Ch04 的正常计时中位数，更不能拿两章的数字当加速比。NSYS 能说明本次哪些活动何时发生，不能凭本章报告证明访存最优、没有越界或所有 block 同时执行。

若程序 PASS 但报告缺少 CUDA GPU 数据，采集仍未验收：保留工具警告，确认 `--trace=cuda`、可执行文件与报告路径，再检查当前工具/驱动环境。GUI 无法打开时先确认兼容版本，用上面的文本路线继续；不要为本章自行重装驱动或扩建环境。到一小时仍受阻，就记录错误与缺少的证据。

## 验收：用自己的报告解释

最后用 10 分钟完成这段口述，填入实际观察，不直接照抄预检：

> 我采集的报告路径是……；普通运行和采集运行的正确性结果是……。CPU API 中我找到了……，它对应源码……；GPU 上 H2D 有……次、D2H 有……次，kernel 是……。API 耗时和 kernel 耗时不能当成同一个数，因为……。

交付为自己的 `.nsys-rep`、三类轨迹的定位说明（GUI 或文本记录均可）与上述解释。无需另建结果文档，实际反馈统一进入 RECORD。只有采集证据和个人解释都具备才记 DONE；Codex 预检不替代你的练习。本章与推理程序的联系是：以后可以用同样方法把 CPU 提交、数据搬运和 GPU 计算对应起来。

## 2026-09-28 工程预检

首次预检由 Codex 编译 `CH02/thread_index.cu` 并完成 CLI 采集（当时尚未复制到 CH05）；GTX 1650 / CC 7.5、驱动 610.88、NVCC 12.9.86、NSYS 2026.4.1。编译无警告，普通与采集运行均退出 0；N=1000、float32、grid=8、block=128，全量校验通过、最大绝对误差 0。

实测 API 汇总中 `cudaMemcpy` 3 次、`cudaLaunchKernel` 1 次；GPU 汇总中 `vector_add` 1 次、H2D 2 次（总 8000 字节）、D2H 1 次（4000 字节），另有 memset 1 次（4000 字节）。逐条 GPU trace 顺序与源码一致，kernel 配置为 grid=(8,1,1)、block=(128,1,1)。本次采集 kernel duration 为 2176 ns，只用于练习读表，不是稳态性能结论。

原始命令、输出与退出码见 [preflight.txt](../../reports/CH05/preflight.txt)；主报告为 [preflight-2026-09-28.nsys-rep](../../reports/CH05/preflight-2026-09-28.nsys-rep)，派生数据为 [同名 SQLite](../../reports/CH05/preflight-2026-09-28.sqlite)。报告与构建沿用 `.gitignore` 留在本地。

已验证 CLI 汇总与逐条 trace；GUI 打开和人工点选 **NOT RUN**，未声称完成截图验收。本章没有运行 Sanitizer、NCU 或新的性能 A/B。正式教材保留用户采集与解释练习；NOTE 不提前记入“已学会”。

## 独立章节目录补充验证

按用户要求新增 `CH05/vector_add.cu`，保留前章计算逻辑并补充本章用途注释；上方编译命令已切换至本章源码。重新编译无警告，普通与 NSYS 采集运行均 PASS、最大误差 0、退出 0；报告仍包含 1 次 kernel、2 次 H2D、1 次 D2H 和 1 次 memset。命令与输出见 [standalone-2026-09-28.txt](../../reports/CH05/standalone-2026-09-28.txt)，新报告为 [standalone-2026-09-28.nsys-rep](../../reports/CH05/standalone-2026-09-28.nsys-rep)。前面的预检报告保留作为历史证据，GUI 仍未验证。
