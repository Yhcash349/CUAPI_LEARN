# 任务进度与工作记录

项目唯一执行依据为 [PLAN.md](PLAN.md)。本文件是任务进度与工作量的唯一记录入口，统一维护学习状态、工作产物、用时、辅助程度、验收证据和工程复盘；学习概念在 NOTE。

## 当前学习进度

环境预检和文档整合不计用户完成课程；实际用时、掌握度与辅助程度没有证据时不估填。“—”表示未记录，不代表用时为零。下表迁移时保留全部 20 章 TODO 状态。

章节状态：TODO / READING / CODING / RUNNING / DONE / BLOCKED。DONE 需程序验证与用户解释达到该章验收；过程状态可随实际更新。掌握度可记 0 未开始、1 看过、2 能解释、3 能独立写、4 能用 profiler 分析、5 能迁移，不能只凭 agent 执行结果提高等级。辅助程度记录骨架、提示、共同实现或完整答案。

| 章节 | 状态 | 计划用时 | 实际用时 | 掌握度 | 辅助程度 | 验收证据 |
| --- | --- | --- | --- | --- | --- | --- |
| 00 环境 | RUNNING | 45～60min | — | 未评估 | Codex 完整答案与讲解 | 完整程序验证通过；用户解释待验收 |
| 01 第一个 kernel | RUNNING | 45～60min | — | 未评估 | Codex 完整答案 | 正式程序 256 项校验通过，最大误差 0；用户解释待验收 |
| 02 线程索引 | RUNNING | 45～60min | — | 未评估 | Codex 完整答案 | 正式程序 1000 项通过、最大误差 0、memcheck 零错误；用户解释待验收 |
| 03 错误检查 | RUNNING | 45～60min | — | 未评估 | Codex 骨架、讲解与修改示例 | 当前源码已完善宏和两处检查点；用户贴出 launch 与 memcheck 越界输出，修复复测及个人解释待验收 |
| 04 正确计时 | RUNNING | 45～60min | — | 未评估 | 保留已有预热设置，Codex 补全 Event 与验证 | 正式程序 1000 项通过、最大误差 0、计时 PASS；个人解释待验收 |
| 05 NSYS | RUNNING | 45～60min | — | 未评估 | Codex 源码、讲义、排障与读图讲解 | 用户 _02 采集与 GUI 读图已有报告/截图；三类活动已验证，个人解释待验收 |
| 06 warp 执行 | RUNNING | 45～60min | — | 未评估 | Codex 骨架、讲解与两处练习补全 | 正式校验、memcheck、计时及 NCU 动态分歧检查通过；用户已有 Source/SASS 关联截图，个人解释验收待补齐 |
| 07 合并访存与 NCU | RUNNING | 45～60min | — | 未评估 | Codex 骨架、讲解、预检与按要求补全索引 | 正式校验、memcheck 与 Event 通过，历史临时版 NCU 对照通过；用户已复述地址排列对照，个人运行/采集及计数与计时边界解释待验收 |
| 08 shared 与同步 | TODO | 45～60min | — | 未评估 | 未开始 | — |
| 09 bank conflict | TODO | 45～60min | — | 未评估 | 未开始 | — |
| 10 归约 | TODO | 45～60min | — | 未评估 | 未开始 | — |
| 11 SM 与 occupancy | TODO | 45～60min | — | 未评估 | 未开始 | — |
| 12 数据复用 | TODO | 45～60min | — | 未评估 | 未开始 | — |
| 13 Host 异步 | TODO | 45～60min | — | 未评估 | 未开始 | — |
| 14 Stream | TODO | 45～60min | — | 未评估 | 未开始 | — |
| 15 Event 与重叠 | TODO | 45～60min | — | 未评估 | 未开始 | — |
| 16 Graph | TODO | 45～60min | — | 未评估 | 未开始 | — |
| 17 编译产物 | TODO | 45～60min | — | 未评估 | 未开始 | — |
| 18 Driver | TODO | 45～60min | — | 未评估 | 未开始 | — |
| 19 内存复用 | TODO | 45～60min | — | 未评估 | 未开始 | — |

后续选修仅在用户启动且 PLAN 写明范围后添加，未启用的选修不影响首轮完成。

## 工作量记录口径

每次任务在日期条目中记录任务范围、具体产物、用户完成部分、Codex 辅助、验证与遗留项；下次工作先核对本页。计划用时是预算，实际用时注明用户报告或可靠计时来源。学习用时与工程准备/agent 执行耗时分开，无依据写“未记录”，不从会话间隔推算。当前学习进度在上表更新，历史工作记在日期条目，不新增另一套进度清单。

## 2026-09-20：环境评估与计划收敛

### 背景与决定

原始 `CUAPI_LEARN_PLAN_V2.md` 面向 Runtime/Driver、profiler 与推理框架接口分析，必修至少 99 小时，含可选多卡至少 105 小时。用户提出程序驱动、知识可观察、每章最多 1 小时的新约束；本机评估提出 20 节轻量首轮，并将进阶工作内容延后。

用户随后明确要求将评估与 V2 核心思想整合进 PLAN，必要上下文分配到 DOCS，其后删除两份来源。此次整合依此执行，不再将路线标为待确认；没有获得或声称获得 Claude 审阅。

### 文件分工与关键改动

PLAN 从占位模板变为正式计划，包含目标、20 节路线、阶段验收、按需选修、工具与证据规范、目录与文档合同、资料入口和变更记录。ENVIRONMENT 保存本次硬件/工具快照与命令；NOTE 保存学习起点和笔记规则；当时建立的独立进度表初始化全部课程为 TODO（现已迁入本页），没有把环境 smoke 标为学习完成。

下表是删除来源前的内容去向核对。旧章号仅作历史追踪，不再作为执行编号。

| 来源主题 | 整合去向与处理 |
| --- | --- |
| V2 目标、四层能力模型、程序→观察→文档→验证 | PLAN §1～2、§6；首轮目标与长期接口分析分开 |
| V2 Ch00～05 环境、vector add、线程、错误、初始化、NSYS | PLAN Ch00～05；首次加载/JIT 深化移至选修；ENVIRONMENT 保存实测 |
| V2 Ch06～09 异步、Stream、Event、重叠 | PLAN Ch04、13～15；先独立数据流水，再连接推理 |
| V2 Ch10 Mini Decode | PLAN §6 独立选修，保留 metadata/kernel/sampling/同步与每 step 统计 |
| V2 Ch11～15 存储、warp、NCU、bank、occupancy | PLAN Ch06～12；分支/归约拆开，bank 采用 stride 32/33，资源限制单变量 |
| V2 Ch16 Roofline/低精度/GEMV-GEMM | PLAN Ch12 数据复用与 §6 性能选修，Tensor Core 等待硬件 |
| V2 Ch17～19 编译、Driver、映射 | PLAN Ch17～18 和 §6～7；保留 primary context、非 1:1 与符号后缀边界 |
| V2 Ch20～21 Inventory、库/JIT/框架 | PLAN §6～7，保留结构化导出、字段合同、kernel 分类与首次/稳态 |
| V2 Ch22～23 Graph | PLAN Ch16 及 Decode Graph 选修，保留静态地址、分桶、metadata、pool 和 capture 合法性 |
| V2 Ch24 Allocator/VMM | PLAN Ch19 与分拆选修，保留 pool/arena/KV/VMM 和稳态分配观察 |
| V2 Ch25 Hook/CUPTI | PLAN §6，保留普通动态库→Driver entry point→callback 递进与链接检查 |
| V2 Ch26～27 真实框架、多卡 | PLAN §6～7，保留综合报告内容与硬件前提，不作为首轮门槛 |
| V2 实验规范、工具流程、诚信要求、schema | PLAN §7，调整 Event/NCU 引入时机并保留实际证据边界 |
| V2 文档模板、进度、官方覆盖、reference traces | PLAN §8～9，RECORD、NOTE；统一 DOCS，按需创建记录与小型 trace |
| V2 依赖图、轮次、初始化、最终验收 | PLAN §5～6、§8；改成线性首轮、按需选修，不保留矛盾依赖或批量初始化 |
| 评估的硬件/工具/限制/命令 | ENVIRONMENT；PLAN §3 引用 |
| 评估的 20 章、一小时约定、实验陷阱与取舍 | PLAN §4～6；NOTE 保存学习目的，RECORD 保存未开始状态 |

