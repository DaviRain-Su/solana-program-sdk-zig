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

echo ""
echo "== Primary path: solana-zig fork =="

SOLANA_ZIG_BIN=""
if SOLANA_ZIG_BIN="$("$ROOT_DIR/scripts/ensure-solana-zig.sh" 2>/dev/null)"; then
  echo "Found solana-zig fork: $SOLANA_ZIG_BIN"
  echo "Recommended: export SOLANA_ZIG_BIN=\"$SOLANA_ZIG_BIN\""
  echo "solana-zig fork closes the CU gap vs solana-zig v1.52 baseline."
else
  SOLANA_ZIG_BIN=""
  echo "solana-zig fork not found — will fall back to stock Zig + elf2sbpf."
  echo "See scripts/ensure-solana-zig.sh for how to install the fork."
fi

echo ""
echo "== Fallback path: stock Zig + elf2sbpf =="

ELF2SBPF_BIN="$("$ROOT_DIR/scripts/ensure-elf2sbpf.sh")"
echo "Resolved elf2sbpf: $ELF2SBPF_BIN"

echo ""
echo "Bootstrap complete."
echo ""
echo "Next steps:"
echo "  1. Edit program-test/pubkey/main.zig"
echo "  2. Run: zig build test --summary all"
if [[ -n "$SOLANA_ZIG_BIN" ]]; then
  echo "  3. Run (fork path — best CU):"
  echo "     ./program-test/test.sh solana-zig \"$SOLANA_ZIG_BIN\""
fi
echo "  3'. Run (elf2sbpf fallback path):"
echo "     ./program-test/test.sh zig \"$ELF2SBPF_BIN\""
echo ""
echo "Environment variables to persist:"
if [[ -n "$SOLANA_ZIG_BIN" ]]; then
  echo "  export SOLANA_ZIG_BIN=\"$SOLANA_ZIG_BIN\""
fi
echo "  export ELF2SBPF_BIN=\"$ELF2SBPF_BIN\""
