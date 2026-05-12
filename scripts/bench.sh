#!/usr/bin/env bash
# Run all CU benchmarks and emit a markdown-friendly summary table.
#
# Usage:
#   ./scripts/bench.sh            # run with auto-located solana-zig
#   SOLANA_ZIG=/path/to/zig ./scripts/bench.sh
#
# Requires:
#   - solana-zig (Zig 0.16 with sbf target) to build BPF artifacts
#   - cargo (for `benchmark/` runner)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
cd "$ROOT_DIR"

if [[ -z "${SOLANA_ZIG:-}" ]]; then
    if command -v solana-zig >/dev/null 2>&1; then
        SOLANA_ZIG="$(command -v solana-zig)"
    else
        echo "error: SOLANA_ZIG not set and 'solana-zig' not in PATH" >&2
        exit 1
    fi
fi

echo "Building BPF artifacts ($SOLANA_ZIG)..."
(cd benchmark && "$SOLANA_ZIG" build --summary none) >/dev/null

export BPF_OUT_DIR="$ROOT_DIR/benchmark/zig-out/lib"

BENCHES=(
    "pubkey_cmp_safe"
    "pubkey_cmp_safe_raw"
    "pubkey_cmp_unchecked"
    "pubkey_cmp_comptime"
    "pubkey_cmp_runtime_const"
    "pda_runtime"
    "pda_comptime"
    "parse_accounts_with"
    "transfer_lamports"
    "transfer_lamports_raw"
    "token_dispatch_transfer"
    "token_dispatch_burn"
    "token_dispatch_mint"
    "vault_initialize"
    "vault_deposit"
    "vault_withdraw"
)

echo
printf '| %-28s | %-8s |\n' "Benchmark" "CU"
printf '|%s|%s|\n' "$(printf -- '-%.0s' {1..30})" "$(printf -- '-%.0s' {1..10})"

cd benchmark
for b in "${BENCHES[@]}"; do
    # The "primary" instruction line is the last `consumed N of 200000`
    # before "success" — withdraw runs init + deposit + withdraw, so we
    # take the final one.
    cu="$(cargo run --release --quiet -- "$b" 2>&1 | \
        grep -E 'consumed [0-9]+ of' | \
        tail -1 | \
        sed -E 's/.*consumed ([0-9]+) of.*/\1/')"
    printf '| %-28s | %8s |\n' "$b" "${cu:-?}"
done
