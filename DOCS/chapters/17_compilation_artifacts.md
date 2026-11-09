# Ch17：同一份 kernel 的 PTX 与 cubin

本章用 45～60 分钟回答：之前一条 `nvcc ... -o ...` 命令把什么交给了 GPU？沿用 Ch02 的 vector add，不重写算法；原练习是补两条编译命令，从同一份源码生成不同阶段的产物，再找到其中的同一个 kernel。2026-11-09 已按用户要求由 Codex 补全命令，当前可直接运行并对照阅读。主要变量是**编译输出阶段**，输入、算法和本机目标能力保持一致。本章没有性能对照，不需要 warmup、Event、NSYS 或 NCU。

先修只需 Ch02 的索引与边界、Ch03 的错误检查，以及平时使用过的 nvcc 命令。相关推理用途是一句连接：框架最终也需要为 GPU 准备可执行的 device code，理解这些产物有助于区分源码、编译表示与实际加载对象。

## 先看程序如何执行

入口是 [CH17/vector_add.cu](../../CH17/vector_add.cu)。host 准备 a/b 和 CPU double reference，分配显存，上传输入，启动 vector_add，等完成后回读 c 并校验所有 1000 项。每个数组是 float32、4000 字节，grid=8、block=128，共 1024 个线程，最后 24 个线程被 `i < n` 挡住。例如 block1/thread3 得到 i=131，从 a[131] 和 b[131] 取数，写入 c[131]；最后一个有效线程为 block7/thread103，i=999。

kernel 已完整提供，因为索引和加法是旧知识。本章新增 `extern "C"`，让产物中的入口保持易查找的 `vector_add` 名称，供下一章按名加载；它不改变 GPU 执行方式，也不表示可以像普通 CPU 函数一样调用 kernel。本章固定入口合同为 `vector_add(const float* a, const float* b, float* c, int n)`，Ch18 按这个次序传参数。

## 两种表示与一条编译路径

**PTX 是尚需进一步翻译的 GPU 程序文本；cubin 是面向指定 GPU 架构的 device 二进制文件。** SASS 则是工具把 cubin 中机器指令反汇编后显示的人类可读形式，不是另一段手写 CUDA C++。

```text
CH17/vector_add.cu
  ├─ device 部分 → PTX（文本，中间表示）→ 汇编/优化 → cubin（sm_75 二进制）
  └─ host 部分  → host 编译器 → CPU 代码

普通 nvcc 构建：CPU 代码 + 嵌入的 device code + Runtime 支持 → 可执行文件
--ptx / --cubin：只输出 device 产物，丢弃 host 代码
```

这里画的是简化的逻辑路径，不是要求你手动调用 nvcc 内部每个工具。生成 cubin 的命令直接输入 `.cu` 即可，不要求先在磁盘生成 `.ptx`。把 `.cu` 同时交给 `--ptx` 和 `--cubin`，是观察同一算法的两个阶段；两种产物都不包含能由操作系统直接运行的 host `main()`。

| 本章出现的名称 | 读法与作用 |
| --- | --- |
| `--gpu-architecture=compute_75` | 编译前端采用的虚拟架构能力；本章用于 PTX 输出 |
| `--gpu-architecture=sm_75` | nvcc 针对真实架构的便捷写法，本章用于单目标 cubin |
| `--ptx` | 只生成 device PTX 文本 |
| `--cubin` | 只生成 device cubin 二进制 |
| `--gpu-code=sm_75,compute_75` | 本章 Runtime 构建显式嵌入 sm_75 cubin 和 PTX 两种 image |
| `.version` / `.target` / `.entry` | PTX 版本、目标能力与 kernel 入口声明，不是 host 函数调用 |

`compute_75` 与 `sm_75` 不是文件扩展名。尤其注意：用 compute_75 生成的 PTX 文本仍会写 `.target sm_75`，不能因此把该文本当成 cubin。PTX 的 `.version` 也不是 GPU compute capability 或 Toolkit 版本的另一种写法。

