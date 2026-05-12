#!/usr/bin/env bash

set -euo pipefail

ZIG="${1:-zig}"
ROOT_DIR="$(cd "$(dirname "$0")"/..; pwd)"

cd "$ROOT_DIR/program-test"

echo "Using Zig: $ZIG"
"$ZIG" version

# Always build from a clean slate. The SBPFv2 loader rejects programs
# with `.bss` / `.data` sections; a stale `.zig-cache` once let a
# broken `ErrorCode` design ship "green" because the cached `.so`
# predated the regression. Removing the cache here makes every test
# run an honest end-to-end build.
echo "Cleaning Zig build cache..."
rm -rf .zig-cache zig-out

"$ZIG" build --summary all --verbose

cargo test --manifest-path "$ROOT_DIR/program-test/Cargo.toml"
