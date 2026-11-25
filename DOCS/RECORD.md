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
| 08 shared 与同步 | RUNNING | 45～60min | — | 未评估 | Codex 骨架、讲解及按要求补全两处练习 | 正式校验、三种 Sanitizer 与 Event 通过；用户已复述对称读取，读写依赖及两类同步已讲解，个人运行和独立解释待验收 |
| 09 bank conflict | RUNNING | 45～60min | — | 未评估 | Codex 骨架、按要求补全地址练习及源码/指标讲解 | 正式校验、三种 Sanitizer、Event 与 NCU 通过；线程组织、转置、bank 分批与 1,015,808 计数已讲解并总结，个人运行和独立解释待验收 |
| 10 归约 | RUNNING | 45～60min | — | 未评估 | Codex 骨架、两处 TODO 补全、验证及源码/实验讲解 | 正式逐片/总和、三种 Sanitizer 与 Event 通过；用户已复述 shuffle 仍为树形归约，属性、mask、跨 warp 交接已讲解并总结，个人运行及完整独立解释待验收 |
| 11 SM 与 occupancy | RUNNING | 45～60min | — | 未评估 | Codex 骨架、两处 TODO 补全、验证及讲解总结 | 正式资源/数值、三种 Sanitizer、Event 与 API/NCU 通过；预留 0/16/32 KiB、理论驻留 4/3/1 blocks/SM；shared 来源、容量推导及 NCU 平均值已讲解总结，个人操作与独立解释待验收 |
| 12 数据复用 | RUNNING | 45～60min | — | 未评估 | Codex 骨架、两处 TODO 补全、验证及讲解总结 | 正式版两种 shape 全量校验、三种 Sanitizer 与 Event 通过；历史 NCU 对照保留；用户已正确复述固定输出与沿 K 分块累加，个人运行及同步/尾部/缓存边界的完整独立解释待验收 |
| 13 Host 异步 | RUNNING | 45～60min | — | 未评估 | Codex 骨架、TODO 补全、验证、计时及GUI讲解总结 | 正式数值、完成边界、memcheck、计时及NSYS关联通过；用户已提供GUI截图并定位第五次kernel，个人程序运行/采集及完整独立解释待验收 |
| 14 Stream | RUNNING | 45～60min | — | 未评估 | Codex 骨架、讲义、两处 TODO 补全、验证与总结 | 正式版same/split配置/路由、8198项全量数值、memcheck与计时通过；历史临时版NSYS对照及用户双stream/默认stream GUI截图已有证据；个人运行/采集与完整独立解释待验收 |
| 15 Event 与重叠 | RUNNING | 45～60min | — | 未评估 | Codex 骨架、讲义、两处 TODO 补全、验证、讲解与总结 | 正式版全量数值、既有memcheck、普通计时及2026-11-05正式NSYS对照通过；用户已部分复述连续提交与槽位复用，stream/slot和ready/done关系及重绘图来源已讲解；个人运行/读图与完整独立解释待验收 |
| 16 Graph | RUNNING | 45～60min | — | 未评估 | Codex 骨架、两处 TODO 补全、验证、逐行讲解与总结 | 正式版节点/数值、既有memcheck/普通计时及2026-11-09正式NSYS node对照通过；指针/句柄、节点检查和间隙已讲解并总结；个人运行/读图与独立解释待验收 |
| 17 编译产物 | RUNNING | 45～60min | — | 未评估 | Codex 骨架、两处命令补全、验证、PTX/SASS讲解与总结 | 正式构建/全量数值/memcheck及入口查看通过；用户已提供nvdisasm命令与完整输出，寄存器/地址/产物关系已讲解；个人编译/Runtime运行与完整独立解释待验收 |
| 18 Driver | RUNNING | 45～60min | — | 未评估 | Codex 骨架、两处 TODO 补全、验证、context探针及逐段讲解总结 | 正式版全量数值/memcheck和context探针已有验证；指针参数、隐式context选择/恢复、资源归属与清理已讲解总结；个人运行与完整独立解释待验收 |
| 19 内存复用 | RUNNING | 45～60min | — | 未完整评估 | Codex 骨架、TODO补全、验证、NSYS及受控对照、讲解总结 | 正式数值/计数/memcheck/普通计时通过；NSYS与诊断边界已记录；用户已正确复述“复用减少反复申请释放开销，Event差距不必巨大”；个人运行与完整独立解释待验收 |
| 20 异步分配与内存池（选修） | RUNNING | 45～60min | — | 未完整评估 | Codex 骨架、两处TODO补全、验证、驱动探针及讲解总结 | 正式双策略数值、memcheck、普通计时与NSYS通过。用户已指出两条路径每轮都释放三个数组、都等释放完成，且kernel仍访问global memory。个人运行和完整独立解释待验收 |
| 21 跨stream异步分配生命周期（选修） | RUNNING | 45～60min | — | 未评估 | Codex 骨架、讲义、两处TODO补全及验证 | 正式版双策略各32000项通过，memcheck零错误及零泄漏，NSYS核对交接API和GPU活动顺序。个人运行与独立解释待验收 |
| 22 VMM 分段扩容（选修） | RUNNING | 45～60min | — | 未完整评估 | Codex 骨架、讲义、两处 TODO 补全、验证及总结 | 正式 probe 和 check 通过，扩容后基地址相同，1,048,576 项正确，memcheck 零错误及零泄漏。用户已复述分段写入和虚拟地址连续性，个人运行和完整独立解释待验收 |

后续选修仅在用户启动且 PLAN 写明范围后添加，未启用的选修不影响首轮完成。2026-11-18 按“生成CH20内容”启用单 stream 内存池，2026-11-19 启用 Ch21 跨 stream 生命周期，2026-11-24 启用 Ch22 VMM 分段扩容。范围见 PLAN 第 6 节，首轮仍为 Ch00～19。

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

## 2026-10-21：Ch08 shared 与同步内容生成及预检

用户明确要求“生成CH08内容”。按 PLAN 阶段 B 新增 [CH08/shared_exchange.cu](../CH08/shared_exchange.cu) 和 [章节讲义](chapters/08_shared_sync.md)，同步 PLAN 目录与准备依据。复用前章错误检查、输入/全量校验与可选 Event 计时，固定每个 block 将自己的有效片段反序，跨 warp 交换 shared 数据；check/race 使用同一个 kernel，只改变是否在读取前执行 block barrier。正式练习保留两处 TODO：同步点和伙伴槽位读取。不提前提供归约、bank conflict 或 NCU 新指标；NOTE 不将未学习内容记成用户成果。

现场复核 NVCC 12.9.86、Compute Sanitizer 2025.2.1.0、GTX 1650 / CC 7.5 / warpSize=32 / 4096 MiB、驱动 610.88；程序查询 sharedMemPerBlock=49152 字节。输入 shape=[1000]、float32、grid=8、block=128，七个完整片段与一个 104 项尾部，每 block shared=512 字节，输入与输出各 4000 字节。所有线程均按本例结构参加同步，无效尾部线程不越界读取或写 output。

最终正式骨架及临时补全版按讲义选项编译无警告。正式 check/bench 均为预期数值 FAIL：mismatches=1000、最大误差 31.75、退出 1，bench 跳过计时。初版占位直接读 input，触发 tile 未使用警告；改为读自己的 shared 槽位后重新完成预检，当前正式代码仍未实现伙伴读取。该警告与修正前后的证据均保留，日志 `FINAL SKELETON` 段对应当前正式源码。

临时版仅填 barrier 与伙伴读取，check/bench 全部 1000 项 PASS、最大误差 0；独立 memcheck（padding=32）、racecheck、synccheck 对 check 均零错误，退出 0。另一次故意缺 barrier 的 race 运行 memcheck 零错误，racecheck 报 shared 写/读冲突、退出 99，数值校验本次仍 PASS。racecheck 摘要为 1 条 error 分析、合并 4000 字节级 hazards，不能写成 4000 个独立 bug。race 模式故意以应用退出 0 结束数值观察，让 Sanitizer 用指定错误码表达检查失败；不能视其应用退出码或数值 PASS 为无竞争证明。

普通计时与 Sanitizer 分开。临时同步版 warmup=10、samples=21、batch=10，最终预检 Event 批次平均每次启动中位数 7.526400 μs，Timing PASS；初版临时预检的 8.873600 μs 也保留在原日志，不把两个运行作优化 A/B。时间不含分配、传输、reference 或回读校验，短 kernel 仍可能受 host 提交间隙影响；本章不计时错误版本，不作 shared 加速结论，可选 bench 不成为必修验收。

原始命令、输出、退出码与两版源码 SHA-256 见 `reports/CH08/preflight-2026-10-21.txt`。临时源码与二进制在核验后清理，正式 build 保留两处 TODO 的练习版本。NCU、NSYS 和 GUI 均 NOT RUN；官方语义按 CUDA 12.9、Compute Sanitizer 文档及本机头文件/CLI 核对。章节源码与文档链接、差异格式已检查，无新增依赖或无效临时产物。

Ch08 更新为 READING；用户本次只提出生成请求，实现练习、个人运行与解释待验收，不记 DONE，不补记 Ch07 或前章完成。计划学习 45～60 分钟，实际学习及工程准备/agent 执行耗时未记录，不从聊天间隔推算。无教学范围偏离，无需额外 Claude 审阅，未启动 Claude、未提交或推送。下一步先预测首尾片段结果，补两处 TODO，重新编译 check，再对照正确/缺同步版本的 racecheck 并解释依赖。

## 2026-10-22：Ch08 两处 TODO 补全与正式验证

用户在阅读课程概述、源码阅读顺序及 main 流程讲解后，明确要求“完成两个todo”。Codex 在 [exchange_block()](../CH08/shared_exchange.cu) 的统一 use_barrier 分支内加入 `__syncthreads()`，并改为 `output[i] = tile[peer]`，移除占位语句与已失效的 TODO 提示，添加同步位置和尾部反序的中文说明。沿用 N=1000、float32、grid=8、block=128、尾部 104 项、shared=512 字节/block；未修改 CPU reference 或扩大教学范围。同步 PLAN 目录注释与讲义当前状态，保留历史骨架预检事实。

现场复核 NVCC 12.9.86、Compute Sanitizer 2025.2.1.0、GTX 1650 / CC 7.5 / warpSize=32 / 4096 MiB、驱动 610.88。正式源码按讲义命令编译无警告，check/bench 均全量 1000 项 PASS、mismatches=0、最大绝对误差 0。独立 memcheck（padding=32）、racecheck、synccheck 对 check 均零错误，退出 0。故意缺同步的 race 另经 memcheck 零错误，racecheck 报出 shared 第 38 行写入与第 46 行读取冲突，合并 4000 个字节级 hazards 为 1 条 error 分析，退出 99；该运行数值仍 PASS，不当作无竞争证明。

普通 bench 与 Sanitizer 分开执行：warmup=10、samples=21、batch=10，Event 批次平均每次启动中位数 12.102400 μs、Timing PASS。时间不含分配、传输或校验，仍可能包含 host 提交间隙；不与历史预检作优化性能 A/B，不测缺同步版本速度。本次 NCU、NSYS 与 GUI 均 NOT RUN，全部命令、输出、退出码和正式源码 SHA-256 见 [completed-2026-10-22.txt](../reports/CH08/completed-2026-10-22.txt)。正式 build 已更新，无临时尝试产物。

Ch08 更新为 RUNNING；实现和验证由 Codex 按用户要求完成，用户已有源码阅读和提问，个人运行、对 shared 作用域、写后读同步、尾部片段及 racecheck 证据的解释仍待验收，不记 DONE。实际学习及工程准备/agent 执行耗时未记录。文档链接与差异格式检查通过，无计划范围偏离或新增依赖，无需额外 Claude 审阅，未启动 Claude、未提交或推送，既有改动保留。

## 2026-10-22：Ch08 现有可执行文件实验现象观察

用户已主动复述 kernel 是在 block 内读取与自身对称的 shared 槽位，作为局部理解证据；随后阅读 benchmark，并要求根据生成的可执行文件说明实验现象。Codex 直接运行现有 `build/CH08/shared_exchange`，未重新编译或修改源码。GTX 1650 / CC 7.5、N=1000、float32、grid=8、block=128、尾部 104 项、shared=512 字节/block；普通 check 全量 PASS、最大误差 0，output[0]=31.75、output[896]=249.75，与 reference 一致。

普通 bench 先校验，通过后按 warmup=10、samples=21、batch=10 采样，本次 Event 批次平均每次启动中位数 14.627200 μs、Timing PASS。独立 racecheck 对 check 为零错误、退出 0；对缺 barrier 的 race 报第 38 行 shared 写入与第 46 行读取冲突，1 条 error 分析合并 4000 字节级 hazards、退出 99，数值本次仍 PASS。核心现象为有同步可正确交接，缺同步可能数值仍正确但检查出缺失的读写顺序保证；本次未测错误版本性能，不推断 shared 加速或历史时间差原因。

命令、输出、退出码及现有二进制/源码 SHA-256 保存在 [observe-2026-10-22.txt](../reports/CH08/observe-2026-10-22.txt)。工具运行与普通计时分开；本次未重跑 memcheck/synccheck、NCU、NSYS 或 GUI，未生成临时尝试产物。Ch08 保持 RUNNING，用户已解释对称读取，但个人操作、同步和工具证据的独立解释仍待验收；实际学习与工程执行用时未记录。仅补充 RECORD 与局部理解证据，无计划偏离，无需额外 Claude 审阅，未提交或推送。

## 2026-10-22：Ch08 本章总结

按用户“总结本章内容”的要求，在 NOTE 新增 Ch08 汇总，覆盖 shared 的 block 作用域、片段反序与尾部 104 项、main/launch 的 CPU 数据流、GPU 写入与伙伴读取、barrier 与 host 等待的区别、benchmark 预热和 Event 批次中位数、正确性与 racecheck 证据。保留用户真实提问及对称读取的主动复述，重点解释“不同位置的读取为何仍依赖其他线程先写好”，不把示意执行顺序写成本次真实硬件轨迹。

总结重读源码和两份已有日志：observe 中 check/race 数值均 PASS，racecheck 分别零冲突/检出 shared 写读冲突，普通同步版 Event 中位数 14.627200 μs；completed 中三种正确性工具零错误，另一轮普通中位数 12.102400 μs。明确来自不同运行，工具检查与普通计时分开，不把数值 PASS 等同于无竞争，不将多次计时作优化 A/B，也不推断固定性能收益。

Ch08 保持 RUNNING。用户已解释对称读取，barrier、跨线程写后读依赖与 host 同步边界已讲解，尚未收到用户个人运行或对这些边界的独立复述，不记 DONE；掌握度未整体评估。实现和工具验证由 Codex 完成，计划学习 45～60 分钟，实际学习及工程执行耗时未记录。NOTE 用两段自测衔接后续验收，不增加首轮范围。

本次仅更新 NOTE 与 RECORD，核对现有源码、既有实验日志、数值、文档链接及 diff 格式，没有重新编译、运行 GPU、计时或采集工具。无计划偏离、依赖变化或临时产物，无需额外 Claude 审阅，未启动 Claude、未提交或推送，既有工作区改动保留。

## 2026-10-22：Ch09 bank conflict 内容生成及预检

用户明确要求“生成CH09内容”。按 PLAN 阶段 B 新增 [CH09/bank_conflict.cu](../CH09/bank_conflict.cu) 与 [章节讲义](chapters/09_bank_conflict.md)，同步 PLAN 目录和准备依据。复用 Ch08 的 shared 写入、barrier、读取与前章校验/计时骨架，固定 1024 个 32×32 小片分别转置，只比较 shared 行跨度 32/33；global 地址、操作数、block、barrier 及 shared 预留大小均保持一致。正式源码保留一处 shared_index 地址 TODO；占位版忽略 stride，因此两模式数值都能 PASS，须以 NCU 计数确认 padding 已生效，不能仅凭输出正确或 stride_arg 标签验收。

现场复核 NVCC 12.9.86、NCU/Compute Sanitizer 2025.2.1.0、GTX 1650 / CC 7.5 / warpSize=32 / 4096 MiB、驱动 610.88。shape=[1024,32,32]、float32、N=1048576、grid=1024、block=(32,8)，输入/输出各 4 MiB。两模式 cudaFuncGetAttributes 与编译资源报告均为 shared=4224 字节、20 registers/thread、local=0；stride 32 保留未使用空间，避免把 shared 资源预留差异引入本章对照。只处理完整 tile，不新增尾部算法任务。

正式骨架和临时补全版编译均无警告，各自 check/bench 每模式全量 1048576 项 PASS、误差 0。两版各自 check 的 memcheck（padding=32）、racecheck、synccheck 均零错误，racecheck 零 warnings，退出 0。临时版仅将 shared_index 的固定行跨度占位改成使用传入 stride，未改 global 数据流、CPU reference 或同步。教学方核验 SASS，两种临时布局各保留四条标量 STS、一个 BAR.SYNC、四条标量 LDS.U，没有将目标访问消除；指令后缀不用于单独判断各 lane 地址或有无冲突，不变成学生首轮门槛。

NCU 仅采集 shared_transpose 的前两次 launch，读取 l1tex__data_bank_conflicts_pipe_lsu_mem_shared_op_ld.sum 与对应 st.sum。正式骨架的 stride_arg=32/33 均为读取冲突 1015808、写入冲突 0；临时补全版分别为读取冲突 1015808/0、写入冲突均为 0。报告导出的两行结果已用 CSV 按指标名核对，摘要保存在 [metrics-2026-10-22.csv](../reports/CH09/metrics-2026-10-22.csv)。本机 CLI 的指标查询和安装文档也确认了 shared_ld_bank_conflict/shared_st_bank_conflict 映射；线上 NCU 2025.2 归档页面访问失败，通用语义参考当前官方页，实际版本、选项和指标依据本机 2025.2.1。

普通 bench 与工具采集分开，warmup=10、samples=21、batch=5。骨架两参数的 Event 批次平均每次启动中位数为 189.760005/193.075204 μs，临时补全版为 195.417595/69.984001 μs，临时版本轮比值约 2.792。时间不含分配、传输和 CPU 校验；包括 kernel 的 global/shared、barrier 与可能的 host 提交间隙。只记录当前设备与输入，不把不同预检运行作优化 A/B，也不将 32 路 bank conflict 推成固定 32 倍 kernel 耗时。

全部命令、原始输出、退出码、源码 SHA-256 与资源报告见 [preflight-2026-10-22.txt](../reports/CH09/preflight-2026-10-22.txt)，两版 NCU/SASS 文件链接集中在讲义。临时补全源码与二进制核验后清理，正式 build 保留 TODO 骨架。NSYS、GUI 均 NOT RUN；未新增依赖，NOTE 不提前记录为用户已学会。

Ch09 更新为 READING。用户本次只提出生成请求，TODO、个人运行/采集与独立解释待验收，不记 DONE，不改变前章状态。计划学习 45～60 分钟，实际学习与工程准备/agent 执行耗时未记录。无计划范围偏离，无需额外 Claude 审阅，未启动 Claude、未提交或推送。下一步先预测两种 bank 分布，完成一处地址转换，重新编译检查，再用 NCU 两结果解释 padding 与 global 合并访存、数据竞争的区别。

## 2026-10-23：Ch09 地址 TODO 补全与正式验证