PTX 可以在合适的驱动上进一步编译到目标 GPU，但受到 PTX 版本、目标能力和驱动支持等条件限制；cubin 也有二进制兼容规则，不能简单说任意 GPU 都能运行。首轮只使用本机 CC7.5；不做跨架构验证、强制 JIT、缓存分析或冷启动比较。

## 先预测，再运行已有 Runtime 骨架（约 10 分钟）

先写下预测：仅生成 PTX/cubin 会执行 GPU 加法吗？两种文件里会保留 host main 吗？反汇编是否必然与 C++ 每行或 PTX 每条一一对应？

在项目根目录运行：

```bash
bash CH17/compile.sh runtime
./build/CH17/vector_add
compute-sanitizer --tool memcheck --padding 32 --error-exitcode 99 ./build/CH17/vector_add
```

脚本的 runtime 分支已完整提供；编译启用 C++17、优化、lineinfo、host 警告和 ptxas 资源报告，固定 sm_75/compute_75。正常程序应显示 checked=1000、mismatches=0、max_abs_error=0、PASS。输出先填 NaN 哨兵，再同时检查数值与非有限值。memcheck 验证这个 Runtime 构建的内存访问，不等于已经加载并执行了外部 cubin。

## 两个编译阶段（原练习约 15 分钟）

打开 [CH17/compile.sh](../../CH17/compile.sh)。`flags` 是复用的 Bash 参数数组，使用 `"${flags[@]}"` 将每个编译选项作为一个独立参数传给 nvcc。原 ptx/cubin 两处分支练习已补全，删除了提示与 `exit 2` 占位；kernel、输入、校验及 runtime 构建命令保持不变。下面保留原任务目标，供对照源码复习。

**原 TODO(1)：输出 PTX，现已完成。** 输入仍为 `CH17/vector_add.cu`，使用现有 flags；以 `--ptx --gpu-architecture=compute_75` 选择 PTX 阶段与虚拟架构，`-o` 指向 `build/CH17/vector_add.ptx`。运行：

```bash
bash CH17/compile.sh ptx
```

**原 TODO(2)：输出 cubin，现已完成。** 同一输入与 flags；以 `--cubin --gpu-architecture=sm_75` 选择 cubin 阶段与真实架构，保留 `-Xptxas=-v,-warn-spills`，`-o` 指向 `build/CH17/vector_add.cubin`。运行：

```bash
bash CH17/compile.sh cubin
```

当前正式脚本三种有效模式都应编译成功、退出0；原骨架提示 TODO 并退出2仅为历史行为。只创建文件名、改扩展名或保留旧文件均不证明生成成功；需检查命令退出状态及本轮实际内容。下一章复用 `build/CH17/vector_add.cubin`，不要改变入口名称与参数顺序。`build/` 是可重新生成的本地产物，不默认进 Git。

## 看产物，不背指令（约 15 分钟）

成功生成后执行：

```bash
file build/CH17/vector_add build/CH17/vector_add.ptx build/CH17/vector_add.cubin
sed -n '1,100p' build/CH17/vector_add.ptx
mkdir -p reports/CH17
cuobjdump --dump-sass build/CH17/vector_add.cubin > reports/CH17/cubin-sass.txt
sed -n '1,100p' reports/CH17/cubin-sass.txt
```

在 PTX 里找到 `.version`、`.target`、`.address_size` 和 `.visible .entry vector_add`；入口有三个指针参数与一个 int 参数。找到线程/块索引、边界判断、两次浮点读取、一次加法和一次写入的大致对应位置即可。不要把 PTX `.reg` 声明个数当成最终每线程硬件寄存器数。

在 SASS 文本中找到 `code for sm_75`、`Function : vector_add` 以及带指令偏移和编码的几行。认识它来自 cubin 就达成本章主要目标，不要求逐条解释寄存器、调度字段、十六进制编码或比较指令数。编译优化会重排或合并操作，源码、PTX 与 SASS 不承诺一一对应。

再看之前的普通可执行文件：

