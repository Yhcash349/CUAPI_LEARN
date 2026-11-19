# 学习笔记

教学范围与章节顺序以 [PLAN.md](PLAN.md) 为准；任务进度和工作量（含实际学习状态与用时）仅在 [RECORD.md](RECORD.md) 更新。本文件服务于理解和复习，不记录编辑器、agent 配置或工程迁移流水。

## 学习背景与起点（2026-09-20）

学习目的是从小程序认识 CUDA 与 NVIDIA GPU 的执行、存储和调度，再为 Runtime/Driver 追踪及推理框架分析建立基础。用户明确希望每章最多约 1 小时，每个必要知识点都能指向代码或实验现象，不先背大量架构术语。

初始阶段只完成了课程讨论与 Codex 环境预检；后续已讲解 Ch00 并按用户要求提供完整代码，仍没有用户独立掌握的验收证据。后续解释从具体 shape、线程或一次数据流开始，先给直觉，再给术语，避免因为这里出现名词就跳过教学。

## Ch10 阅读入口（2026-10-26）

[归约讲义](chapters/10_reduction.md) 从“256 个线程手里的数怎样合成一个和”开始。先复用 shared 与 block barrier 合并片段和，再用 warp shuffle 在同一 warp 内直接交换线程手里的值；跨 warp 的 shared 交接仍需 barrier。本章固定完整 warp，只要求理解局部合并和交接，不扩展尾部 mask 或全 GPU 多级归约。

入口讲义保留原练习路线，本页末尾的 Ch10 总结整理实际提问、树形合并与跨 warp 交接。阅读重点是每轮谁写、下一轮谁读，以及为什么最后只有 8 个有效 warp 和时仍让完整 32 lanes 参与 shuffle。

## Ch11 阅读入口（2026-10-27）

[SM 与 occupancy 讲义](chapters/11_occupancy.md) 从“一个 SM 能同时放下多少个相同 block”开始。复用 Ch10 求和，只增加启动时每 block 额外预留的 shared 字节数；求和结果应相同，但有限 shared 可能限制驻留数量。occupancy 在这里是驻留 warp 占该 SM 最大 warp 数的比例，不是 GPU 利用率或加速比。

阅读时先分清每 SM 的容量、每 block 的用量与全 GPU 的 grid，再看 host 上的 occupancy 查询和动态预留字节数。API 给出理论上限，NCU 核对实际配置与 achieved occupancy，普通 Event 单独看耗时。本页末尾的 Ch11 总结整理实际提问、shared 容量推导、实验现象与 NCU 平均值口径，不将已有讲解记为用户独立掌握。

2026-10-28 用户先后要求 Codex 补全两处练习。`active_blocks_per_sm()` 根据 kernel、kBlock 和 dynamic_bytes 查询每 SM 理论驻留 block 数，输出写入 blocks；查询不会启动 kernel，也不改变实际预留量。随后 `launch()` 将 requested_bytes 作为第三个启动参数，为每个 block 实际预留相应的动态 shared；静态 32 字节仍另外计入。只完成查询的阶段，实际预留曾全部为 0；当前两处均完成，NCU 已核对三组动态预留量。两处实现和验证由 Codex 完成，个人独立解释待验收。

## Ch12 阅读入口（2026-10-28）

[数据复用讲义](chapters/12_data_reuse.md) 从“相邻输出会重复使用同一份输入”开始。一个线程负责 C 的一个元素，一个 block 合作装载两块 16×16 的输入到 shared，沿 K 分段累加。阅读时区分线程负责搬的元素与它计算时读取的元素，结合具体线程说明谁写、谁读，以及为何每轮装载后与覆盖前都要 barrier。

源码最初保留装载与累加两处练习，2026-10-28 已按用户要求由 Codex 补全：各线程按 A 的 (row,base+tx) 与 B 的 (base+ty,col) 装载，越界填零，再用 a_tile[ty][p] 与 b_tile[p][tx] 逐项乘加。host 提供 naive 对照、CPU double reference、尾部边界校验和 Event 骨架。减少源码 global 读取不等于 DRAM 流量或耗时同比下降；本章先用正确性和实测观察复用，不扩展完整 GEMM 优化体系。本页末尾的 Ch12 总结整理参数、语法、分块累加的实际复述及访存疑问，不将讲解或 Codex 验证直接记为独立掌握。

## Ch13 阅读入口（2026-10-28）

[Host 异步讲义](chapters/13_host_async.md) 从“CPU 已交出工作，GPU 可能仍在计算”开始。复用逐元素向量运算，同一次 launch 分别记录提交返回和等待完成后的 CPU 时刻，再用同 stream Event 对照 GPU 区间。核心是指出等待放在哪个时间边界里，以及区分 CPU 提交 Event 请求与 GPU 到达标记的时刻。

`wait_on_host()` 原有一处练习，2026-10-29 已按用户要求由 Codex 实现并验证。用户已提供 NSYS GUI 截图，选中第五次 `repeated_add`，结合 CPU/GPU 关联高亮询问提交与执行的对应关系。本页末尾的 Ch13 总结整理实际提问、三种时间范围、正式数据和 GUI 读图；实现及工具验证由 Codex 完成，个人运行和完整独立解释待验收，不将截图或已讲解等同于独立掌握。

## Ch14 阅读入口（2026-11-02）

[Stream 讲义](chapters/14_streams.md) 从“两个独立任务放进一条或两条队列”开始。复用 Ch13 的逐元素累加，A/B 读写不同数组片段，只改变 B 的目标 stream。先预测同队列的先后与双队列可能的重叠，再完成创建和启动路由两处练习，最后在 NSYS 按 stream 与 Correlation ID 观察两个 GPU 区间。

2026-11-02 已按用户要求由 Codex 补全两处练习：`create_work_stream()` 用 `cudaStreamCreateWithFlags` 创建 nonblocking 队列，`launch()` 把调用方传入的 stream 放入第四个启动参数。创建决定有哪些队列，启动参数决定本次任务放入哪条队列；`cudaStreamGetFlags` 只查询配置，不修改队列。实现由 Codex 辅助完成，个人运行与独立解释仍待验收。

阅读重点是同 stream 保序、不同 stream 的 CPU 提交顺序不能替代设备依赖，以及 stream 不固定对应 SM。host 在两个 launch 都提交后才依次等待两队列，等待 s0 不会阻止已经提交到 s1 的独立任务推进；实际是否并发由本次 GPU 时间线判断。普通 host_pair 覆盖提交与完成等待，不能当作单 kernel 的 GPU 时间。本页末尾的 Ch14 总结整理实际提问、两类实验数据和用户提供的 GUI 截图；个人实现与采集、完整独立解释仍待验收。跨 stream Event 和传输流水留到 Ch15。

## Ch15 阅读入口（2026-11-02）

[Event 与重叠讲义](chapters/15_event_pipeline.md) 从“下一块上传能否与当前块计算同时推进”开始。Event 是队列里的完成标记，另一条队列可以等标记后继续；pinned memory 是固定在内存中、供异步传输使用的 host 缓冲。骨架给出两个 device 槽位，交替处理 8 个独立数据块，块内仍保持 H2D→kernel→D2H 顺序。串行与流水只改变每块结束是否额外等待 CPU。

两处练习已于 2026-11-03 按用户要求由 Codex 补全：`wait_for_input()` 用 `cudaStreamWaitEvent(compute, ready, 0)` 让计算队列等待输入就绪，`wait_for_slot()` 用 `cudaStreamWaitEvent(upload, done, 0)` 让上传队列等待旧槽位用完。两者均检查 API 状态后返回 true；设备依赖保留，CPU 不再在 helper 中等待 Event 完成。原骨架使用 CPU 等待占位，数值可以通过，但拒绝流水计时，该状态现已结束。阅读时沿块 0～2 区分 host 的独立片段与 device 的复用地址，解释 Record 提交、设备队列等待和 CPU 等待的差别。实现与工具验证由 Codex 完成，个人运行、读图或独立解释仍待验收，不据此补记用户掌握。