用户要求“完成todo，并告诉我这里整个kernel主要是什么功能”。Codex 将 `CH09/bank_conflict.cu` 的 shared_index 改为 `row*stride+col`，移除 `(void)stride` 和过时占位提示；global 索引、输入、CPU reference、block、循环及同步均未改变。同步更新讲义的当前实现、历史占位版边界与本次证据，PLAN 目录说明更新为已补全，保留既有工作区改动。kernel 的功能为每个 block 转置一个独立 32×32 小矩阵，按行写 shared、barrier 后按列读、连续写 global；stride 32/33 只改变 shared 布局，两种输出必须一致。

现场复核 NVCC 12.9.86、NCU/Compute Sanitizer 2025.2.1.0、GTX 1650 / CC 7.5 / warpSize=32 / 4096 MiB、驱动 610.88。shape=[1024,32,32]、float32、N=1048576、grid=1024、block=(32,8)，两模式 shared 均为 4224 字节。正式编译无警告，check/bench 每模式全量 PASS、误差 0；check 的 memcheck（padding=32）、racecheck、synccheck 均零错误，racecheck 零 warnings，退出 0。NCU 过滤 shared_transpose、采集两次 launch，读取 bank conflict 为 1015808/0，写入均为 0，按指标名解析 CSV 核对正式布局已生效。

独立普通 bench 为 warmup=10、samples=21、batch=5，Event 批次平均每次启动中位数为 189.683199/68.320000 μs，本轮比值约 2.776，不含分配、传输和 CPU 校验，可能包含 host 提交间隙；不推断通用加速比，不与历史预检跨运行比较。命令、输出、退出码和正式源码 SHA-256 见 [completed-2026-10-23.txt](../reports/CH09/completed-2026-10-23.txt)，报告为 [completed-2026-10-23.ncu-rep](../reports/CH09/completed-2026-10-23.ncu-rep)，解析摘要为 [completed-metrics-2026-10-23.csv](../reports/CH09/completed-metrics-2026-10-23.csv)。本次 NSYS、GUI、SASS 均 NOT RUN，无临时源码或新增依赖。

Ch09 更新为 RUNNING，实现和验证由 Codex 完成；用户已要求讲解参数与 kernel 功能，但个人运行、bank 映射及 padding 的独立解释待验收，不记 DONE。计划学习 45～60 分钟，实际学习与工程执行耗时未记录。无计划范围偏离，无需额外 Claude 审阅，未启动 Claude、未提交或推送。

## 2026-10-26：Ch09 本章总结

按用户“总结本章内容”的要求，在 NOTE 新增 Ch09 汇总，覆盖参数与 block 工作划分、二维线程一维编号及 warp/lane 计算、两轮循环和转置输出索引、shared_index 的 stride 32/33 映射、template/volatile/pragma unroll、bank 分批服务、NCU Raw/访存表入口及累计冲突口径。按 NOTE 既有格式保留用户真实问题和理解难点，用标记突出关键结论；不把用户尚未给出的独立复述或 GUI 操作记成掌握证据。

重读正式源码、10 月 23 日验证日志及 NCU 指标 CSV：两模式 1048576 项 PASS、误差 0，三种 Sanitizer 零错误，shared 读冲突 1015808/0、写冲突均为 0，独立 Event 中位数 189.683199/68.320000 μs、本轮比值约 2.776。通过 1024 blocks×8 warps×4 次读取×31 额外批次解释本例大计数，限定为本机该标量读取实验，未泛化到其他访问宽度或所有 kernel；工具与普通计时、历史预检与正式版分别表述。

本次只更新 NOTE 与 RECORD，核对源码、既有日志、计算和本地文档链接及差异格式；没有重新编译、运行 GPU、计时、采集 profiler 或操作 GUI，未新增临时产物。Ch09 保持 RUNNING，用户个人运行与对 warp 分组、转置读写、bank 映射和指标口径的独立解释仍待验收，不记 DONE；实际学习与工程执行耗时未记录。无计划范围偏离、依赖变更或新增课程门槛，无需额外 Claude 审阅，未启动 Claude、未提交或推送，既有工作区改动保留。


## 2026-10-26：Ch10 归约内容生成与预检

用户明确要求“生成CH10内容”。按 PLAN 阶段 B 新增 [CH10/reduction.cu](../CH10/reduction.cu) 与 [章节讲义](chapters/10_reduction.md)，更新 PLAN 目录与准备依据、NOTE 预习入口。固定 N=262144、float32、grid=1024、block=256，每线程读取一项，GPU 每 block 输出一个和，CPU 汇总 1024 个片段和。主要变量为 shared 树形与 warp shuffle 的协作方式；保留 shared 累加和 shuffle 取值累加两处关键 TODO。输入全部覆盖完整 warp，最后一轮由 warp 0 的 32 个 lane 读取 8 个有效和及 24 个零，不引入尾部 mask、atomic、跨 block GPU 归约或新 profiler 指标。

现场复核 GTX 1650 / CC 7.5 / warpSize=32 / 4096 MiB、驱动 610.88，NVCC 12.9.86、Compute Sanitizer 2025.2.1.0。输入 1 MiB、输出 4 KiB，以包含正负数和零的小整数 float 逐片校验，CPU reference 使用 double 顺序加法。本例的整数范围允许精确比较，不推广为任意浮点归约必须误差 0。正式骨架与临时两阶段补全版均编译无警告；正式骨架两方法各 1014 个 partial 不匹配、最大误差 232、总和 -11（期望 -184），check/bench 预期退出 1，bench 拒绝计时。临时只补 TODO(1) 时 shared PASS、shuffle FAIL；两处补全后两方法的 1024 个 partial 均 PASS、最大误差 0、总和 -184、第一片 -189，check/bench 退出 0。

正式骨架与临时补全版各自执行 memcheck（padding=32）、racecheck、synccheck，均无工具错误，racecheck 无 warnings。骨架因数值未完成退出 1，工具打印 Target application returned an error；临时补全版均退出 0，区分算法校验与访问/同步检查。临时补全版资源为 shared=1024/32 字节每 block、寄存器=12/14 每线程、均无 spill；教学方查看 SASS，shared 版保留树形交接，shuffle 版保留 SHFL 和 block barrier，未把静态指令当动态计数或用户必学内容。

独立普通 bench 为 warmup=10、samples=21、batch=10，shared/shuffle 的 Event 批次平均每次启动中位数为 49.526399/29.548800 μs，本轮比值 1.676。区间不含分配、传输、CPU 校验及最终汇总，可能含 host 提交间隙；不把差值单独归因于 barrier，不推断固定加速比。原始命令、源码 SHA-256、输出、退出码、资源及 SASS 见 [preflight-2026-10-26.txt](../reports/CH10/preflight-2026-10-26.txt)。临时补全源码与二进制已清理，正式 build 保留 TODO 骨架；NCU、NSYS、GUI 均 NOT RUN，无新增依赖。

Ch10 更新为 READING，TODO、个人运行与独立解释待验收；Codex 提供并验证骨架和临时补全版，不把预检计为用户完成，不改变前章待验收状态。计划学习 45～60 分钟，实际学习与工程准备/agent 执行耗时未记录。NOTE 只新增预习提示，不编造用户问题或掌握证据。无计划范围偏离，无需额外 Claude 审阅，未启动 Claude、未提交或推送。下一步先预测 8 项缩小例子的合并，再分两步补 TODO、重新编译、校验和解释 shared/barrier 与 shuffle 的交接边界。


## 2026-10-27：Ch10 shared 归约 TODO(1) 补全与验证

用户明确要求“完成TODO1，并告诉我这个kernel的功能”。Codex 在 `block_sum_shared()` 的 tid<stride 分支内加入 `tile[tid] += tile[tid + stride];`，移除该 TODO 标记并解释片段合并；保留 TODO(2) 与 shuffle 实现原状。更新程序提示、PLAN 目录说明及讲义的当前阶段，保留 10 月 26 日预检的历史事实。kernel 每 block 用 256 个线程读取连续 256 项，经 shared 逐轮合并为一个 partial，由线程 0 写出；1024 个 block 独立处理各片，最后由 CPU 汇总。

现场复核 GTX 1650 / CC 7.5 / warpSize=32 / 4096 MiB、驱动 610.88，NVCC 12.9.86、Compute Sanitizer 2025.2.1.0。固定 N=262144、float32、grid=1024、block=256，重新编译无警告；shared 的全部 1024 个片段和 PASS、最大误差 0、总和 -184、第一片 -189。shuffle 因 TODO(2) 尚未完成而 FAIL，整个 check 预期退出 1，不能误报整章两种方法均通过。

对正式 check 执行 memcheck（padding=32）、racecheck、synccheck，均零工具错误，racecheck 零 warnings；均因 shuffle 数值未完成而继承退出 1，Target application returned an error 不作为内存/同步错误。命令、源码 SHA-256、输出和退出码见 [shared-completed-2026-10-27.txt](../reports/CH10/shared-completed-2026-10-27.txt)。本次 bench、NCU、NSYS、GUI 均 NOT RUN，未新增临时源码或二进制，无依赖变化。

Ch10 更新为 CODING，shared 实现及验证由 Codex 完成；TODO(2)、个人操作与独立解释待验收，不记 DONE。NOTE 补充本次 kernel 功能与数据交接的讲解，不把已讲解当成用户掌握。计划用时 45～60 分钟，实际学习及工程执行耗时未记录；无计划范围偏离，无需额外 Claude 审阅，未启动 Claude、未提交或推送，保留既有工作区改动。


## 2026-10-27：Ch10 shuffle TODO(2) 补全与正式验证

用户明确要求“完成TODO2”。Codex 在 `warp_sum()` 的 offset=16、8、4、2、1 循环内实现 `value += __shfl_down_sync(0xffffffffu, value, offset);`，移除占位和失效的 TODO 提示，添加完整 warp 同时交换片段和的中文说明；调用布局、跨 warp shared 交接和 block barrier 保持不变。更新 PLAN 目录、讲义当前行为和 NOTE 的阶段性失败说明，保留历史预检及只完成 TODO(1) 的记录。

现场复核 GTX 1650 / CC 7.5 / warpSize=32 / 4096 MiB、驱动 610.88，NVCC 12.9.86、Compute Sanitizer 2025.2.1.0。N=262144、float32、grid=1024、block=256，重新编译无警告；正式 shared/shuffle 各检查全部 1024 个片段和，均 PASS、mismatches=0、最大误差 0、总和 -184、第一片 -189。两种方法的 check 经 memcheck（padding=32）、racecheck、synccheck 均零错误，racecheck 零 warnings，所有命令退出 0。

独立普通 bench 为 warmup=10、samples=21、batch=10，同 stream Event 批次平均每次启动中位数为 shared 29.046401 μs、shuffle 16.640000 μs，本轮比值 1.746、Timing PASS。区间不含分配、传输、CPU 校验或汇总，可能含 host 提交间隙；不与历史运行作性能 A/B，不把比值泛化或全部归因于减少 barrier。命令、源码 SHA-256、原始输出和退出码见 [completed-2026-10-27.txt](../reports/CH10/completed-2026-10-27.txt)。本次 NCU、NSYS、GUI 均 NOT RUN，未创建临时源码或二进制，无新增依赖。

Ch10 更新为 RUNNING，两处实现和验证均由 Codex 按用户要求完成；个人运行、shared 轮间依赖及完整 warp shuffle 的独立解释仍待验收，不记 DONE。计划学习 45～60 分钟，实际学习及工程执行耗时未记录。无计划范围偏离，无需额外 Claude 审阅，未启动 Claude、未提交或推送，既有改动保留。


## 2026-10-27：Ch10 本章总结

按用户“总结本章内容”的要求，整合 NOTE 原有的 shared 片段求和与 shuffle 补全说明，形成完整 Ch10 复盘。覆盖 kernel 属性查询、host 数据流与 CPU 汇总范围、shared 树形合并和轮间依赖、shuffle 的 per-lane value/full mask/offset、跨 warp shared 交接与 warp 0 的零填充合并、__forceinline__、校验和 Event 边界。保留用户实际提问及“shuffle 仍然是树形归约”的主动复述，用于局部理解证据，不编造用户实现或工具操作。

重读正式源码、章节讲义及当日 completed 日志：两方法各 1024 个 partial PASS、最大误差 0、总和 -184、第一片 -189；三种 Sanitizer 零错误、racecheck 零 warnings。静态 shared=1024/32 字节每 block，源码 barrier 次数=9/1，普通 Event 中位数=29.046401/16.640000 μs，本轮比值 1.746（warmup=10、samples=21、batch=10）。明确源码计数与硬件动态指标、工具与普通计时、本轮结果与历史预检的边界，不把收益全部归因于单个因素或泛化到其他设备输入。

本次仅更新 NOTE 与 RECORD，并核对源码 SHA-256、日志数值、文档链接与 diff 格式；没有重新编译、运行 GPU、计时或采集 profiler，无新临时产物。Ch10 保持 RUNNING，用户已有树形归约与通信差别的局部复述，个人运行及对 shared 轮间依赖、完整 warp 参与和跨 warp 数据流的完整独立解释仍待验收，不记 DONE。实际学习及工程执行耗时未记录。无计划偏离、新依赖或新增课程门槛，无需额外 Claude 审阅，未启动 Claude、未提交或推送，既有工作区改动保留。


## 2026-10-27：Ch11 SM 与 occupancy 内容生成及预检

用户明确要求“生成CH11内容”。按 PLAN 阶段 B 新增 [CH11/occupancy.cu](../CH11/occupancy.cu) 与 [章节讲义](chapters/11_occupancy.md)，更新 PLAN 目录/准备依据和 NOTE 预习入口。复用 Ch10 已实现的 shuffle 求和及校验、Event 骨架，固定 N=262144、float32、grid=1024、block=256、输入 1 MiB、输出 4 KiB；唯一主动改变的变量是每 block 额外预留 0/16384/32768 字节 dynamic shared。额外空间不访问，静态 shared 均为 32 字节。正式源码保留 occupancy API 查询和 launch 动态字节数两处关键 TODO；不调寄存器、block 或 kernel 算法。

现场复核 GTX 1650 / CC 7.5 / 14 SM / warpSize=32 / 4096 MiB、驱动 610.88，NVCC 12.9.86、NCU/Compute Sanitizer 2025.2.1.0。核对本机 cuda_runtime.h 和 CUDA 12.9 官方 API 参数。正式骨架与只补两处 TODO 的临时版均编译无警告，编译/Runtime 属性为每线程 14 个寄存器、32 字节静态 shared、无 spill。骨架三组全部 1024 个 partial 均数值 PASS、误差 0、总和 -184，但查询未完成、实际预留均为 0，资源配置 INCOMPLETE，check/bench 预期退出 1，bench 拒绝计时。临时补全版三组逐片及总和均 PASS、误差 0，API 返回每 SM 驻留 4/3/1 个 block、理论 occupancy 100%/75%/25%，check/bench 退出 0。

正式骨架和临时版各经 memcheck（padding=32）、racecheck、synccheck，均零工具错误，racecheck 零 warnings；骨架因练习未完成继承退出 1，Target application returned an error 不能解释为 Sanitizer 错误，补全版均退出 0。NCU 仅采临时版 check 的三次 launch，LaunchStats 确认动态预留为 0/16384/32768 字节、静态 32 字节；理论 occupancy 与 API 一致，achieved occupancy 分别为 73.49%/51.84%/19.42%，shared 限制 block 数为 128/3/1、warp 限制均为 4。NCU 中 shared 配置从 32768 变为 65536 字节，不能假设缓存配置也固定；NCU 分配后的每线程寄存器报告为 16，与编译报告分开记录，不据此新增调参任务。

独立普通 bench 为 warmup=10、samples=21、batch=10，三组 Event 批次平均每次启动中位数分别为 31.251201/33.695999/75.939202 μs。区间不含分配、传输、CPU reference/校验及汇总，可能含 host 提交间隙；不与 profiler/前章或历史运行作性能 A/B，不将耗时全部归因于 occupancy 或推广为固定性能比例。原始命令、两份源码 SHA-256、临时补全差异、退出码及工具/资源表见 [预检日志](../reports/CH11/preflight-2026-10-27.txt)，报告为 [NCU](../reports/CH11/preflight-2026-10-27.ncu-rep)，原始指标为 [CSV](../reports/CH11/preflight-metrics-2026-10-27.csv)。临时补全源码及二进制已清理，正式 build 对应两处 TODO 骨架。NSYS、GUI、SASS 均 NOT RUN，无新增依赖。

Ch11 记 RUNNING，仅表示骨架和教学预检已开展，不计用户完成或掌握；两处 TODO、个人运行及关于 static/dynamic shared、驻留容量、理论/实际 occupancy 与计时边界的独立解释待验收。NOTE 只添加预习入口，不编造用户问题或学习结果；前章待验收保留。计划学习 45～60 分钟，实际学习与工程准备/agent 执行耗时未记录。无计划范围偏离，无需额外 Claude 审阅，未启动 Claude、未提交或推送。下一步先读讲义预测，再补查询与 launch 两处 TODO，重新编译并做三组对照。


## 2026-10-28：Ch11 occupancy 查询 TODO(1) 补全

用户明确要求“完成TODO1”。Codex 在 CH11/occupancy.cu 的 active_blocks_per_sm 中加入 CUDA_CHECK(cudaOccupancyMaxActiveBlocksPerMultiprocessor(&blocks, block_sum_shuffle, kBlock, dynamic_bytes))，移除未完成标记和过时提示；保留 TODO(2) 与实际 launch 预留 0 字节。更新 PLAN 目录说明、讲义当前行为和 NOTE 的查询/启动区别，保留原预检记录及既有工作区修改。属于 PLAN 阶段 B 的已授权练习补全，无范围偏离。

现场复核 GTX 1650 / CC 7.5 / 14 SM / 4096 MiB、驱动 610.88，NVCC 12.9.86、Compute Sanitizer 2025.2.1.0；API 参数按本机 cuda_runtime.h 核对。正式重编译无警告，固定 N=262144、float32、grid=1024、block=256；查询目标动态预留 0/16384/32768 字节分别返回每 SM 4/3/1 个 block、理论 occupancy 100%/75%/25%。三组全部 1024 个 partial PASS、误差 0、总和 -184；实际预留均为 0，只有 0 字节配置通过，另外两组 INCOMPLETE，check 预期退出 1。三种 Sanitizer 均零工具错误，racecheck 零 warnings；其退出 1 继承练习未完成，不是工具错误。

命令、正式源码 SHA-256、原始输出和退出码见 [query-completed-2026-10-28.txt](../reports/CH11/query-completed-2026-10-28.txt)。本轮 bench、NCU、NSYS、GUI 均 NOT RUN，未创建临时源码或二进制，无新增依赖。Ch11 保持 RUNNING，TODO(1) 实现及验证由 Codex 完成；TODO(2)、个人操作及完整独立解释待验收。计划学习 45～60 分钟，实际学习与工程执行耗时未记录。无需额外 Claude 审阅，未启动 Claude、未提交或推送。


## 2026-10-28：Ch11 dynamic shared 启动 TODO(2) 补全与正式验证

用户明确要求“完成TODO2”。Codex 将 CH11/occupancy.cu 的 launch_bytes 设为 requested_bytes，通过 kernel 第三个启动参数为每 block 预留请求的动态 shared；移除 TODO(2)、无用占位和过时程序提示，添加静态/动态资源分别计入的中文说明。kernel 算法、输入、grid/block 与 occupancy 查询不变。同步更新 PLAN 目录、NOTE 查询/启动说明及讲义当前行为，保留前期骨架和仅补 TODO(1) 的历史记录及既有工作区改动。属于 PLAN 阶段 B 已授权范围，无偏离。