```bash
cuobjdump --list-elf build/CH17/vector_add
cuobjdump --dump-ptx build/CH17/vector_add > reports/CH17/runtime-ptx.txt
cuobjdump --dump-sass build/CH17/vector_add > reports/CH17/runtime-sass.txt
```

本章 runtime 命令明确嵌入两种 image，因而既能看到 PTX，也能看到 sm_75 的机器码。**普通可执行文件包含 device image，不需要旁边另放一份同名 cubin 才能运行。** 当前 Runtime 程序不会自动加载你刚生成的独立 cubin；外部模块加载留给 Ch18。`cuobjdump --dump-ptx` 提取已嵌入的 PTX，不能把一个只有机器码的 cubin 还原为最初的 PTX。

如还剩时间，可运行 `nvdisasm build/CH17/vector_add.cubin` 看另一种反汇编显示；它只接受 cubin，不接受普通 host executable。首轮用 cuobjdump 即可，不再引入 ELF 节表、重定位、链接细节或 SASS 优化。

## 用自己的话验收（约 10 分钟）

指出两条编译命令、各自目标与输出，沿 `.cu → PTX → cubin` 说出哪一步得到指定 GPU 的机器码，解释为什么 PTX 中出现 sm_75 也仍是中间表示。展示本轮生成的入口 vector_add 与 SASS 中的同名函数，并解释为什么这些 device-only 文件没有可直接运行的 host main。

最后运行 Runtime 校验，说明它验证的是哪份构建、是否验证了外部 cubin 加载；区分 host 可执行文件、嵌入的 device image 和独立 cubin。能指出 ptxas 报告的资源信息即可，不从寄存器数、文件大小或指令数推断性能。到一小时仍未完成就记录阻塞；Codex 预检不替代个人操作与独立解释，状态保持 RUNNING。

## 官方资料

