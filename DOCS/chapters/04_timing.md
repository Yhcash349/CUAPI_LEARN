# Ch04：正确计时

本章给已经正确的 vector add 加上计时，回答“GPU 算得多久”和“CPU 等到结果用了多久”。计划 45～60 分钟，源码为 [timing.cu](../../CH04/timing.cu)，进度与实际用时只记在 [RECORD](../RECORD.md)。复用 Ch02 的 1000 项、8 个 block、每 block 128 线程，以及 Ch03 的错误检查。按本次明确请求准备 Ch04；前章尚缺的验收不因此完成。

## 先看同一次加法的不同边界

CPU 计时器像墙上的秒表，测两次读表之间经过了多久；CUDA Event 像放在 GPU 工作队列里的两个时间标记，测 GPU 走过两个标记的间隔。stream 暂时只理解为按顺序处理工作的队列，本章所有操作使用默认 stream 0，不学习多队列并发。

```text
CPU 直接计算：CPU 起表 → CPU 相加 → CPU 停表

GPU 含传输总时间：
  先等旧工作完成
  CPU 起表 → H2D(a,b) → kernel → D2H(c) → 等待完成 → CPU 停表

GPU Event 区间（输入已经在显存）：
  start 标记 → 连续启动 100 次 kernel → stop 标记
  CPU 等 stop 完成 → 读取两标记时间差 → 毫秒 × 1000 / 100
```

| 输出字段 | 单位与范围 |
| --- | --- |
| `cpu_add_host_median_us` | 微秒；CPU 执行一次 1000 项加法，包括函数调用，不含输入准备与校验 |
| `gpu_with_copies_host_median_us` | 微秒；两次 H2D、一次 kernel、一次 D2H，以及 API、错误检查和等待；不含分配、初始化、校验和释放 |
| `gpu_event_batch_per_launch_median_us` | 微秒；每批 Event 区间除以 100，再对 21 个归一化样本取中位数；不含传输 |

这里的“总时间”特指预分配之后的一次数据处理路径，不是程序启动到退出的总耗时。GPU kernel 启动后 CPU 可以继续执行，因此只包住启动语句的 CPU 秒表不能证明 GPU 已完成。本章只记住正确等待的边界，异步机制到 Ch13 再展开。

Event 也不是自动只统计计算指令的秒表：批内可能存在 host 提交不及时造成的 GPU 空闲间隔，本例每次启动还有错误检查。故字段叫“批次平均每次启动时间”，不能冒充 profiler 上单个 kernel 的纯执行时长，也不能直接拿它与 CPU 单次时间宣称端到端加速。重复访问相同输入还可能受缓存影响。本章不归因这些性能机制，只把测量范围说清楚。

## 已完成的两处练习（2026-09-28）

本次按用户“完成CH04练习”的要求补全正式源码。保留现场已有的 `warmup = 10`，Codex 完成四次 Event 调用及注释整理。预热就是先做几遍不计入结果的工作，让首次使用路径走完；它不保证消除所有抖动。程序预热后采集 21 个样本并取中位数。

Event 计时现在按下面的顺序执行，所有返回值均由 `CUDA_CHECK` 检查：

```cpp
CUDA_CHECK(cudaEventRecord(start, 0));
for (int j = 0; j < batch; ++j) {
    vector_add<<<grid, block>>>(d_a, d_b, d_c, n);
    CUDA_CHECK(cudaGetLastError());
}
CUDA_CHECK(cudaEventRecord(stop, 0));
CUDA_CHECK(cudaEventSynchronize(stop));
CUDA_CHECK(cudaEventElapsedTime(&elapsed_ms, start, stop));
```

按执行次序查这三个接口，参数名就是源码中已声明的对象：

```cpp
cudaEventRecord(cudaEvent_t event, cudaStream_t stream = 0);
cudaEventSynchronize(cudaEvent_t event);
cudaEventElapsedTime(float* ms, cudaEvent_t start, cudaEvent_t end);
```

以上省略返回类型与 CUDA 修饰，均返回 `cudaError_t`；`cudaEventElapsedTime` 的第一个参数需要输出变量的地址，单位是毫秒。`cudaEventRecord` 用两次，起止标记都放 stream 0。先等待结束标记再读取结果；普通 `cudaEventCreate` 已启用计时，不应改用禁用计时的标志。依据 [CUDA Runtime API 12.9：Event Management](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART__EVENT.html)，签名另与本机 `/usr/local/cuda-12.9/include/cuda_runtime_api.h` 核对。

`elapsed_ms` 仍初始化为 NaN，用于检测无效计时结果；正式调用会将毫秒差写入它。已经等待 `stop` 完成，因此移除了原骨架在此处冗余的全设备同步。回读和校验在 Event 区间之外。预热不足或 Event 结果不是有限正数时返回非零，避免将未完成计时当成成功。

