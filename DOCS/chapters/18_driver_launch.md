# Ch18：加载 cubin，用 Driver API 启动 vector add

Ch17 已经把 GPU 加法编译成独立 cubin，本章让一个普通 C++ host 程序打开它，按名字找到 `vector_add`，传入数组地址并启动。算法没有变化；主要变量是 host 使用 Runtime 启动还是 Driver 加载后启动。固定 `n=1000`、float32、grid=8、block=128、每数组4000字节，两条路径都与 CPU reference 比较，不做速度竞赛。

计划45～60分钟。只聚焦“context→module→function 的使用关系”和“显式启动与参数传递”两个知识点。[Driver 源码](../../CH18/driver_vector_add.cpp) 的两处练习已于2026-11-10按用户要求由Codex补全，下面保留原任务目标供对照复习；context、内存、校验、完成等待和释放均已提供。[构建脚本](../../CH18/compile.sh) 使用本机 WSL2/Toolkit 路径，不新增依赖。真实框架也会把编译后的 GPU 程序交给 Driver 启动，但本章不追踪框架或实现 Hook。

## 先预测并运行 Runtime 对照（约10分钟）

先预测：host 文件没有 `__global__` 定义，还能让 GPU 算加法吗？找到 `vector_add` 是否就代表已经执行？把 host 变量 `d_a` 的地址作为启动参数，会不会让 kernel 去读取 CPU 内存？

在项目根目录运行：

```bash
bash CH17/compile.sh runtime
bash CH17/compile.sh cubin
./build/CH17/vector_add
bash CH18/compile.sh
./build/CH18/driver_vector_add
```

前三条复用 Ch17 已有源码，得到 Runtime 对照与本章要加载的 sm_75 cubin。Ch18 有自己的 host 源码目录，但 GPU 程序刻意复用 `build/CH17/vector_add.cubin`，避免用两份 kernel 混淆“换启动路径”这个变量。不要把普通 host executable 或 SASS 文本传给模块加载函数。

当前正式版本已补齐并验证，正常运行会加载模块、找到入口并输出数值PASS。原骨架未补TODO(1)或只补第一处时提示 `GPU launch NOT RUN` 并退出2，仅为历史练习行为；当前不会再输出占位提示。修改后仍需重新编译；运行旧可执行文件不会自动使用修改后的host源码。

## 沿执行顺序读骨架（约10分钟）

context 可以先理解为“本进程在这块 GPU 上使用资源和提交工作的环境”。代码用 `cuInit(0)` 初始化 Driver、`cuDeviceGet` 选设备，再用 `cuDevicePrimaryCtxRetain` 保持对该设备 primary context 的使用，`cuCtxSetCurrent` 则让当前 CPU 线程的后续调用使用它。primary context 在进程内按设备管理，并与 CUDA Runtime 共享；retain 本身不会把它设为当前 context。这里采用 PLAN 已选定的 primary context，不另讲创建多个 context 或切换栈。[官方 primary context 语义](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-driver-api/group__CUDA__PRIMARY__CTX.html)。

module 是“已经加载的 GPU 程序包”，function 是“包内某个可启动入口的句柄”。句柄就是用来指认对象的值；`CUfunction` 不能当作普通 CPU 函数指针直接调用。加载与查找只准备程序，分配与上传只准备数据；真正提交 GPU 计算的是后面的 `cuLaunchKernel`。

```text
cuInit → 选 device → retain primary context → 设为 current
  → 加载 cubin 得到 module → 按名取出 function
  → 分配 d_a/d_b/d_c → H2D → 输出填 NaN 哨兵
  → 组织参数 → launch → 等待完成 → D2H → 全量校验
  → 释放 device 内存 → 卸载 module → 恢复 previous → release
```

`CUdeviceptr d_a` 保存的是 GPU 地址值，`a.data()` 指向 CPU 输入。`cuMemAlloc` 产生地址，`cuMemcpyHtoD` 把输入复制过去；`cuMemsetD8` 按字节填 `0xff`，使未写输出保留 NaN，校验时检查非有限值和数值误差。初始化、内存与释放都不要求本章重新实现。

| 此前 Runtime 源码中的工作 | 本章 Driver 源码中的表达 |
| --- | --- |
| 编译时关联 kernel 与可执行文件内 device image | 运行时从路径加载 module，按名查 function |
| `cudaMalloc` / `cudaMemcpy` | `cuMemAlloc` / `cuMemcpyHtoD` / `cuMemcpyDtoH` |
| `vector_add<<<grid, block>>>(...)` | function 句柄、参数数组与 `cuLaunchKernel` |
| `cudaDeviceSynchronize` | 本例 current context 上的 `cuCtxSynchronize` |
| `cudaError_t` / `CUDA_CHECK` | `CUresult` / `CU_CHECK` |

