# spl-token-2022 (Zig)

Status: ✅ **v0.1 interface-core** — read-only Token-2022 mint/account
TLV parsing, fixed-length including confidential extension views, base mint/account/authority
instruction builders, generic prepared CPI helpers, reallocation and
lamport-rescue helpers, and Transfer Fee / ConfidentialTransfer proof-location account lifecycle, registry configure, and withdraw /
ConfidentialTransferFee proof-location withdraw plus no-proof config and harvest toggles
/ MintCloseAuthority / DefaultAccountState / MemoTransfer / NonTransferable /
CpiGuard / InterestBearingMint / PermanentDelegate / Pausable / MetadataPointer
/ GroupPointer / GroupMemberPointer / TransferHook / ScaledUiAmount builders,
plus variable-length TokenMetadata / TokenGroup / TokenGroupMember parser
bridges, validated by host tests, pinned Rust parity fixtures, and the real
`example_spl_token_2022_parse.so` program-test artifact.

`spl_token_2022` is an on-chain-safe parsing package for the
[SPL Token-2022](https://github.com/solana-program/token-2022)
account layout. It exports the canonical program id, account-type
parsing, base layout constants, TLV scanning, typed fixed-length including confidential
extension views, ordinary mint/account/authority instruction builders,
generic prepared CPI helpers, reallocation and lamport-rescue helpers, and Transfer Fee, ConfidentialTransfer
proof-location account lifecycle, registry configure, and withdraw, ConfidentialTransferFee
proof-location withdraw plus no-proof config/harvest toggles, MintCloseAuthority,
DefaultAccountState, MemoTransfer, NonTransferable, CpiGuard, InterestBearingMint,
PermanentDelegate, Pausable, MetadataPointer, GroupPointer, GroupMemberPointer,
TransferHook, and ScaledUiAmount instruction builders that target the
Token-2022 program id. It also exposes parser bridges for variable-length
TokenMetadata, TokenGroup, and TokenGroupMember TLV payloads using the sibling
interface packages.

## Scope (v0.1)

- canonical Token-2022 `PROGRAM_ID`
- mint/account base layout parsing
- TLV iterator + lookup helpers
- fixed-length mint/account extension views, including confidential transfer,
  confidential transfer fee, and confidential mint-burn raw POD views
- generic prepared CPI helpers over caller-built Token-2022 instructions
- base instruction builders for transfer/approve/mint/burn/close,
  revoke/setAuthority/freeze/thaw/syncNative, checked variants,
  initializeMint, initializeAccount, initializeAccount2, initializeAccount3,
  initializeMultisig, initializeMultisig2, initializeMint2,
  getAccountDataSize including extension lists, initializeImmutableOwner,
  initializeMintCloseAuthority, createNativeMint, initializeNonTransferableMint, reallocate,
  withdrawExcessLamports, and UI amount conversion
- Transfer Fee extension builders for initialize config,
  transferCheckedWithFee, withdraw/harvest withheld tokens, and setTransferFee
- ConfidentialTransfer builders for initialize/update mint, configure/approve
  account, empty account, deposit, withdraw, transfer, transferWithFee, apply
  pending balance, registry-backed configureAccountWithRegistry, and
  confidential / non-confidential credit toggles
- ConfidentialTransferFee builders for initialize config, proof-location
  withdraw from mint/accounts, harvestWithheldTokensToMint, and harvest
  enable/disable toggles
- DefaultAccountState initialize/update builders and MemoTransfer
  enable/disable builders
- CpiGuard enable/disable builders, InterestBearingMint initialize/updateRate
  builders, PermanentDelegate initialize builder, and Pausable
  initialize/pause/resume builders
- MetadataPointer, GroupPointer, GroupMemberPointer, TransferHook, and
  ScaledUiAmount initialize/update builders
- variable-length TokenMetadata / TokenGroup / TokenGroupMember parser bridges
- pinned Rust parity against `spl-token-2022 = 9.0.0` instruction builders
- parsing demo wired into `program-test/build.zig`

## Not in scope

- per-instruction CPI convenience wrappers
- confidential proof generation and typed auto-append wrappers; use
  `solana_zk_elgamal_proof` for raw caller-provided proof instructions
- extension-specific instruction families beyond Transfer Fee,
  ConfidentialTransfer proof-location lifecycle and registry configure,
  ConfidentialTransferFee
  proof-location withdraw/config/harvest toggles, MintCloseAuthority,
  DefaultAccountState,
  MemoTransfer, NonTransferable, CpiGuard, InterestBearingMint,
  PermanentDelegate, Pausable, MetadataPointer,
  GroupPointer, GroupMemberPointer, TransferHook, and ScaledUiAmount
- off-chain RPC / transaction / keypair packages

## Commands

```console
# Package host tests
zig build --build-file packages/spl-token-2022/build.zig test --summary all

# Rust instruction parity
cargo test --manifest-path packages/spl-token-2022/rust-parity/Cargo.toml

# Full SBF + Mollusk regression suite
./program-test/test.sh
```
