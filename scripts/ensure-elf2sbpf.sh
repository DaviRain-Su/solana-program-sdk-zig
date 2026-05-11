#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
TOOLS_DIR="${ELF2SBPF_TOOLS_DIR:-$ROOT_DIR/.tools}"
INSTALL_DIR="$TOOLS_DIR/elf2sbpf"
BIN_PATH="$INSTALL_DIR/bin/elf2sbpf"
REPO_URL="https://github.com/DaviRain-Su/elf2sbpf.git"

if [[ -n "${ELF2SBPF_BIN:-}" ]]; then
  if [[ -x "$ELF2SBPF_BIN" ]]; then
    printf '%s\n' "$ELF2SBPF_BIN"
    exit 0
  fi
  echo "ELF2SBPF_BIN is set but not executable: $ELF2SBPF_BIN" >&2
  exit 1
fi

if [[ -x "$BIN_PATH" ]]; then
  printf '%s\n' "$BIN_PATH"
  exit 0
fi

if command -v elf2sbpf >/dev/null 2>&1; then
  command -v elf2sbpf
  exit 0
fi

if ! command -v zig >/dev/null 2>&1; then
  echo "zig is required to build elf2sbpf automatically" >&2
  exit 1
fi

mkdir -p "$TOOLS_DIR"

SOURCE_DIR=""
if [[ -d "$ROOT_DIR/../elf2sbpf/.git" ]]; then
  SOURCE_DIR="$ROOT_DIR/../elf2sbpf"
else
  SOURCE_DIR="$INSTALL_DIR/src"
  if [[ ! -d "$SOURCE_DIR/.git" ]]; then
    rm -rf "$SOURCE_DIR"
    git clone --depth 1 "$REPO_URL" "$SOURCE_DIR"
  fi
fi

(
  cd "$SOURCE_DIR"
  zig build -p "$INSTALL_DIR"
)

if [[ ! -x "$BIN_PATH" ]]; then
  echo "failed to prepare elf2sbpf at $BIN_PATH" >&2
  exit 1
fi

printf '%s\n' "$BIN_PATH"
