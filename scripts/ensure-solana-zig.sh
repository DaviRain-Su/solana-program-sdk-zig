#!/usr/bin/env bash
#
# Locate a solana-zig fork binary (Zig 0.16-dev with sbf target support).
# Prints the absolute path to stdout on success; exits non-zero otherwise.
#
# Search order:
#   1. $SOLANA_ZIG_BIN env var (if set and executable)
#   2. $ZIG env var (if points to a solana-zig fork — detected by the
#      fork's version suffix `-dev.*+` and sbf target support)
#   3. .tools/solana-zig/bin/zig under repo root
#   4. Sibling checkout ../solana-zig-bootstrap/out-smoke/host/bin/zig
#   5. Sibling checkout ../solana-zig-bootstrap/out/*/zig
#   6. $PATH lookup for `solana-zig` (user-installed symlink)
#
# If nothing is found, prints a guidance message to stderr and exits 1.
# The caller can either fall back to the elf2sbpf path or abort.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"

is_solana_zig() {
  local zig_bin="$1"
  [[ -x "$zig_bin" ]] || return 1
  # Fork ships sbf as a real cpu_arch; stock Zig does not.
  # Buffer the whole output so `grep -q`'s early exit doesn't SIGPIPE
  # zig under `set -o pipefail`.
  local targets_out
  targets_out="$("$zig_bin" targets 2>/dev/null)" || return 1
  grep -q '"sbf",' <<<"$targets_out" || return 1
  return 0
}

try_candidate() {
  local cand="$1"
  if is_solana_zig "$cand"; then
    printf '%s\n' "$cand"
    exit 0
  fi
}

if [[ -n "${SOLANA_ZIG_BIN:-}" ]]; then
  try_candidate "$SOLANA_ZIG_BIN"
  echo "SOLANA_ZIG_BIN is set but not a valid solana-zig fork: $SOLANA_ZIG_BIN" >&2
  exit 1
fi

if [[ -n "${ZIG:-}" ]]; then
  try_candidate "$ZIG"
fi

try_candidate "$ROOT_DIR/.tools/solana-zig/bin/zig"
try_candidate "$ROOT_DIR/../solana-zig-bootstrap/out-smoke/host/bin/zig"

# ../solana-zig-bootstrap/out/<target>/zig (after a non-smoke build)
if [[ -d "$ROOT_DIR/../solana-zig-bootstrap/out" ]]; then
  for cand in "$ROOT_DIR/../solana-zig-bootstrap/out"/*/zig; do
    try_candidate "$cand"
  done
fi

if command -v solana-zig >/dev/null 2>&1; then
  try_candidate "$(command -v solana-zig)"
fi

cat <<EOF >&2
solana-zig fork not found.

Options:
  - Set SOLANA_ZIG_BIN=/path/to/solana-zig-bootstrap/out-smoke/host/bin/zig
  - Clone and build https://github.com/DaviRain-Su/solana-zig-bootstrap
    (branch solana-1.52-zig0.16) into a sibling directory
  - Fall back to stock Zig + elf2sbpf via scripts/ensure-elf2sbpf.sh
EOF
exit 1