已按用户授权删除 `DOCS/PLAN_V2_ASSESSMENT.md` 和 `CUAPI_LEARN_PLAN_V2.md`。

来源中的“保留原 V2”“路线待确认”、CUDA 13.x 统一基线、每章 2～8h、一次创建全部目录及实现前四章、独立 docs/result 文档体系均由新要求替代，不作为遗失内容重新引入。

### 验证与证据

前次评估已实际编译执行最小 kernel，4096 个整数校验通过；NCU basic 与 NSYS trace/stats 可用，详见 ENVIRONMENT。它们是环境检查，不是正式课程 A/B 或学生独立完成证据。

本次只做文档整合，不重跑 GPU benchmark。删除来源前核对上述迁移表及 20 节编号；删除后检查本地 Markdown 链接、来源残留引用与占位计划。历史文件名仅保留在本条记录作追踪，不作为链接或执行依赖。

### 当前状态与下一步

尚未初始化课程源码、构建系统或 Git；下一步按 PLAN 从 Ch00 开始。重要风险是教学一小时预算依赖可运行骨架，以及临时预检报告可能被系统清理；高级 API 和所有课程性能实验仍需实际验证。Claude 尚未审阅，当前无需以额外审阅阻塞执行。

## 2026-09-20：协作规则与进度记录统一

用户要求按任务背景更新 AGENTS.md、CLAUDE.md，并将全部任务进度和工作量集中到本文件，删除独立的 PROGRESS.md。

已完成的工作量：更新两份协作规则，明确程序驱动、单章最多 1h、用户关键代码练习、本机边界、实测证据和人工审阅方式；迁移 20 行章节进度及状态定义；同步 PLAN、NOTE 的记录入口，删除旧进度文件。用户本次完成的是提出规则调整需求，未发生章节练习；文档修改与检查由 Codex 完成。实际学习用时、工程准备及 agent 执行耗时均未记录，不估填。

验证：核对迁移前后 20 行章节数据一致，检查 Markdown 本地链接与进度入口引用。本次只改文档，没有重跑 GPU 实验，也没有新增课程完成记录。Claude 未参与本次审阅；无需因本次规则同步额外阻塞后续教学。下一步仍从 PLAN 的 Ch00 开始。

## 2026-09-20：Ch00 简介与代码准备

用户先询问 Ch00 简介，随后要求生成所需代码。已提供章节介绍；用户尚未提交代码修改、运行结果或个人解释，Ch00 标为 READING，不记 DONE。学习用时和工程准备耗时均未记录。

Codex 新建 `CH00/device_probe.cu`，提供版本、设备属性、错误处理和输出骨架，保留 SM 数量和 warp 大小两处 TODO；新增 `DOCS/chapters/00_environment.md`，说明预测、命令、练习、验收和官方资料；新增 `.gitignore` 忽略本地 build/reports。复用现场已有空 CH00 目录，PLAN 同步目录及当前状态，未扩大课程范围。

验证：使用章节文档中的 nvcc 命令编译，`-Wall,-Wextra` 无警告；正式骨架运行退出 0，显示设备查询成功和练习 TODO。Codex 在临时副本补全两处属性读取后再次编译运行，得到 14 个 SM、warp 32，临时源码和二进制已自动删除，正式源码仍保留练习。设置 `CUDA_VISIBLE_DEVICES` 为空检查无设备路径，得到 `cudaGetDeviceCount failed: no CUDA-capable device is detected`，退出 1，符合预期。

本次实测 NVCC 12.9.86、GPU GTX 1650、CC 7.5、4.00 GiB、Driver 支持 CUDA 13.3；更多输出见章节预检结果。无计算 kernel、计时或 profiler 采集。原有未提交文档变更完整保留；现场已存在 Git，与早期“尚未初始化”历史快照不同，本次未初始化、提交或推送 Git。

下一步：用户先运行骨架，再补两处属性读取并解释版本与属性含义。辅助程度为 Codex 骨架及预检，不能记成用户独立实现。例行 Ch00 准备无需额外 Claude 审阅。

## 2026-09-20：Ch00 代码讲解与完整作业

用户询问 device_probe.cu 的作用和实现，Codex 已解释版本查询、输出参数、设备属性、错误处理与练习标记；随后用户明确要求“直接完成今日作业”。据此补全 `prop.multiProcessorCount` 与 `prop.warpSize`，删除占位注释，并让无效属性返回失败状态。正式代码由 Codex 完整实现，不记为用户独立完成。

使用章节中的 nvcc 命令编译，无警告；运行退出 0，GTX 1650、CC 7.5、4.00 GiB、14 SM、warp 32、最大 block 线程数 1024、默认每 block shared memory 48 KiB，headers/Runtime 12.9、Driver 支持 CUDA 13.3。完成代码与运行验证，状态 RUNNING；缺少用户自己的解释，未标 DONE。学习和工程实际用时均未记录。未增加课程范围，不要求额外 Claude 审阅，未提交或推送 Git。

随后讲解保存、nvcc 编译、执行二进制的操作及 `&&` 的作用。用户要求本章总结，已在 NOTE 汇总程序流程、版本区别、硬件属性及编译运行命令。本次仅更新文档并检查 diff 格式，未重复运行程序；状态保持 RUNNING，辅助程度为完整答案，尚无用户独立运行反馈或个人解释。后续计划为 Ch01 第一个计算 kernel，未提前生成代码。

## 2026-09-20：Ch01 内容与骨架准备

用户明确要求生成 Ch01 内容。按 PLAN 阶段 A 准备 `CH01/vector_add.cu` 与 [章节说明](chapters/01_first_kernel.md)，延续 CH00 的目录命名与 `check_cuda` 用法；PLAN 同步实际目录及本次推进依据。Ch00 仍为 RUNNING、解释待验收，本次按用户最新指令提供 Ch01，不虚报前章完成，也不批量生成后续章节。

Codex 提供 CPU 输入、参考答案、GPU 分配与双向拷贝、启动、同步、逐元素校验及释放骨架；用户需补一处 kernel 计算。固定 `[256]` float32、一个 block、256 个线程，只对照占位输出与正确计算；索引泛化、错误分类、计时及 profiler 分别留到后续章节。用户本次完成部分为提出生成需求，尚无代码修改、运行或解释证据；Ch01 为 READING，掌握度未评估。学习及工程准备/agent 实际耗时均未记录。

