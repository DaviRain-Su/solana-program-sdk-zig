#!/usr/bin/env bash

set -euo pipefail

ZIG="${1:-zig}"
ROOT_DIR="$(cd "$(dirname "$0")"/..; pwd)"
ELF2SBPF_BIN="${2:-${ELF2SBPF_BIN:-}}"

if [[ -z "$ELF2SBPF_BIN" ]]; then
  ELF2SBPF_BIN="$($ROOT_DIR/scripts/ensure-elf2sbpf.sh)"
fi

cd "$ROOT_DIR/program-test"
"$ZIG" build -Delf2sbpf-bin="$ELF2SBPF_BIN" --summary all --verbose
cargo test --manifest-path "$ROOT_DIR/program-test/Cargo.toml"
