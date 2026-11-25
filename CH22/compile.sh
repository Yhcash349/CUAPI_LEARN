#!/usr/bin/env bash
# 只构建本章。VMM 使用 WSL 提供的真实 libcuda，kernel 由 nvcc 一起编入。
set -euo pipefail
chapter_root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
cd -- "$chapter_root"
if (( $# != 0 )); then
    printf 'Usage: bash CH22/compile.sh\n' >&2
    exit 2
fi
mkdir -p build/CH22
nvcc -std=c++17 -O2 -lineinfo -arch=sm_75 -Xcompiler=-Wall,-Wextra \
    CH22/vmm_grow.cu -L/usr/lib/wsl/lib -lcuda -o build/CH22/vmm_grow