验证：现场复核 NVCC 12.9.86、GTX 1650 / CC 7.5。正式骨架与临时补全版均编译无警告；骨架校验失败符合预期（256 项不符，最大绝对误差 129.25，退出 1），临时补全版全量校验通过（0 项不符，最大绝对误差 0，退出 0）。命令与原始输出见 `reports/CH01/preflight.txt`，文档记录关键结果；临时补全源码及二进制已清理。正式源码保留 TODO，未运行计时或 profiler，不构成用户完成或性能证据。

下一步：用户先预测、运行骨架，再补 TODO、重编译并解释数据流。沿用既定教学范围；提前准备下一章的依据为本次明确请求，Ch00 遗留验收继续保留。本次例行课程准备无需额外 Claude 审阅，未提交或推送 Git。

## 2026-09-20：Ch01 完整答案与编译运行

用户明确要求“解题并编译”。Codex 补全 `CH01/vector_add.cu` 的逐元素相加，删除占位语句及过时 TODO 提示；章节文档同步当前版本和验证结果。使用章节 nvcc 命令编译，无警告；运行正式二进制 `build/CH01/vector_add`，固定 `[256]` float32、grid=1、block=256，全部元素通过，最大绝对误差 0，退出 0。没有计时或 profiler，不作性能结论。

代码与验证由 Codex 完成，辅助程度改为完整答案，不记用户独立实现。Ch01 状态 RUNNING，待用户解释 kernel 和 CPU/GPU 数据流后再验收 DONE；学习及工程实际用时均未记录。符合 PLAN 允许按明确要求提供完整实现的范围，无课程扩展，无需额外 Claude 审阅。保留已有改动，未提交或推送 Git。

用户随后要求总结本章。已在 NOTE 汇总 CPU/GPU 数据流、kernel 与线程分工、主要 API、编译命令、正确性结果与两道自测题；引用本次已有运行证据，没有重新编译或运行。仅更新文档并检查 diff 格式，状态保持 RUNNING、辅助程度为完整答案，个人解释仍待验收；无额外 Claude 审阅需要。

## 2026-09-20：Ch03 错误检查内容与骨架准备

用户明确要求生成 Ch03 内容。新增 `CH03/error_check.cu` 和 [章节说明](chapters/03_error_check.md)，复用 Ch01 的单 block、256 项 float32 相加，提供 `ok/launch/oob` 三种故障模式。保留检查宏字符串化、两处检查点迁移及越界修复练习；host、输入、reference、校验、错误打印与故障注入由 Codex 提供。用户本次仅提出生成要求，尚无练习或解释证据；状态 READING，学习及工程准备/agent 实际用时均未记录。

当前 Ch02 尚未生成，按用户最新指令直接准备 Ch03，以 Ch01 单 block 示例避免引入多 block 索引；PLAN 同步这一顺序调整，Ch00/01 解释待验收、Ch02 TODO 均保留。未生成其他章节，没有扩大教学主题。

实测 NVCC 12.9.86、GTX 1650 / SM75、Compute Sanitizer 2025.2.1.0。正式与临时练习完成版均无编译警告；正常模式 256 项校验通过、最大绝对误差 0、memcheck 零错误；非法启动 1025 线程在 launch 检查报告 `cudaErrorInvalidConfiguration`，退出 1。memcheck 越界案例定位 `c[n]` 的 4 字节写入，随后同步报 `cudaErrorUnknown`，汇总 2 errors，外层退出 99。临时修复版数值通过且 memcheck 零错误。详细命令和输出见 `reports/CH03/preflight.txt`；临时源码及二进制已自动清理，正式代码保留 TODO。未运行普通 oob、计时、NSYS 或 NCU，不作性能结论。

下一步：用户先预测，再完成宏与检查点练习，采集并修复越界，提交个人解释。例行课程准备无需额外 Claude 审阅，未启动 Claude，未提交或推送 Git。

## 2026-09-21：Ch02 线程索引内容与骨架准备

用户明确要求生成 Ch02 内容。按 PLAN 阶段 A 新增 `CH02/thread_index.cu` 与 [章节说明](chapters/02_thread_index.md)，复用 Ch01 的 host、输入、reference、校验与释放，固定 `[1000]` float32、8 个 block、每 block 128 线程。用户需补全全局索引与边界判断两处 TODO；骨架安全跳过数组访问，输出保持零，不注入越界或竞争写入。文档提供线程映射、预测、编译命令和验收问题，PLAN 同步实际目录，无范围扩展。

现场复核 NVCC 12.9.86、GTX 1650 / CC 7.5。正式骨架与临时补全版均编译无警告；骨架 1000 项不符、最大绝对误差 501.75、退出 1，符合占位预期；临时补全版 1000 项校验通过、最大绝对误差 0、退出 0，memcheck 零错误。命令和输出见 `reports/CH02/preflight.txt`；临时补全源码及二进制已自动清理，正式源码保留 TODO。未计时或采集 NSYS/NCU，不作性能结论。

状态 READING，辅助程度为 Codex 骨架、提示与预检。用户本次仅提出生成需求，尚无代码修改、独立运行或个人解释证据；学习实际用时和工程准备/agent 执行实际耗时均未记录。Ch00/01 的解释待验收状态与已有 Ch03 改动保留，不把预检算作用户完成。下一步由用户预测、运行骨架、补两处并重编译，再解释跨 block 索引和尾部 24 个线程为何跳过。例行课程准备无需额外 Claude 审阅，未启动 Claude，未提交或推送 Git。

## 2026-09-21：Ch02 完整答案与验证

用户明确要求“完成今日作业”。Codex 补全 `CH02/thread_index.cu` 的全局索引及边界保护，删除 TODO 并添加中文实现说明；章节文档与 PLAN 同步当前完成版本。固定 N=1000、block=128、grid=8，数据和校验未改变。正式源码按章节命令编译无警告，1000 项全量校验通过、最大绝对误差 0、退出 0；正式二进制 memcheck 报告零错误、退出 0，原始证据见 `reports/CH02/completed.txt`。未计时或采集 NSYS/NCU，无性能结论。

代码与验证由 Codex 完成，辅助程度为完整答案；用户尚无独立实现或个人解释证据，状态 RUNNING，未标 DONE。学习及工程实际用时均未记录。下一步验收用户对跨 block 索引与尾部保护的解释。符合 PLAN 明确请求可提供完整实现的范围，无计划偏离；无需额外 Claude 审阅，保留其他已有改动，未提交或推送 Git。

用户随后要求总结本章。已在 NOTE 汇总线程分组、全局索引、组数向上取整、尾部保护、编译命令及自测问题，引用本次正式程序已有验证结果。本次仅更新 NOTE 与本记录并检查 diff 格式，未重新编译或运行；状态保持 RUNNING、辅助程度为完整答案，个人解释仍待验收，实际用时未记录。无计划偏离或额外 Claude 审阅需要。


## 2026-09-22：Ch02 追问与总结补充

按用户再次总结本章的要求，更新 NOTE 中 Ch02 条目，补入用户关于 block 是否同时启动、为何需要全局索引及 1024 个线程中仅 1000 个执行加法的原始问题与解释。区分整次 grid 提交、实际 block 调度和源码层面的条件执行；没有本章调度追踪或机器指令证据，不声称观察到同时执行。