这张表只对应本例源码里的工作，不能据此推断一次 Runtime 调用必然对应一次同名 Driver 调用；这里没有采集内部调用链。[官方 Runtime/Driver 区别](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-runtime-api/driver-vs-runtime-api.html)。

## 原 TODO(1)：加载文件并找到入口（已完成，约5～10分钟复习）

`load_vector_add()` 已用 `CU_CHECK(cuModuleLoad(module, path))` 加载文件，再以 `CU_CHECK(cuModuleGetFunction(function, *module, "vector_add"))` 查找入口，成功后返回 `true`。对应本机 `/usr/local/cuda/include/cuda.h` 中的签名：

```cpp
CUresult cuModuleLoad(CUmodule* module, const char* fname);
CUresult cuModuleGetFunction(CUfunction* function, CUmodule module, const char* name);
```

注意函数参数 `module` 已经是 `CUmodule*`：加载函数需要输出位置，查入口函数需要加载得到的句柄值。结合 Ch16 的指针阅读经验，先说清这里何时使用 `module`、何时使用 `*module`。Ch17 的 `extern "C"` 保留了易查找的 `vector_add` 名称，入口参数顺序仍为 a/b/c/n。[官方 module API](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-driver-api/group__CUDA__MODULE.html)。

模块加载与查找成功后，当前程序会继续执行已完成的启动部分。路径默认相对于启动程序时的工作目录；构建脚本会自行切到项目根目录，host 程序不会。若从其他目录运行，请把 cubin 的绝对路径作为唯一参数传入。

## 原 TODO(2)：传参并启动（已完成，约10～15分钟复习）

`launch_vector_add()` 已构造 `void* args[] = {&d_a, &d_b, &d_c, &n}`，调用 `cuLaunchKernel`、检查返回值并返回 `true`，原占位和提示已删除。前三项参数是设备地址值，第四项是 int，顺序和类型都必须与 cubin 中的入口一致；无需手工填参数偏移或大小。

这里最容易混淆的是“参数的值”和“保存这个值的位置”。假设 CPU 变量 `d_a` 存在 host 地址 `0x1000`，其中的值是设备地址 `0x80000000`：参数数组对应项应给 Driver 一个指向 `d_a` 的指针，让它从 host 变量里复制出 `0x80000000` 这个值。kernel 最终拿到的是设备地址，之后才从 GPU 数组读取 float；它不会收到 `0x1000` 去读取 CPU 变量。`n` 也同理，Driver 需要指向保存1000的 int 的位置。不要通过把设备地址强转成 host 指针来代替这个步骤。[官方 kernelParams 语义](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-driver-api/group__CUDA__EXEC.html)。

本机签名中的参数依次为：

```cpp
CUresult cuLaunchKernel(CUfunction f,
    unsigned gridDimX, unsigned gridDimY, unsigned gridDimZ,
    unsigned blockDimX, unsigned blockDimY, unsigned blockDimZ,
    unsigned sharedMemBytes, CUstream hStream,
    void** kernelParams, void** extra);
```

用传入的 `grid` 和 `block` 作为 X 维，Y/Z 维均为1，dynamic shared 为0，stream 为 `nullptr`（本章单队列默认 stream），`kernelParams` 使用参数数组，`extra` 为 `nullptr`。本章不使用打包参数缓冲，也不手写 ABI 对齐。

提交返回后，骨架在 main 中调用 `cuCtxSynchronize`，再回读和校验。`CU_CHECK(cuLaunchKernel(...))` 检查提交调用的结果，不等于已证明 GPU 成功完成，仍需检查完成边界。和 Ch13 相同，CPU 提交返回与 GPU 完成是两件事。

## 重编译、验证并对照（约10分钟）

```bash
bash CH18/compile.sh
./build/CH18/driver_vector_add
compute-sanitizer --tool memcheck --padding 32 --error-exitcode 99 \
    ./build/CH18/driver_vector_add
./build/CH17/vector_add
ldd build/CH18/driver_vector_add
```

完成版本应显示 module loaded、function found，然后 `checked=1000 mismatches=0 max_abs_error=0` 与 PASS。memcheck 应报告零错误。kernel 仍是每线程加一个数：block1/thread3 处理 i=131，最后24个线程由已有边界保护退出。本章没有 shared 协作或 barrier，不新增 racecheck/synccheck 门槛。

