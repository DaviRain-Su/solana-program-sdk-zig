#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")"/..; pwd)"

usage() {
  cat <<'EOF'
Run the repository's Rust integration tests against freshly built SBF artifacts.

Usage:
  ./program-test/test.sh
  ./program-test/test.sh /path/to/solana-zig

Notes:
  - No arguments: auto-detect a verified solana-zig fork via scripts/ensure-solana-zig.sh
  - One argument: use that Zig binary, but still verify it against the repository SBF probe
  - Stock Zig is supported for host unit tests only, not for program-test SBF builds
EOF
}

resolve_zig() {
  case "$#" in
    0)
      "$ROOT_DIR/scripts/ensure-solana-zig.sh"
      ;;
    1)
      printf '%s\n' "$1"
      ;;
    2)
      case "$1" in
        solana-zig|zig)
          printf '%s\n' "$2"
          ;;
        *)
          usage >&2
          return 1
          ;;
      esac
      ;;
    *)
      usage >&2
      return 1
      ;;
  esac
}

ZIG="$(resolve_zig "$@")"

if ! SOLANA_ZIG_BIN="$ZIG" "$ROOT_DIR/scripts/ensure-solana-zig.sh" >/dev/null 2>&1; then
  echo "program-test requires a repository-compatible solana-zig fork." >&2
  echo "Try auto-detection with: ./program-test/test.sh" >&2
  echo "Or pass an explicit verified binary: ./program-test/test.sh /path/to/solana-zig" >&2
  exit 1
fi

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
