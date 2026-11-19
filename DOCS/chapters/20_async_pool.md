# Ch20：把申请和释放也排进 stream

这是首轮之后的第一节选修，承接Ch19。预算45～60分钟，只学习同一stream内的异步分配生命周期，以及内存池保留空闲空间。前章个人验收继续保留，本章材料生成不表示首轮已经完成。

## 先看一轮程序做什么（约5分钟）

Ch19已经看到：若32轮一直用同一组三数组，自己在循环外分配即可把申请/释放从每批96/96次降到3/3次。本章换一个问题：如果接口仍要求每轮申请、用完释放，能否由CUDA管理后续复用？

内存池可以先理解为一份“已经取得、可以再次分给后续申请”的空间储备。程序释放自己的分配后，这份储备可能暂时保留。本章每轮仍申请a/b/c三个数组，各1000个float、4000字节，用完释放；只改变分配释放API。

以第0轮为例，CPU先取到a/b/c的device地址，然后向同一条stream提交：

```text
sync： cudaMalloc ×3 → H2D(a,b) → memset(c) → vector_add → D2H(c)
                                                           ↓
                                                 CPU等待 → cudaFree ×3

async：cudaMallocAsync ×3 → H2D(a,b) → memset(c) → vector_add → D2H(c)
                                                                 ↓
                                                 cudaFreeAsync ×3 → CPU等待
```

图中`sync`和`async`是两种运行策略的名字。两者的拷贝都使用同一stream上的`cudaMemcpyAsync`，输入/输出均为已学过的pinned host内存；两者每轮都等待完成，然后才开始下一轮，不新增跨轮流水实验。

`vector_add`不变。例如block0/thread3仍读取a[3]、b[3]并写c[3]；第0轮输入为−5.875与−0.6875，结果−6.5625。第1轮host输入换到下一段，结果也会改变。pool复用存储空间不会自动更新输入，H2D仍必须提交。

运行前先预测：两种策略各有多少次申请/释放API？释放完后pool的`used`和`reserved`是否必须同时为0？相同kernel是否保证整批host时间相同？先写出自己的理由，再运行。

## 阅读与构建入口（约10分钟）

源码为 [CH20/async_pool.cu](../../CH20/async_pool.cu)，构建入口为 [CH20/compile.sh](../../CH20/compile.sh)。从`main`读到`run_batch`，再看`enqueue_work`、`allocate_async`和`release_async`。`main`提供环境检查、输入、pinned内存、stream、pool配置、校验及清理。

从项目根目录执行：

```bash
bash CH20/compile.sh
./build/CH20/async_pool check sync
./build/CH20/async_pool check both
```

2026-11-18，Codex按用户要求补全了两处TODO。`check sync`校验普通路径的32000项，`check both`依次校验普通与异步路径，各32000项。

程序会实际查询`cudaDevAttrMemoryPoolsSupported`；若为0，async明确NOT RUN，不强行扩大环境。遇到其他CUDA错误先读API名称和错误码。计时前取消`CUDA_LAUNCH_BLOCKING`，程序会拒绝在其非0时继续本实验。

## 两处实现复盘（约15～20分钟）

原TODO1在`allocate_async(Buffers&, Calls&, cudaStream_t)`。它在传入的`stream`上用`cudaMallocAsync`为a/b/c各申请`kBytes`。`CUDA_CHECK`逐次检查返回状态，每成功调用一次就增加`calls.mallocs`，随后由`run_batch`在同一条stream提交传输和计算。

原TODO2在`release_async(Buffers&, Calls&, cudaStream_t)`。它在这条stream上按c/b/a顺序提交三次`cudaFreeAsync`。每成功提交一次就增加`calls.frees`并将对应host指针设为`nullptr`。`run_batch`提交完释放后才调用`cudaStreamSynchronize`。

这里`&b.a`是host指针变量的地址，供申请API写回device地址；使用和释放API接收的是`b.a`保存的device地址值。这与Ch18区分输出位置和参数值的思路一致。host变量设为nullptr只改变CPU保存的值，不会取消已经提交的GPU任务。

API签名与准确语义以本机CUDA12.9头文件及[NVIDIA Runtime 12.9.1内存池文档](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-runtime-api/group__CUDART__MEMORY__POOLS.html)为准。`cudaMallocAsync`返回地址时，GPU上的分配操作未必已经执行；同stream随后提交的访问由队列顺序保护。`cudaFreeAsync`返回后，不得再提交使用旧分配的新任务；此前已提交的D2H位于释放之前，可以正常完成。本章只用一条stream，不推广为其他stream可无条件访问。

