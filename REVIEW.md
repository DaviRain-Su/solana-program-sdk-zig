# Current SDK Review

Date: 2026-05-14

This document records the current-state audit for the core SDK, package
structure, and ecosystem gap against the broader Solana Program SDK-style
surface.

## Verdict

- **Core CU:** near the local floor for the benchmarked paths, but not proven
  globally minimal. The repo has low-CU wins for static PDAs, raw entrypoints,
  prepared CPI staging, and comptime-known system helpers. The remaining
  intentional cost is mostly in safer parsing and checked dispatch.
- **Code structure:** stable. The root package remains on-chain-focused, with
  typed modules instead of a mixed client SDK surface.
- **Project structure:** stronger than the prior state. Each ecosystem package
  is independently buildable, and CI now exercises every `packages/*/build.zig`
  plus Rust parity fixtures.
- **Ecosystem completeness:** improved, but still incomplete. This pass added
  low-level off-chain foundations plus more native/SPL program surfaces,
  including loader v3/v4, stake/vote seeded builders, SPL ElGamal Registry,
  SPL Name Service, SPL Stake Pool, and SPL Governance interface coverage,
  ATA Rust parity plus precomputed-address builders, and ALT management
  instruction builders.

## Evidence

Host-side verification passed:

```console
zig build test --global-cache-dir .zig-cache-global --summary all
# 256/256 tests passed

for build_file in packages/*/build.zig; do
  zig build --build-file "$build_file" --global-cache-dir .zig-cache-global test --summary all
done
# all package tests passed

for manifest in packages/*/rust-parity/Cargo.toml; do
  RUSTC_WRAPPER= cargo test --manifest-path "$manifest" --locked -j 4
done
# all Rust parity fixtures passed

git diff --check
# passed
```

SBF/program-test and fresh CU bench verification are blocked in this
workspace until a compatible Solana Zig fork is installed:

```console
./scripts/ensure-solana-zig.sh
# solana-zig fork not found.
```

## Package Surface

| Package | Status | Scope |
|---|---|---|
| `solana_program_sdk` | released core | on-chain entrypoint, account, CPI, syscalls, sysvars, system CPI |
| `spl_token` | released v0.3 | SPL Token instruction builders and CPI helpers |
| `spl_token_2022` | released v0.1 parsing | Token-2022 fixed/TLV extension views |
| `spl_ata` | released v0.1 | associated token account derivation, precomputed-address builders, create CPI, and Rust parity fixtures |
| `spl_memo` | released v0.1 | memo instruction builders, checked scratch variant, CPI helpers, and Rust parity fixtures |
| `spl_token_metadata` | v0.1 interface | Token Metadata interface builders/parsers and state fixtures |
| `spl_token_group` | v0.1 interface | Token Group interface builders/parsers and state fixtures |
| `spl_transfer_hook` | v0.1 interface-core | Transfer Hook discriminators, meta helpers, PDA resolution |
| `spl_elgamal_registry` | v0.1 interface | ElGamal Registry PDA, fixed account layout, and create/update registry builders |
| `spl_name_service` | v0.1 interface | Name Service header parsing, name hash/PDA helpers, and create/update/transfer/delete/realloc builders |
| `spl_stake_pool` | v0.1 interface-core | Stake Pool PDA helpers, validator-list parsing, common deposit/withdraw/update builders |
| `spl_governance` | v0.1 interface-core | Governance PDA helpers, account-type/header parsing, realm/config/admin, token deposit/delegate, proposal/signatory/vote, and proposal transaction builders |
| `solana_address_lookup_table` | v0.1 ALT helpers | Address Lookup Table account parsing, index resolution, v0 lookup records, and management instruction builders |
| `solana_codec` | v0.1 codec primitives | shortvec, Borsh primitives/string/bytes, bincode `COption` |
| `solana_config` | v0.1 config store helpers | Config Program raw ConfigKeys encoding, store instruction builders, and ConfigState views |
| `solana_compute_budget` | v0.1 instruction builders | Compute Budget heap frame, CU limit, CU price, loaded account data size |
| `solana_feature_gate` | v0.1 feature helpers | Feature account encode/decode and activation instruction sequence |
| `solana_loader_v3` | v0.1 loader helpers | Upgradeable BPF Loader v3 state layout, buffer/deploy/upgrade/authority/close/extend/migrate builders |
| `solana_loader_v4` | v0.1 loader helpers | Loader v4 state layout, write/copy/setProgramLength/deploy/retract/authority/finalize builders |
| `solana_system` | v0.1 instruction builders | System Program plain, seeded account, and durable nonce maintenance builders |
| `solana_stake` | v0.1 instruction builders | Stake Program initialize, authorize including seeded variants, lockup mutation, delegate, split, withdraw, deactivate, merge, minimum delegation, and move builders |
| `solana_vote` | v0.1 instruction builders | Vote Program initialize, authorize including seeded variants, update validator identity, update commission, and withdraw builders |
| `solana_tx` | v0.1 transaction foundation | legacy message compilation plus legacy/v0 message and transaction serialization |
| `solana_transaction_builder` | v0.1 transaction assembly | compile/sign/serialize legacy/v0 transactions, supplied-ALT selection, durable nonce pairs, and compute-budget transfer prelude helpers |
| `solana_keypair` | v0.1 signing foundation | Ed25519 seed/secret-key recovery and detached signing |
| `solana_client` | v0.1 RPC client core | JSON-RPC/account-info builders/parsers, remote ALT fetch helper, std HTTP transport adapter, typed WebSocket subscription surface, endpoint/retry/commitment policy, and typed RPC error normalization |
| `solana_wallet` | v0.1 wallet core | Solana CLI keypair JSON, BIP39 seed derivation/checksum validation, Solana derivation paths, wallet adapter boundary, and AEAD encrypted-keystore payload / envelope helpers |

## Remaining Gaps

High-priority gaps:

1. `solana_wallet`: optional bundled BIP39 wordlist.
2. `solana_client`: concrete WebSocket socket adapter and transport-level
   deadline enforcement for the existing caller-owned transport boundary.
3. Broader transaction-level ergonomics: richer app-specific instruction
   bundles beyond nonce and compute-budget transfer flows.
5. Codec adoption: migrate package-local Borsh string, bincode `COption`, and
   shortvec helpers onto `solana_codec` where that does not disturb verified
   parity fixtures.
6. Wider program ecosystem: loader deployment ergonomics and
   confidential-transfer proof-generation ergonomics; plus vote runtime
   submission / vote-state update / tower-sync builders.
7. Anchor-style surface: IDL parsing/generation, account discriminator helpers
   beyond the current core, and a macro/codegen story if this project chooses
   to support that layer.
8. Crypto/syscall parity: secp256r1, BLS/MCL-style helpers, and any Solana
   built-in program surfaces not yet modeled.

## Completion Criteria For Next Passes

- Each new package has `build.zig`, `build.zig.zon`, README, tests, and a
  top-level README / packages README row.
- CI package loop must cover the package automatically.
- Byte formats must be backed by pinned Rust parity fixtures when an official
  Rust crate is the source of truth.
- Core CU changes must include SBF/program-test or bench evidence, not only
  host-side unit tests.
