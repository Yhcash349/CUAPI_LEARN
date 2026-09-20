# CUAPI_LEARN 执行计划

本文件是本项目唯一的课程与工程执行计划。2026-09-20 用户要求将原 V2 与本机评估整合到本文件，并在完整迁移后删除两份来源文件；后续执行统一按本文件及用户最新明确指令进行。当前已完成计划整合、环境预检和 Ch00 完整代码（用户要求 Codex 代为完成），程序验证通过，用户解释待验收；已按用户最新要求准备 Ch01 任务和练习骨架，具体进度见 RECORD。

## 1. 任务背景、用户需求与项目主旨

最初的工作背景是 CUDA Runtime API 梳理、NSYS trace 分析、Runtime 与 Driver 的关联，以及推理框架运行过程分析；长期希望能把框架行为转化为 runtime/simulator 同事可使用的接口需求和证据报告。

用户当前优先目标是以亲手编写程序为引子，快速熟悉 CUDA 必要知识与 NVIDIA GPU 硬件设计逻辑。知识点必须能在代码、正确性结果、时间线或硬件计数器中体现；每章最多约 1 小时，内容少而清楚，不钻低收益细节。原 V2 必修至少 99 小时，不适合作为本轮直接执行清单。

项目定位是实践学习。采用“先写或改程序→预测现象→运行观察→按需查官方语义和机制→解释结果”的路径。首轮约 15～20 小时；保留长期工作背景，但不把完整框架分析、API 清单工程或生产级优化当作首轮毕业门槛。

## 2. 目标、边界与成功标准

首轮完成后，应能编译、修改和验证小型 CUDA 程序，解释 host/device 数据流、线程组织、warp、访存与协作、资源限制、异步与依赖；能用 NSYS 对应 CPU 调用与 GPU 活动，用少量 NCU 指标解释访问或资源变化；能运行基础 Graph，并看懂同一 kernel 的编译产物和 Driver 启动路径。

每章验收为“运行正确、能指出对应代码或证据、能用自己的话解释一个现象”。性能实验不预设必须达到某个加速比。不要求从零独立写全部 host 工程，也不把 agent 提供骨架后的完成记为完全独立实现。

首轮不做大模型下载、完整 Transformer、框架环境扩建、生产级 allocator、Hook/CUPTI 工程、完整 SQL schema 工具链或多卡系统。不深入 SASS 调优、Tensor Core MMA、图形互操作、Green Context、动态并行、多节点通信、全套 Unified Memory/offload、Programmatic Dependent Launch。后续实际需要时再评估，不能仅为覆盖文档而增加必修。

## 3. 本机基线与技术选择

2026-09-20 实测：GTX 1650 约 4 GiB、CC 7.5、14 SM、warp 32；WSL2；NVCC/Toolkit 12.9.86；NSYS 2026.4.1；NCU 2025.2.1。已通过最小 kernel 正确性与两款 profiler 的采集检查。完整属性、版本含义、命令及证据边界见 [ENVIRONMENT.md](ENVIRONMENT.md)。这不是所有课程实验已验证的声明。

使用 CUDA C++、本机 Toolkit 12.9 和 `sm_75`。初期每章给最短 `nvcc` 命令，后续需要统一构建时再引入简单 CMake，设置 `CMAKE_CUDA_ARCHITECTURES=75`。不为学习建立复杂框架。只支持当前 WSL2 环境，不额外承担原生 Windows 或跨平台适配。

GTX 1650 没有 Tensor Core，多卡功能也无法在本机完成实践验收；对应内容等待适合硬件。4GB 下使用小数组和小矩阵，不能把该卡结论泛化到所有 NVIDIA 架构。能力查询只说明支持条件，不保证双 stream 一定并发、拷贝一定重叠或某种算法一定更快。

## 4. 单章教学方式与时间边界

每章 45～60 分钟：约 5 分钟任务与预测、10 分钟读旧代码、20 分钟补关键实现、15 分钟运行对照、10 分钟解释复盘。聚焦 1～2 个核心新知识，一个必做实验、一个主要变量。新术语先用一句直觉解释，再指向代码。细分 API 名称不逐项扩成知识课。

