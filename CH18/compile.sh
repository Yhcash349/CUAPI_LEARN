#!/usr/bin/env bash
# 本机 WSL2 / Toolkit 12.9 路径；仅构建 Driver host 程序，不生成或执行 cubin。
# 用法：bash CH18/compile.sh，可从任意目录调用。
set -euo pipefail
chapter_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$chapter_root"
if (( $# != 0 )); then
    printf 'Usage: bash CH18/compile.sh\n' >&2
    exit 2
fi
mkdir -p build/CH18
# cuda.h 来自 Toolkit；libcuda.so 来自 WSL 驱动，不能用 Toolkit 的 stubs 运行。
# 这是普通 C++ 编译，不需要链接 libcudart，也不需要为 host 指定 sm_75。
g++ -std=c++17 -O2 -g -Wall -Wextra -Wpedantic \
    -I/usr/local/cuda/include CH18/driver_vector_add.cpp \
    -L/usr/lib/wsl/lib -lcuda -o build/CH18/driver_vector_add
