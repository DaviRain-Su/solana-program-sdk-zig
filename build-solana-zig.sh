#!/usr/bin/env bash

# build-solana-zig.sh - Build the project using solana-zig compiler

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")"; pwd)"
ZIG_PATH="$SCRIPT_DIR/solana-zig/zig"

# Check if solana-zig is installed
if [[ ! -f "$ZIG_PATH" ]]; then
    echo "solana-zig not found at $ZIG_PATH"
    echo "Please run: ./install-solana-zig.sh"
    exit 1
fi

echo "Building with solana-zig at $ZIG_PATH"

# Run the build command with solana-zig
"$ZIG_PATH" build "$@"

echo "Build completed successfully"