`ldd` 用来查看程序实际依赖的动态库，本机 Driver host 应加载 `/usr/lib/wsl/lib/libcuda.so.1`，没有 `libcudart` 依赖。构建用 g++ 处理普通 `.cpp`，Toolkit 只提供 `cuda.h`，驱动提供可运行的 libcuda。host 编译命令不需要 `-arch=sm_75`，目标 GPU 已在 Ch17 cubin 构建时确定。若迁移机器需核对 include/lib 路径与 cubin 架构，不为本节扩建跨平台构建系统。

缺失文件时，正式版本会在 `cuModuleLoad` 报 `CUDA_ERROR_FILE_NOT_FOUND` 并退出1；错误入口名称通常在 `cuModuleGetFunction` 报 `CUDA_ERROR_NOT_FOUND`。先查本轮实际 cubin 路径、入口拼写和构建，不把所有加载问题都归因于驱动。`CU_CHECK` 是短练习的失败即退出 helper；API 错误路径由进程退出收尾，不是生产级异常资源管理模板。正常路径显式释放本程序资源。

## 用自己的话验收（约5分钟，可与验证合并）

指出哪份 cubin 被实际加载、哪个调用得到入口、哪个调用才提交计算；说明 context、module、function 各自在这条执行链上负责什么。用一个具体地址例子解释为什么参数数组存的是参数变量的地址，而 kernel 接收到的仍是 GPU 地址值，再指出等待完成与回读的先后关系。

亲自重编译、运行 Runtime/Driver 两条路径及 memcheck，并说明它们计算相同结果，却不能仅凭源码表格证明 Runtime 内部调用的一一对应或性能高低。到一小时仍未完成就记录阻塞；不追加显式新 context、PTX JIT、首次加载开销、缓存、Hook 或 NSYS Inventory。个人运行和独立解释待验收，Codex 预检不代替学习完成。

## Codex 教学预检：2026-11-09（生成时的历史记录）

现场为 GTX1650 / CC7.5 / 14SM / 4096MiB、KMD610.88、DriverAPI13030，NVCC12.9.86、g++13.3.0、Compute Sanitizer2025.2.1.0，CUDA_LAUNCH_BLOCKING unset。重新构建 Ch17 Runtime 与 sm_75 cubin，并构建正式 Ch18 骨架；均无编译警告。Runtime 对照全量1000项正确、最大误差0。正式骨架按预期提示 TODO(1) 并退出2；构建脚本从 `/tmp` 调用成功，多余参数和 host 程序多余参数均退出2。

Codex 在 `build/CH18/preflight/` 临时补全两处 API，先验证只补模块部分时退出2且未启动，再验证完整版本实际加载 `build/CH17/vector_add.cubin`。完整版本全量1000项 mismatches=0、最大误差0、退出0，memcheck padding32 零错误；从 `/tmp` 通过 cubin 绝对路径启动同样通过。缺失文件对照按预期报 CUDA_ERROR_FILE_NOT_FOUND、退出1。ldd 确认正式骨架与临时完整程序加载 WSL libcuda.so.1，均无 libcudart 依赖。

完整环境、命令、工作目录、正式与临时源码、输出、预期/实际退出码及 SHA-256 见 [预检日志](../../reports/CH18/preflight-2026-11-09.txt)。临时源码已删除，其内容保留在日志用于复盘；隔离的 module_only/complete 可执行文件保留为预检证据，不替代正式练习构建。正式源码仍有两处 TODO，正式 Driver 路径的 GPU 加法为 NOT RUN；这里的 Driver 数值和内存检查结论仅来自临时完整版本。build/reports 默认不入 Git。

本章没有计时、NSYS、NCU、PTX 加载/JIT、racecheck 或 synccheck，不做性能与内部映射结论。源码、讲义、预检由 Codex 提供；用户实现、个人运行和独立解释尚待验收，Ch18 保持 RUNNING、掌握度未评估，实际学习与工程执行耗时未记录。按 PLAN 阶段D推进，无范围偏离，也无需额外 Claude 审阅作为本节前置条件。

## 正式补全与验证：2026-11-10

按用户要求，Codex补全两处模块/启动练习，删除正式源码中的TODO和占位输出。保留已有bool接口，成功返回true，API错误经CU_CHECK报错退出；context、内存和校验流程不变。上节“正式Driver未执行/留有两处TODO”仅描述11月9日生成时状态，当前正式版本已经实际加载并执行Ch17 cubin。

