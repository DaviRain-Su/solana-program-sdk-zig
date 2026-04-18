#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"

if ! command -v zig >/dev/null 2>&1; then
  echo "zig is required. Please install Zig 0.16.0 first." >&2
  exit 1
fi

zig_version="$(zig version)"
case "$zig_version" in
  0.16.*) ;;
  *)
    echo "warning: expected Zig 0.16.x, found $zig_version" >&2
    ;;
esac

if ! command -v cargo >/dev/null 2>&1; then
  echo "warning: cargo not found. program-test Rust integration tests will be unavailable." >&2
fi

ELF2SBPF_BIN="$($ROOT_DIR/scripts/ensure-elf2sbpf.sh)"

echo ""
echo "Bootstrap complete."
echo ""
echo "Resolved elf2sbpf: $ELF2SBPF_BIN"
echo ""
echo "Next steps:"
echo "  1. Edit program-test/pubkey/main.zig"
echo "  2. Run: zig build test --summary all"
echo "  3. Run: ./program-test/test.sh zig \"$ELF2SBPF_BIN\""
echo ""
echo "Optional environment variable:"
echo "  export ELF2SBPF_BIN=\"$ELF2SBPF_BIN\""
