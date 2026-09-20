# Ch01：第一个计算 kernel

本章用 GPU 完成两个数组逐元素相加，理解数据往返和 kernel 的作用。计划 45～60 分钟；源码为 [vector_add.cu](../../CH01/vector_add.cu)，进度见 [RECORD](../RECORD.md)。前置是 Ch00 的保存、编译、运行操作；Ch00 的用户解释仍待验收，本次按用户要求准备下一章，不补记前章完成。

当前版本：用户随后要求“解题并编译”，Codex 已补全 kernel 并编译运行通过。下文 TODO 与首次 FAIL 描述的是原始练习流程；当前源码没有 TODO，直接运行应为 PASS，个人解释仍待验收。

## 先看一个具体任务

向量在这里就是一维数组。输入 256 个 `float`：`a[i] = 0.5 × i`，`b[i] = 1 + 0.25 × (i % 7)`；要求每一项 `c[i] = a[i] + b[i]`。例如第 3 项是 `1.5 + 1.75 = 3.25`，不能只检查某一项或总和。

host 指 CPU 一侧，device 指 GPU 一侧。本程序在两边分别分配数组，数据流是：

```text
CPU：h_a、h_b ──H2D 拷贝──> GPU：d_a、d_b
                                  │ kernel 计算
CPU：h_c     <──D2H 回读─── GPU：d_c
   │
与 CPU reference 逐元素比较
```