Codex 提供可运行的 host、输入、CPU reference、校验和计时骨架；用户完成关键 kernel/API 修改。首次使用 helper 时解释用途，后续复用。复杂章节只填关键部分，不能要求一小时从空文件写完整工程。正式授课前验证骨架和微基准，准备失败时明确阻塞，不占满学生一节课。

依次推进，完成当前章再准备下一章，不一次生成全部课程或所有答案。用户明确要求完整实现时按其指令执行，并记录辅助程度。普通分支、访存和同步的错误示例可能受编译器和运行条件影响，不把偶然错误当成稳定教学证据。

一小时到点仍有问题，记录实际结果与未解决项，必要时另开短节；不临时追加 SASS、驱动排障或深层框架知识。未完成不能记 DONE。

## 5. 首轮章节与阶段验收

以下 Ch00～19 为唯一有效的首轮编号，按顺序学习，默认以前面章节为前提。旧 V2 编号仅用于工程记录中的迁移追踪。

| 章 | 程序任务 | 直观观察与设计逻辑 |
| --- | --- | --- |
| 00 环境 | 编译 device probe，读取设备属性 | 分清 GPU、Driver、Toolkit，看到 warp/SM/存储资源上限 |
| 01 第一个 kernel | 补全 vector add | CPU 准备→拷贝→GPU 计算→回读，逐元素验证 |
| 02 线程索引 | N=1000，block=128，补全索引与越界保护 | 8 个 block、1024 个线程覆盖 1000 个元素，理解工作划分 |
| 03 错误检查 | 加 CUDA_CHECK，分别运行非法 launch 和越界案例 | 区分 launch 错误与执行错误；越界用 Compute Sanitizer 检查，不依赖碰巧崩溃 |
| 04 正确计时 | 为 vector add 加预热、CPU timer 和同 stream CUDA Event | 分开 kernel 时间和含传输总时间；小任务 GPU 未必更快 |
| 05 NSYS | 采集现有 vector add | 只找 API、memcpy、kernel 三类轨迹，对应 CPU/GPU 工作 |
| 06 warp 执行 | 输出少量 lane 编号，对照 warp 内/warp 间分支 | 理解 32 线程一组执行；分支可能被编译器改写，不承诺固定减速 |
| 07 合并访存与 NCU | 连续/跨步访问，保持逻辑工作量可比 | 学一个 NCU 命令，观察事务效率和计时；相邻线程相邻地址更易合并 |
| 08 shared 与同步 | 用 shared buffer 交换线程数据，加 block barrier | 验证线程间数据交换，解释 block 内协作；错误案例可用 racecheck，不以偶然错误作为验收 |
| 09 bank conflict | 同一列访问，比较 shared tile 的 stride 32/33 | 用 bank-conflict 指标解释 padding；区别于 global 合并访存 |
| 10 归约 | 在骨架中补 block sum，再加入 warp shuffle | 验证总和；体会线程合作与减少 shared/barrier 的动机 |
| 11 SM 与 occupancy | 固定 kernel，增加预留 dynamic shared memory | 查 occupancy API 和 NCU，看到资源限制驻留 block；高 occupancy 不等于高性能 |
| 12 数据复用 | 补全小型 FP32 tiled GEMM 的装载和累加 | 与 naive GEMM 校验、计时，看到 global→shared→register 的复用；性能差异以实测为准 |
| 13 Host 异步 | 对照只测 launch 与等待执行完成 | API 返回不等于 GPU 完成；与 Ch04 正确计时呼应 |
| 14 Stream | 两个无数据依赖 kernel 放同/不同 stream | timeline 观察有序队列和并发条件；stream 不是固定 SM |
| 15 Event 与重叠 | 两个独立数据块，pinned copy stream 与 compute stream 用 Event 接力 | 对照串行与流水执行，观察实际重叠及依赖；复用已给双缓冲骨架 |
| 16 Graph | 对固定小 kernel 链做 capture/replay | 输出一致，对照 CPU 提交次数和间隙；graph 不会自动融合 kernel |
| 17 编译产物 | 同一 kernel 生成 PTX/cubin 并查看产物 | 理解中间表示与目标 GPU 机器码；首轮不做 JIT 缓存性能分析 |
| 18 Driver | 在骨架中加载 Ch17 cubin 并启动 vector add | 对照 Runtime 版本，看到 context/module/function/launch；不宣称 API 严格一一对应 |
| 19 内存复用 | 比较循环分配释放与循环外分配复用 | 校验相同结果，查看稳态分配调用数；理解复用动机，不实现完整 allocator |


