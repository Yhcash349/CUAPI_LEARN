#!/usr/bin/env bash
# 本机 sm_75 构建；只编译，不执行。可从任意工作目录调用。
set -euo pipefail
chapter_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$chapter_root"
if (( $# != 0 )); then
    printf 'Usage: bash CH19/compile.sh\n' >&2
    exit 2
fi
mkdir -p build/CH19
nvcc -std=c++17 -O2 -lineinfo -arch=sm_75 -Xcompiler=-Wall,-Wextra \
    CH19/memory_reuse.cu -o build/CH19/memory_reuse
