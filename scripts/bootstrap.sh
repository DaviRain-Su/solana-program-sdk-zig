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
echo "== Verified solana-zig fork =="

SOLANA_ZIG_BIN=""
if SOLANA_ZIG_BIN="$($ROOT_DIR/scripts/ensure-solana-zig.sh 2>/dev/null)"; then
  echo "Found repository-compatible solana-zig fork: $SOLANA_ZIG_BIN"
  echo "Recommended: export SOLANA_ZIG_BIN=\"$SOLANA_ZIG_BIN\""
else
  SOLANA_ZIG_BIN=""
  echo "No repository-compatible solana-zig fork found."
  echo "Install one, then re-run: ./scripts/ensure-solana-zig.sh"
fi

echo ""
echo "Bootstrap complete."
echo ""
echo "Next steps:"
echo "  1. Run host tests: zig build test --summary all"
echo "  2. Build or validate SBF artifacts with a verified solana-zig fork"
if [[ -n "$SOLANA_ZIG_BIN" ]]; then
  echo "     ./program-test/test.sh \"$SOLANA_ZIG_BIN\""
else
  echo "     SOLANA_ZIG_BIN=/path/to/solana-zig ./program-test/test.sh"
fi