仅修改 NOTE 和本记录，检查 diff 格式；引用 2026-09-21 已有正确性与 memcheck 结果，未重新编译或运行。状态保持 RUNNING、Codex 完整答案，用户主动追问不替代个人解释验收；学习与工程实际用时未记录。范围符合 PLAN，无额外 Claude 审阅需要，未提交或推送 Git。

## 2026-09-22：Ch03 代码阅读、故障实验与今日总结

用户逐段询问头文件、检查函数、宏参数及字符串化、命令行模式、设备上限、结果校验与释放，并追问错误名称来源、Sanitizer 命令和报告、与 nsys 的区别及其他检查工具。Codex 提供解释和修改示例；本次总结将概念、真实提问、报告解读与自测整理到 NOTE，不扩展课程范围。

现场只读核对 `CH03/error_check.cu`：宏已使用 `#call`，启动与同步检查已改为 `CUDA_CHECK(...)`；这两项练习代码已落地，但旧 TODO 注释尚未同步。故意越界的 `c[n] = 123.0f` 仍存在。用户已有源码改动完整保留，本次总结不修改或代做代码。

用户在本会话贴出两组运行证据：`./build/CH03/error_check launch` 使用 1025 线程超过上限 1024，在第 77 行检查处报 `cudaErrorInvalidConfiguration`；`compute-sanitizer --tool memcheck --padding 32 --error-exitcode 99 ./build/CH03/error_check oob` 定位第 33 行 4 字节 global 越界写入、block 0 线程 0，随后第 80 行同步检查报 `cudaErrorUnknown (999)`，汇总 2 errors。证据来源为用户粘贴的终端输出，未另存为原始报告，也没有展示 shell 退出码，不据参数猜填实际退出码。历史 `reports/CH03/preflight.txt` 仍仅是 Codex 预检，不能替代本日用户运行证据。

Ch03 更新为 RUNNING；辅助程度为骨架、讲解与修改示例，不记完全独立实现。尚缺本日用户正常模式通过、越界修复后数值及 memcheck 零错误的反馈与个人解释，不标 DONE。下一步删除故意越界写入、重新编译并复测，按实际完成状态整理 TODO 注释。学习与工程实际用时均未记录。

本次仅更新 NOTE、RECORD，检查 diff 格式；没有重新编译、运行 GPU 程序或 profiler。其余 Sanitizer 工具和 nsys 本日仅概念介绍，不作新验证声明。保留已有 Ch02 等记录，无额外 Claude 审阅需要，未提交或推送 Git。

## 2026-09-22：Ch04 正确计时内容与骨架准备

用户明确要求“生成CH04内容”。按 PLAN 阶段 A 新增 `CH04/timing.cu` 与 [章节说明](chapters/04_timing.md)，复用 Ch02 的 `[1000]` float32、grid=8、block=128 和 Ch03 错误检查。Codex 提供 host、CPU 对照、全量校验、预热循环、21 样本中位数统计及资源释放；用户保留预热次数与四次 Event 调用练习。固定输入与计算，仅比较 CPU 计算、GPU 含传输总时间和同 stream Event 批次区间；每批 100 次 kernel，归一化后取中位数，不将其称为纯 kernel 指令执行时间。

实测 GTX 1650 / CC 7.5、NVCC 12.9.86。初版常量零次预热产生不可达循环警告，改为普通可编辑变量后最终正式骨架与临时补全版编译均无警告。两版全部 1000 项通过、最大误差 0、退出 0；骨架明确 `Timing NOT RUN`。临时补全版 warmup=3、samples=21、batch=100，最终一次 CPU 中位数 0.561000 μs、GPU 含传输 host 中位数 98.217000 μs、Event 批次平均每次启动中位数 7.857920 μs。输入准备、分配、校验、统计与释放均不在计时区间；CPU 对照每次计时后读取校验，Event 区间不含拷贝但可能含提交间隙。

命令、原始输出和退出码保存在 `reports/CH04/preflight.txt`，临时补全源码及二进制已清理，正式源码保留 TODO。该结果只是本机教学预检，不是正式性能优化 A/B；没有运行本章 Sanitizer、NSYS 或 NCU。检查文档链接和 diff 格式。NOTE 不追加尚未学习内容作为用户学习总结。

Ch04 状态 READING，辅助程度为骨架、提示与预检；用户本次仅提出生成需求，尚无代码修改、运行或个人解释验收。学习实际用时与工程准备/agent 实际耗时均未记录。按用户指令准备下一章，Ch03 的越界修复复测和个人解释仍待验收；PLAN 同步目录与本次准备，不扩展课程主题。下一步先预测，运行骨架，补两处 TODO、重新编译运行，再解释三种时间的边界。例行准备无需额外 Claude 审阅，未启动 Claude，未提交或推送 Git。

## 2026-09-28：Ch04 练习补全与正式验证

用户明确要求“完成CH04练习”。读取现场源码时 `warmup` 已为 10，本次完整保留，不将该设置归为 Codex 本次修改。Codex 在 `CH04/timing.cu` 补全 stream 0 上的 start/stop 记录、等待 stop 和读取毫秒差四次调用，清理过时 TODO，移除 Event 等待后冗余的全设备同步；预热不足和无效 Event 结果改为非零退出。数据、kernel、21 样本与每批 100 次启动保持原设计。同步章节说明及 PLAN 的目录状态。

复核 GTX 1650 / CC 7.5、NVCC 12.9.86；按讲义命令编译正式源码无警告。N=1000、float32、grid=8、block=128，全部元素通过、最大绝对误差 0、warmup=10、samples=21、batch=100，计时 PASS、退出 0。本次中位数：CPU 加法 0.781000 μs，GPU 含传输 host 时间 161.777000 μs，Event 批次平均每次启动时间 9.461120 μs。证据见 `reports/CH04/completed-2026-09-28.txt`。这不是与历史预检的配对 A/B，不将跨日差异当作优化结论；没有运行 Sanitizer、NSYS 或 NCU。

状态改为 RUNNING，辅助程度明确为保留已有预热设置、Codex 补全与验证；用户此前提问和代码讲解不替代个人解释验收，未记 DONE。学习与工程实际用时均未记录。剩余验收为解释 CPU 计时等待的原因及 Event 与含传输总时间的范围。检查 diff 格式和章节本地链接；遵循 PLAN 中明确请求可提供完整实现的规则，无教学范围偏离，无需额外 Claude 审阅，未提交或推送 Git。

## 2026-09-28：Ch05 NSYS 内容与采集预检

用户明确要求“生成CH05内容”。新增 [Ch05 讲义](chapters/05_nsys.md)，按 PLAN 阶段 A 直接采集已有 `CH02/thread_index.cu`，以单次 vector add 对应 CPU API、GPU memcpy 与 kernel 三类轨迹。复用完整 host、输入和校验，不复制源码或新增 kernel；本章用户练习为采集命令、三类轨迹定位与源码对应解释。构建独立输出到 `build/CH05/vector_add`。同步 PLAN 的目录说明与本次准备依据，前章未完成验收保留，无课程范围偏离。

Codex 复核 GTX 1650 / CC 7.5、驱动 610.88、NVCC 12.9.86、NSYS 2026.4.1；按讲义编译无警告，普通运行与采集运行均退出 0，N=1000、float32、grid=8、block=128，全量校验通过、最大绝对误差 0。`nsys profile --trace=cuda --sample=none --cpuctxsw=none` 成功生成报告；API/kernel/memory 汇总与 API/GPU 逐条 trace 命令均退出 0。实测 1 次 vector_add、2 次 H2D（共 8000 字节）、1 次 D2H（4000 字节），另有一次清零（4000 字节），顺序与源码一致。kernel 与 launch 的关联编号均为 124。单次 kernel 2176 ns 仅作读表证据，不作正常计时、稳态性能或优化 A/B 结论。