## 预测、编译、运行

先用 5 分钟预测：只做 1000 次加法，加入往返传输后 GPU 是否一定快过 CPU？Event 与 CPU 总时间谁更可能大，为什么？本章主要比较变量是计时边界，固定 N、block、计算逻辑与输入。原练习安排为约 10 分钟读流程、20 分钟补调用、15 分钟运行、10 分钟解释；当前代码已由 Codex 补全，可直接阅读和运行。

在项目根目录执行；每次修改都要“保存源码 → 重新编译 → 运行”：

```bash
mkdir -p build/CH04
nvcc -std=c++17 -O2 -arch=sm_75 -lineinfo -Xcompiler=-Wall,-Wextra CH04/timing.cu -o build/CH04/timing
./build/CH04/timing
```

`-O2` 用于优化编译，也使 CPU 对照不处于刻意关闭优化的状态。程序先验证再预热，每次测量后的校验与统计都在计时区间外；CPU 输出每轮实际读取，避免重复计算变成无人使用的结果。CPU 对照只是当前程序的单线程实现，不代表最佳 CPU 库性能。全部输入输出为 `[1000]` float32，容差 `1e-6`；普通 CPU 内存与所有 GPU 内存均在计时前分配。

当前正式源码已补全，直接编译运行即可。读三个字段时写出各自包含的工作；需要保存自己的输出时运行 `./build/CH04/timing | tee reports/CH04/user_run.txt`（先执行 `mkdir -p reports/CH04`）。正常计时不套 Sanitizer、NSYS 或 NCU，工具采集与正常计时分开。若重复运行有波动，如实记录，不挑最快的一次；本章不要求固定加速比。

## 验收与范围

验收需要全部元素通过、最大误差满足容差、预热至少 3 次、21 个有效样本和三个有明确边界的计时结果。还需用自己的话解释：为什么 CPU 秒表必须等 GPU 完成？为什么 Event 时间较短仍不能证明整个 GPU 路径更快？指出起止标记和两次拷贝输入、一次回读的位置即可。

代码骨架由 Codex 提供；本次保留现场已有预热设置，由 Codex 补全 Event 调用并验证。程序运行与个人解释都具备才记 DONE，不将代为补全视为用户独立实现。到一小时仍有问题就记录未完成点，不追加跨 stream 依赖、硬件计数器或优化实验。与推理程序的联系是：计算本身的时间和用户等待结果的时间可能有明显差别。

## 工程预检

命令、输出与退出码保存在 [preflight.txt](../../reports/CH04/preflight.txt)，构建与报告按现有 `.gitignore` 留在本地。以下为 9 月 22 日历史预检：当时正式源码保留练习，临时补全版仅用于验证后清理；这些结果不是用户独立完成或掌握的证据。实测摘要见下方。

2026-09-22 复核 GTX 1650 / CC 7.5、NVCC 12.9.86。最终正式骨架与临时补全版均编译无警告，退出 0；1000 项全部通过、最大绝对误差 0。骨架输出 `Timing NOT RUN`；补全版 warmup=3、samples=21、event_batch=100，最终一次运行的中位数如下。

| CPU 加法 host 时间 | GPU 含传输 host 时间 | Event 批次平均每次启动时间 |
| --- | --- | --- |
| 0.561000 μs | 98.217000 μs | 7.857920 μs |

这次小输入下 GPU 含传输路径慢于当前 CPU 实现，符合“小任务 GPU 未必更快”的观察目标。它是教学预检，不是正式优化 A/B，也不是其他输入或架构的结论。原始报告保留早期编译中常量零次预热导致的不可达循环警告；将预热次数改为可编辑普通变量后重新编译，最终无警告。未运行本章 Sanitizer、NSYS 或 NCU，不据数值通过宣称内存安全证明或硬件瓶颈。

## 2026-09-28 正式完成版验证

GTX 1650 / CC 7.5、NVCC 12.9.86；按上方命令编译无警告，运行退出 0。N=1000、float32、grid=8、block=128，全部元素通过、最大误差 0；warmup=10、samples=21、batch=100，计时 PASS。

| CPU 加法 host 中位数 | GPU 含传输 host 中位数 | Event 批次平均每次启动中位数 |
| --- | --- | --- |
| 0.781000 μs | 161.777000 μs | 9.461120 μs |

原始命令与输出见 [completed-2026-09-28.txt](../../reports/CH04/completed-2026-09-28.txt)。本次验证正式源码，不是历史临时版；没有采集 profiler 或运行 Sanitizer。仅说明本机本次小输入的观察，不能把与历史预检的差异当作优化效果。个人解释仍待验收。
