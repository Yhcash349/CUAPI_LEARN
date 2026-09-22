# Ch02：线程索引与越界保护

本章把 Ch01 的单 block 相加扩展为 1000 项，学习如何分配线程任务，以及如何让多出的线程跳过数组访问。计划 45～60 分钟，源码为 [thread_index.cu](../../CH02/thread_index.cu)，进度见 [RECORD](../RECORD.md)。复用 Ch01 的 host/device 数据流、输入、CPU reference 和逐元素校验；前章个人解释仍待验收，本次按用户要求准备 Ch02。

当前版本：用户要求“完成今日作业”，Codex 已补全两处实现，正式程序编译、全量校验与 memcheck 均通过。下文 TODO 和骨架 FAIL 为原始练习流程，当前源码无 TODO，直接运行应为 PASS。个人解释仍待验收。

## 先理解任务如何分组

把 1000 项工作每 128 项分成一组，需要 8 组。block 就是一组线程，grid 是一次启动中的全部 block；`vector_add<<<blocks, threads_per_block>>>` 的两个参数分别指定组数和每组线程数。这里总共启动 1024 个线程，不代表它们物理上同时执行，也不代表一个 block 固定绑定某个 SM。

`threadIdx.x` 是组内编号，每个 block 都从 0 重新编号；`blockIdx.x` 是组号；`blockDim.x` 是每组线程数。本章只用一维的 `.x`。例如 block 1 的线程 3 应处理第 131 项：先跳过前一组的 128 项，再加上组内偏移 3。请据此自己写出通用索引表达式，不能继续只使用 Ch01 的 `threadIdx.x`。

| block 编号 | 对应全局索引 | 本章应做的工作 |
| --- | --- | --- |
| 0 | 0～127 | 128 项相加 |
| 1 | 128～255 | 128 项相加 |
| 2～6 | 256～895 | 每组各 128 项相加 |
| 7 | 896～1023 | 896～999 相加，1000～1023 跳过 |

数组长度为 1000，最后合法索引是 999。边界保护就是在读取和写入数组之前判断该线程是否有合法任务；保护范围必须包含 `a[i]`、`b[i]` 和 `c[i]`，不能先读越界再判断。最后一个 block 有 104 个有效线程、24 个线程跳过访问。

host 已提供向上取整的组数计算 `(n + threads_per_block - 1) / threads_per_block`。整数除法直接写 `1000 / 128` 只得到 7，会漏掉尾部 104 项；这与启动 8 组后让多余线程跳过访问是不同问题。

## 你需要完成的两处练习

先读 kernel，再找到 `main()` 的启动配置。只修改 `TODO(CH02-1)` 的索引右侧表达式和 `TODO(CH02-2)` 的条件；加法语句、N=1000、block=128、CPU reference 和校验保持不变。唯一实验变量是 kernel 的任务映射与有效范围判断，不比较不同 block 大小的性能。

骨架用 `i = n` 和 `if (false)` 占位，不访问数组，输出保持 host 初始化的零；因此可以编译运行，但会校验 FAIL。请补全两处后再运行，尤其不要只开启条件却留下无效索引。不要直接删除判断来“试试是否崩溃”，越界不能依赖偶然报错证明，相关工具练习在 Ch03。

输出选择 0、127、128、895、896、999 这些位置帮助观察跨 block 与尾部边界；程序仍校验全部 1000 项，绝对误差容限为 `1e-6`，NaN/Inf 判失败。现有输入可精确表示，正确实现预期最大误差为零。`check_cuda`、拷贝与等待继续沿用 Ch01，不在本章扩展错误分类。

## 先预测，再运行

建议 5 分钟预测、10 分钟读旧代码与骨架、20 分钟补两处、15 分钟运行对照、10 分钟解释。先写下自己的判断：为什么需要 8 组？block 7 的线程 103 和 104 分别负责哪个索引，谁应访问数组？只使用组内编号会发生什么？

在项目根目录编译运行：

```bash
mkdir -p build/CH02
nvcc -std=c++17 -arch=sm_75 -lineinfo -Xcompiler=-Wall,-Wextra CH02/thread_index.cu -o build/CH02/thread_index && ./build/CH02/thread_index
```

原始骨架应显示 `mismatches=1000`、`FAIL`，退出 1；这是练习未完成的预期结果。补完两处并重新编译后，应显示 `grid=8 block=128 launched=1024 extra=24`、`mismatches=0 max_abs_error=0`、`PASS`，退出 0。启动配置的打印来自 host，不是线程实际访问的追踪；数值正确性由全量比较检查。

如遇 CUDA API 错误，保留原始输出定位，不与预期数值 FAIL 混淆。一小时仍未完成时记录阻塞并结束本节，不追加 profiler 排障。此章不计时、不讲 warp 调度、二维索引或 grid-stride loop。

## 验收与推理用途

保留自己的修改和运行结果，并用自己的话解释：为什么组内编号不够？block 7 的哪些线程应该跳过？为什么 7 个 block 不够？指出索引和保护条件各自对应的代码。程序通过与个人解释齐备才标 DONE，Codex 预检不能替代用户完成。

与推理算子的联系：张量元素数不一定整除线程组大小，正确的任务映射与尾部处理是逐元素算子的基本要求。

## 官方资料与预检

语义参考 CUDA C++ Programming Guide **12.9** 的 [Thread Hierarchy](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#thread-hierarchy)，本次已核对其中 `blockIdx`、`blockDim`、`threadIdx` 与边界判断示例。只需阅读一维线程分组相关部分，不延伸到 Thread Block Clusters。

预检结果见下方，原始命令与输出保存在本地 [preflight.txt](../../reports/CH02/preflight.txt)，由 `.gitignore` 排除。正式骨架二进制为 `build/CH02/thread_index`；临时补全源码及二进制在预检后自动清理，正式练习保留 TODO。

2026-09-21 实测：NVCC 12.9.86，GTX 1650 / CC 7.5，输入 `[1000]` float32，grid=8、block=128。正式骨架与临时补全版均编译无警告；骨架得到 `mismatches=1000 max_abs_error=501.75`，退出 1，符合预期。临时副本补全两处后得到 `mismatches=0 max_abs_error=0`，退出 0；另用 `compute-sanitizer --tool memcheck --error-exitcode 99` 检查补全版，报告 `ERROR SUMMARY: 0 errors`，退出 0。

内存检查仅由 Codex 做教学预检，本章不要求用户学习该工具。未运行计时、NSYS 或 NCU，无性能结论；用户修改、运行与个人解释仍待验收。

## 完整答案验证（2026-09-21）

按用户要求，正式 kernel 已补全为：

```cpp
const int i = blockIdx.x * blockDim.x + threadIdx.x;
if (i < n) {
    c[i] = a[i] + b[i];
}
```

例如 block 7 的线程 103 得到 `7 * 128 + 103 = 999`，负责最后一项；线程 104 得到 1000，跳过全部数组读写。8 个 block 覆盖 1000 项，多出的 24 个线程由条件保护。

使用上方 nvcc 命令编译正式源码，无警告；运行得到 `mismatches=0 max_abs_error=0`、PASS、退出 0。对正式二进制运行 `compute-sanitizer --tool memcheck --error-exitcode 99 ./build/CH02/thread_index`，报告零错误、退出 0。原始命令和输出见 [completed.txt](../../reports/CH02/completed.txt)，保留初始 preflight 供对照；未计时或采集性能 profiler。

辅助程度为 Codex 完整答案与验证，个人解释待验收，不记为用户独立完成。