## 编译、校验，再计时（约10～15分钟）

```bash
bash CH20/compile.sh
./build/CH20/async_pool check both
compute-sanitizer --tool memcheck --padding 32 --leak-check full \
  --track-stream-ordered-races all --error-exitcode 99 \
  ./build/CH20/async_pool check both
./build/CH20/async_pool bench both
```

两条路径必须各检查32000项，`mismatches=0`、`max_abs_error=0`、`malloc/free=96/96`。输入每轮变化，全部输出检查有限值与误差，防止旧内容或漏写偶然通过。memcheck检查越界、泄漏及按stream排序的分配访问问题；它是另一层证据，不能用数值PASS代替。这里没有新增shared协作，故不把racecheck/synccheck作为无关门槛。Sanitizer下的用时不用于性能比较。

`bench both`先校验，各预热3批，再交替策略顺序测21批，输出`median_host_batch_us`。该CPU时间从第0轮分配前，到第31轮完成等待和释放后，包含全部分配API、拷贝、memset、kernel提交、释放及等待；pool设置、host准备、CPU数值校验、pool查询和最终trim都在计时外。本章没有CUDA Event计时，不需要从短kernel的Event差异推断分配成本。

两种策略工作量固定，但普通free前需要确认访问已完成，async free则按队列顺序保护生命周期，因此等待与释放位置不同。host差异反映本程序整批路径成本，不能仅凭差值推断底层物理申请次数，也不表示加法指令本身变快。无固定加速比要求。

## 看懂pool的两个数字（约5分钟）

程序在计时外固定当前device pool的`cudaMemPoolAttrReleaseThreshold`为64MiB，退出前恢复旧值。这个阈值用于控制同步时尝试归还空闲储备的行为，不是预先申请64MiB，也不是池容量硬上限。默认值为0，可能在同步时归还空闲储备；固定保留策略便于本章观察后续复用，不同时把阈值作为第二个实验变量。教学预检先试8MiB，但本机一次4000字节分配就观测到32MiB储备，超过阈值后同步归还；因此正式材料固定64MiB。32MiB是本机本次观察，不是所有设备的固定粒度。

`used_bytes`是pool中当前由应用分配使用的字节数；`reserved_bytes`是pool当前保有的底层储备。程序完成释放并同步后，可能出现used=0而reserved>0：应用已经交还分配，CUDA暂时保留可再使用的储备。其数值不要求等于3×4000，底层保留有分配粒度。sync路径的普通cudaMalloc空间不属于这组pool统计，不能拿pool used=0断言sync没有占显存。

最后的`cudaMemPoolTrimTo(pool, 0)`在工作完成后尝试归还可安全释放的储备，位于计时外；观察`after_trim`实际值，不把请求trim等同于任何条件下都保证清零。释放后旧地址失效，即使以后某次申请得到相同地址值，也要以那一次申请的生命周期为准。

这与Ch19的区别可以直接从调用数看出：Ch19由程序一直持有同一组分配，所以循环内分配释放为0；Ch20的async路径每批仍有96次申请和96次释放，只是底层可借助pool管理空间复用。两者都可能复用空间，API数量与资源持有方式不同。

## 可选：用NSYS核对API与GPU活动

时间紧时只完成上述必做内容；本节用于熟悉工具后的观察，不新增SQL学习要求。两条命令分别采预热后的一个批次，报告保存到`reports/CH20/`：

```bash
mkdir -p reports/CH20
nsys profile --trace=cuda --sample=none --cpuctxsw=none \
  --capture-range=cudaProfilerApi --capture-range-end=stop \
  -o reports/CH20/user-sync ./build/CH20/async_pool trace sync
nsys profile --trace=cuda --sample=none --cpuctxsw=none \
  --capture-range=cudaProfilerApi --capture-range-end=stop \
  -o reports/CH20/user-async ./build/CH20/async_pool trace async
```

在CPU CUDA API行分别找`cudaMalloc/cudaFree`或`cudaMallocAsync/cudaFreeAsync`，它们在目标批次应各96次；两份GPU轨迹均应有32个vector_add、64次H2D、32次D2H和32次memset。异步分配仍有CPU调用成本，不能从名字里的Async推导为零开销或任意调用都立刻返回，也不要求GPU轨迹一定显示独立分配色块。

