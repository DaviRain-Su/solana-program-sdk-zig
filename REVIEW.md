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
  typed modules instead of a mixed client SDK surface; native signature
  precompile builders/parsers are grouped under `src/crypto/instructions`.
- **Project structure:** stronger than the prior state. Each ecosystem package
  is independently buildable, and CI now exercises every `packages/*/build.zig`
  plus Rust parity fixtures.
- **Ecosystem completeness:** improved, but still incomplete. This pass added
  low-level off-chain foundations plus more native/SPL program surfaces,
  including loader v3/v4, stake/vote seeded builders, SPL ElGamal Registry,
  SPL Name Service, SPL Stake Pool, and SPL Governance interface coverage,
  ATA Rust parity plus precomputed-address builders, and ALT management
  instruction builders, plus raw ZK ElGamal proof-program builders. Core crypto
  now includes ed25519, secp256k1, and secp256r1 verify-instruction
  builders/parsers.

## Evidence

Host-side verification passed:

```console
zig build test --global-cache-dir .zig-cache-global --summary all
# 262/262 tests passed

for build_file in packages/*/build.zig; do
  zig build --build-file "$build_file" --global-cache-dir .zig-cache-global test --summary all
done
# all package tests passed

for manifest in packages/*/rust-parity/Cargo.toml; do
  CARGO_BUILD_RUSTC_WRAPPER= cargo test --manifest-path "$manifest"
done
# all Rust parity fixtures passed

git diff --check
# passed
```

SBF/program-test verification also passed with the local compatible
solana-zig fork:

```console
ZIG_GLOBAL_CACHE_DIR=.zig-cache-global \
SOLANA_ZIG_BIN=/Users/davirian/tools/zig-aarch64-macos-none-baseline/zig \
./scripts/ensure-solana-zig.sh
# /Users/davirian/tools/zig-aarch64-macos-none-baseline/zig

ZIG_GLOBAL_CACHE_DIR=.zig-cache-global \
SOLANA_ZIG_BIN=/Users/davirian/tools/zig-aarch64-macos-none-baseline/zig \
./program-test/test.sh /Users/davirian/tools/zig-aarch64-macos-none-baseline/zig
# SBF build: 40/40 steps succeeded
# Rust integration tests: passed
```

Fresh CU benchmark evidence:

```console
CARGO_BUILD_RUSTC_WRAPPER= \
SOLANA_ZIG=/Users/davirian/tools/zig-aarch64-macos-none-baseline/zig \
ZIG_GLOBAL_CACHE_DIR=.zig-cache-global \
./scripts/bench.sh
```

| Instruction | Zig (this SDK) | Pinocchio | Delta |
|---|---:|---:|---:|
| `vault_initialize` | 1337 CU | 1351 CU | -14 CU |
| `vault_deposit` | 1547 CU | 1565 CU | -18 CU |
| `vault_withdraw` | 1873 CU | 1949 CU | -76 CU |

