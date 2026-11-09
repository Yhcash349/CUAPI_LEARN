#!/usr/bin/env bash
# 在任意目录调用均可；同一份源码只改变编译输出阶段。
# 用法：bash CH17/compile.sh [runtime|ptx|cubin]，省略参数默认 runtime。
# 本脚本只编译；执行 Runtime 程序、查看产物需另行运行对应命令。
set -euo pipefail
chapter_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$chapter_root"
if (( $# > 1 )); then
    printf 'Usage: bash CH17/compile.sh [runtime|ptx|cubin]\n' >&2
    exit 2
fi

mode="${1:-runtime}"
case "$mode" in
    runtime|ptx|cubin) ;;
    *) printf 'Usage: bash CH17/compile.sh [runtime|ptx|cubin]\n' >&2; exit 2 ;;
esac
mkdir -p build/CH17
flags=(-std=c++17 -O2 -lineinfo -Xcompiler=-Wall,-Wextra)

case "$mode" in
    runtime)
        # 显式把 sm_75 cubin 与 compute_75 PTX 都嵌入 host 可执行文件。
        nvcc "${flags[@]}" --gpu-architecture=compute_75 --gpu-code=sm_75,compute_75 \
            -Xptxas=-v,-warn-spills CH17/vector_add.cu -o build/CH17/vector_add
        ;;
    ptx)
        # 只输出 device PTX 文本；compute_75 指定前端使用的虚拟架构能力。
        nvcc "${flags[@]}" --ptx --gpu-architecture=compute_75 \
            CH17/vector_add.cu -o build/CH17/vector_add.ptx
        ;;
    cubin)
        # 只输出 sm_75 的 device 二进制；ptxas 同时报告寄存器与 spill 等资源。
        nvcc "${flags[@]}" --cubin --gpu-architecture=sm_75 \
            -Xptxas=-v,-warn-spills CH17/vector_add.cu -o build/CH17/vector_add.cubin
        ;;
esac