命令、原始输出和退出码见 `reports/CH05/preflight.txt`；正式预检报告为 `reports/CH05/preflight-2026-09-28.nsys-rep`，同名 `.sqlite` 为工具派生数据。均按现有规则留在本地，保留作复盘证据。GUI 打开与人工点选 NOT RUN，讲义提供已验证的 CLI 替代路线；未运行 Sanitizer、NCU 或性能 A/B。辅助查询曾把多个报告名传给 `--help-reports`，收到 `UNKNOWN REPORT`；改用单报告帮助后取得说明，不影响已通过的多报告 `--report` 采集分析流程。

Ch05 为 READING，辅助程度为 Codex 讲义、命令与预检；用户本次仅提出生成要求，个人采集和解释尚待验收。计划学习 45～60 分钟，实际学习与工程准备/agent 执行耗时均未记录。NOTE 不提前添加未学习内容。检查 diff 格式、章节链接与证据路径；下一步用户按讲义先预测，再采集自己的报告并解释三类轨迹。例行课程准备无需额外 Claude 审阅，未启动 Claude，未提交或推送 Git。

## 2026-09-28：补齐 Ch05 独立目录

用户明确要求即使复用前章代码也单独创建章节目录，方便按章查看。新增 `CH05/vector_add.cu`，从 Ch02 复制完整程序，补充本章用途注释；讲义链接与编译命令改用 CH05。PLAN 写明后续每章均保留独立源码目录，并替代先前直接引用 CH02 的安排。原 Ch02 文件保留。

独立源码编译无警告；普通运行与 NSYS 采集均退出 0，1000 项 float32 全量通过、最大误差 0。汇总验证 1 次 kernel、2 次 H2D、1 次 D2H、1 次 memset。证据为 `reports/CH05/standalone-2026-09-28.txt` 与同前缀 `.nsys-rep`、`.sqlite`；旧预检报告保留。检查文档链接与 diff 格式。Ch05 保持 READING，复制、注释与验证均由 Codex 完成，不新增用户掌握证据；实际学习与工程耗时未记录。GUI 未验证，无需额外 Claude 审阅，未提交或推送。

## 2026-10-08：Ch05 GUI 与采集版本排查

用户反馈 nsys-ui 启动时 OpenGL/ZINK/EGL 错误。核对本机脚本，GUI 实际为 2025.1.3，当前 Codex PATH 中 CLI 为 2026.4.1；用户报告的诊断记录加载 2025.1.3 CUPTI 库，并提示驱动 13.3 不受该版本支持。用户报告包含 CPU API，缺少 GPU kernel/memcpy 数据，不能据报告存在就验收完整采集。

临时软件渲染启动探测使用 LIBGL_ALWAYS_SOFTWARE=true GALLIUM_DRIVER=llvmpipe，进程退出 0，原 ZINK/EGL 警告未重现；窗口与报告显示未人工验证。Codex 用已安装 2026.4.1 CLI 重采集到 reports/CH05/repair-20261008.nsys-rep，应用 N=1000、float32、grid=8、block=128、全量 PASS、最大误差 0，采集退出 0；stats 验证 1 kernel、2 H2D、1 D2H、1 memset。诊断依据与命令见 reports/CH05/repair-20261008-diagnostics.txt，派生 SQLite 留作复盘，用户原报告保留。讲义补入实际 GUI/CLI 版本差异、软件渲染与显式 CLI 路径。

Ch05 改为 RUNNING，用户已尝试采集和打开 GUI，完整 GPU 数据采集及个人解释待验收；Codex 重采集不替代用户完成。学习和工程实际用时未记录；未安装或升级工具、未运行性能 A/B。

## 2026-10-08：用户新版报告验证与 GUI 读图指导

用户提供 Windows Nsight Systems 2026.4.1 截图，当前活动标签仍为 user_20261008_01，左侧已选中 _02；说明 GUI 已成功打开旧报告，不能据此认定新报告已显示。现场使用 2026.4.1 stats 检查用户生成的 reports/CH05/user_20261008_02.nsys-rep，成功导出同名 SQLite，验证 CPU API 汇总及 GPU 数据：1 次 vector_add、2 次 H2D（共 8000 字节）、1 次 D2H（4000 字节）、1 次 memset。CPU 汇总中 cudaMalloc 3 次、cudaMemcpy 3 次、cudaLaunchKernel 1 次、cudaDeviceSynchronize 1 次、cudaFree 3 次。kernel 单次采集 duration=2176 ns，仅用于说明秒级视图下短事件难以辨认。

本次为用户新报告的实际验证，取代之前用户报告缺 GPU 数据的当前状态；原报告仍保留。已针对活动标签、Events View 列表、横向时间缩放与纵向轨道大小的区别准备操作指导，个人轨迹定位和解释尚待反馈。Ch05 保持 RUNNING，不标 DONE；未改源码或重新采集，实际学习及工程用时未记录。

用户随后提供 `_02` 的 GUI 截图，已展开 GPU 与 CPU 轨道并显示 API 事件列表，但未找到 `cudaLaunchKernel` 名称。核对同报告 API/GPU trace：GUI API 列表第 8 行 `vector_add(...)` 的起点与 450.575 μs 时长精确对应 CLI 的 cudaLaunchKernel，关联编号 124；GPU vector_add 同编号、2.176 μs。讲义补入 GUI 显示名称区别，解释轨道树与父子百分比，未将用户提问视为个人解释验收。

## 2026-10-08：Ch05 本章总结

按用户“总结本章内容”的要求，在 NOTE 新增本日 Ch05 条目，整理本章数据流、编译/采集命令、三类轨迹、Events View 与缩放、源码与关联编号对应、API/GPU 耗时边界及 CPU/GPU 时间重叠。保留用户真实追问：找不到 cudaLaunchKernel、每行含义、拷贝方向、A/B 同大小却时长不同、GPU 是否等待 CPU 进程结束、绿色条宽度含义。排障只保留本章必要的工具版本与数据缺失边界，不扩展首轮范围。

用户已有实际新版报告与 GUI 操作截图；源码、采集命令、工具排障、报告核对及解释由 Codex 辅助。引用本日已验证的 `_02` 报告及其 SQLite，A/B/C 均 4000 字节，CPU API 分别为 454.982/57.448/73.237 μs，GPU 拷贝分别为 2.208/1.344/2.656 μs。用户观察与追问继续如实记录，不将疑问本身视为独立解释通过；Ch05 保持 RUNNING，待个人复述后再验收 DONE。学习与工程实际用时均未记录。

本次仅更新 NOTE 与 RECORD，检查新增笔记的本地链接和 diff 格式；没有重新编译、采集、计时或执行 GPU 程序，未新增性能或内存安全结论。保留已有源码、讲义与报告，无计划偏离，无需额外 Claude 审阅，未提交或推送。

## 2026-10-08：Ch06 warp 执行内容与骨架预检