采集覆盖目标批次和其host校验/打印；初始化、warmup、pool设置与最终trim在capture外。profiler结果只用于轨迹与调用关系，正常性能看前面独立bench。GUI需使用能读取当前2026.4.1报告的版本；本章不声称Codex操作过GUI。

## 历史预检与个人验收

以下预检来自当时保留两处TODO的骨架及隔离补全版。[preflight日志](../../reports/CH20/preflight-2026-11-18.txt)记录了命令、环境、源码哈希和退出码。[历史预检脚本](../../reports/CH20/preflight-2026-11-18-run.py)需要当时含占位符的源码。正式补全版的验证见下文及[RECORD](../RECORD.md)。

2026-11-18现场为GTX1650/CC7.5/4GB、NVCC12.9.86、Runtime12090、DriverAPI13030、驱动610.88、Compute Sanitizer2025.2.1、NSYS2026.4.1，`memory_pools_supported=1`。正式骨架构建无警告、sync数值和memcheck通过；both在TODO1处按预期返回2。隔离补全版两策略各32000项、最大误差0，分配/释放各96次；memcheck带padding32、leak-check full及stream-ordered-races all，零错误、零泄漏。仅补TODO1的路径也验证了TODO2处返回2和安全清理；该未完成路径的pool统计不用于正常分配生命周期结论。

普通bench独立于profiler，3批预热、交替顺序21批的host整批中位数如下。该值不包含pool设置和最终trim，不是kernel时间或纯分配成本。

| 策略 | median_host_batch_us |
| --- | ---: |
| sync | 24140.163 |
| async（固定64MiB阈值） | 3837.102 |

成功async批次同步后used为0、reserved为33554432字节，trim后两者均为0。这个观察说明本机本次在应用释放后保留了pool储备，不证明具体物理页复用次数或要求每次申请得到同一地址。原8MiB pilot的整批中位数为23116.116/67181.754μs（sync/async），释放后reserved=0；不同配置不混成一组稳态统计，也不把Async名称当作必然加速保证。定位阈值问题的[最小统计探针](../../reports/CH20/pool-stats-probe-2026-11-18.txt)保留源码与输出，旧pilot日志和报告使用`pilot-8MiB-`前缀保留。

独立NSYS已核对普通/异步API各96次、两份各32个kernel、64次H2D、32次D2H、32次memset，所有传输均4000字节；GPU活动在同一stream逐轮保持H2D/H2D/memset/kernel/D2H顺序。33次stream同步包括批次开始前一次和32次逐轮等待。原始报告为`reports/CH20/preflight-{sync,async}-2026-11-18.nsys-rep`，同前缀SQLite保留；[分析脚本](../../reports/CH20/preflight-2026-11-18-analysis.py)与[结构化计数](../../reports/CH20/trace-counts-2026-11-18.json)保留raw API名称和版本后缀。未运行NCU或声称操作GUI，预检临时源码与可执行文件已清理。

## 正式补全版验证（2026-11-18）

重新构建后，普通与异步两条路径各校验32000项，最大误差0，申请和释放分别为96次。memcheck含stream-ordered-races all和leak-check full，报告零错误、零泄漏。64MiB阈值下，异步批次释放并同步后`used=0`、`reserved=32 MiB`，trim后均为0。正常计时的32轮host整批中位数为sync 24.220ms、async 3.770ms，各预热3批、交替顺序测21批。这个数值覆盖提交、释放、传输和等待，适用于本机本次实验。

正式NSYS对照分别确认普通与异步申请/释放各96次，两份GPU轨迹均有32个kernel、64次H2D、32次D2H和32次memset，单stream工作顺序一致。命令、版本、哈希、原始API计数与退出码见[正式验证日志](../../reports/CH20/completed-2026-11-18.txt)，原始报告和SQLite为`reports/CH20/completed-{sync,async}-2026-11-18.*`。

独立验收时，重编译并运行双策略，沿`run_batch`和两个helper说明：同stream中为什么D2H可以先于异步释放完成？为什么async申请/释放API仍各96次，而释放后pool可以used=0、reserved>0？Ch19自己持有空间与本章pool保留空间有何区别？指出host批次时间包含什么，并对照实际输出解释结果。到一小时仍有卡点就记录，不追加跨stream复用、自定义pool、Graph内存节点或完整allocator。
