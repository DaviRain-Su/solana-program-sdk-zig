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
    if SOLANA_ZIG="$("$ROOT_DIR/scripts/ensure-solana-zig.sh" 2>/dev/null)"; then
        :
    elif command -v solana-zig >/dev/null 2>&1; then
        SOLANA_ZIG="$(command -v solana-zig)"
    else
        echo "error: SOLANA_ZIG not set and no compatible solana-zig fork was found" >&2
        exit 1
    fi
fi

echo "Building BPF artifacts ($SOLANA_ZIG)..."
(cd benchmark && "$SOLANA_ZIG" build --summary none) >/dev/null

export BPF_OUT_DIR="$ROOT_DIR/benchmark/zig-out/lib"

# Pinocchio reference vault (Rust) — build with cargo-build-sbf if
# available, then copy the .so next to the Zig artifacts so the
# `ProgramTest` `BPF_OUT_DIR` lookup finds it. We deliberately keep
# this best-effort: if cargo-build-sbf isn't installed, just skip and
# the `pino_vault_*` benchmarks will be reported as `?` in the table.
if command -v cargo-build-sbf >/dev/null 2>&1; then
    echo "Building Pinocchio reference vault (cargo build-sbf)..."
    # The cargo-build-sbf binary needs the rustup-managed `cargo`
    # ahead of any system cargo (Homebrew, etc.) on PATH so it can
    # resolve its `+1.89.0-sbpf-solana-v1.52` toolchain override.
    export PATH="$HOME/.cargo/bin:$PATH"
    # Re-link the toolchain in case it was uninstalled by a previous
    # build-sbf run — `cargo build-sbf` self-manages its toolchain and
    # may remove it on exit. The link is idempotent.
    if [[ -d "$HOME/.local/share/solana/install/active_release/bin/platform-tools-sdk/sbf/dependencies/platform-tools/rust" ]]; then
        rustup toolchain link 1.89.0-sbpf-solana-v1.52 \
            "$HOME/.local/share/solana/install/active_release/bin/platform-tools-sdk/sbf/dependencies/platform-tools/rust" \
            >/dev/null 2>&1 || true
    fi
    (cd bench-pinocchio && cargo build-sbf --skip-tools-install --sbf-out-dir "$BPF_OUT_DIR" >/dev/null)
else
    echo "warn: cargo-build-sbf not found in PATH — skipping Pinocchio build" >&2
fi

BENCHES=(
    "pubkey_cmp_safe"
    "pubkey_cmp_safe_raw"
    "pubkey_cmp_unchecked"
    "pubkey_cmp_comptime"
    "pubkey_cmp_runtime_const"
    "pda_runtime"
    "pda_comptime"
    "parse_accounts"
    "parse_accounts_with"
    "parse_accounts_with_signer_only"
    "parse_accounts_with_writable_only"
    "parse_accounts_with_owner_only"
    "parse_accounts_with_unchecked"
    "sysvar_copy"
    "sysvar_ref"
    "program_entry_1"
    "program_entry_lazy_1"
    "transfer_lamports"
    "transfer_lamports_raw"
    "create_rent_exempt"
    "create_rent_exempt_comptime"
    "system_transfer_with_seed_signed"
    "system_transfer_with_seed_signed_single"
    "spl_token_mint_to_checked_signed"
    "spl_token_mint_to_checked_signed_single"
    "spl_token_mint_to_checked_multisig"
    "spl_token_transfer_checked_multisig"
    "spl_token_approve_checked_multisig"
    "spl_token_burn_multisig"
    "spl_token_initialize_multisig"
    "spl_token_initialize_multisig2"
    "spl_token_batch_transfer_checked"
    "spl_token_batch_transfer_checked_prepared"
    "token_dispatch_transfer"
    "token_dispatch_burn"
    "token_dispatch_mint"
    "token_dispatch_parse_only_transfer"
    "token_dispatch_parse_only_burn"
    "token_dispatch_parse_only_mint"
    "token_dispatch_bind_only_transfer"
    "token_dispatch_bind_only_burn"
    "token_dispatch_bind_only_mint"
    "token_dispatch_unchecked_transfer"
    "token_dispatch_unchecked_burn"
    "token_dispatch_unchecked_mint"
    "vault_initialize"
    "vault_deposit"
    "vault_withdraw"
    "pino_vault_initialize"
    "pino_vault_deposit"
    "pino_vault_withdraw"
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