用户明确要求“生成CH06内容”。按 PLAN 阶段 B 新增 [CH06/warp_branch.cu](../CH06/warp_branch.cu) 和 [章节说明](chapters/06_warp_execution.md)，复用 Ch02 索引、Ch03 检查和 Ch04 Event 计时方式。正式源码保留两处练习：计算 lane/block 内 warp 编号，以及填写 warp 内/warp 间分路条件。Codex 提供 host、输入、独立 CPU reference、两条整数计算路径、校验和成对计时框架；只改变线程走 A/B 的分组方式，不引入新依赖、shared 协作或 NCU 教学。PLAN 同步目录和准备依据，NOTE 不提前记录未实际学习的内容。

现场复核 GTX 1650 / CC 7.5 / warpSize=32 / 4096 MiB、驱动 610.88、NVCC 12.9.86、Compute Sanitizer 2025.2.1.0。正式练习版和临时补全版均编译无警告。正式 probe 的 64 项编号不符，check/bench 每种分支模式 32768 项不符、计时 NOT RUN、退出 1，均为占位预期。临时补全 probe 全部 64 项正确，两个分支模式各 65536 项全部正确、整数误差为 0，三个模式均退出 0；临时 probe/check 的 memcheck 均零错误、退出 0。

普通计时与 Sanitizer 分开运行：N=65536、uint32、grid=256、block=256、iterations=256；每模式预热 10 次、21 个样本、每批 5 次启动，轮换两模式先后顺序。Event 批次平均每次启动中位数为 within_warp 109.081602 μs、between_warps 65.171200 μs。本机此次 warp 内分路较慢；测量不含传输和校验，仍可能包含 host 提交间隙及两种条件计算开销，不作为纯分歧成本或固定减速比例证明。

教学方对临时补全版执行 cuobjdump --dump-sass：branch_work 在 0x340 保留条件 BRA，0x360/0x3a0 分别 CALL 两条不同计算体，计算体保留乘加、移位和循环，输出经 STG 写出。结合全量正确性，确认本次对照未被消除或合并成同一计算路径；静态检查不代替动态计数或逐周期调度证据，相关指令不计入学生必学。证据为 `reports/CH06/preflight-2026-10-08.txt` 与 `reports/CH06/completed-sm75.sass.txt`，正式可执行文件为 `build/CH06/warp_branch`；临时补全源码及二进制已清理。NSYS/NCU 本章 NOT RUN。

Ch06 为 READING，用户本次仅提出生成需求，实际代码练习、运行和个人解释待验收，不记 DONE；前章个人解释和 Ch03 修复复测等遗留项保留。计划学习 45～60 分钟，实际学习用时与工程准备/agent 执行耗时均未记录。校对章节链接、diff 格式和预检证据；无计划范围偏离，无需额外 Claude 审阅，未启动 Claude、未提交或推送 Git。下一步用户按讲义先预测、填 TODO 1 后编译 probe，再填 TODO 2、重新编译 check/bench，最后解释结果与计时边界。

## 2026-10-14：Ch06 编号练习 TODO 1 补全

用户指定 `CH06/warp_branch.cu` 的 `probe_warps()` 并要求“完成todo并解释功能”。Codex 仅补全该函数的编号计算：lane=`t % warpSize`，warp_in_block=`t / warpSize`，添加一维 block 的分组注释；保留 GPU 数组写入和少量 printf。讲义同步当前完成范围、运行入口及验证，TODO 2 的分路条件保留。无课程范围偏离，无新增依赖或其他 kernel 修改。

使用章节 nvcc 命令编译正式源码，无警告；NVCC 12.9.86、GTX 1650 / CC 7.5 / warpSize=32，正式 probe 校验全部 64 项通过、mismatches=0、退出 0。正式 probe 的 `compute-sanitizer --tool memcheck --padding 32 --error-exitcode 99` 报告零错误、退出 0。证据为 `reports/CH06/probe-completed-2026-10-14.txt`；本次没有运行 check/bench、计时、NSYS 或 NCU，不新增分支性能结论。

用户完成部分为指定代码并要求补全；实现、编译和 GPU 验证由 Codex 完成，个人解释尚未验收。Ch06 保持 READING，TODO 2 与全章验收待完成，未标 DONE；实际学习用时及工程准备/agent 执行耗时未记录。例行局部补全无需额外 Claude 审阅，未启动 Claude、未提交或推送 Git；此前已有工作区改动保留。

## 2026-10-20：Ch06 分路练习 TODO 2 补全与正式验证

用户指定 `CH06/warp_branch.cu` 的 `choose_path_a()` 并要求“完成todo”。Codex 使用 block 内线程编号计算 lane/warp：mode=0 按 `lane < 16` 将同一 warp 分为 A/B 两半，mode=1 按 `warp_in_block % 2 == 0` 将完整 warp 分到 A/B；移除占位语句，更新正确性失败提示。保留此前 TODO 1 的正式实现，未改变输入、CPU reference、计算体或计时配置。讲义同步完成范围与运行方式，PLAN 更新目录注释，无计划范围偏离。

NVCC 12.9.86、GTX 1650 / CC 7.5 / warpSize=32 / 4096 MiB、驱动 610.88。按章节命令编译正式源码，无警告；probe 全部 64 项通过，check/bench 的两模式各 65536 项全量正确、mismatches=0，均退出 0。正式 check 的 memcheck 零错误、退出 0。正常计时使用 N=65536、uint32、grid=256、block=256、iterations=256；每模式预热 10 次、21 个样本、每批 5 次启动并轮换模式顺序。Event 批次平均每次启动中位数为 within_warp 113.785601 μs、between_warps 65.478402 μs，Timing PASS；本机本次 warp 内分路较慢，不将总差值归为纯分歧开销，不与历史数值作配对优化结论。

检查正式完成版 SASS：branch_work 的 0x270 条件 BRA、0x290/0x2d0 两路 CALL、计算体整数计算与循环、0x320 STG 输出均保留，未消除两路对照；静态产物不代替动态分歧计数。证据为 `reports/CH06/completed-2026-10-20.txt` 和 `reports/CH06/completed-2026-10-20-sm75.sass.txt`；Sanitizer 与正常计时分开，NSYS/NCU 本次 NOT RUN。无临时补全源码或二进制，正式 build 和报告保留复盘。

Ch06 改为 RUNNING，辅助程度为 Codex 提供框架、讲解和按要求补全两处练习；用户本次指定修改，未新增独立实现或个人解释验收证据，未标 DONE。实际学习与工程准备/agent 执行耗时均未记录。剩余验收为用户结合实际输出解释 warp/lane、两种模式的分路与计时边界。无需额外 Claude 审阅，未启动 Claude、未提交或推送 Git，先前工作区改动保留。

## 2026-10-20：Ch06 观察指令与 NSYS 时间线预检

用户要求提供指令，直观观察两个 path 整体流程的耗时差异。依据当前代码明确对照单位为两种 A/B 分路安排，保留 Event 不含分配/传输/校验的边界；现有程序未按模式单独测含传输的 host 端到端时间。本次不改源码，讲义补充普通 check/bench 与独立 NSYS 采集指令，并说明两种模式共用 branch_work 名称，通过当前启动顺序定位，不把内部 path_a/path_b 当成独立 kernel。

正式源码按原命令编译无警告；普通 check 两模式各 65536 项全部正确，bench warmup=10、samples=21、batch=5，Event 批次平均每次启动中位数为 within_warp 116.083205 μs、between_warps 71.097600 μs，均退出 0。该观察沿用 GTX 1650、uint32、N=65536、grid/block=256、iterations=256，仅反映当前微基准，不把跨次运行差异当优化 A/B。

