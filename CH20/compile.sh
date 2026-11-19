#!/usr/bin/env bash
# 只构建本章；允许从其他目录调用。
set -euo pipefail
chapter_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$chapter_root"
if (( $# != 0 )); then
    printf 'Usage: bash CH20/compile.sh\n' >&2
    exit 2
fi
mkdir -p build/CH20
nvcc -std=c++17 -O2 -lineinfo -arch=sm_75 -Xcompiler=-Wall,-Wextra \
    CH20/async_pool.cu -o build/CH20/async_pool