编译选项已核对本机 `nvcc --help` 和 [NVCC 12.9.1：编译阶段](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-compiler-driver-nvcc/index.html#supported-phases)、[GPU 架构选项](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-compiler-driver-nvcc/index.html#gpu-architecture-arch)；产物和查看工具参考 [CUDA Binary Utilities 12.9.1：CUDA Binary 与工具区别](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-binary-utilities/index.html#what-is-a-cuda-binary)。编译与兼容性边界参考 [Programming Guide 12.9.1：Compilation with NVCC](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-c-programming-guide/index.html#compilation-with-nvcc)。按当前问题阅读相应段落，不通读工具手册。

## Codex 教学预检：2026-11-09（生成时的历史记录）

现场为 GTX1650 / CC7.5 / 14SM、KMD610.88、Runtime12090、DriverAPI13030，NVCC12.9.86、cuobjdump12.9.82、nvdisasm12.9.88、Compute Sanitizer2025.2.1.0，CUDA_LAUNCH_BLOCKING unset。正式 Runtime 构建编译无警告，1000 个 float32 全量校验 mismatches=0、最大绝对误差0，memcheck（padding32）零错误，均退出0。ptxas 报告12 registers/thread、0 barriers、0 stack/spill；资源数不是性能结论。

正式脚本语法检查通过；ptx/cubin 分支各提示对应 TODO 并退出2，符合未填练习的预期。非法模式和多余参数也退出2。教学方临时仅补齐两条命令并将输出隔离到 `build/CH17/preflight/`，生成 [PTX](../../build/CH17/preflight/vector_add.ptx) 与 [cubin](../../build/CH17/preflight/vector_add.cubin) 均退出0。PTX 为1334字节，含 `.version 8.8`、`.target sm_75`、`.address_size 64` 和 `.visible .entry vector_add`，四参数为3×u64与1×u32；cubin 为4456字节，file 识别为NVIDIA CUDA ELF，符号与反汇编均找到 vector_add、目标sm_75。临时 cubin 的 ptxas 资源与 Runtime 构建一致；文件大小只用于辨识产物，不推断效率。

cuobjdump 与 nvdisasm 查看独立 cubin 均成功，Runtime 可执行文件也能提取到嵌入的PTX和sm_75 SASS。Runtime 程序没有加载临时 cubin；外部 PTX/cubin 的实际加载执行 **NOT RUN**，属于 Ch18。本轮没有计时、NSYS、NCU、racecheck 或 synccheck；kernel 不含 shared 协作或 barrier，不追加这些验证作为本章要求。

完整命令、两份正式源码SHA-256、临时脚本内容、版本、原始输出、预期/实际退出码及产物哈希见 [预检日志](../../reports/CH17/preflight-2026-11-09.txt)。另保留 [cubin SASS](../../reports/CH17/preflight-cubin-sass.txt)、[cubin符号](../../reports/CH17/preflight-cubin-symbols.txt)、[nvdisasm输出](../../reports/CH17/preflight-cubin-nvdisasm.txt)、[Runtime嵌入PTX](../../reports/CH17/preflight-runtime-ptx.txt) 和 [Runtime嵌入SASS](../../reports/CH17/preflight-runtime-sass.txt)。build/reports 均为本机产物、默认不进Git；预检目录不替代用户练习应生成的 `build/CH17/vector_add.ptx` 和 `.cubin`。临时补全脚本已删除，正式脚本保留两处TODO。

源码、讲义、编译与验证由Codex提供；用户填写命令、个人运行/查看及独立解释均待验收，Ch17保持RUNNING，掌握度未评估，实际学习与工程执行耗时未记录。按 PLAN 阶段D推进，无范围偏离、新依赖或例行Claude审阅前置要求，没有生成Ch18内容。

## 正式补全与验证：2026-11-09

按用户要求，Codex 补全 `compile.sh` 两处命令：ptx 分支用 `--ptx --gpu-architecture=compute_75`，cubin 分支用 `--cubin --gpu-architecture=sm_75` 并保留 ptxas 资源报告。删除占位提示与退出2，新增脚本用法及“只编译”的中文注释。Runtime 命令、CUDA 源码、输入和校验不变；上节临时预检是历史证据，当前正式脚本已无未完成TODO。

现场仍为 GTX1650 / CC7.5 / 14SM、KMD610.88、Runtime12090、DriverAPI13030，NVCC12.9.86、Bash5.2.21、Compute Sanitizer2025.2.1.0，CUDA_LAUNCH_BLOCKING unset。正式 Bash 语法检查、默认 runtime 构建、ptx/cubin 构建均退出0；cubin 分支从 `/tmp` 通过脚本绝对路径调用也成功。非法模式及多余参数按预期退出2。两种机器码构建无警告，ptxas 各12 registers/thread、0 barriers、0 stack/spill。重编译的 Runtime 全量1000项正确、最大误差0、memcheck padding32零错误。

正式 PTX 为1334字节，含 `.version 8.8`、`.target sm_75`、`.address_size 64` 与 `.visible .entry vector_add`；cubin 为4456字节的NVIDIA CUDA ELF，符号和SASS确认同名入口与sm_75目标。两份device产物SHA-256与生成时隔离预检产物分别相同，当前路径为 `build/CH17/vector_add.ptx`、`build/CH17/vector_add.cubin`。Runtime内嵌PTX也提取成功；仍未加载执行外部PTX/cubin，不扩展Ch18内容或性能测量。

完整版本、命令、工作目录、源码/产物哈希、输出及退出码见 [正式日志](../../reports/CH17/completed-2026-11-09.txt)；另保留 [cubin SASS](../../reports/CH17/completed-cubin-sass-2026-11-09.txt)、[符号](../../reports/CH17/completed-cubin-symbols-2026-11-09.txt)、[Runtime PTX](../../reports/CH17/completed-runtime-ptx-2026-11-09.txt) 和 [Bash执行跟踪](../../reports/CH17/completed-shell-trace-2026-11-09.txt)。脚本阅读方法已写入 NOTE 的 Ch17 入口，包括 `$1`、默认参数、目录定位、flags数组、case分支及 `bash -n`/`bash -x` 的区别。实现和验证由Codex完成，个人运行/查看与独立解释待验收，Ch17保持RUNNING；实际学习及工程执行耗时未记录，无新依赖或计划偏离，无额外Claude审阅需要。