核验 `/home/yhc23/.local/bin/nsys` 为 2026.4.1，单独采集 bench 并验证 GPU 数据完整：232 次 branch_work、1 次 H2D、44 次 D2H、2 次 memset。逐条 CSV 结构化解析确认数量，结合源码确定第 23～27 次为第一批正式 within_warp、第 28～32 次为第一批正式 between_warps；前 2 次初始校验、随后 20 次预热。CPU/GPU 时间线能观察整个运行过程，汇总合并两模式不用于单模式比较。GUI 人工打开本次 NOT RUN，未声称完成用户操作验收。

证据前缀 `reports/CH06/observe-preflight-2026-10-20`，保留 `.txt`、`.nsys-rep`、`.sqlite`、`.csv`。第一次 trace stats 因派生 SQLite 时间戳早于主报告而退出 1，诊断已转存日志，删除该次无效 CSV 后改读本次 SQLite，成功生成有效 CSV、退出 0，无需重新采集。工具采集运行与普通计时分开，未执行 NCU 或新的 Sanitizer。

用户本次要求指令，预检由 Codex 完成，个人实验输出与解释待验收，Ch06 保持 RUNNING。实际学习及工程准备/agent 用时未记录。复用 Ch05 已学的 NSYS 流程，无新增依赖或必修知识，无需额外 Claude 审阅；未提交或推送，已有工作区改动保留。

## 2026-10-20：Ch06 可选 NCU 动态分歧观察

用户主动询问如何用 NSYS/NCU 观察 warp divergence。按最新明确指令增加可选观察：讲义提供 NCU Source Counters 和两项少量指标的采集/读取命令；PLAN 记录该可选观察，Ch07 正式教学及首轮验收边界保留。解释 NSYS 时间线能观察长短但不独立证明分歧，NCU 分歧目标计数和线程参与数结合源码才支持本例结论。此次未修改源码或增加依赖。

核验 NCU 2025.2.1，依据本机 SourceCounters.section 和 metric 查询核对指标名。初次候选的 `smsp__branch_targets_threads_divergent` 在 launch metric 查询中无效，改用带 sass 的 `smsp__sass_branch_targets_threads_divergent.sum`；source 页面使用前一种名称。初次全量后缀查询输出过大，后续改为指定 base metric 和 sections 定向查询，未生成需清理的查询文件。

按原 nvcc 命令重新编译，无警告，普通 check 两种模式全量正确。NCU 只过滤 branch_work 的两次 launch，运行 check，第一个结果 mode=0、第二个 mode=1，采集 SourceCounters、分歧目标总计数与每条指令平均参与线程数，import-source=yes；每次 launch 5 passes，采集后的应用仍两模式各 65536 项全量正确、退出 0。mode=0/mode=1 的分歧目标总计数为 2048/0，每条指令平均参与线程数为 16.40/32，Branch Efficiency 为 98.08%/100%。前者存在动态分歧证据；后者本次分歧计数为 0。高 Branch Efficiency 可能被大量一致的循环分支稀释，不换算为性能损失。

报告 Details/Raw CSV 已导出并结构化核对结果 ID 0/1；CLI Source 导出进一步定位 kernel 偏移 0x270 的 BRA 分歧计数为 2048/0，后续 A/B 计算指令参与线程数为 16/32。该证据超出此前静态 SASS 检查，仍不等于逐周期硬件轨迹或固定减速比例。此处未做预热性能采样，不使用 NCU 插桩/重放下耗时作为普通计时；GUI 人工操作 NOT RUN。

证据前缀 `reports/CH06/ncu-divergence-2026-10-20`，保留 `.ncu-rep`、`.txt`、`-details.txt`、`-raw.csv`、`-source.txt`。报告读取均退出 0；无临时无效产物。用户提出观察问题，工具查询、采集与解释由 Codex 完成，个人操作及解释待验收，Ch06 保持 RUNNING，不记 DONE。实际学习与工程准备/agent 用时均未记录，无需额外 Claude 审阅，未提交或推送，既有工作区改动保留。

## 2026-10-20：用户 NCU GUI Source/SASS 关联观察

用户提供打开 `ncu-divergence-2026-10-20.ncu-rep` 的 GUI 截图，已选择左侧 CUDA Source、右侧 SASS，并显示 Divergent Branches、Avg. Threads Executed 及 Avg. Predicated-On Threads Executed。截图中源码第 80 行分路处对应 SASS 偏移 0x270 的条件 BRA，第 81/83 行 A/B 调用各显示 16 个参与线程，第 85 行输出写入显示 32；与此前 CLI 导出一致，证明用户已实际打开报告并定位相关源码。用户询问这种源码/SASS 对照定位方法是否正确，属于实际观察与解释确认，未据此自动认定全章独立解释通过。

截图中 Divergent Branches 的 100.0 为相对百分比显示，按官方文档可用 Source 工具栏 [%] 切换绝对值；结合原报告实际计数 2048，含义是当前该显示范围的分歧事件集中于此处，不是 100 次分歧、100% 性能损失或 Branch Efficiency=100%。源码行可关联多条 SASS，左侧行级聚合值不强行解释为单条指令值。历史“本次 GUI 未人工操作”仍描述 Codex 采集阶段；当前已新增用户截图证据，第二结果 GUI 对比尚未提供。

本次仅据用户截图、既有报告和官方 Source 页面文档核对，不重新编译或采集；Ch06 保持 RUNNING，个人解释仍待补齐，实际学习与工程用时未记录。未改源码、未提交或推送。

## 2026-10-20：Ch06 本章总结

按用户“总结本章内容”的要求，在 NOTE 新增 Ch06 汇总，覆盖本章实际接触的 warp/lane、block 内与全局索引、两种分路方式、程序分工、constexpr 与六个实验参数、device 函数与两条计算体、CUDA 状态码和辅助检查、异步提交与同步边界、普通 Event 计时、NSYS 时间线、可选 NCU 动态分歧及 Source/SASS 对照。保留用户真实提问，补入 report 按执行结果组织、check 的 2 次与 bench 的 232 次启动、launch 筛选和 5 passes 的区别，不编造用户操作或独立理解证据。

辅助程度明确为 Codex 提供框架并按请求补全两处练习、编译、memcheck、普通计时及 profiler 采集；用户完成了逐段阅读、提问和 NCU GUI 报告打开/源码关联查看，已有截图。总结引用本日已保存证据：普通观察 bench 的两模式中位数 116.083205/71.097600 μs；NCU 两结果分歧目标计数 2048/0、平均每指令参与线程 16.40/32、Branch Efficiency 98.08%/100%。注明这些计时与 NCU 指标来自不同运行，分别保留计时边界与动态证据范围，不混用 profiler 耗时或相对百分比。

Ch06 保持 RUNNING，个人解释验收待补齐；用户提问和 GUI 观察不自动替代对 warp 分组、分歧原因及 Event 边界的独立复述。NOTE 给出必做复述及可选工具复习，不将主动扩展的 NCU 观察升级为必修。计划学习 45～60 分钟，实际学习与工程准备/agent 执行耗时仍未记录，不从跨日会话推算。

本次仅整理 NOTE 与 RECORD，核对源码、既有日志/报告、文档链接和 diff 格式，没有重新编译、运行 GPU、采集 profiler 或测量性能。无新增计划范围变更，无需额外 Claude 审阅，未启动 Claude、未提交或推送，已有代码、讲义与证据保留。

