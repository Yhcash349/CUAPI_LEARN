# Ch19：把 GPU 分配移出循环

假设 CPU 连续交给 GPU 32 组向量加法。每组都需要 a、b、c 三个数组，每个数组大小相同：是否需要每次都申请新空间，算完立即释放？本章保持算法、输入、传输和等待相同，只改变这三块 GPU 空间从何时开始存在、何时释放。

内存复用就是“一块空间用完这轮，再拿来放下一轮的数据”。这里复用的是存储空间，每轮仍上传新输入、重新计算并回读。计划45～60分钟，只学习分配生命周期和循环内调用数；不实现 allocator、内存池或 `cudaMallocAsync`。在真实推理中，提前准备工作缓冲也有类似动机，但本实验不能证明某个框架实际如何管理内存。

[源码](../../CH19/memory_reuse.cu) 与 [构建脚本](../../CH19/compile.sh) 独立放在 CH19。沿用 Ch17 的 vector add 和 Runtime 启动写法；无需加载 Ch17 cubin，也不增加 Ch18 的 context 练习。

## 先预测，再运行骨架（约10分钟）

固定 `n=1000`、float32、block=128、grid=8、每数组4000字节，每批32轮。两种策略使用同一份提前准备好的 host 输入，逐轮执行相同流程：

```text
per_step:
  循环32轮：分配 a/b/c → H2D → c填NaN → 加法 → 等待 → D2H → 释放 a/b/c

reuse:
  分配 a/b/c
  循环32轮：             H2D → c填NaN → 加法 → 等待 → D2H
  释放 a/b/c
```

先预测：两条路径的结果是否相同？循环内各有多少次 `cudaMalloc` 和 `cudaFree`？减少分配，会不会同时减少 kernel 数量和 H2D 字节数？暂时不预测固定加速比。

在项目根目录执行：

```bash
bash CH19/compile.sh
./build/CH19/memory_reuse check per_step
./build/CH19/memory_reuse check both
```

2026-11-17 已按用户要求由 Codex 补全正式版本，`per_step` 与 `both` 均已通过数值和调用数检查，`bench both` 可以对照两条路径。原骨架因复用准备未实现而提示NOT RUN、退出2的行为仅为11月11日的历史预检状态。编译脚本只构建，不运行程序；修改源码后必须重编译。

## 沿一轮数据流读代码（约10分钟）

先看 `main()` 中输入准备，再看 `run_batch()` 和 `run_step()`，最后回到分配与释放 helper。参数解析、统计中位数等骨架暂时略读即可。

以第3轮为例：host 片段从 `offset=3*1000=3000` 开始，a[3000..3999] 与 b[3000..3999] 上传到当前 device 数组。GPU 的 block0/thread3 算 `i=3`，从本轮 d_a[3]、d_b[3] 读数，写 d_c[3]；回读后对应 output[3003]。block7 中 i=1000～1023 的线程被边界判断挡住。下一轮换 host 片段，复用路径仍把新输入写入相同的三块 device 空间。

`run_step()` 先上传两份输入、把输出按字节填0xff作为NaN哨兵，再等待准备完成。然后用同一 default stream 的两个 Event 包住 vector_add，等待 stop 到达，最后 D2H 回读。两种策略都执行这些操作；这里有意逐轮完成，不引入流水并发。每轮结果分别保存在 host 的 output 片段，CPU 在整批结束后检查全部32轮，不只看最后一轮。

`Buffers` 里三个指针保存 device 地址值。`allocate_buffers()` 调三次 `cudaMalloc` 并计数，`release_buffers()` 调三次 `cudaFree` 后清空指针。分配拿到的是空间，不会自动写入正确输入；本程序每轮仍需上传。官方签名已与本机 Toolkit 头文件核对：

```cpp
cudaError_t cudaMalloc(void** devPtr, size_t size);
cudaError_t cudaFree(void* devPtr);
```

源码使用 CUDA 提供的 C++ typed-pointer 重载传入 `&b.a` 等位置。`cudaMalloc` 不清零内存，`cudaFree` 之后也不能继续使用旧地址；本例在 kernel 完成和回读后才释放，不拿释放来替代显式等待。[CUDA Runtime API 12.9.1：Memory Management](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-runtime-api/group__CUDART__MEMORY.html)。

