# spl-transfer-hook (Zig)

Status: 🚧 **v0.1 on-chain/interface** — canonical validation PDA
helper, Execute / Initialize / Update instruction discriminators,
caller-buffer-backed builders/parsers, raw `ExtraAccountMeta` record
helpers, and official parity/host test coverage.

`spl_transfer_hook` is the monorepo package for the
[SPL Transfer Hook](https://github.com/solana-program/transfer-hook)
on-chain/interface surface.

## Scope (v0.1)

- package metadata and module name `spl_transfer_hook`
- standalone package build/test wiring and consumer-style import
  fixture coverage
- canonical `spl-transfer-hook-interface` instruction discriminators
- `findValidationAddress` plus exposed `extra-account-metas` seed
  bytes
- caller-owned-buffer builders/parsers for `Execute`,
  `InitializeExtraAccountMetaList`, and `UpdateExtraAccountMetaList`
- raw 35-byte `ExtraAccountMeta` record and slice helpers
- checked-in official Rust parity fixtures plus package host tests

## Not in scope

- TLV validation-account parsing, dynamic extra-account resolution,
  or remaining-account safety validation beyond raw record helpers
- RPC clients, transaction builders, keypair helpers, searcher flows,
  or other off-chain orchestration APIs
- full Token-2022 transfer execution or real third-party hook
  integrations

## Commands

```console
# Package host tests
zig build --build-file packages/spl-transfer-hook/build.zig test --summary all
```

## Notes

- Transfer-hook programs are caller-supplied, so the package does not
  export a fixed `PROGRAM_ID`.
- Public APIs stay on-chain/package scoped and use caller-provided
  buffers/slices instead of allocator-backed builder state.
