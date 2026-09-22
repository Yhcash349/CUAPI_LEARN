# 环境与预检记录

课程与后续环境变更按 [PLAN.md](PLAN.md) 执行。本页为 2026-09-20 评估时的实测快照；本次文档整合没有重新运行 GPU 实验。切换机器或升级工具后重新核验，不将快照当成永久事实。

实测 GPU：GTX 1650，CC 7.5，14 SM，warp 32 线程，约 4 GiB 显存；每 SM 最大驻留 1024 线程、65536 个 32-bit 寄存器、64 KiB shared memory；默认每 block shared memory 上限 48 KiB。查询到 asyncEngineCount=2、concurrentKernels=1、memoryPoolsSupported=1。这些属性是能力信息，不保证任意双 stream 程序都能重叠或加速。

系统：WSL2，Ryzen 5 5600H，6 核 12 线程，WSL 可见内存约 11 GiB。NVCC 12.9.86，Runtime 12090，Driver API 13030；nvidia-smi 显示 KMD 610.88、UMD 13.3。Nsight Systems 2026.4.1，Nsight Compute 2025.2.1。课程使用 CUDA 12.9 文档及 `sm_75`，不能把驱动支持版本当作 Toolkit 版本。

实际执行：最小 kernel 写入并回读 4096 个整数，全部校验通过。NCU basic 采集成功并返回 SM、访存和 occupancy 数据；NSYS CUDA trace 生成成功。这里只证明工具链及基础采集可用，不是课程 A/B 性能实验，也没有验证 Graph、VMM、async allocator 或框架运行。

本次探针和 trace 保留在 `/tmp/cuapi-assess-RkTAoI/` 供短期复查，属于临时证据，可能被系统清理：

```bash
nvcc -arch=sm_75 -lineinfo /tmp/cuapi-assess-RkTAoI/probe.cu -o /tmp/cuapi-assess-RkTAoI/probe
/tmp/cuapi-assess-RkTAoI/probe
ncu --set basic --launch-count 1 /tmp/cuapi-assess-RkTAoI/probe
nsys profile --trace=cuda --sample=none --cpuctxsw=none -o /tmp/cuapi-assess-RkTAoI/smoke /tmp/cuapi-assess-RkTAoI/probe
```

当前目录尚未初始化 Git，`git status` 返回 `not a git repository`；本次没有执行 Git 初始化。

GTX 1650 没有 Tensor Core，因此 Tensor Core 加速不列为本机实践目标，FP16 运算不能当作 Tensor Core 的证据。多 GPU、P2P/NCCL 也不列入单卡首轮验收。4GB 足够小数组和小矩阵实验，首轮无需下载大模型或建立新框架环境。


另已运行 `nsys stats --report cuda_gpu_kern_sum,cuda_api_sum /tmp/cuapi-assess-RkTAoI/smoke.nsys-rep`，成功生成 SQLite 并显示 kernel/API 汇总。此次整合时确认该临时目录仍存在；原始 NCU 文本仅在评估会话中，未持久化为独立报告。本页不据此建立性能基线。

正式预检还应记录 `cmake --version`、`gcc --version`，并检查 Compute Sanitizer；这些不在此前已验证清单内。Graph、async allocator、VMM、框架实验均 `NOT RUN`，按课程实际用到时测试。Driver/Toolkit/应用链接 Runtime/框架自带 Runtime 版本分别记录；不需要仅因 UMD 13.3 而升级 Toolkit。

硬件边界参考 [NVIDIA GTX/RTX 说明](https://blogs.nvidia.com/blog/whats-the-difference-between-nvidia-rtx-and-gtx/) 与 PLAN 中的官方资料。未来报告保存到 `reports/`，在本页或单章记录写准确路径；历史临时文件丢失时写明证据不可重读，不能伪造恢复结果。

## 2026-09-20 Ch03 补充核验

本次复核 NVCC 12.9.86、GTX 1650 / CC 7.5，并首次实际核验 Compute Sanitizer 2025.2.1.0。`memcheck --padding 32 --error-exitcode 99` 对 Ch03 正常案例和临时修复版报告零错误，对故意越界写入报告源码与线程位置；命令、退出码及原始输出见 `reports/CH03/preflight.txt`，解释见 [Ch03](chapters/03_error_check.md)。仅验证本章 memcheck 路径，不代表 racecheck 等其他功能已验证。当前 Git 已存在，早期“尚未初始化 Git”仅为历史快照；本次未初始化、提交或推送。