现场复核 GTX 1650 / CC 7.5 / 14 SM / 4096 MiB、驱动 610.88，NVCC 12.9.86、NCU/Compute Sanitizer 2025.2.1.0。固定 N=262144、float32、grid=1024、block=256，正式编译无警告，编译资源每线程 14 个寄存器、32 字节静态 shared、无 spill。三组实际 launch 动态预留为 0/16384/32768 字节、配置均 PASS；API 返回每 SM 4/3/1 个 block、理论 occupancy 100%/75%/25%。每组 1024 个 partial 全部 PASS、误差 0、总和 -184；memcheck（padding=32）、racecheck、synccheck 均零错误，racecheck 零 warnings，check/工具检查/bench 均退出 0。

独立普通 Event bench 为 warmup=10、samples=21、batch=10，三组归一化到每次启动的批次中位数为 29.926401/30.604801/45.705599 μs。区间不含分配、传输、CPU reference/校验与汇总，可能含 host 提交间隙。NCU 单独采正式 check 的三次 launch，确认实际动态 shared 和静态 32 字节；理论 occupancy 与 API 一致，achieved occupancy 为 73.66%/51.41%/19.43%。shared 配置大小为 32768/65536/65536 字节，不假设缓存资源也恒定、不将时间差全部归因于 occupancy，不与历史结果作优化 A/B 或泛化固定性能比例。

命令、正式源码 SHA-256、原始输出、退出码和指标摘要见 [completed-2026-10-28.txt](../reports/CH11/completed-2026-10-28.txt)，报告为 [NCU](../reports/CH11/completed-2026-10-28.ncu-rep)，原始指标为 [CSV](../reports/CH11/completed-metrics-2026-10-28.csv)。本轮 NSYS、GUI、SASS 均 NOT RUN，无临时补全源码或二进制、无新增依赖。Ch11 保持 RUNNING，两处实现及验证均由 Codex 完成，个人操作及对 SM 驻留、静态/动态 shared、理论/实际 occupancy 与计时边界的独立解释待验收。计划学习 45～60 分钟，实际学习与工程执行耗时未记录。无需额外 Claude 审阅，未启动 Claude、未提交或推送。


## 2026-10-28：Ch11 本章总结

按用户“总结本章内容”的要求，在 NOTE 新增 Ch11 汇总，沿用“今日完成任务、基本概念、踩坑记录、八股自测”格式，覆盖 occupancy 查询的输入/输出及错误状态、第三个启动参数与动态预留、静态 32 字节数组的来源、8 warp/block 和本机 32 warp/SM 的区别、资源共同约束下 4/3/1 blocks/SM 的容量推导、正式实验现象与计时边界，以及 NCU 理论/实际 occupancy、活跃周期、跨 SM 聚合和平均值小数。用红色问题标签保留用户真实提问、mark 标记核心结论；不编造用户独立实现、GUI 操作或完整复述。

重读正式源码、completed 日志和原始 NCU CSV，核对 SHA-256 及三组动态预留 0/16384/32768 字节、静态 32 字节、理论 occupancy 100%/75%/25%、平均 active warp 23.570222/16.451688/6.217337 和实测 73.656944%/51.411524%/19.429179%。既有片段和校验均 PASS、误差 0、总和 -184，三种 Sanitizer 零错误、racecheck 零 warnings；普通 Event 中位数为 29.926401/30.604801/45.705599 μs。明确 shared/L1 配置随预留变化、耗时不可全部归因于 occupancy；warp 0 后段合并等只作机制解释，未量化实际贡献，不将教学平均值例子当逐周期实测。

本次只更新 NOTE 与 RECORD，并核对源码哈希、日志/CSV 数值、文档链接与 diff 格式；没有重新编译、运行 GPU、计时、采集 profiler 或操作 GUI，无新增临时产物。Ch11 保持 RUNNING，两处实现与验证均由 Codex 完成，个人操作及完整独立解释仍待验收，不记 DONE。实际学习与工程执行耗时未记录。无计划范围偏离、新依赖或新增课程门槛，无需额外 Claude 审阅，未启动 Claude、未提交或推送，保留已有工作区改动。

## 2026-10-28：Ch12 数据复用内容生成及预检

用户明确要求“生成CH12内容”。按 PLAN 阶段 B 新增 [CH12/tiled_gemm.cu](../CH12/tiled_gemm.cu) 与 [数据复用讲义](chapters/12_data_reuse.md)，更新 PLAN 目录/准备依据及 NOTE 预习入口。一个实验比较 naive 与单层 shared tiled FP32 GEMM，固定主 shape M=N=K=256、block=(16,16)、grid=(16,16)，每线程计算一个输出；A/B/C 各 256 KiB。复用已有错误检查、全量校验与 Event 模式，正式源码保留 shared 装载和乘加两处 TODO，两次 barrier 和尾部填零框架由 Codex 提供。额外 M=37,N=53,K=29 仅用于非整除边界校验，不是第二个性能变量。

现场复核 GTX 1650 / CC 7.5 / 14 SM / warpSize=32 / 4096 MiB、驱动 610.88，NVCC 12.9.86、NCU/Compute Sanitizer 2025.2.1.0，核对 CUDA 12.9 官方矩阵乘法/shared 示例及 NCU 指标口径。正式骨架与只替换 TODO 占位的临时补全版编译均无警告、无 spill；naive 每线程 53 个寄存器、0 shared，tiled 骨架 31 个寄存器、补全版 39 个，两版 tiled 静态 shared 均为 2048 字节。正式骨架 naive 两种 shape 均 PASS，tiled 主 shape 65536 项和尾部 1961 项均 FAIL、最大绝对误差分别 3.4921875/1.3125，check/bench 预期退出 1、bench 拒绝计时。临时补全版四组全量校验 PASS，最大绝对/相对误差均 0、check/bench 退出 0；混合容差 atol=rtol=1e-4，NaN/Inf 拒绝，CPU double reference 独立生成。

两版均运行 memcheck（padding=32）、racecheck、synccheck：均零工具错误，racecheck 零 warnings。骨架继承目标程序退出 1，不能把 Target application returned an error 当成 Sanitizer 发现错误；补全版工具命令均退出 0。独立普通 bench 在正确性通过后仅测主 shape，每法 warmup=10、samples=21、batch=5，naive/tiled Event 批次平均每次启动中位数为 155.961597/106.156802 μs，比值 1.469163。计时不含分配、传输、CPU reference/校验，可能含 host 提交间隙；不与历史/其他 shape 作优化 A/B，不泛化固定收益。

NCU 仅采临时补全版 check 最前面的主 shape 两次 launch，每 kernel 3 passes；global load 请求数为 1048576/65536（naive/tiled），L1/TEX sectors 为 2097152/261594，DRAM 读取 537728/528000 字节。请求减少 16 倍而 DRAM 字节接近，不能把源码读取、合并/缓存后的请求与显存流量混用，也不将加速全部归因于某个因素。NCU 理论 occupancy 均 100%，achieved 为 91.85%/92.86%；NCU 分配后的寄存器为 56/40，与编译报告分别记录。NCU 使用默认 replay/缓存控制，不代表普通预热计时的缓存状态；本章 NCU 为可选观察，不增加必修门槛。

原始命令、两版源码 SHA-256、补全差异、输出及退出码见 [预检日志](../reports/CH12/preflight-2026-10-28.txt)，报告为 [NCU](../reports/CH12/preflight-2026-10-28.ncu-rep)，原始指标为 [CSV](../reports/CH12/preflight-metrics-2026-10-28.csv)。临时补全源码及二进制已清理，正式 build 对应保留两处 TODO 的骨架；正式证据保留。NSYS、GUI、SASS 均 NOT RUN，无新增依赖。

Ch12 记 RUNNING，仅表示骨架与教学预检已开展；用户完成部分尚无证据，两处实现、个人运行、关于输出/装载坐标、shared 复用、两次 barrier、尾部参与和计时边界的独立解释仍待验收。前章状态保留。计划学习 45～60 分钟，实际学习与工程准备/agent 执行耗时未记录；NOTE 仅新增预习入口，不编造用户疑问或掌握。无计划范围偏离，不引入 cuBLAS、Roofline、Tensor Core、多层 tiling 或框架依赖；无需额外 Claude 审阅，未启动 Claude，未提交或推送。

## 2026-10-28：Ch12 TODO(1)/(2) 正式补全与验证

按用户“完成todo1和todo2”的要求，正式补全 [gemm_tiled](../CH12/tiled_gemm.cu)：线程按 A 的 (row,base+tx) 和 B 的 (base+ty,col) 装载到 shared，分别判断两维边界、越界填零；内层逐项累加 a_tile[ty][p]*b_tile[p][tx]。保留两次 block barrier 和最终带边界写出，移除零占位、unused 参数处理及过时提示。更新章节当前状态、NOTE 与 PLAN 目录说明，历史骨架预检及 NCU 证据保留并明确为补全前结果；未改变 naive、shape、输入、block/grid、容差或计时方式。

现场复核 GTX 1650 / CC 7.5 / 14 SM / 4096 MiB、驱动 610.88，NVCC 12.9.86、Compute Sanitizer 2025.2.1.0。正式重编译无警告、无 spill，naive/tiled 每线程寄存器为 53/39，静态 shared 为 0/2048 字节。M=N=K=256 的 65536 项和 M=37,N=53,K=29 的 1961 项，两种方法均全量 PASS、最大绝对/相对误差均 0；memcheck（padding=32）、racecheck、synccheck 均零错误，racecheck 零 warnings。check、工具命令和 bench 全部退出 0。

普通 Event 与 Sanitizer 分开运行；主 shape、float32、block/grid 均 (16,16)，warmup=10、samples=21、batch=5，naive/tiled 中位数为 157.452798/107.673597 μs/次，比值 1.462316。计时不含分配、H2D/D2H、CPU reference/校验，可能含 host 提交间隙；只用于本轮比较，不与历史预检作优化 A/B，不泛化固定收益。本轮 NCU、NSYS、GUI、SASS 均 NOT RUN；历史临时版 NCU 不冒充正式版重新采集结果。原始命令、正式源码 SHA-256、编译资源、结果及退出码见 [正式补全日志](../reports/CH12/completed-2026-10-28.txt)。

两处实现与验证均由 Codex 完成，用户个人运行及对装载/计算坐标、shared 复用、两次 barrier、尾部参与与计时边界的独立解释仍待验收，Ch12 保持 RUNNING，不记 DONE。计划学习 45～60 分钟，实际学习与工程执行耗时未记录。无新增依赖、临时补全文件或计划范围偏离，无需额外 Claude 审阅，未启动 Claude、未提交或推送，保留既有工作区改动。

## 2026-10-28：Ch12 本章总结

按用户“总结本章内容”的要求，整合 NOTE 的 Ch12 阅读入口并新增完整复盘，沿用“今日完成任务、基本概念、踩坑记录、八股自测”格式。覆盖六个实验常量、作用域枚举/名称函数语法、naive 与 tiled 数据流、固定 C 输出 tile、base 沿 K 移动、协作装载与每线程 sum、两次 barrier 和尾部参与、正式数值/计时与历史 NCU 的证据边界，以及 global 请求、缓存和 DRAM 流量的区别。以红色问题标签保留用户实际疑问，用 mark 标注关键理解；记录用户关于 A 向右、B 向下及片段累加的正确主动复述，不将辅助实现或已经讲解等同于独立掌握。

重读正式源码、completed 日志和历史 NCU CSV，核对正式源码 SHA-256 一致。已有正式主 shape 65536 项与尾部 1961 项，两种算法均 PASS、最大绝对/相对误差 0；三种 Sanitizer 零错误、racecheck 零 warnings。正式普通 Event 为 naive/tiled 157.452798/107.673597 μs/次，warmup=10、samples=21、batch=5，比值约 1.462、耗时降低约 31.6%。历史临时版 NCU 请求数 1048576/65536、sectors 2097152/261594、DRAM 537728/528000 字节，L2 容量 1048576 字节；A+B 合计 524288 字节。说明缓存复用与两个 DRAM 读数接近相符，但既不能由容量证明全部命中，也不能将差额 9728 字节解释为确定且稳定的收益。计时、采集版本与指标层次分别记录，不量化未采集的因果贡献，不把 replay 前清缓存误读为 kernel 内禁用缓存。

本次仅更新 NOTE 与 RECORD，核对日志数值、CSV 单位、源码哈希、文档链接和 diff 格式；未重新编译、运行 GPU、计时、采集 profiler 或操作 GUI，无新增临时文件。Ch12 保持 RUNNING，分块累加主线已有用户复述，个人运行及同步、边界、缓存/计时证据的完整独立解释仍待验收。两处实现与工程验证由 Codex 完成，实际学习与工程执行耗时未记录；无计划偏离、新依赖或新增课程门槛，无需额外 Claude 审阅，未启动 Claude、未提交或推送，保留既有工作区改动。


## 2026-10-28：Ch13 Host 异步内容生成与预检

用户明确要求“生成CH13内容”。按 PLAN 阶段 C 新增 [CH13/host_async.cu](../CH13/host_async.cu) 与 [Host 异步讲义](chapters/13_host_async.md)，更新 PLAN 目录/准备依据与 NOTE 预习入口。复用逐元素向量运算，固定 N=65539、float32、block=256、grid=257、每线程累加 2048 次；三个 device 数组各 262156 字节。一个实验只改变计时终点，对照同一次 launch 的 CPU 提交段、CPU 到等待完成边界及同 stream GPU Event。正式源码保留 wait_on_host() 一处 TODO，host、输入、独立 CPU reference、全量校验、预热、计时与安全收尾由 Codex 提供。

现场复核 GTX 1650 / CC 7.5 / 14 SM / 4096 MiB、KMD 610.88、NVCC 12.9.86、Compute Sanitizer 2025.2.1.0、NSYS 2026.4.1，CUDA_LAUNCH_BLOCKING unset；按本机 cuda_runtime_api.h 和 CUDA 12.9 官方同步语义核对 API。正式骨架与仅补等待调用的临时版编译均无警告、无 spill，每线程 10 个寄存器、无 barrier。两版全量 65539 项均 PASS、最大绝对误差 0；输入为 /16 小数，本例所有中间和可精确表示，不推广任意 FP32。两版 memcheck（padding=32、error-exitcode=99）均零工具错误；骨架 check/bench/工具命令退出 1，原因是等待练习占位并拒绝计时，非工具错误。临时补全版 check、工具命令及 bench 均退出 0。

普通 bench 与工具检查、NSYS 分开运行。warmup=3、samples=21、batch=1，另有一次数值预检与完成边界试运行；每个样本起点前等待前序工作，末端后回读校验。CPU launch 段、CPU 到完成边界、GPU Event 三列中位数分别为 15.018000/228.564000/205.311999 μs。CPU launch 段含错误检查，完成边界还含 stop Event 提交与等待开销；start Event 提交位于 CPU 起点之前，Event 可能含 host 提交间隙。三列均不含分配、传输、CPU reference/校验；不将中位数相减当精确等待时间，不将比值称为算法加速或泛化固定耗时。

NSYS 采临时补全版 trace，共 5 次 kernel（数值预检 1、预热 3、测量 1），CLI stats 及 SQLite 关联已核对。最后一次 Correlation ID=141，CPU launch API 10.309 μs、GPU kernel 160.161 μs、后续同步 API 193.057 μs；NSYS 分配后的寄存器为 16，与编译报告 10 分别记录。该 WSL 报告同步返回与 GPU 结束的绝对时间端点约有 8 μs 错位，不据此推断同步提前返回或精确跨轨迹等待时长。未操作 GUI；NCU、racecheck、synccheck 均 NOT RUN，本例无 shared/barrier，不增加额外课程门槛。

原始命令、两版源码 SHA-256、补全差异、输出和退出码见 [预检日志](../reports/CH13/preflight-2026-10-28.txt)，正式证据保留 [NSYS](../reports/CH13/preflight-2026-10-28.nsys-rep)、[SQLite](../reports/CH13/preflight-2026-10-28.sqlite) 与 [时间关联 CSV](../reports/CH13/preflight-timeline-2026-10-28.csv)。临时补全源码和二进制已清理，正式 build 对应保留 TODO 的骨架。完成预检后仅调整一处说明查询边界的源码注释，最终重新编译并确认骨架预期行为；该注释改动不改变实验实现，最终哈希另存日志。

Ch13 记 RUNNING，仅代表课程骨架和教学预检已准备；用户完成部分尚无证据，TODO、个人运行与对提交/完成、错误检查、host/block 同步及 CPU/Event 边界的独立解释待验收。前章状态保留。计划学习 45～60 分钟，实际学习与工程准备/agent 执行耗时未记录。无计划范围偏离、无新依赖，不引入多 stream、pinned memory 或传输重叠；无需额外 Claude 审阅，未启动 Claude、未提交或推送。


## 2026-10-29：Ch13 TODO 正式补全与 measure 计时边界讲解

用户要求“完成TODO，并告诉我当前这个measure是如何测量时间的”。按 PLAN 阶段 C，Codex 在 [wait_on_host()](../CH13/host_async.cu) 返回 cudaDeviceSynchronize() 的状态，移除 TODO、NotReady 占位及对应未完成收尾分支；保留调用方错误检查和额外 stop Event 查询。未改 kernel、N=65539、float32、block=256、grid=257、每线程累加2048次、输入、reference 或计时端点。更新 PLAN 目录、讲义当前行为和 NOTE 的 measure 数据流，保留用户既有工作区修改与历史预检。

现场复核 GTX 1650 / CC 7.5 / 14 SM / 4096 MiB、KMD 610.88，NVCC 12.9.86、Compute Sanitizer 2025.2.1.0，CUDA_LAUNCH_BLOCKING unset；签名及语义按本机头文件和 CUDA 12.9 官方资料核对。正式编译无警告、无 spill，10 个寄存器/线程、无 barrier；全部 65539 项 PASS、最大绝对误差 0，完成边界 PASS；memcheck（padding=32、error-exitcode=99）零错误。check、memcheck、bench 均退出 0。

普通 bench 与工具检查分开，warmup=3、samples=21、batch=1；CPU launch 段 / CPU 到完成边界 / 同 stream GPU Event 三列中位数为 15.950000 / 228.193000 / 203.263998 μs。说明初始清空前序工作的同步和 start Event 的 host 提交位于 CPU 区间外，t_submit 在 launch 与错误检查之后，t_complete 在 stop Event 提交及设备等待之后；GPU Event 记录设备经过两事件之间的时间，查询/读取耗时及 D2H 校验位于 CPU 终点后。两种时钟和端点不同，不必相等；三列中位数分别计算，不将相减当作精确等待时间或用比值宣称算法加速，不与历史预检作性能 A/B。

原始命令、正式源码 SHA-256、编译信息、输出和退出码见 [正式补全日志](../reports/CH13/completed-2026-10-29.txt)。本轮 NSYS、NCU、GUI、racecheck、synccheck 均 NOT RUN；历史临时版 NSYS 不冒充本轮采集，无临时补全文件或新增依赖。Ch13 保持 RUNNING，实现与验证由 Codex 完成，用户个人运行与完整独立解释待验收；计划学习45～60分钟，实际学习与工程执行耗时未记录。无计划偏离，无需额外 Claude 审阅，未启动 Claude、未提交或推送。


## 2026-11-02：Ch13 正式实验重跑、真实结果记录与解读

