# Bench results snapshot

Captured: 2026-05-13 against `main` HEAD (see `git log -1 --format=%H`).

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
| `parse_accounts`                   |   23 |
| `parse_accounts_with`              |   29 |
| `parse_accounts_with_signer_only`  |   26 |
| `parse_accounts_with_writable_only` |   29 |
| `parse_accounts_with_owner_only`   |   37 |
| `parse_accounts_with_unchecked`    |   18 |
| `sysvar_copy`                      |   15 |
| `sysvar_ref`                       |   14 |
| `program_entry_1` (eager)          |   11 |
| `program_entry_lazy_1` (lazy)      |   10 |
| `transfer_lamports`                |   23 |
| `transfer_lamports_raw`            |   22 |
| `create_rent_exempt`               | 1419 |
| `create_rent_exempt_comptime`      | 1252 |
| `system_transfer_with_seed_signed` | 1163 |
| `system_transfer_with_seed_signed_single` | 1163 |
| `spl_token_mint_to_checked_signed` | 1136 |
| `spl_token_mint_to_checked_signed_single` | 1134 |
| `spl_token_mint_to_checked_multisig` | 1209 |
| `spl_token_transfer_checked_multisig` | 1238 |
| `spl_token_approve_checked_multisig` | 1238 |
| `spl_token_burn_multisig` | 1208 |
| `spl_token_initialize_multisig` | 1180 |
| `spl_token_initialize_multisig2` | 1150 |
| `spl_token_batch_transfer_checked` | 1239 |
| `spl_token_batch_transfer_checked_prepared` | 1209 |
| `token_dispatch_transfer` (current path)   |   36 |
| `token_dispatch_burn` (current path)       |   35 |
| `token_dispatch_mint` (current path)       |   33 |
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

## Safe-parse / token-dispatch snapshot

Fresh reruns against the current tree show the safe parse path is now
much closer to the unchecked baseline than the older snapshot rows:

- `parse_accounts` = **23 CU**
- `parse_accounts_with` = **29 CU**
- `parse_accounts_with_unchecked` = **18 CU**

That leaves `parseAccountsWith` at roughly **+11 CU** over the fully
unchecked path and **+6 CU** over the non-validating safe parse.

The new expectation-shape benches show where that validation tax comes
from:

- `parse_accounts_with_signer_only` = **26 CU**
- `parse_accounts_with_writable_only` = **29 CU**
- `parse_accounts_with_owner_only` = **37 CU**

So the remaining validated-parse cost is not uniform: signer-only checks
are relatively cheap, writable checks land near the current mixed spec,
and comptime owner validation is the most expensive single expectation
shape of the three.

For dispatch, the decomposition benches isolate the remaining checked
path costs:

- `parse_only` ~= unchecked baseline on transfer/burn and +2 CU on mint,
  so `parseAccountsUnchecked` itself is already near-minimal.
- `bind_only` is still a consistent +4 CU over unchecked, which points at the
  typed ix-data length-check/bind path as the main remaining cost.
- The current end-to-end path now adds only ~1 CU on top of `bind_only`
  after adding cold-branch hints to `requireIxDataLen*`, so the explicit
  checked account-consumption gate is no longer the dominant part of the
  remaining dispatch tax.

## SPL Token CPI notes

- `create_rent_exempt_comptime` lands at **1252 CU** versus
  **1419 CU** for the runtime-rent `create_rent_exempt` helper,
  confirming a direct **167 CU** saving from baking the rent-exempt
  minimum at build time even on the plain no-signer account-creation path.
- `system_transfer_with_seed_signed` and
  `system_transfer_with_seed_signed_single` both land at **1163 CU**
  against the no-op callee, indicating that the seeded single-PDA path
  is currently an ergonomics/API win rather than a measurable wrapper-only
  CU reduction for this family.
- `mint_to_checked_signed_single` remains just 2 CU cheaper than
  `mint_to_checked_signed`, confirming the single-PDA path is mostly an
  ergonomics improvement for already-raw wrappers.
- Wrapper-only multisig benchmarks against the no-op callee now land at
  **1209 CU** for `mint_to_checked_multisig`, **1238 CU** for both
  `transfer_checked_multisig` and `approve_checked_multisig`, **1208 CU**
  for the non-checked `burn_multisig`, **1180 CU** for legacy
  `initialize_multisig`, and **1150 CU** for `initialize_multisig2`.
- The `batch_transfer_checked` wrapper-only benchmark lands at **1239 CU**
  for a two-child `TransferChecked` envelope against the no-op callee.
- The new lower-level `batch_transfer_checked_prepared` fast path lands at
  **1209 CU**, saving **30 CU** by letting the caller provide the fully
  prepared runtime-account slice (with the token program already appended)
  and therefore skipping the extra runtime-account staging memcpy inside
  `spl_token.cpi.batch(...)`.

## Current priority takeaway

### Real CU wins

- **PDA strategy dominates.** `pda_runtime` (`findProgramAddress`) is
  **3025 CU** versus **6 CU** for `pda_comptime`, and stored-bump
  `verifyPda` remains far cheaper than `verifyPdaCanonical`.
- **Comptime rent folding is real.** `create_rent_exempt_comptime`
  saves **167 CU** over the runtime-rent helper.
- **Prepared Batch is a measurable local win.**
  `batch_transfer_checked_prepared` saves **30 CU** over the higher-level
  `batch_transfer_checked` wrapper, even though current devnet proofs do
  not show a net end-to-end CU win for Batch versus lean direct flows.

### Mostly ergonomics wins

- `*SignedSingle` helper families are valuable API surface, but current
  wrapper-only evidence shows little or no CU change once a path already
  uses raw signer staging:
  - `system_transfer_with_seed_signed` = `1163`
  - `system_transfer_with_seed_signed_single` = `1163`
  - `spl_token_mint_to_checked_signed` = `1136`
  - `spl_token_mint_to_checked_signed_single` = `1134`

### Areas that now look largely flat

- Sysvar copy-vs-ref (`15` vs `14`), eager-vs-lazy entrypoint (`11` vs `10`),
  and raw lamport transfer (`23` vs `22`) are already near the floor.
- Owner-check and bind-path experiments did not produce a benchmark-backed
  improvement under low-risk code-shape changes.

### Remaining hotspot worth revisiting

- **Safe parse / checked dispatch bookkeeping** is still the one internal
  area with visible but now modest headroom. `parse_accounts_with` is
  **29 CU** versus **18 CU** for `parse_accounts_with_unchecked`, and the
  checked token-dispatch path is **36/35/33 CU** versus
  **31/30/28 CU** for the unchecked baseline. Within validated parse,
  owner checks are the most expensive single expectation shape
  (`parse_accounts_with_owner_only` = **37 CU**), but recent local
  experiments did not uncover a low-risk win there.
