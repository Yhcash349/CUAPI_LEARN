# Ch21：跨 stream 使用与释放异步分配的内存

预算45～60分钟，承接Ch15的Event接力与Ch20的异步分配。先读`run_batch()`，再找计算和释放之前的两个等待点。两处TODO已于2026-11-24按用户要求补全。[源码](../../CH21/cross_stream_lifetime.cu)

## 从第0轮的数据流开始（约10分钟）

本章把“申请空间的人”和“使用空间的人”放在两条队列。`owner`负责申请、上传和最终释放；`worker`负责初始化输出、计算和回读。这是程序给队列取的名字，两者都是同一GPU上的普通nonblocking stream，没有特殊所有权权限。

每轮处理1000个float32，a/b/c各4000字节。以第0轮为例，CPU先调用`cudaMallocAsync`取得三个地址，在owner上传输入，记录`ready[0]`；接着向worker提交初始化、8个block×128线程的加法和回读，在worker记录`done[0]`；最后向owner提交释放。线程3只负责`c[3]=a[3]+b[3]`，尾部24个线程由`i<n`保护。

问题是：CPU依次调用了这些API，不代表两条队列已经建立执行顺序。必须让worker在ready完成后才能使用地址，再让owner在done完成后才能释放。

```text
owner:  mallocAsync(a/b/c) → H2D(a/b) → ready[0] ───────┐
                                                       ↓
worker:                                     等ready → memset → kernel → D2H → done[0]
                                                                              │
owner:                                                   等done ←─────────────┘
                                                            ↓
                                                   freeAsync(a/b/c)
                                                            ↓
                                                   第1轮申请和上传
```

第一条边同时保护“分配可用”和“输入上传完成”；第二条边保护“最后一次读取c的D2H已经完成”，因而done必须记录在回读后。若以后把done移到kernel后、D2H前，释放c就失去了对回读的保护。

异步分配的直觉是：CPU先取得地址，GPU按排好的顺序启用、访问和归还这份分配。其他stream要使用它，必须保证分配已经完成；释放前也必须保证所有访问已经结束。这是[CUDA 12.9.1异步分配接口](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-runtime-api/group__CUDART__MEMORY__POOLS.html)规定的生命周期条件。只拿到非空指针，或者只在main最后等待两条stream，都不能替代中途两条边；最后等待无法修复已经发生的提前访问或提前释放。

## 本章只改变谁来等（约5分钟）

两条路线都使用两条stream、相同的三次`cudaMallocAsync`和三次`cudaFreeAsync`、相同输入和GPU工作。唯一变量是两处交接用CPU等待还是设备队列等待。

| 路线 | ready之后 | done之后 | CPU能否先提交后续工作 |
| --- | --- | --- | --- |
| host | CPU调用`cudaEventSynchronize(ready)`再提交worker工作 | CPU等待done后再提交owner释放 | 每轮两次交接均需CPU等到标记完成 |
| event | 向worker排入等待ready | 向owner排入等待done，再排入释放 | 不要求CPU在这两处等标记完成 |

`cudaStreamWaitEvent`让目标队列的后续工作等Event，不把这次交接变成CPU等待Event完成；API仍有提交成本，也不承诺任何条件下都瞬间返回。其参数顺序按[Stream Management](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-runtime-api/group__CUDART__STREAM.html)核对：第一个参数是“谁等待”，第二个是“等哪个标记”，本例flags为0。

与Ch15不同，本章有意让owner先等本轮worker用完、释放后才处理下一轮，GPU整条链仍然按轮有序。这里的收益观察是减少CPU交接等待及其间隙，不要求两个kernel重叠，也不要求两条stream必然比一条更快。与Ch20相比，新的问题是同一分配跨队列时如何保持有效生命周期。

运行前先预测：数值和96/96次分配释放应不会改变；两条路线各有64处交接，等待类型会怎样变化？如果kernel数量和执行顺序都没变，host整批时间是否仍可能变化？

## 运行程序并阅读两处等待（约20分钟）

从项目根目录执行：

```bash
bash CH21/compile.sh
./build/CH21/cross_stream_lifetime check both
```

`wait_until_ready(worker, ready)`调用`cudaStreamWaitEvent(worker, ready, 0)`，把等待排在worker的初始化与计算之前。`wait_until_unused(owner, done)`调用`cudaStreamWaitEvent(owner, done, 0)`，把等待排在owner的释放之前。两处用`CUDA_CHECK`检查提交结果，提交成功后计入设备等待。`host`路线在对应位置用`cudaEventSynchronize`等待。正式程序的两条路线分别显示以下计数。

```text
host:  malloc/free=96/96 host_waits=64 device_waits=0
event: malloc/free=96/96 host_waits=0  device_waits=64
```