用户要求“给我真实的实验结果记录，并讲解数据如何体现本章内容”。核对当前 CH13/host_async.cu 与2026-10-29正式日志 SHA-256一致，未修改 CUDA 源码，正式重编译后执行 check、memcheck、独立普通 bench 和 NSYS trace/stats，全部退出0。环境为GTX 1650 / CC7.5 / 14SM / 4096MiB / KMD610.88，NVCC12.9.86、Compute Sanitizer2025.2.1.0、NSYS2026.4.1，CUDA_LAUNCH_BLOCKING unset。shape/dtype为N=65539、float32，block=256、grid=257、每线程2048次累加；编译无警告、无spill、10寄存器/线程。全量65539项正确、最大绝对误差0，完成边界PASS，memcheck（padding=32）零错误。

普通bench为warmup=3、samples=21、batch=1，先校验再测量，另有完成边界试测；CPU launch / CPU到完成 / GPU Event三列中位数为14.818000 / 234.205000 / 209.376007 μs。不包含分配、传输和CPU校验；三列分别取中位数，不相加、不将差额当精确等待，不与历史或profiler数值作性能A/B。

独立NSYS trace共5次kernel，最后一次Correlation ID=141。CPU start Record / launch API / stop Record / sync API分别持续25.679 / 64.132 / 13.516 / 180.693 μs，GPU kernel159.713 μs；该次程序打印host_launch66.326 μs、host_complete261.487 μs、Event250.943989 μs。CPU从start Record调用入口到stop Record返回为119.928 μs，与GPU Event区间不是同一测量。报告中stop Record返回早于GPU kernel结束178.232 μs，而Event仍包含kernel，结合同stream顺序说明“提交stop请求不等于立即记录GPU终点”。Event比纯kernel区间更长，可能包含提交/排队/调度及标记边界间隙，本轮未分解各因素贡献。查询stop返回cudaSuccess；未将CPU Record端点当GPU Event时间戳，也不把跨轨迹微小端点差当精确硬件耗时。

原始命令、环境、源码哈希、输出和退出码见 [本轮实验日志](../reports/CH13/experiment-2026-11-02.txt)，保留 [NSYS](../reports/CH13/experiment-2026-11-02.nsys-rep)、[SQLite](../reports/CH13/experiment-2026-11-02.sqlite) 与 [时间关联CSV](../reports/CH13/experiment-2026-11-02-timeline.csv)。更新讲义的本轮结果、NOTE的提交/执行区别及本页；无CUDA代码修改、新依赖或临时补全文件，GUI/NCU/racecheck/synccheck本轮NOT RUN。Ch13保持RUNNING，实验与记录由Codex完成，用户个人运行及完整独立解释待验收；实际学习与工程执行耗时未记录。无计划偏离，无需额外Claude审阅，未启动Claude、未提交或推送，保留原工作区改动。


## 2026-11-02：Ch13 NSYS GUI 路线及设备 Event 标记补采

用户询问如何通过GUI查看本章几个时间的真实分布。核对默认GUI版本2025.1.3与采集CLI2026.4.1不一致，当前环境没有匹配Linux GUI；未安装升级，也未声称完成GUI交互。按官方文档给出匹配版本要求、File/Open、CPU CUDA API与GPU行、最后一个kernel/correlation141、Events View查找、tooltip端点及Duration的阅读路线。原报告CPU Record区间119.928 μs与kernel159.713 μs可直接核对；原报告未启用设备EventTrace，其250.943989 μs应读当次程序输出。Clock::now的三个时间点未被单独记录，GUI不能逐点精确还原完整host计时。

未改源码，另以 --cuda-event-trace=true 采正式trace，65539项全量PASS、误差0，profile/stats退出0；[新报告](../reports/CH13/events-2026-11-02.nsys-rep)、[日志](../reports/CH13/events-2026-11-02.txt)、[SQLite](../reports/CH13/events-2026-11-02.sqlite)、[标记CSV](../reports/CH13/events-2026-11-02-markers.csv)保留。设备Event表确认start/stop两行，eventId1/2、correlation140/143，时间差170.169 μs；中间kernel correlation141、160.029 μs；程序当次Event171.552002 μs，host_launch/complete15.900/303.307 μs。不同采集不得与原119.928/159.713/250.944或普通bench混算。

这份新报告CPU同步返回与GPU结束时间戳存在95.177 μs反向错位，但同步及查询均成功，说明本次跨轨迹绝对时间对齐不可作为严格完成顺序证据；仅用新报告GPU内部标记/区间教学，不推断同步提前返回，也不追求逐小数位Event读数等同。附明确边界，未追加低收益环境排查。更新讲义、ENVIRONMENT及本页；无新依赖、源码更改或临时尝试产物，无计划偏离，无需额外Claude审阅。Ch13保持RUNNING，个人GUI操作与完整独立解释待验收，实际学习与工程执行耗时未记录；未提交或推送，保留原工作区改动。


## 2026-11-02：Ch13 本章总结

按用户“总结本章内容”的要求，整合NOTE的Ch13阅读入口，并新增“今日完成任务、基本概念、踩坑记录、八股自测”完整复盘。覆盖参数及CUDA_LAUNCH_BLOCKING读取、host异步与同stream顺序、measure的CPU/GPU时间边界、start Record为何放在t0之前、CPU提交stop与GPU实际到达stop的区别、wait_status状态/完成等待、Event查询防护、三种时间的包含/重叠关系、真实数据的分组解释，以及GUI关联高亮、汇总行重复条形和Pin row。以红色问题标签记录用户真实疑问，用mark标出核心结论，不扩展多stream、拷贝重叠或NVTX必修。

重读正式源码及completed-2026-10-29、experiment-2026-11-02、events-2026-11-02日志/CSV，源码SHA-256一致。核对普通bench三列14.818000/234.205000/209.376007μs；原NSYS同一目标样本CPU Record区间119.928μs、GPU kernel159.713μs、程序Event250.943989μs，CPU stop Record自身13.516μs。设备标记补采的170.169/160.029μs及程序Event171.552002μs分别记录，并保留跨轨迹95.177μs反向错位、采集开销和不同运行不得混算的边界。既有全量65539项正确、误差0、完成边界PASS及memcheck零错误未冒充本次重新执行。

将后续新增的用户GUI截图纳入验收证据：用户已打开原实验报告、选中第五次repeated_add，截图显示159.713μs的GPU条形及关联CPU调用；这更新了先前“个人GUI操作待补”的状态。截图不证明个人编译/采集、完成新报告Event标记定位或完整独立解释，实际GUI所在系统和版本也不从截图推定。Ch13仍RUNNING，辅助实现与工具验证由Codex完成，待用户个人程序运行/采集及完整复述；实际学习和本次文档整理耗时未记录。

本次仅更新NOTE与RECORD，验证源码哈希、已有日志/CSV数据、文档链接和diff格式；未修改CUDA源码、重新编译、执行GPU、采集profiler或操作GUI，无新增临时文件。无计划偏离、新依赖或额外课程门槛，无需额外Claude审阅，未启动Claude、未提交或推送，保留已有工作区改动。

## 2026-11-02：Ch14 Stream 内容生成与教学预检

按用户“生成CH14内容”的要求，落实 PLAN 阶段 C 的同/不同 stream 独立双任务对照。新增 [CH14/streams.cu](../CH14/streams.cu) 和 [讲义](chapters/14_streams.md)，更新 PLAN 目录及变更记录、NOTE 阅读入口和本页。复用 Ch13 的逐元素累加，固定每任务 N=4099、float32、grid=17、block=256、每线程 8192 次加法；A/B 分别读写不同的 4099 项片段，只改变第二个 kernel 的目标 stream。两处学习 TODO 分别为创建显式 nonblocking stream 和将传入 stream 用作启动目标，正式源码及 build 保留练习。

骨架提供全量 CPU double reference、NaN 漏写检查、stream 配置/路由检查、安全完成等待，以及 check/bench/trace 模式。计时从第一次 launch 前到两队列均等待完成后，分配、H2D、哨兵准备、D2H 和 CPU 校验在外；不把单队列 Event 当双队列总时长，不引入跨 stream Event、pinned copy 或流水。讲义给出先预测、两处修改、编译与工具命令、NSYS 最后两次 kernel 的定位和独立解释要求。

本轮复核 GTX 1650 / CC 7.5 / 14 SM、concurrentKernels=1、KMD 610.88；设备属性显存约4095 MiB，nvidia-smi显示4096 MiB。NVCC 12.9.86、Compute Sanitizer 2025.2.1.0、NSYS 2026.4.1，CUDA_LAUNCH_BLOCKING unset。正式骨架及临时补全版编译无警告、无 spill，kernel 10 registers/thread、0 barriers。两版 same/split 各8198项全量数值 PASS、最大绝对误差0，memcheck（padding=32）均零错误。正式骨架 check/bench/memcheck 退出1，原因是练习未完成而拒绝实验计时；只补创建、只补路由的两个临时中间态也核验为数值 PASS、路由 INCOMPLETE、退出1。临时完整补全版 check/memcheck/bench/NSYS及导出均退出0。

独立普通 bench：warmup=3、samples=21、batch=1，每样本一对 kernel，host_pair 中位数 same=177.898 μs、split=135.919 μs，包含 host 提交及等待开销，不把差值全部归因于并发。单独 NSYS 采集的两报告各10个kernel；目标为最后两次：same在stream13，Correlation ID=168/170，GPU持续69.276/69.020 μs，交集0，整对GPU跨度144.760 μs；split在stream13/14，Correlation ID=172/174，持续69.823/99.039 μs，交集65.919 μs，整对跨度102.943 μs。仅确认该次GPU区间重叠，不承诺固定加速或每SM的并发分布；不混算profiler与普通bench，不做跨CPU/GPU绝对时间的精确分解。

原始命令、源码哈希、编译和运行输出、退出码及区间摘要见 [预检日志](../reports/CH14/preflight-2026-11-02.txt)。保留 [same NSYS](../reports/CH14/preflight-same-2026-11-02.nsys-rep)、[split NSYS](../reports/CH14/preflight-split-2026-11-02.nsys-rep)、对应SQLite与 [目标区间CSV](../reports/CH14/preflight-2026-11-02-timeline.csv)。报告来自临时完整补全版，未冒充正式TODO骨架；临时完整/中间态源码与可执行文件已清理。GUI、NCU、racecheck、synccheck NOT RUN；沿用ENVIRONMENT中已记录的GUI版本兼容提示，不新增安装任务。

Ch14记RUNNING，仅代表骨架、讲义和教学预检已准备。用户代码完成部分尚无证据，两处TODO、个人运行/采集/读图，以及对同stream顺序、不同stream并发条件、host等待和SM关系的独立解释待验收。计划学习45～60分钟，实际学习与工程准备/agent执行耗时未记录；前章状态保留，无课程范围偏离或新依赖，无需额外Claude审阅，未启动Claude、未提交或推送。

## 2026-11-02：Ch14 两处 TODO 正式补全与验证

按用户明确要求完成TODO1和TODO2。`CH14/streams.cu` 的 `create_work_stream()` 现在通过 `cudaStreamCreateWithFlags(stream, cudaStreamNonBlocking)` 创建队列并返回状态；`launch()` 将传入 stream 用作 target，放入第四个启动参数，并返回实际队列供路由检查。移除源码中的两处TODO、占位与过时注释。未改kernel、shape、输入或计时边界，正式build已重编译。同步更新PLAN目录说明、NOTE阅读入口和讲义，原练习说明与历史临时版预检保留并标明历史状态。

现场GTX1650 / CC7.5 / 14SM、KMD610.88、NVCC12.9.86、Compute Sanitizer2025.2.1.0，CUDA_LAUNCH_BLOCKING unset。正式编译无警告、无spill，kernel仍为10 registers/thread、0 barriers。same/split 的显式nonblocking配置、实际启动路由全部PASS，各8198项全量正确、最大绝对误差0；memcheck（padding=32）零错误。普通bench先校验、预热3次，再收集21个单次pair样本并逐样本回读校验，host_pair中位数same=173.116 μs、split=129.053 μs。所有编译、check、工具检查及bench命令退出0。

