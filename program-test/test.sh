#!/usr/bin/env bash

set -euo pipefail

ZIG="${1:-zig}"
ELF2SBPF_BIN="${2:-${ELF2SBPF_BIN:-$HOME/dev/active/elf2sbpf/zig-out/bin/elf2sbpf}}"
ROOT_DIR="$(cd "$(dirname "$0")"/..; pwd)"

cd "$ROOT_DIR/program-test"
"$ZIG" build -Delf2sbpf-bin="$ELF2SBPF_BIN" --summary all --verbose
cargo test --manifest-path "$ROOT_DIR/program-test/Cargo.toml"