## 2026-10-20：Ch07 合并访存与 NCU 内容生成及预检

用户明确要求“生成CH07内容”。按 PLAN 阶段 B 新增 [CH07/memory_access.cu](../CH07/memory_access.cu) 和 [章节讲义](chapters/07_coalescing_ncu.md)，同步 PLAN 目录及准备依据。复用前章检查、全量校验与成对 Event 计时骨架，正式代码只留一处 `input_index()` 跨步读取索引 TODO。连续/跨步模式在相同输入数组的每个 32×32 小片内按行/按列读取，均应读取全部元素各一次、做相同次数加法并连续写出；不使用直接 i*stride 的越界/扩大 footprint 对照，不引入 shared memory、bank conflict 或新依赖。NOTE 不提前记录未实际学习的内容。

现场复核 NVCC 12.9.86、GTX 1650 / CC 7.5 / warpSize=32 / 4096 MiB、驱动 610.88、NCU 2025.2.1.0、Compute Sanitizer 2025.2.1.0；程序查询 L2=1048576 字节。正式骨架与临时补全版均按讲义选项编译，无警告。shape=[4194304]、float32、grid=16384、block=256，GPU 两数组各 16 MiB。正式 check/bench 的 contiguous 全量 PASS，strided 为预期 FAIL（4063232 项不符、最大绝对误差 240.25），跳过计时并退出 1。临时补全版 check/bench 两模式各 4194304 项全量正确、误差 0，单独 memcheck 零错误，均退出 0。

正常计时与工具采集分开：每模式 warmup=10、samples=21、batch=5，Event 批次平均每次启动中位数 contiguous=317.452788 μs、strided=684.985590 μs。教学方 SASS 核查保留 LDG、FADD、STG，未消除读取。另一次 NCU check 运行只采 access_pattern 的两次 launch、每次 3 passes；两种模式应用仍全量 PASS。结果 ID 0/1 的 global load requests 均为 131072，global load sectors 为 524288/4194304，平均每请求涉及 sector 为 4/32。Details 和 Raw CSV 均成功导出并核对；CSV 为宽表，已排除单位行。计数只描述 L1/TEX global load 请求，不推断 DRAM 字节数或固定 8 倍减速；本机本次跨步较慢，无普适加速承诺。

证据为 `reports/CH07/preflight-2026-10-20.txt`、`completed-2026-10-20-sm75.sass.txt` 及 `ncu-preflight-2026-10-20` 前缀的 `.ncu-rep`、`-details.txt`、`-raw.csv`。预检报告导入临时补全源码以便复盘；临时源码及二进制在核对后清理，正式 build 保留练习占位版本。NCU 指标名与命令按本机工具核验，语义核对 NVIDIA 官方 CUDA 12.9/NCU 文档；本次 NCU GUI 人工操作和 NSYS 为 NOT RUN。检查章节链接及 diff 格式，无无效尝试文件遗留。

Ch07 为 READING，用户本次仅提出生成请求，关键索引实现、实际采集与个人解释待验收；Codex 提供骨架、讲义和临时完成版预检，不记为用户掌握。前章解释与其他遗留项保持。计划学习 45～60 分钟，实际学习及工程准备/agent 执行耗时均未记录。无教学范围偏离，无需额外 Claude 审阅，未启动 Claude、未提交或推送 Git。下一步用户先预测、编译观察占位失败，再补 TODO、重编译 check/bench、独立采两次 NCU 并解释计数和计时边界。

## 2026-10-21：Ch07 跨步读取索引补全与正式验证

用户指定 `CH07/memory_access.cu` 的 `input_index()` 并要求“完成todo”。Codex 计算 32×32 小片起点 base 和片内 row/col，返回 `base + col * kSide + row`，移除占位 TODO，添加保留小片起点的中文说明；正确性失败时不再提示补全已完成的 TODO。沿用输入、独立 CPU reference、kernel 计算与计时配置，同步讲义当前状态和 PLAN 目录注释，无计划范围偏离。

现场复核 NVCC 12.9.86、Compute Sanitizer 2025.2.1.0、GTX 1650 / CC 7.5 / warpSize=32 / 4096 MiB、驱动 610.88；shape=[4194304]、float32、grid=16384、block=256，输入和输出各 16 MiB。正式源码按讲义命令编译无警告，check/bench 两种访问各 4194304 项全量 PASS、mismatches=0、最大绝对误差 0；独立 memcheck 零错误，均退出 0。

正常计时与 Sanitizer 分开，每模式 warmup=10、samples=21、batch=5，Event 批次平均每次启动中位数 contiguous=317.593598 μs、strided=689.043188 μs，Timing PASS。不包含分配、传输或校验，仍可包含 host 提交间隙；仅为当前 GPU/输入的观察，不与历史运行作配对优化结论。本次 NCU、NSYS、SASS 导出和 GUI 均 NOT RUN，历史临时版 NCU 计数未冒充本次正式采集。命令、输出与源码 SHA-256 见 `reports/CH07/completed-2026-10-21.txt`，正式 build 已更新，无临时尝试文件。

Ch07 更新为 RUNNING；实现和验证均由 Codex 按要求完成，用户本次指定补全，个人运行、NCU 采集及解释待验收，不记 DONE。实际学习及工程准备/agent 执行耗时未记录。检查文档链接和 diff 格式，既有工作区改动保留；无需额外 Claude 审阅，未启动 Claude、未提交或推送 Git。

## 2026-10-21：Ch07 今日与本章总结

用户要求“总结今日。本章内容”。在 NOTE 新增本日 Ch07 条目，整理连续/跨步地址分组、base/row/col 索引、host run 流程、lambda 与字符串指针数组、forceinline/noinline、Event 采样和中位数、NCU requests/sectors、L1/TEX/L2/DRAM 层次与证据边界。保留用户真实提问与主动复述：能说明把 1024 项看成 32×32 表格，通过行列交换改变相邻线程的读取位置。该复述作为局部理解证据，不继续笼统写成没有任何解释，也不据此完成整章验收。

实现和编译、memcheck、bench 由 Codex 按要求完成，用户已逐段阅读、提问并复述实验主要变量；尚未收到本章用户自己的运行输出、NCU 报告或 GUI 截图。总结重读正式完成版日志及历史 NCU Details：10 月 21 日普通 Event 中位数连续=317.593598 μs、跨步=689.043188 μs，约 2.17 倍；10 月 20 日临时版 NCU 两结果 requests 均为 131072，sectors 为 524288/4194304，平均每请求 4/32 sector。NOTE 明确这两组证据来自不同日期和运行，不混用 profiler 耗时、DRAM 流量或缓存命中率；未采集的指标不填造。本次未增加 GPU 性能结论。

Ch07 保持 RUNNING，不标 DONE；剩余为用户自己的正确性/计时与两次 NCU 结果对应、sector 与显存流量及时间边界的个人解释。掌握度仍未整体评估，计划学习 45～60 分钟，实际学习和工程准备/agent 执行耗时未记录。NOTE 不另维护进度或工时。

本次只更新 NOTE 与 RECORD，核对现有源码、日志、数据计算、文档链接和 diff 格式；没有重新编译、运行 GPU、计时或采集 NCU/NSYS/Sanitizer。既有源码与报告保留，无临时文件或新增计划范围，无需额外 Claude 审阅，未启动 Claude、未提交或推送，先前工作区改动保留。