阶段 A 为 Ch00～05，验收 vector add 正确性、索引、错误检查、计时和最小 timeline 闭环。阶段 B 为 Ch06～12，验收线程协作与访存/资源对照。阶段 C 为 Ch13～16，验收异步、依赖、流水和 Graph。阶段 D 为 Ch17～19，验收编译产物、Runtime/Driver 对照及内存复用。阶段产物是代码、短实验记录和相关证据，不另写长篇交付报告。

Ch06、09 的微基准应由教学方事先验证没有被编译器消除或变成别的访问/执行形式；相关源码/SASS 排查不计入学生必学内容。Ch10 第一版只处理固定完整 warp 的输入，mask 和尾部泛化留作选修。Ch11 通过 dynamic shared memory 单变量实验看资源限制，寄存器限制只对应编译报告，不同时调多个参数。

Ch12 的手写 GEMM 只做单层 tiling；cuBLAS、完整 Roofline 和低精度对比不挤入同一小时。缓存层次仅结合 NCU 已显示的数据位置作简要说明，不要求首轮反推出硬件缓存策略。


Ch04 只学习同一 stream 内 Event 计时，跨 stream 依赖到 Ch15 再讲。Ch05 正式引入 NSYS，Ch07 正式引入 NCU；此前的工具执行可由 Codex 做环境预检，不能要求用户提前解释指标。Ch13 之前只给运行和计时所需的最小异步说明。

Ch15 先使用相互独立的数据块和双缓冲骨架；不能把同一步有数据依赖的 H2D→计算→D2H 强行重叠。Ch16 使用已预热、预分配、固定地址的小 kernel 链，先检查 capture 合法性，不要求掌握所有 capture mode 或跨 stream capture。Ch18 采用 primary context、module/function 和 `cuLaunchKernel` 骨架，复用 Ch17 cubin；显式 context、Driver entry point 等留给选修。

## 6. 后续选修：保留原工作主线

选修不是自动排入的课程。由用户工作需求触发，先将当前要做的小节、依赖和验收加入本计划，每节仍最多 1 小时；下表是主题及拆分方向，不意味着一行可以一节讲完。不得重新引入“必须完成所有进阶主题才能学 Graph”的依赖。

