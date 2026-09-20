# 工程记录

项目唯一执行依据为 [PLAN.md](PLAN.md)。本文件记录工程改动、验证与遗留项；学习概念在 NOTE，实际学习进度在 PROGRESS。

## 2026-09-20：环境评估与计划收敛

### 背景与决定

原始 `CUAPI_LEARN_PLAN_V2.md` 面向 Runtime/Driver、profiler 与推理框架接口分析，必修至少 99 小时，含可选多卡至少 105 小时。用户提出程序驱动、知识可观察、每章最多 1 小时的新约束；本机评估提出 20 节轻量首轮，并将进阶工作内容延后。

用户随后明确要求将评估与 V2 核心思想整合进 PLAN，必要上下文分配到 DOCS，其后删除两份来源。此次整合依此执行，不再将路线标为待确认；没有获得或声称获得 Claude 审阅。

### 文件分工与关键改动

PLAN 从占位模板变为正式计划，包含目标、20 节路线、阶段验收、按需选修、工具与证据规范、目录与文档合同、资料入口和变更记录。ENVIRONMENT 保存本次硬件/工具快照与命令；NOTE 保存学习起点和笔记规则；PROGRESS 初始化全部课程为 TODO，没有把环境 smoke 标为学习完成。

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
| V2 文档模板、进度、官方覆盖、reference traces | PLAN §8～9，PROGRESS、NOTE；统一 DOCS，按需创建记录与小型 trace |
| V2 依赖图、轮次、初始化、最终验收 | PLAN §5～6、§8；改成线性首轮、按需选修，不保留矛盾依赖或批量初始化 |
| 评估的硬件/工具/限制/命令 | ENVIRONMENT；PLAN §3 引用 |
| 评估的 20 章、一小时约定、实验陷阱与取舍 | PLAN §4～6；NOTE 保存学习目的，PROGRESS 保存未开始状态 |

已按用户授权删除 `DOCS/PLAN_V2_ASSESSMENT.md` 和 `CUAPI_LEARN_PLAN_V2.md`。

来源中的“保留原 V2”“路线待确认”、CUDA 13.x 统一基线、每章 2～8h、一次创建全部目录及实现前四章、独立 docs/result 文档体系均由新要求替代，不作为遗失内容重新引入。

### 验证与证据

前次评估已实际编译执行最小 kernel，4096 个整数校验通过；NCU basic 与 NSYS trace/stats 可用，详见 ENVIRONMENT。它们是环境检查，不是正式课程 A/B 或学生独立完成证据。

本次只做文档整合，不重跑 GPU benchmark。删除来源前核对上述迁移表及 20 节编号；删除后检查本地 Markdown 链接、来源残留引用与占位计划。历史文件名仅保留在本条记录作追踪，不作为链接或执行依赖。

### 当前状态与下一步

尚未初始化课程源码、构建系统或 Git；下一步按 PLAN 从 Ch00 开始。重要风险是教学一小时预算依赖可运行骨架，以及临时预检报告可能被系统清理；高级 API 和所有课程性能实验仍需实际验证。Claude 尚未审阅，当前无需以额外审阅阻塞执行。
