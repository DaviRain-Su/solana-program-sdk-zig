#!/bin/bash
# Solana BPF 编译脚本

set -e

echo "Building Solana BPF program with Zig..."

# 检查是否提供了源文件
if [ $# -eq 0 ]; then
    echo "Usage: $0 <source-file>"
    echo "Example: $0 examples/hello-world/main.zig"
    exit 1
fi

SOURCE_FILE=$1
OUTPUT_NAME=$(basename "$SOURCE_FILE" .zig)

# 创建输出目录
mkdir -p target/bpf

# 编译为 BPF 目标
# 注意：Zig 目前支持 bpfel (little-endian) 和 bpfeb (big-endian)
# Solana 使用 little-endian BPF
echo "Compiling $SOURCE_FILE to BPF..."
zig build-lib \
    -target bpfel-freestanding \
    -O ReleaseSmall \
    -fstrip \
    -dynamic \
    --name "$OUTPUT_NAME" \
    -I src \
    "$SOURCE_FILE" \
    -femit-bin="target/bpf/${OUTPUT_NAME}.so"

echo "Build complete: target/bpf/${OUTPUT_NAME}.so"

# 如果安装了 Solana CLI，显示程序大小
if command -v solana &> /dev/null; then
    echo ""
    echo "Program size:"
    ls -lh "target/bpf/${OUTPUT_NAME}.so"
fi