2026-11-05 已补充 [正式实验与实际GPU时间线](chapters/15_event_pipeline.md#正式实验与流水证据2026-11-05)，本页末尾的 Ch15 总结整理本章真实提问、run_batch执行顺序、串行/流水的实际复述与实验读图。重点区分CPU提交与GPU执行、全程共用的stream与复用存储slot、同chunk的ready接力与跨chunk同槽位的done保护，以及NSYS采集数据与Python重绘图的来源。用户已有部分复述，实现与工具验证由Codex完成，个人运行/读图与完整独立解释仍待验收。

## Ch16 阅读入口（2026-11-05）

[Graph 讲义](chapters/16_graph_replay.md) 从“同样的三个小 kernel 能否少提交几次”开始。固定 input→加 1→乘 2→减 0.5→output 的链，每批重复 64 条；direct 每条分别启动三个 kernel，graph 将提前录好的链一次提交。Graph 是把固定工作及依赖先描述好再重放，capture 负责记录，实例化得到可启动对象，replay 才提交执行；GPU 上仍然是三个 kernel，不自动融合。

两处练习已于2026-11-06按用户要求由Codex补全：capture_chain在stream上开始capture、录入launch_chain、结束capture得到graph，再实例化得到exec；replay_chain用cudaGraphLaunch提交exec，整批完成等待仍由run_batch负责。host、计算、校验和计时同样由Codex提供。沿thread3和tmp0/tmp1解释先写后读，同一stream保序，固定地址要保持有效到最后一次replay完成。阅读时分清CPU提交时间、host等待完成时间和含间隙的Event区间，一次性建图不在稳态计时内。原骨架的安全回退与拒绝Graph计时已成为历史状态；临时预检与正式补全验证分列在讲义中，均不替代个人运行或独立解释。

2026-11-09补充 [正式版NSYS间隙对照与GUI阅读路线](chapters/16_graph_replay.md#正式-nsys-间隙对照与-gui-阅读路线2026-11-09)。同一批192个kernel的执行耗时合计相近，普通/Graph链内间隙中位数为2.016/0.320μs，目标区间没有memcpy/memset；这体现工作提交与执行衔接的变化，不能把所有间隙都归成H2D拷贝开销。重点看CUDA HW的GPU色块端点，CPU CUDA API行用于看逐kernel提交与Graph提交，不能互换计时含义。图由NSYS SQLite实测端点重绘，非GUI截图；原始报告保留，Graph仍存在链间间隙。本页末尾的Ch16总结整理本章实际提问、API流程、指针/句柄、节点检查、三种计时与正式实验，个人读图与独立解释待验收。

## Ch17 阅读入口（2026-11-09）

[编译产物讲义](chapters/17_compilation_artifacts.md) 从熟悉的 vector add 出发：同一份 CUDA 源码，普通构建得到含 host 代码与 device image 的可执行文件，`--ptx` 和 `--cubin` 则只保留 device 产物。PTX 是还需进一步翻译的 GPU 程序文本，cubin 是面向指定架构的二进制，SASS 是其中机器指令的可读反汇编；本章只比较编译输出阶段，不做性能实验。

两处练习在 `CH17/compile.sh`，2026-11-09 已按用户要求由 Codex 补全 PTX/cubin 编译命令，分别使用 `--ptx --gpu-architecture=compute_75` 和 `--cubin --gpu-architecture=sm_75`。`CH17/vector_add.cu` 的 host、已学过的索引/加法和全量校验由 Codex 完整提供；`extern "C"` 保留 `vector_add` 入口名称及 a/b/c/n 参数顺序，供 Ch18 使用。阅读时区分 compute_75、sm_75 与 PTX 文本里的 `.target sm_75`，不要把 PTX `.version 8.8` 当成 GPU 能力或 Toolkit 版本，也不要把 PTX 虚拟寄存器数量当成 ptxas 的硬件分配结果。

Codex 已重新编译正式脚本三种输出，Runtime 全量数值与 memcheck 通过，正式 PTX/cubin 生成及入口查看通过。普通程序通过不表示已经加载并执行了外部 cubin，外部加载留待下一章。用户已贴出 nvdisasm 命令及完整输出，作为产物查看证据；个人编译/Runtime运行与完整独立解释仍待验收。本页末尾的 Ch17 总结整理本章真实问题、PTX逐线程数据流、地址与数值、SASS及cubin结构，不将讲解直接记为已掌握。

**用户提问：这种 `.sh` 文件以后拿到怎么看其实现的功能？**

`.sh` 通常是保存终端命令的文本脚本，本例指定使用 Bash。先找真正执行工作的命令，再追踪决定命令的输入参数、变量和分支，最后确认工作目录及输出。本例真正工作的是 nvcc；`bash CH17/compile.sh ptx` 把 ptx 作为 `$1`，`mode="${1:-runtime}"` 选择 ptx（省略或传空字符串则默认 runtime），先检查参数是否合法，再在第二个 case 中只进入 ptx 分支。输入是 `CH17/vector_add.cu`，输出由 `-o` 指定为 `build/CH17/vector_add.ptx`。脚本只编译，不启动生成的程序或执行 GPU 加法。

开头 `#!/usr/bin/env bash` 指定直接执行脚本时使用 Bash；显式 `bash 文件` 则已经选定解释器。`chapter_root` 根据脚本所在位置找项目根目录，再 cd 过去，保证相对路径一致。`$#` 是参数数量，`flags=(...)` 是公共参数数组，`"${flags[@]}"` 展开成独立参数；行尾反斜杠把下一物理行接成同一条命令，`;;` 结束一个 case 分支。`set -euo pipefail` 启用常见失败退出、未设置变量检查及管道失败传播；`-e` 存在条件判断等例外，本章只需知道编译失败会让此脚本停止。

先用编辑器或 `less CH17/compile.sh` 阅读源码，再用 `bash -n CH17/compile.sh` 检查语法（不执行主体命令）。需要观察参数展开时，`bash -x CH17/compile.sh ptx` 会显示并实际执行命令，因而也会重新编译输出；`-x` 不是只读预览。语法检查也不保证命令路径或功能正确。参数语义参考 [GNU Bash 手册](https://www.gnu.org/software/bash/manual/bash.html#The-Set-Builtin)。本次提问说明用户开始关注脚本的执行流程，不据此补记为已经独立掌握 Bash。

## Ch18 阅读入口（2026-11-09）

[Driver 启动讲义](chapters/18_driver_launch.md) 接着 Ch17 的独立 cubin：先建立当前线程使用 GPU 资源的 context，再加载模块、按名字找到 vector_add，最后传参启动。host 源码不再包含 kernel 定义；GPU 仍执行相同的 sm_75 加法，数据和线程配置保持一致。本节比较启动路径，不做性能结论或 Runtime/Driver 内部调用的一一映射。

`CH18/driver_vector_add.cpp` 原有两处 TODO，2026-11-10 已按用户要求由 Codex 补全：`cuModuleLoad` 写出模块句柄，`cuModuleGetFunction` 从 `*module` 查找 vector_add；启动时以 `void* args[] = {&d_a, &d_b, &d_c, &n}` 按参数顺序提供 host 变量地址，再用 `cuLaunchKernel` 提交。context、内存、等待和校验由骨架提供。阅读重点是“GPU 地址值”与“保存该值的 host 变量地址”：Driver 从参数数组指向的 host 变量复制参数值，kernel 随后拿到 GPU 地址并访问数组。加载成功、提交返回、执行完成和数值正确分别对应不同检查点，不能互相替代。

此前隔离临时版本预检为历史证据；2026-11-10 Codex 已重建并运行正式版本，实际加载 Ch17 cubin，1000项全量校验与 memcheck 均通过。两处实现及验证由 Codex 完成，个人运行与独立解释待验收，不记为用户已经独立掌握；进度及证据统一见 RECORD。

**用户提问：CPU线程和context是什么关系，context具体保存什么，能否打印previous/context？**

CPU线程在这里就是运行main、调用这些cu API的host执行线程。驱动记录“这个线程当前选用哪个context”，后续cuModuleLoad、cuMemAlloc等据此选择资源所属环境。context可理解为驱动管理的CUDA资源账本，关联设备、分配的GPU内存、已加载模块及函数、stream/event等对象和配置；这是功能层面的理解，不代表这些内容都作为可见字段放在一块结构体里。primary context属于进程内的设备，多个CPU线程可以使用同一个context，各线程的current绑定分别管理；不是每个CPU线程必须新建一份context。[官方context管理](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-driver-api/group__CUDA__CTX.html)。

`previous`与`context`是两个host局部变量，里面只存句柄值。打印`&context`看到变量本身所在位置，打印`context`看到其保存的句柄；不透明句柄不能解引用查看内部资源或当作GPU数组读取。当前源码已加入`print_context_probe()`，查询并打印OS线程TID、两个句柄、线程current、设备和primary active/flags。普通运行实测：retain前全空且active0；retain后context非空、current仍空、active1；set后current等于context且设备为0；restore后current空但active仍1；release后active0，代码另行将局部context清空。`previous`本次一直为空，表示进入这段前该线程未绑定context，不表示没有显卡。

打印的地址/TID每次可能变化，句柄不是完整GPU状态快照，也不编码资源列表。`primary_active`是context是否活跃，不能作为GPU忙碌率或kernel是否在运行的证据；flags是配置位，不表示内存用量或任务数。本次primary_flags=0x0、current_flags=0x8来自各自查询的原始返回，未据差异推导内部实现。探针只演示当前单CPU线程的绑定变化，不新增多线程或新context实验。用户明确表示此前仍不理解，保留为实际理解难点，不能把Codex输出等同独立掌握。

本页末尾的“2026-11-11 Ch18”总结整理本章后续实际提问，包括输出参数与args输入参数的区别、launch配置、context资源归属/隐式选择、previous恢复、跨context数据和module生命周期。实现与工具验证由Codex完成，讨论和探针输出不替代个人独立验收。

## Ch19 阅读入口（2026-11-11）

[内存复用讲义](chapters/19_memory_reuse.md) 从“连续32轮加法是否需要重复申请三块相同大小的空间”开始。复用就是保留已经申请的空间，下一轮把新数据写进去再计算；不是复用旧答案，也不会自动减少传输或kernel数量。先沿第3轮host片段→device数组→线程3→回读片段理解数据流，再定位循环外准备与循环后释放。

`CH19/memory_reuse.cu` 原有一处 `prepare_reuse_buffers()` 练习，2026-11-17 已按用户要求由Codex补全：调用 `allocate_buffers(b, calls)` 准备循环共用的三个数组，然后返回true。`run_batch()` 在循环前调用它，全部32轮完成后才统一释放。骨架提供基线、逐轮传输/等待、全部32轮校验、调用计数及计时；原来复用未完成时的NOT RUN提示仅为历史状态。分配空间的生命周期是从成功分配到释放，指针变量本身的作用域不能代替这段有效期；每轮等待和回读后才覆盖或释放，不能使用已释放地址。

阅读时分清循环内malloc/free为96/96与0/0，而完整批次为96/96与3/3；“循环内无分配”不表示整个程序不需要显存。host_loop包含传输、初始化、提交与等待，host_lifecycle还包括复用的准备/清理，Event只覆盖每轮kernel的队列区间。正式骨架、隔离补全预检与个人独立验收分开，实测证据见讲义和RECORD。自测：沿代码解释何时能复用地址，为什么分配调用减少但32次kernel和每轮输入更新都保留。本段为阅读指引，未记录用户已掌握或编造用户提问。

用户实际询问过 `run_batch()` 整段流程：它在CPU上安排32轮任务，用step×1000选择每轮host片段；复用时device地址保留，新输入仍逐轮上传。`before_loop`复制进入循环时的调用计数，相减得到循环内增量；t0→t1只包循环，life0→life1还包循环外准备和释放。函数返回true只说明该批流程执行成功，数值和计数另由validate验收。正式实现及工具验证由Codex完成，个人运行与完整独立解释待验收。

<span style="color:red">用户提问：event_sum_us每次累加的是单线程时间还是一次kernel全部执行完成的时间？为什么两种分配方案的Event时间不同？要求用NSYS采集解释三个时间与实验原理。</span>

每轮累加的是start→stop Event区间，已由毫秒转成微秒；stop排在本次kernel后，覆盖所有block执行完成，不是单线程耗时或线程耗时之和，也不是kernel内新增了一次全体线程barrier。Event区间内可能有kernel前后的空档，因此不能把event_sum直接当作32个kernel色块耗时之和。两种方案都从device全局内存读同样数据，变量是分配生命周期；分配和传输在当前Event区间之外，不能把malloc/free本身直接加进Event差值。

本次NSYS第二轮GPU区间实际为：per_step前空档3.200μs、kernel2.432μs、后空档7.936μs，设备标记跨度13.568μs；reuse分别3.072/1.599/4.064μs，跨度8.735μs。全部逐轮Event窗口均无显式memcpy/memset，空档不能说成H2D。CPU侧反复分配路径循环内malloc/free各96次，而复用只在完整生命周期各3次；host_loop看循环，host_lifecycle还看循环外准备/清理。实测与图见 [NSYS讲义小节](chapters/19_memory_reuse.md#nsys三个时间为什么不同2026-11-17)。图从SQLite端点重绘，非GUI截图。

设备Event标记间隔与Event API读数存在不一致，保留原值，不跨CPU/GPU轨迹强行对齐，也不声称精确定位每一段等待的内部原因；频率/cache/TLB影响未量化。三个计时不能相加，采集时的读数不能充当普通bench；NSYS已观察kernel与Event窗口的区别，不能把Codex采集、解释或用户提出问题直接记为用户掌握。

2026-11-18用户进一步指出仍未解释“为什么两方案的间隔不同”，并提出换地址访存的假设。补充对照表明：反复分配时a虚拟地址可以始终相同；同样每轮malloc/free，仅另保留一组不用空间，就能显著改变CPU分配和提交API耗时。它把影响因素缩小到分配驻留状态与Runtime/Driver提交路径，而不是简单的“新地址必然取数慢”。Graph一次提交start/kernel/stop也改变Event窗口。虚拟地址相同不证明物理映射/cache完全相同，NSYS也未揭示驱动内部慢路径；原始某次差距的唯一根因仍未确定，不能把可能的提交节奏当成确定归因。对照与限制见 [进一步诊断](chapters/19_memory_reuse.md#进一步区分地址分配状态与提交方式2026-11-18)，未增加个人掌握记录。

用户随后已正确复述“复用可以节省反复申请释放的开销，Event时间不必有巨大差别”。本页末尾的 [Ch19总结](#2026-11-18-ch19内存复用分配生命周期与计时边界) 汇总本章实际问题、核心概念、实测边界与自测；这是一项核心理解证据，个人运行和完整独立解释仍待验收。

## Ch20 阅读入口（2026-11-18，首轮后选修）

[异步分配与内存池讲义](chapters/20_async_pool.md)承接Ch19。仍做32轮、每轮1000项vector_add，两条路径都每轮申请并释放三个数组，比较普通cudaMalloc/cudaFree与同stream的cudaMallocAsync/cudaFreeAsync。[CH20/async_pool.cu](../CH20/async_pool.cu)的申请和释放两处练习已于2026-11-18按用户要求由Codex补全。沿main→run_batch→enqueue_work阅读，再看两个分配/释放helper，个人运行和独立解释待验收。

先把异步分配理解为“申请、访问、释放也按队列顺序安排”。同stream内先申请，再H2D→memset→kernel→D2H，最后释放，run_batch每轮等待完成；地址写回host变量不等于GPU操作已经完成，freeAsync返回后不能再提交使用旧地址的新工作。两条路径每批API仍各申请96次、释放96次，不能照搬Ch19循环外持有空间时的3/3或循环内0/0。

沿`a`看参数的读写方向。`cudaMallocAsync(&b.a, kBytes, stream)`把显存地址写进CPU上的`b.a`，`cudaFreeAsync(b.a, stream)`则读取当时保存在`b.a`里的地址并提交释放。随后将`b.a`清空只改变CPU变量。用户也问到`cudaDeviceGetAttribute(&supported, cudaDevAttrMemoryPoolsSupported, 0)`。`CUDA_CHECK`检查查询调用是否成功，`supported`是写回的能力值，`1`表示支持，`0`表示不支持。配置pool时，`GetAttribute`向`old_threshold`写入旧值，`SetAttribute`从`threshold`读取新值，退出前再用保存的旧值恢复设置。

pool是CUDA管理的空间储备。used表示应用正在使用的分配，reserved表示池保留的底层储备，释放后可能used为0而reserved非0；它不表示旧地址仍可访问。固定release threshold允许同步后保留空闲储备，但它不是容量上限或预分配量，也不保证任何环境都出现同样的保留值。先看本次实际输出；本机教学预检中8MiB低于观察到的32MiB储备，因此正式材料固定64MiB，成功批次释放同步后实际used=0、reserved=32MiB，trim后均为0；不把该32MiB推广成跨设备常数。host批次时间包括32轮分配、拷贝、kernel提交、释放和完成等待，不等于kernel时间或底层纯分配耗时。准确语义已核对[CUDA12.9.1内存池文档](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-runtime-api/group__CUDART__MEMORY__POOLS.html)，计数和验证证据由RECORD维护，不用预检结果认定个人掌握。

本页末尾的 Ch20 总结集中整理了本章追问，包括每轮仍同步为什么更快、普通API能否使用池、如何看4个池统计观测点、32MiB是在哪一层出现的，以及本机两次正式bench与NSYS证据各回答什么问题。

## 首轮贯穿的观察问题

| 观察问题 | 将使用的程序证据 |
| --- | --- |
| CPU 与 GPU 分别做了什么？ | vector add 的拷贝、launch、回读及 NSYS timeline |
| 为什么需要线程分组与合作？ | 索引覆盖、warp 分支、shared 交换、归约 |
| 为什么访问和复用方式会影响效率？ | 连续/跨步、shared padding、分块 GEMM 对照 |
| 为什么资源更多不一定更快？ | block shared 用量、驻留数量与实际计时 |
| 为什么提交完成不等于计算完成？ | CPU timer、Event、stream 依赖、Graph 对照 |
| 框架下方的执行链是什么？ | 同一 kernel 的源码、cubin、Runtime/Driver 启动和内存复用 |

这些是待学习的问题，不是已完成的学习成果。每节结束只保留实际讲解且用户接触过的核心内容；有解释但没有独立练习时如实注明。

## 后续记录规则

采用 `## YYYY-MM-DD ChXX：主题`，依次记录“今日完成任务、基本概念、踩坑记录、八股自测”。任务说明用户实际写了什么、使用了多少骨架或完整答案；基本概念联系代码，重要结论用 `<mark>...</mark>`；问题与误解只记录用户实际提出的内容，不编造学习经历。用户主动问题使用：

```html
<span style="color:red">用户提问：原问题或忠实摘要</span>
```

自测围绕本章一两个关键问题，不拓展为面试题库。实验数据引用 DOCS 中的章节记录与报告路径，不重复维护进度或工程日志。

## 2026-09-20 Ch00：设备查询程序

### 今日完成任务

<span style="color:red">用户提问：device_probe.cu 的作用和实现的功能。</span>

已讲解程序的执行顺序与辅助函数。用户随后要求直接完成作业，Codex 提供完整实现并编译运行；无用户独立代码修改或个人解释证据。运行数据见 [章节记录](chapters/00_environment.md)。

### 基本概念

<mark>程序在 CPU 上调用 CUDA API 查询设备属性，本章没有启动计算 kernel。</mark> `cudaGetDeviceProperties(&prop, device)` 把指定设备的信息填入 `prop`；返回值表示调用是否成功，输出参数承载查到的数据。`check_cuda` 检查返回值，失败时输出原因并退出。

`prop.multiProcessorCount` 是 SM 数量，`prop.warpSize` 是每个 warp 的线程数。SM 是安排线程执行的计算单元，warp 是共同执行指令的一组线程。总显存不等于当前空闲显存，资源上限不代表最佳配置。

<mark>GPU 计算能力、Toolkit 版本、驱动支持的 CUDA 版本是不同概念。</mark> `print_version` 把整数版本拆为主次版本；例如 12090 对应 12.9。程序末尾的提示只证明属性已输出，不能代替用户解释验收。

GPU 是计算硬件，Driver 让软件能够使用 GPU，Toolkit 提供 nvcc、头文件和库。程序流程是“查询版本 → 查询可见设备数量 → 逐个填充 cudaDeviceProp → 打印属性”。本次完整作业实测 GTX 1650、计算能力 7.5、4.00 GiB、14 个 SM、warp 32 线程；Toolkit 12.9 与驱动支持 CUDA 13.3 可以同时出现。数值引用章节验证记录，本次总结没有重新测量。

<span style="color:red">用户提问：修改后的 cu 文件如何编译，如何运行可执行文件？</span>

<mark>保存源码 → nvcc 编译 → 运行可执行文件；每次修改源码后都需重新编译。</mark> 在项目根目录执行：

```bash
mkdir -p build/CH00
nvcc -std=c++17 -arch=sm_75 CH00/device_probe.cu -o build/CH00/device_probe && ./build/CH00/device_probe
```

`-o` 指定输出文件，`-arch=sm_75` 指定本机课程目标架构，`&&` 确保编译成功后才运行，避免编译失败时误跑旧程序。

### 踩坑记录

未收到用户运行错误或具体误解；不据此推定已掌握。

### 八股自测

为什么这份 `.cu` 程序不需要自己写 GPU kernel？`cudaGetDeviceProperties` 的返回值与 `prop` 各承载什么信息？待用户自行解释。

## 2026-09-20 Ch01：第一个计算 kernel

### 今日完成任务

用户要求生成 Ch01 内容，随后明确要求“解题并编译”。Codex 提供并补全 [vector_add.cu](../CH01/vector_add.cu)，完成编译和运行，用户尚未提供独立实现或个人解释。程序对两个长度为 256 的 float32 数组逐元素相加，全部元素与 CPU reference 一致，最大绝对误差为 0。结果见 [章节记录](chapters/01_first_kernel.md)，本次总结不重复运行实验。

### 基本概念

<mark>本章的核心是 CPU 准备数据、GPU 执行计算、CPU 回读并验证结果。</mark> host 指 CPU 一侧，device 指 GPU 一侧。程序中的 `h_a/h_b/h_c` 保存 CPU 数据，`d_a/d_b/d_c` 指向 GPU 分配的空间；这些前缀是命名约定。完整流程为：

```text
CPU 准备输入与参考答案
  → cudaMalloc 分配 GPU 空间
  → cudaMemcpy（H2D）拷贝输入
  → 启动 vector_add kernel
  → cudaDeviceSynchronize 等待完成
  → cudaMemcpy（D2H）回读输出
  → CPU 逐元素校验
  → cudaFree 释放 GPU 空间
```

kernel 是交给 GPU 线程执行的函数。本程序的 `main()` 和普通循环在 CPU 上运行，`__global__` 标记的 `vector_add()` 在 GPU 上运行。启动代码 `vector_add<<<1, n>>>(d_a, d_b, d_c)` 使用一个 block、256 个线程；block 先理解成一组线程。传入的是 GPU 数组指针，与本程序显式分配和拷贝的方式对应。

```cpp
__global__ void vector_add(const float* a, const float* b, float* c) {
    const int i = threadIdx.x;
    c[i] = a[i] + b[i];
}
```

<mark>每个线程执行同一段代码，通过不同的编号处理不同元素。</mark> `threadIdx.x` 是线程在当前 block 内的 x 方向编号，本章为 0～255。线程 3 计算 `a[3] + b[3] = 1.5 + 1.75`，写入 `c[3] = 3.25`。无需在 kernel 中写一个遍历全部元素的循环；也不能由此推定 256 个线程物理上同时执行。

当前索引只适用于本章固定的一个 block、256 个元素与 256 个线程配置。多个 block 的索引及越界保护留到 Ch02，不直接增大启动规模套用这份代码。

`cudaMalloc` 和 `cudaMemcpy` 的大小参数以字节计，256 个 float 对应 1024 字节。`cudaMemcpy` 的参数顺序为目标、来源、字节数、方向。本程序通过 `cudaDeviceSynchronize` 显式等待计算结束，再回读结果；提交 kernel 不等于计算已经完成，详细异步机制留到后续。

<mark>运行不报错还不够，要把 GPU 结果与 CPU 参考答案逐元素比较。</mark> 本程序检查全部 256 项，前四项打印仅用于观察，容限为 `1e-6`，NaN/Inf 也判失败。此次 PASS 证明当前输入的计算正确；没有计时，不能据此判断 GPU 比 CPU 快。

修改源码后需重新编译。在项目根目录执行：

```bash
mkdir -p build/CH01
nvcc -std=c++17 -arch=sm_75 -Xcompiler=-Wall,-Wextra CH01/vector_add.cu -o build/CH01/vector_add && ./build/CH01/vector_add
```

### 踩坑记录

未收到用户运行错误或具体误解。教学预检中的原始骨架把输出写为零，因此校验 FAIL，是预设的未完成练习状态；随后补全计算后 PASS，不属于环境故障，也不记为用户犯错。

### 八股自测

从 CPU 准备输入到 CPU 验证输出，数据经过哪些步骤，哪个函数在 GPU 上执行？同一段 kernel 代码如何让线程 3 与线程 4 分别处理不同元素？待用户用自己的话解释。

## 2026-09-21 Ch02：线程索引与越界保护

### 今日完成任务

用户要求生成本章并随后要求“完成今日作业”，Codex 补全 [thread_index.cu](../CH02/thread_index.cu) 的全局索引和边界判断，完成编译、数值校验与内存检查。使用 8 个 block、每 block 128 个线程，对 1000 项 float32 输入逐元素相加。正式程序全部通过，最大绝对误差 0，memcheck 零错误；证据见 [章节记录](chapters/02_thread_index.md) 与 `reports/CH02/completed.txt`。本次总结引用已有结果，没有重新运行；尚无用户独立实现或个人解释证据。

### 基本概念

<mark>本章解决两个问题：每个线程负责哪一项，以及多出的线程如何避免越界。</mark> Ch01 只有一个 block，组内编号即可对应数组索引；Ch02 有多个 block，每组的线程编号都会从零开始，所以还需加上该组在整个数组中的起点。

block 是一组线程，grid 是一次启动中的全部 block。`vector_add<<<8, 128>>>(...)` 表示启动 8 组、每组 128 个线程；这不表示 1024 个线程物理上同时执行，也不表示组号就是 SM 编号。

| 标识 | 直觉含义 | 本章取值 |
| --- | --- | --- |
| `blockIdx.x` | 当前组号 | 0～7 |
| `blockDim.x` | 每组线程数 | 128 |
| `threadIdx.x` | 当前线程的组内编号 | 0～127 |

<mark>全局索引 = 组号 × 每组线程数 + 组内编号。</mark> 核心代码为：

```cpp
const int i = blockIdx.x * blockDim.x + threadIdx.x;
if (i < n) {
    c[i] = a[i] + b[i];
}
```

例如 block 1 的线程 3 处理 `1 * 128 + 3 = 131` 号元素。只写 `threadIdx.x` 会让每组都访问前 128 项，产生重复写入，其余元素没有线程负责。

host 使用 `(n + threads_per_block - 1) / threads_per_block` 向上取整计算组数。本章 `1000 / 128` 的整数结果是 7，但 7 组只能覆盖 896 项，所以要启动 8 组，共 1024 个线程。最后一组覆盖索引 896～1023，其中 896～999 是 104 个有效元素，1000～1023 对应 24 个多余线程。

<mark>保护条件必须放在所有数组读取和写入之前。</mark> block 7 的线程 103 得到索引 999，可以执行加法；线程 104 得到索引 1000，不满足 `i < n`，跳过整个加法语句。不能先读取 `a[i]` 再判断，也不能把“不崩溃”当作没有越界的证明。

CPU 准备输入、H2D 拷贝、启动 kernel、等待、D2H 回读与全量校验沿用 Ch01。本次通过证明当前输入的正确性，没有计时，不能据此比较 CPU/GPU 速度。修改源码后仍需重新编译：

```bash
mkdir -p build/CH02
nvcc -std=c++17 -arch=sm_75 -lineinfo -Xcompiler=-Wall,-Wextra CH02/thread_index.cu -o build/CH02/thread_index && ./build/CH02/thread_index
```

### 追问复盘（2026-09-22 整理）

<span style="color:red">用户提问：所有 blocks 是同时启动的吗？</span>

<mark>一次 kernel 调用提交整个 grid，但不保证所有 block 同时开始执行，也不保证按组号执行。</mark> SM 是 GPU 上执行线程组的计算单元；GPU 根据可用资源安排 block，一个 SM 在资源允许时可以容纳多个 block，未能驻留的 block 等待资源。block 编号不是 SM 编号。本章各线程独立处理自己的元素，不依赖 block 的执行先后。未采集本章 block 调度证据，不能根据启动配置、SM 数量或 PASS 推断实际同时开始。

<span style="color:red">用户提问：为什么只用 threadIdx.x 不够？为什么需要 8 组，却只有 1000 个线程执行加法？</span>

每组的 `threadIdx.x` 都是 0～127，单独使用它会让 8 组重复访问前 128 项；加上 `blockIdx.x * blockDim.x` 才能区分各组负责的区间。7 组只有 896 个线程，覆盖不足，故向上取整到 8 组。<mark>1024 个线程都被启动；从源码逻辑看，它们计算索引并判断条件，只有 1000 个有效线程执行数组相加。</mark> 其余 24 个线程跳过加法和数组访问，不是没有启动。这里解释的是程序逻辑，未检查编译后的机器指令。

### 踩坑记录

用户已就 block 是否同时启动及索引、尾部线程行为提问，已作上述解释；尚无用户自行复述，不据此认定掌握。未收到用户实际运行错误。初始骨架的 `i = n` 和 `if (false)` 刻意跳过计算，数值 FAIL 是预设的未完成状态；完整实现已通过验证，不记为用户犯错。

### 八股自测

为什么多个 block 时只使用 `threadIdx.x` 不够？N=1000、每 block 128 线程时，为什么需要 8 个 block，最后一组哪些线程应跳过数组访问？待用户自行解释。

## 2026-09-22 Ch03：CUDA 错误检查与 Sanitizer 定位

### 今日完成任务

围绕 [error_check.cu](../CH03/error_check.cu) 阅读 host 检查与三种实验模式。用户在 Codex 讲解和代码示例辅助下修改检查宏及两处检查点，并贴出非法启动、memcheck 越界的终端输出。现场源码已使用 `#call` 和两处 `CUDA_CHECK`，故意越界写入仍保留；尚无修复后用户运行结果或个人复述，不记为完全独立实现。实验依据及待办见 [RECORD](RECORD.md) 的同日 Ch03 条目。

### 基本概念

<span style="color:red">用户提问：为什么 include 这些头文件？check_cuda 如何实现？call 到底怎么理解？</span>

`#include` 引入函数和类型等声明或定义。`cuda_runtime.h` 提供 CUDA 接口；`algorithm` 用于 `std::max`；`cmath` 用于绝对误差和有限值检查；`cstdio` 用于打印与刷新输出；`cstdlib` 用于退出程序；`cstring` 用于比较模式字符串；`vector` 保存 CPU 端数组。

`check_cuda` 在 CPU 上检查传入的 `cudaError_t`：成功则返回，失败则打印调用、文件、行号和错误文字，随后 `std::exit(EXIT_FAILURE)` 结束程序。它不会自动等待 GPU，能检查什么由传入 API 的返回值决定。

```cpp
#define CUDA_CHECK(call) check_cuda((call), #call, __FILE__, __LINE__)
```

<mark>`call` 是宏参数名，代表传入的代码；`(call)` 执行该调用，`#call` 将同一段代码转换为报错用的字符串。</mark> 例如传入 `cudaMalloc(&d_a, bytes)`，实际调用只求值一次，字符串不执行。`__FILE__` 和 `__LINE__` 标记宏调用位置。`cudaGetErrorName(status)` 将状态码转为名称，`cudaGetErrorString(status)` 给出英文说明，最终由 `fprintf` 拼接打印。

<span style="color:red">用户提问：模式选择、设备属性查询和结果输出各在做什么？</span>

`argc` 包含程序名，`argv[1]` 是用户传入的模式；不传时默认 `ok`，`strcmp` 返回 0 表示相等。`ok` 用 256 个线程处理 256 项；`launch` 将 block 线程数设为设备上限加 1；`oob` 在正常计算之外额外写 `c[n]`。`fflush(stdout)` 刷新 CPU 输出，不等待 GPU。程序校验全部 256 项，前四项打印仅便于观察，末尾 `cudaFree` 释放 GPU 数组。

<mark>启动检查通过不代表执行完成；数值校验通过也不代表没有越界。</mark> `cudaGetLastError()` 读取并清除当前 host 线程对应 Runtime 的最后错误记录，不等待 GPU，且可能报告之前异步调用的错误；`cudaDeviceSynchronize()` 等待 GPU 并检查返回值。报错所在 API 是发现错误的检查点，未必是故障源头。参考 [CUDA Runtime API 12.9：Error Handling](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART__ERROR.html)。

<span style="color:red">用户提问：Compute Sanitizer 做什么，命令参数是什么意思，与 nsys 有什么区别，还有哪些工具？</span>

```bash
compute-sanitizer --tool memcheck --padding 32 --error-exitcode 99 ./build/CH03/error_check oob
```

该命令在工具监测下运行程序的 `oob` 模式。`--tool memcheck` 选择内存检查；`--padding 32` 为分配添加 32 字节保护间隔，这些字节不属于程序可合法使用的空间；`--error-exitcode 99` 让应用成功退出但工具发现错误的情况也以非零码返回。`99` 是此命令指定的退出码，不是报告中 CUDA 错误码 `999`。

| 工具 | 本轮需要知道的检查范围 |
| --- | --- |
| `memcheck` | 越界、未对齐访问等；泄漏检查需按选项启用 |
| `racecheck` | shared memory 数据访问冲突，不是通用 global memory 竞争检测器 |
| `initcheck` | GPU global memory 未初始化读取 |
| `synccheck` | 同步原语的非法使用 |

一次 `--tool` 选择一种检查，不会自动运行全部工具。<mark>Compute Sanitizer 查执行正确性，Nsight Systems 查时间花在哪里以及 CPU/GPU 如何配合。</mark> nsys 可观察 API、kernel、拷贝时间线与重叠，不能替代逐次访存合法性检查；Sanitizer 有运行开销，不用其运行耗时衡量性能。零错误仅覆盖本次执行和所选工具的检查范围，算法结果仍需 reference 校验。工具边界参考 [Compute Sanitizer](https://docs.nvidia.com/compute-sanitizer/ComputeSanitizer/index.html) 与 [Nsight Systems](https://docs.nvidia.com/nsight-systems/UserGuide/index.html)，本日未实际运行其余三种检查或 nsys。

### 踩坑记录

<span style="color:red">用户提问：cudaErrorInvalidConfiguration 从哪里来？越界报告如何帮助定位？</span>

用户贴出的 `launch` 输出为 block=1025、设备上限=1024。非法配置导致 Runtime 记录错误，`cudaGetLastError()` 取出状态码，检查函数打印 `cudaErrorInvalidConfiguration (invalid configuration argument)`；不是第 77 行检查函数自己制造了错误。

用户贴出的 memcheck 报告指向 `error_check.cu:33`、block 0 的线程 0、4 字节 global 写入，对应 `c[256] = 123.0f`。数组只有 256 个 float，共 1024 字节，合法下标为 0～255。访问地址 `0x603401000` 正好等于起点 `0x603400c00 + 0x400`；“1 bytes after”指访问起点位于最后合法字节之后，不代表只写了 1 字节。

后续 `cudaDeviceSynchronize()` 报 `cudaErrorUnknown (999)`，此次 `ERROR SUMMARY: 2 errors` 对应非法写入及随后 API 报错，不证明有两处独立越界。<mark>先读第一条具体错误，再找源码行、线程和地址范围；修复根因后重新编译、重新检查。</mark> 这是预设故障实验，不记为用户无意写错，也不能将本次错误名称推广为所有越界的固定返回值。

### 八股自测

`CUDA_CHECK(cudaMalloc(...))` 中调用文字、实际返回值和源码位置分别从哪里来？为什么 launch 检查通过后，memcheck 仍能报告越界，且同步处可能再次报错？待用户用自己的话解释。

## 2026-10-08 Ch05：NSYS 采集与 CPU/GPU 时间线

### 今日完成任务

使用独立的 [CH05/vector_add.cu](../CH05/vector_add.cu)，固定 N=1000、float32、grid=8、block=128。源码由 Codex 从 Ch02 复制并提供，本章用户练习为采集、读图与源码对应，没有新增 kernel 实现要求。

用户生成 `user_20261008_01.nsys-rep` 和 `user_20261008_02.nsys-rep`，在 Windows Nsight Systems 2026.4.1 中打开新版报告、展开 CPU/GPU 轨道、显示 Events View、放大时间轴并提供截图。Codex 检查用户 `_02` 报告，验证 1 次 vector_add、2 次 H2D、1 次 D2H 和 1 次 memset，辅助解释启动名称、拷贝方向和时间边界。证据为 [用户报告](../reports/CH05/user_20261008_02.nsys-rep) 与 [同名 SQLite](../reports/CH05/user_20261008_02.sqlite)，工程验证与剩余验收见 [RECORD](RECORD.md)。用户已实际采集和操作 GUI；主动提问与接受讲解不等于独立解释验收。

### 基本概念

<mark>NSYS 把 CPU 的接口调用与 GPU 的计算、数据搬运放在同一时间轴上，帮助对应源码与实际活动。</mark> 本程序的数据流为：

```text
CPU 准备输入和参考答案 → 分配 GPU 数组
  → H2D(a) → H2D(b) → memset(c) → vector_add
  → 等待 GPU 完成 → D2H(c) → CPU 校验 → 释放
```

<span style="color:red">用户提问：这两个编译与采集指令分别是什么意思？</span>

保存源码后重新编译，在根目录执行；先普通运行确认 PASS，再采集。本次使用的命令如下，重复采集时更换报告前缀，保留原证据：

```bash
mkdir -p build/CH05 reports/CH05
nvcc -std=c++17 -O2 -arch=sm_75 -lineinfo \
  -Xcompiler=-Wall,-Wextra CH05/vector_add.cu -o build/CH05/vector_add \
  && ./build/CH05/vector_add

/home/yhc23/.local/bin/nsys profile \
  --trace=cuda --sample=none --cpuctxsw=none \
  -o reports/CH05/user_20261008_02 ./build/CH05/vector_add
```

`nvcc` 编译 CUDA C++；`-std=c++17` 指定语言标准，`-O2` 开启优化，`-arch=sm_75` 指定课程目标 GPU 架构，`-lineinfo` 保留源码行号，`-Xcompiler=-Wall,-Wextra` 开启 host 编译警告，`-o` 指定二进制路径，`&&` 保证编译成功才运行。行末单个 `\` 表示续行。

`nsys profile` 在工具监测下启动程序；`--trace=cuda` 记录 CUDA API 与 GPU 活动，`--sample=none`、`--cpuctxsw=none` 关闭 CPU 指令位置采样和调度追踪，仍保留 CUDA API；`-o` 指定报告前缀，产物为 `.nsys-rep`。

<span style="color:red">用户提问：时间轴每一行代表什么？CUDA HW 是 GPU，Threads 是 CPU 吗？</span>

| 轨道 | 本例的含义 |
| --- | --- |
| `CUDA HW → Kernels → vector_add` | GPU 上执行加法的活动，不逐个展示 GPU 线程 |
| `CUDA HW → Memory` | GPU 的拷贝与清零活动 |
| `HtoD memcpy` / `DtoH memcpy` | CPU→GPU 输入 / GPU→CPU 输出 |
| `Threads → [6664] vector_add → CUDA API` | CPU 线程 6664 调用 CUDA API；此处 vector_add 是程序/线程名称 |
| `CUDA Overhead` / `Profiler overhead` | CUDA 额外工作（例如加载）/ 工具自身的工作 |

父级行汇总子行，同一活动可在不同层级重复显示，不算额外操作。横向位置表示发生时间，横向宽度表示持续时间，行的位置区分执行方与活动类别；1000 ns = 1 μs。本例 `Kernels 22.4%` 与 `Memory 77.6%` 是 GPU 已记录活动时间的分类比例，子级百分比使用相应分组范围；不能当成整个程序的 GPU 利用率。

<span style="color:red">用户提问：为什么只看到很少几个环节，是不是要缩放才能看到所有 API？cudaLaunchKernel 为什么没找到？</span>

程序只做一次小型加法，微秒级活动在秒级全局视图中像细线。先核对活动标签确实为 `_02`，在 `CUDA API` 行右键选择 `Show in Events View`，列出当前可见时间范围内的事件，再定位并放大目标区域。右上角 `1x` 滑块调整轨道高度，横向时间缩放另有操作，可通过键盘图标查看帮助。列表适合逐项查调用，时间线适合看顺序与时间关系；采集范围不会因放大而增加。

<mark>GUI 的 CPU 启动事件也可能显示 kernel 名称，需要结合轨道判断。</mark> 用户截图中 API 列表第 8 行 `vector_add(...)` 的 450.575 μs，对应 CLI 的 `cudaLaunchKernel` 和源码第 56 行；GPU kernel 轨道中的同名事件为 2.176 μs，对应源码第 20 行的函数执行。两者关联编号均为 124。前者包含启动及此次显示的模块/函数加载工作，后者为 GPU 执行活动；不将两个耗时当成同一测量。

<span style="color:red">用户提问：两个 cudaMemcpy 怎样区分 HtoD/DtoH？要先了解源码吗？A、B 都是输入，为什么一个长、一个短？</span>

方向先看 GPU 的 `HtoD memcpy`、`DtoH memcpy` 行，再选中 CPU API，通过关联高亮或 Correlation ID 对应 GPU 事件。报告说明方向和大小，源码说明是哪一个变量：第 51 行拷贝 A、第 52 行拷贝 B、第 60 行回读 C。源码与报告互相核对，不凭 CPU 行中通用的 `cudaMemcpy` 名称或颜色猜方向。

| 数据 | 方向 | Correlation ID | 字节数 | CPU API 耗时 | GPU 拷贝耗时 |
| --- | --- | --- | --- | --- | --- |
| A | HtoD | 121 | 4000 | 454.982 μs | 2.208 μs |
| B | HtoD | 122 | 4000 | 57.448 μs | 1.344 μs |
| C | DtoH | 127 | 4000 | 73.237 μs | 2.656 μs |

数值来自本日已核查的用户 `_02` 报告，本次总结未重测。<mark>CPU API 耗时包含接口内的准备、提交、可能的等待等工作；GPU 拷贝时长记录传输活动，两者边界不同。</mark> 普通 CPU 内存到 GPU 的传输可能经过中转；首次准备、内部资源和工具开销可能影响调用时长。该报告没有逐项拆分这些原因，不能确定第一次较慢的单一原因，也不能用一次采集宣称固定带宽或优化效果。

<span style="color:red">用户提问：CPU 发起后，要等 CPU 进程结束 GPU 才动吗？绿色条有长有短表示什么？</span>

<mark>API 返回、GPU 工作完成、CPU 进程退出是不同时间点；CPU/GPU 可以在同一时间段做不同工作。</mark> 本例第一次 GPU HtoD 的时间区间与 CPU 第二次 cudaMemcpy 调用重叠，可由两层的起止时间确认。CPU 仍会继续提交计算、等待、回读和校验。绿色 GPU HtoD 条的宽度表示拷贝时长，不直接表示数据量；本例 A/B 字节数相同，实际时长仍不同。颜色解释必须结合轨道和事件信息，不泛化成所有绿色均是同一种操作。

图形操作与关联规则参考 [Nsight Systems User Guide](https://docs.nvidia.com/nsight-systems/UserGuide/index.html#reading-your-report-in-gui)；CPU 拷贝调用语义参考 [CUDA Runtime API 12.9：API synchronization behavior](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/api-sync-behavior.html)。本章停留在识别与解释三类轨迹，异步细节和多 stream 继续按 PLAN 后续章节学习。

### 踩坑记录

用户第一次尝试在 WSL 启动 GUI 出现 OpenGL/ZINK/EGL 报错，本机 GUI 入口是旧版 2025.1.3，CLI 新版为 2026.4.1。原 `_01` 报告有 CPU API，却缺少 GPU 数据，诊断含旧版采集对当前驱动不支持的警告。不能把“报告生成了”当成数据齐全。后续用户 `_02` 数据完整，并在 Windows 2026.4.1 GUI 提供可读截图；以新版报告作为本章读图证据。

读图中实际遇到的疑问已在上面保留：旧报告标签未切换、短事件被全局缩放压成细线、API 启动事件显示 kernel 名称、误把 CPU API 条长当成 GPU 搬运时长、认为 GPU 要等 CPU 进程结束。这些问题已讲解，仍需个人复述，不据主动提问自动认定掌握。

### 八股自测

拿自己的 `_02` 报告说明：CPU 的 vector_add 启动事件与 GPU 的 vector_add 执行事件如何区分、怎样对应源码？两个相同大小的输入拷贝为什么不能只比较 CPU 红色条就判断 GPU 搬运速度，哪个时间区间说明 CPU 与 GPU 可以重叠工作？待用户用自己的话解释。

## 2026-10-20 Ch06：warp 分组、分支分歧与实验观察

### 今日完成任务

本条为本章汇总，覆盖 10 月 8 日内容准备、10 月 14 日编号练习及后续代码讲解、10 月 20 日分路补全与观察，不把跨日会话间隔当成学习用时。源码为 [CH06/warp_branch.cu](../CH06/warp_branch.cu)，完整操作与历史验证见 [章节讲义](chapters/06_warp_execution.md)，进度、辅助程度及验收只在 [RECORD](RECORD.md) 维护。

框架、TODO 1 的 lane/warp 计算、TODO 2 的分路条件均由 Codex 按用户要求实现并验证。用户逐段阅读和提问，并实际用 NCU GUI 打开 `ncu-divergence-2026-10-20.ncu-rep`，提供左侧 CUDA Source、右侧 SASS 及分歧/线程参与指标的截图。源码与指令的对应已有用户操作证据；没有将 Codex 编译、采集或用户提问写成用户独立实现与完整解释验收。

### 基本概念

<span style="color:red">用户提问：Ch06 主要讲什么，程序的组织结构怎样，为什么比前章多了很多函数？</span>

<mark>本章主要观察：相同的 A/B 总工作量，放在同一 warp 内分路，或让不同 warp 分别走完整路径，执行情况可能不同。</mark> warp 是 GPU 调度的一组 32 个线程，lane 是线程在组内的位置。这里使用一维 block，连续的 32 个 block 内线程编号组成一个 warp；不能据此认为所有 GPU 线程在每个时刻严格同步。

```cpp
const int t = threadIdx.x;
const int lane = t % warpSize;
const int warp_in_block = t / warpSize;
```

线程 31 是 warp 0、lane 31；线程 32 是 warp 1、lane 0；线程 63 是 warp 1、lane 31。`warp_in_block` 在每个 block 中重新从 0 编号，不是 SM 编号。数组访问则用全局下标 `i = blockIdx.x * blockDim.x + threadIdx.x`，不要将 lane、block 内编号和全局下标混为一谈。

程序分工围绕实验流程展开：

```text
CPU main：选择模式、查询设备、返回成功或失败
  ├─ probe → run_probe → GPU probe_warps → 回读并校验 64 项编号
  ├─ check → run_branch(false) → 两种分路模式各运行一次并校验
  └─ bench → run_branch(true) → 校验、预热、重复计时、输出中位数

GPU branch_work：读 input[i] → choose_path_a → path_a 或 path_b → 写 output[i]
```

`make_reference` 在 CPU 生成两套正确答案，`mismatches` 统计错误元素，`median` 取计时中位数。`run_branch` 内的 `launch`、`validate` 是 lambda，即当前函数内部起名的小函数，`[&]` 允许其引用外层变量；前者由 CPU 提交 kernel，后者回读并校验。函数变多是为了分开编号观察、两路计算、校验和计时，核心修改仍是编号和分路两处。

`run_probe` 先在 GPU 分配两个数组，64 个 GPU 线程各写自己的 lane/warp 编号，再回读到 CPU 的两个 vector。GPU 只打印 8 项边界值，CPU 检查全部 64 项；printf 的输出先后不证明线程执行顺序。`errors += 条件1 || 条件2` 中，只要任一编号错误就给该线程计 1 项，两个字段都错也只加 1。

<span style="color:red">用户提问：这些参数是做什么的，constexpr 是什么意思？</span>

| 参数 | 本章作用 |
| --- | --- |
| `kBlock=256` | 计时 kernel 每个 block 256 个线程，含 8 个完整 warp |
| `kN=65536` | 每线程处理一项，共 256 个 block |
| `kIterations=256` | 每个线程在所选路径中循环计算 256 次 |
| `kWarmup=10` | 每种模式正式计时前先运行 10 次 |
| `kSamples=21` | 每种模式获取 21 个样本并取中位数 |
| `kBatch=5` | 每个 Event 样本连续启动 5 次 kernel，再将整批时间除以 5 |

<mark>Iterations 是一次 kernel 内的循环次数，Batch 是一次计时内 kernel 的启动次数。</mark> `probe` 的一个 block、64 个线程独立配置，不使用计时 kernel 的 `kBlock`。`constexpr` 变量要求初始化值在编译时能确定，且初始化后不可修改；`const` 只要求初始化后不可修改，初值可以运行时才得到。变量名前的 `k` 只是常量命名习惯。

<span style="color:red">用户提问：__device__ 是什么意思，path_a 与 path_b 有什么区别？</span>

`__device__` 表示函数在 GPU 上执行，供 GPU 代码调用；本程序由 CPU 用 `<<<...>>>` 启动 `__global__` kernel，当前 GPU 线程再调用选中的 device 函数。调用 `path_a` 不会创建新线程，也不是重新提交一次 kernel。

两条路径都接收 `x`、循环 `iterations` 次、返回最终值，区别是乘加常数及右移位数不同：A 右移 13 位，B 右移 11 位。`x ^= x >> 13` 等价于 `x = x ^ (x >> 13)`，用移位和按位异或混合数值中的位。`uint32_t` 的运算按模 2^32 处理，CPU/GPU 可以精确比较结果；无需把这些常数扩展成算法学习任务。

`__noinline__` 是尽量保留独立函数调用的编译提示，不单独保证真实分支存在。两条有数据依赖的计算体用于形成不同且可校验的工作，实际控制流还需由编译产物及动态指标核对。

两种模式都包含 A、B，总人数各 32768，输入和输出地址始终按全局下标连续访问：

| 模式 | 选 A 的条件 | warp 内的安排 |
| --- | --- | --- |
| `within_warp`，mode=0 | `lane < 16` | 每个 warp 的前半组走 A、后半组走 B |
| `between_warps`，mode=1 | `warp_in_block % 2 == 0` | 偶数 warp 全走 A、奇数 warp 全走 B |

<mark>分支分歧发生在同一 warp 的线程选择不同执行路径时；不同 warp 各自选择不同路径不构成这个意义上的 warp 内分歧。</mark> 不属于当前路径的线程暂不参与相关指令。两种模式的同一下标可能走不同路径，输出无需相互相等，应各自与对应的 CPU reference 比较。编译器可能改写简单分支，本机一次结果也不能推广成所有分支固定慢几倍。

<span style="color:red">用户提问：CUDA 自己没有错误码吗，为什么需要 check_cuda，必须显式写这个函数吗？</span>

CUDA API 本身返回 `cudaError_t`，成功为 `cudaSuccess`。`check_cuda` 是项目自己的辅助函数，将判断状态、输出 API 名称/源码位置/错误说明、退出程序统一起来，并非 CUDA 必须提供的函数。可以逐次写 `if (status != cudaSuccess)` 自行处理；返回错误码不会自动替应用完成所有错误处理。当前程序选择失败时退出，不把这一处理策略当成 API 要求。

<span style="color:red">用户追问：GPU 异步执行，和 cudaGetLastError 是否等待 GPU 完成有什么关系？</span>

CPU 提交 kernel 后能够继续运行，此时 GPU 可能尚未执行到会出错的位置。`cudaGetLastError()` 读取并清除当前 host 线程的 Runtime 错误记录，不等待 GPU；它也可能读到此前异步工作留下的错误，检查点不是故障发生点的保证。

```cpp
branch_work<<<grid, block>>>(...);      // CPU 提交 GPU 工作
CUDA_CHECK(cudaGetLastError());        // 读取此刻已有的错误记录
CUDA_CHECK(cudaDeviceSynchronize());   // 等待此前设备工作完成，并检查返回状态
```

<mark>启动后的检查没有读到错误，不代表 GPU 后续执行一定成功；等待完成后再检查，才能覆盖执行结束这一时间边界。</mark> 需要精确检查越界等内存访问仍使用 Sanitizer，不能把数值 PASS 当作内存安全证明。

<span style="color:red">用户提问：给出观察两条 path 整个流程耗时差异的指令。</span>

这里的对照单位是两种线程分路安排，当前没有分别启动一个“全 A kernel”和一个“全 B kernel”。普通 `check` 先检查正确性，`bench` 通过后再预热并采集 Event 样本；起止 Event 与 kernel 在同一 stream，等待 stop 完成再读时间。两种模式成对采样并轮换先后，每批回读校验在计时区间外。

`event_batch_per_launch_median_us` 是 Event 毫秒差乘 1000、除以 5，再对每模式 21 个样本取中位数。它不含分配、H2D、D2H、CPU reference/校验和初始化，仍可能包含 CPU 提交间隙；不能冒充含传输的端到端时间或 profiler 上某一次 kernel 的 duration。

本章 10 月 20 日普通观察运行得到 within_warp=116.083205 μs、between_warps=71.097600 μs，参数为 GTX 1650、N=65536、uint32、grid/block=256、iterations=256、warmup=10、samples=21、batch=5。数值引自 [普通运行及 NSYS 预检日志](../reports/CH06/observe-preflight-2026-10-20.txt) 中工具外的 bench；本次总结未重测。它支持本机本次“warp 内分路较慢”的观察，不把总差值全部解释为纯分歧开销。

<span style="color:red">用户提问：如何用 NSYS 或 Nsight Compute 观察是否存在 warp divergence？</span>

NSYS 记录 CPU 提交、GPU kernel 与内存活动的时间关系。两种模式都显示为 `branch_work`，内部 device 函数 A/B 不会各自变成 kernel 时间条；时间较长本身不独立证明分歧。用户主动提出的 NCU 观察为本章可选扩展，正式 NCU 课程仍按 Ch07 推进。

NCU 在本机采集 `SourceCounters`、分歧分支目标总计数与每条指令平均参与线程数，得到以下动态证据：

| 指标 | within_warp | between_warps |
| --- | --- | --- |
| 分歧分支目标计数（sum） | 2048 | 0 |
| 每条指令平均参与线程数 | 16.40 | 32 |
| Branch Efficiency | 98.08% | 100% |

来源为 [NCU 报告](../reports/CH06/ncu-divergence-2026-10-20.ncu-rep) 与 [Details 文本](../reports/CH06/ncu-divergence-2026-10-20-details.txt)，本次只核对已有证据。第一种模式的非零分歧目标计数，结合条件分路和半组线程参与，支持实际发生分歧。Branch Efficiency 汇总大量一致的循环等分支，98.08% 不代表仅损失 1.92% 性能。低参与线程数也可能来自尾部线程或提前退出，不能单独作为分歧证明。

<span style="color:red">用户提问：在 NCU Source 选择 Divergent Branches 和 Avg. Threads Executed，就能定位源码，并与旁边 SASS 对照吗？</span>

可以。用户截图中，第 80 行 if 对应右侧偏移 0x270 的条件 BRA；第 81、83 行 A/B 调用各有 16 个参与线程，第 85 行写出恢复为 32。SASS 是 GPU 机器指令的汇编表示，Source 页面借助编译时的 `-lineinfo` 将指标与 CUDA/SASS 位置关联；`--import-source yes` 把相关源码保存在报告中，便于跨机器查看。

<mark>一行 CUDA 可能关联多条 SASS，源码行的聚合值不等于每条指令的值。</mark> 用户截图里 Divergent Branches 的 100.0 是相对显示，表示相应范围内的分歧计数集中在这一处；可用工具栏 `%` 切换绝对值，该处原始计数为 2048。它不是 100 次分歧，也不是 100% 时间损失或 Branch Efficiency=100%。

<span style="color:red">用户提问：NCU report 怎样组织，为什么只有两次 branch_work，实验不是重复了很多次吗，能只采集某几次吗？</span>

在本次默认 kernel 采集方式下，一份 report 包含多个执行结果，每个结果对应一次选中的 kernel 启动，并包含该次配置、Details 指标、Source/SASS 关联等；顶部 Result 切换结果，不是切换源码中的两个不同函数。实际采集末尾参数为 `check`，只主动提交 mode=0/1 两次启动；`bench` 才会提交 2 次初始校验＋20 次预热＋21×2×5 次正式启动，共 232 次。

`--kernel-name branch_work` 筛选名称，`--launch-count 2` 限制采集数量，`--launch-skip` 跳过指定数量的匹配启动。它按启动次数计数，不自动识别模式；例如对当前 bench 跳过 22 次后采集 1 次对应第 23 次 within_warp，跳过 27 次后采集 1 次对应第 28 次 between_warps。改参数后需要重新核对顺序。

日志的 `5 passes` 是 NCU 为收集不同指标对同一次启动进行的多轮采集，最终合成一个结果，不会因此在 GUI 生成 5 个 Result。<mark>程序循环次数、筛选出的启动次数、工具内部 replay passes 是三个不同层次。</mark> 本次 NCU 采集 check 用于观察动态计数，不是预热性能采样，工具下耗时与普通 bench 分开解释。

相关语义见 [CUDA 12.9 错误处理](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART__ERROR.html)、[NCU Source 页面](https://docs.nvidia.com/nsight-compute/NsightCompute/index.html#source-page)、[NCU CLI](https://docs.nvidia.com/nsight-compute/NsightComputeCli/index.html) 与 [Replay](https://docs.nvidia.com/nsight-compute/ProfilingGuide/index.html#replay)。完整命令集中在章节讲义，不在笔记重复维护多套实验入口。

### 踩坑记录

本章真实追问集中在三个理解边界：CUDA 已返回状态码，为何还需自定义检查；GPU 异步执行，为何错误查询成功不保证后续成功；bench 明明重复很多次，为何 NCU 报告只有两个结果。相应原因与调用顺序已在上文保留，不将这些问题写成用户发生了编译或运行故障。

用户实际提供了 NCU Source/SASS 关联截图；显示中的 100.0 需要区分相对值与绝对计数，行级聚合也需区分单条指令。第二结果的 GUI 对比尚未收到截图，两个模式的动态数值来自 Codex 已采集报告；不把建议用户进行的操作写成已经完成。代码、常量设置和工具细节已讲解，仍不据此推定独立掌握。

### 八股自测

必做复述：线程 32 的 warp/lane 是什么？两种模式 A/B 总人数相同，为什么 mode=0 会发生 warp 内分歧，而 mode=1 不会？结合条件代码和普通计时结果，说明本次测量包含哪些工作、没有覆盖哪些端到端环节。

可选复述：拿 NCU Source/SASS 说明分歧定位、16/32 个参与线程与相对 100.0 的含义，再解释 report 的两次结果和 5 passes 为什么不矛盾。该项用于复习主动询问过的工具观察，不新增课程必修门槛。

## 2026-10-21 Ch07：合并访存、读取索引与 NCU sector

### 今日完成任务

围绕 [CH07/memory_access.cu](../CH07/memory_access.cu) 阅读连续/跨步读取索引、host 实验流程、校验与 Event 计时，学习用 NCU 对应读取请求数和 sector 数。原骨架及预检于 10 月 20 日准备，今天用户要求补全唯一 TODO，Codex 完成正式实现、编译、全量校验、memcheck 和普通 bench；用户随后逐段阅读、提问并用自己的话复述了两种地址安排。完整命令与验证见 [章节讲义](chapters/07_coalescing_ncu.md)，工程进度和工作量只在 [RECORD](RECORD.md) 维护。

用户的复述已抓住主要变量：把 1024 项想象成 32×32 表格，通过交换行列让相邻线程读取不相邻的位置，比较访问效率与耗时。补充澄清“按顺序”指地址下标相邻，不表示线程一个接一个执行；1024 项只是一个小片，完整输入含 4194304 项。尚未收到用户自己的 check/bench 输出或本章 NCU 报告/截图；实现与工具验证不写成用户独立完成。

### 基本概念

**从线程编号到读取地址**

<span style="color:red">用户提问：本章主要讲什么，怎样阅读这个 CU 文件，input_index() 中这一段是什么意思？</span>

<mark>本章保持每线程一次读取、一次加法和一次连续写出，只改变同一 warp 中线程的读取地址排列。</mark> GPU kernel 的核心是：

```cpp
const int j = input_index(i, mode);
output[i] = input[j] + 1.0f;
```

`i` 是全局输出下标，决定写在哪里；`j` 是输入下标，决定从哪里读。连续模式返回 i；跨步模式把每个小片内的 `(row, col)` 映射到 `(col, row)`：

```cpp
const int base = (i / kTileElements) * kTileElements;
const int row = (i - base) / kSide;
const int col = (i - base) % kSide;
return base + col * kSide + row;
```

`kSide=32`、`kTileElements=1024`。base 是当前小片起点；对片内偏移整除 32 得行号，取余得列号。返回时保留 base，保证不同小片各自处理自己的数据。比如 i=35 对应 `(1,3)`，跨步读 j=97，即 `(3,1)`，结果仍写 output[35]。两种模式都恰好读取全部输入各一次，输出顺序可不同，应分别和各自的 CPU reference 比较。

```text
同一个 warp 的 lane：   0   1   2   3  ……  31
连续读取 input 下标：    0   1   2   3  ……  31
跨步读取 input 下标：    0  32  64  96  …… 992
两者写入 output 下标：  0   1   2   3  ……  31
```

这张 32×32 表格只是理解一维数组下标的方法，没有分配 shared memory。直接 `i*32` 会超出当前数组，简单取模又可能重复读部分元素，均不是本章要求的片内行列交换。

**run() 的组织与遇到的 C++ 语法**

<span style="color:red">用户提问：讲解 run()；read_and_check 和 const char* names[] 分别是什么语法，为什么读不懂？</span>

`run(bool timing)` 在 CPU 上组织“准备输入和两套 reference → GPU 分配/H2D → 两种模式分别计算和校验 → 按需预热与计时 → 释放内存”。timing 控制是否计时，mode=0/1 控制读取方式。`correct &= pass` 保留任一模式失败的结果；两个模式的校验分别执行，不因前者失败就跳过后者。

`const char* names[] = {"contiguous", "strided"};` 是含两个元素的字符指针数组，指向只读字符串；names[mode] 取得对应模式的名称。const 修饰所指字符，不表示指针数组本身不可修改。

`auto read_and_check = [&](int mode, bool verbose) { ... };` 是 lambda 表达式，可以先理解为在 run() 内起名的局部小函数。auto 让编译器推断变量类型，`[&]` 允许通过引用使用外层局部变量，括号中是调用参数，花括号中是执行内容。它在 CPU 上回读 GPU 输出，再调用 validate，返回 bool；调用形式是 `read_and_check(1, true)`。verbose 控制是否打印正常校验结果，出错时即使 false 也会打印。另一个 lambda launch 负责向 GPU 提交 kernel，它自身仍在 CPU 上执行。

**内联标记的用途**

<span style="color:red">用户提问：__forceinline__ 是什么意思，什么时候用 forceinline，什么时候用 noinline，有什么讲究？</span>

内联是编译器把被调用函数的计算展开到调用位置，省去独立调用和返回，并可能进一步优化。`__device__` 表示函数在 GPU 上执行，`__forceinline__` 要求编译器内联；本章短小的 input_index 使用该标记。普通代码可以先交给编译器自行决定，不因看到短函数就要求手工标记。

`__noinline__` 是尽可能保留独立函数调用的提示，可用于控制重复展开或构造实验；Ch06 的 path_a/path_b 用它帮助保留两条计算路径。它不禁止函数内部其他优化，也不单独保证最终分支形态。强制内联大函数可能使代码膨胀，不能承诺更快；两标记不能同时用于同一函数。语义见 [CUDA 12.9 内联说明](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#noinline-and-forceinline)。

**普通 bench 测量了什么**

<span style="color:red">用户提问：最后 bench 跑出来的数据差异是什么？</span>

先全量校验，再每模式预热 10 次；取 21 轮样本，每轮两模式交替先后，每个 Event 区间连续启动同模式 kernel 5 次。等待 stop 完成后读毫秒差，乘 1000 转为微秒、除以 5 得批次平均每次启动时间，最后对每模式 21 个值取中位数。每批回读校验在 Event 区间外。

正式完成版的 GTX 1650、float32、N=4194304、grid=16384、block=256 运行结果如下，原始证据为 [completed-2026-10-21.txt](../reports/CH07/completed-2026-10-21.txt)：

| 读取方式 | Event 批次平均每次启动的中位数 |
| --- | --- |
| contiguous 连续 | 317.593598 μs |
| strided 跨步 | 689.043188 μs |

跨步耗时约为连续的 2.17 倍，多约 371.45 μs。两模式各 4194304 项全量正确、误差 0，独立 memcheck 零错误。<mark>时间不含分配、H2D/D2H、CPU reference 或校验，仍可能包含 host 提交间隙；这是本机本次对照，不是固定减速比例。</mark> 本条总结重读已有日志，没有重新计时。

**NCU 的 sector 与缓存层次**

<span style="color:red">用户提问：如何用 NCU 查看读取请求涉及多少个 32 字节数据块，什么是数据块？L1/TEX 层面的访问是什么意思，为什么 sector 多 8 倍不代表显存传输或耗时多 8 倍？</span>

sector 是这里按 32 字节边界划分的访存单位，容纳 8 个 float；它与 kernel 的线程组 block 不同。本章对齐的第一个 warp 连续读 0～31 项，集中在 4 个 sector；跨步读 0、32……992 项，涉及 32 个不同 sector。合并访存关注的是同一 warp 一次读取所需数据的分布，不只是整个 kernel 最后有没有遍历完整数组。

NCU 对本例只选 access_pattern 的两次 check 启动，第一个结果为连续、第二个为跨步。采集 `l1tex__t_requests_pipe_lsu_mem_global_op_ld.sum`（读取请求总数）和 `l1tex__t_sectors_pipe_lsu_mem_global_op_ld.sum`（请求涉及的 sector 总数），用后者除以前者得到平均每次请求涉及的 sector 数。对当前 kernel，一个完整 warp 执行一次 global load 产生一次请求，不是每个线程各算一次请求。

10 月 20 日教学方临时补全版的 [NCU Details](../reports/CH07/ncu-preflight-2026-10-20-details.txt) 已有实测：

| 模式 | requests | sectors | sectors/request |
| --- | --- | --- | --- |
| 连续 | 131072 | 524288 | 4 |
| 跨步 | 131072 | 4194304 | 32 |

这组计数与上面的 10 月 21 日正式 bench 来自不同运行、不同日期；今天没有重采 NCU。完整采集、CLI 导入和 GUI Details 查看方法集中在 [讲义 NCU 小节](chapters/07_coalescing_ncu.md#正式用一次-ncu-采集解释访问)，不重复维护另一套命令。

缓存可以理解为靠近计算单元、临时保留已取回数据的快速存储。本章普通读取的简化请求路径是“线程 → L1/TEX → 未命中才继续到 L2 → 仍未命中才继续到显存 DRAM”。命中缓存的 sector 访问也计入 L1/TEX 指标；同一 sector 被不同请求访问会重复计数，不是全程序访问过的不同 sector 数量。

例如两组 warp 的请求分别包含 input[0]/input[1]、input[32]/input[33]，每对元素属于同一 sector。若相关数据仍在可用缓存中，后来的请求可能复用已有内容，不必每次从 DRAM 重取；这不假定 warp 编号决定执行先后，也不保证所有请求均命中 L1。<mark>L1/TEX sector 访问次数、缓存未命中次数、实际显存传输字节数、kernel 总耗时，是不同层次的量。</mark> 即便显存字节数增加，访存并行、地址计算和不变的输出写入等因素也会影响总耗时，不能直接同比换算。

本章没有测量 L1/L2 命中率和 DRAM 流量，因此缓存复用是解释可能机制的例子，不是已经测出缓存抵消多少流量；也不能把 2.17 倍耗时精确归因于某一级缓存。指标口径见 [NCU Memory Tables](https://docs.nvidia.com/nsight-compute/ProfilingGuide/index.html#memory-tables)。

### 踩坑记录

本章真实疑问集中在读取索引拆分、内联标记、lambda 与字符串指针数组，以及 sector、缓存与显存流量的区别。用户已主动复述地址排列的主要变量，尚需结合自己的运行结果解释计数和时间边界；不把提问本身当作所有概念已独立掌握。

没有收到用户实际编译、运行或 NCU 采集失败的输出。历史骨架 strided FAIL 是 TODO 占位的预期，今天正式完成版已通过，不记成用户误写。NCU 运行下的耗时不用于替代普通 bench，理论 4/32 也不换算成固定 8 倍减速。缓存、SASS 和内联优化的进一步调优不新增为本章必修。

### 八股自测

给出 i=35 和 i=1025 的跨步输入下标，解释为什么必须保留 base，以及为什么两个模式都读遍所有输入但输出可以不同。再用同一 warp 的地址分布说明连续为 4、跨步为 32 个 sector。

结合一次自己的 check/bench 与 NCU 两结果，说明读取请求数为何可以相同、sector 数为何不同，sector 8 倍为何不等于显存流量或耗时 8 倍，并指出 Event 计时包含和排除的工作。以上为后续验收入口，不把建议操作写成已经完成。

## 2026-10-22 Ch08：shared 数据交换与 block 同步

### 今日完成任务

围绕 [CH08/shared_exchange.cu](../CH08/shared_exchange.cu) 阅读实验参数、main 数据流、kernel 的对称读取，以及 benchmark 的 Event 批次采样。骨架在 10 月 21 日生成，今天按用户“完成两个todo”的要求，由 Codex 补全 barrier 与伙伴槽位读取，完成正式编译、全量校验、Sanitizer 检查和普通计时；随后直接运行已有可执行文件，观察同步/缺同步模式。运行命令集中在 [章节讲义](chapters/08_shared_sync.md)，工程进度和工作量只在 [RECORD](RECORD.md) 维护。

用户主动复述了“每个 block 内线程去读取与自己对称的 shared 位置”，这是对 kernel 功能的局部理解证据。用户随后追问 barrier 是否就是最后的同步，以及不同线程只是取不同位置为何仍会冲突；已结合写入阶段和跨 warp 例子讲解。实现和工具运行由 Codex 完成，尚未收到用户自己的运行输出或对同步依赖的独立复述，不据此认定整章掌握。

### 基本概念

**shared 是 block 内共用的暂存区**

shared memory 可以理解为同一个 block 共用的工作台：每个线程先放上自己的数据，再取走伙伴放的数据。`__shared__ float tile[kBlock]` 在每个 block 内各有一份，128 个 float 共 512 字节，生存期随该 block；本例的 tile 用于 block 内交换。main 的 cudaMalloc 分配输入/输出 global memory，tile 则在 kernel 内声明。

<span style="color:red">用户提问：这个 kernel 的功能，就是每个 block 内的线程读取该 block 中与自己对称的 shared 位置吗？</span>

是。固定 N=1000、block=128、grid=8，七个完整 block 各处理 128 项，最后一个处理 104 项。`t` 是 block 内线程编号，`base` 是本片段起点，`i=base+t` 是全局下标，`count` 是本片段有效项数，`peer=count-1-t` 是伙伴槽位编号。<mark>输出为每个 block 对应的有效片段分别反序。</mark>

```cpp
tile[t] = valid ? input[i] : 0.0f;
if (use_barrier) {
    __syncthreads();
}
if (valid) {
    const int peer = count - 1 - t;
    output[i] = tile[peer];
}
```

完整 block 中线程 0 读取 tile[127]、线程 127 读取 tile[0]；尾部线程 0 读取 tile[103]。无效尾部线程 t=104～127 写零、参加本例的集合点，但不读取越界 input，也不写 output。输入为 input[i]=i*0.25f，因此 output[0]=input[127]=31.75，output[896]=input[999]=249.75。

**barrier 建立写入与伙伴读取的先后关系**

<span style="color:red">用户提问：barrier 是什么，就是最后的同步吗？本次实验是否对照加同步和不加同步？只是让不同线程取对称位置，为什么会与其他线程冲突？</span>

barrier 是集合点。本例的 `__syncthreads()` 位于 shared 写入之后、伙伴读取之前，等待同一 block 的线程到达，并让此前写入对 block 内线程可见。`use_barrier` 在一次 launch 内取值一致，所有线程选择同一分支；不能将本例集合点移入只有部分线程满足的 if(valid)。128 个线程含四个 warp，伙伴交接跨越 warp，不能用单个 warp 的同步覆盖全部依赖。

<mark>不同线程的读取彼此不冲突，但读取的槽位由另一个线程负责写入；必须保证伙伴先写好，自己再读取。</mark> 输入已从 CPU 传入 global memory，也不代表线程已经把它搬到了 shared。以下只是一种可能的错误执行顺序，用于理解风险，不是本次工具还原的实际执行轨迹：

```text
线程 0：   写 tile[0]
线程 0：   读 tile[127]  ← 伙伴可能尚未写好
线程 127： 写 tile[127]
```

这里的风险是线程 0 对 tile[127] 的读取与线程 127 对同一槽位的写入缺少顺序保证。本例先写一轮、再读一轮，读完不覆盖复用 shared，所以一个写后读 barrier 足够；循环复用时是否需要额外同步留到后续实际程序。

| 同步位置 | 谁在等待 | 本例作用 |
| --- | --- | --- |
| kernel 中间的 `__syncthreads()` | 同一 block 的线程 | 保证写完 shared 后再互相读取 |
| main 的 `cudaDeviceSynchronize()` | CPU 调用线程 | 等待此前 GPU 工作完成，再回读结果 |

<mark>kernel 完成后的 host 等待，不能补救 kernel 内部已发生的过早读取。</mark> 语义参考 [CUDA 12.9 Synchronization Functions](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#synchronization-functions)。

**main 组织 CPU 与 GPU 数据流**

<span style="color:red">用户提问：如何阅读当前 cu 文件，main 函数整个是什么流程？</span>

建议先看参数，再沿 main→launch→exchange_block 阅读执行流程，随后用 make_reference/validate 理解校验，最后看 benchmark。main 和 launch 在 CPU 上执行，exchange_block 在 GPU 上执行。main 的流程是：选择模式、打印配置、CPU 准备输入与 reference、GPU 分配和 H2D、启动 kernel、等待完成、D2H、全量校验、按需计时、释放内存和返回状态。

`argc==1` 表示只有程序名，默认 check；否则从 argv[1] 取得模式。`strcmp(a,b)==0` 表示字符串内容相同。check 启用 barrier，bench 先校验再计时，race 传入 false 跳过 barrier。`!unsafe` 因此是启动时的 use_barrier 参数。`reference` 是 CPU 按每片首尾反向生成的正确答案，不调用 kernel 的 shared 实现；validate 检查全部 1000 项，示例打印不替代全量校验。

**benchmark 测的是同步版本的批次平均时间**

<span style="color:red">用户指定 benchmark() 代码段要求讲解，并要求根据生成的可执行文件说明实验现象。</span>

benchmark 的 input/output 指向 GPU 数组，reference/host_output 是 CPU 数组；后两者按引用传入，const reference 只读。先以 use_barrier=true 预热 10 次，等待完成，再创建 start/stop Event。每个样本在同一默认 stream 中依次记录 start、提交 10 次 kernel、记录 stop；等待 stop 完成后取得毫秒差，乘 1000 转微秒、除以 10，得到本批平均每次启动时间。

一共最多采 21 个样本，每批结束回读并校验最后一次启动留下的输出，同时要求时间有限且大于零；失败则停止后续采样，不打印有效中位数。全部通过后排序，取第 11 个值，最后销毁 Event。每次仍读相同 input、覆盖相同 output，不把前次反序结果当作下次输入。

<mark>最终统计是“21 个批次平均每次启动时间的中位数”。</mark> 预热、分配、H2D/D2H、CPU reference 和回读校验不在 Event 区间内；短 kernel 的区间仍可能包含 host 提交间隙。本章只测同步版本，不拿缺同步版本作速度比较。

**实验现象：缺同步可以数值 PASS，但仍有读写竞争**

以下引自 10 月 22 日已有 [observe 日志](../reports/CH08/observe-2026-10-22.txt)，本次总结只重读证据，没有重新运行。环境为 GTX 1650 / CC 7.5，N=1000、float32、grid=8、block=128。

| 模式 | 数值结果 | racecheck 结果 |
| --- | --- | --- |
| check，有 barrier | 全部 1000 项 PASS，误差 0 | 零冲突，退出 0 |
| race，无 barrier | 本次也全部 PASS，误差 0 | 检出 shared 第 38 行写与第 46 行读的冲突，退出 99 |

racecheck 将 4000 个字节级 hazards 合并为 1 条 error 分析，不能当作 4000 个独立 bug。<mark>数值 PASS 只说明本次结果符合 reference，不能证明读写顺序可靠。</mark> race 模式的应用退出码故意为 0，让工具在检测错误时通过 --error-exitcode 99 报告检查失败，因此应用退出成功也不是无竞争证明。工具职责见 [Compute Sanitizer](https://docs.nvidia.com/compute-sanitizer/ComputeSanitizer/index.html#racecheck-tool)。

同一 observe 日志中，普通 bench 的 Event 中位数为 14.627200 μs/次；这是与 racecheck 分开的普通运行。更早的 [正式完成版验证](../reports/CH08/completed-2026-10-22.txt) 已有 check 的 memcheck、racecheck、synccheck 零错误，以及另一轮 bench 的 12.102400 μs/次。它们来自不同运行，不作优化 A/B，不推断时间波动原因或 shared 固定加速比。

### 踩坑记录

本章实际疑问是把“读取位置不同”理解为没有线程间冲突，以及把 block 内 barrier 与最后的 host 等待混淆。关键是补上 shared 的写入阶段：自己要读的槽位由伙伴写入，需要明确先写后读；同一 block 的线程进度不能靠猜。已经讲解这一边界，但尚未收到用户对它的独立复述。

用户已经准确复述对称读取的功能，不能笼统写成没有理解证据。代码两处补全、正式编译及工具运行由 Codex 完成；没有用户独立实现、个人运行输出或工具操作截图，不虚构用户发生过编译、运行故障。缺同步数值仍 PASS 是本例真实观测，不是要求通过多跑几次制造 FAIL。bank conflict、归约和底层指令优化不扩展为本章内容。

### 八股自测

用自己的话解释线程 0 读取 tile[127] 时依赖谁的写入，以及为什么 main 最后的 cudaDeviceSynchronize 不能代替 kernel 内的 __syncthreads。结合现有 check/race 两结果，说明为什么两者数值都 PASS，racecheck 却不同。

再解释最后一个 block 为什么使用 count=104、线程 0 为什么读 tile[103]、无效线程为什么仍参加本例集合点，并说明 14.627200 μs 的统计方式与不包含的工作。以上用于后续验收，不将已讲解视为已独立掌握。

## 2026-10-26 Ch09：shared 布局、bank conflict 与 NCU 计数

### 今日完成任务

按用户“总结本章内容”的要求，汇总本章源码阅读与提问。围绕 [CH09/bank_conflict.cu](../CH09/bank_conflict.cu)，已讲解参数、二维线程坐标与 warp 分组、shared 寻址、转置读写、template、volatile、循环展开，以及 NCU 冲突指标的位置、分批服务和大数值的来源。运行命令与教学任务见 [章节讲义](chapters/09_bank_conflict.md)，进度和工作量只在 [RECORD](RECORD.md) 维护。

骨架在 10 月 22 日生成；10 月 23 日按用户要求，由 Codex 完成唯一的 shared_index 地址 TODO 并验证正式程序。本次只重读源码及已有报告，没有重新运行实验。用户明确表示不理解 x/y、warp 归属与循环赋值，并继续追问 bank conflict；这些是实际理解难点，尚未收到用户独立实现、个人运行/采集输出或完整解释，不据提问推定已经掌握。

### 基本概念

**程序任务与参数：每个 block 转置一个小矩阵**

<span style="color:red">用户提问：先讲解一下参数设置含义；完成 TODO，并告诉我这里整个 kernel 主要是什么功能。</span>

输入为 1024 个独立的 32×32 float32 小矩阵，输出将每片分别转置，即交换行列。kSide=32、kTileElements=1024、kTiles=1024、kN=1048576；输入和输出各占 4 MiB。每个 block 负责一个小片，base=blockIdx.x*1024 定位当前片段，不交换小片的位置。

kRows=8 决定 block=(32,8)，每个 block 有 256 个线程、8 个 warp，每线程搬运 4 项，合计覆盖 1024 项。kRows 是线程组织高度，矩阵仍有 32 行。kSharedElements=32*33=1056 个 float，每个 block 两种布局均预留 4224 字节；stride 32 使用前 1024 个槽位，stride 33 每行末尾留一个空位，空位不属于逻辑矩阵。

普通 bench 的 kWarmup=10、kSamples=21、kBatch=5：先预热 10 次，每个 Event 区间连续启动 5 次，区间时间除以 5 得到每次启动的批次平均值，再对 21 个样本取中位数。分配、传输及 CPU 校验不在 Event 区间中，可能的 host 提交间隙仍可能影响结果。check 则只分别启动两种布局，不执行预热与重复计时。

**二维坐标先转一维编号，再组成 warp**

<span style="color:red">用户提问：不太懂 x、y 有什么区别，也不懂“每个 warp 固定 y，x=0..31”；warp 到底如何组织，怎么知道哪些线程属于一个 warp？</span>

可以把当前 block 逻辑上看成 8 排、每排 32 个座位。每个线程同时具有 x 和 y：x 是排内座位号，y 是排号，这不是 GPU 上的物理座位布局。CUDA 按 x 优先增加的顺序编号，二维 block 中：

```cpp
int tid = threadIdx.x + blockDim.x * threadIdx.y;
int warp_in_block = tid / 32;
int lane = tid % 32;
```

同一 block 内连续 32 个编号组成一个 warp，不跨 block。本例 tid=x+32*y，因此 y=0、x=0..31 是 warp 0，y=1、x=0..31 是 warp 1，以此类推。线程 (x=3,y=2) 的 tid=67，属于 warp 2、lane 3。

<mark>“同一个 warp 固定 y”来自本例 blockDim.x=32，并不是任意二维 block 都成立。</mark> 若 block=(16,16)，warp 0 会包含 y=0 和 y=1 的各 16 个线程。归属按编号计算，不能根据线程碰巧何时运行来判断。[CUDA Thread Hierarchy](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#thread-hierarchy) / [SIMT Architecture](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#simt-architecture)

**两轮循环：先按行搬入，再按列读出**

<span style="color:red">用户提问：这个循环里面的赋值逻辑不太懂；output[base + col * kSide + x] 是什么意思？</span>

每个线程独立执行循环，j=0、8、16、24。第一轮 row=y+j，线程将输入第 row 行、第 x 列放到 shared 的同一逻辑位置；例如 (x=3,y=2) 负责第 2、10、18、26 行的第 3 列。同一个 warp 的 x 覆盖 0..31，所以每轮沿完整的一行连续搬运。

```cpp
tile[shared_index(row, x, Stride)] = input[base + row * 32 + x];
__syncthreads();  // 实际源码位于整个写入循环之后，等待所有线程完成四项写入。
```

整个写入循环结束后执行 block barrier，再进入读取循环。第二轮 col=y+j，读取 shared 的第 x 行、第 col 列，写到输出第 col 行、第 x 列：

```cpp
output[base + col * 32 + x] = tile[shared_index(x, col, Stride)];
```

这里 col 沿用输入列号，转置后成为输出行号。base 找到当前小矩阵，col*32 跳过输出的 col 整行，x 再定位该行中的列。例如 base=0、col=2、x=3 时写 output[67]，即输出第 2 行、第 3 列，数据来自输入第 3 行、第 2 列。同一个 warp 的 global 写出仍连续。

**shared_index 与 padding：位置改变，逻辑数据保持一致**

<span style="color:red">用户提问：stride 如何通过 shared_index 影响实验结果，如何体现 shared memory bank conflict？</span>

当前 helper 为 `return row*stride+col;`，stride 的单位是 float 槽位。它先找到行起点，再加列偏移；写入和读取共用同一个映射，因此 padding 后仍能找到原来的逻辑数据。global 地址、工作量、barrier 和 shared 预留大小都保持不变，转置输出应一致。历史占位版固定使用行跨度 32，数值也能 PASS，所以正确性本身不能证明 padding 已生效。

本机本例的 tile 按 bank 0 对齐，每线程每条读取处理一个 32-bit float，可用 float 槽位下标模 32 得到 bank 编号。按行写入的下标为 row*Stride+x，warp 中相邻 x 落在不同 bank；按列读取的下标为 x*Stride+col，同一个 warp 中 col 固定：

| 行跨度 | col=0 时线程 0、1、2、31 的 shared 下标 | 对应 bank |
| --- | --- | --- |
| 32 | 0、32、64、992 | 0、0、0、0 |
| 33 | 0、33、66、1023 | 0、1、2、31 |

<mark>stride 32 使同列的不同地址挤在一个 bank；stride 33 通过每行空一个位置，把这些访问分散到全部 bank。</mark> 多线程读取同一个 32-bit 字可以广播，不属于本例的不同地址冲突。Ch07 的 global 合并访存关注数据落在哪些 sector；本章关注 shared 地址落在哪些 bank，二者不能混为同一个指标。[CUDA 12.9：Shared Memory and Memory Banks](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-best-practices-guide/index.html#shared-memory-and-memory-banks)

**template、volatile 与循环展开的作用**

<span style="color:red">用户提问：template 模板什么作用？volatile 什么作用？#pragma unroll 什么作用？</span>

`template<int Stride>` 让一份源码按编译期整数生成不同版本，`shared_transpose<32>` 和 `<33>` 的地址计算分别使用固定的 32 和 33。调用中的 `<32>` 选择模板版本，`<<<...>>>` 指定 grid/block，`(input,output)` 传运行时数据。

`__shared__` 决定 tile 放在 shared memory，`volatile` 限制部分读写优化，帮助本微基准保留希望观察的访问。它不保证源码访问与硬件访问严格一一对应，也不提供线程间同步；写后读交接仍需要 `__syncthreads()`。不能把 volatile 当成消除数据竞争的办法。[CUDA 12.9：Volatile Qualifier](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#volatile-qualifier)

`#pragma unroll` 作用于紧随其后的循环；本例循环次数在编译期固定，展开后逻辑上相当于直接写出 j=0、8、16、24 四份搬运操作，便于减少循环控制及优化固定偏移。每个线程依然处理四项，线程数不变，不保证四份操作同时执行，也不预设一定更快。[CUDA 12.9：pragma unroll](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#pragma-unroll)

**bank conflict 的分批服务与 NCU 大计数**

<span style="color:red">用户提问：发生 bank conflict 时是怎样分批的？在 NCU 哪里看指标？Bank Conflicts 是什么，为什么数字这么大？</span>

可以把 bank 看成并行服务窗口。本例一次 warp 标量读取中，每个 bank 在一批中服务一个不同的 float，不同 bank 可并行；同 bank 的不同 float 需要分批。这类服务批次在 NCU 中称为 wavefront。stride 32 的同列读取需要 32 批，stride 33 可一批完成；若 32 个请求均匀分布到 16 个 bank、每个 bank 有两个不同 float，则两批、每批服务 16 个 bank。warp 成员不变，实际先服务哪个线程不保证按 lane 编号，不能把示意顺序当成硬件轨迹。

本章 [正式 NCU 报告](../reports/CH09/completed-2026-10-23.ncu-rep) 只专门采集冲突指标，优先在 GUI 的 Raw 页筛选 bank_conflicts。`l1tex__data_bank_conflicts_pipe_lsu_mem_shared_op_ld.sum` 对应 shared 读取，`..._st.sum` 对应写入；sum 汇总本次 kernel 各硬件实例。若采集完整访存表，可在 Details 的 Memory Workload Analysis Tables → Shared Memory 看 Bank Conflicts 列。显示约 1.02 M 可能是 1015808 的缩写。[NCU Raw Page](https://docs.nvidia.com/nsight-compute/NsightCompute/index.html#raw-page)

对本例的 32-bit 标量读取，无冲突时每请求一批；32 路冲突时每请求 32 批，额外 31 批。每个 kernel 的 1024 个 block、每 block 8 个 warp、每 warp 4 次 shared 读取，合计 32768 次请求，因此：

```text
1024 × 8 × 4 × (32 - 1) = 1,015,808
```

这一推导与本机本例的读取冲突实测完全一致，不泛化为任意访问宽度或任意 kernel 的计数恒等式。两种 kernel 分别计数，普通 bench 的预热和 21×5 次重复不计入这次 NCU check 结果。<mark>Bank Conflicts 是累计访问效率计数，不是 bank 数量、不同地址个数、内存错误数或总耗时倍数。</mark> 32 路冲突也不直接推出整个 kernel 慢 32 倍。[NCU Shared Memory](https://docs.nvidia.com/nsight-compute/ProfilingGuide/index.html#shared-memory) / [Compute Triage Guide](https://docs.nvidia.com/nsight-compute/ComputeTriage/)

**正式结果与证据边界**

以下重读 10 月 23 日已有 [正式验证日志](../reports/CH09/completed-2026-10-23.txt) 和 [指标 CSV](../reports/CH09/completed-metrics-2026-10-23.csv)，环境为 GTX 1650 / CC 7.5、NVCC 12.9.86、NCU/Compute Sanitizer 2025.2.1.0，shape/dtype 与上文一致。本次总结未重新运行。

| 布局 | 数值校验 | shared 读取冲突 | shared 写入冲突 | 普通 Event 中位数 μs/次 |
| --- | --- | --- | --- | --- |
| stride 32 | 1048576 项 PASS，误差 0 | 1015808 | 0 | 189.683199 |
| stride 33 | 1048576 项 PASS，误差 0 | 0 | 0 | 68.320000 |

两模式 memcheck、racecheck、synccheck 均零错误，racecheck 零 warnings。普通计时与工具运行分开，统计为 21 个批次平均每次启动时间的中位数；本轮比值约 2.776，仅用于当前设备、输入与测量边界，不与 10 月 22 日的临时版或骨架跨运行比较，也不保证所有 GPU 有相同收益。<mark>barrier 保证交接顺序，padding 改善 bank 分布；数据竞争和 bank conflict 分别属于正确性与访问效率问题。</mark>

### 踩坑记录

用户明确暴露的难点是二维线程编号、warp 如何分组、循环中谁负责哪些元素，以及输出一维下标为何对应转置。已用 (x=3,y=2)、block=(16,16) 反例和输入/输出行列对应关系解释，不将这些已讲解例子写成用户独立复述。

用户还追问了限定符、循环展开、硬件分批与大冲突计数。复习时应分清线程组织、shared 逻辑布局、物理 bank 和工具累计口径；避免把每行 32 个线程当成任意 block 的固有规则，把 volatile 当同步，或把 1015808 当成错误数。正式 helper 由 Codex 按要求补全，没有用户误写、编译失败或个人 GUI 操作的证据；不编造这些经历。更深的 bank 调度电路、SASS 后缀与性能归因不新增为首轮门槛。

### 八股自测

不用查看答案，说明本章线程 (x=3,y=2) 的 tid、warp、lane，以及第一轮循环读哪四个输入位置；再解释把 block 换成 (16,16) 时，为什么同一 warp 的 y 可以不同。结合读写代码，说明 output[base+col*32+x] 的行列含义，以及 stride 改变后为什么输出数据保持相同。

手算同一 warp 读取第 0 列时 stride 32/33 的 bank 分布，解释额外 31 批的来源，并用启动规模推导 1015808；指出 NCU 的查看入口、冲突计数与普通计时的区别，以及 volatile、barrier、padding 各自负责什么。以上为后续验收问题，不把已有讲解或 Codex 验证计为个人掌握。


## 2026-10-27 Ch10：归约与 warp shuffle

### 今日完成任务

围绕 [CH10/reduction.cu](../CH10/reduction.cu) 对照 shared 树形归约和 warp shuffle 归约。用户先阅读 kernel 属性查询，再要求 Codex 依次完成两处 TODO，随后追问 shuffle 语句、`__forceinline__` 和跨 warp 的合并过程，并讨论实验现象。两处实现及程序、工具验证均由 Codex 完成；用户已有局部复述，不记为独立实现或整章掌握。运行方法和原始证据见 [章节讲义](chapters/10_reduction.md) 与 [正式验证日志](../reports/CH10/completed-2026-10-27.txt)。

### 基本概念

**任务、数据流与输出范围**

归约就是把许多输入逐步合成一个结果，本章求和。固定 N=262144、float32、grid=1024、block=256，每线程读取一个数，每个 block 负责连续 256 项，输出一个片段和。

```text
CPU 生成输入与 reference → H2D
  → 1024 个 block 各自将 256 项合为 1 项
  → D2H 回读 1024 个 partial → 逐片校验 → CPU 汇总总和
```

<mark>两个 kernel 的输出都是 1024 个 block 和，最终总和由 CPU 汇总。</mark> 本章没有实现 kernel 内跨 block 同步、atomic 或第二级 GPU 归约。逐片校验能发现总和中可能相互抵消的错误，不能只核对一个总和。

**查询 kernel 属性**

<span style="color:red">用户提问：cudaFuncAttributes 和两次 cudaFuncGetAttributes 这一段什么意思？</span>

`cudaFuncAttributes shared_attr{}, shuffle_attr{};` 创建并初始化两个属性结构体。`cudaFuncGetAttributes(&shared_attr, block_sum_shared)` 在 host 侧查询指定 kernel 的属性，将结果写进 shared_attr，返回值由 CUDA_CHECK 检查；它没有启动求和 kernel。后面的 sharedSizeBytes 表示该 kernel 每个 block 所需的静态 shared 字节数，不包括 launch 时请求的 dynamic shared。本例分别为 256×4=1024 和 8×4=32 字节。

**shared 树形归约：每轮合并两份已有的和**

<span style="color:red">用户提问：完成 TODO1，并告诉我这个 kernel 的功能。</span>

线程 tid 先把 input[blockIdx.x*256+tid] 放到 tile[tid]，首次 barrier 保证输入全部写好。随后 stride=128、64、32、16、8、4、2、1，每轮只有 tid<stride 的线程执行：

```cpp
tile[tid] += tile[tid + stride];
```

参与合并的片段数量从 256→128→64→…→1；最终线程 0 把 tile[0] 写进 partial[blockIdx.x]。以本片相对下标为例，stride=128 后 tile[0] 包含输入 0、128，tile[64] 包含输入 64、192；stride=64 时线程 0 合并两份已有和，结果包含四项。

<mark>下一轮读取依赖其他线程上一轮已经写完；所有线程都必须到达轮间 barrier。</mark> 所以 `__syncthreads()` 位于 if 外，不做加法的线程仍参与同步。host 上等待 kernel 完成的 cudaDeviceSynchronize 无法补上 kernel 内缺失的交接顺序。

**shuffle：同一树形思路，改变数据交换方式**

<span style="color:red">用户提问：value += __shfl_down_sync(0xffffffffu, value, offset); 怎么理解？</span>

每个线程有自己独立的 value。shuffle 从同一 warp 的 lane+offset 取回伙伴的当前 value，+= 再把它累加到自己的 value；交换不经过 shared 中转。mask=0xffffffffu 的 32 位全为 1，表示完整 32 lanes 参与，u 表示无符号整数。所有参与 lane 执行同一个 intrinsic 并使用相同 mask。[CUDA 12.9：Warp Shuffle Functions](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#warp-shuffle-functions)

```cpp
for (int offset = 16; offset > 0; offset /= 2) {
    value += __shfl_down_sync(0xffffffffu, value, offset);
}
```

若 lane 0..31 最初分别持有 1..32，offset=16 时 lane 0 得到 1+17=18，lane 8 得到 9+25=34；offset=8 时 lane 0 取得的是伙伴已合并的 34，自己的结果变成 52。继续 offset=4、2、1，最终 lane 0 得到 528。每轮读取的是本次交换时伙伴的当前值，不是永远读取最初输入，也不是按 lane 编号顺序逐个更新。

<mark>本例只使用 lane 0 的完整 warp 和，其他 lane 不保证同样得到全和。</mark> 默认 width=32，源 lane 超过 31 时 shuffle 返回调用者自己的值，不自动补零；这些高 lane 的无用结果不会进入 lane 0 的完整和。`_sync` 协调指定 warp 成员参与交换，不提供 shared memory 的内存顺序保证，也不能跨 warp 取值。

**跨 warp：shared 交接，再由 warp 0 合并**

<span style="color:red">用户提问：这里如何实现跨 warp 的归约？</span>

一个 block 有 8 个 warp，第一轮各自在 lane 0 得到 32 项和，再执行 warp_partial[warp]=value。整个 block 到达 `__syncthreads()` 后，这 8 个片段和才交给 warp 0：lane 0..7 各读一个 warp_partial，lane 8..31 输入 0。

```text
8 个 warp 分别求和 → [S0,S1,…,S7] 写 shared → block barrier
  → warp 0 的 32 lanes 持有 [S0,S1,…,S7,0,…,0]
  → warp_sum → lane 0 写出本 block 的和
```

具体到线程，tid=32 是 warp 1 的 lane 0，它写 warp_partial[1]；同步后，tid=1 是 warp 0 的 lane 1，它读取这个槽位。跨 warp 的交接通过 shared 和 block barrier 完成，最后的加法归约发生在 warp 0 内部。

if (warp==0) 包含该 warp 的全部 32 个 lane，满足 full mask 的参与要求。只有 8 个有效和不等于只让 8 个 lane 调用 shuffle：其余 24 个 lane 用零参与。不能把调用条件改成 lane<8 后仍沿用 full mask。本章只处理固定完整 warp，任意长度与尾部 mask 留给选修。

**`__forceinline__`：把短函数体内联到调用位置**

<span style="color:red">用户提问：<code>__forceinline__</code> 是干啥的，我又忘了。</span>

`__device__` 表明 warp_sum 是 GPU 侧函数；`__forceinline__` 要求编译器将函数内联，可以理解为把函数逻辑直接放到调用位置，省去独立函数调用/返回并方便优化。它适合这里短小的 helper，但不保证性能必然提高；这是编译方式，不承担线程同步作用。[CUDA 12.9：函数内联限定符](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#noinline-and-forceinline)

**实验现象与用户的局部理解**

<span style="color:red">用户复述：我看其实 shuffle 一个 warp 里面还是树形归约的逻辑，只不过同步和读取 shared memory 的开销小一些，对吗？</span>

<mark>shuffle 版仍然是逐轮合并片段和的树形归约，主要改变线程之间传值和同步的方式。</mark> shared 版通过 shared 交接，每轮都等待整个 block；shuffle 版在 warp 内直接交换线程寄存器中的值，跨 warp 时再保留 shared 与一次 block barrier。这是用户已主动表达的局部理解，不据此推断已经独立解释全部数据流或完成个人操作。

以下重读当日已有正式日志，环境为 GTX 1650 / CC 7.5、NVCC 12.9.86、Compute Sanitizer 2025.2.1.0。本次总结没有重新编译或运行。

| 实现 | 静态 shared / block | 每 block 源码 barrier 次数 | 片段和校验 / CPU 汇总总和 | 普通 Event 中位数 μs/次 |
| --- | --- | --- | --- | --- |
| shared 树形 | 1024 字节 | 9（首次装载后 + 8 轮） | 1024 项 PASS，误差 0 / -184 | 29.046401 |
| warp shuffle | 32 字节 | 1（跨 warp 交接） | 1024 项 PASS，误差 0 / -184 | 16.640000 |

两种实现第一片均为 -189，memcheck（padding=32）、racecheck、synccheck 均零错误，racecheck 零 warnings。输入是混合正负小整数，相关整数和可用 float 精确表示，因此要求误差 0；一般浮点输入改变归约顺序可能改变舍入，不套用这里的精确相等。

计时先校验、各预热 10 次，21 个样本，每个同 stream Event 区间启动 10 次，归一化到每次启动后取中位数。它不含分配、H2D/D2H、CPU 校验和最终汇总，可能含 host 提交间隙；工具检查与普通 bench 分开。本轮 shared/shuffle 比值为 1.746，体现本机该输入下 shuffle 版更快，不把收益全部归因于单个因素，也不推断通用加速比。表中的 barrier 数来自源码，不是本次新采集的硬件动态计数；本次总结未采集 NCU、NSYS 或操作 GUI。

### 踩坑记录

实际疑问集中在 kernel 属性查询、每轮拿到的 value、限定符和跨 warp 数据交接。复习时应分清查询属性与启动 kernel、参与加法与参与同步、warp 内交换与跨 warp shared 交接。shuffle 的 full mask 要求完整参与，不能因为只使用 lane 0 的结果就只让 lane 0 调用。

历史上只完成 TODO(1) 时 shared PASS、shuffle FAIL、整个程序退出 1；这属于阶段性算法未完成，不是 shared 失败或 Sanitizer 检出错误。当前两处均完成，check、三种工具检查和 bench 均退出 0。没有用户误写、编译错误或个人工具操作的证据，不编造学习经历。

### 八股自测

不看答案，解释 shared 版 stride=64 时线程 0 为什么已合并四项，为什么 barrier 必须位于 if 外；再追踪 tid=32 写出的 warp 和如何交给 tid=1，说明最后仅 8 个有效和时为何仍由 32 lanes 参与 shuffle。

用自己的话区分树形归约算法与 shared/shuffle 的通信方式，解释 `__forceinline__` 的作用，并指出本轮 Event 1.746 倍比较包含和排除了哪些工作。这些是后续验收问题，不把已有讲解或 Codex 验证当成用户已完整回答。


## 2026-10-28 Ch11：SM、shared 资源与 occupancy

### 今日完成任务

围绕 [CH11/occupancy.cu](../CH11/occupancy.cu)，复用 Ch10 的 shuffle 求和，只改变每 block 额外预留的 dynamic shared 字节数。用户要求 Codex 先后补全 occupancy 查询和启动参数两处 TODO，随后追问查询函数、预留的含义、warp 数的来源、静态 shared 的来源、驻留限制，以及 NCU 实测 occupancy 的计算与小数。两处实现和正式程序/工具验证均由 Codex 完成，没有用户个人运行、GUI 操作或完整独立复述的证据。运行方法见 [章节讲义](chapters/11_occupancy.md)，数据见 [正式日志](../reports/CH11/completed-2026-10-28.txt) 与 [原始指标 CSV](../reports/CH11/completed-metrics-2026-10-28.csv)。

### 基本概念

**固定求和任务，只增加每 block 的资源占用**

固定 N=262144、float32、grid=1024、block=256。每个 block 的 256 个线程处理连续 256 项，经 shuffle 和 shared 交接输出一个 partial；GPU 输出 1024 个片段和，由 CPU 逐片校验并汇总总和。对照的动态预留为 0/16384/32768 字节，额外空间故意不读写，kernel 的输入、算法、读写和线程组织不变。

```text
CPU 输入与 reference → H2D → 同一个 shuffle 求和 kernel → D2H → 逐片校验与 CPU 汇总
                                     ↑
                         每 block 额外预留 0 / 16 / 32 KiB
```

**查询容量与实际启动分别做什么**

<span style="color:red">用户提问：讲解一下 active_blocks_per_sm 这段的作用。</span>

```cpp
int blocks = 0;
CUDA_CHECK(cudaOccupancyMaxActiveBlocksPerMultiprocessor(
    &blocks, block_sum_shuffle, kBlock, dynamic_bytes));
return blocks;
```

该 host 函数回答“假设使用这个 kernel、每 block 256 个线程和指定 dynamic shared，一个 SM 在资源约束下最多能同时容纳几个 block”。blocks 保存查询结果，&blocks 是输出地址；后面三个参数指定 kernel、线程数和每 block 动态字节数。API 本身返回错误状态，由 CUDA_CHECK 检查；helper 最后返回 blocks。kernel 的静态 shared 和寄存器属性参与计算，不需手动重复传入。[CUDA Runtime API 12.9：Occupancy](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART__OCCUPANCY.html)

实际启动在另一个 helper 中完成：`launch_bytes=requested_bytes`，再传给 `block_sum_shuffle<<<kBlocks,kBlock,launch_bytes>>>(input,partial)` 的第三个启动参数。<mark>occupancy API 只查询容量，第三个启动参数才让每个 block 实际预留动态 shared；两处必须使用相同字节数。</mark> 只完成查询的历史阶段，16/32 KiB 查询已有结果，但实际 launch 仍均为 0，因此资源实验不能算通过。

**预留、静态 shared 与动态 shared 的来源**

<span style="color:red">用户提问：这里预留什么意思？只要有 block 就有 32 字节静态 shared 吗？这是 CUDA C 还是 Turing 规定的？</span>

预留表示 block 驻留时占用一份 shared 空间，执行期间供本 block 使用；即使没有读写，空间也占资源。block 结束后资源可供后续 block 使用。本例第三个启动参数是每 block 的额外字节数，不是全 GPU 的一次总分配，也不表示提前拷入了数据。

32 字节来自我们写的 `__shared__ float warp_partial[kWarps]`：kWarps=8，每个 float 为 4 字节，因此数组大小是 8×4=32。每个 block 都有自己的一份，保存它的 8 个 warp 和。<mark>32 字节是本 kernel 的静态 shared 用量，不是所有 block 的固定开销。</mark> CUDA C++ 提供按 block 独立的 shared 变量语义，数组大小由代码决定；Turing 规定硬件资源容量。其他 kernel 的静态 shared 可以为 0 或其他大小；本例编译和 Runtime 属性均确认 32 字节。

**为什么每 block 有 8 个 warp，每 SM 最多 32 个 warp**

<span style="color:red">用户提问：为什么每 block 有 8 个 warp，每 SM 最多 32 个 warp？</span>

本机 warpSize=32。每 block 的线程数由代码设为 256，因此 256/32=8 个 warp；线程 0..31 为 warp 0，32..63 为 warp 1，依次到 224..255 为 warp 7。若将 block 改成 128 线程，则为 4 个 warp，但本章保持 256 不变。

SM 是执行线程组的处理单元。本机 GTX 1650 / CC 7.5 每 SM 最多驻留 1024 线程，即 32 个 warp，这是硬件容量；整张卡有 14 个 SM，不能把全 GPU 的 grid 数量当成单个 SM 的驻留数量。驻留表示线程组已进入 SM 并占用资源，指令仍需调度，不保证所有 warp 同时发射。Turing 的 32 warp/SM 上限不能套用到所有架构。[CUDA 12.9：Turing Occupancy](https://docs.nvidia.com/cuda/archive/12.9.0/turing-tuning-guide/index.html#occupancy)

**为什么预留 16 KiB 后只能驻留 3 个 block**

<span style="color:red">用户提问：就因为给一个 block 预留了 16 KB，所以只允许同时驻留 3 个 block 吗？</span>

本例额外预留 16 KiB 后，每 block 还需加静态 32 字节。SM 的 shared 最大容量为 65536 字节；4×(16384+32)=65664，超过容量，3×(16384+32)=49248，才放得下。额外预留 32 KiB 时，2×(32768+32)=65600，也超限，因此只能放 1 个。额外预留为 0 时，shared 很小，但每 SM 的线程/warp 容量只允许 1024/256=4 个此类 block。

<mark>驻留上限必须同时满足线程、寄存器、shared 和 block 数等限制，最紧的资源约束决定结果。</mark> 上述字节加法是理解本例的容量推导；实际还涉及分配粒度和 shared/L1 配置，以 API/NCU 核对。不是“16 KiB 对应 3 个 block”的通用规则；若某 kernel 的 shared 总量恰好为 16 KiB，单看 64 KiB 容量可放 4 个，还需检查其余资源。

本例每 block 有 8 个 warp，理论 occupancy=理论驻留 block/SM×8/32，因此 4/3/1 个 block 对应 100%/75%/25%。它表示资源允许的上限，不等于实际 GPU 利用率或性能比例。

**正式实验现象与计时边界**

<span style="color:red">用户提问：给我具体的实验现象，并说明原理。</span>

以下重读 2026-10-28 正式证据，源码 SHA-256 与日志一致；本次总结没有重新编译、运行或采集。环境为 GTX 1650 / CC 7.5 / 14 SM、NVCC 12.9.86、NCU/Compute Sanitizer 2025.2.1.0，shape/dtype 与上文一致。

| 动态预留字节/block | API 驻留 block/SM | API / NCU 理论 occupancy | NCU 平均 active warp/SM | NCU achieved occupancy | 普通 Event 中位数 μs/次 |
| --- | --- | --- | --- | --- | --- |
| 0 | 4 | 100% / 100% | 23.570222 | 73.656944% | 29.926401 |
| 16384 | 3 | 75% / 75% | 16.451688 | 51.411524% | 30.604801 |
| 32768 | 1 | 25% / 25% | 6.217337 | 19.429179% | 45.705599 |

三组实际动态预留经 NCU 核对，静态 shared 均为 32 字节；每组 1024 个片段和 PASS、最大误差 0，CPU 汇总总和均为 -184。输入为可精确表示的小整数，计算不变，因此结果一致；不推广为一般浮点归约均须精确相等。memcheck（padding=32）、racecheck、synccheck 均零错误，racecheck 零 warnings；check、工具检查与 bench 均退出 0。

Event 先全量校验，再各预热 10 次、21 个样本，每样本批量启动 10 次并归一化到每次启动后取中位数；区间不含分配、传输、CPU reference/校验与汇总，可能含 host 提交间隙。Sanitizer、NCU 和普通计时分开运行，本次没有新做 NSYS、GUI 或 SASS 检查。

本轮 0/16 KiB 的耗时相近，32 KiB 比 0 KiB 约长 53%，没有因为理论 occupancy 降到四分之一就慢四倍。机制上，当一个 warp 等待数据时，更多驻留 warp 能提供更多就绪候选供调度，可能帮助利用等待时间；是否更快仍取决于访存、依赖与指令执行等因素。本报告还显示 shared 配置大小为 32768/65536/65536 字节，可能改变 L1 资源。<mark>资源对驻留上限的限制已由 API/NCU 证实；现有指标不能把全部耗时差归因于延迟隐藏或 occupancy。</mark> 不与历史临时版跨运行作优化 A/B，不推断固定加速比。

**NCU 实测 occupancy 怎样计算，为什么有小数**

<span style="color:red">用户提问：为什么实测 occupancy 低于理论值？NCU 的 occupancy 怎么计算，为什么会有那样的小数？</span>

本机 NCU 2025.2.1 的 Occupancy.section 将 Theoretical Occupancy 映射到 `sm__maximum_warps_per_active_cycle_pct`，将 Achieved Occupancy 映射到 `sm__warps_active.avg.pct_of_peak_sustained_active`，将 Achieved Active Warps Per SM 映射到 `sm__warps_active.avg.per_cycle_active`。硬件计数累计 active warp，按 SM 活跃周期归一化并跨 SM 聚合，再换算为最大容量百分比；不是用 CPU 提交到同步结束的整段时间，也不是每条指令参与线程数或发射率。[NCU：Metrics Entities](https://docs.nvidia.com/nsight-compute/ProfilingGuide/index.html#metrics-entities)

对本机报告可直接核对：achieved occupancy=平均 active warp/SM÷32×100%。例如 23.570222/32×100%≈73.656944%。`.avg` 对应跨 SM 实例平均，`.per_cycle_active` 对应每个单元活跃周期归一化，`.pct_of_peak_sustained_active` 再表达为活跃周期口径的峰值百分比，不把 active 与 elapsed 周期混用。

每一时刻的 warp 数是整数，但不同周期和 SM 的数量可不同，所以平均值有小数。仅作教学示意：一个 SM 有 80 个活跃周期驻留 8 个 warp，另 20 个周期驻留 1 个，则平均为 (80×8+20×1)/100=6.6 个，对应 6.6/32×100%=20.625%。这不是本次原始逐周期轨迹，不把示例数字当实测。

理论上限不保证一直填满。block 进入/完成、补入后续 block、grid 收尾和 warp 结束时机都会影响平均驻留数量；本 kernel 在 shared 交接后只有 warp 0 继续合并并写出，其他 warp 可以先结束，而 block 的 shared 资源尚未释放。这是源码可解释的降低平均 active warp 数的机制，但现有报告未量化各因素贡献，不能直接认定它是主要原因。

<mark>等待内存或 barrier 的 warp，只要仍在驻留且尚未结束，仍可计入 active warp；没有发射指令不等于 occupancy 下降。</mark> 需要立即可执行的 warp 数与发射情况时，应看另外的就绪/调度指标，本章不追加完整 stall 分析作为首轮门槛。

### 踩坑记录

用户真实疑问集中在“预留是否使用空间”“32 字节是不是架构固定开销”“8 warp/block 与 32 warp/SM 分别由谁决定”“只预留就能限制 block 数吗”和“百分比为什么不是整数档位”。已结合数组、启动参数、容量加法和平均值解释，不把提问本身写成错误实现或独立掌握。

只补 TODO(1) 的阶段，求和可全部正确，但实际动态预留仍为 0，整个资源实验退出 1；这是练习未完成，不是 Sanitizer 检出错误。两处均补全后实际资源与查询一致，程序退出 0。未见用户编译失败、个人 NCU/GUI 操作或完整独立复述的证据，不编造这些经历。更多平均值小数位不代表更高的实验稳定性，耗时与架构结论也不能跨机器直接泛化。

### 八股自测

不看答案，指出查询函数的四个参数与第三个 launch 参数分别做什么，说明静态 32 字节来自哪行代码；用 256 线程、warpSize=32 和每 SM 的资源上限，推导三种预留量为什么得到 4/3/1 个 block 和 100%/75%/25% 理论 occupancy。

再解释 NCU 的 23.570222 个平均 warp 如何对应 73.656944%，为什么平均值可以有小数、等待内存的 warp 仍可能计入 active，以及本次 occupancy 降到四分之一为什么不意味着耗时变成四倍。以上是待独立回答的验收问题，不将已讲解或 Codex 验证计为用户已掌握。

## 2026-10-28 Ch12：分块矩阵乘法与数据复用

### 今日完成任务

围绕 [CH12/tiled_gemm.cu](../CH12/tiled_gemm.cu) 对照 naive 与单层 shared tiled FP32 GEMM。两处装载/累加练习按用户要求由 Codex 实现和验证；用户阅读参数及枚举语法，主动询问 base 和分块数据流，随后正确复述了“一个线程负责一个输出、A/B 小块沿 K 移动、各轮行列片段乘加累积到 sum”的主线。该复述是局部理解证据，不替代个人实现、运行及对同步和缓存的完整解释。相关工程与验收记录统一见 [RECORD](RECORD.md)。

### 基本概念

**从输出位置理解矩阵乘法**

A[M,K] 与 B[K,N] 相乘得到 C[M,N]。每个输出是 A 的一行与 B 的一列的点积：`C[row,col]=Σ A[row,q]*B[q,col]`，q 从 0 到 K-1。行连续存储时，A 的下标是 `row*K+q`，B 是 `q*N+col`，两者行步长不同。

一个线程始终计算同一个 C[row,col]，一个 16×16 block 的 256 个线程负责 C 的一个固定 16×16 区域。主实验 M=N=K=256，grid=(16,16)，共 256 个 block，输出 65536 项。block 的 x 对应输出列、y 对应输出行。naive 每线程直接读取 global 完成全部 K 项；tiled 用 shared 协作安排输入复用，每线程的输出归属不变。

**参数、算法选择与 C++ 语法**

<span style="color:red">用户提问：讲解一下参数设置；这是什么语法；什么叫作用域枚举？</span>

`kTile=16` 同时控制本例的 block 两维、输入小块两维和每轮 K 分段长度；两个 float[16][16] 数组共占每 block 2048 字节静态 shared。它是固定教学配置，不代表硬件要求或性能最优。`constexpr` 表示这里的值可在编译期确定。

`kWarmup=10` 是每种方法的预热次数，不进入统计；`kSamples=21` 表示取 21 个计时样本；每个样本用一对同 stream Event 包住 `kBatch=5` 次启动，时间除以 5 后排序，取第 11 项作为中位数。`kAtol=kRtol=1e-4` 只用于结果判断：`abs(gpu-ref)<=1e-4+1e-4*abs(ref)`。绝对容差照顾接近零的值，相对容差随参考值大小变化；NaN/Inf 拒绝。它们不改变 kernel 的计算精度或过程。

`enum class Method { Naive, Tiled };` 定义算法选择类型，作用域枚举将成员名放在类型内部，使用 `Method::Naive` 或 `Method::Tiled`，不同枚举可以各有自己的同名成员。`name(Method method)` 将选择转换为输出文字；`const char*` 在此返回只读字符串，函数前 `static` 限定当前源文件使用，`条件 ? 值1 : 值2` 在条件成立时选前者、否则选后者。

**base 怎样让同一输出分轮累加**

<span style="color:red">用户提问：没太看懂分块逻辑，base 是什么？每线程负责 C 的一个位置，block 有两个 shared 输入切片，但理不清关系。</span>

<mark>C 的输出 tile 固定，base 表示本轮在 K 维的起点：A 小块向右移动，B 小块向下移动。</mark> 主实验 base=0,16,...,240，共 16 轮；每轮覆盖 16 项乘加，两个 shared 数组大小保持不变，内容逐轮替换。

只看第一个 block，表中区间都含两端：

| base | A 小块的全局范围 | B 小块的全局范围 | 每个输出本轮累加的 K 项 |
| --- | --- | --- | --- |
| 0 | 行 0..15、列 0..15 | 行 0..15、列 0..15 | 0..15 |
| 16 | 行 0..15、列 16..31 | 行 16..31、列 0..15 | 16..31 |
| 240 | 行 0..15、列 240..255 | 行 240..255、列 0..15 | 240..255 |

每线程每轮只搬一个 A 元素和一个 B 元素，256 个线程共同填满两个 tile。下式省略边界判断，以二维数学坐标说明源码的一维地址：

```text
装载：A[row,base+tx] → a_tile[ty][tx]
      B[base+ty,col] → b_tile[ty][tx]

计算：a_tile[ty][p] × b_tile[p][tx]
    = A[row,base+p] × B[base+p,col]，p=0..15
```

例如第一个 block 的线程 (ty,tx)=(2,3) 一直负责 C[2,3]。base=0 时它搬 A[2,3] 和 B[2,3]；计算 p=5 时却读取 A[2,5] 和 B[5,3]，由线程 (2,5) 和 (5,3) 分别装载。<mark>线程负责搬的元素与计算所需的全部元素不同；合作装载后，每个线程读取自己需要的 shared 行列。</mark> 完整 tile 中，每个 A 元素供同一输出行的 16 个线程使用，每个 B 元素供同一输出列的 16 个线程使用。

base=16 后，同一线程累加 A[2,16..31] 与 B[16..31,3] 的贡献。`sum` 是每线程私有变量，定义在外层循环之前，只初始化一次；16 轮的贡献累积保留，直到 K 全部处理完才写 C。shared 是每 block 的公用输入工作区，sum 是每线程自己的输出累加值。

用户随后主动复述：一个 block 负责一个 tile，外层循环对应 A tile 向右、B tile 向下移动，每线程把当前行列片段的乘加加入 sum，最终得到整行与整列的点积。该主线正确；已进一步明确 block 负责的是固定的 C tile，以及每线程每轮只装载两个输入元素。

**为什么每轮需要两次 barrier**

装载后的 `__syncthreads()` 保证本 block 所有线程写完当前 shared，再允许其他线程读取；内层计算后的第二次 barrier 保证所有线程读完，才允许下一轮覆盖相同 buffer。两个 barrier 分别保护“写完再读”和“读完再覆盖”，不能因同一线程自身写读有序就省掉跨线程协调。

尾部用例 M=37,N=53,K=29 同时覆盖三个维度不足整块的情况。A 独立判断 row 与 base+tx，B 独立判断 base+ty 与 col，越界位置填零；输出最后按 row/col 边界写出。输出越界的线程仍可能负责有效输入装载，且需要参加 barrier，不能在 tiled 开头照抄 naive 的提前 return。CPU 的 cudaDeviceSynchronize 等待 kernel 完成，也不能代替内部两次同步。

**实验现象：正确、较快，但请求数与 DRAM 流量不同**

<span style="color:red">用户提问：从实验现象看结果怎样？为什么 DRAM 读取量从 537728 字节变为 528000 字节？</span>

本次总结只重读已有证据，未重新运行。正式源码 SHA-256 与 [正式补全日志](../reports/CH12/completed-2026-10-28.txt) 一致。该次环境为 GTX 1650 / CC 7.5 / 14 SM、NVCC 12.9.86、Compute Sanitizer 2025.2.1.0；主 shape 为 M=N=K=256、float32、block/grid 均 (16,16)。

| 正式版结果 | naive | tiled |
| --- | --- | --- |
| 主 shape 的 65536 个输出 | PASS，最大绝对/相对误差 0 | PASS，最大绝对/相对误差 0 |
| 尾部 shape 的 1961 个输出 | PASS，最大绝对/相对误差 0 | PASS，最大绝对/相对误差 0 |
| 每 block 静态 shared 字节 | 0 | 2048 |
| 普通 Event 中位数 μs/次 | 157.452798 | 107.673597 |

正式版 memcheck（padding=32）、racecheck、synccheck 均零错误，racecheck 零 warnings；check、工具命令与 bench 均退出 0。输入是 /16 的小数，本例长度下结果可以精确表示，误差 0 不推广为任意 FP32 GEMM 的要求。普通计时为 warmup=10、samples=21、batch=5，naive/tiled 比值约 1.462，tiled 耗时降低约 31.6%；区间不含分配、H2D/D2H、CPU reference/校验，可能含 host 提交间隙，不等于端到端收益。

以下访存指标来自此前临时补全版的独立 NCU 预检，不是正式补全版重新采集结果；原始表见 [CSV](../reports/CH12/preflight-metrics-2026-10-28.csv)，采集命令见 [预检日志](../reports/CH12/preflight-2026-10-28.txt)。

| NCU 预检指标 | naive | tiled |
| --- | --- | --- |
| L1/TEX global load 请求数 | 1048576 | 65536 |
| L1/TEX global load sectors | 2097152 | 261594 |
| DRAM 读取字节 | 537728 | 528000 |

请求数减少为 1/16、sector 约为 1/8，而 DRAM 读取接近。A 与 B 各 262144 字节，合计 524288 字节（512 KiB）；报告中 L2 容量为 1048576 字节（1 MiB）。输入规模为缓存复用提供条件：naive 的重复 global 请求也可能由缓存满足，不必每次回到 DRAM。<mark>global load 请求与 DRAM 实际读取处在不同层次；两种 DRAM 读数都接近一份 A+B，与缓存减少重复显存读取的解释一致。</mark> 容量足够本身不是命中率证明，也不能反推出所有具体访问都只读取一次。

两次 DRAM 读数相差 9728 字节，约为 naive 读数的 1.8%。现有数据未拆分这段差额，也没有重复采集来确认稳定性，不能认定某段代码精确、省下且稳定地产生这 9728 字节收益。CSV 的 Kbyte 为十进制，例如 537.728 Kbyte=537728 字节；A/B 大小的 KiB 则按 1024 换算。

NCU 的设备内存字节描述 L2 与 DRAM 间的数据传输；默认在 replay 前清缓存，kernel 执行期间仍可正常填充并命中缓存。此次各 kernel 3 passes，缓存控制没有关闭 kernel 内的缓存；该状态也不等于普通预热 Event 的状态。语义参考 [NCU：Device Memory](https://docs.nvidia.com/nsight-compute/ProfilingGuide/index.html#device-memory) 与 [Cache Control](https://docs.nvidia.com/nsight-compute/ProfilingGuide/index.html#cache-control)。

shared 显式复用减少重复 global 请求，但增加 shared 读写和同步；缓存、指令与资源差异也会影响性能。现有结果没有量化各因素对耗时的贡献，不能将约 1.46 倍加速全部归给 DRAM 流量，也不能由请求减少 16 倍推断加速 16 倍。数据只适用于本机、本输入与对应运行；普通计时与 profiler 分开，不把正式版与历史临时版跨运行作优化 A/B。

### 踩坑记录

用户实际困惑集中在参数用途、作用域枚举、base 沿哪个维度移动，以及线程装载的两个数如何参与行列片段计算。随后分块累加主线已被正确复述；两次 barrier、尾部线程参与和缓存层次已讲解，但没有完整独立复述或个人操作的证据。不把提问编造成实现错误，也不把 Codex 补全记成用户独立写出。

最初骨架 tiled 输出为零，数值 FAIL 且拒绝计时，属于练习未完成；当前正式代码已补全并验证。未见用户个人编译失败、Sanitizer 报错或 GUI 采集经历，不补写这些事件。DRAM 字节接近输入总量不代表所有 global 请求直接访问显存，也不代表 shared 优化没有收益；细小差额的来源和稳定性尚未验证。

### 八股自测

任选一个线程，指出它负责的 C[row,col]，说明 base=0 和 base=16 时分别装载哪两个输入、内层 p=5 时从哪些线程写入的 shared 位置取数，以及 sum 为什么能保留所有轮次贡献。再解释两个 barrier 分别保护什么，为什么输出越界的线程仍可能需要装载和同步。

结合本次 157.45/107.67 μs、请求减少 16 倍和 DRAM 约 0.53 MB 的结果，说明 shared 复用发生在哪里、naive 为什么也能利用缓存，以及普通 Event 和 NCU 分别测了什么。以上用于后续独立回答，不额外扩展为 cuBLAS、Roofline、Tensor Core 或多层 GEMM 调优。


## 2026-11-02 Ch13：Host 异步与计时边界

### 今日完成任务

本章围绕 [CH13/host_async.cu](../CH13/host_async.cu) 比较 CPU 提交、CPU 等待完成和 GPU Event 三种时间。host、输入、reference 和测量框架由 Codex 提供；唯一等待 TODO 已按用户要求于2026-10-29补全为 `return cudaDeviceSynchronize();`，正式验证及2026-11-02重跑、两次NSYS采集由Codex完成。本次总结只重读源码、日志和CSV，不重新编译、执行GPU或采集。

用户主动询问环境开关、循环次数、measure流程、Event标记为何能包住kernel、同步与查询的区别、三个时间为何不能相加，并要求真实实验和GUI阅读路线。随后提供 `experiment-2026-11-02.nsys-rep` 的GUI截图，选中第五次repeated_add并询问上下蓝色条及Pin row。这证明已打开报告并定位目标kernel，尚不等同于个人编译/采集或完整独立解释；工程与验收证据统一见 [RECORD](RECORD.md)。

### 基本概念

**从一个线程的工作理解实验参数**

<span style="color:red">用户提问：kRepeats这个参数是什么含义？</span>

固定N=65539、float32、block=256、grid=257，每个有效线程负责一个输出，先令sum=a[i]，再将b[i]累加2048次，得到c[i]=a[i]+2048*b[i]。kRepeats表示一次kernel内每线程的循环次数，不是启动2048次kernel。重复运算只用于放大GPU执行区间，使提交与完成的差别更容易观察；末尾block只有3个有效线程，其余线程由边界判断退出。输入为小范围/16的数，使本例中间和可精确表示，误差0不推广为任意FP32实验的要求。

<span style="color:red">用户提问：这里的blocking是干啥的？</span>

`const char* blocking = std::getenv("CUDA_LAUNCH_BLOCKING");` 读取外部环境配置，未设置返回nullptr，设置后指向值字符串；三元表达式有值就打印该值，否则打印unset。这行不修改CUDA配置，也不执行同步。CUDA_LAUNCH_BLOCKING=1用于调试时强制同步kernel启动，未设置或为0时保留正常异步行为；程序拒绝非零配置，避免改变本章实验前提。该参数不是block维度，也不能与CPU等待函数混为一谈。

**提交返回与执行完成是两个边界**

<span style="color:red">用户提问：当前理解CPU和GPU执行是异步的，launch提交后CPU会继续执行下一条指令，对吗？</span>

host异步描述CPU调用返回与GPU工作完成的关系。launch提交任务并检查启动错误后，CPU线程可以继续；GPU可能已经开始，也可能仍在等待调度。这里用“CPU线程继续执行”即可，无需引入“CPU stream”。本例只有一个默认CUDA stream，其中的工作保持顺序，不因host异步就让后面的stop越过前面的kernel。

<mark>launch返回只代表CPU走过了提交调用，不能单凭这一点判断GPU是否完成；异步也不保证每一次调用返回时GPU都尚未完成。</mark> `cudaGetLastError()`检查启动错误，不等待kernel完成。即使后面D2H回读最终得到正确输出，也不能证明之前已经停止的CPU计时包含了GPU执行。

**measure的两个CPU终点与一个GPU区间**

<span style="color:red">用户提问：完成TODO，并告诉我当前measure是如何测量时间的；为什么start Record在t0之前？</span>

关键顺序如下，省略状态检查：

```cpp
cudaDeviceSynchronize();        // 先等前序工作，位于本次CPU起点之外
cudaEventRecord(start, 0);       // 提交GPU起点请求
const auto t0 = Clock::now();
launch(a, b, c);                 // 包含启动错误检查
const auto t_submit = Clock::now();
cudaEventRecord(stop, 0);        // 提交GPU终点请求
const cudaError_t wait_status = wait_on_host();
const auto t_complete = Clock::now();
```

start Record放在t0前，是为了把CPU提交start请求的开销排除在CPU测量外；不是CUDA强制要求，也不保证GPU记录start时间戳一定先于CPU记录t0。两个CPU时间共用t0，改变的是终点；GPU Event使用另外一对设备时间点。

| 结果 | 起点与终点 | 覆盖范围 |
| --- | --- | --- |
| launch_us | t0→t_submit | CPU提交kernel及启动错误检查 |
| complete_us | t0→t_complete | 上述提交，再加stop请求提交和设备完成等待等host开销 |
| event_us | GPU经过start→GPU经过stop | 两个设备标记之间的工作与可能的间隙 |

`cudaEventElapsedTime(&ms,start,stop)`将Event区间写为毫秒，乘1000后才是event_us的微秒。两个CPU端点之后才查询Event、读取耗时、回读和校验，分配与输入传输也位于计时之外；complete_us不是整个程序的端到端耗时。bench先校验、预热3次和试测，再收集21个单次样本，对三列分别取中位数。

**stop请求可以提前排队，设备终点仍在kernel之后**

<span style="color:red">用户提问：kernel还没执行完就直接打stop标记，start和stop之间有什么意义？是不是没有记录GPU执行耗时？</span>

“打标记”需要区分CPU提交记录请求与GPU真正记录时间。CPU快速把start请求、kernel请求、stop请求依次交给同一stream；GPU按顺序经过它们。stop Record调用不需要CPU先等待kernel，它表达的是“轮到这个位置时记录终点”，不是“CPU现在就给GPU工作盖上结束时间”。

```text
CPU提交顺序：start请求 → kernel请求 → stop请求 → host等待
GPU执行顺序：记录start → 执行kernel → 记录stop
```

<mark>CPU可以在kernel尚未完成时提交stop，但GPU必须完成该stream中前面的kernel，才会到达stop标记。</mark> Event名称只是程序变量名，测量范围由Record位置和stream顺序决定，并不自动代表整个GPU进程的开始/结束；若中间放两个kernel，两者都进入区间。

Event包含kernel，但不保证等于纯kernel执行时间。例如GPU已记录start，CPU尚未提交好kernel，这段间隙进入Event；不能把GPU标记时间戳等同于CPU调用Record的时刻。[CUDA 12.9 Event说明](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART__EVENT.html)

**等待、状态码和查询分别做什么**

<span style="color:red">用户提问：wait_status = wait_on_host()是干啥的？cudaEventQuery(stop)和后面的if是什么意思？</span>

赋值先执行右侧wait_on_host()，其内部cudaDeviceSynchronize()让CPU等到当前设备此前请求的工作完成，返回后再把状态码存入wait_status；状态码不是耗时，const表示初始化后不修改。CUDA_CHECK(wait_status)检查成功或执行阶段错误。这个host等待与block内__syncthreads()用途不同。

cudaEventQuery(stop)只观察该Event捕获的工作是否完成，不主动等到完成；成功返回cudaSuccess，未完成返回cudaErrorNotReady。若未完成，当前防护分支在t_complete之后先安全等待，再返回false拒绝当前样本；计时后的收尾不能修复已结束的区间。正常完成设备同步并成功返回后，这个NotReady分支不应进入；查询也不能代替对等待实现的检查。[CUDA 12.9同步说明](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART__DEVICE.html)

**为什么三种时间不能相加**

<span style="color:red">用户提问：ms、launch_us、complete_us分别是什么？为什么三者加起来不一致？</span>

<mark>complete_us已经包含launch_us，GPU同时在自己的时间线上推进，这些不是互不重叠的三个连续阶段。</mark> 单个样本有精确的CPU区间关系：`complete_us = launch_us + us(t_submit,t_complete)`；Event不等于第二项，因为GPU与CPU的端点不同、工作可能重叠，还有host调用和等待返回开销。三列中位数可能来自不同样本，不能相减给出精确等待时间，更不能把“提交比完成快”称为算法加速。

**本轮真实数据：CPU提交、kernel、Event分别阅读**

<span style="color:red">用户提问：给我真实的实验结果记录，并讲解数据如何体现本章内容；119.928、159.713、250.944这三个有什么区别？</span>

本次总结重读2026-11-02的证据，没有重新采集。当前源码SHA-256与正式日志一致；记录环境为GTX1650 / CC7.5 / 14SM、NVCC12.9.86、Compute Sanitizer2025.2.1.0、NSYS2026.4.1，CUDA_LAUNCH_BLOCKING unset。全部65539项正确、最大绝对误差0、完成边界PASS、memcheck零错误。

以下普通bench与profiler分开运行，warmup=3、samples=21、batch=1，完整输出见 [正式实验日志](../reports/CH13/experiment-2026-11-02.txt)：

| 普通bench，各列独立中位数 | μs |
| --- | --- |
| CPU launch_us | 14.818000 |
| CPU complete_us | 234.205000 |
| GPU event_us | 209.376007 |

CPU约15μs便走过提交段，但Event约209μs、走到完成边界约234μs；现象与提交返回不等于GPU完成相符。不要把这组数与下面的独立采集混算，也不推广为固定延迟或性能比例。

原NSYS报告中同一个目标样本（第五次kernel，Correlation ID=141）的三种不同范围如下，原始关联见 [CSV](../reports/CH13/experiment-2026-11-02-timeline.csv)：

| 原trace的观测范围 | μs | 证据位置 |
| --- | --- | --- |
| CPU开始调用start Record→stop Record返回 | 119.928 | CPU两个API条目的端点差，不等于launch_us |
| GPU kernel开始→结束 | 159.713 | CUDA HW kernel条的Duration |
| GPU Event区间 | 250.943989 | 当次程序输出，原报告未采设备Event标记 |

CPU stop Record调用自身只持续13.516μs，但Event仍包含整个kernel区间；说明提交stop请求与设备到达stop是不同动作。Event比kernel区间长，可能含提交、排队、调度及标记边界间隙，本轮没有量化每个因素的贡献。GUI无法从两个CPU Record端点直接得到设备Event区间，也没有单独记录Clock::now()的三个时间点。

另一次启用设备EventTrace的报告见 [标记CSV](../reports/CH13/events-2026-11-02-markers.csv)：GPU start/stop标记间隔170.169μs，中间kernel160.029μs，程序当次Event读数171.552002μs。这组与原250.944μs属于不同运行，不要求数字相同。新报告的CPU同步返回时间戳比GPU结束时间戳早95.177μs，而同步与查询均成功，存在跨轨迹对齐不一致；只用它观察GPU内部标记与区间，不解释为同步提前返回，不作跨轨迹精确耗时分解。工具兼容与报告路径见讲义和ENVIRONMENT，用户首轮不增加环境排障任务。

**GUI的上下蓝色块与Pin row**

<span style="color:red">用户提问：选中第五个repeated_add后为什么有两个蓝色块、位置不一样？上面CUDA HW是kernel，下面CUDA API是CPU launch吗？Pin row有什么用？</span>

用户截图中，上方CUDA HW的第五次repeated_add是GPU执行，右侧Duration=159.713μs；下方host_async线程的CUDA API条是CPU启动调用，NSYS可用目标kernel名字显示它。选择一个会关联高亮另一个，浅青背景是选择范围，不是额外计算。CPU调用较早返回，GPU之后执行，是该截图中的现象；不推广为所有kernel必须在launch返回后才开始。

上方Kernels汇总行与按名称分组的100.0% repeated_add行还各画了一条完全对齐的kernel条，它们是同一次执行在不同层级的重复展示，不是启动两次；百分比也不是本次GPU利用率或occupancy。阅读时以单次事件、Duration和Correlation ID对应，不把汇总图层的重复条目计成额外kernel。

Pin row把某行固定在视口，滚动其他行时仍能看到它，便于同时比较CPU提交与GPU执行。它只改变显示方式，不修改数据或事件的时间位置。用户截图已能同时显示两行时，可以不固定。用户打开原报告和选中目标的截图是实际GUI证据；尚无其在带Event标记的新报告中定位两标记或个人采集的证据，不补写这些操作。

### 踩坑记录

真实疑问主要在把CPU提交Record请求理解为GPU立即记录时间，以及把CPU提交段、GPU执行段与host完成区间当作可相加的阶段。已结合源码顺序、三个测量边界、同一次NSYS样本与用户截图澄清；不把仍在提问等同于独立掌握，也不编造用户实现错误。

原骨架曾因等待TODO未完成而拒绝计时，但数值可正确；当前正式代码已经补全，不能继续把旧INCOMPLETE当成当前故障。GUI图中的CPU launch有时显示kernel名称，汇总行还可能重复展示同一GPU执行，需要按轨迹和关联读取。Pin row只是视图辅助，不是同步操作。设备标记补采报告有跨轨迹对齐不一致的明确边界，不用显示异常推翻已核对的API语义。

### 八股自测

不看答案，按measure顺序解释CPU提交start、记录t0、launch返回、提交stop、设备实际记录两个Event和CPU等待返回分别发生什么；说明为什么stop可以提前排队却仍能包住kernel，以及start Record放在t0前排除了哪部分CPU开销。

再结合14.818/234.205/209.376μs，说明三种时间为何不能相加、complete为何不是整个程序耗时；面对GUI截图指出CPU launch、GPU kernel、汇总行重复显示与同步等待各在哪里，并解释查询为什么不等于等待。以上用于后续独立验收，不新增多stream、拷贝重叠或NVTX改造门槛。

## 2026-11-02 Ch14：Stream 队列与独立任务并发

### 今日完成任务

本章在 [CH14/streams.cu](../CH14/streams.cu) 中用两个独立的向量累加任务，对照同一 stream 与两条 stream 的执行。每任务4099项、float32、block=256、grid=17、每线程8192次累加；两个模式只改变任务B的目标stream，不改变计算内容。用户要求“完成TODO1和TODO2”，两处实现与正式编译、校验、memcheck及计时均由Codex完成。用户随后要求结合结果解释stream作用，并提供NSYS GUI截图询问默认队列中的Memory活动；这属于实际读图交流，不等同于个人实现或采集已完成。

### 基本概念

**Stream 管的是工作顺序**

<span style="color:red">用户提问：stream的作用是什么？从实验结果讲解本例中stream起到的作用。</span>

stream可以理解为GPU工作的有序队列，能组织kernel、内存拷贝和填充等任务。同一队列里的普通任务按提交顺序执行；没有额外依赖的不同队列可以独立推进，实际是否重叠由设备能力、资源和调度决定。<mark>同stream保证先后，不同stream提供并发机会；stream不固定对应某个SM，也不保证更快。</mark> [CUDA 12.9 Streams](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#streams)

```text
same： s0：A → B
split：s0：A
       s1：B    （可以重叠，实际看时间线）
```

本例A使用a/b/c的前4099项，B的三个指针分别加上kN，使用后4099项。B的block0/thread3局部索引仍为3，实际写整个c数组的第4102项；A的对应线程写第3项。因此二者没有数据读写依赖，可以安全地放到不同队列。本章不演示B读取A结果的情况，那需要另外建立依赖。

**创建配置、队列句柄和启动目标是三个环节**

<span style="color:red">用户提问：s0/s1创建后的检查是干啥的？flags是干啥的？“不与legacy默认stream隐式同步”是什么意思？</span>

`cudaStream_t s0, s1`保存队列句柄，可理解为后续指定队列的标识；把`&s0`传入创建函数，是让它将新队列句柄写回s0。当前`create_work_stream()`返回`cudaStreamCreateWithFlags(stream, cudaStreamNonBlocking)`的状态，main检查返回值并负责最终销毁。

flags是创建队列时的行为选项。`cudaStreamGetFlags(s0, &flags0)`将查到的配置写入flags0，函数返回的状态交给CUDA_CHECK检查；查询本身不改变配置。`streams_ready`先检查s0/s1都不是nullptr且互不相同，再检查两者的flags都符合本章的nonblocking要求。nullptr在本例是默认stream占位，不代表默认队列本身无效。

“隐式同步”指代码没显式写等待，CUDA仍按默认规则安排了等待。例如本项目使用legacy默认stream时，先在默认队列提交A，再往普通创建的队列提交B，会有默认同步规则让B等A。`cudaStreamNonBlocking`让新队列不参与与legacy默认队列的这层隐式同步。<mark>NonBlocking不会取消默认stream，也不会取消显式同步等待，更不等于保证并发。</mark> [CUDA 12.9 Stream配置](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART__STREAM.html)

创建后还要在kernel启动时指定队列。当前`launch()`将传入stream赋给target，放在`<<<grid, block, 0, target>>>`的第四项，并返回实际使用的target供路由检查。第三项0表示动态shared字节数。两种模式都创建相同配置的s0/s1，本实验改变的是B的启动目标，未单独对照NonBlocking选项的性能。

**run_pair：先提交两个任务，再等待它们都完成**

<span style="color:red">用户提问：讲解run_pair这一段。</span>

函数先等待前序工作结束，用cudaMemset将输出的每个字节填为0xff，在本例float数组中形成NaN哨兵，便于校验发现漏写；再等待填充完成。这些准备位于计时之外。`split ? s1 : s0`决定B的目标队列，然后按以下顺序执行：

```text
记录t0 → 提交A到s0 → 提交B到指定队列
       → 等A实际所在队列 → 若B在另一队列，再等那条队列 → 记录t1
```

<mark>两个launch之间没有host等待；CPU等s0时，已经提交到s1的独立B仍能推进。</mark> 同队列时只需同步一次，因为等待覆盖该队列此前提交的两个kernel。`used_a/used_b`保存实际队列，不是计算结果；`run_pair()`返回值检查两条显式队列及启动目标是否符合要求，数值正确性在函数外检查，是否并发看GPU时间线。

`double& host_us`是输出参数，函数将`t1-t0`换算成微秒写回。host_pair包含两次提交、启动错误检查及完成等待；分配、输入传输、哨兵准备、输出回读和CPU校验在外。它不是单kernel的GPU时间，也不是整个程序耗时；本章不拿单条队列的Event终点代表两队列都完成。

**实验结果：耗时变化和GPU重叠分别看**

本次总结重读既有证据，未重跑实验。当前源码SHA-256与 [正式补全日志](../reports/CH14/completed-2026-11-02.txt)一致。日志环境为GTX1650 / CC7.5 / 14SM、NVCC12.9.86、Compute Sanitizer2025.2.1.0，CUDA_LAUNCH_BLOCKING unset；same/split队列配置及路由通过，各8198项全量正确、最大绝对误差0，memcheck零错误。

正式版普通bench先校验、预热3次，再收集21个单次pair样本，每个样本在计时外回读校验：

| 模式 | 任务放置 | host_pair中位数 μs |
| --- | --- | --- |
| same | A/B都放s0 | 173.116 |
| split | A放s0，B放s1 | 129.053 |

本轮双队列完成整对工作的host区间较短，不能仅凭这个差值证明GPU重叠或量化并发的全部贡献。独立NSYS证据来自此前临时完整补全版，未冒充正式版新采集；以各报告目标A的GPU开始时刻为0，既有 [目标区间CSV](../reports/CH14/preflight-2026-11-02-timeline.csv)为：

| 模式 | A/B的stream ID | A的GPU区间 μs | B的GPU区间 μs | 重叠 μs |
| --- | --- | --- | --- | --- |
| same | 13 / 13 | 0～69.276 | 75.740～144.760 | 0 |
| split | 13 / 14 | 0～69.823 | 3.904～102.943 | 65.919 |

same中B在A结束后开始；split中A尚未结束，B在3.904μs已经开始，直接显示那次采集的GPU执行区间发生交叠。整对GPU跨度分别144.760/102.943μs。<mark>普通计时描述这轮host完成区间，NSYS描述另次采集的GPU区间；二者不能拼成一次运行或直接相减。</mark> 该结果不说明每个SM上如何分配任务，也不保证换任务后仍有同样收益。原始报告及完整边界见 [讲义](chapters/14_streams.md)。

**默认队列为何仍有Memory活动**

<span style="color:red">用户提问：为什么NSYS关于Memory还有一个Default stream？之前launch没有指定具体stream或指定stream 0，0就是默认的吗？</span>

用户截图显示Stream13、Stream14中的repeated_add，以及Default stream7上的Memory活动，下方还有CPU的cudaMemcpy调用。本例只将两个计算kernel明确指定到s0/s1，输入上传、输出填充和结果回读仍调用未指定stream的cudaMemcpy/cudaMemset，因此仍走默认队列。只读复核已有split SQLite，Memcpy与Memset活动的streamId均为7。不能把Memory行理解为kernel每次读取a/b时另建一条队列。

在本项目当前编译方式下，`kernel<<<grid, block>>>(...)`与`kernel<<<grid, block, 0, 0>>>(...)`等价：第四项0表示默认stream，第三项0仍是动态shared字节数。报告中的Default stream7与代码默认句柄0属于不同编号表达，不要求数值相同。<mark>创建显式队列不会把所有CUDA操作自动搬过去，未指定队列的操作仍使用默认stream。</mark>

本例在提交kernel前显式等哨兵准备完成，在回读前显式等两队列完成，保证内存操作与计算之间的正确顺序。截图可以证明用户已经接触相应GUI轨迹，不能据此认定个人编译、运行、采集或完整独立解释全部完成；不从截图推定报告文件名、GUI版本或每个色块的具体活动，准确类型以tooltip及报告记录为准。

### 踩坑记录

本章真实疑问集中在stream的作用、flags与NonBlocking含义、配置检查、run_pair等待顺序，以及默认stream为何出现在内存轨迹中。已结合源码与证据解释；这些提问不等同于用户写错代码或已独立掌握，不补造调试经历。

原骨架的两处TODO已由Codex补全，当前正式版应PASS，不能继续把历史骨架退出1当作现有故障。数值正确只说明输出正确，配置/路由检查只说明队列选择符合要求，GPU区间交集才是那次采集发生重叠的直接证据。创建队列、选择启动目标与CPU等待是不同动作；NonBlocking也不是让所有同步函数都立即返回的开关。

### 八股自测

不看代码，解释s0/s1的创建、flags查询、第四个启动参数和cudaStreamSynchronize分别做什么；画出same/split中A/B的队列关系，说明为何B不读A的结果，以及为什么“先提交两个任务，再依次等队列”仍有并发机会。

再结合173.116/129.053μs与NSYS的65.919μs重叠，分别说出两类数据能证明什么；指出GUI里的两个计算stream和默认stream内存活动，解释代码的stream0、报告ID7以及启动配置两个0的区别。以上用于后续独立验收，不扩展跨stream Event、pinned memory、传输流水或SM资源调优。

## 2026-11-05 Ch15：Event 接力、双缓冲与流水执行

### 今日完成任务

围绕 [CH15/event_pipeline.cu](../CH15/event_pipeline.cu) 复盘chunk、slot、stream与Event的关系，按源码顺序解释run_batch，并用正式实验检验串行/流水对照。骨架于11月2日生成，两处TODO于11月3日按用户要求由Codex补全；今天结合用户真实疑问继续讲解，并由Codex运行正式版正确性、普通计时和两份NSYS采集，生成基于实际数据的对照图。用户已部分复述连续提交和槽位复用过程，尚无个人编译/采集或完整独立解释的验收证据；不将完整实现、工具通过或已看重绘图记为独立掌握。

### 基本概念

**本章的工作量与运行方式**

<span style="color:red">用户提问：本次代码有哪几个模式？mode、selection、chunks、slots、N_per_chunk、block、grid等参数是什么意思？</span>

第一个参数mode选择运行用途：check每种调度检查一批；bench先检查、预热3批，再测21批并报告中位数；trace先检查、预热3批，再运行一批目标样本，供外部nsys profile采集。第二个参数selection选择serial、pipeline或both，默认是check both。trace本身不启动profiler。当前两处练习已经补全，旧骨架数值正确但拒绝计时的INCOMPLETE状态仅是历史记录。

| 配置 | 本例取值与含义 |
| --- | --- |
| chunks / slots | 每批8个独立数据块，轮流使用2套device存储 |
| N_per_chunk / dtype | 每块262147个float32，每元素4字节 |
| block / grid | 每次kernel为1025个block，每block256线程，最后block仅3个有效线程 |
| repeats | 每个有效线程做256次+0.125，结果为输入加32，不是启动256次kernel |
| bytes_per_copy | 每块一次H2D或D2H为1048588字节，约1MiB |

chunk是host程序的数据划分，block是GPU线程组织；一个chunk由整个grid处理。kernel每线程只读写自己的一项，不在本章引入shared交换或block间合作。

**chunk决定处理哪段数据，slot决定使用哪套显存地址**

<span style="color:red">用户提问：chunk是在host划分的数据批块是什么意思？显存槽位slot干什么？host_input + offset怎么理解？</span>

host_input一次分配8×262147个元素，逻辑上按连续范围分成8块，没有为每个chunk再分配一个host数组。offset=chunk*kN是当前块的元素起点；host_input+offset等价于&host_input[offset]，float指针会自动按每元素4字节移动，不能再把offset乘4。拷贝函数中的kBytes才以字节为单位。

每个slot含input、output两块device显存以及ready、done两个Event，是本程序定义的数据结构，不是硬件执行槽。slot0和slot1各能承载一个完整chunk，按chunk%2复用：

| chunk | host数据起点 | device槽位 | 槽位旧使用者 |
| --- | --- | --- | --- |
| 0 | host_input | slot0 | 无 |
| 1 | host_input+kN | slot1 | 无 |
| 2 | host_input+2*kN | slot0 | chunk0 |

例如chunk2的block0/thread3读slot0.input[3]、写slot0.output[3]，回读到host_output[524297]。chunk0和chunk2的host地址不同，device地址却相同，因此覆盖前要保护旧块的使用期。<mark>两个slot各自都有输入和输出，轮流承担不同chunk；不是一个slot固定用于计算、另一个固定用于传输。</mark>

**两条stream在整个程序中复用，不是每块新建两条**

<span style="color:red">用户提问：upload和compute针对整个程序，还是每个chunk各有两个stream？slot与stream到底是什么关系？</span>

main在循环外只创建一次upload和compute，全部chunk和后续run_batch都共用它们，最终才销毁。slot提供存储地址，stream组织操作顺序；upload负责两个slot的H2D，compute负责两个slot的kernel和D2H。不能把slot0绑定upload、slot1绑定compute，也不能从图中两行推断它们表示两个slot。

同一stream按提交顺序执行，不同stream若无依赖可以独立推进。当前所有kernel和D2H在同一compute队列，因此多个chunk的kernel仍依次执行；本章观察的主要重叠是当前块kernel与下一块H2D。

**memset按字节初始化，NaN用来暴露漏写**

<span style="color:red">用户提问：std::memset(host_output, 0xff, kTotal*sizeof(float))为什么不是给float赋值255，为什么能帮助校验？</span>

memset把指定范围的每个字节写为0xff。本例一个float占4字节，位模式成为0xffffffff，按本机float32解释为NaN；直接赋值255.0f则得到0x437f0000。这里先给host_output和两个slot.output写NaN哨兵，若kernel或回读漏写，后续可能保留NaN。validate计算误差后检查std::isfinite，非有限值直接计入mismatch，避免只做error>容差时漏掉NaN。两条stream的前序工作先等完，device哨兵填充也等完，才开始计时。

**CPU等待、设备队列等待与Event完成标记**

<span style="color:red">用户提问：cudaStreamSynchronize干什么？以前Event叫start/stop，现在ready该如何理解？</span>

Event是某条队列工作完成进度的标记，start、stop、ready、done是变量名。start/stop用两个标记测时间，ready表示输入就绪，done表示本块计算及回读结束；本章用cudaEventDisableTiming创建ready/done，只需要依赖功能。

| API | 本章中的作用 |
| --- | --- |
| cudaEventRecord(event, stream) | 把该stream在调用时已提交工作的完成状态记录到event，CPU返回不代表这些工作已经完成 |
| cudaStreamWaitEvent(stream, event, 0) | 约束目标stream后续工作，等该event覆盖的工作完成；CPU无需先等event完成才继续提交 |
| cudaEventSynchronize(event) | CPU等该event覆盖的工作完成，本章serial每块结束时使用 |
| cudaStreamSynchronize(stream) | CPU等该stream此前工作完成，本章用于批次准备和最终收尾 |

同stream本身保证先后；跨stream需要明确建立依赖。CPU等待一个stream时，另一个已提交工作的stream仍可推进。CUDA_CHECK检查API状态，失败会终止程序；它本身不是同步机制。

**ready连接同一chunk的上传与计算，done保护同槽位复用**

<span style="color:red">用户提问：Record(ready, upload)与wait_for_input(compute, ready)的先后关系是什么？这两句是不是两个chunk在同一slot上的交接？</span>

```cpp
cudaMemcpyAsync(slot.input, host_input + offset, kBytes,
                cudaMemcpyHostToDevice, upload);
cudaEventRecord(slot.ready, upload);
wait_for_input(compute, slot.ready);  // 内部为cudaStreamWaitEvent
repeated_add<<<grid, kBlock, 0, compute>>>(slot.input, slot.output, kN);
```

CPU先提交H2D和ready，再给compute设置等待，最后提交kernel；CPU不必等上传完成才调用wait。设备端顺序为H2D完成→ready完成→kernel开始。<mark>ready是同一chunk从upload到compute的阶段接力；done才是旧chunk向复用同一slot的新chunk交出空间。</mark>

chunk0的kernel之后，在同一compute队列提交D2H，再Record(slot0.done)。提交chunk2的H2D之前，upload先通过wait_for_slot等待旧done，防止覆盖chunk0仍在使用的slot0。前两个chunk首次使用槽位，没有旧工作，不依赖尚未record的done。Event重录会更新状态，已提交的Wait绑定调用时最近一次Record覆盖的工作，不会被后续重录改成等待未来一轮。

**Async允许CPU继续提交，同stream仍然保序**

<span style="color:red">用户提问：为什么使用cudaMemcpyAsync？kernel之后直接回读，为何不用再加Event？</span>

本程序用cudaMallocHost分配pinned host内存，为异步传输提供条件；cudaMemcpyAsync把任务提交到指定stream，使CPU不必逐次等传输完成再提交后续工作。API名字不保证所有情形都立即返回，也不保证实际一定重叠。

kernel写slot.output，随后的D2H也提交到compute，因此GPU执行时自然满足整个kernel完成→D2H开始。<mark>Async涉及CPU返回与工作完成的关系，不会取消同stream顺序。</mark>CPU提交D2H时kernel可以还在执行，但D2H排在其后；CPU最终读取host_output前，仍需等待回读完成。cudaGetLastError是CPU查询错误状态，不是加入GPU队列的一项计算或拷贝任务。

**run_batch的顺序、唯一对照开关与布尔返回值**

<span style="color:red">用户提问：按逻辑顺序逐行解释run_batch；串行和流水是不是只差第91行？为什么最后返回device_waits，helper又指什么？</span>

run_batch先等待前序工作并写NaN哨兵，再记t0。每轮选择slot和host偏移，需要复用时先保护旧槽位，随后提交H2D→ready→compute等待→kernel→D2H→done。循环后等待两条stream完成，再记t1，把微秒数写入引用参数host_us。输入生成、分配、哨兵和CPU校验均在计时外。

```cpp
if (!pipeline) CUDA_CHECK(cudaEventSynchronize(slot.done));
```

这行是唯一调度对照：serial让CPU每块等完，pipeline连续提交并最终统一等待。用户已复述chunk0尚未全结束就提交chunk1、chunk2要复用slot0时需等chunk0。进一步需要区分：<mark>chunk2的CPU代码可以提前提交等待与上传；真正的新H2D必须等旧done完成，CPU不必在wait_for_slot中停住。</mark>

helper只是自写的辅助函数，此处指wait_for_input和wait_for_slot。device_waits用逻辑与累计helper完成声明；原骨架helper安全地让CPU等待但返回false，从而拒绝发布流水计时。现在两处均正确调用StreamWaitEvent、成功后返回true；API失败由CUDA_CHECK终止，因此该bool主要保留教学检查接口。调用方将waits_ok与validate得到的correct组合，不能把device_waits当数值正确、GPU已完成或并发已发生的证明。

**实际实验分别回答“是否更快”和“是否重叠”**

<span style="color:red">用户提问：给我实际实验结果，并说明如何体现本章的流水模式。</span>

11月5日正式版在GTX1650上，两种调度各2097176项全部正确、最大误差0。普通bench预热3批、测21批，每批8块；串行host_batch中位数4473.431μs，流水3000.325μs，耗时减少32.930%，串行/流水耗时比约1.491。这是本机本轮的整批host时间，包含提交、传输、计算和等待，不是单kernel GPU时间。

另外两次NSYS采集各40次kernel、40次H2D和40次D2H，最后8次各类活动对应目标批次。串行7对“当前kernel/下一块H2D”无交集，流水7对都有交集，总和617.060μs。以流水kernel0和H2D1为例，分别位于234.145～326.082μs与161.761～321.762μs，交集87.617μs，直接显示slot0计算与slot1上传同时推进。

旧D2H0结束于543.843μs，新H2D2开始于610.372μs；全部8块的块内先后和6次槽位复用端点检查均符合依赖。两份trace均有70次StreamWaitEvent，额外CPU EventSynchronize为serial40、pipeline0，对应5批×8块的开关差异。<mark>流水保留同块与同槽位的必要顺序，利用不同块之间的独立性；创建两条stream、数值PASS或耗时下降，单独都不能证明发生了重叠。</mark>

普通bench与NSYS属于不同运行。目标GPU整批跨度4635.592/3097.683μs、交集617.060μs，不能与普通host中位数相加、相减或互相替代。详细端点、计时边界和原始报告见 [本章正式实验](chapters/15_event_pipeline.md#正式实验与流水证据2026-11-05) 与 [目标活动CSV](../reports/CH15/experiment-2026-11-05-timeline.csv)；11月3日同哈希源码memcheck零错误是既有证据，11月5日没有重跑该工具。

**对照图的数据来源与原始NSYS报告**

<span style="color:red">用户提问：这张时间线图是NSYS本来就有的，还是你自己生成的？</span>

[对照PNG](../reports/CH15/experiment-2026-11-05-timeline.png)由Codex用Python/Matplotlib生成：NSYS采集.nsys-rep→导出SQLite→提取目标批次GPU起止时间和stream ID→按实测区间绘图。矩形位置、宽度与交集取自采集数据；颜色、H/K/D标签、chunk编号及上下对照布局由 [脚本](../reports/CH15/experiment-2026-11-05-analysis.py)添加，chunk编号按同类活动在各队列的顺序对应。它不是NSYS GUI截图；每份报告分别以首个目标H2D归零，不把两次采集拼成同一绝对时间轴。

原始 [串行报告](../reports/CH15/experiment-serial-2026-11-05.nsys-rep) 与 [流水报告](../reports/CH15/experiment-pipeline-2026-11-05.nsys-rep)均保留。用户查看并询问重绘图的来源，不据此推断已经打开NSYS GUI、亲自采集或完成完整读图验收。

### 踩坑记录

本章真实疑问包括：chunk与block的层次区别、两个slot是否固定分担计算/传输、每个chunk是否另建两条stream、ready是否负责两个chunk的槽位交接，以及chunk2复用slot0时究竟由CPU还是GPU队列等待。已沿chunk0～2的地址、队列和Event链解释；不将试探性提问记成已经确认的错误理解，也不把已讲解等同于独立掌握。

需要反复分清字节写入与float数值赋值、CPU等待与设备依赖、Record返回与Event完成、错误查询与任务排队、教学bool与正确性校验。数值PASS和memcheck零错误不独立证明跨stream依赖充分；实际端点与源码语义共同构成解释依据。所有kernel仍在compute中顺序执行，不能把本章结果说成多个kernel并发，也不预设其他GPU或每次运行都获得相同加速。

### 八股自测

不看答案，沿chunk0、chunk1、chunk2说明host数组范围、slot复用、upload/compute中的提交顺序，以及ready和done分别由谁记录、谁等待；解释CPU什么时候可以继续提交、GPU什么时候允许读输入或覆盖slot0，以及为什么同stream的kernel→D2H不需要额外Event。

再用实际图里的K0/H1重叠与D0/H2先后，分别解释并发机会与槽位保护；说明4.473/3.000ms普通host时间、87.617μs单对交集和GPU整批跨度各测了什么，并指出哪些图形标注来自脚本、哪些时间来自NSYS。以上用于后续独立验收，不追加三阶段完全并发、CPU线程池或Graph改造。

## 2026-11-09 Ch16：CUDA Graph 与固定小 kernel 链

### 今日完成任务

围绕 [CH16/graph_replay.cu](../CH16/graph_replay.cu) 复盘固定三阶段链的capture、实例化和replay，以及Graph为什么能减少提交和执行间隙。骨架11月5日生成，11月6日按用户要求由Codex补全两处TODO并验证；本章已结合用户提问解释参数、输出指针、Graph句柄、capture函数、节点数量与类型检查、正式计时和NSYS时间线。11月9日由Codex采集当前正式版两种模式的NSYS并生成实测对照图，本次总结只核对已有源码、日志及摘要，没有重新运行实验。

用户主动追问过指针地址与H2D开销，并要求逐行讲解和实测对照；这些是实际学习接触，不等同于独立实现或完整解释通过。代码补全、编译、校验、memcheck、采集及绘图由Codex完成，尚无个人运行/采集或完整独立解释的验收证据。

### 基本概念

**一条链做什么，参数控制哪一层**

<span style="color:red">用户提问：简介本章学习目的；介绍一下本章参数。</span>

输入依次经过三个GPU kernel：input→add_one写tmp0→scale_two写tmp1→subtract_half写output，每项结果为(input+1)×2−0.5。CPU函数launch_chain负责提交这三个启动请求，三个kernel都在同一stream中，按先写后读的依赖顺序执行。例如block0/thread3负责第3项，依次从−6.6875得到−5.6875、−11.375和−11.875。

| 参数 | 本例值与作用 |
| --- | --- |
| Clock | steady_clock，用于CPU侧计时 |
| kN / dtype | 每个数组4099个float32 |
| kBlock / kGrid | 每block256线程、每次启动17个block，共4352线程，最后block仅3个有效线程 |
| kChains | 每批重复64条三kernel链，共192个GPU kernel |
| kWarmup / kSamples | bench先预热3批，再测21批并分别取时间中位数 |
| kBytes | 单个数组16396字节，用于分配与拷贝；四个device数组各占这么多 |

64条链复用同一组input/tmp0/tmp1/output，每条都从原input重新计算，覆盖中间数组与output，不把上一条output再累积一轮。64条链不是64套输入，也不等于64个block。唯一实验变量是普通逐kernel提交或Graph replay，数据、计算、地址与依赖不变。

**capture记录工作，实例化准备执行，replay提交工作**

<span style="color:red">用户提问：逐行讲解capture_chain。</span>

```cpp
cudaStreamBeginCapture(stream, cudaStreamCaptureModeGlobal);
launch_chain(b, stream);
cudaStreamEndCapture(stream, &graph);
cudaGraphInstantiate(&exec, graph, 0);
// 后续需要运行时：
cudaGraphLaunch(exec, stream);
```

以上摘录省略CUDA_CHECK，正式源码每个API均检查状态。BeginCapture让指定stream进入记录状态；CPU仍执行launch_chain的C++代码，但三个kernel启动被录为节点及其依赖，此时不排队执行这条链。EndCapture结束记录并取得graph；Instantiate检查和准备图，生成exec，最后一个0为默认flags；GraphLaunch才将可执行图提交到stream。replay不会重新走一遍launch_chain的host代码。Global是capture约束模式，不表示自动捕获所有stream或使用global memory。

<mark>graph是工作及依赖的描述，exec是可重复启动的对象；capture/实例化成功、GraphLaunch返回和GPU执行完成是不同事件。</mark> 两个helper返回true只表示相应API成功，完成等待在run_batch整批末尾。分配、输入上传、预热、哨兵、同步和计时留在capture外；尤其不能在capture中同步正在捕获的stream。图保留参数中的地址，相关device分配要活到最后一次replay完成。本章保持地址、shape和参数固定，不扩展图更新或跨stream捕获。

**为什么传&b.input，以及句柄为什么可以初始化为nullptr**

<span style="color:red">用户提问：b.input是一个指针，&b.input不是这个指针变量的地址吗？为什么不能直接赋值给b.input？第一次解释后又表示“没明白，再讲一下”。</span>

b.input是CPU中的一个指针变量，变量本身有存放位置，其值以后指向GPU显存。以假设地址说明：变量存放在CPU地址0x1000，最初里面是nullptr；cudaMalloc分到显存地址0x8000后，需要把0x8000写进CPU地址0x1000处的变量。因而传&b.input，让API知道把结果填进哪个变量；只传b.input，拿到的只是当前nullptr值。这里的0x1000/0x8000是教学假设，不是本次运行实测地址。

<mark>cudaMalloc的返回值是成功或失败状态，显存地址通过第一个参数写回；CUDA_CHECK检查状态，b.input接收地址。</mark> 最终确实修改了b.input，只是写回发生在API内部。变量中存放的地址与变量本身的地址要分开理解；第二次解释使用CPU盒子/GPU空间示意，未据此记录用户已经独立掌握。

<span style="color:red">用户提问：cudaGraph_t graph和cudaGraphExec_t exec是干嘛的，为什么cuda____t初始值都是nullptr、像一个指针？</span>

本机头文件将cudaGraph_t和cudaGraphExec_t定义为内部结构指针的类型别名，类型名已经包含指针含义，所以声明变量时不用再写*。它们作为句柄交给CUDA API识别、管理相应对象，内部结构不用自己访问；初始化nullptr只表示这两个变量尚未取得有效图句柄。&graph、&exec用于接收API写回的句柄，逻辑与输出指针相同。<mark>不能把所有cuda___t都看成指针，_t只是命名习惯，例如cudaError_t是错误码类型。</mark>

**节点检查为什么先查询数量，再逐个查类型**

<span style="color:red">用户提问：讲解193～199行的count、nodes和两次cudaGraphGetNodes，以及200～205行的循环。</span>

graph和exec有效后，第一次cudaGraphGetNodes(graph,nullptr,&count)只查询节点数；第二个nullptr表示不接收列表，&count让API写回数量。知道count后，用std::vector&lt;cudaGraphNode_t&gt; nodes(count)在CPU准备存句柄的数组，nodes.data()给出数组起始地址，第二次cudaGraphGetNodes把节点句柄填进去。这里没有新增kernel或数组H2D传输，节点列表也不作为kernel执行顺序的证明。

kernel_nodes先设为(count==3)，只检查数量；for(auto node:nodes)依次读取句柄，cudaGraphNodeType type{}准备接收类型的CPU变量，cudaGraphNodeGetType(node,&type)写回类别，再计算：

```cpp
kernel_nodes = (type == cudaGraphNodeTypeKernel) && kernel_nodes;
```

当前是kernel且此前通过，结果才保持true。假设数量为3但类型依次为kernel、拷贝、kernel，则结果为true→true→false→false；一旦失败，后面的正确节点不能恢复true。最终true表示数量为3且全为kernel类型，不能独立证明运算内容、依赖或结果正确；数值由CPU reference另查，实际GPU活动由trace核对。查询类型不会执行该节点。

**数据已经在显存，为什么仍有kernel间隙**

<span style="color:red">用户提问：launch_chain里面就是按顺序调用device上显存的内容，Graph减少的间隙原本主要花在哪里，是H2D调度开销吗？</span>

launch_chain本身在CPU执行，里面的&lt;&lt;&lt;...&gt;&gt;&gt;通过Runtime/Driver发起启动，传入kernel、grid/block、stream及指针等参数；GPU执行kernel函数体时才读写显存。数据常驻显存解决了数组搬运问题，但CPU仍须逐次提交启动，GPU也须接收并衔接这些工作。同stream保证顺序，不保证前后kernel零间隙；cudaGetLastError同样是host错误查询，不是GPU计算。

本例kernel约1～2μs，CPU逐次提交及GPU启动衔接的开销可能明显影响整批耗时。Graph把工作及依赖提前准备，一次提交一条链，减少重复的提交准备并让CUDA按已知流程执行。<mark>Graph优化的是固定工作链的提交与衔接，GPU仍执行三个独立kernel，保持原来的数据依赖。</mark> 从本次目标窗口无memcpy/memset可排除其中数组传输，但不能把某个间隙精确拆成CPU、Driver、GPU调度各占多少；系统环境和profiler也可能影响间隙。

**正式实验：稳态更快与间隙更小分别看证据**

<span style="color:red">用户提问：结合实验结果对比突出CUDA Graph的作用。</span>

本次总结只重读既有证据，当前源码SHA-256与11月6日正式补全日志、11月9日正式NSYS日志一致。两次实验都为GTX1650 / CC7.5 / 14SM、NVCC12.9.86、Runtime12090、DriverAPI13030，CUDA_LAUNCH_BLOCKING unset。11月6日正式check两路径各4099项全部正确、最大误差0，memcheck零错误；这些保持为已有验证，不冒充本次总结新运行。

11月6日普通bench预热3批、测21批，每批64条链，三种时间各自中位数如下，单位μs：

| 边界 | direct | graph |
| --- | --- | --- |
| host_submit：CPU提交循环 | 1158.311 | 359.904 |
| host_complete：同一起点到整批等待完成 | 1534.156 | 627.443 |
| Event span：同stream整批区间，含间隙 | 1497.024 | 595.744 |

本机本轮host完成区间从约1.534ms到0.627ms，耗时比约2.45，减少59.1%。host_complete已包含submit；stop Event提交及最终等待也在其中。start Event的host提交在t0前，stop提交在t1后，Event并非CPU timer的相同边界，也不是kernel耗时求和。分配、H2D、capture/实例化、哨兵、D2H及CPU校验在计时外，只说明稳态收益，没有测一次性建图回本次数。原始结果见 [正式补全日志](../reports/CH16/completed-2026-11-06.txt) 和 [讲义正式验证](chapters/16_graph_replay.md#正式补全与验证2026-11-06)。

11月9日当前正式版的独立NSYS node trace，提取每份报告最后192个GPU kernel作为目标批次：

| 目标批次观测 | direct | graph |
| --- | --- | --- |
| CPU提交主计算API | 192次普通launch | 64次Graph launch |
| GPU kernel数 | 192，每阶段64 | 192，每阶段64 |
| kernel自身耗时合计 | 330.048μs | 332.736μs |
| 首kernel开始至末kernel结束 | 1365.216μs | 751.394μs |
| 链内128个间隙中位数 | 2.016μs | 0.320μs |
| 链间63个间隙中位数 | 1.920μs | 2.144μs |
| 目标GPU窗口memcpy/memset | 0 / 0 | 0 / 0 |

<mark>本次计算数量相同、kernel耗时合计接近，Graph链内衔接明显紧凑；链间仍有空档，不能说所有间隙都降低或消失。</mark> profiler与普通bench分属不同运行，不能相加、相减或拼成一次延迟分解；历史11月5日临时版6.032μs链内间隙也不代替本次2.016μs。单卡、小kernel链的结果不预设适用于所有工作负载。

**在NSYS里读哪条轨迹，图从哪里来**

<span style="color:red">用户提问：能不能在NSYS里面直观对比出两种模式kernel间隙开销？</span>

采集需用--cuda-graph-trace=node，才能展开Graph内部节点；node采集增加开销。CPU的CUDA API行看提交，CUDA HW下目标stream的kernel色块看实际GPU执行。两份报告目标stream ID均为13，完整各963次kernel，最后一批192次才是对照样本；观察时保持相同时间跨度，空档为后kernel的Start减前kernel的End。

以各报告目标首kernel开始归零，普通首链A为0～1.760μs、B为4.000～5.696μs，空档2.240μs；Graph首链A为0～1.728μs、B为2.048～3.744μs，空档0.320μs。Graph首链三个节点关联同一次Graph launch，Correlation ID=453，普通首链则为1719/1721/1723。不能拿CPU API条的宽度当GPU间隙，也不从WSL跨CPU/GPU端点做精确等待拆分。

[实测对照图](../reports/CH16/experiment-2026-11-09-timeline.png)由Python/Matplotlib按NSYS报告→SQLite→GPU端点绘制；矩形位置/宽度取自实测，颜色、A/B/C和链编号由脚本添加，每份报告分别归零。它不是GUI截图，灰色只表示目标stream上相邻kernel的空档，不证明整卡都空闲。原始 [direct报告](../reports/CH16/experiment-direct-2026-11-09.nsys-rep) 和 [graph报告](../reports/CH16/experiment-graph-2026-11-09.nsys-rep)保留；完整端点、命令与GUI版本边界见 [讲义读图路线](chapters/16_graph_replay.md#正式-nsys-间隙对照与-gui-阅读路线2026-11-09) 及 [摘要JSON](../reports/CH16/experiment-2026-11-09-summary.json)。用户要求并接触了对照讲解，尚无个人打开GUI、采集或完整独立读图验收的证据。

### 踩坑记录

本章实际难点包括：指针变量的值与变量地址、cudaMalloc的错误码返回与地址写回、Graph句柄类型别名、capture记录与GPU执行、两次查询节点的用途、数量检查与逐类型累积检查，以及把数据常驻显存误等同于启动不再有开销。用户对&b.input第一次讲解明确表示没明白，已用具体假设地址和CPU盒子示意重讲；不把再次讲解记为已经独立掌握，也不把试探性提问写成用户已经确认的错误结论。

原骨架曾安全回退并拒绝Graph计时，当前两处TODO均由Codex补全，正式版应PASS。数值PASS、memcheck零错误、3个kernel节点及教学bool分别有不同验证范围，不能互相替代。192次launch变64次是主计算提交计数，不代表所有CUDA API只剩64次；GPU仍执行192个kernel。时间比较需分清普通bench与trace、链内与链间、首次准备与稳态，不用单次间隙差给CPU/Driver内部开销定量归因。

### 八股自测

不看代码，沿一条链说明CPU何时capture、何时实例化、何时replay、何时等完成，解释graph与exec、&b.input与b.input分别是什么，以及固定地址为什么要保持有效。指出节点数量/类型检查与实际执行、数值校验各自能证明什么。

再用自己的运行结果和NSYS轨迹，解释为什么CPU主计算提交192→64而GPU kernel数仍为192；指出一对GPU端点算出间隙，说明本轮2.016/0.320μs、链间1.920/2.144μs和普通host完成1.534/0.627ms的不同口径。说明H2D放在哪里、图的哪些部分来自实测、为什么Graph仍有空档。以上用于后续独立验收，不追加图更新、跨stream捕获或框架工程。

## 2026-11-09 Ch17：编译产物、PTX与SASS

### 今日完成任务

围绕 [CH17/vector_add.cu](../CH17/vector_add.cu) 和 [compile.sh](../CH17/compile.sh)，学习同一份kernel如何生成PTX、sm_75 cubin以及包含host/device代码的普通可执行文件，并用cuobjdump/nvdisasm查看产物。本章主要变量是编译输出阶段，向量加法、输入和校验保持不变，没有性能对照或JIT缓存实验。

两条编译命令已按用户要求由Codex补全，正式构建、数值校验和memcheck由Codex完成。用户主动询问extern "C"、Bash脚本阅读、PTX逐段含义、64位地址与32位数据、寄存器与方括号、PTX/SASS区别、为何需要IR以及Ch18如何加载cubin，并提供了nvdisasm命令及323行完整输出。该输出已 [原样保存](../reports/CH17/user-nvdisasm-2026-11-09.txt)，作为实际产物查看证据；没有据此推断用户已独立编译、运行Runtime程序或完成全部解释验收。

### 基本概念

**同一份源码，为什么生成不同文件**

<span style="color:red">用户提问：分清源码、PTX、cubin与普通可执行文件的关系。</span>

本例.cu同时包含CPU上的main和GPU上的vector_add。host准备输入、分配显存、H2D、启动kernel、等完成、D2H并逐项校验；device部分每线程计算一项c[i]=a[i]+b[i]。n=1000、float32、每数组4000字节、block128/grid8，共1024线程，最后24个线程跳过访存。

| 产物 | 内容与用途 |
| --- | --- |
| `CH17/vector_add.cu` | 人写的CUDA C++，包含host与device代码 |
| `build/CH17/vector_add.ptx` | kernel的文本中间表示，还需进一步编译，无host main |
| `build/CH17/vector_add.cubin` | 面向sm_75的GPU机器码及符号、资源、调试等信息，供CUDA加载 |
| `build/CH17/vector_add` | 可由操作系统启动的host程序，内嵌device image及所需Runtime支持 |

device部分的简化路径为源码→PTX→cubin中的GPU机器码，机器码经工具反汇编显示为SASS。普通构建还要编译host代码并链接；SASS文本是机器指令的可读表示，不是应用运行时额外读取的一份文件。`--ptx`/`--cubin`只输出device产物并丢弃host代码。本章runtime分支明确嵌入sm_75 cubin与PTX，程序运行不依赖旁边那份独立cubin；生成独立cubin也不会自动执行加法。

**PTX和SASS的区别，以及为什么需要IR**

<span style="color:red">用户提问：ptx和sass的区别，为什么要有ptx这个ir？</span>

IR可理解为编译过程中先表达“需要做什么”的中间程序。PTX保留线程、地址空间、类型和运算等信息，使用虚拟寄存器，后端再针对具体GPU做优化、选择机器指令和分配寄存器。SASS则展示目标架构上最终机器指令的可读名称，例如本例PTX的ld.global.f32/add.f32/st.global.f32对应到了sm_75的LDG/FADD/STG；该例的对应不代表所有代码逐条一一对应。

<mark>PTX把前端生成程序与后端适配GPU分开，提供较稳定的编译及分发接口；GPU最终执行的是目标机器指令。</mark> PTX可以在构建阶段继续编译，也可以随程序分发，在需要时由驱动JIT（即时编译）。这受PTX版本、目标能力和驱动支持限制，不表示任意PTX可在任意GPU上运行，也不保证跨架构相同性能。`.version 8.8`是PTX语法版本，`.target sm_75`表示目标能力，`.address_size 64`表示地址宽度；PTX里出现sm_75仍不等于它已是机器码。

**extern "C"让kernel按什么名字被找到**

<span style="color:red">用户提问：为什么要有extern "C"？</span>

C++通常会将参数类型等信息编码进函数的外部名称，以区分重载等情况。`extern "C"`指定C语言链接方式，避免C++名称修饰，使本例PTX/cubin里的入口保持vector_add；`__global__`负责声明GPU kernel。普通`<<<...>>>`启动时编译器会处理名称对应关系，通常不必手工按字符串查找；Ch18要通过模块API查找"vector_add"，保留简单名称便于教学。a/b/c/n的参数顺序由函数签名决定，并非extern "C"额外保证；该修饰不把kernel变成CPU函数，也不带来本章可声称的性能收益。

**如何看懂compile.sh的功能**

<span style="color:red">用户提问：这种.sh文件以后拿到怎么看其实现的功能？</span>

脚本是由解释器执行的一组命令。本例使用Bash，阅读时先找真正工作的nvcc，再追踪参数、变量、分支、工作目录与输出。`mode="${1:-runtime}"`取第一个参数，缺失或为空时默认runtime；case检查并选择runtime/ptx/cubin中的一个分支。chapter_root定位项目根目录，flags数组复用编译选项，`"${flags[@]}"`逐项展开，行尾反斜杠连接命令。具体Bash语法见本页Ch17阅读入口，不扩展成Shell课程。

```bash
bash CH17/compile.sh runtime  # 普通可执行程序；不带模式时也默认runtime
bash CH17/compile.sh ptx      # --ptx --gpu-architecture=compute_75
bash CH17/compile.sh cubin    # --cubin --gpu-architecture=sm_75
```

`bash -n`只检查语法，`bash -x`显示展开后的命令并实际执行，不能把-x当作只读预览。脚本本身只编译，不负责运行生成的程序或查看产物。

**沿一个线程读PTX**

<span style="color:red">用户提问：vector_add.ptx这个怎么理解？</span>

`.visible .entry vector_add`声明kernel入口，四个.param依次对应a、b、c的64位指针值和32位n。ld.param取出这些参数值，尚未读取数组元素；mov从%ctaid.x/%ntid.x/%tid.x取得blockIdx.x/blockDim.x/threadIdx.x，mad.lo.s32计算i。以block1/thread3为例，i=1×128+3=131；setp.ge.s32检查i>=n，条件为真就跳到ret，跳过数组读写。

有效线程用i×4得到字节偏移，再加到a/b/c基地址。本例i=131时偏移524字节。cvta.to.global把通用地址转换为global地址表示，不复制数组，也不分配显存；mul.wide.s32将32位乘法结果保留为64位，供地址计算。随后ld.global.f32读取a[i]/b[i]，add.f32相加，st.global.f32写回c[i]。

**地址的64位与float的32位不是来回转换**

<span style="color:red">用户提问：先转换为64位最后又转回32位是为了什么？</span>

第48行cvta.to.global.u64处理的是b的地址，输入%rd2本来已是64位；第58行st.global.f32规定写入一个32位float。<mark>地址宽度描述“去哪里”，数据类型描述“读写什么、多少字节”。</mark> 用64位指针定位内存、读写4字节float，完全可以同时成立，没有将同一个浮点数先扩宽再缩窄。

**寄存器名字与方括号分别表示什么**

<span style="color:red">用户提问：为什么ld和st时其中一个要用[]？意思就是%rd8表示rd8这个寄存器吗？</span>

%rd8是PTX虚拟寄存器的名字；作为源操作数时使用它保存的值，作为目的操作数时接收结果，不是寄存器本身在内存里的地址。寄存器可以装普通数值、偏移或地址；例如%rd5是字节偏移、%rd8是b[i]地址、%f3是加法结果。%rd8也不表示固定硬件寄存器8，实际寄存器分配发生在后端。

```ptx
add.s64 %rd8, %rd7, %rd5;   // 寄存器里的值相加，算出地址；还未读取该内存
ld.global.f32 %f1, [%rd8];  // 从该地址读取float，存入%f1
st.global.f32 [%rd10], %f3; // 将%f3写到%rd10指向的内存
```

方括号标识内存操作数，直觉对应C++的解引用。ld从右侧内存读取到左侧寄存器，st从右侧寄存器写入左侧内存；这不是所有寄存器都“按地址传值”。.reg声明的是虚拟寄存器，声明个数不能直接当成最终硬件寄存器用量。.loc/.file用于关联源码位置，不是数值计算。

**用工具查看cubin，以及nvdisasm为什么打印这么多内容**

<span style="color:red">用户提问：cubin人类无法阅读，是不是只能通过cuobjdump得到sass？讲解贴出的nvdisasm输出都有哪些内容。</span>

cubin是ELF格式的二进制容器，包含GPU代码和支持加载、执行、调试的其他信息。cuobjdump --dump-sass与nvdisasm都可反汇编其机器指令；cuobjdump还可查看host可执行文件内嵌的device image，nvdisasm接受cubin并提供源码关联等显示。SASS只覆盖机器指令的可读表示，不等于整个cubin，也不保证恢复原CUDA源码。

用户原文从headerflags/elftype、debug区域一直打印到.text.vector_add。前者标记sm_75与64位地址；debug_frame/debug_line/nv_debug_line_sass为调试及行号关联信息；.byte/.word是在展示数据和元数据，不都是GPU指令。.nv.info记录本kernel寄存器数12（0x0c）、frame/最小stack为0，MAXREG_COUNT的0xff不是实际用了255个寄存器。.nv.callgraph是函数调用关系信息，不是Ch16的CUDA Graph；.nv.rel.action属于定位修正相关元数据，当前不解码其内部字段。

本例参数区起点0x160、大小0x1c=28字节，可沿本份元数据及SASS对应如下；这是当前编译产物的布局，不作为跨版本固定合同：

| 参数 | 当前constant bank 0偏移 | 大小 |
| --- | --- | --- |
| a | 0x160 | 8字节 |
| b | 0x168 | 8字节 |
| c | 0x170 | 8字节 |
| n | 0x178 | 4字节 |

`c[0x0][0x178]`是SASS里的constant bank访问，不是源码数组c。.nv.constant0.vector_add的.zero 380描述文件区域的初始内容与大小，不是输出数组有380项或参数永远为0。CH18应按API传参数，不手填这些内部偏移。

.text.vector_add才是主要代码：S2R取block/thread编号，IMAD算i，ISETP加条件EXIT处理尾部，IMAD.WIDE计算地址，LDG读输入，FADD相加，STG写回，最后EXIT。R寄存器会复用，同名寄存器在前后可保存不同用途的值。每行/*00c0*/这类数字是代码区内偏移，不是线程编号或耗时；尾部自跳转位于正常EXIT之后，不能据此说正常线程会死循环。

用户输出中的.nv_debug_ptx_txt经字节解码，确实含.version 8.8和.visible .entry vector_add等PTX文本。<mark>这份cubin保留了调试用途的PTX文本；它不是从机器码逆向恢复的PTX，也不代表每个cubin都含这些文本。</mark> 纯机器码无法保证还原为原始PTX，与本例保留调试文本并不矛盾。

```bash
cuobjdump --dump-sass build/CH17/vector_add.cubin
nvdisasm -c -g build/CH17/vector_add.cubin
```

第二条只打印代码区并附源码行号；本轮讲解时Codex已确认能关联.cu第21～24行，便于对照索引、边界与加法。工具语义参考 [Binary Utilities 12.9.1](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-binary-utilities/index.html)，PTX含义参考 [PTX ISA 8.8](https://docs.nvidia.com/cuda/archive/12.9.1/parallel-thread-execution/index.html)，编译流程参考 [NVCC 12.9.1](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-compiler-driver-nvcc/index.html)。首轮不要求背SASS后缀、解码全部ELF元数据或从指令数推断性能。

**与Ch18的连接：加载代码不等于执行代码**

<span style="color:red">用户提问：如何为CH18加载cubin？</span>

概念流程为cuInit→选择device→保留primary context→设为当前线程context→cuModuleLoad读取cubin→cuModuleGetFunction按"vector_add"取得kernel句柄。context是CUDA管理GPU资源和执行状态的环境，module代表加载的代码模块，function句柄标识其中的kernel。之后仍需准备显存和参数、cuLaunchKernel、等完成、回读校验，再清理资源；相对路径取决于进程工作目录。

这里只做过API流程讲解，没有生成Ch18、加载外部cubin或执行Driver启动；后者保持NOT RUN。Runtime程序数值PASS不能替代该验证，也不从本节建立Runtime/Driver严格一一对应关系。

**已有验证及其边界**

11月9日正式补全日志记录GTX1650/CC7.5/14SM、NVCC12.9.86、Runtime12090、DriverAPI13030，脚本三种构建均成功；Runtime的1000项全量mismatches=0、最大绝对误差0，memcheck padding32零错误。ptxas为12 registers/thread、0 barriers、0 stack/spill；PTX1334字节、cubin4456字节。详见 [正式日志](../reports/CH17/completed-2026-11-09.txt) 和 [讲义验证](chapters/17_compilation_artifacts.md#正式补全与验证2026-11-09)。

本次总结核对当前源码、脚本、PTX、cubin及可执行文件哈希与正式日志一致，重读用户贴出的nvdisasm证据，没有重新编译或运行GPU。上述数字是已有验证，不冒充总结时新测量；寄存器数和文件大小不是性能结论。用户已有查看输出及针对性追问，个人编译/Runtime运行、完整独立解释仍待验收。

### 踩坑记录

本章实际疑问集中在：把地址表示转换与float数值转换混为一谈、将寄存器操作理解为一律按地址传值、混淆寄存器名字与硬件编号，以及不清楚ld/st方括号为何位于不同一侧。已用i=131、偏移524字节和C++解引用解释，不把试探性提问或一次确认句当成全部独立掌握证据。

复习时还要分清：PTX版本与GPU能力，PTX虚拟寄存器与ptxas硬件资源，SASS与整个cubin，constant bank的c记法与输出数组c，调试PTX文本保留与机器码逆向还原，以及编译成功、模块加载成功与kernel完成。脚本命令由Codex补全，不能记录为用户独立编写；nvdisasm输出是用户提供的实际查看证据，但不能代替数值或内存安全验证。本章没有性能实验或JIT缓存结论。

### 八股自测

不看讲义，说清.cu、PTX、cubin、SASS文本和普通可执行文件各保存什么、由谁使用；解释PTX中间层为何有价值、为何.target sm_75的PTX仍需编译，以及extern "C"如何帮助Ch18按名找到kernel。

沿block1/thread3说明参数读取、i=131、i×4=524字节偏移、输入读取和输出写回，分别解释%rd8、[%rd8]、cvta.to.global.u64和st.global.f32，指出哪里处理64位地址、哪里读写32位数据。再从SASS找到边界退出、两次读取、一次加法和一次写入，并说明debug/metadata与.text的区别，不能用寄存器声明数或文件大小推出性能。

最后亲自生成并查看两种device产物、运行Runtime校验，指出现有证据没有证明的外部模块加载步骤。能复述局部概念不替代完整验收，Ch17仍保持RUNNING；不追加SASS编码、ELF逐字段、JIT缓存或Ch18实现作为本章门槛。

## 2026-11-11 Ch18：Driver启动、指针参数与CUDA context

### 今日完成任务

围绕 [Driver host源码](../CH18/driver_vector_add.cpp)、[构建脚本](../CH18/compile.sh) 和 [本章讲义](chapters/18_driver_launch.md)，串起“初始化→选择设备/context→加载Ch17 cubin→查找vector_add→准备显存和参数→启动→等待→回读校验→清理”的流程。GPU仍执行Ch17的向量加法；变化是host显式使用Driver API，未新增算法或性能比较。

11月9日的骨架和隔离预检、11月10日的两处TODO正式补全和context打印探针均由Codex完成。用户主动逐段追问CU_CHECK、primary context、句柄、指针的指针、args与launch参数、Runtime/Driver组织方式、previous恢复、资源隔离和卸载；曾明确表示仍不理解context及指针层级，随后尝试复述并继续追问。这些是实际学习过程和理解难点，尚无用户个人重编译/运行或完整独立解释的验收证据。本次总结核对现有源码、构建产物和日志，没有重新运行GPU。

### 基本概念

**从cubin到GPU执行，以及.cpp/.cu的职责**

<span style="color:red">用户提问：cuLaunchKernel是不是执行对应cubin的SASS？当前cpp只是加载已有cubin，真实开发有什么场景？</span>

Ch17的.cu同时包含kernel和Runtime版main；生成cubin时只输出device程序。Ch18的.cpp没有kernel定义，通过g++编译、链接WSL libcuda，实际GPU程序来自 `build/CH17/vector_add.cubin`。`cuModuleLoad`准备模块，`cuModuleGetFunction`取得入口，`cuLaunchKernel`提交工作，GPU执行该入口对应的机器指令；SASS文本是反汇编表示，不是另行读取执行的脚本。后缀不强制选择API：.cu也可调用Driver，普通.cpp也可使用Runtime接口，具体取决于代码与构建方式。

实际用途包括把预编译kernel与host程序分开发送/加载，以及运行时生成CUDA代码后用NVRTC编译、Driver加载启动；CuPy RawModule也公开支持加载cubin/PTX并按名取kernel。这些是官方接口用途，不是本机新增实验。参考 [NVRTC 12.9示例](https://docs.nvidia.com/cuda/archive/12.9.1/nvrtc/index.html)、[CuPy RawModule](https://docs.cupy.dev/en/stable/reference/generated/cupy.RawModule.html)。本章未测框架、JIT或首次加载开销，不推断Runtime/Driver调用严格一一对应。

**CU_CHECK检查什么，返回值与输出参数如何分工**

<span style="color:red">用户提问：为什么需要CU_CHECK？为什么cuCtxSetCurrent直接传context，其他调用却传地址？</span>

Driver API通常返回CUresult状态，CU_CHECK是本项目的宏：先执行调用，再检查是否CUDA_SUCCESS，失败打印API/文件/行号/错误并exit。实际结果如context/module/function通过输出参数写回。它不提供同步，也不会让launch返回自动等同GPU完成。

CUcontext/CUmodule/CUfunction本身是指针形式的不透明句柄；句柄是驱动交给程序、供后续API指认对象的值。变量中只有句柄，不包含整个对象；不能通过解引用读取驱动内部字段。`cuCtxSetCurrent(context)`需要已有句柄作为输入，所以传context；`cuDevicePrimaryCtxRetain(&context, device)`要把句柄写进调用方变量，所以传变量地址。

**为什么module/function需要“指针的指针”**

<span style="color:red">用户提问：为什么cuModuleGetFunction传function和*module？为什么用指针变量的地址这么绕的方式？</span>

先看main：`CUmodule module=nullptr; CUfunction function=nullptr;`，再调用 `load_vector_add(path, &module, &function)`。普通函数参数按值传递；要改写main中的指针变量，就提供该变量所在地址。包装函数的 `CUmodule* module` / `CUfunction* function` 已分别保存这两个输出位置。为便于理解，可以在脑中将其改名为out_module/out_function：

```cpp
cuModuleLoad(out_module, path);  // 往main的module变量写模块句柄
cuModuleGetFunction(out_function, *out_module, "vector_add");
// out_function：新结果写到哪里；*out_module：到哪个已有模块里查找
```

<mark>两层指针对应两层关系：先找到保存句柄的变量，再读写其中的句柄值。</mark> `*module`只读出main变量里保存的模块句柄，没有解引用驱动内部的模块对象。`extern "C"`让Ch17产物保留易查找的vector_add名字。

**args不是输出位置，而是启动参数的取值位置**

<span style="color:red">用户提问：void* args[] = {&d_a, &d_b, &d_c, &n}是干什么的？</span>

GPU入口参数顺序是 `a, b, c, n`。args四项分别指向CPU上保存这些参数值的变量；Driver根据kernel image中的参数信息，从这些位置复制实际值。前三项复制GPU数组地址，第四项复制int1000。void*使不同类型变量的地址可以放进同一个数组，不改变被复制的数据类型或参数顺序。

例如CPU变量d_a里存着GPU地址0x80000000，args[0]保存的是这个CPU变量的地址；Driver读出其中的0x80000000，kernel的a收到这个GPU地址，随后读取显存。kernel不会拿CPU变量地址去访问数组。<mark>同样出现&，module/function输出参数是让API写回新句柄；args中的地址是让Driver读取已有参数值，不能混为一谈。</mark> 本机CUdeviceptr为8字节、int为4字节；数组地址值被传递，不等于整个数组在launch时随参数再次复制。[官方kernelParams语义](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-driver-api/group__CUDA__EXEC.html)。

**cuLaunchKernel配置与完成边界**

<span style="color:red">用户提问：cuLaunchKernel的输入参数各自是干什么的？</span>

| 本例参数 | 作用 |
| --- | --- |
| function | 从模块中找到的vector_add入口句柄 |
| grid,1,1 | X/Y/Z方向block数量，本例8×1×1 |
| block,1,1 | 每个block的X/Y/Z线程数量，本例128×1×1 |
| 0 | 每block额外dynamic shared字节数，不是全部显存用量 |
| 第一个nullptr | 使用默认stream |
| args | 四个kernel参数的取值位置列表 |
| 最后一个nullptr | 不使用extra打包参数方式 |

总共1024个线程覆盖1000个float32元素，额外24个线程由kernel的 `i<n` 保护跳过。提交成功后，main仍需检查 `cuCtxSynchronize()` 的完成结果，再D2H与CPU double reference全量比较；输出先填NaN，以检查错算和漏写。

**context管理什么，在哪里用到了它**

<span style="color:red">用户多次提问：CUDA context到底是什么、里面有什么，CPU线程与它什么关系？能否打印previous/context？</span>

本例context是驱动在GPU0上管理代码、显存、工作队列及配置的运行环境，功能上关联设备、地址空间/内存分配、module/function、stream/event和配置。数组数据实际在显存，context维护资源归属和管理状态；这不是公开的结构体字段清单，更不是保存在局部变量里的整张GPU状态快照。

```text
CPU线程执行main，记录当前选中的context
    → cuModuleLoad：模块加载到当前context
    → cuMemAlloc：在当前context关联设备/地址空间中分配
    → cuLaunchKernel：使用加载的function和分配的数组提交计算
    → cuCtxSynchronize：等待当前context的工作完成
```

`cuCtxGetDevice` / `cuCtxGetFlags`是探针查询当前context设备和配置的直接例子。很多API不再显式传context，是因为驱动维护了调用线程的current绑定；它们可以从这份线程状态取得所需环境。官方模型为每host线程的current context栈；具体内部存储、缓存与调用路径未公开，讲解中的“隐含参数”伪代码不冒充驱动源码。[官方context说明](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-c-programming-guide/index.html#context)。

**previous、retain、current与active不是同一件事**

<span style="color:red">用户提问：是不是先中断CPU任务、把GPU上下文设成CPU现场？如果不是，为什么保存previous并恢复？previous在本例是什么？primary_active又是什么？</span>

CPU始终顺序执行main中的普通API调用。GetCurrent查询线程原来的CUDA绑定，retain取得primary句柄并保持使用引用，set才改变线程选用的CUDA环境；这不等于操作系统保存/恢复CPU寄存器和执行现场，也不让CPU线程变成GPU kernel线程。previous与context均为CUcontext，分别保存“原来的选择”与“本段要用的句柄”，不保证一定指向不同对象。

11月10日探针实际关系如下，H只是非空句柄的缩写：

| 阶段 | previous | context | 线程current | primary_active |
| --- | --- | --- | --- | --- |
| after_get | 空 | 空 | 空 | 0 |
| after_retain | 空 | H | 空 | 1 |
| after_set | 空 | H | H | 1 |
| after_restore | 空 | H | 空 | 1 |
| after_release | 空 | 空 | 空 | 0 |

本例previous=nullptr，没有一个先前绑定的context要切回；最后set(nullptr)解除绑定。保存/恢复是可复用代码中常见的临时选择管理：外层若用A，本段临时用B，返回前恢复A，避免外层后续的无显式context调用意外落到B。例如 `cuMemAlloc(&p, bytes)` 没有device/stream参数，`cuCtxSynchronize()`连参数都没有，二者会依赖current；已有A的地址和句柄不会因切换而自动变成B的资源。

primary_active是查询输出的0/1，表示primary是否活跃，不是GPU忙碌率、线程绑定状态或引用计数。retain后active1但current仍空，正好区分这两个概念；本例释放最后引用后active0。release不会改写局部context变量，探针里最后的nullptr由代码显式赋值。地址、TID和8字节句柄大小不能解释成内部对象布局；primary_flags0x0/current_flags0x8只是本机不同查询的原始配置返回，不推导内部实现差异。

**资源归属与跨context数据：只做概念连接**

<span style="color:red">用户提问：context像Python虚拟环境吗？不同context互不影响吗？显存独立吗？跨context参数怎么传？</span>

venv主要管理解释器/包依赖，CUDA context管理GPU资源。对本章cuMemAlloc普通分配，不应假定A的device指针可直接用于B的kernel；但同卡的两个context共同消耗物理显存、计算能力和带宽，不各自独享一整张卡，也不保证性能互不影响。资源归属/访问权限与物理硬件共享需要分开理解。

标量n可以分别按值传给两边kernel；device地址的数值被复制，不代表数组被复制或访问权限自动开放。跨context数组可显式复制（如 `cuMemcpyPeer(dst_B, ctxB, src_A, ctxA, bytes)`，或经host中转），也可在支持条件下用peer访问等共享机制，仍需安排生产者写完与消费者读取的依赖。若本来只是同一程序的两个kernel协作，可放在同一context内复用buffer。参考 [跨context复制](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-driver-api/group__CUDA__MEM.html)、[peer访问](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-driver-api/group__CUDA__PEER__ACCESS.html)；本机没有运行多context、peer、IPC、VMM或多卡实验，不增加为本章门槛。

**清理顺序、module不卸载和保留的失败分支**

<span style="color:red">用户提问：if(!load_vector_add(...))这一段干什么？module不unload会怎样？</span>

正常结束先释放d_c/d_b/d_a，再卸载module、恢复previous并release本程序的primary使用引用。unload释放已加载模块相关资源，不删除磁盘cubin，也不代替单独分配数组的cuMemFree；模块卸载后旧module/function句柄不能继续使用。有意保留模块复用是正常策略；反复加载不用的模块而不卸载，资源可能累积。本例最后一个primary引用释放时会reset并清理相应资源，因此省略unload通常不影响已完成结果，但不能把所有release都当成最后引用，也不依赖其他使用者结束才清理自己的模块。[官方module](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-driver-api/group__CUDA__MODULE.html)、[primary release](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-driver-api/group__CUDA__PRIMARY__CTX.html)。

<mark>当前load_vector_add成功固定返回true，API失败则CU_CHECK直接exit；因此main中的if(!load_vector_add(...))清理分支已无法通过这两类路径进入。</mark> 它是原TODO骨架遗留，不是当前可靠的API失败清理路径。launch包装函数也保留“成功true、错误exit”的接口。本次总结只解释实际控制流，未把短练习重构成生产级错误资源管理框架。

**已有验证及其边界**

11月10日 [正式补全日志](../reports/CH18/completed-2026-11-10.txt) 记录Runtime/Driver全量1000项正确、最大误差0、正式Driver memcheck padding32零错误，另检查缺失cubin报CUDA_ERROR_FILE_NOT_FOUND/退出1、多余host参数退出2、从/tmp传绝对路径成功，以及ldd无libcudart依赖。之后增加探针，当前源码/脚本/cubin/Driver可执行文件SHA-256均与 [探针日志](../reports/CH18/context-probe-2026-11-10.txt) 一致。该日志的GTX1650/CC7.5/14SM、KMD610.88、DriverAPI13030、g++13.3.0、Compute Sanitizer2025.2.1.0为当时实测；n1000/float32/grid8/block128、每数组4000字节，普通及memcheck运行均PASS，内存检查零错误。

无探针正式日志里的Driver源码/可执行文件哈希与当前不同，是后续增加探针的预期结果，不把两份构建冒充同一版本。此次仅核对已有日志和哈希，没有新编译/运行、性能计时或profiler采集；所有计数和环境均按历史证据引用。没有Runtime/Driver内部调用映射或性能比较结论，所有实现与工具验证仍归Codex辅助。

### 踩坑记录

本章真实理解难点集中于把“CPU线程的CUDA环境选择”当成操作系统CPU现场切换、把句柄值当成完整GPU状态、把primary active当成GPU正在执行、把previous误认为一定已有另一个context，以及认为所有CUDA调用都显式指定了device/stream。已沿本例的nil→H、current和active变化及无context参数的分配/同步说明，但不能据此补记独立掌握。

指针部分需要继续区分：句柄变量与句柄值、输出位置与args的取值位置、`*module`读取句柄与解引用驱动内部对象、复制GPU地址与复制数组。用户曾尝试说明指针的指针，随后明确表示“有点扯不清楚”，保留为待自测内容。另需避免把模块加载成功等同kernel执行完成、把未进入的false分支当作真实错误回收、把context隔离解释为独占物理显存或任意跨context指针可用。

### 八股自测

不看讲义，从cubin路径沿context→module→function→args→launch→同步→回读说明整条链，并用一个具体地址例子解释两种&的用途：为什么module/function要输出位置，而args提供输入参数取值位置；指出grid8/block128如何覆盖1000项，以及两个nullptr各代表什么。

再结合自己的探针输出，说明retain与set的区别、previous为什么可能为空、active为什么不能证明GPU忙碌，以及若外层使用A而函数返回后current仍为B，cuMemAlloc/cuCtxSynchronize会受什么影响。能指出当前false清理分支为何不执行、module卸载与显存释放各负责什么即可；跨context/peer/JIT只保留概念边界，不增加实现验收。

后续独立运行正式程序并解释上述关键关系，再按PLAN判断验收。当前Ch18保持RUNNING，个人运行和完整独立解释待补齐，不以Codex预检、指针复述或探针打印单独认定课程完成。

## 2026-11-18 Ch19：内存复用、分配生命周期与计时边界

### 今日完成任务

本次汇总11月11日至18日的Ch19学习与实验，不表示全部工作在今天完成。程序固定32轮向量加法、每轮1000个float32元素、grid8/block128，只对照GPU工作空间在循环内反复分配释放，还是在循环外准备后复用。[正式源码](../CH19/memory_reuse.cu) 的唯一TODO已于11月17日按用户要求由Codex补全，构建、校验、Sanitizer、普通计时和后续NSYS诊断也由Codex执行。

用户逐段询问run_batch、main中的策略选择/预热/计时流程、三个时间的含义，以及Event为何不同、是否与换地址访存有关。用户最后主动归纳：“复用分配空间可以节约每次反复申请和释放的时间开销，而event时间差异不是必然有巨大差别。”该归纳准确，记录为核心结论已复述；尚无用户个人运行、采集或完整独立解释的证据，不等同于独立实现或全章验收。

### 基本概念

**复用的是空间，生命周期决定分配放在哪里**

<mark>先申请三块GPU空间，连续处理32轮新数据，最后释放；直接节省的是反复申请和释放的管理开销。</mark> 两种策略执行相同的上传、输出初始化、kernel、等待和回读，每轮输入仍然更新，kernel数量仍为32。复用不等于复用旧答案，也不要求把32轮工作数组都留在device上。

```text
per_step：重复32轮〔申请a/b/c → 上传 → 计算 → 等待 → 回读 → 释放〕
reuse：   申请a/b/c → 重复32轮〔上传 → 计算 → 等待 → 回读〕→ 释放
```

`prepare_reuse_buffers()`调用allocate_buffers并返回true，run_batch在for循环前执行它；复用路径循环中跳过申请释放，循环后才清理。每轮分配策略整批malloc/free各96次；复用整批各3次、循环内各0次。计数是本程序发出的成功Runtime调用，不是驱动内部调用或物理显存分配次数。空间必须在所有访问和必要回读完成后才能覆盖或释放；本例run_step逐轮等待并回读，满足复用条件。

**一批数据如何进入32轮计算**

<span style="color:red">用户提问：讲解run_batch及main中214～260行的实现。</span>

main提前准备32轮host输入，run_batch用offset=step×1000选择当前片段。step3读取a/b的第3000～3999项，上传到本轮device数组，再把结果回读到output相同片段；复用时device地址保留，内容每轮更新。result清零后保存调用计数，before_loop是进入循环时的副本，相减得到循环内增量。run_batch返回true只表示流程走通，数值与调用数由validate另查。

main用policy0/1表示每轮分配/复用，selection决定policies包含哪一项；strcmp相等返回0，因此不加!时表示“不相等”。局部execute包装run_batch与validate，前者成功才校验。check只做初始验证；bench与trace先各预热3批，bench再测21批、交替策略顺序，分别存储样本并取中位数；trace只选一个策略，采预热后的目标批次。每次execute是一批32轮，不是一个kernel。失败状态阻止继续发布计时，结束后销毁Event。

**三个时间分别回答不同问题**

<span style="color:red">用户提问：time.host_loop_us、time.host_lifecycle_us、time.event_sum_us分别是什么含义？</span>

| 字段，单位μs/批 | 起止与范围 | 用来观察什么 |
| --- | --- | --- |
| host_loop_us | CPU的t0→t1；32轮传输、初始化、提交、等待、回读及循环内分配释放 | 已准备好复用空间后的循环耗时 |
| host_lifecycle_us | CPU的life0→life1；还包括循环外准备和最终释放 | 计入准备/清理成本后，整批是否仍更快 |
| event_sum_us | 32轮GPU start→stop Event区间之和，由毫秒转成微秒 | 每次kernel前后两个标记之间的设备时间 |

<mark>host_lifecycle包含host_loop；Event区间也与CPU观察的工作发生重叠，三个时间不能相加。</mark> 两个CPU时间不是仅提交launch的时间，包含完成等待；CPU reference校验在正式批次计时外。

**Event覆盖整次启动完成，但不等同于纯kernel色块**

<span style="color:red">用户提问：event_sum每次累加的是一个线程的时间，还是一个kernel全部执行完成的时间？不是只夹住kernel吗，为什么两方案会差这么多？</span>

Event不测某个线程，也不把1024个线程的耗时相加。stop排在该次kernel之后，覆盖所有block执行完成；这不表示kernel内部新增一次全体线程barrier。CPU依次提交start、kernel、错误检查和stop，GPU同时向前推进；两个设备标记之间可能存在尚未执行该kernel的间隔。<mark>因此Event计时是设备上的两标记区间，不能自动替换成NSYS kernel色块的持续时间。</mark>

11月17日同次NSYS第二轮，每轮分配方案前间隔3.200μs、kernel2.432μs、后间隔7.936μs，设备标记窗口13.568μs；复用对应3.072/1.599/4.064μs，窗口8.735μs。全部逐轮设备Event窗口内均无显式memcpy/memset，不能把这些间隔说成本程序H2D/D2H；分配释放同样位于当前Event区间之外。设备Event标记跨度与Event API读数还有不一致，必须分列，不能强行凑成同一个精确数值。图为SQLite端点重绘，非GUI截图，详见 [NSYS分析](chapters/19_memory_reuse.md#nsys三个时间为什么不同2026-11-17)。

**本章性能结论与尚未确定的部分**

<span style="color:red">用户提问：还是没回答为什么两方案间隔不同；是否每轮换地址取数有额外开销？</span>

正式11月17日普通bench各预热3批、测量21批。每轮分配/复用的CPU完整生命周期中位数为24551.166/5404.955μs，而Event合计为601.440/373.856μs；这些数来自同一轮正式普通测量，不能和NSYS采集时的耗时拼接。两条路径各32000项全部正确、最大误差0，memcheck零错误、零泄漏；本次总结只复核已有记录，没有重新运行。

额外诊断显示，反复分配时a虚拟地址可以始终相同；仅额外保留不用的分配，也会改变后续分配和提交API成本。32组预分配地址轮换也没有必然更慢。它说明影响因素不止“地址值是否变化”，但虚拟地址相同不证明物理映射/cache/TLB状态相同。Graph把Event→kernel→Event连成一次提交也改变测量结果；这些对照支持分配状态与提交结构会影响观察值，没有揭示驱动内部唯一慢路径。

11月18日原正式程序的一次Event中位数为411.200/398.048μs，另一次为558.976/294.560μs，差距并不固定。<mark>复用直接减少反复分配释放的工作；Event差异不是必然巨大，也不能用某次Event差值断言kernel计算本身获得固定加速。</mark> 完整实验、辅助程度和原始报告统一见 [Ch19讲义](chapters/19_memory_reuse.md) 与 [RECORD](RECORD.md)，内部原因未确定的部分保留为未确定，不加入本章额外验收门槛。

### 踩坑记录

实际理解难点是把“两个Event夹住kernel”直接等同于“只统计kernel正在执行的时间”，以及希望用地址变化解释全部差异。应分别看CPU API、GPU kernel、设备Event标记和Event API读数，不能把GPU端间隔自动归因到某个CPU调用，更不能用跨轨绝对端点强行还原精确等待。

同样要避免把循环外分配成本当成消失、把复用当作省掉传输或计算、把重新申请得到相同地址当作没有分配调用，以及把NSYS或Sanitizer条件下的耗时当普通bench。早先“可能的提交节奏”解释没有确定唯一内部原因，最终结论保留这一边界。用户已正确复述核心结论，具体源码/计时边界的完整独立表达仍待自测。

### 八股自测

沿源码说明为什么malloc/free从整批各96次变成各3次，而循环内是0次；为什么32次kernel和新输入上传仍然保留，以及哪一步保证下一轮可安全覆盖旧空间。

再用自己的话画出life0→t0→循环→t1→life1，并指出start Event、kernel和stop Event的位置：三个时间为什么不能相加？如果复用后Event几乎不变、但CPU整批明显缩短，为什么仍能说明复用有价值？个人运行和完整解释达到PLAN验收后，再更新章节状态。

## 2026-11-19 Ch20：单 stream 异步分配与内存池

### 今日完成任务

汇总11月18日至19日的Ch20学习与实验。[源码](../CH20/async_pool.cu)固定32轮，每轮1000个float32元素，grid=8、block=128，`a/b/c`各4000字节。两条路线使用相同的H2D、输出初始化、vector add和D2H，只对照普通分配释放与同stream异步分配释放。两处TODO由Codex按用户要求补全，正式验证、复测与驱动探针也由Codex执行。

用户逐行询问内存池能力查询、池配置、验证/计时/清理和`print_pool()`，其中能力查询与池配置的行号后来随两处TODO补全调整。后续追问集中在池从哪来、普通API能否使用池、两条路径都等待为什么仍有差距、CH20相比CH19有什么优势，以及4000B为什么对应32MiB储备。

### 基本概念

**先看一轮如何执行。** `run_batch`按`step×1000`选择host片段，`enqueue_work`在同一stream提交H2D(a/b) → memset(c) → vector_add → D2H(c)。普通路径在第109行等这些工作完成后，第110行才调用三次`cudaFree`。异步路径在第107行已经把三次`cudaFreeAsync`排在D2H后，第109行一起等回读和释放完成。两条路径都逐轮等待，下一轮都重新申请三个数组，所以整批都是申请96次、释放96次。<mark>异步让CPU能提前提交释放。stream仍按顺序执行，当前程序仍等完这一轮才进入下一轮。</mark> [循环源码](../CH20/async_pool.cu#L97)

**池来自哪里，API如何选池。** 第171行的`CUDA_CHECK`检查查询调用是否成功，`supported`接收设备能力值。第189行取得GPU 0当前池的句柄，程序使用CUDA提供的默认池。`cudaMallocAsync(&b.a, kBytes, stream)`根据stream所属设备选池，并把地址写回host上的`b.a`。`cudaFreeAsync(b.a, stream)`读取该地址，向stream提交释放，随后将host变量清空。普通`cudaMalloc`走传统分配接口。CUDA支持两种API混用，释放前仍需保证相关访问完成。例如把`cudaMallocAsync`的地址传给普通`cudaFree`时，调用方需要先确认GPU已经用完。 [CUDA内存池文档](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-runtime-api/group__CUDART__MEMORY__POOLS.html) · [NVIDIA混用说明](https://developer.nvidia.com/blog/using-cuda-stream-ordered-memory-allocator-part-2/)

**日志里的两次归还。** `used`是池当前分给应用使用的字节数，`reserved`是池当前持有的底层显存量。`cudaFreeAsync`执行完成后，数组交回池，`used`下降。释放后同步时，池持有量超过release threshold，CUDA会尝试把可归还的空闲显存交给系统。尾部的`cudaMemPoolTrimTo(pool, 0)`显式请求归还空闲储备，第254行再恢复之前保存的阈值。正式`bench both`的四个观测点如下。

| 源码打印位置 | 对应阶段 | `used` | `reserved` |
| --- | --- | ---: | ---: |
| 第197行 `before` | 取池并设置64MiB阈值后，异步申请前 | 0 B | 0 B |
| 第223行 `after_async_check` | 首批32轮异步校验后 | 0 B | 32 MiB |
| 第251行 `after_selected_work` | 预热和计时结束并确认完成后 | 0 B | 32 MiB |
| 第253行 `after_trim` | 显式trim后 | 0 B | 0 B |

正式版在整批边界读数。另一个探针只申请一个4000B数组，在释放前实测`used=4000、reserved=32MiB`。每轮三个数组请求量合计12000B，和池从系统取得的底层储备是两个数量。8MiB阈值与64MiB阈值下首次请求4000B，都观测到32MiB储备。释放并同步后，前者实测reserved归零，后者留下32MiB。<mark>阈值和reserved比较，影响的是空闲储备何时尝试归还。它既不决定首次取得多少显存，也不限制池能取得多少。</mark> [正式池日志](../reports/CH20/completed-2026-11-18.txt) · [阈值和申请大小对照](../reports/CH20/pool-size-check-2026-11-19-160346.txt)

**本机32MiB出现在哪里。** `cudaMallocAsync`和直接Driver API都测到相同的储备，显式新建的池也一样。同机直接VMM的最小、推荐分配粒度均为2MiB，实际2MiB分配成功。追到WSL用户态驱动后，4000B池申请时有一条8192页的映射请求，33MiB池申请时有两条同样大小的请求，分别对应池统计的32MiB和64MiB。NVIDIA桥接库在调用`libdxcore`前已把字节数转为4KiB页数，`libdxcore`把结构体传入`/dev/dxg`。因此32MiB在进内核前已出现在请求里。当前证据定位到这条用户态驱动的池扩充路径，内部究竟是常量还是由设备或运行配置算出仍未确定。32MiB不能推广成所有设备的固定粒度，这段驱动追踪只用于回答追问。 [Driver对照](../reports/CH20/pool-driver-check-2026-11-19-160908.txt) · [WSL调用栈](../reports/CH20/pool-dxg-stack-2026-11-19-161320.txt)

**为什么变快，和CH19有什么区别。** CH19把三个固定数组留在循环外，由程序一直持有，整批申请、释放各3次，循环内各0次。CH20允许各轮或各函数继续自行申请释放，底层空闲显存由CUDA池保留，下次请求合适大小时有机会复用。对于本实验这样固定形状、同一处控制整个循环的代码，CH19更直接。池的优势在于可以保留按需申请的接口，而CUDA负责管理底层空闲储备。两者的kernel都读写global memory，池复用发生在取得地址的阶段。

`check`只跑初始校验。`bench`在正确性检查后每策略预热3批，交替顺序测21批并取中位数。`trace`只选一条策略，独立采集预热后的一批。`host_batch_us`用CPU时钟测从首轮申请前到末轮同步和释放完成，包含提交、拷贝、计算、释放及等待。池设置、CPU数值校验与最终trim在外。11月18日普通bench为**24.220 ms / 3.770 ms**，11月19日同一正式构建重跑为**25.689 ms / 4.162 ms**（普通/异步，32轮每批）。CH19循环外复用没有进入CH20同一套计时对照。 [首次正式计时](../reports/CH20/completed-2026-11-18.txt) · [11月19日复测](../reports/CH20/bench-2026-11-19-152127.txt)

独立NSYS的一批两策略均有32个kernel、64次H2D、32次D2H和32次memset。CPU申请/释放API合计为**15.42 / 0.35 ms**，GPU实际拷贝、初始化和计算合计为**0.410 / 0.314 ms**，GPU上一轮回读结束到下一轮上传开始的31段间隔合计为**18.83 / 1.79 ms**。从CPU同步返回到下一轮第一次上传调用开始，普通路线要先做三次free再做三次malloc，异步路线只剩下一轮的三次mallocAsync，这段中位数为**446.84 / 5.75 μs**。这些读数显示主要差距在申请/释放调用与轮间衔接。CPU API与GPU空档会覆盖部分相同的时间。现有对照无法把整批收益精确分给提前提交、复用储备或驱动内部各环节。 [普通NSYS SQLite](../reports/CH20/completed-sync-2026-11-18.sqlite) · [异步NSYS SQLite](../reports/CH20/completed-async-2026-11-18.sqlite)

### 踩坑记录

用户曾把“CPU可以先提交释放”理解为“接着直接提交下一轮”。本章第109行仍逐轮等完，实际区别是释放命令排在等待的前面还是CPU等完才调用释放。用户后来指出两条路径都必须释放三个数组并等完成，kernel也仍读写global memory，讨论据此把收益定位到分配管理和提交衔接。另一个易混点是用12000B去和8MiB比。阈值比较的是池实际持有的32MiB，释放后`used=0`和`reserved=32MiB`可以同时成立。8MiB历史预检中储备在同步后回到0，那次异步整批约67.18ms，说明这一实验里保留策略会显著影响结果，不能只看API名称判断速度。 [8MiB历史预检](../reports/CH20/pilot-8MiB-2026-11-18.txt)

### 八股自测

从第0轮回读开始，分别说出CPU何时调用释放、GPU何时才执行释放、第1轮何时可以申请并上传。根据日志解释4000B、32MiB和64MiB分别从哪里来，再说出为什么used可以为0、reserved仍有32MiB，以及trim之后为何变为0。最后对比CH19的3/3、循环内0/0和CH20的96/96，说明两者各留住什么，并用普通bench与NSYS分别指出整批差距和轮间空档的证据。个人运行和完整独立解释待验收，私有驱动规则不列入验收。
