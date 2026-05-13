#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")"/..; pwd)"

usage() {
  cat <<'EOF'
Run the starter project's Rust integration tests against freshly built SBF artifacts.

Usage:
  ./program-test/test.sh
  ./program-test/test.sh /path/to/solana-zig

Notes:
  - No arguments: auto-detect a verified solana-zig fork via scripts/ensure-solana-zig.sh
  - One argument: use that Zig binary, but still verify it against the project SBF probe
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
  echo "program-test requires a project-compatible solana-zig fork." >&2
  echo "Try auto-detection with: ./program-test/test.sh" >&2
  echo "Or pass an explicit verified binary: ./program-test/test.sh /path/to/solana-zig" >&2
  exit 1
fi

cd "$ROOT_DIR/program-test"

echo "Using Zig: $ZIG"
"$ZIG" version

echo "Cleaning Zig build cache..."
rm -rf .zig-cache zig-out

# Extra zig build args (e.g. -Dbuild-program) can be passed via ZIG_BUILD_ARGS env var.
EXTRA_ARGS="${ZIG_BUILD_ARGS:-}"

# shellcheck disable=SC2086
"$ZIG" build $EXTRA_ARGS --summary all --verbose

cargo test --manifest-path "$ROOT_DIR/program-test/Cargo.toml"