命令、正式源码SHA-256和原始输出见 [正式补全日志](../reports/CH14/completed-2026-11-02.txt)，计时口径及结果见 [讲义](chapters/14_streams.md#正式补全与验证2026-11-02)。host_pair包含host提交与等待，不凭耗时证明GPU区间重叠；本轮NSYS、NCU、GUI、racecheck、synccheck均NOT RUN，历史临时版trace未冒充正式版新采集。本轮无临时补全产物、新依赖或计划偏离，无需额外Claude审阅，未启动Claude、未提交或推送。实现与验证由Codex完成，用户个人运行/读图和完整独立解释仍待验收，Ch14保持RUNNING；实际学习及工程执行耗时未记录。

## 2026-11-02：Ch14 本章总结

按用户“总结本章内容”的要求，在NOTE新增Ch14“今日完成任务、基本概念、踩坑记录、八股自测”完整复盘并更新阅读入口。围绕实际问题整理stream队列作用、s0/s1句柄与配置检查、flags查询/返回值、NonBlocking与legacy默认队列隐式同步、第四启动参数、run_pair数据分段/提交/等待/计时/返回值，以及默认队列内存活动和stream0与报告编号的区别。红色标签记录真实提问，mark突出核心结论；两处实现明确为Codex按要求代为完成，未扩展Ch15内容或额外验收门槛。

重读正式源码、completed-2026-11-02日志、历史NSYS目标CSV及split SQLite。正式源码SHA-256与补全日志一致；既有same/split各8198项正确、误差0、memcheck零错误，普通bench host_pair中位数173.116/129.053μs。历史临时版trace目标区间的same交集0、整对跨度144.760μs；split交集65.919μs、跨度102.943μs，始终与正式普通计时分开陈述。已有split报告Memcpy/Memset活动均在streamId7，作为默认队列内存活动的只读核验，未冒充新采集或将它们视为kernel内部每次访存。

纳入用户提供的NSYS GUI截图证据：可见Stream13/14的repeated_add、Default stream7的Memory活动，以及CPU CUDA API中的cudaMemcpy；这更新了个人GUI观察的证据。截图不证明个人编译/运行/采集、报告具体文件或GUI版本，也不证明完整独立解释已经通过。Ch14仍RUNNING，个人运行/采集与对队列顺序、并发条件、等待及默认stream关系的完整复述待验收，掌握度不据此上调。实际学习与本次文档整理耗时未记录。

本次只更新NOTE与RECORD，核对现有证据、官方12.9语义、文档链接与diff格式；未修改CUDA源码、重编译、执行GPU或采集profiler，未新增临时产物。既有工作区改动保留，无计划偏离、新依赖或额外Claude审阅需要，未启动Claude、未提交或推送。

## 2026-11-02：Ch15 Event 与重叠内容生成及教学预检

按用户“生成CH15内容”的要求，落实 PLAN 阶段 C。新增 [CH15/event_pipeline.cu](../CH15/event_pipeline.cu) 与 [讲义](chapters/15_event_pipeline.md)，更新 PLAN 目录/变更记录、NOTE 阅读入口及本页。固定 8 个独立数据块、每块 N=262147、float32、block=256、grid=1025，每项加 256 次 0.125；两个 device 槽位交替处理，upload stream 做 H2D，compute stream 做 kernel 和 D2H。两种调度仅改变每块结束是否额外让 CPU 等待 done，保留块内 H2D→kernel→D2H 依赖，不扩展为三阶段完全并发流水。

Codex 提供 pinned host 缓冲、双缓冲分配与生命周期、Event 记录、全量 CPU double reference、NaN 哨兵、check/bench/trace 模式、计时与清理。正式源码保留 compute 等 ready、upload 等旧 done 两处 TODO；未补时使用安全的 CPU 等待占位，仍可检查数值，但返回未完成状态并拒绝计时。讲义从块 0～2 和具体线程说明跨 stream 接力、同槽覆盖保护、Event 重录及 pinned memory 条件，限定 45～60 分钟；未批量生成后章或将预检记作用户掌握。

现场复核 GTX 1650 / CC7.5 / 14SM、asyncEngineCount=2、concurrentKernels=1、KMD610.88、NVCC12.9.86、Compute Sanitizer2025.2.1.0、NSYS2026.4.1，CUDA_LAUNCH_BLOCKING unset。正式骨架及临时补全版编译无警告、无 spill，ptxas 报告 kernel 为8 registers/thread、0 barriers。两版 serial/pipeline 各全量检查2097176项，数值PASS、最大绝对误差0；memcheck（padding=32）均零错误。正式骨架 check/bench/memcheck 退出1，这是两处练习保留导致的预期应用状态，非工具检出内存错误。临时补全版只将两个 helper 改为检查 cudaStreamWaitEvent(target,event,0) 并返回true，check/memcheck/bench/两份NSYS采集及导出均退出0。

临时版独立普通 bench：warmup=3、samples=21、每样本8块，host_batch 中位数 serial=4481.916μs、pipeline=2990.141μs。范围从本批首次提交前到两条队列均完成后，含H2D、kernel、D2H、Event操作及host提交/等待；分配、输入、哨兵和CPU校验在外。该差值不全部归因于设备端重叠，不与profiler时间混算。两份NSYS各40次kernel、40次H2D、40次D2H，目标为各类最后8次；upload/compute的stream ID为13/14。串行的下一块H2D与当前kernel交集为0，流水7对均有交集、总和632.193μs；目标GPU整批跨度分别4743.324/3654.726μs。所有块内先后和6次槽位复用端点检查通过。两份trace各70次StreamWaitEvent，额外CPU EventSynchronize次数为serial40、pipeline0，符合唯一开关。仅确认本次trace实际重叠，不承诺每次或所有GPU都加速。

命令、源码SHA-256、编译/运行原始输出、退出码和区间摘要见 [预检日志](../reports/CH15/preflight-2026-11-02.txt)，保留 [serial NSYS](../reports/CH15/preflight-serial-2026-11-02.nsys-rep)、[pipeline NSYS](../reports/CH15/preflight-pipeline-2026-11-02.nsys-rep)、对应SQLite和 [目标区间CSV](../reports/CH15/preflight-2026-11-02-timeline.csv)。nsys stats读取rep时因已有SQLite时间戳检查退出1，改为直接读取导出的SQLite后成功、退出0；未覆盖证据。profiler与性能数据均来自临时补全版，正式源码/build保留练习。临时源码、可执行文件与路径指示文件已清理，GUI、NCU、racecheck、synccheck NOT RUN；memcheck零错误不冒充跨stream竞争证明。

Ch15保持RUNNING，用户代码完成部分尚无证据，两处补全、个人运行/读图及独立解释待验收；前章状态不变。实际学习和工程准备/agent执行耗时未记录，无新依赖、计划偏离或额外Claude审阅需要，未启动Claude、未提交或推送。

## 2026-11-03：Ch15 两处 TODO 正式补全与验证

按用户“完成TODO1和TODO2”的明确要求，修改 [CH15/event_pipeline.cu](../CH15/event_pipeline.cu)：`wait_for_input()` 检查 `cudaStreamWaitEvent(compute, ready, 0)`，`wait_for_slot()` 检查 `cudaStreamWaitEvent(upload, done, 0)`，均在成功后返回 true。移除两处源码 TODO 和 CPU 等待占位，补充中文依赖注释；保留 serial 每块结束后的额外 CPU 等待和整批最终等待，kernel、shape、双缓冲和计时范围不变。同步更新 PLAN 目录说明、NOTE 阅读入口、讲义和本页；历史生成预检保留并与当前状态区分。

现场复核 GTX1650 / CC7.5 / 14SM、asyncEngineCount=2、concurrentKernels=1、KMD610.88、NVCC12.9.86、Compute Sanitizer2025.2.1.0，CUDA_LAUNCH_BLOCKING unset。正式源码重编译无警告、无 spill，ptxas 为8 registers/thread、0 barriers。serial/pipeline 的设备等待完成状态及各2097176项全量数值检查全部PASS，最大绝对误差0；memcheck（padding=32）零错误。编译、check、memcheck、bench命令均退出0，正式build已对应补全后的源码。

普通bench先校验、预热3批，再测21批并逐批在计时外校验，每批8块，host_batch中位数serial=4410.856μs、pipeline=2938.147μs。时间包含H2D、kernel、D2H、Event操作和host提交/等待，不当作单kernel GPU时间，不凭耗时单独证明重叠，也不把与历史临时版的差异解释成性能A/B。原始命令、正式源码SHA-256、输出和退出码见 [正式补全日志](../reports/CH15/completed-2026-11-03.txt)。本轮NSYS、NCU、GUI、racecheck、synccheck均NOT RUN，历史临时版NSYS不冒充正式版新采集；memcheck不替代跨stream依赖语义检查。

两处实现及验证由Codex完成，个人运行/读图与完整独立解释待验收，Ch15仍RUNNING，掌握度未据此提高。实际学习及工程执行耗时未记录，无新增临时实现文件、新依赖、计划偏离或额外Claude审阅需要，未启动Claude、未提交或推送，保留既有工作区改动。

## 2026-11-05：Ch15 正式实验、流水时间线与证据解释

按用户要求提供实际实验结果，并解释结果如何体现本章流水模式。本次使用当前正式源码，SHA-256仍为f0621f86436a9fe2f93b06583e08f376022d63a24cdcffa753fd686f8ce57d10，与11月3日补全版一致；重新编译无警告、无spill，ptxas为8 registers/thread、0 barriers。现场GTX1650 / CC7.5 / 14SM、asyncEngineCount=2、concurrentKernels=1、KMD610.88、NVCC12.9.86、NSYS2026.4.1，CUDA_LAUNCH_BLOCKING unset；固定8块、每块262147个float32、两个slot、block256、grid1025、每项256次加法、单次拷贝1048588字节。两种调度各2097176项全量数值PASS、最大绝对误差0，普通bench先校验、预热3批、测21批并逐批校验，host_batch中位数serial=4473.431μs、pipeline=3000.325μs；本轮耗时减少32.930%，耗时比1.491。该范围含提交、H2D/kernel/D2H、Event操作及完成等待，哨兵、分配和CPU校验在外。

普通bench之外，分别采集当前正式build的serial/pipeline NSYS，各40次kernel、40次H2D、40次D2H，提取各类最后8次对应目标批次。上传stream13、计算及D2H stream14；serial中7对“下一块H2D/当前块kernel”均无交集，pipeline中7对均有交集，依次87.617/78.336/91.296/91.744/91.201/91.265/85.601μs，合计617.060μs。GPU目标整批跨度分别4635.592/3097.683μs，属于独立profiler运行，不与普通bench时间混算。

各报告分别以目标批次第一个H2D开始为零：pipeline的kernel0区间234.145～326.082μs（Correlation416），H2D1区间161.761～321.762μs（Correlation420），交集87.617μs，直接显示slot0计算与slot1上传同时推进。serial的kernel0区间202.783～292.574μs，H2D1区间554.717～714.556μs，无交集。pipeline的旧D2H0结束543.843μs，新H2D2开始610.372μs；两模式全部8块均满足H2D结束≤kernel开始、kernel结束≤D2H开始，6次同槽复用均满足旧D2H结束≤新H2D开始。端点观察与源码ready/done链相符，不把单次图当成完整同步证明，也不把重叠区间合计等同整批耗时节省。

两份完整trace各70次cudaStreamWaitEvent，serial额外40次cudaEventSynchronize、pipeline为0，符合逐块CPU等待开关；kernel和D2H始终在同一compute队列，未宣称多个kernel并发。结合用户本轮问题，讲义与NOTE区分了固定两条全程复用的stream、两套存储地址slot、同chunk的ready接力，以及跨chunk同slot复用的done保护。

正式命令、版本、源码哈希、编译/运行/采集/导出输出及退出码见 [实验日志](../reports/CH15/experiment-2026-11-05.txt)。保留 [serial报告](../reports/CH15/experiment-serial-2026-11-05.nsys-rep)、[pipeline报告](../reports/CH15/experiment-pipeline-2026-11-05.nsys-rep)、对应SQLite、[目标区间CSV](../reports/CH15/experiment-2026-11-05-timeline.csv)、[摘要JSON](../reports/CH15/experiment-2026-11-05-summary.json)、[提取绘图脚本](../reports/CH15/experiment-2026-11-05-analysis.py) 和 [实际时间线PNG](../reports/CH15/experiment-2026-11-05-timeline.png)/同名SVG。图形矩形来自原始GPU端点，两个报告分别归零，非示意比例图。所有本轮运行/采集/导出命令退出0；未改CUDA源码、未覆盖历史报告，无无效临时文件、新依赖或计划偏离，无额外Claude审阅需要。GUI、NCU、memcheck、racecheck、synccheck本轮NOT RUN；11月3日同哈希源码memcheck零错误保持为既有证据。

实验及图形由Codex执行和生成，不计用户独立操作或掌握；用户对连续提交及槽位复用已有部分复述，CPU/GPU等待、stream与slot、ready与done交接已进一步讲解，完整独立解释仍待验收。Ch15保持RUNNING，实际学习与工程执行耗时未记录，未启动Claude、未提交或推送。

## 2026-11-05：Ch15 今日学习总结

按用户“总结今天的本章内容”的要求，更新NOTE的Ch15阅读入口，并新增“今日完成任务、基本概念、踩坑记录、八股自测”完整复盘。覆盖运行模式与配置、chunk/slot/block的区别、host指针偏移、两个全程共用的stream、NaN哨兵、pinned memory与异步拷贝、CPU/设备等待、Event与start/stop/ready/done命名、两处helper、run_batch逻辑及唯一串行开关、同stream的kernel→D2H顺序、device_waits教学返回值。红色问题标签保留用户真实提问，mark突出关键结论，不扩展后章或新必修内容。

对照当前正式源码及11月3日补全日志、今日实验日志/摘要JSON/目标CSV核对数据：源码SHA-256一致，今日普通host_batch中位数4473.431/3000.325μs，耗时降低32.930%；NSYS目标GPU跨度4635.592/3097.683μs，串行0/7和流水7/7上传/计算交集，流水交集总和617.060μs。kernel0与H2D1交集87.617μs，D2H0结束543.843μs、新H2D2开始610.372μs，分别说明不同slot重叠与同slot复用保护。保留普通计时、profiler和既有memcheck的证据边界，未把这些历史执行冒充本次文档整理时重新运行。

明确对照PNG是Codex用Matplotlib从NSYS SQLite原始GPU区间重绘：位置/宽度来自实测，颜色、chunk标签和布局由脚本添加，不是NSYS GUI截图。用户已部分复述连续提交与chunk2复用slot0的过程，并查看/询问重绘图，但没有据此认定个人编译、采集、NSYS GUI交互或完整独立解释通过。两处实现和实验执行均由Codex完成，Ch15仍RUNNING，掌握度未上调；实际学习与文档整理耗时未记录。

本次仅修改NOTE与RECORD，核对源码哈希、既有日志/JSON/CSV的数值与端点、文档链接及diff格式；未修改CUDA源码、重新编译、执行GPU或重新采集profiler，没有新增临时文件。无计划偏离、新依赖或额外Claude审阅需要，未启动Claude、未提交或推送，保留既有工作区改动。

## 2026-11-05：Ch16 Graph 内容生成与教学预检

按用户“生成CH16内容”的要求，落实PLAN阶段C。新增 [CH16/graph_replay.cu](../CH16/graph_replay.cu) 与 [Graph讲义](chapters/16_graph_replay.md)，同步PLAN目录/变更记录及NOTE预习入口。固定N=4099、float32、block256、grid17，四个device数组各16396字节；单stream依次执行add_one→scale_two→subtract_half，每批重复64条链，始终从同一input开始。唯一变量为逐kernel普通启动或固定链的Graph replay，输入、计算、地址与依赖不变。

Codex提供三个kernel、host生命周期、独立CPU double reference、NaN哨兵、全量校验、check/bench/trace模式及三种计时边界。正式源码保留capture/实例化和replay两处TODO；未补时Graph安全回退到direct，但明确标记未完成并拒绝该路径计时。讲义沿thread3解释数据流，限定45～60分钟，包含预测、两个API练习、命令、capture合法性、固定地址生命周期、NSYS node trace和验收，不扩展跨stream capture、图更新或框架工程。按本机12.9头文件及NVIDIA12.9.1官方文档核对API签名和语义，按现场nsys help核对node参数。

现场GTX1650 / CC7.5 / 14SM、Runtime12090、DriverAPI13030、KMD610.88、NVCC12.9.86、Compute Sanitizer2025.2.1.0、NSYS2026.4.1，CUDA_LAUNCH_BLOCKING unset。正式骨架及临时补全版均编译无警告、无spill，ptxas报告三个kernel各10 registers/thread、0 barriers。两版两路径各全量检查4099项，数值PASS、最大绝对误差0；memcheck（padding32）均零错误。正式骨架check both、bench graph及memcheck退出1是TODO未完成的预期应用状态，check direct退出0；临时版capture/实例化检查三个kernel节点通过，check/memcheck/bench/NSYS采集、导出与stats均退出0。

临时版只补两个helper，具体实现及源码哈希保存在日志。独立普通bench各预热3批、测21批，每批64条链：host_submit中位数direct2190.224μs、graph1002.935μs，host_complete为2388.791/1049.644μs，Event span为2347.872/1015.904μs。submit含提交循环及错误检查，complete已包含submit并加stop Event提交和完成等待；Event覆盖同stream整批并包含间隙，不能相加或相减冒充单kernel/精确等待开销。分配、上传、capture/实例化、哨兵、回读及CPU校验均在外，没有测一次性建图成本回本次数，也不作普遍加速承诺。

另外两次NSYS采集显式使用--cuda-graph-trace=node。各完整trace963次GPU kernel，取最后192次为目标批次，三种kernel各64次、顺序符合链、stream ID13，GPU端点无前后交叠。目标direct192次cudaLaunchKernel_v7000各关联1个kernel；graph64次cudaGraphLaunch_v10000各关联3个kernel，证明本次减少提交但未融合kernel。完整graph trace320次Graph launch和6次普通launch，后者包含预热及capture时host调用，不等于6次额外GPU执行。graph目标首链三个GPU区间为0～1.728、2.048～3.776、4.064～5.824μs，均关联Correlation453，直接展示一次Graph API对应多个GPU活动。

目标GPU跨度direct7712.763μs、graph824.593μs；链内128个间隙中位数6.032/0.320μs，链间63个间隙中位数6.848/2.528μs。这些来自独立profiler运行，不与普通bench混算，不把单次间隙或长尾差值全部归因于某个硬件机制。全量数值只核对每批最终输出，实际执行次数由trace另证；memcheck零错误也不替代Graph依赖语义检查。

完整命令、正式/临时源码SHA-256、编译/运行输出、退出码及helper替换内容见 [预检日志](../reports/CH16/preflight-2026-11-05.txt)。保留 [direct报告](../reports/CH16/preflight-direct-2026-11-05.nsys-rep)、[graph报告](../reports/CH16/preflight-graph-2026-11-05.nsys-rep)、对应SQLite、[目标CSV](../reports/CH16/preflight-2026-11-05-timeline.csv)、[摘要JSON](../reports/CH16/preflight-2026-11-05-summary.json) 与 [提取脚本](../reports/CH16/preflight-2026-11-05-analysis.py)。性能和Graph trace仅来自临时补全版；临时源码与可执行文件已清理，正式源码/build保留两处TODO。GUI、NCU、racecheck、synccheck均NOT RUN。

Ch16保持RUNNING，辅助程度为Codex骨架、讲义与教学预检；用户本次提出生成需求，尚无两处实现、个人运行/读图或独立解释的验收证据，前章状态不变。实际学习与工程准备/agent执行耗时未记录。无新依赖、计划偏离或额外Claude审阅需要，未启动Claude、未提交或推送Git。

## 2026-11-06：Ch16 两处 TODO 正式补全与验证

按用户“完成TODO1和TODO2”的要求，Codex修改 [CH16/graph_replay.cu](../CH16/graph_replay.cu)：capture_chain在传入stream开启Global capture，调用launch_chain录入一条链，结束capture得到graph并实例化到exec；replay_chain调用cudaGraphLaunch(exec,stream)。各API均检查状态、成功后返回true；移除两处TODO与占位，补充中文语义注释，保留路径检查和安全回退。kernel、输入、shape、固定地址、reference、预热/样本数及计时边界均不变。同步PLAN目录、NOTE入口、讲义当前行为和本页，生成预检及原始练习路线保留并标明历史状态，保留既有工作区改动。

现场GTX1650 / CC7.5 / 14SM、Runtime12090、DriverAPI13030、KMD610.88、NVCC12.9.86、Compute Sanitizer2025.2.1.0，CUDA_LAUNCH_BLOCKING unset。正式build重编译无警告、无spill，ptxas报告三个kernel各10 registers/thread、0 barriers。捕获检查3个kernel节点通过，direct/graph各4099项全量数值PASS、最大绝对误差0，graph使用实际graph_replay路径；memcheck（padding32）零错误。编译、check、memcheck、bench均退出0。

独立普通bench每种方式预热3批、测21批，每批64条链：host_submit中位数direct1158.311μs、graph359.904μs，host_complete1534.156/627.443μs，Event span1497.024/595.744μs。保留三种计时的不同边界，不相加或直接相减，不与历史预检组成性能A/B；分配、上传、capture/实例化、哨兵及回读校验在计时外。命令、正式源码SHA-256、环境、编译/运行原始输出及退出码见 [正式补全日志](../reports/CH16/completed-2026-11-06.txt)。本轮NSYS、NCU、GUI、racecheck、synccheck均NOT RUN，历史临时版NSYS不冒充正式版新采集，memcheck零错误不替代Graph依赖语义核查。

两处实现和验证均由Codex完成，个人运行/读图及完整独立解释仍待验收，Ch16保持RUNNING，掌握度未据此提高。实际学习与工程执行耗时未记录。无新增临时实现文件、新依赖、计划偏离或额外Claude审阅需要，未启动Claude、未提交或推送Git。

## 2026-11-09：Ch16 正式NSYS间隙对照与GUI阅读路线

按用户“能不能在NSYS里面直观对比出两种模式kernel间隙开销”的要求，使用当前正式源码重新编译、check并分别采集direct/graph，不改CUDA源码。SHA-256为0040ef8165bd4f30848c55590ace7db577c3eaf664fc0e29b51925cc1d761a42，与11月6日正式补全版一致。现场GTX1650 / CC7.5 / 14SM、Runtime12090、DriverAPI13030、NVCC12.9.86、NSYS CLI2026.4.1，CUDA_LAUNCH_BLOCKING unset。编译无警告、无spill，三个kernel各10 registers/thread、0 barriers，check两路径各4099项全量正确、最大误差0；编译/check/两次采集及SQLite导出/stats均退出0。

采集显式使用--cuda-graph-trace=node，以展示Graph内部kernel活动。各报告963个GPU kernel，取最后192个为目标，三种阶段各64次、顺序A→B→C、stream ID13；direct目标192次cudaLaunchKernel_v7000各关联1个kernel，graph目标64次cudaGraphLaunch_v10000各关联3个kernel。两份目标GPU时间窗均无memcpy/memset活动，不能将其中空档解释为数组H2D传输。

目标GPU整批跨度direct1365.216μs、graph751.394μs，kernel自身耗时合计330.048/332.736μs，191个相邻空档合计1035.168/418.658μs；链内128个间隙中位数2.016/0.320μs，链间63个间隙中位数1.920/2.144μs。Graph链内衔接更紧，仍保留链间空档，不能声称所有间隙降低或消失。各报告按目标首kernel归零，首链direct的A区间0～1.760μs、B为4.000～5.696μs，首空档2.240μs；graph的A为0～1.728μs、B为2.048～3.744μs，首空档0.320μs。graph首链三个节点均关联Correlation453，direct首链为1719/1721/1723。

新增Python/Matplotlib实测对照图，含整批192个kernel与前3条链9个kernel两个面板，每面板两行共用刻度，矩形起止与宽度取自SQLiteGPU端点、每份报告独立归零。图为重绘而非NSYS GUI截图；灰色只表示目标stream的kernel间隙，不证明整卡空闲，不将GPU间隙全归于CPU/Driver某项开销，也不与11月6日普通bench混算。本轮未新跑普通bench或Compute Sanitizer，NCU/racecheck/synccheck NOT RUN。

讲义新增原始报告链接、目标定位、GPU End/Start相减、CPU/API与CUDA HW区分、关联检查及版本说明，NOTE新增概念入口，当前进度仍RUNNING。现场nsys-ui --version退出0，默认GUI仍2025.1.3.140并打印WSL/OpenGL回退提示；本轮未启动交互GUI、安装或升级GUI，读新报告需匹配2026.4.1或更新GUI。工具用法核对现场help与NVIDIA官方User Guide。

完整命令、版本、源码哈希与输出见 [实验日志](../reports/CH16/experiment-2026-11-09.txt)。保留 [direct报告](../reports/CH16/experiment-direct-2026-11-09.nsys-rep)、[graph报告](../reports/CH16/experiment-graph-2026-11-09.nsys-rep)、对应SQLite、[目标CSV](../reports/CH16/experiment-2026-11-09-timeline.csv)、[摘要JSON](../reports/CH16/experiment-2026-11-09-summary.json)、[提取绘图脚本](../reports/CH16/experiment-2026-11-09-analysis.py)、[PNG](../reports/CH16/experiment-2026-11-09-timeline.png)及同名SVG，原有历史报告未覆盖。无无效临时实现文件、新依赖或计划偏离，无额外Claude审阅需要，未启动Claude、未提交或推送。所有采集/绘图由Codex完成，个人运行/读图与独立解释待验收，实际学习及工程执行耗时未记录。

## 2026-11-09：Ch16 本章总结

按用户“总结本章内容”的要求，更新NOTE的Ch16阅读入口，新增“今日完成任务、基本概念、踩坑记录、八股自测”完整复盘，串联11月5日生成、11月6日正式补全和11月9日正式NSYS实验。内容覆盖三阶段链/参数与数组复用、capture/实例化/replay、helper成功与完成边界、指针变量地址与显存地址、cudaMalloc输出参数、Graph句柄类型别名及nullptr、两次节点查询、CPU vector与节点类型布尔累积、host提交与GPU执行、间隙/H2D区别，以及普通计时和NSYS读图。用户真实问题用红色标签、关键结论用mark，未编造个人实现或调试经历。

核对当前源码SHA-256与两份正式日志一致：11月6日普通host_submit中位数1158.311/359.904μs，host_complete1534.156/627.443μs、耗时比约2.45及减少59.1%，Event span1497.024/595.744μs；全量正确与memcheck零错误为已有验证。11月9日NSYS目标两路径各192个kernel、主计算API192/64次、kernel耗时合计330.048/332.736μs，链内间隙中位数2.016/0.320μs、链间1.920/2.144μs，目标窗口memcpy/memset均0。保留普通bench、独立trace与历史临时预检的边界，未将三类数据混算。

总结强调Graph保留192次GPU计算及依赖、缩减提交并改善本例链内衔接，仍有链间间隙，单次空档不能精确归因CPU/Driver。重绘图为NSYS原始GPU端点经SQLite与Matplotlib生成，非GUI截图；同面板刻度一致、各报告独立归零，灰色不证明整卡空闲。已有原始报告、目标CSV、摘要JSON和讲义链接均保留。

用户多次要求逐行解释，并对&b.input第一次解释明确表示没明白，后用具体假设地址重讲；这些记录为真实理解难点，未等同个人独立掌握。代码补全、工具执行和绘图由Codex完成，尚无个人运行/采集/GUI操作或完整独立解释的验收证据，Ch16保持RUNNING，掌握度未上调。实际学习及文档整理耗时未记录。

本次只修改NOTE与RECORD，核对当前源码、已有日志/JSON/CSV、数值、文档链接与diff格式，未修改CUDA源码、编译、运行GPU或重新采集profiler，未新增临时文件。无新依赖、计划偏离或额外Claude审阅需要，未启动Claude、未提交或推送Git，保留既有工作区改动。

## 2026-11-09：Ch17 编译产物骨架、讲义与预检

按用户“生成CH17内容”的要求，对应 PLAN 阶段D，仅准备 Ch17，不生成 Ch18/19。新增 `CH17/vector_add.cu`、`CH17/compile.sh` 和 [本章讲义](chapters/17_compilation_artifacts.md)，同步 PLAN 目录/变更记录及 NOTE 预习入口。复用 Ch02 的向量加法思路，host 输入/CPU double reference/全量校验与错误检查完整提供；主要变量是同源代码的编译输出阶段。正式脚本保留生成 PTX 与 cubin 的两处命令 TODO，已提供的 Runtime 分支显式嵌入 sm_75 cubin 和 compute_75 PTX。以 `extern "C"` 固定入口 vector_add，参数依次为 a/b/c/n，练习应生成 `build/CH17/vector_add.cubin` 供 Ch18 使用。没有新增依赖、计时实验或 JIT 缓存/SASS 优化内容。

现场核验 GTX1650 / CC7.5 / 14SM、KMD610.88、Runtime12090、DriverAPI13030，NVCC12.9.86、cuobjdump12.9.82、nvdisasm12.9.88、Compute Sanitizer2025.2.1.0，CUDA_LAUNCH_BLOCKING unset。正式 Runtime 构建无警告；n=1000、float32、每数组4000字节、grid8/block128，全量 mismatches=0、最大绝对误差0，memcheck padding32 零错误，均退出0。ptxas 为12 registers/thread、0 barriers、0 stack/spill；本章不据此推断性能。正式 Bash 语法通过，ptx/cubin 两个占位分支按预期提示 TODO 并退出2，非法模式与多余参数也退出2。

Codex 临时仅补两条命令、将产物隔离到 `build/CH17/preflight/`；PTX/cubin 生成退出0，PTX 为1334字节，含 `.version 8.8`、`.target sm_75`、`.address_size 64`、`.visible .entry vector_add`，参数为3×u64与1×u32。cubin 为4456字节的NVIDIA CUDA ELF，cuobjdump符号/SASS与nvdisasm均找到 vector_add、目标sm_75；独立 cubin 的ptxas资源与Runtime一致。Runtime可执行文件内嵌的PTX/SASS均能提取。临时补全脚本已删除，正式源码保留两处练习；保留预检产物用于复盘，不替代用户应生成的正式路径。

完整命令、正式源码哈希、临时补全内容、版本、原始输出、退出码和产物哈希见 [预检日志](../reports/CH17/preflight-2026-11-09.txt)，同目录保存 cubin SASS/符号/nvdisasm 与 Runtime PTX/SASS。Runtime 校验只证明对应可执行文件内的代码，外部PTX/cubin加载执行 NOT RUN，留待 Ch18；NSYS/NCU/性能计时/racecheck/synccheck 均 NOT RUN，本例无shared协作或barrier，不新增相关要求。官方语义查CUDA12.9.1 NVCC/Programming Guide/Binary Utilities，选项同时核对现场help；无计划偏离或额外Claude审阅需要，未启动Claude、未提交或推送Git。

本次内容生成与验证全部由Codex完成，尚无用户填写命令、个人运行/查看或独立解释的验收证据。Ch17记RUNNING、掌握度未评估；Ch00～16的原状态不变。计划学习用时45～60分钟，实际学习与工程执行耗时均未记录。遗留为两处命令练习及本章个人验收。

## 2026-11-09：Ch17 两处编译命令补全与Bash脚本阅读

按用户“完成TODO1和TODO2，以及这种.sh文件以后拿到怎么看其实现的功能”的要求，Codex直接补全 `CH17/compile.sh` 的PTX/cubin分支，移除提示与退出2占位。前者使用 `--ptx --gpu-architecture=compute_75`，后者使用 `--cubin --gpu-architecture=sm_75 -Xptxas=-v,-warn-spills`；同一源码及flags不变，正式输出在build/CH17。新增用法与只编译的注释，Runtime构建命令和CUDA源码未改。同步PLAN目录、NOTE入口和讲义当前状态，保留生成时预检历史，讲义新增正式验证记录。无计划偏离、新依赖或额外Claude审阅需要。

现场GTX1650 / CC7.5 / 14SM、KMD610.88、Runtime12090、DriverAPI13030、NVCC12.9.86、Bash5.2.21、Compute Sanitizer2025.2.1.0，CUDA_LAUNCH_BLOCKING unset。脚本语法、默认Runtime/PTX/cubin构建均退出0；从/tmp通过绝对路径调用cubin成功，非法模式和多余参数按预期退出2。编译无警告，ptxas为12 registers/thread、0 barriers、0 stack/spill。重编译Runtime全量1000项正确、最大误差0、memcheck padding32零错误。正式PTX1334字节、cubin4456字节，与生成时预检的对应device产物哈希相同；PTX含version8.8/targetsm_75/entryvector_add，cubin符号/SASS确认vector_add及sm_75，Runtime嵌入PTX提取成功。外部模块加载执行仍NOT RUN，不新增Driver实现或profiler/性能实验。

NOTE记录用户的真实脚本阅读问题，按命令→输入/变量→分支→工作目录/输出解释nvcc编译脚本，涵盖Bash解释器、`$1`/`$#`、默认值、数组展开、续行、case和错误检查；区分 `bash -n` 语法检查与 `bash -x` 显示并实际执行命令。执行跟踪已实测ptx分支，退出0。GNU Bash手册分页面首次获取超时，随后使用同一官方手册的可访问版本及本机Bash信息核对，没有因页面超时改变实现。

完整证据见 [正式日志](../reports/CH17/completed-2026-11-09.txt)，同目录保存正式cubin SASS/符号、Runtime PTX和 [Bash跟踪](../reports/CH17/completed-shell-trace-2026-11-09.txt)。本轮无临时实现文件、未删除历史证据，未启动Claude、未提交或推送Git。两处命令实现、编译和验证均由Codex完成，个人运行/产物查看与独立解释待验收；Ch17保持RUNNING，掌握度未上调，实际学习及工程执行耗时未记录。

## 2026-11-09：Ch17 本章总结与产物查看证据

按用户“总结本章内容”的要求，更新NOTE的Ch17阅读入口，并在页末新增“今日完成任务、基本概念、踩坑记录、八股自测”总结。覆盖本章真实问题：extern "C"与入口名称、Bash脚本执行流程、源码/PTX/cubin/SASS/普通可执行文件关系、PTX作为IR的用途与兼容边界、逐线程索引及字节地址、64位地址与32位float、虚拟寄存器名称与ld/st方括号、cubin查看工具、nvdisasm调试/资源/参数/代码区域，以及Ch18加载流程的概念连接。用户问题用红色标签、关键理解用mark，不记录为用户已经独立掌握或独立完成TODO。

重读当前compile.sh、vector_add.cu、PTX和正式日志，核对两份源码及PTX/cubin/Runtime可执行文件SHA-256均与11月9日正式日志一致。已有验证为三种构建成功，Runtime n1000/float32/grid8/block128全量mismatches0、最大误差0、memcheck padding32零错误，ptxas12 registers/thread、0 barriers、0 stack/spill，PTX1334字节、cubin4456字节；本次只核对既有证据，没有重编译、运行GPU或重新采集profiler。没有把资源数、文件大小或SASS指令数量当成性能结论。

用户已提供 `nvdisasm build/CH17/vector_add.cubin` 命令及323行完整输出，原文原样保存为 [用户nvdisasm证据](../reports/CH17/user-nvdisasm-2026-11-09.txt)（17823字节），与附件逐字节核对一致；没有覆盖或修改原附件。该输出作为产物查看证据，不能替代用户编译、Runtime数值运行或完整独立解释。重读原文确认SHI_REGISTERS12、参数区起点0x160/大小0x1c、constant0大小380和实际LDG/FADD/STG；解码.nv_debug_ptx_txt确认保留PTX文本，说明它是调试信息而非从机器码逆向恢复，也不泛化到所有cubin。

此前讲解中Codex已只读运行cuobjdump和nvdisasm -c -g，确认当前cubin的vector_add/sm_75及源码21～24行关联，并提取普通可执行文件中的PTX。Ch18仅解释cuInit/device/primary context/current/module/function/launch流程，未生成章节、实际加载外部模块或进行Driver启动；外部PTX/cubin加载执行继续记NOT RUN。PTX/SASS后缀、ELF内部字段、JIT缓存和跨架构实验不增加为本章门槛。

本次只修改NOTE与RECORD并持久保存用户原始查看输出，核对文档链接、证据哈希及diff格式，未修改CUDA源码/编译脚本，没有临时尝试文件、新依赖、计划偏离或额外Claude审阅需要，未启动Claude、未提交或推送Git。当前Ch17保持RUNNING，掌握度未评估；个人产物查看已有输出，个人编译/Runtime运行与完整独立解释仍待验收。实际学习及文档整理耗时未记录。

## 2026-11-09：Ch18 Driver 加载与启动骨架、讲义及预检

按用户“生成CH18内容”的要求，对应 PLAN 阶段D，新增 `CH18/driver_vector_add.cpp`、`CH18/compile.sh` 和 [Driver 启动讲义](chapters/18_driver_launch.md)，同步 PLAN 目录/变更记录与 NOTE 预习入口。独立 host 目录使用普通 C++ 和 Driver API，按既定方案复用 Ch17 的 sm_75 cubin；与 Runtime 对照保持相同输入、n1000/float32/grid8/block128、每数组4000字节与 CPU double reference。骨架完整提供 primary context retain/current/恢复/release、内存分配/上传/哨兵/回读/释放、等待与全量校验，保留模块加载/入口查找和参数组织/launch 两处 TODO。重点为 context/module/function 使用关系、参数变量地址与设备地址值，不扩展 PTX JIT、性能、Hook 或 API Inventory。

现场核验 GTX1650 / CC7.5 / 14SM / 4096MiB、KMD610.88、DriverAPI13030，NVCC12.9.86、g++13.3.0、Compute Sanitizer2025.2.1.0，CUDA_LAUNCH_BLOCKING unset。重建 Ch17 Runtime 和 cubin，以及正式 Driver 骨架均无警告；Runtime 全量1000项 mismatches0、最大误差0、退出0。正式脚本语法与从/tmp调用通过，正式骨架按预期提示 TODO(1)、退出2；脚本及host多余参数均退出2。

教学方临时在 `build/CH18/preflight/` 补全 API，先验证只完成模块部分时查找成功、提示 TODO(2)、退出2且未提交；完整临时版本实际加载 `build/CH17/vector_add.cubin`，全量1000项 mismatches0、最大误差0、退出0，memcheck padding32 零错误。从/tmp传入cubin绝对路径也正确；故意使用缺失路径按预期得到 CUDA_ERROR_FILE_NOT_FOUND、退出1，属于加载失败对照。ldd确认正式与临时host程序均使用WSL的libcuda.so.1，无libcudart依赖。API签名与primary context/参数复制语义核对本机cuda.h和官方CUDA12.9.1文档，链接写入讲义。

完整命令、版本、cwd、源码/产物SHA-256、临时补全源码、输出与预期/实际退出码见 [预检日志](../reports/CH18/preflight-2026-11-09.txt)。临时源码已删除，内容保留在日志；module_only/complete预检可执行文件保留用于复盘。正式源码仍保留两处TODO，正式Driver加法路径为NOT RUN；临时完整版的校验不冒充正式实现验收。无计时、NSYS、NCU、PTX加载/JIT、racecheck或synccheck，本例无shared协作/barrier，不追加这些门槛。build/reports均为本地产物，默认不进Git。

内容生成、临时补全与验证由Codex完成，用户关键实现、个人重编译/运行与独立解释待验收；Ch18记RUNNING、掌握度未评估，前章状态不变。计划学习用时45～60分钟，实际学习与工程执行耗时均未记录。无计划偏离、新依赖或额外Claude审阅需要，未启动Claude，未生成Ch19、未提交或推送Git。遗留为两处练习与本章个人验收。

## 2026-11-10：Ch18 两处 TODO 补全与正式验证

按用户“完成TODO1和TODO2”的要求，Codex 修改 `CH18/driver_vector_add.cpp`：`load_vector_add()` 用 `cuModuleLoad(module, path)` 加载模块，并以 `cuModuleGetFunction(function, *module, "vector_add")` 查找入口；`launch_vector_add()` 用 `void* args[] = {&d_a, &d_b, &d_c, &n}` 组织参数，再以 grid×1×1/block×1×1、dynamic shared0、默认stream启动。API均经CU_CHECK检查，删除原占位、提示及无用参数抑制，补充模块句柄与参数复制的中文注释。既有context、内存、等待与全量校验流程不变；两函数保留骨架bool接口，成功返回true、API错误立即报错退出。同步PLAN目录、NOTE入口和讲义当前状态，保留11月9日临时预检历史。

现场GTX1650 / CC7.5 / 14SM / 4096MiB、KMD610.88、DriverAPI13030、NVCC12.9.86、g++13.3.0、Compute Sanitizer2025.2.1.0，CUDA_LAUNCH_BLOCKING unset。本机cuda.h核对module/launch签名及kernelParams复制语义；重建Ch17 cubin/Runtime和正式Driver host均成功、无警告，未修改Ch17源码。Runtime与Driver均以n1000、float32、grid8/block128、每数组4000字节运行，全量mismatches0、最大误差0、退出0。正式Driver的memcheck padding32零错误、退出0，实际使用 `build/CH17/vector_add.cubin`，不再是临时补全版结果。

从/tmp通过cubin绝对路径启动正式程序成功；缺失文件按预期报CUDA_ERROR_FILE_NOT_FOUND、退出1，host多余参数按预期退出2。ldd确认正式程序使用WSL libcuda.so.1、无libcudart依赖。完整版本、命令、cwd、原始输出、预期/实际退出码与源码/产物SHA-256见 [正式验证日志](../reports/CH18/completed-2026-11-10.txt)。本轮未新建临时实现、未删除历史证据；没有计时、NSYS、NCU、PTX加载/JIT、racecheck或synccheck，不增加性能或Runtime内部调用映射结论。

本次实现和验证由Codex完成，个人重编译/运行与完整独立解释仍待验收；Ch18保持RUNNING、掌握度未上调，实际学习及工程执行耗时未记录。按PLAN阶段D执行，无范围偏离、新依赖或额外Claude审阅需要；未启动Claude、未生成Ch19、未提交或推送Git。

## 2026-11-10：Ch18 CPU线程与context打印探针

用户表示仍不理解CPU线程与context关系，要求在三次API之间打印previous/context。Codex在 `CH18/driver_vector_add.cpp` 新增只读 `print_context_probe()`，打印Linux/WSL OS线程TID、局部变量地址/句柄大小、previous/context值、实时查询的current、设备、primary active/flags及current flags。在get前后、retain后、set后、restore后、release后共六处采样；release后显式清空context局部变量，注释说明驱动不会替用户改写变量。未新建context、未增加worker线程或依赖，既有kernel、数据、启动和校验保持不变。PLAN记录本次用户授权的教学观测，NOTE和讲义补充真实疑问、资源归属解释与读图表。

普通运行实测同一cpu_tid361332：变量地址为0x7ffd70dd8c10/0x7ffd70dd8c18、句柄大小8字节。retain前previous/context/current空、primary active0；retain后context=0x5635a1dd03f0、current空、active1；set后current等于context、device0；restore后current空而active1；release后active0。primary_flags0x0、current_flags0x8作为原始配置返回记录，不推断实现差异。memcheck独立运行的TID/地址不同，关系相同；地址不是可解码的GPU状态，active不是GPU忙碌或引用次数。此单线程观测不声称验证跨线程共享行为。

现场仍为GTX1650 / CC7.5 / 14SM / KMD610.88 / DriverAPI13030、g++13.3.0、Compute Sanitizer2025.2.1.0，CUDA_LAUNCH_BLOCKING unset。正式版本重编译无警告，n1000/float32/grid8/block128、每数组4000字节，全量mismatches0、最大误差0、退出0；memcheck padding32零错误、退出0。查询签名核对本机cuda.h与CUDA12.9.1官方context/primary文档。完整命令、输出、退出码与源码/cubin/可执行文件哈希见 [探针日志](../reports/CH18/context-probe-2026-11-10.txt)。未生成临时实现、未删除历史证据、未计时或采集profiler。

探针实现、工具执行与讲解由Codex完成；用户仍有明确理解难点，Ch18保持RUNNING、掌握度未上调，个人运行/解释待验收，实际学习与工程耗时未记录。无原课程范围偏离、额外Claude审阅需要或Git提交/推送。

## 2026-11-11：Ch18 本章总结与证据复核

按用户“总结本章内容”的要求，只更新NOTE与RECORD。NOTE补充页首阅读入口和页末“今日完成任务、基本概念、踩坑记录、八股自测”总结，覆盖实际提问：CU_CHECK与返回值/输出参数，context/module/function及不透明句柄，module/function指针的指针与args取值位置的差异，launch各参数和GPU完成边界，.cpp/.cu职责与cubin/SASS执行链，CPU线程current绑定、previous保存恢复、primary active，隐式context参数、资源归属/物理显存共享、跨context复制/访问，以及module卸载和骨架遗留false分支。用户问题以红色标签忠实归纳，核心理解用mark；概念说明不记为用户已独立掌握。

只读核对当前CH18源码/脚本、CH17kernel/构建脚本、正式cubin/Runtime/Driver可执行文件与11月10日两份日志。当前Driver源码、脚本、cubin和可执行文件哈希与context-probe日志全部一致；CH17源码/脚本、cubin和Runtime可执行文件与completed日志一致。无探针completed日志的Driver源码/可执行文件与当前不同，是之后增加探针的预期版本变化，不将历史错误路径检查冒充当前探针构建的新测试。已有数值/环境/命令和证据见 [正式日志](../reports/CH18/completed-2026-11-10.txt) 与 [探针日志](../reports/CH18/context-probe-2026-11-10.txt)：GTX1650/CC7.5/14SM、KMD610.88、DriverAPI13030、n1000/float32/grid8/block128/每数组4000字节，mismatches0、最大误差0，Driver memcheck padding32零错误。probe普通及Sanitizer输出均显示retain后context非空/current空、set后相同、restore后current空、release后primary active0；没有把TID/地址当成固定数值或GPU状态编码。

总结明确当前load/launch包装函数成功返回true、API失败CU_CHECK直接exit，因此main原false清理分支不可达；这是现有教学骨架的控制流限制，本轮未据此改动源码或错误处理方式。context资源关系和current线程绑定属于公开语义，内部存储/TLS/调度实现未验证；跨context、peer、IPC、VMM、多卡、NVRTC/CuPy仅概念连接或官方接口用途，不声称本机运行。没有计时、NSYS、NCU、PTX JIT或Runtime/Driver严格映射结论。

用户多次表示仍不理解context和指针层级，并尝试复述后继续追问；尚无用户个人重编译/运行或完整独立解释的验收证据。实现、probe及验证由Codex完成，Ch18保持RUNNING、掌握度未上调，实际学习与文档整理耗时未记录。文档检查包括本轮新增本地链接、历史证据哈希和diff格式；没有修改CUDA/C++源码、构建脚本或PLAN，没有重编译/执行GPU/重新采集profiler、创建临时实现或删除历史产物，无计划偏离、新依赖或额外Claude审阅需要，未提交或推送Git。

## 2026-11-11：Ch19 内存复用骨架与教学预检

用户明确要求“生成CH19内容”。按PLAN阶段D最后一章新增 `CH19/memory_reuse.cu`、`CH19/compile.sh` 和 [内存复用讲义](chapters/19_memory_reuse.md)，更新PLAN实际目录及授权依据，NOTE新增阅读入口与自测。固定n1000/float32/grid8/block128、每数组4000字节、每批32轮，逐轮输入和预期输出变化；只改变三块device缓冲区的生命周期。骨架提供完整per_step基线、逐轮H2D/kernel/等待/D2H、NaN哨兵、全部32轮CPU double reference、Runtime调用计数、3次预热/21次交替顺序测量及NSYS采集范围，只保留prepare_reuse_buffers一处循环外准备TODO，循环后释放已提供。未新增完整allocator、async pool或后续选修。

现场复核GTX1650/CC7.5/4GB、KMD610.88、NVCC12.9.86、Runtime12090、DriverAPI13030、NSYS2026.4.1和Compute Sanitizer2025.2.1，CUDA_LAUNCH_BLOCKING unset。正式构建与临时补全版使用-O2/-lineinfo/sm_75/-Wall/-Wextra，无警告；脚本bash -n通过。正式check per_step检查32000项，mismatches0、最大误差0，整批及循环内malloc/free均96/96；memcheck padding32加leak-check full零错误、泄漏0字节。正式check both和bench both预期提示reuse NOT RUN并退出2，bench没有发布计时；trace both参数拒绝路径也符合预期。

隔离临时副本只把复用准备函数补成调用allocate_buffers并返回true；两种策略各32000项全量校验通过、最大误差0，memcheck及leak-check零错误/零泄漏。临时reuse整批malloc/free为3/3，循环内0/0；per_step保持96/96。普通计时中位数（μs/批，3次预热/21次重复）：per_step的host_loop/host_lifecycle/Event区间合计为24154.982/24155.053/763.168，reuse为4568.006/5287.791/450.592。CPU loop包含传输、初始化、Event操作与等待，lifecycle额外包括循环外准备/释放；Event不覆盖分配路径且短区间可能包含提交衔接空隙，不将差值解释为纯分配成本或GPU加法指令加速。数据仅限本机本次同步方式，不预设固定加速比。

独立NSYS通过cudaProfilerApi只采预热后的目标循环，排除reuse准备/清理；SQLite结构化核对per_step的malloc/free各96次，reuse各0次，两者各32个kernel、64次H2D、32次D2H和32次memset。首次匹配未处理原始API的_v3020后缀导致解析断言失败，属于后处理匹配问题；修正为保留raw name、另去除末尾版本后缀匹配后核对通过，GPU实验本身无失败。完整命令/退出码/环境/临时补全说明与源码哈希见 [preflight日志](../reports/CH19/preflight-2026-11-11.txt)，结构化计数及正式源码/二进制哈希见 [trace-counts](../reports/CH19/trace-counts-2026-11-11.json)；两份preflight-{per_step,reuse}-2026-11-11.nsys-rep与SQLite保留在reports/CH19。正式构建在preflight日志建立前完成，命令见章节脚本，编译退出0且无诊断。临时补全源码及二进制已自动清理，正式TODO完整保留；没有运行NCU、提交或推送Git。

用户本次完成部分为提出生成需求，没有个人实现、运行或解释证据；辅助程度为Codex骨架、讲义和隔离补全预检，不算用户完整答案或学习验收。Ch19保持RUNNING仅表示骨架及工程预检已运行，掌握度未评估，实际学习与工程准备/agent耗时均未记录。下一步由用户补TODO、重编译、运行双策略并解释生命周期、调用数与计时边界；前章待验收项保留，不因首轮最后一章材料生成而宣称全课程完成。本次符合既定PLAN，无额外依赖或范围偏离，例行准备无需额外Claude审阅。

## 2026-11-17：Ch19 TODO1 正式补全与验证

用户先要求讲解run_batch的执行流程，随后明确要求“完成TODO1”。Codex已将prepare_reuse_buffers实现为调用allocate_buffers并返回true，三块device数组在循环前分配，32轮完成后由既有run_batch释放；删除占位语句，防御检查提示改为通用准备失败/缺少缓冲信息，不再指向已完成TODO。kernel、输入、传输、等待、计时和调用计数方式保持一致。更新讲义当前状态及正式验证、NOTE学习入口和实际问答、PLAN目录说明，不改动历史预检事实。

现场复核GTX1650/CC7.5/4GB、驱动610.88、NVCC12.9.86、Runtime12090、DriverAPI13030、Compute Sanitizer2025.2.1，CUDA_LAUNCH_BLOCKING unset。bash -n与正式构建通过，-Wall/-Wextra无警告；check both两条路径各32000项mismatches0、最大误差0，per_step整批/循环内malloc/free均96/96，reuse整批3/3、循环内0/0。memcheck padding32、leak-check full零错误、泄漏0字节，退出0。

正式bench both先校验、各预热3批、交替策略顺序测21批，CPU校验在计时外。中位数μs/批：per_step的host_loop/host_lifecycle/Event区间合计为24551.086/24551.166/601.440，reuse为4650.845/5404.955/373.856。CPU计时包含传输、初始化、Event操作和等待，lifecycle额外包含复用准备/清理；不把差值当纯分配成本或kernel指令加速。完整命令、输出、退出码及正式源码/脚本/二进制哈希见 [正式验证日志](../reports/CH19/completed-2026-11-17.txt)。本次未重采NSYS/NCU，已有11月11日NSYS仍属于隔离临时补全版历史证据；没有创建临时实现或清理历史产物。

实现、重建、工具执行和文档更新均由Codex完成，用户个人运行与独立解释待验收；Ch19保持RUNNING、掌握度未上调，实际学习与agent工程耗时未记录。按既定PLAN阶段D推进，无范围偏离、新依赖或额外Claude审阅需要，未提交或推送Git。

## 2026-11-17：Ch19 NSYS采集与三个计时的边界分析

用户要求实际用NSYS采集，解释host_loop_us、host_lifecycle_us、event_sum_us的区别及现象原理。正式CH19源码与二进制保持不变；生成并保留同计算的诊断副本reports/CH19/experiment-2026-11-17-probe.cu，扩大cudaProfilerApi采集范围至完整生命周期，紧邻life0/t0/t1/life1添加CPU NVTX标记，保存每轮Event API读数并在批次结束后打印。未改变输入、kernel、传输、等待或分配生命周期，不引入新allocator。采集前正式check both通过；诊断副本编译无警告，check及目标采集全量数值/调用数通过。现场GTX1650/CC7.5/4GB、NVCC12.9.86、Runtime12090、DriverAPI13030、驱动610.88、NSYS2026.4.1，CUDA_LAUNCH_BLOCKING unset。

先独立普通bench，各预热3批、21批中位数μs：per_step的loop/lifecycle/Event合计为25687.094/25687.174/700.928，reuse为6306.048/6831.647/197.888。随后分别用--trace=cuda,nvtx、--cuda-event-trace=true、--capture-range=cudaProfilerApi采诊断副本预热后的一个目标批次。采集内程序loop/lifecycle/Event为27939.568/27949.616/949.920μs与10978.555/12237.293/325.760μs，属于profiler条件，不当普通性能基线。

每份目标报告均为32个kernel、64次H2D、32次D2H、32次memset；CPU全生命周期malloc/free分别96/96与3/3，复用循环内0/0。per_step循环内malloc/free API持续时间合计17389.396μs；reuse完整生命周期这两类API合计1229.891μs，CPU API持续时间含调用与可能等待，不推断内部实际物理分配次数或纯分配算法成本。NVTX复用准备/清理跨度923.880/330.509μs，靠近CPU时钟取点但不要求逐位相等。

GPU逐轮Event标记与同stream kernel通过Correlation ID配对，所有前后间隙非负，全部64个窗口内无memcpy/memset。第二轮per_step的前空档/kernel/后空档为3.200/2.432/7.936μs，设备窗口13.568μs，程序同轮Event14.080μs；reuse为3.072/1.599/4.064μs，设备窗口8.735μs，程序Event9.280μs。32个kernel执行区间合计76.508/52.921μs，设备Event窗口合计1084.985/407.279μs，表明短kernel前后确有较多非kernel区间；不能把Event直接当单线程耗时或kernel色块之和。

本次设备Event标记跨度与程序Event API存在不一致：累计差135.065/81.519μs，单轮最大绝对差45.435/97.075μs，根因未确定；保留两种读数，不用平移或强制校准掩盖，不用跨CPU/GPU绝对端点推断精确等待时长。仅据此不能确定每段空隙属于哪个CPU调用、WSL调度或频率/cache/TLB影响；未量化后几项，也不把kernel时长差宣称为复用让加法指令加速。Event Trace有额外开销，普通bench与采集结果分列。

采集原始报告experiment-{per_step,reuse}-2026-11-17.nsys-rep及SQLite保存在reports/CH19；[完整日志](../reports/CH19/experiment-2026-11-17.txt)、[运行脚本](../reports/CH19/experiment-2026-11-17-run.py)、[分析脚本](../reports/CH19/experiment-2026-11-17-analysis.py)、[汇总JSON](../reports/CH19/experiment-2026-11-17-summary.json)、[逐轮CSV](../reports/CH19/experiment-2026-11-17-intervals.csv)及PNG/SVG保留。图从SQLite实测端点由Matplotlib重绘，非GUI截图，上排CPU/下排GPU分别使用自己的时间原点；GUI阅读路线与证据限制写入讲义，用户实际问题和概念写入NOTE，PLAN记录本次授权。没有操作GUI、重采NCU或运行新的Sanitizer；计算与内存访问逻辑没有改变，不重复既有正式memcheck。诊断副本仍用于复现，保留而不清理；没有创建无用临时方案产物，没有删除用户文件或历史证据。

本次为用户要求的实验诊断，Codex完成采集和解释，不作为个人掌握证据；Ch19保持RUNNING，实际学习与工程执行耗时未记录。未扩展首轮必修、未启动Claude或其他agent，例行实验无需额外Claude审阅，未提交或推送Git。

## 2026-11-18：Ch19间隙差异的受控对照

用户指出前面只解释了Event边界，未解释两方案间隔为什么不同。Codex补做独立诊断，复用正式kernel/helper，保持正式源码与二进制不变。首轮pilot在per_step也保留了不用的固定数组，未完整复现原分配状态；保留pilot源码/日志作审计，v2明确区分per_step与per_step_keepalive。最终六条件为复用、每轮分配、每轮分配但另保留不用空间、固定工作地址而每轮分配额外不用空间、500μs CPU空转间隔、32组预分配地址轮换。每种各预热3批、轮换条件顺序测21批，每批32轮。诊断逐轮生成并校验CPU数据，CPU时间不混同正式程序的host_loop。

普通direct对照Event中位数μs/批：reuse417.152、per_step635.872、per_step_keepalive337.600、scratch367.520、idle471.552、rotate356.064。CPU批次中位数依次4938.915/24758.418/5285.573/5175.454/21601.369/4681.715μs。除rotate每批用32个a地址外，其余各条件每批a虚拟地址数均为1；这反证“每轮必然换地址取数”，不证明物理映射/cache相同。原正式bench在诊断前后两次Event为411.200/398.048与558.976/294.560μs，说明两方案差距不固定；正式host_lifecycle仍分别为24555.217/5220.801与23132.056/4689.411μs。

Graph控制将start Event→同kernel→stop Event连成一次提交，更新kernel参数在Event外；六条件Event中位数分别269.984/386.496/333.216/255.520/357.760/312.608μs。普通直接/Graph全量逐轮校验通过；另对Graph每轮分配案例运行memcheck padding32/leak-check full，零错误、零泄漏。Graph数据只支持提交结构会影响窗口，不据此排除调度因素或声称纯kernel耗时。

另以NSYS2026.4.1采direct的per_step/per_step_keepalive/reuse各一个预热后批次，CUDA Event Trace开启，保留NSYS SQLite与原始报告。前两者循环内malloc/free都96/96，但API持续时间合计17669.642/367.908μs；cudaLaunchKernel CPU中位数18.861/9.453μs，cudaEventRecord为12.1985/9.8435μs。第三个复用条件无循环内分配释放。证据支持分配驻留状态会改变Runtime/Driver后续提交路径的耗时，不能解释为malloc/free直接计入Event；NSYS没有给出内部慢路径名称，仍不能唯一归因到重映射、回收、频率、cache或OS调度。所有采集内API返回成功，每份32个kernel。诊断时GPU仍GTX1650/CC7.5、驱动610.88、NVCC12.9.86，采集前GPU处于P8/300MHz仅是瞬时快照，不当作每个kernel的运行频率证据。

报告统一保留reports/CH19/cause-2026-11-18*及cause-{per_step,per_step_keepalive,reuse}-2026-11-18.nsys-rep/SQLite；[v2完整日志](../reports/CH19/cause-2026-11-18-v2.txt)、[NSYS日志](../reports/CH19/cause-2026-11-18-trace.txt)、[结构化汇总](../reports/CH19/cause-2026-11-18-summary.json)、[分析脚本](../reports/CH19/cause-2026-11-18-analysis.py)、[memcheck与源码核验](../reports/CH19/cause-2026-11-18-verification.txt)可复查。诊断源码、二进制和pilot仍用于复盘，不视作无用临时文件；未删除用户或历史文件。NOTE与讲义补充真实问题、对照结论及未确定边界。Ch19继续RUNNING，Codex诊断不作为用户掌握证据，实际学习/工程用时未记录；未引入新课程必修、提交或推送Git。

## 2026-11-18：Ch19本章总结与理解证据更新

按用户“总结本章内容”的要求，仅更新NOTE与RECORD。NOTE新增页末“今日完成任务、基本概念、踩坑记录、八股自测”本章总结，页首阅读入口同步；覆盖分配生命周期、唯一TODO实现、run_batch逐轮host片段/计数差值、main的策略与lambda/校验/预热/trace/bench流程、三个时间边界、全kernel完成与线程barrier的区别、NSYS设备标记/kernel间隔、地址与常驻分配对照，以及未知内部原因。实际提问使用红色标签，核心概念使用mark；引用11月17日正式普通测量与既有诊断，保持不同日期/口径分离，不重复新增工程证据。

用户已主动准确归纳：“复用分配空间可以节约每次反复申请和释放的时间开销，而event时间差异不是必然有巨大差别。”记录为两项核心结论的复述证据，进度表不再只写“个人解释全无”，但没有个人运行、采集或完整独立解释的验收证据；Ch19保持RUNNING、掌握度未完整评估，不由Codex实现与工具通过推定个人掌握，也不据最后一章总结宣布首轮全课程DONE。既有代码与工具执行归Codex辅助，实际学习与总结耗时均未记录。

只读复核当前CH19源码、compile.sh及正式二进制SHA-256，均与completed-2026-11-17.txt一致；该日志双路径各32000项正确、最大误差0、memcheck零错误/零泄漏，正式计时及11月18日cause汇总可重读。本次仅核对已保存日志、数据和文档链接/格式，没有重编译、运行GPU、重采NSYS/NCU或重复Sanitizer，也没有修改源码、脚本、PLAN、章节实验或环境配置；没有创建临时实现或删除历史文件，无计划偏离或额外Claude审阅需要，未提交或推送Git。

## 2026-11-18：Ch20单stream异步分配与内存池选修准备

用户要求“生成CH20内容”。首轮PLAN止于Ch19，本次依最新指令选择紧接Ch19的Allocator方向第一节作为最小延伸，在PLAN第6节先写明依赖、45～60分钟预算、范围、产物和验收，补计划变更记录。未改变首轮编号、追加其他选修或补记前章完成。新增CH20/async_pool.cu、CH20/compile.sh及DOCS/chapters/20_async_pool.md，更新NOTE入口和ENVIRONMENT能力快照。复用既有vector_add，固定N1000/float32/grid8/block128/32轮，每轮三数组4000字节；唯一比较普通cudaMalloc/cudaFree与同stream的cudaMallocAsync/cudaFreeAsync，两者每轮都完成后进入下一轮。正式源码保留allocate_async和release_async两处TODO，完整提供输入、pinned内存、传输、哨兵、全量校验、API计数、host计时、pool配置及清理。

现场核验GTX1650/CC7.5/4GB、驱动610.88、NVCC12.9.86、Runtime12090、DriverAPI13030、Compute Sanitizer2025.2.1、NSYS2026.4.1，CUDA_LAUNCH_BLOCKING unset，memory_pools_supported=1。bash -n、正式和临时补全版构建均通过且-Wall/-Wextra无诊断。正式check sync的32000项误差0、调用96/96，memcheck零错误/零泄漏；check both在TODO1处按预期NOT RUN、退出2。隔离临时补全版check both各32000项、最大误差0、申请/释放各96次，memcheck padding32、leak-check full、track-stream-ordered-races all均零错误、泄漏0字节，退出0。只补TODO1时另验证TODO2占位路径能等待后清理，预期退出2，memcheck无错误/泄漏；该未完成路径在Sanitizer下pool used读数仍为12096，trim后reserved=0，故该分支统计不作为正常pool释放状态或泄漏证据，根因未深挖。

准备阶段先设8MiB release threshold，得到成功释放后used/reserved均0，普通host批次中位数sync/async为23116.116/67181.754μs。随后最小统计探针实际观察4000字节分配在有效期间used=4000、reserved=33554432，8MiB阈值同步后储备归零；据此正式骨架改为固定64MiB，原pilot日志/NSYS/SQLite以pilot-8MiB-前缀保留，探针源码和输出保存到[pool-stats-probe](../reports/CH20/pool-stats-probe-2026-11-18.txt)。阈值不是预分配大小/容量上限，32MiB只代表本机本次观察；未把这一准备问题扩成用户额外实验或低层allocator排障课。

源码修订后重跑匹配的构建、数值、Sanitizer、普通计时和NSYS预检。固定64MiB配置下，成功async批次释放同步后used=0、reserved=33554432字节，trim后均0。普通bench先校验、各预热3批、交替顺序测21批，host整批中位数sync/async为24140.163/3837.102μs。host从首轮分配前到末轮释放和完成后，包含分配、H2D、memset、kernel提交、D2H、释放及等待，不包含pool设置、CPU校验或最终trim；没有Event计时，不将差值当kernel加速、纯分配成本或跨设备保证。8MiB pilot与64MiB正式预检分列，不混成一次性能统计。

独立NSYS以cudaProfilerApi仅采预热后的一个目标批次和紧随的CPU校验/打印。SQLite结构化检查sync的普通malloc/free各96次，async的异步malloc/free各96次，无另一类分配调用；两份均32个vector_add、64次H2D、32次D2H、32次memset，传输均4000字节；GPU单stream逐轮顺序均为H2D/H2D/memset/kernel/D2H。每份33次stream synchronize包含批次前一次和32次逐轮等待。保留raw API名称及版本后缀，另生成normalized计数，不用API数反推物理分配次数。原始报告为reports/CH20/preflight-{sync,async}-2026-11-18.nsys-rep及同前缀SQLite；[preflight日志](../reports/CH20/preflight-2026-11-18.txt)、[运行复现脚本](../reports/CH20/preflight-2026-11-18-run.py)、[分析脚本](../reports/CH20/preflight-2026-11-18-analysis.py)、[结构化计数及哈希](../reports/CH20/trace-counts-2026-11-18.json)保留。两个TODO临时补全仅在TemporaryDirectory内生成，验证后清理；正式源码/二进制均仍为TODO骨架。未运行NCU或GUI，未提交或推送Git。

用户本次完成部分为提出生成需求；实现骨架、讲义、配置修正与工具预检均由Codex辅助，不算用户完整答案或个人学习成果。Ch20保持RUNNING，仅表示工程骨架和预检已运行；个人补全、重编译、双策略运行及生命周期/pool/计时边界解释待验收，掌握度未评估。实际学习用时与工程准备/agent耗时均未记录。范围扩展已按本次CH20请求落实到PLAN，是既有Allocator方向的小节，没有新增依赖或大规模路线切换；本次无需额外Claude审阅，前章待验收继续保留。

## 2026-11-18：Ch20正式补全两处TODO与验证

按用户要求在[CH20/async_pool.cu](../CH20/async_pool.cu)补全异步分配与释放。`allocate_async`在传入stream为a/b/c各调用一次cudaMallocAsync，`release_async`在同一stream、D2H之后按c/b/a提交cudaFreeAsync，并清空对应host指针。每次成功提交后计数，CUDA_CHECK检查API返回状态。移除过时的练习占位和回退，`run_batch`每轮仍等待一次，普通free排在等待后，异步free排在等待前。将阈值注释改为“本机预检观察到32MiB储备”，避免把单次读数写成固定分配粒度。同步更新PLAN目录、NOTE与讲义，原骨架和临时版预检作为历史证据保留。

现场GTX1650/4GB/CC7.5，驱动610.88，NVCC12.9.86、Runtime12090、DriverAPI13030、Compute Sanitizer2025.2.1、NSYS2026.4.1，memory_pools_supported=1，采集时CUDA_LAUNCH_BLOCKING unset。bash -n和正式构建通过且无警告，`check both`各32000项无误差、申请/释放各96次。memcheck含padding32、leak-check full、track-stream-ordered-races all，零错误、零字节泄漏。异步释放并同步后观察到used=0、reserved=33554432字节，trim后均归零。普通bench各预热3批、交替顺序测21批，32轮host整批中位数sync/async为24220.318/3770.247μs，包含传输、提交、释放与等待，适用于本机本次设置。

独立NSYS采正式版每策略一个预热后的批次。SQLite核对普通/异步API各96次申请与释放、各33次显式stream同步（批前1次加逐轮32次）。两份均有32个vector_add、64次H2D、32次D2H、32次memset、每次传输4000字节，GPU单stream逐轮顺序相同。原始报告与SQLite为`reports/CH20/completed-{sync,async}-2026-11-18.*`，命令、版本、哈希、程序结果、API原始名称及顺序校验见[正式验证日志](../reports/CH20/completed-2026-11-18.txt)。未执行NCU或GUI。Ch20保留RUNNING，Codex完成实现与验证，用户个人运行和独立解释待验收，学习与工程实际耗时均未记录。本次按既有选修范围推进，无新增依赖或额外Claude审阅需要。

## 2026-11-19：Ch20默认池32MiB储备来源核查

用户问为什么请求4000B时`reserved`为32MiB，以及这个值在哪设置。核对源码：第55行给`cudaMallocAsync`传4000B，第193～194行只设64MiB归还阈值，32MiB出现在观测注释与日志。另用最小探针对默认池做单次分配，各组从新进程和空池开始。GTX1650/CC7.5、驱动610.88、NVCC12.9.86、Runtime12090、DriverAPI13030。请求4000B时，设0/8/64MiB三个阈值，申请前均`reserved=0`，首次`cudaMallocAsync`返回后均`used=4000、reserved=32MiB`。释放并同步后`used`均为0，`reserved`分别为0/0/32MiB。固定64MiB时，请求1B、12000B、1MiB和32MiB均观测到32MiB储备，请求33MiB观测到64MiB。结果表明储备随分配产生，阈值影响的是实验中释放后的保留。CUDA12.9.1文档只说明底层申请与用户分配可以采用不同粒度，当前证据不能确定实现内部为何选择32MiB，也不能推广成固定粒度。

[核查日志](../reports/CH20/pool-size-check-2026-11-19-160346.txt)含临时源码、编译/运行命令、原始读数与退出码。编译和8次运行均通过，临时目录已清理。正式课程代码及个人验收状态未改动。此项是统计探针，不作性能对照。

## 2026-11-19：Ch20沿WSL驱动链定位32MiB池扩充请求

按用户追问继续核查。WSL2 6.18.33.2、GTX1650、驱动610.88、CUDA12.9.86。实际`cuGetProcAddress`和`dladdr`定位公开入口在`/usr/lib/wsl/lib/libcuda.so.1`，解析后的`cuMemAllocAsync`位于Windows驱动投影目录的`libcuda.so.1.1`。独立进程的Runtime默认池、直接Driver默认池、显式创建的Driver池分别申请4000B，均`used=4000/reserved=32MiB`。同机公开VMM粒度查询在设备本地、无导出句柄配置下返回最小与推荐均2MiB，直接`cuMemCreate(2MiB)`成功，默认池统计未增长。NSYS采集通过，公共API轨迹未提供池内部扩充算法。命令、源码和输出见[Driver探针](../reports/CH20/pool-driver-check-2026-11-19-160908.txt)。

进程内只观察`/dev/dxg`映射请求的公开字段，所有参数原样转发。校正观察器格式警告后以`-Werror`重建，调用栈和三组运行通过。4000B池请求在`cuMemAllocAsync`返回前发出一条8192页的映射请求，另有一条512页映射，池统计增加32MiB。33MiB池请求发出两条8192页映射，另有一条512页映射，池统计增加64MiB。直接2MiB VMM映射对照为512页。调用栈为用户态`libcuda.so.1.1 → libnvdxgdmal.so.1 → libdxcore.so → ioctl(/dev/dxg)`；本机反汇编显示bridge将字节数右移12换成页数，libdxcore原样转发结构体指针。32MiB已体现在传入内核前的请求里，结果支持当前NVIDIA用户态的池扩充路径使用32MiB块，不支持将其归因于CH20阈值、默认池专属属性、普通VMM最小粒度或通用WSL接口强制取32MiB。未定位私有实现中该规格是常量还是由配置/设备属性推导。调用栈、公开UAPI头文件哈希、相关库哈希、反汇编和原始结果见[WSL映射探针](../reports/CH20/pool-dxg-stack-2026-11-19-161320.txt)，初版观测也保留；临时源码、下载头文件与二进制已清理。正式章节源码和个人验收状态保持原记录，此项不作性能对比。

## 2026-11-19：Ch20本章总结、bench复测与理解证据

按用户“总结本章内容”，在NOTE末尾新增章节总结并更新阅读入口。按真实追问整理同stream轮次顺序、默认池和混用边界、四个池统计观测点、阈值与两次归还、32MiB来源、CH19与CH20的分工，以及普通bench与NSYS证据。保留踩坑与自测，驱动私有规则只作为追问记录，不加入课程验收。正式源码和脚本未改动。

补记此前按用户要求直接执行的11月19日`bench both`。GTX1650/CC7.5/4GB、驱动610.88、Runtime12090、DriverAPI13030，源码和二进制哈希与11月18日正式验证一致。每策略先校验、预热3批，交替顺序测21批，每批32轮。普通/异步host整批中位数为25689.384/4161.930μs，差21527.454μs（少83.799%）。双路径各32000项正确、最大误差0，申请/释放各96次。释放并同步后used=0/reserved=32MiB，trim后均为0。命令、环境和原始输出见[11月19日复测日志](../reports/CH20/bench-2026-11-19-152127.txt)，11月18日正式版24220.318/3770.247μs作为独立历史测量保留。

本次只读复核11月18日两份正式NSYS SQLite。按对应malloc/free的Runtime行累计`end-start`得普通/异步15.422604/0.349550ms。把同stream每轮的H2D/H2D/memset/kernel/D2H五段GPU活动按时间排序，各批累计0.410031/0.314023ms。相邻轮D2H结束到下一轮H2D开始的31段累计18.833302/1.788738ms。仅在CPU轨上取前轮同步结束到后轮第一次memcpy API开始的31段，中位数446.841/5.751μs，普通段内为三次free和三次malloc，异步段内为三次mallocAsync。独立采集数值不拼成普通bench差值，CPU与GPU观察区间也不相加。池保留与释放提交顺序同时不同，现有对照不分摊二者的独立收益。

用户曾把异步理解为提交释放后直接进入下一轮，讲解后已主动指出两条路径每轮都有三次释放、都等释放完成、计算仍访问global memory。记为具体理解证据。个人构建、运行与完整独立解释尚待验收，Ch20仍为RUNNING、掌握度未完整评估，实际学习和工程用时均未记录。总结时未重编译、运行GPU、重采NSYS或重复Sanitizer，复测与驱动诊断均按此前已保存的证据记录。本次无需额外Claude审阅。

## 2026-11-19：Ch21跨stream异步分配生命周期骨架与预检

用户要求“生成CH21内容”，按PLAN第6节启用Allocator方向第二节，依赖Ch15/20，预算45～60分钟。Codex生成独立的`CH21/cross_stream_lifetime.cu`、`CH21/compile.sh`与[讲义](chapters/21_cross_stream_lifetime.md)，同步PLAN、NOTE入口与ENVIRONMENT能力核验。固定32轮、N=1000、float32、grid8/block128；owner队列申请、上传和释放，worker队列初始化、计算和回读，只改变ready/done两处交接采用CPU等待还是Event设备等待。GPU链有意保持按轮串行，不以重叠或加速为验收要求。

正式源码保留`wait_until_ready`和`wait_until_unused`两处TODO，安全CPU等待占位；`check`明确报告回退，未完成时拒绝event路线的bench/trace。正式骨架编译无警告，两路线各32000项正确、最大误差0、分配/释放96/96，event仍为host_waits=64/device_waits=0。隔离副本仅补TODO1后为32/32，性能运行仍按预期返回2；完整补全副本host为64/0、event为0/64，两路线全量数值与调用数通过。正式骨架及完整补全副本均通过memcheck（padding32、leak-check full、stream-ordered-races all），零错误、零泄漏。未完成路线拒绝性能运行后仍清理并trim。

现场GTX1650/CC7.5/4096MiB、驱动610.88、NVCC12.9.86、Runtime12090、DriverAPI13030、Compute Sanitizer2025.2.1、NSYS2026.4.1、memory_pools_supported=1。完整补全版独立普通bench每策略预热3批、交替顺序21批，host整批中位数为host3702.467μs、event4261.529μs，event未加速；该差值未做驱动内部原因拆分，也不代表kernel本身变化。host计时包括本批分配、传输、初始化、计算提交、等待和释放，Event/stream创建、输入准备、池配置、CPU校验和trim在外。

独立NSYS两份各96次mallocAsync、96次freeAsync、64次EventRecord、4次stream同步；交接分别为64次EventSynchronize与64次StreamWaitEvent。GPU均为32个kernel、64次H2D、32次D2H和32次memset，传输/初始化每次4000字节，H2D在owner、其余GPU活动在worker，每轮及轮间顺序核查通过，无活动重叠。释放同步后池used=0/reserved=32MiB，trim后均为0。原始命令、环境、源码/二进制哈希、退出码及数值见[预检日志](../reports/CH21/preflight-2026-11-19.txt)；[预检脚本](../reports/CH21/preflight-2026-11-19-run.py)保留临时补全方法，NSYS报告和SQLite为`reports/CH21/preflight-{host,event}-2026-11-19.*`，[分析脚本](../reports/CH21/preflight-2026-11-19-analysis.py)和[计数/端点JSON](../reports/CH21/trace-counts-2026-11-19.json)保留原始API名及版本后缀。未运行NCU或声称GUI验证；临时补全源码和二进制已清理，正式源码及build保持TODO骨架。

本次用户完成部分仅为提出生成需求；源码、讲义、提示和工程预检由Codex提供，个人实现、运行与独立解释待验收，Ch21为READING，前章状态保持。实际学习用时与工程准备/agent执行耗时均未记录，不按聊天间隔估算。下一步由用户预测并运行骨架，再补两处设备依赖、重编译、检查全量输出及生命周期，解释ready与done各保护什么。范围已写入PLAN，无额外路线偏离；例行教学准备无需额外Claude审阅，未提交或推送Git。

## 2026-11-24 Ch21 两处设备等待补全

按用户要求完成TODO1和TODO2。`wait_until_ready()`把等待`ready`排入`worker`，`wait_until_unused()`把等待`done`排入`owner`。两个helper都检查`cudaStreamWaitEvent`的结果。删除骨架的CPU回退和性能运行拦截，按策略分别校验host与device等待次数。同步更新PLAN、讲义和NOTE。

正式构建无警告。GTX1650 / CC7.5、驱动610.88、NVCC12.9.86、Runtime12090、DriverAPI13030。`check both`中每条路线的32,000项输出全部正确，最大误差0，申请和释放各96次。`host`路线为64次CPU等待，`event`路线为64次队列等待。Compute Sanitizer memcheck 2025.2.1（padding32、leak-check full、stream-ordered-races all）报告零错误、零泄漏。两路线同步释放后池used为0、reserved为32MiB，trim后均为0。

普通bench按每路线3批预热、21批交替顺序采样，32轮整批耗时中位数为host 3807.623μs、event 4338.693μs。独立NSYS 2026.4.1报告分别确认64次EventSynchronize和64次StreamWaitEvent，两份各有96次申请和96次释放，GPU均为32个kernel、64次H2D、32次D2H、32次memset，按轮有序。命令、哈希和结果见[正式验证日志](../reports/CH21/completed-2026-11-24.txt)，原始报告及SQLite为`reports/CH21/completed-{host,event}-2026-11-24.*`，另有[结构化计数](../reports/CH21/completed-trace-counts-2026-11-24.json)。

实现及验证由Codex执行，Ch21更新为RUNNING。个人运行和独立解释待验收，个人学习与工程准备耗时均未记录。本次工作符合PLAN第6节，无需额外Claude审阅。

### 同日补充 CH21 交接耗时与整批耗时诊断

用户追问为何交接API合计较短而整批仍可能较长。复核正式版哈希与两份原有NSYS SQLite，单独核算批末同步段与GPU活动。另对正式版执行10组普通bench，对两份临时副本分别执行两策略分段和四策略对照。分段把CPU循环末尾设为边界，`event`循环段从3.773 ms缩至1.887 ms，批末同步段由0.002 ms增至2.457 ms。原正式版10组里`host`快6组、`event`快4组。两种诊断的数值和memcheck均通过，临时源码及二进制已清理，正式课程状态为RUNNING。数据及限制见[讲义中的计时诊断](chapters/21_cross_stream_lifetime.md#为什么交接-api-更短整批却可能更长)，个人运行和解释待验收。

### 同日 Ch21 学习总结

按用户要求，在 NOTE 汇总两条跨 stream 依赖、命令行模式、创建标志、计时口径与实际提问，补充自测。核对正式源码和二进制哈希、既有校验和诊断日志。此次只整理已有证据。两处 TODO、构建和工具验证由 Codex 执行，用户已就源码与结果提问，个人运行和独立解释待验收。状态为 RUNNING，个人学习和工程准备实际用时均未记录。[Ch21 学习总结](NOTE.md#2026-11-24-ch21跨-stream-异步分配的使用与释放)

## 2026-11-24 Ch22 VMM 分段扩容骨架与预检

按用户“生成CH22内容”启用 PLAN 第 6 节的 VMM 选修，预算 45～60 分钟。Codex 提供 `CH22/vmm_grow.cu`、`CH22/compile.sh`、讲义和两处 TODO 提示。实验以设备报告的粒度预留两段连续虚拟地址，先启用一段，再映射并授权第二段，使用同一基地址逐项检查扩容前后的数组。[Ch22 讲义](chapters/22_virtual_memory.md)

WSL2 / GTX 1650 / CC 7.5 / 4096 MiB，驱动 610.88、NVCC 12.9.86、Driver API 13030、Runtime 12090。正式构建无警告，`probe` 完成预留、物理申请和清理，退出 0，`check` 在缺映射时安全停止并退出 3。仅补映射的隔离副本查询权限为 `0x0 → 0x0`，在 GPU launch 前停止。完整副本两段均为 `0x0 → 0x3`，每段 2 MiB、524,288 项 `uint32_t`，每次写一段的 kernel 配置为 grid 4096、block 128。扩容前后基地址相同，分别检查 524,288 和 1,048,576 项，均零偏差。memcheck 2025.2.1 报告零错误、零泄漏，临时副本已清理。计时、NSYS 和 NCU 为 NOT RUN。[命令与验证日志](../reports/CH22/preflight-2026-11-24.txt)

用户本次提出生成需求，工程准备与验证由 Codex 执行。Ch22 为 READING，待用户补全两处 API、运行校验并解释映射、授权和释放顺序。实际学习与工程准备耗时均未记录。工作在 PLAN 第 6 节范围内，例行章节无需额外 Claude 审阅。

## 2026-11-25 Ch22 映射与访问权限补全

按用户要求，Codex 在 `CH22/vmm_grow.cu` 用 `cuMemMap` 将各段显存接到相应的虚拟地址，用 `cuMemSetAccess` 为目标 GPU 授予读写权限。映射成功后记录状态，授权后检查权限，再启动 kernel。移除骨架占位与 `INCOMPLETE` 分支，API 失败沿既有错误路径清理。同步更新 PLAN、NOTE 与讲义。[Ch22 源码](../CH22/vmm_grow.cu) · [讲义](chapters/22_virtual_memory.md)

正式程序在 GTX 1650 / SM75、驱动 610.88、Toolkit 12.9.86 下构建无编译警告。`probe` 和 `check` 均退出 0。两段各 2 MiB，授权前后均为 `0x0 → 0x3`。普通 `check` 的扩容前后基地址都为 `0x800000000`，分别校验 524,288 和 1,048,576 项 `uint32_t`，均零偏差。扩容后边界值为 525,287 和 526,288，前半段数据保留。Compute Sanitizer 2025.2.1 memcheck 报告零错误、零泄漏。计时、NSYS 和 NCU 为 NOT RUN。[命令与正式验证日志](../reports/CH22/completed-2026-11-25.txt)

实现、构建和验证由 Codex 执行。Ch22 更新为 RUNNING，用户已就结构体、初始化、粒度和权限配置提问，个人运行与独立解释待验收。个人学习和工程准备实际耗时均未记录。本次工作符合 PLAN 第 6 节，例行章节无需额外 Claude 审阅。

### 同日 Ch22 学习总结

按用户要求在 NOTE 整理分段扩容的执行顺序、实际追问及自测。用户已用自己的话正确复述先预留连续虚拟地址、分两次申请显存并先后写入，以及物理显存即使不相邻也可以映射到相邻的虚拟地址。该复述是对虚拟连续性和分段扩容的理解证据，个人运行与完整独立解释待验收，状态为 RUNNING。

复核正式源码、脚本与二进制的 SHA-256 和验证日志，确认与 11 月 25 日的正式记录一致。本次为文档复盘，沿用既有 GPU 校验和 memcheck 证据。两处 API 实现和验证由 Codex 执行，个人学习与工程准备实际用时均未记录。[Ch22 学习总结](NOTE.md#2026-11-25-ch22用-vmm-保持基地址并扩容)
