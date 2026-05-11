#!/usr/bin/env bash

set -euo pipefail

ZIG="${1:-zig}"
ROOT_DIR="$(cd "$(dirname "$0")"/..; pwd)"

cd "$ROOT_DIR/program-test"

echo "Using Zig: $ZIG"
"$ZIG" version

"$ZIG" build --summary all --verbose

cargo test --manifest-path "$ROOT_DIR/program-test/Cargo.toml"
