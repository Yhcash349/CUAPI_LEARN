# Ch03：错误检查

本章学习让程序报告“哪次调用失败”，并区分启动配置错误和 GPU 执行中的非法访问。计划 45～60 分钟，源码为 [error_check.cu](../../CH03/error_check.cu)，进度只记在 [RECORD](../RECORD.md)。按用户明确要求直接准备 Ch03；Ch02 尚未生成，本章复用 Ch01 的一个 block、256 个线程，不把 Ch02 记为完成。

## 先理解这条流程

错误检查像在提交任务和等待结果的位置各放一个检查点。`CUDA_CHECK` 是我们自己定义的 C++ 宏，作用是执行一次 CUDA API、检查返回值，失败时打印调用文字、文件和行号并退出；它不是 NVIDIA 提供的 API。沿用 Ch01 的输入、CPU reference 和逐元素校验，不做计时。

```text
分配与拷贝：检查每次 API 的返回值
  → 提交 kernel
  → cudaGetLastError：检查当前记录的错误，不等待 GPU 完成
  → cudaDeviceSynchronize：等待 GPU 完成并检查返回值
  → 回读、数值校验、释放
```

`cudaGetLastError()` 读取并清除当前 host 线程对应 Runtime 的最后错误记录，也可能返回此前异步启动的错误；不能把它理解成只能检查本次 launch。这里每个命令都是新进程、只有一次 kernel 启动，让归因简单一些。同步处发现错误表示它在这里被报告，不代表错误就是同步函数造成的。读取错误记录也不等于修复 GPU 执行故障，失败后本例直接退出，再用新进程运行另一模式。语义见 [CUDA Runtime API 12.9：Error Handling](https://docs.nvidia.com/cuda/archive/12.9.0/cuda-runtime-api/group__CUDART__ERROR.html)。

Compute Sanitizer 的 `memcheck` 是检查 GPU 非法访存的工具，能指出错误指令对应的源码位置及线程；它和逐元素数值校验互相补充。我们用 `-lineinfo` 编译以保留源码定位信息。本章不学习性能 profiler。

## 一个实验，三种模式

固定输入 `[256]` float32，正常输出仍为 `c[i] = a[i] + b[i]`。只改变故障模式，每个命令单独启动进程。

| 模式 | 改动与预测 | 要观察的证据 |
| --- | --- | --- |
| `ok` | 正常一个 block、256 个线程 | 256 项数值校验通过；memcheck 零错误 |
| `launch` | block 线程数设为设备上限加 1，本机为 1025 | 启动检查报告 `cudaErrorInvalidConfiguration`，程序非零退出 |
| `oob` | 正常计算之外，线程 0 额外写 `c[n]` | memcheck 报告越界写的位置、线程和 block |

`n=256` 时有效下标为 0～255，`c[256]` 已越界。这个例子保留所有合法输出，因此数值 PASS 也不能证明没有越界。普通运行时越界不一定崩溃，也不保证同步 API 一定报错；越界验收以 memcheck 为准。

## 你需要完成的修改

先运行现有骨架，它已有实际错误检查，不会为了练习而忽略 API 失败。`TODO(CH03-1)` 的宏目前用固定文字描述调用，请用 `#call` 将宏参数转换成源码字符串，保留实际 API 的单次求值及 `__FILE__`、`__LINE__`。这两个预定义宏提供调用位置，例如 `CUDA_CHECK(cudaMalloc(&d_a, bytes))` 失败时应能显示这一调用。

随后完成 `TODO(CH03-2)`：把 kernel 后两条直接调用 `check_cuda` 的旧写法换成 `CUDA_CHECK(...)`，分别保留原本检查的 API。不要删除同步检查，也不要把 `<<<...>>>` 启动表达式直接当成返回 `cudaError_t` 的普通 API。

采集并读懂越界报告后，完成 `TODO(CH03-3)`，删除故意添加的 `c[n]` 写入，重新编译，用同一个 `oob` 命令确认错误消失、数值仍通过。不改输入、reference 或合法计算来绕过校验。

建议 5 分钟预测、10 分钟读代码、20 分钟修改、15 分钟运行对照、10 分钟解释。运行前先写下：1025 个线程会在哪个检查点失败？数值全部正确能否排除额外越界写？

## 编译与运行

在项目根目录执行，修改源码后重新编译：

```bash
mkdir -p build/CH03
nvcc -std=c++17 -arch=sm_75 -lineinfo -Xcompiler=-Wall,-Wextra CH03/error_check.cu -o build/CH03/error_check
```

编译成功后，逐条执行以下命令；不要把预期失败的案例用 `&&` 串起来，否则后续命令不会执行。

```bash
./build/CH03/error_check ok
./build/CH03/error_check launch
compute-sanitizer --tool memcheck --padding 32 --error-exitcode 99 ./build/CH03/error_check ok
compute-sanitizer --tool memcheck --padding 32 --error-exitcode 99 ./build/CH03/error_check oob
```

`--padding 32` 在工具运行时为分配添加保护间隔，帮助发现相邻分配边界上的越界，不改变数组有效长度。`--error-exitcode 99` 让“应用返回成功但工具发现错误”的情况也返回非零；如果应用本身已失败，不要求一定返回 99。在 shell 中紧接命令执行 `echo $?` 可看退出码。

`launch` 的非零退出和修复前 `oob` 的 memcheck 错误都是故意故障案例的预期结果。读越界报告时只找 `Invalid __global__ write`、源码行、`thread (0,0,0)` 与 `block (0,0,0)`，不用理解完整 host backtrace。修复后重编译，再执行最后一条命令，应有数值 PASS 和 `ERROR SUMMARY: 0 errors`。

## 验收与范围

保留修复前后的输出，并用自己的话解释：为什么启动后检查一次，还要等待后再检查？为什么一个数值 PASS 的程序仍会被 memcheck 报错？指出本例的非法下标和错误报告的源码位置即可。

程序验证和个人解释都满足才记 DONE。骨架、故障案例和预检由 Codex 提供，用户负责宏的修改、检查点迁移和越界修复。到一小时仍有问题就记录阻塞，不扩展到错误恢复框架、异步调度细节或性能优化。与推理程序的联系是：错误可能在后续等待或拷贝时才显露，应结合检查点与工具报告定位。

## 官方资料与预检记录

API 签名核对本机 `/usr/local/cuda-12.9/include/cuda_runtime_api.h`。错误语义参考上方 Runtime API 12.9；工具说明参考 [Compute Sanitizer：Memcheck](https://docs.nvidia.com/compute-sanitizer/ComputeSanitizer/index.html#memcheck-tool)。该工具网页为滚动文档，本机版本及选项另以 `compute-sanitizer --version`、`--help` 核实。

预检结果见下方，原始命令和输出保存在 [preflight.txt](../../reports/CH03/preflight.txt)，报告与构建产物由 `.gitignore` 排除。正式源码保留练习；预检补全版只在临时目录生成并清理。没有计时、NSYS 或 NCU 采集，不作性能结论。

2026-09-20 实测：GTX 1650 / CC 7.5，NVCC 12.9.86，Compute Sanitizer 2025.2.1.0。正式骨架与临时补全、修复版编译均无警告。`ok` 全部 256 项通过，最大绝对误差 0，退出 0；memcheck 正常模式为 0 errors。`launch` 在启动检查处报 `cudaErrorInvalidConfiguration`，退出 1。

修复前 `oob` 在 memcheck 下报告 `error_check.cu:33` 的 4 字节非法 global 写入，线程和 block 均为 `(0,0,0)`；随后同步检查报告 `cudaErrorUnknown`，工具汇总 2 errors，外层退出 99。这是一次越界诊断及其后续 API 报错，不能读成两个独立越界，也不预设执行错误一定叫 `cudaErrorIllegalAddress`。临时补全版启动报错能显示 `cudaGetLastError()`；临时修复版 `oob` 数值误差 0、memcheck 0 errors、退出 0。普通不带工具的 `oob` 未运行，不推断其是否崩溃。以上仅为 Codex 工程预检，用户练习与解释待验收。
