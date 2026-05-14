# spl-token-2022 (Zig)

Status: ✅ **v0.1 interface-core** — read-only Token-2022 mint/account
TLV parsing, fixed-length extension views, base mint/account/authority
instruction builders, reallocation and lamport-rescue helpers, and Transfer Fee
/ MintCloseAuthority / DefaultAccountState / MemoTransfer / NonTransferable /
CpiGuard / InterestBearingMint / PermanentDelegate / Pausable / MetadataPointer
/ GroupPointer / GroupMemberPointer / TransferHook / ScaledUiAmount builders,
validated by host tests, pinned Rust parity fixtures, and the real
`example_spl_token_2022_parse.so` program-test artifact.

`spl_token_2022` is an on-chain-safe parsing package for the
[SPL Token-2022](https://github.com/solana-program/token-2022)
account layout. It exports the canonical program id, account-type
parsing, base layout constants, TLV scanning, typed fixed-length
extension views, ordinary mint/account/authority instruction builders,
reallocation and lamport-rescue helpers, and Transfer Fee, MintCloseAuthority,
DefaultAccountState, MemoTransfer, NonTransferable, CpiGuard, InterestBearingMint,
PermanentDelegate, Pausable, MetadataPointer, GroupPointer, GroupMemberPointer,
TransferHook, and ScaledUiAmount instruction builders that target the
Token-2022 program id.

## Scope (v0.1)

- canonical Token-2022 `PROGRAM_ID`
- mint/account base layout parsing
- TLV iterator + lookup helpers
- fixed-length mint/account extension views
- base instruction builders for transfer/approve/mint/burn/close,
  revoke/setAuthority/freeze/thaw/syncNative, checked variants,
  initializeMint, initializeAccount, initializeAccount2, initializeAccount3,
  initializeMultisig, initializeMultisig2, initializeMint2,
  getAccountDataSize including extension lists, initializeImmutableOwner,
  initializeMintCloseAuthority, createNativeMint, initializeNonTransferableMint, reallocate,
  withdrawExcessLamports, and UI amount conversion
- Transfer Fee extension builders for initialize config,
  transferCheckedWithFee, withdraw/harvest withheld tokens, and setTransferFee
- DefaultAccountState initialize/update builders and MemoTransfer
  enable/disable builders
- CpiGuard enable/disable builders, InterestBearingMint initialize/updateRate
  builders, PermanentDelegate initialize builder, and Pausable
  initialize/pause/resume builders
- MetadataPointer, GroupPointer, GroupMemberPointer, TransferHook, and
  ScaledUiAmount initialize/update builders
- pinned Rust parity against `spl-token-2022 = 9.0.0` instruction builders
- parsing demo wired into `program-test/build.zig`

## Not in scope

- CPI wrappers
- confidential extension parsing
- variable-length TokenMetadata / TokenGroup / TokenGroupMember parsers
- extension-specific instruction families beyond Transfer Fee,
  MintCloseAuthority, DefaultAccountState, MemoTransfer, NonTransferable,
  CpiGuard, InterestBearingMint, PermanentDelegate, Pausable, MetadataPointer,
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
