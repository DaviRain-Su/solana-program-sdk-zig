# spl-token-group (Zig)

Status: 🚧 **v0.1 on-chain/interface package** — standalone package
build/test wiring, stable `spl_token_group` imports, interface-only
public roots, canonical group instruction/state surfaces, and local
Rust parity coverage.

`spl_token_group` is the monorepo package for the
`spl-token-group-interface` on-chain surface.

## Scope (v0.1)

- package metadata and module name `spl_token_group`
- standalone package build/test wiring
- consumer-style import fixtures
- interface-only public roots (`id`, `instruction`, `state`)
- canonical group instruction discriminators plus raw
  caller-program-id instruction builders/parsers
- public `MaybeNullPubkey` helpers with canonical zero-as-null 32-byte
  encoding
- fixed-layout TokenGroup / TokenGroupMember parsing and checked parity
  fixtures against `spl-token-group-interface = "=0.7.2"`

## Not in scope

- processors, rent/realloc logic, or runtime mutation helpers
- RPC clients, transaction assembly, recent-blockhash/signature
  management, keypair/wallet helpers, searcher flows, or external JSON
  fetching

## Commands

```console
# Package host tests
zig build --build-file packages/spl-token-group/build.zig test --summary all

# Rust parity fixtures
cargo test --manifest-path packages/spl-token-group/rust-parity/Cargo.toml --locked -j 4

# Root SDK regression is intentionally deferred while unrelated
# user-owned sysvar/root refactor work breaks the root baseline
echo Root test deferred: unrelated user-owned sysvar/root dirty work currently breaks root baseline
```

## Notes

- Group programs are caller-supplied, so the package does not export
  a fixed `PROGRAM_ID`.
- Public APIs stay on-chain/interface scoped and use borrowed raw
  instruction slices instead of full transaction orchestration.