| 方向 | 启动前提 | 保留的实验与验收思想 |
| --- | --- | --- |
| 库与性能直觉 | Ch12、17 | cuBLAS 小 GEMM/GEMV，对比 shape、latency、带宽、FLOPS；算术强度/Roofline 单独小节，低精度和 Tensor Core 按硬件另定 |
| 首次调用、JIT、加载 | Ch04、17、18 | 区分 Runtime/context 初始化、module lazy loading、PTX JIT；比较匹配 cubin 与仅 PTX、记录缓存及 CUDA_MODULE_LOADING，不能把首次开销全部归于 malloc |
| Framework/JIT trace | Ch05、17、18，已具备对应环境 | 分别安排 cuBLAS、PyTorch 小 MLP、Triton 小 kernel；区分库、框架、JIT、自写及 unknown kernel，分开首次调用与稳态 |
| Mini Decode | Ch10、13～16 | 固定 toy kernel 链、metadata、sampling-like top1、token 回读；不用真实 Transformer，记录每 step API/kernel/同步数和 CPU/GPU 间隙 |
| Runtime/Driver 与 API Inventory | Ch05、18，先有简单可复现 trace | 同一 vector add 两种 API 实现对照；再做结构化 CSV/SQLite 清单、名称归一化与关联；规范见下一节 |
| Decode Graph | Ch16、Mini Decode | 静态 input/metadata/output/workspace，更新内容，按 batch=1/2/4/8 等分桶；观察 replay、内存 pool，实际 trace 决定 prefill/decode 使用情况 |
| Allocator | Ch19；推理关联另需 Mini Decode | 分别安排 malloc/free 与 async pool、简单 arena/free-list/reuse、KV pool 规划；warmup 后观察稳态分配次数，不假定真实框架每 step malloc/free |
| VMM | Ch18、Allocator，先查设备及环境支持 | 单独安排地址预留、物理内存创建、映射、访问权限与释放的小 demo；不假定 PyTorch expandable segments 已启用 |
| Hook/CUPTI | Ch18、API Inventory | 先普通 C 动态库 LD_PRELOAD/dlsym/RTLD_NEXT，再 Driver 拦截与 cuGetProcAddress，最后最小 CUPTI callback；分节推进 |
| 真实框架分析 | 已完成所需库/trace、Mini Decode、Inventory 等依赖；按实际功能补 Graph/Allocator | cuBLAS→MLP→Tiny Transformer→工作目标框架；按多节完成阶段、内存、stream、kernel、Graph 与接口报告，不要求先学所有 Hook/VMM |
| 多卡 P2P/IPC/NCCL | 有相应硬件，Ch18 及 stream/trace 基础 | 观察 peer copy、IPC/VMM handle、通信 kernel 与 compute/comm overlap，不扩为完整分布式系统 |

Hook 必须用 `ldd/readelf/nm` 查实际 cudart 链接方式；静态 cudart 不能假定可由普通 LD_PRELOAD 覆盖，Driver 函数指针入口也不能当作普通符号调用。CUPTI 只学习 domain、callback id、enter/exit、metadata；环境不支持时用 NSYS 导出完成 Inventory，并明确标注 callback demo 未完成。

长期能力链为 Framework→Runtime/Libraries→Driver→GPU：能把阶段、API、kernel、memory、stream/event 与证据串起来，形成 runtime/simulator 接口需求；它是后续应用方向，不替代首轮学习验收。

## 7. 工具使用、实验规范与证据诚信

运行前写预测，运行后只记录实际结果。无法执行写 `NOT RUN` 和原因，不能猜测 profiler 指标、GPU 型号、kernel 名称或 trace。代码、命令、环境、shape/dtype、正确性误差及 report 路径必须能对应；理论推断、工具计数、计时结果和未测试假设分别表述。

先正确再计时。性能实验关闭 kernel printf，至少 warmup 3 次、重复 20 次，默认报告中位数；短 kernel 可批量重复并说明归一化方式，稳定性不足再适当增加，不把固定次数当作可靠性的保证。CPU timer 测 host elapsed 时在正确边界同步；Ch04 起 GPU elapsed 用同 stream CUDA Event；两种时间不能混用。冷启动另行设计，不混入稳态统计。

正常计时与 profiler 分开运行。NSYS 从 API/kernel/memcpy timeline 入手，后续才按需引入 NVTX、cudaProfilerStart/Stop 和 capture range，区分初始化、warmup、稳态与 cleanup；确认本机选项再使用 Graph node trace。NCU 只选目标 kernel 和少数 launch，按 Summary/Launch→相关 Memory 或 Occupancy 指标→必要时 Source/PTX/SASS 的顺序深入，首轮不要求完整指标体系。

单个耗时差、源码分支、指令减少或 occupancy 不是硬件因果关系的独立证明；编译器可能消除分支或访存。性能结论注明 GPU 和输入；没有加速同样是结果。Runtime 与 Driver 只做概念和实际 trace 关联，不宣称严格 1:1。