kernel 是交给 GPU 线程执行的函数。`__global__` 标记这里的 GPU 入口；`vector_add<<<1, n>>>` 启动一个 block、其中 256 个线程。block 先理解成一组线程；每个线程执行同一段函数，但 `threadIdx.x` 不同，分别处理第 0～255 项。例如编号 3 的线程只处理第 3 项。这不保证所有线程同一时刻运行，也无需本章推导调度规则。对应 CUDA 12.9 官方 [Kernels](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#kernels)。

## 读骨架并完成一处修改

相比 Ch00 的“查询设备”，这里新增真正的 GPU 计算；继续使用相同的 `check_cuda` 辅助函数。`main()` 及其中普通循环在 CPU 上运行，CPU reference 已写好，你只需修改 kernel 内的 `TODO(CH01)`。当前占位行把输出写成零，请替换为读取两项输入、相加、写入对应输出的语句。不要修改 CPU reference、校验或启动配置来让程序通过。

阅读 host 部分时，按下面的顺序对应数据流即可，不要求背 API 签名：

| 代码 | 本章作用 |
| --- | --- |
| `std::vector<float>` | 在 CPU 一侧保存输入、回读结果和参考答案 |
| `cudaMalloc` | 为 GPU 数组分配空间；`bytes` 是字节数，每个数组 1024 字节 |
| `cudaMemcpy(..., cudaMemcpyHostToDevice)` | 把输入从 CPU 拷到 GPU，参数顺序是目标、来源、字节数、方向 |
| `vector_add<<<1, n>>>` | 提交 GPU 计算，传入的是 `d_` 指针 |
| `cudaDeviceSynchronize` | 等待 GPU 完成，检查执行是否出错 |
| `cudaMemcpy(..., cudaMemcpyDeviceToHost)` | 把 GPU 结果回读到 CPU，再进行校验 |
| `cudaFree` | 释放 GPU 分配的空间 |

`cudaMemset` 是已提供的输出初始化；`cudaGetLastError` 和 `check_cuda` 是检查骨架，错误分类留到 Ch03。输入、配置和校验保持固定，本章唯一实验变量是 kernel 的占位写入与正确计算。不要增大 N 或改为多个 block；通用索引及越界保护到 Ch02 再补。

## 先预测，再运行

建议用 5 分钟预测、10 分钟读骨架、20 分钟修改、15 分钟运行对照、10 分钟解释；提前完成即可结束，不必用满一小时。

运行前先写下预测：占位程序输出零时会通过校验吗？修改后第 3 项应是多少？只修改 `.cu` 而没有重新编译，运行的会是哪一版？

在项目根目录执行：

```bash
mkdir -p build/CH01
nvcc -std=c++17 -arch=sm_75 -Xcompiler=-Wall,-Wextra CH01/vector_add.cu -o build/CH01/vector_add && ./build/CH01/vector_add
```

首次运行未修改骨架，应显示 `FAIL` 并退出 1：这是计算练习尚未完成，不能当成 CUDA 环境故障。完成 TODO 后重新执行同一命令，应显示 `mismatches=0 max_abs_error=0` 和 `PASS`，退出 0。前四项只帮助读结果，程序实际检查全部 256 项；绝对误差容限为 `1e-6`，NaN/Inf 也判失败。当前输入可精确表示，正确实现预期误差为零。

若出现 `cudaMalloc ... failed` 等 API 错误，保留原始报错再定位，不把它与预期的数值校验失败混为一谈。本章不比较 CPU/GPU 速度，不做 Event、预热或 profiler；计时从 Ch04 开始。

## 验收与学习边界

完成后保留自己的运行结果，并用自己的话说明：哪个函数在 GPU 上计算？为什么传入 `d_a/d_b/d_c`？从输入准备到 CPU 校验，中间数据经过哪些步骤？指出线程 3 在源码中如何得到自己的任务即可，暂不推导多 block 索引。

程序 PASS 加上上述个人解释，才构成本章完成证据。Codex 提供 host、输入、参考答案、校验和预检；用户负责 kernel 核心计算，不能将整个工程记为从零独立实现。遇到一小时内无法解决的问题，记录阻塞，不追加进阶内容。

与推理程序的连接：后续算子也需要明确输入存放位置、GPU 计算入口和输出何时可用，本章先看清这条最小数据流。

## 官方资料与预检

仅按需阅读 CUDA C++ Programming Guide 12.9 的 [Kernels](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-c-programming-guide/index.html#kernels)，以及 Runtime API 12.9 的 [Memory Management](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART__MEMORY.html) 中 `cudaMalloc`、`cudaMemcpy`、`cudaFree`。签名同时核对本机 `/usr/local/cuda-12.9/include/cuda_runtime_api.h`，CUDA C++ 的类型化分配重载由 Toolkit 头文件提供。

2026-09-20，复核 NVCC 12.9.86、GTX 1650 / CC 7.5；使用上方命令，无编译警告。正式骨架运行得到 `mismatches=256 max_abs_error=129.25`，退出 1，符合占位实现的预期。Codex 在临时副本中只替换 TODO 的写入语句，重新编译运行得到 `mismatches=0 max_abs_error=0`，退出 0；第 3 项为 3.25。临时源码及二进制已清理，正式源码保留练习。

输入 shape 为 `[256]`、dtype 为 float32，grid=1、block=256。原始命令和输出保存在本地 [preflight.txt](../../reports/CH01/preflight.txt)（由 `.gitignore` 排除），骨架二进制为 `build/CH01/vector_add`。计时与 profiler 未运行，本章无性能结论。上述为 Codex 预检，用户运行、代码修改和解释尚未验收。

## 完整答案验证（2026-09-20）

按用户要求，将 kernel 的占位写入替换为 `c[i] = a[i] + b[i];`，移除未使用参数占位，并更新失败提示。`i = threadIdx.x` 让每个线程处理自己的元素，例如线程 3 写入 `1.5 + 1.75 = 3.25`。

使用上方 nvcc 命令编译正式源码，无警告；运行 `./build/CH01/vector_add`，256 项 float32 全量校验通过，输出 `mismatches=0 max_abs_error=0` 和 `PASS: all elements match the CPU reference.`，退出 0。当前二进制已替换为完整答案版；前述骨架失败与临时补全结果保留为历史预检。未做计时或 profiler。辅助程度为 Codex 完整答案，用户解释待验收。