The remaining measured hot spots are unchanged from the benchmark snapshot:
`parse_accounts_with` is 29 CU versus 18 CU for
`parse_accounts_with_unchecked`, and checked token dispatch is 36/35/33 CU
versus 31/30/28 CU for the unchecked transfer/burn/mint baselines.
```

## Package Surface

| Package | Status | Scope |
|---|---|---|
| `solana_program_sdk` | released core | on-chain entrypoint, account, CPI, syscalls, sysvars, system CPI, crypto syscalls, and ed25519/secp256k1/secp256r1 verify-instruction builders/parsers |
| `spl_token` | released v0.3 | SPL Token instruction builders and CPI helpers |
| `spl_token_2022` | released v0.1 interface-core | Token-2022 fixed/TLV extension views including confidential raw POD views, variable TokenMetadata/TokenGroup/Member parser bridges, generic prepared CPI helpers, base mint/account/authority + reallocate + withdrawExcessLamports + Transfer Fee / ConfidentialTransfer proof-location lifecycle and registry configure / ConfidentialTransferFee proof-location withdraw/config/harvest toggles / MintCloseAuthority / DefaultAccountState / MemoTransfer / NonTransferable / CpiGuard / InterestBearingMint / PermanentDelegate / Pausable / pointer / TransferHook / ScaledUiAmount instruction builders, and Rust parity fixtures |
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
| `solana_codec` | v0.1 codec primitives | shortvec, Borsh primitives/string/bytes, bincode string/options, bincode `COption`, and split tag/payload `COption` readers for packed state |
| `solana_config` | v0.1 config store helpers | Config Program raw ConfigKeys encoding, store instruction builders, and ConfigState views |
| `solana_compute_budget` | v0.1 instruction builders | Compute Budget heap frame, CU limit, CU price, loaded account data size |
| `solana_feature_gate` | v0.1 feature helpers | Feature account encode/decode and activation instruction sequence |
| `solana_zk_elgamal_proof` | v0.1 raw proof builders | ZK ElGamal proof-program close-context, inline proof, and proof-account verify instruction builders |
| `solana_loader_v3` | v0.1 loader helpers | Upgradeable BPF Loader v3 state layout, chunked program writes, and buffer/deploy/upgrade/authority/close/extend/migrate builders |
| `solana_loader_v4` | v0.1 loader helpers | Loader v4 state layout, write/copy/setProgramLength/deploy/retract/authority/finalize builders |
| `solana_system` | v0.1 instruction builders | System Program plain, seeded account, and durable nonce maintenance builders |
| `solana_stake` | v0.1 instruction builders | Stake Program initialize, authorize including seeded variants, lockup mutation, delegate, split, withdraw, deactivate, merge, minimum delegation, and move builders |
| `solana_vote` | v0.1 instruction builders | Vote Program initialize, authorize including seeded variants, update validator identity, update commission, withdraw, raw runtime vote/update/tower builders, and typed `Vote` / `VoteStateUpdate` / `TowerSync` payload encoders |
| `solana_tx` | v0.1 transaction foundation | legacy message compilation plus legacy/v0 message and transaction serialization over shared shortvec codec |
| `solana_transaction_builder` | v0.1 transaction assembly | compile/sign/serialize legacy/v0 transactions, supplied-ALT selection, durable nonce pairs, compute-budget System/SPL Token/Token-2022 transfer, transfer-fee, confidential-transfer and confidential-transfer-with-fee proof preludes, context cleanup, and ATA+token transfer helpers |
| `solana_keypair` | v0.1 signing foundation | Ed25519 seed/secret-key recovery and detached signing |
| `solana_client` | v0.1 RPC client core | JSON-RPC/account-info builders/parsers, remote ALT fetch helper, std HTTP transport adapter, caller-owned stream WebSocket adapter, endpoint/retry/commitment/deadline policy, and typed RPC error normalization |
| `solana_wallet` | v0.1 wallet core | Solana CLI keypair JSON, bundled BIP39 English wordlist, seed derivation/checksum validation, Solana derivation paths, wallet adapter boundary, and AEAD encrypted-keystore payload / envelope helpers |

## Remaining Gaps

High-priority gaps:

1. Broader transaction-level ergonomics: richer app-specific instruction
   bundles beyond nonce, compute-budget System/SPL Token/Token-2022
   transfer / transfer-fee, and ATA+token transfer flows.
2. Codec adoption: continue migrating remaining package-local Borsh string,
   bincode `COption`, and shortvec helpers onto `solana_codec` where that
   does not disturb verified parity fixtures. Classic SPL Token state now
   uses shared split-field `COption` readers for checked authority/native
   accessors while keeping zero-copy fast paths.
3. Wider program ecosystem: confidential-transfer proof-generation and typed
   auto-append ergonomics beyond raw/caller-provided inline or
   proof-account/context-state proof bundling with cleanup, plus additional
   SPL extension surfaces.
4. Anchor-style surface: IDL parsing/generation, account discriminator helpers
   beyond the current core, and a macro/codegen story if this project chooses
   to support that layer.
5. Crypto/syscall parity: BLS/MCL-style helpers and any Solana built-in program
   surfaces not yet modeled.

## Completion Criteria For Next Passes

- Each new package has `build.zig`, `build.zig.zon`, README, tests, and a
  top-level README / packages README row.
- CI package loop must cover the package automatically.
- Byte formats must be backed by pinned Rust parity fixtures when an official
  Rust crate is the source of truth.
- Core CU changes must include SBF/program-test or bench evidence, not only
  host-side unit tests.