进阶 Inventory 使用 `nsys stats --format csv` 或 `nsys export` 后的 SQLite 和 Python 结构化处理，不用脆弱的文本 grep 当正式解析器。保留 raw symbol 与 normalized symbol，不能丢失 `_v2/_ptsz/_ptds` 信息。按所用工具版本确认 schema，可用 correlation、时间窗、stream 建立关系，不能假定一个 API 只对应一个 GPU activity。

选修时采用以下最小字段合同，拿不到的字段明确为空并解释，不补造：

```text
api_trace: sequence_id, phase, timestamp, thread_id, api_layer,
           raw_name, normalized_name, category, duration, stream,
           sync_semantics, memcpy_kind, bytes, grid, block, dynamic_smem,
           first_call, step_id, correlation_id
gpu_trace: timestamp, activity_type, kernel_name, stream, device,
           duration, correlation_id, memcpy_kind, bytes
```

输出 API trace、GPU activity、API summary 和 kernel summary；类别包含 initialization/device/memory/execution/stream/event/synchronization/graph/library-JIT/profiler/other。进一步分析真实框架时，最终报告包含环境和启动参数、初始化/权重加载/内存规划/warmup/prefill/decode/sampling/cleanup、每 step 调用与同步、weight/workspace/KV/temp、stream/event 拓扑、Graph bucket/static buffer/pool、kernel 来源比例、API 关联、少量 NCU 发现、unknown 项与接口需求。continuous batching 若存在，再观察请求加入、batch 变化、KV block 分配与退出；未使用的功能标不适用。

## 8. 文档、产物与进度

所有记录文档统一在 `DOCS/`，不保留另一套 `docs/` 或章节内 result.md。现有分工：

| 文件 | 职责 |
| --- | --- |
| [PLAN.md](PLAN.md) | 唯一计划：目标、范围、路线、规则和计划变更 |
| [ENVIRONMENT.md](ENVIRONMENT.md) | 硬件/工具版本、预检命令和环境证据边界 |
| [NOTE.md](NOTE.md) | 学习背景、概念、用户疑问和复盘，不把预习记成已掌握 |
| [RECORD.md](RECORD.md) | 唯一任务进度与工作量记录：学习状态、计划/实际用时、辅助程度、验收证据，以及工程变更、验证和待办 |

任务进度与工作量只在 RECORD 维护，不另设进度文件；计划用时与实际用时分开，学习与工程准备/agent 执行耗时分开。实际时间无可靠依据时写“未记录”，不得从会话间隔推算。

后续按需形成以下结构，此树不表示已经创建：

```text
CH00/                                       # 已有目录，设备查询骨架已准备
CH01/                                       # vector add 已按用户要求补全并验证，解释待验收
CH02/ ... CH19/                              # 延续章节命名，按需创建，不提前生成
common/                                      # 逐步提取的检查、计时 helper
scripts/                                     # 按需新增 env/profile/export 脚本
DOCS/chapters/XX_topic.md                     # 一章一份简短任务和实验记录
reports/                                     # 原始 profiler 产物，默认不进版本管理
reference_traces/                            # 后续少量可公开 CSV/SQLite 样本
build/                                       # 本地构建产物
```

单章文档记录目标、所需旧章、1～2 个核心概念、从旧代码的改动、运行前预测、编译/运行命令、官方资料、验收和实际结果（环境、数值、报告路径、解释、异常或 NOT RUN）。相关真实推理用途仅一句连接，不强行扩展知识量。少量 reference trace 可覆盖 vector add、stream/event、Mini Decode、cuBLAS、MLP；环境和说明在 DOCS 记录，不默认提交巨大二进制 trace。

Ch00 代码已复用现有 `CH00/` 目录，任务说明在 `DOCS/chapters/00_environment.md`，两处属性读取已按用户要求由 Codex 完成，下一步验收用户解释；不一次创建 20 个空目录，不提前实现 Ch00～03 全部内容。完成一章才标 DONE，过程状态随实际更新；工程预检不计学生学习完成。

