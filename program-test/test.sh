#!/usr/bin/env bash

ZIG="$1"
ROOT_DIR="$(cd "$(dirname "$0")"/..; pwd)"
if [[ -z "$ZIG" ]]; then
  ZIG="$ROOT_DIR/solana-zig/zig"
fi

set -e
cd $ROOT_DIR/program-test

echo "=== Step 1: Generate Rust test vectors ==="
cargo run --bin generate-vectors

echo "=== Step 2: Build Zig program ==="
$ZIG build --summary all --verbose

echo "=== Step 3: Run Rust tests ==="
cargo test --manifest-path "$ROOT_DIR/program-test/Cargo.toml"

echo "=== Step 4: Run Zig integration tests ==="
cd $ROOT_DIR/program-test/integration
$ZIG build test --summary all

echo "=== All tests passed! ==="