这些计数只统计循环里的Runtime调用与两处交接，不包括批次首尾的stream同步，也不是驱动内部调用或物理显存申请次数。每轮ready/done各一个，所有64个Event在计时外创建，用`cudaEventDisableTiming`表示只作依赖标记；它们没有承担GPU计时。下一批重用这些Event前，上一批两条stream均已完成。

## 正确性、生命周期与整批时间（约10分钟）

```bash
./build/CH21/cross_stream_lifetime check both
compute-sanitizer --tool memcheck --padding 32 --leak-check full \
  --track-stream-ordered-races all --error-exitcode 99 \
  ./build/CH21/cross_stream_lifetime check both
./build/CH21/cross_stream_lifetime bench both
```

每条路线全量校验32×1000项，参考值由CPU计算，非有限数或绝对误差超过1e-6都失败；输入按轮变化，以检查旧数据和漏写。Sanitizer额外检查非法访问、泄漏及异步分配生命周期问题。数值PASS和memcheck零错误是两层证据，仍需沿代码确认两条依赖；本例不涉及shared协作，不增加racecheck/synccheck门槛，也不执行故意缺失依赖的未定义行为作为稳定错误演示。

`bench both`先校验，再每策略预热3批，交替顺序测21批取中位数。`host_batch_us`从第0轮申请前，到第31轮结束并等待两条stream完成，包含32轮分配、传输、初始化、计算提交、依赖、释放和完成等待。批次开头清空队列、创建stream/Event、准备pinned输入、设置池、CPU校验和最终trim都在计时外；这不是纯kernel时间或CPU仅提交时间。

沿用Ch20的64MiB release threshold，固定两策略的池保留配置，结束时trim并恢复旧配置。同步后打印`used/reserved`供确认释放；只把它作为环境与清理观察，不把池阈值或储备大小变成第二个实验变量，也不承诺所有环境都保留32MiB。两策略没有固定加速比要求。

## 可选：用NSYS核对两条等待边（剩余时间足够时）

独立于普通bench采集。

```bash
mkdir -p reports/CH21
nsys profile --trace=cuda --sample=none --cpuctxsw=none \
  --capture-range=cudaProfilerApi --capture-range-end=stop \
  -o reports/CH21/user-host ./build/CH21/cross_stream_lifetime trace host
nsys profile --trace=cuda --sample=none --cpuctxsw=none \
  --capture-range=cudaProfilerApi --capture-range-end=stop \
  -o reports/CH21/user-event ./build/CH21/cross_stream_lifetime trace event
```

捕获的是已校验、预热后的一个批次，初始化、预热、池配置及最终清理在外。目标CPU API中，host应有64次`cudaEventSynchronize`，event应有64次`cudaStreamWaitEvent`且无交接用的EventSynchronize；两份各有96次mallocAsync、96次freeAsync、64次EventRecord和4次stream同步（批次开始2次、末尾2次）。

GPU轨迹两份均为32个vector_add、64次H2D、32次D2H和32次memset，各次操作处理4000字节。owner承载H2D，worker承载memset/kernel/D2H；依次查看本轮ready和done相关CPU提交、跨队列GPU工作顺序与下一轮开始位置。依赖标记不必显示为独立GPU色块，不用相邻色块猜测唯一驱动机制，也不把profiler下时间当普通bench。GUI使用能打开NSYS 2026.4.1报告的版本。

## 独立验收与边界（约5分钟）

从一轮具体地址开始，说明为什么`cudaMallocAsync`已经返回仍需要ready，为什么done要放在D2H后，以及owner只负责释放并不自动知道worker用完了。指出两条设备等待各自的目标stream，再解释为什么最后的stream同步不能补救缺失的中途依赖。

个人编译运行、解释96/96和64处交接，并根据实际普通bench及可选trace说明结果后再判断验收；Codex预检只说明工程准备。实际一小时到点仍有问题就记录，不追加多GPU、自定义pool、VMM或完整allocator。框架里的“分配方与使用方分处不同队列”是本例的应用连接，不据此推定真实框架的具体实现。

## 教学方预检（2026-11-19）

现场GTX1650/CC7.5/4096MiB，驱动610.88、NVCC12.9.86、Runtime12090、DriverAPI13030、Compute Sanitizer2025.2.1、NSYS2026.4.1，`memory_pools_supported=1`。API签名同时核对本机`cuda_runtime_api.h`和上述CUDA12.9.1官方资料。

正式骨架与隔离的部分/完整补全版均编译无警告。骨架两路线各32000项正确、最大误差0，但event仍是64次CPU回退；骨架bench/trace按预期返回2且执行trim。仅补TODO1时为32次host/32次device等待，性能运行继续被拒绝。完整补全版两路线各32000项正确、最大误差0、申请释放96/96，host为64/0次交接等待，event为0/64。正式骨架及完整补全版的memcheck均开启padding32、leak-check full、stream-ordered-races all，零错误、零泄漏。