## 原 TODO(1)：准备跨轮使用的空间（已完成，约10～15分钟复习）

2026-11-17 Codex 已实现 `prepare_reuse_buffers(Buffers& b, Calls& calls)`：调用 `allocate_buffers(b, calls)` 准备三个device数组，然后返回true。每次分配都由helper中的CUDA_CHECK检查，失败直接报错退出；成功路径才继续循环。占位语句已移除，计算、传输、等待和循环次数保持一致，此处不释放空间。

```cpp
allocate_buffers(b, calls);
return true;
```

关键在调用位置：`run_batch()` 在进入 for 循环前调用这个函数，循环体里只有 `!reuse` 才分配或释放；复用路径的最后一次释放已经放在循环后。沿这一段指出“创建、使用32次、释放”的位置，比记住 helper 名字更重要。

`calls` 是本程序的成功 Runtime 调用计数，既不是驱动内部调用数，也不是实际物理显存分配次数。`validate()` 同时检查数值与预期调用位置：

| 策略 | 整批malloc | 整批free | 循环内malloc | 循环内free | kernel |
| --- | ---: | ---: | ---: | ---: | ---: |
| per_step | 96 | 96 | 96 | 96 | 32 |
| reuse | 3 | 3 | 0 | 0 | 32 |

两条路径同时持有的工作数组均为3×4000字节，指申请的数据大小，不含驱动开销。复用让这些分配跨越全部32轮，并不要求同时保留32份 device 工作数组。反过来，即便 per_step 某次分配返回了与上次相同的地址，也不能说没有发生重新分配；应看 API 调用和有效生命周期。

## 校验、计时与调用数（约15分钟）

当前完整版本可直接构建和检查：

```bash
bash CH19/compile.sh
./build/CH19/memory_reuse check both
compute-sanitizer --tool memcheck --padding 32 --leak-check full --error-exitcode 99 ./build/CH19/memory_reuse check both
./build/CH19/memory_reuse bench both
```

`check` 对每条路径的全部32000项使用 CPU double reference，检查非有限值、1e-6误差阈值和调用数。输入随轮次变化，预期结果也变化；每轮重新填充输出NaN哨兵，帮助发现漏写。数值通过与 memcheck 零错误是不同层面的证据。

`bench` 先校验，再各预热3批、测量21批；成对测量时交替顺序，输出中位数，单位均为μs/批，不是每轮耗时。CPU reference 检查放在计时外，每批仍检查。三个字段边界不同：

| 输出字段 | 覆盖范围 |
| --- | --- |
| median_host_loop_us | CPU从进入32轮循环到全部回读完成；包括循环内分配释放、传输、NaN初始化、Event操作及等待 |
| median_host_lifecycle_us | CPU从本批准备到最终释放；还包含复用路径的循环外分配/释放 |
| median_event_sum_us | 每批32个start→stop GPU Event区间之和；区间只包kernel，排除H2D/D2H及分配释放，但仍可能包含提交衔接的空隙 |

