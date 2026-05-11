#!/usr/bin/env bash

set -euo pipefail

ZIG="${1:-zig}"
ROOT_DIR="$(cd "$(dirname "$0")"/..; pwd)"

cd "$ROOT_DIR/program-test"

echo "Using Zig: $ZIG"
"$ZIG" version

# Extra zig build args (e.g. -Dbuild-program) can be passed via ZIG_BUILD_ARGS env var.
EXTRA_ARGS="${ZIG_BUILD_ARGS:-}"

# shellcheck disable=SC2086
"$ZIG" build $EXTRA_ARGS --summary all --verbose

cargo test --manifest-path "$ROOT_DIR/program-test/Cargo.toml"
