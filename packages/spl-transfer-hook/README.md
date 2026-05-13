# spl-transfer-hook (Zig)

Status: 🚧 **v0.1 on-chain/interface scaffold** — package metadata,
module wiring, import/guard tests, and compile-time placeholder
namespaces only.

`spl_transfer_hook` is the monorepo package for the
[SPL Transfer Hook](https://github.com/solana-program/transfer-hook)
on-chain/interface surface.

## Scope (v0.1 scaffold)

- package metadata and module name `spl_transfer_hook`
- standalone package build/test wiring
- consumer-style import fixture coverage
- placeholder namespaces for upcoming instruction/meta/resolution work
- source/API guards proving no RPC, client, keypair, transaction,
  or searcher surfaces are introduced

## Not in scope

- full instruction builder/parser semantics
- extra-account-meta TLV parsing or PDA resolution internals
- RPC clients, transaction builders, keypair helpers, searcher flows,
  or other off-chain orchestration APIs
- real third-party hook integrations or full Token-2022 transfer
  execution

## Commands

```console
# Package host tests
zig build --build-file packages/spl-transfer-hook/build.zig test --summary all
```

## Notes

- Transfer-hook programs are caller-supplied; this scaffold does not
  expose a fixed `PROGRAM_ID`.
- Future package work will fill in canonical discriminators,
  instruction builders/parsers, TLV/meta resolution, and safety
  helpers within the same `spl_transfer_hook` module.
