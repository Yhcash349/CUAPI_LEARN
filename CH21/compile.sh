#!/usr/bin/env bash
# 只构建本章；允许从其他目录调用。
set -euo pipefail
chapter_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$chapter_root"
if (( $# != 0 )); then
    printf 'Usage: bash CH21/compile.sh\n' >&2
    exit 2
fi
mkdir -p build/CH21
nvcc -std=c++17 -O2 -lineinfo -arch=sm_75 -Xcompiler=-Wall,-Wextra \
    CH21/cross_stream_lifetime.cu -o build/CH21/cross_stream_lifetime
