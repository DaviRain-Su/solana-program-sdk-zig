# spl-governance

Allocation-free SPL Governance interface helpers for Zig.

This package covers the low-level surface that is useful from both on-chain
and host-side code:

- governance, realm, token-owner-record, proposal, vote/signatory, treasury,
  required-signatory, metadata, and proposal-deposit PDA helpers
- account-type discriminants and compact header parsers for governance,
  token-owner-record, and proposal-deposit accounts
- raw realm/governance config builders for `CreateRealm`,
  `CreateGovernance`, `SetGovernanceConfig`, `SetRealmAuthority`, and
  `SetRealmConfig`
- raw builders for `DepositGoverningTokens`, `WithdrawGoverningTokens`, and
  `SetGovernanceDelegate`
- raw proposal/vote builders for `CreateProposal`, `AddSignatory`,
  `SignOffProposal`, `CastVote`, `FinalizeVote`, `RelinquishVote`, and
  `CancelProposal`
- proposal transaction builders for `InsertTransaction`, `RemoveTransaction`,
  `ExecuteTransaction`, and `FlagTransactionError`
- admin/lifecycle builders for `CreateTokenOwnerRecord`,
  `UpdateProgramMetadata`, `CreateNativeTreasury`, `RevokeGoverningTokens`,
  `AddRequiredSignatory`, `RemoveRequiredSignatory`,
  `RefundProposalDeposit`, and `CompleteProposal`

The instruction builders require caller-owned PDA pubkeys in their account
structs because `AccountMeta` stores pubkey pointers. Use the `find*Address`
helpers first, keep the returned pubkeys alive, then pass pointers into the
builder.

## Validation

```console
zig build --build-file packages/spl-governance/build.zig test --summary all
RUSTC_WRAPPER= cargo test --manifest-path packages/spl-governance/rust-parity/Cargo.toml --locked
```