现场GTX1650 / CC7.5 / 14SM、KMD610.88、DriverAPI13030，NVCC12.9.86、g++13.3.0、Compute Sanitizer2025.2.1.0，CUDA_LAUNCH_BLOCKING unset。重建Ch17 Runtime/cubin及正式Driver host均无警告、退出0。Runtime与Driver的1000个float32输出均mismatches=0、最大误差0、PASS；正式Driver memcheck padding32零错误、退出0。grid8/block128、每数组4000字节；两条路径使用相同输入与CPU reference。

正式程序从/tmp传入cubin绝对路径启动通过；缺失文件按预期报CUDA_ERROR_FILE_NOT_FOUND、退出1，host多余参数退出2。ldd确认使用WSL libcuda.so.1、无libcudart依赖。完整命令、版本、cwd、输出、退出码及源码/产物哈希见 [正式日志](../../reports/CH18/completed-2026-11-10.txt)。本次未新建临时实现，未进行性能计时、profiler采集或PTX JIT，不扩展Runtime内部调用映射结论。

两处实现、编译与验证均由Codex完成，个人运行和完整独立解释仍待验收；Ch18保持RUNNING、掌握度未上调，实际学习和工程执行耗时未记录。无计划偏离、新依赖或额外Claude审阅需要。

## previous/context打印探针：2026-11-10

按用户要求，在三次context API前后插入 `print_context_probe()`，并在恢复/释放时再打印。探针使用公开查询API，无需新建context或启动新的CPU线程。重编译并运行即可看到输出：

```bash
bash CH18/compile.sh
./build/CH18/driver_vector_add
```

先看第一条 `variables`：`&previous` / `&context` 是main中两个host变量的地址，`sizeof(CUcontext)=8` 是本机句柄变量的字节数，不是驱动内部context对象大小。随后每阶段的 `previous` / `context` 是变量保存的句柄值；`current` 由 `cuCtxGetCurrent` 重新查询，代表发起本次调用的CPU线程当前使用哪个context。`cpu_tid`由Linux/WSL的gettid查询，是OS线程编号，不是CPU核编号或CUDA kernel线程编号。

本次普通运行的实际关系如下，H代表本次非空句柄0x5635a1dd03f0，仅为缩写：

| 阶段 | previous | context | 线程current | primary_active |
| --- | --- | --- | --- | --- |
| after_get | 空 | 空 | 空 | 0 |
| after_retain | 空 | H | 空 | 1 |
| after_set | 空 | H | H | 1 |
| after_restore | 空 | H | 空 | 1 |
| after_release | 空 | 空 | 空 | 0 |

CPU线程执行main中的API，GPU上的1024个kernel线程执行加法；驱动为CPU调用线程记录current绑定，使后续模块加载、分配等操作知道使用哪个资源环境。context从功能上关联设备、GPU内存分配、模块/函数、stream/event等对象和配置；previous/context局部变量仅持有指认它的句柄，不包含这些资源的完整内容。不能通过 `*context` 查看内部字段：cuda.h只公开不透明类型，内部布局不属于可访问接口。[官方context查询与绑定](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-driver-api/group__CUDA__CTX.html)。

retain后H非空但current为空，说明取得使用引用没有改变当前线程绑定；set后current=H才让后续操作使用它。restore只恢复线程原有绑定，primary仍active；release后本次active归零。release不改写局部变量，所以代码显式执行 `context = nullptr` 再打印。地址和TID每次运行可不同，表中空值/初始状态是本例独立进程实测，不要求所有嵌入程序都相同。

`current_device=0`查询的是当前context关联设备；无current时跳过相关查询。primary_active是primary context的活跃状态，不能判断GPU是否正在执行kernel。flags是API返回的配置位，本次primary_flags=0x0、current_flags=0x8，不能当成GPU利用率、任务数或内存用量，也未据其差异推断内部机制。[官方primary状态查询](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-driver-api/group__CUDA__PRIMARY__CTX.html)。

本次重新构建无警告，保留原n1000/float32/grid8/block128；全量mismatches0、最大误差0、PASS，memcheck padding32零错误。完整版本、源码/cubin/可执行文件哈希、命令及两次运行的原始输出见 [探针日志](../../reports/CH18/context-probe-2026-11-10.txt)。探针增加printf和查询，不做性能测量；没有读取内部对象内存，也未将查询演示记为用户已掌握。