## 9. 官方资料与查阅方式

Reference 查参数、错误与同步语义，Programming Guide 查执行机制；按问题阅读，不顺序通读整本。记录章节标题、URL、文档版本，章节编号只作辅助。API 签名以本机安装头文件及对应官方版本核实；升级工具或更换 GPU 后重新核验环境及相关实验。

| 资料 | 首轮用途及后续覆盖 |
| --- | --- |
| [CUDA C++ Programming Guide 12.9](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html) | Ch01～03 编程模型；Ch06～12 硬件/存储/性能；Ch13～16 异步与 Graph；Ch17 编译；选修 JIT、VMM、多卡 |
| [CUDA Runtime API 12.9](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/index.html) | Ch00 设备/版本；Ch03 错误/内存；Ch04 Event；Ch11 occupancy；Ch13～16 同步/stream/event/graph；Ch19 内存；选修 pool、entry point |
| [CUDA Driver API 12.9](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-driver-api/index.html) | Ch18 initialization/primary context/module/function/launch/memory；选修 VMM、library、entry point、互操作 |
| [Turing Tuning Guide 13.0](https://docs.nvidia.com/cuda/archive/13.0.0/turing-tuning-guide/index.html) | Ch06～12 架构依据，不能从通用 Turing 功能推定 GTX 产品具备 Tensor Core |
| [Nsight Systems 文档](https://docs.nvidia.com/nsight-systems/) / [Nsight Compute 文档](https://docs.nvidia.com/nsight-compute/) | 选择本机版本，查采集范围、导出及指标语义 |
| [CUDA on WSL](https://docs.nvidia.com/cuda/wsl-user-guide/) | 工具支持与平台限制，以本机 smoke 另行验证 |
| [NVTX](https://nvidia.github.io/NVTX/) / [CUPTI](https://docs.nvidia.com/cupti/) | 仅后续范围标记、拦截/trace 选修按需查阅 |

## 10. 风险、协作与变更

一小时上限依赖事先验证的骨架、已有基础和实验稳定性。若未满足，应减小任务或拆节，不降低正确性要求。WSL 工具支持、计数器权限、GPU 频率和系统负载都可能改变；环境 smoke 不保证所有高级 API 或采集方式可用。临时报告可能被系统清理，重要后续结果应保存正式产物。

当前无需新增技术路线决策即可按本计划逐章推进；选修启动、范围增加或技术路线变化时再更新本文件。遵守 AGENTS.md 和 CLAUDE.md：Codex 执行，Claude 由用户手动转交做独立审阅；收到审阅意见先判断，不自动修改。例行课程不以每章 Claude 审阅为前置条件。若需转交，材料应列当前目标、计划阶段、文件、验证、风险及审阅重点。

| 日期 | 变更 | 原因与授权 |
| --- | --- | --- |
| 2026-09-20 | 将 99h+ 专项路线调整为 20 节首轮及按需选修，提前硬件实验和计时，修正依赖、重叠和 bank-conflict 示例 | 用户要求程序驱动、单章最多 1h、快速建立认识 |
| 2026-09-20 | 整合两份来源为本文件，背景/证据/进度分工落盘，核对后删除来源 | 用户明确要求唯一执行计划和充分迁移后删除；整合已授权 |
| 2026-09-20 | 更新 AGENTS/CLAUDE 教学协作规则，将进度表与工作量统一迁入 RECORD 并删除独立进度文件 | 用户明确要求；20 章状态保留，PLAN 和 NOTE 引用同步 |
| 2026-09-20 | 准备 Ch00 可运行骨架，源码复用已有 CH00/，任务说明仍放 DOCS/chapters/ | 用户要求生成 Ch00 所需代码；目录适配现状，教学范围不变 |
| 2026-09-20 | 准备 Ch01 单 block vector add 练习及文档，源码延续 CH01/ 命名 | 用户明确要求生成 Ch01 内容；允许准备下一章，保留 Ch00 解释待验收状态，未扩大教学范围 |
