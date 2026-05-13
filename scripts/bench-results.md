# Bench results snapshot

Captured: 2026-05-12 against `main` HEAD (see `git log -1 --format=%H`).

Reproduce: `./scripts/bench.sh` from the repo root. Requires
`solana-zig` on PATH (or `SOLANA_ZIG=/path/to/zig`) plus optional
`cargo-build-sbf` for the Pinocchio reference rows.

## Primitive benchmarks

| Benchmark                          | CU   |
|------------------------------------|-----:|
| `pubkey_cmp_safe` (byte-by-byte)   |   26 |
| `pubkey_cmp_safe_raw`              |   18 |
| `pubkey_cmp_unchecked` (aligned)   |   18 |
| `pubkey_cmp_comptime` (xor-or)     |   24 |
| `pubkey_cmp_runtime_const`         |   30 |
| `pda_runtime` (syscall)            | 3025 |
| `pda_comptime` (build-time fold)   |    6 |
| `parse_accounts_with`              |   93 |
| `parse_accounts_with_unchecked`    |   25 |
| `sysvar_copy`                      |   15 |
| `sysvar_ref`                       |   14 |
| `program_entry_1` (eager)          |   11 |
| `program_entry_lazy_1` (lazy)      |   10 |
| `transfer_lamports`                |   23 |
| `transfer_lamports_raw`            |   22 |
| `spl_token_mint_to_checked_signed` | 1136 |
| `spl_token_mint_to_checked_signed_single` | 1134 |
| `spl_token_mint_to_checked_multisig` | 1209 |
| `spl_token_transfer_checked_multisig` | 1238 |
| `token_dispatch_transfer` (current path)   |   37 |
| `token_dispatch_burn` (current path)       |   36 |
| `token_dispatch_mint` (current path)       |   34 |
| `token_dispatch_parse_only_transfer`       |   31 |
| `token_dispatch_parse_only_burn`           |   31 |
| `token_dispatch_parse_only_mint`           |   30 |
| `token_dispatch_bind_only_transfer`        |   35 |
| `token_dispatch_bind_only_burn`            |   34 |
| `token_dispatch_bind_only_mint`            |   32 |
| `token_dispatch_unchecked_transfer`        |   31 |
| `token_dispatch_unchecked_burn`            |   30 |
| `token_dispatch_unchecked_mint`            |   28 |

## End-to-end vault (Zig vs. Pinocchio reference)

Both implementations live in this repo and run **identical** business
semantics — same PDA seeds, same client-supplied bump, same 56-byte
account layout, same 24-byte `sol_log_data` payload — so the
comparison isolates pure SDK overhead.

| Instruction          | Zig (this SDK) | Pinocchio | Δ (Zig − Pino)  |
|----------------------|---------------:|----------:|----------------:|
| `vault_initialize`   |       **1334** |     1351  | −17  (−1.3%)   |
| `vault_deposit`      |       **1543** |     1565  | −22  (−1.4%)   |
| `vault_withdraw`     |       **1866** |     1949  | −83  (−4.3%)   |

**All three vault instructions now beat the Pinocchio reference.**

## Performance journey on `vault.initialize` (1823 → 1353, −26%)

The 470-CU reduction came from three measurable optimizations, all of
which are documented in their respective `perf:` commits:

| Commit     | Optimization                                            | Δ CU  |
|------------|---------------------------------------------------------|------:|
| `f0ece32`  | `Rent.getMinimumBalance` integer fast path (skip f64)   |  −283 |
| `0c7586b`  | `createRentExemptComptimeRaw` (build-time fold rent)    |  −161 |
| `79d3161`  | `CpiAccountInfo.fromPtr` u32 flag-copy                  |   −27 |
| _baseline_ | (other f0ece32 wins absorbed: Seed/Signer, bindUnchecked)| various |

The remaining 2 CU vs. Pinocchio is sub-instruction noise that LLVM
has already optimized flat.

## Token-dispatch decomposition

The new decomposition benches isolate where the remaining dispatch gap
comes from:

- `parse_only` ~= unchecked baseline on transfer/burn and +2 CU on mint,
  so `parseAccountsUnchecked` itself is already near-minimal.
- `bind_only` is a consistent +4 CU over unchecked, which points at the
  typed ix-data length-check/bind path as the main remaining cost.
- The current end-to-end path adds another ~2 CU on top of `bind_only`,
  largely from the fully safe account-consumption bookkeeping.

## SPL Token CPI notes

- `mint_to_checked_signed_single` remains just 2 CU cheaper than
  `mint_to_checked_signed`, confirming the single-PDA path is mostly an
  ergonomics improvement for already-raw wrappers.
- Wrapper-only multisig benchmarks against the no-op callee now land at
  **1209 CU** for `mint_to_checked_multisig` and **1238 CU** for
  `transfer_checked_multisig` after fusing signer-meta staging with
  runtime-account staging on the checked wrappers, a further **-30 CU**
  win on each path.
