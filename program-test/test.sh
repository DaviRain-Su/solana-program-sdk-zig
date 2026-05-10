#!/usr/bin/env bash

set -euo pipefail

ZIG="${1:-zig}"
ROOT_DIR="$(cd "$(dirname "$0")"/..; pwd)"
ELF2SBPF_BIN="${2:-${ELF2SBPF_BIN:-}}"

cd "$ROOT_DIR/program-test"

# Detect if we're using the solana-zig fork (has sbf target support)
is_solana_zig() {
  local zig_bin="$1"
  [[ -x "$zig_bin" ]] || return 1
  local targets_out
  targets_out="$("$zig_bin" targets 2>/dev/null)" || return 1
  grep -q '"sbf",' <<<"$targets_out" || return 1
  return 0
}

if is_solana_zig "$ZIG"; then
  echo "Detected solana-zig fork — using buildProgram (sbf target) path"
  "$ZIG" build --summary all --verbose
else
  echo "Using stock Zig — using buildProgramElf2sbpf (bpf + elf2sbpf) fallback path"
  if [[ -z "$ELF2SBPF_BIN" ]]; then
    ELF2SBPF_BIN="$($ROOT_DIR/scripts/ensure-elf2sbpf.sh)"
  fi
  "$ZIG" build -Delf2sbpf-bin="$ELF2SBPF_BIN" --summary all --verbose
fi

cargo test --manifest-path "$ROOT_DIR/program-test/Cargo.toml"