稳态这里具体指“已经准备好复用缓冲的循环”。复用的准备和清理没有消失；同时查看 lifecycle，才能看到它们的代价。Event不覆盖分配路径，不能用它判断CPU总开销；这么短的加法也容易受提交衔接影响，不把Event差异直接说成GPU加法本身加速。官方资料将 malloc/free 的开销列为优化关注点，本章先用最简单的提前分配验证动机，内存池方案留给按需选修。[Best Practices Guide 12.9：Allocation](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-c-best-practices-guide/index.html#allocation)。

需要用 NSYS 独立核对实际调用时，运行以下采集；这是与普通计时分开的两次进程：

```bash
mkdir -p reports/CH19
nsys profile --trace=cuda --sample=none --cpuctxsw=none --capture-range=cudaProfilerApi --capture-range-end=stop -o reports/CH19/per_step ./build/CH19/memory_reuse trace per_step
nsys profile --trace=cuda --sample=none --cpuctxsw=none --capture-range=cudaProfilerApi --capture-range-end=stop -o reports/CH19/reuse ./build/CH19/memory_reuse trace reuse
nsys stats --report cuda_api_sum,cuda_gpu_kern_sum,cuda_gpu_mem_time_sum reports/CH19/per_step.nsys-rep
nsys stats --report cuda_api_sum,cuda_gpu_kern_sum,cuda_gpu_mem_time_sum reports/CH19/reuse.nsys-rep
```

`trace` 只接受单条策略。骨架先校验和预热，再以已经提供的 `cudaProfilerStart/Stop` 标记目标循环；上述选项让 NSYS 只采该区间，不需另写标记代码。复用的循环外分配与清理刻意不在报告里，所以报告的0次分配不表示整个程序从未分配。若报告名已存在，换输出前缀保留旧证据。

在 CUDA API Summary 数 malloc/free，GPU Kernel Summary 应各有32次 vector_add；MemOps 应各有64次H2D、32次D2H和32次memset。打开 GUI 时先看 CPU CUDA API 行的分配调用，再看 CUDA GPU 行的计算和传输；CPU API色块不是GPU kernel。正常计时用于看耗时，采集报告用于核对工作与调用数，不拿采集后的耗时当普通 benchmark。

## Codex教学预检（2026-11-11）

以下为11月11日历史预检，区别于后面的11月17日正式补全验证。当日现场为 GTX1650 4GB、CC7.5、NVCC12.9.86、Runtime12090、DriverAPI13030、驱动610.88、NSYS2026.4.1、Compute Sanitizer2025.2.1。构建使用 `-O2 -lineinfo -arch=sm_75 -Xcompiler=-Wall,-Wextra`，无警告。当时正式源码保留TODO，隔离临时副本仅补全复用准备函数，完成下列预检后自动清理源码与二进制；临时版数据不能当作正式骨架已经完成练习。

正式 `check per_step` 全量校验与计数通过，memcheck及leak-check均为零；正式 `check both` 和 `bench both` 按预期退出2，后者没有发布计时。临时补全版两条策略分别检查32000项，mismatches=0、max_abs_error=0；memcheck零错误、泄漏0字节，调用数均与上表一致。

临时补全版普通计时（3次预热、21次重复，中位数，μs/批）：

| 策略 | host_loop | host_lifecycle | Event区间合计 |
| --- | ---: | ---: | ---: |
| per_step | 24154.982 | 24155.053 | 763.168 |
| reuse | 4568.006 | 5287.791 | 450.592 |

本次复用减少了该小程序的CPU总耗时；传输、逐轮等待和Event操作都仍在，不能把差值全部当成纯分配函数成本，也不能把Event差异当作加法指令加速。结果只适用于本机、本输入与本同步方式，未要求达到固定加速比。

独立NSYS采集核对：per_step循环内malloc/free各96次，reuse各0次；两条路径GPU上各32个kernel、64次H2D、32次D2H、32次memset。原始Runtime符号带 `_v3020` 等版本后缀；结构化核对保留原名，另去除末尾版本后缀进行计数匹配，不解释为额外调用。

完整命令、退出码、环境、临时补全方式与源码哈希见 [preflight日志](../../reports/CH19/preflight-2026-11-11.txt)，结构化调用数与正式源码/二进制哈希见 [trace-counts](../../reports/CH19/trace-counts-2026-11-11.json)。原始报告为 `reports/CH19/preflight-{per_step,reuse}-2026-11-11.nsys-rep`，对应SQLite同前缀保留，build/reports按现有规则不进版本管理。没有运行NCU，也没有实现async allocator或内存池。

## 正式补全验证（2026-11-17）

本次按用户“完成TODO1”要求直接补全正式源码并重建，不再使用隔离临时实现。现场复核GTX1650/CC7.5/4GB、驱动610.88、NVCC12.9.86、Runtime12090、DriverAPI13030、Compute Sanitizer2025.2.1，CUDA_LAUNCH_BLOCKING unset。构建无警告，`check both` 两条路径各32000项全部通过、最大误差0；Runtime计数per_step整批/循环内均96/96，reuse整批3/3、循环内0/0。memcheck padding32及leak-check full零错误、泄漏0字节。

普通计时（3次预热、21次重复，中位数，μs/批）如下，边界沿用上文：

| 策略 | host_loop | host_lifecycle | Event区间合计 |
| --- | ---: | ---: | ---: |
| per_step | 24551.086 | 24551.166 | 601.440 |
| reuse | 4650.845 | 5404.955 | 373.856 |

命令、环境、退出码与正式源码/脚本/二进制哈希见 [正式验证日志](../../reports/CH19/completed-2026-11-17.txt)。本次没有重采NSYS或NCU，前面的NSYS报告仍是11月11日隔离补全版的历史证据。本次由Codex完成实现和工具验证，用户个人运行与独立解释仍待验收，不将正式程序PASS当作用户已经掌握。

## NSYS：三个时间为什么不同（2026-11-17）

用户要求实际采集，解释host_loop、host_lifecycle、event_sum与实验现象。正式源码保持不变；本次另存 [诊断副本](../../reports/CH19/experiment-2026-11-17-probe.cu)，沿用完全相同的输入、kernel、传输、等待及分配生命周期，只把采集范围扩大到本批完整生命周期，紧邻life0/t0/t1/life1添加CPU NVTX标记，并在采集结束后输出本批及逐轮Event读数。NVTX是给时间线添加名称标记的工具；本次只为读图提供定位，不新增本章实现作业。

原正式程序的trace仍只采循环；下面的诊断副本采集则包括复用的初始分配和最终释放。现场仍为GTX1650/CC7.5/4GB、NVCC12.9.86、驱动610.88、Runtime12090、DriverAPI13030、NSYS2026.4.1，CUDA_LAUNCH_BLOCKING unset。诊断副本编译无警告，正式程序和诊断副本的双路径数值/调用数均通过；每份目标采集各有32个kernel、64次H2D、32次D2H和32次memset。

先单独重跑正式程序的普通bench：各预热3批、测量21批、中位数μs/批。per_step的host_loop/host_lifecycle/event_sum为25687.094/25687.174/700.928，reuse为6306.048/6831.647/197.888。这是本次未启用profiler的结果，与上一节早先测量分开；没有把两次运行的数据拼起来解释。

随后对诊断副本分别采两条路径，使用 `--trace=cuda,nvtx --cuda-event-trace=true --capture-range=cudaProfilerApi --capture-range-end=stop`，只采预热后的一个目标批次。CUDA Event Trace用于获得设备端Event完成标记，额外采集开销可能改变运行耗时，不作为普通bench。[NSYS CUDA Event Trace说明](https://docs.nvidia.com/nsight-systems/UserGuide/index.html#cuda-event-trace)。

同次诊断采集读数，单位μs/批：

| 指标 | per_step | reuse |
| --- | ---: | ---: |
| 程序host_loop | 27939.568 | 10978.555 |
| 程序host_lifecycle | 27949.616 | 12237.293 |
| 程序event_sum | 949.920 | 325.760 |
| NSYS中32个kernel执行区间合计 | 76.508 | 52.921 |

host_loop包括本批32轮所有提交、传输、初始化、等待和循环内管理；host_lifecycle还包括循环外准备和释放。per_step二者几乎相同，是因为所有分配释放都在循环内；reuse中lifecycle比loop长1258.738μs，因为还要包含循环外准备/清理及诊断标记开销。NVTX标记紧邻CPU取时位置，标记间隔与steady_clock值不要求逐位一致：本次CPU NVTX循环跨度27944.547/10987.342μs，完整跨度27951.410/12241.731μs。

CPU CUDA API行进一步解释了大部分总耗时差：per_step循环内malloc/free各96次，API调用持续时间合计17389.396μs；reuse循环内均0次，完整生命周期malloc/free各3次，API持续时间合计1229.891μs。它们是CPU端API持续时间，含驱动调用及可能的等待，不等于GPU计算或纯分配算法成本，也不能把不同运行的API耗时差精确等同于总加速。提前准备减少了反复管理空间的成本；官方也将malloc/free开销列为内存管理优化关注点。[Best Practices 12.9：Allocation](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-c-best-practices-guide/index.html#allocation)。

### 从一轮GPU端点看Event区间

取两份报告的step=1，即第二轮，各自以GPU start Event为0，完全使用同一GPU时间线上的端点：

| 区间，μs | per_step | reuse |
| --- | ---: | ---: |
| start Event→kernel开始 | 3.200 | 3.072 |
| kernel自身执行 | 2.432 | 1.599 |
| kernel结束→stop Event | 7.936 | 4.064 |
| 设备Event标记间隔 | 13.568 | 8.735 |
| 同轮cudaEventElapsedTime读数 | 14.080 | 9.280 |

这里可在GPU轨迹内精确核对13.568=3.200+2.432+7.936，另一路同理。Event区间中，kernel只占其中一段；全部64个逐轮Event窗口内都没有显式memcpy/memset活动，因此这些窗口内的空档不是本程序H2D/D2H传输。CPU依次提交start、launch、错误检查和stop，GPU可以在CPU提交完全部工作前向前执行；提交衔接、排队和调度可能使两标记之间存在空闲。源码只证明相应操作的提交顺序，不能仅凭两个色块的空档断定每段空档由哪个CPU调用或哪种调度机制导致。

本例两个方案都从device全局内存读取相同输入，区别是分配生命周期；不是更换了kernel算法或读取了另一类存储。32个kernel合计76.508/52.921μs，确实也有差异，但比程序Event合计小得多。当前采集没有量化频率、cache、TLB或WSL调度影响，不能给kernel时长差指定唯一原因，也不能断言所有Event差异都由某一个CPU API造成。更稳妥的解释是：本实验的CPU总耗时主要受反复管理空间影响，而短kernel的Event区间又容易受到执行前后空档影响，三个指标回答的是不同问题。

### 读数限制与图的来源

设备Event标记区间与程序Event API读数在本环境中存在不一致。全部32轮设备标记跨度合计为1084.985/407.279μs，而程序Event合计为949.920/325.760μs；单轮最大绝对差为45.435/97.075μs。后处理保留两种原始读数，没有强制校准、平移或把它们拼成精确等式。设备标记转换差异的根因未确定；CPU/GPU绝对端点也不用于推导严格的提交后等待时长，避免把跨轨对齐问题解释为API提前完成。Event API的定义仍是两个Event之间的时间，而不是一个线程的耗时；stop在kernel之后，因此覆盖整次launch的所有block完成，不等同于在kernel内部添加全体线程屏障。[Runtime Event语义](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-runtime-api/group__CUDART__EVENT.html)。

![NSYS实测端点重绘：CPU生命周期与GPU Event窗口](../../reports/CH19/experiment-2026-11-17-timeline.png)

图是Matplotlib从NSYS SQLite实际端点重绘，不是NSYS GUI截图。上排是CPU：浅紫完整生命周期、深紫循环、橙/红分配和释放；下排只看GPU第二轮：灰色是设备Event标记窗口、绿色是kernel。每份报告分别归零，CPU与GPU面板不共享绝对时间原点。

完整命令、环境、退出码和同次程序逐轮读数见 [采集日志](../../reports/CH19/experiment-2026-11-17.txt)；[运行脚本](../../reports/CH19/experiment-2026-11-17-run.py) 保存诊断副本的生成方式，[分析脚本](../../reports/CH19/experiment-2026-11-17-analysis.py) 导出 [逐轮CSV](../../reports/CH19/experiment-2026-11-17-intervals.csv)、[汇总JSON](../../reports/CH19/experiment-2026-11-17-summary.json) 以及PNG/SVG。原始报告为 `reports/CH19/experiment-{per_step,reuse}-2026-11-17.nsys-rep`，同前缀SQLite保留。

在NSYS GUI打开原始报告后，先在CPU NVTX行找到CH19.life0/t0/t1/life1四个标记，再看CPU CUDA API行的cudaMalloc/cudaFree；转到CUDA HW的stream7查看vector_add和设备Event完成标记。step1的kernel Correlation ID分别为per_step539、reuse533。GUI需使用2026.4.1或更新版本；本次完成CLI采集和SQLite分析，未声称操作GUI。诊断副本和脚本保留以供复现，正式源码/二进制未修改，未运行NCU或新增allocator实验。

## 进一步区分地址、分配状态与提交方式（2026-11-18）

用户指出前面的解释只说明间隔在哪里，没有解释两方案为什么不同。为避免把可能机制当成已证明原因，本次补充独立诊断对照，正式源码和二进制保持不变。所有对照复用正式vector_add、n1000/float32/grid8/block128，每批32轮，各预热3批、循环轮换条件顺序测21批。诊断在每轮生成/校验CPU数据，因此host_batch只在诊断条件之间比较，不和正式host_loop直接混用。

核心对照仍是每轮对工作数组malloc/free各3次，但另设一个条件，在批次内一直保留一组完全不用的三数组空间。这样kernel输入与算法不变，每轮分配释放次数不变，只改变本程序的分配是否在每轮末尾全部释放。普通运行结果如下：

| 诊断条件 | Event合计中位数，μs/批 | CPU批次中位数，μs | 每批工作a的不同虚拟地址数 |
| --- | ---: | ---: | ---: |
| 工作空间复用 | 417.152 | 4938.915 | 1 |
| 每轮分配释放，不保留常驻工作分配 | 635.872 | 24758.418 | 1 |
| 每轮分配释放，另保留不用的常驻空间 | 337.600 | 5285.573 | 1 |
| 固定工作地址，每轮只分配释放不用的额外空间 | 367.520 | 5175.454 | 1 |
| 循环前准备32组工作地址，逐轮换地址但不分配释放 | 356.064 | 4681.715 | 32 |

这说明“每轮换一个虚拟地址取数”不是必要原因；本次反复分配拿到的a地址值并未变化，而轮换32组地址也没有稳定地产生更大的Event时间。但虚拟地址相同不证明物理映射、缓存或地址转换状态完全相同，本实验不据此排除所有访存状态因素。

进一步NSYS采集每轮分配、不用空间常驻、复用三个条件，循环内malloc/free分别仍为96/96、96/96、0/0。前两者malloc/free CPU API累计分别17669.642与367.908μs；cudaLaunchKernel CPU API中位数分别18.861与9.453μs，cudaEventRecord中位数分别12.199与9.843μs。额外保留不用的分配能改变后续API成本，证据把问题缩小到了分配驻留状态与Runtime/Driver提交路径这一层；并非malloc/free直接落进Event区间。NSYS没有揭示驱动内部究竟触发哪一个慢路径，不能把重映射、回收、驻留检查等猜测写成确定原因。

另用已学过的Graph，把start Event→同一kernel→stop Event先连好再一次提交，kernel参数更新放在Event外。相应Event批次中位数为复用269.984、每轮分配386.496、每轮分配加常驻333.216μs。它支持提交结构会影响Event窗口，但Graph也会影响调度，不能仅据此将所有剩余差异归为某一种CPU延迟。Graph Event节点依赖语义核对[CUDA12.9.1文档](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-runtime-api/group__CUDART__GRAPH.html)。

原正式程序在这组诊断前后各测了一次：Event合计分别为411.200/398.048μs和558.976/294.560μs（per_step/reuse），说明Event差距并非固定常数或稳定加速比。先前某一轮差距的唯一内部原因仍不能确定；目前有直接对照支持的是分配状态与提交方式会改变结果，不是从两个标记区间就能推出一个唯一驱动机制。

完整普通对照见 [v2日志](../../reports/CH19/cause-2026-11-18-v2.txt)、[v2源码](../../reports/CH19/cause-2026-11-18-v2.cu)，原始NSYS报告为 `reports/CH19/cause-{per_step,per_step_keepalive,reuse}-2026-11-18.nsys-rep`；[采集日志](../../reports/CH19/cause-2026-11-18-trace.txt)、[分析脚本](../../reports/CH19/cause-2026-11-18-analysis.py)、[汇总JSON](../../reports/CH19/cause-2026-11-18-summary.json)保留。首个pilot的per_step也保留了一组未使用空间，未完整复现原分配状态；v2将它明确拆成per_step_keepalive，pilot留作审计，不作为原版基线。所有普通对照逐轮数值通过，Graph每轮分配案例另经memcheck验证零错误、零泄漏；Sanitizer耗时不用于性能比较。

## 独立验收与首轮边界（约5～10分钟）

当前实现由Codex按请求提供。用户自行运行并复习后，用自己的话沿代码解释：为什么96次降为3次、循环内又是0次？为什么复用后仍要传输新输入，仍有32个kernel？在什么位置可以安全覆盖或释放旧空间？说明host_loop、host_lifecycle和Event各包含什么，并用输出或NSYS指出证据。

本章是PLAN首轮Ch00～19的最后一章，但材料、Codex实现和验证不等于个人完成课程。前章待验收项继续保留；本章个人运行与独立解释仍需验收。若一小时到点，记录卡点，不追加生产级allocator或自动启动后续选修。