完整补全版独立普通bench每策略预热3批、交替顺序测21批，host整批中位数为host **3702.467μs**、event **4261.529μs**。本次event路线没有更快；减少CPU交接等待不保证整批完成时间必然缩短，当前对照没有进一步分解这次差值的内部原因，不能把它解释成加法kernel变慢。这组结果只适用于本机本次32轮小任务。

独立NSYS确认host/Event两路线的交接API分别为64次`cudaEventSynchronize`与64次`cudaStreamWaitEvent`；两份各96次mallocAsync、96次freeAsync、64次EventRecord及4次stream同步。GPU均有32个kernel、64次H2D、32次D2H和32次memset，4000字节/次；H2D在owner（本次stream13），memset/kernel/D2H在worker（本次stream14），按轮保持H2D/H2D/memset/kernel/D2H顺序，未观察到活动间重叠。数值ID只标识本次报告，阅读其他运行时按活动识别队列。计数和已导出的GPU端点不能证明驱动内部唯一性能原因。

完成并同步后池`used=0、reserved=33554432`，trim后均为0。NSYS原始报告及SQLite为`reports/CH21/preflight-{host,event}-2026-11-19.*`。当日的临时补全源码和二进制已自动清理。[预检日志](../../reports/CH21/preflight-2026-11-19.txt) · [历史骨架预检脚本](../../reports/CH21/preflight-2026-11-19-run.py) · [分析脚本](../../reports/CH21/preflight-2026-11-19-analysis.py) · [计数及端点JSON](../../reports/CH21/trace-counts-2026-11-19.json)

## 正式版验证（2026-11-24）

两个TODO补全后，`check both`中两条路线各32,000项全部正确，最大误差0。每条路线申请和释放各96次。memcheck开启`--track-stream-ordered-races all`和完整泄漏检查，报告零错误、零泄漏。

GTX1650上，每条路线独立预热3批后交替测21批，整批耗时中位数为`host` **3.808 ms**、`event` **4.339 ms**。独立NSYS分别确认两条路线有64次CPU Event等待、64次stream Event等待，GPU活动数量及逐轮顺序一致。`event`路线在本次计时中较慢。现有结果仅定位到整批耗时，未分解差值来源。[正式验证日志](../../reports/CH21/completed-2026-11-24.txt) · [NSYS结构化计数](../../reports/CH21/completed-trace-counts-2026-11-24.json)

## 为什么交接 API 更短，整批却可能更长

`cudaEventSynchronize` 返回时，CPU 已经等到对应标记完成。`cudaStreamWaitEvent` 的 CPU API 区间只覆盖提交队列依赖。两处等待都交给 stream 时，CPU 可以更早提交下一轮，GPU 仍须按 `ready → 计算和回读 → done → 释放` 的顺序推进。最后一次 CPU 同步要等 owner 队列里的工作完成。

在临时诊断版中，用同一 CPU 时钟在循环末尾加一个计时点，将整批拆成循环段与批末等待段。保持两路线交替，每次预热3批、测21批。5次运行各取中位数后再取中位数，结果如下。这三列各自取中位数，因此展示值不要求精确相加。

| 路线 | 循环段（含循环内的等待） | 批末同步段 | 整批 |
| --- | ---: | ---: | ---: |
| `host` | 3.773 ms | 0.002 ms | 3.775 ms |
| `event` | 1.887 ms | 2.457 ms | 4.306 ms |

四策略对照中，两处都用CPU等待的整批中位数为3.729 ms，只把`ready`或`done`交给stream后分别为3.914和3.967 ms，两处都交给stream为4.358 ms。各组合均通过全量校验和memcheck。两个诊断程序与正式版均独立运行普通bench。正式版另跑10组对照，`host`快6组、`event`快4组。由此能看出，CPU更早交完工作、在末尾等待更久可以同时发生，整批排名会随运行而变。[两策略分段日志](../../reports/CH21/handoff-pair-2026-11-24.txt) · [四策略对照日志](../../reports/CH21/handoff-diagnosis-2026-11-24.txt) · [诊断脚本](../../reports/CH21/handoff-diagnosis-2026-11-24.py)

原有单批NSYS里，64次交接CPU API合计为`host` 2.578 ms、`event` 0.087 ms。两份报告从第一次申请API入口到批末第二次stream同步返回的跨度分别为5.177和5.084 ms，其中末尾两次同步合计0.003和0.979 ms。GPU轨迹中全部可见拷贝、初始化和kernel区间合计0.300和0.304 ms。普通bench和这次采集是不同运行，整批差值无法用两份轨迹的调用耗时直接相减解释，CUDA驱动内部的排队及调度成本也未分离。[host原始报告](../../reports/CH21/completed-host-2026-11-24.nsys-rep) · [event原始报告](../../reports/CH21/completed-event-2026-11-24.nsys-rep)
