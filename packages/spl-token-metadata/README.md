# spl-token-metadata (Zig)

Status: 🚧 **v0.1 on-chain/interface scaffold** — standalone package
build/test wiring, stable `spl_token_metadata` imports, interface-only
public roots, and raw instruction-builder boundary coverage.

`spl_token_metadata` is the monorepo package for the
`spl-token-metadata-interface` on-chain surface.

## Scope (v0.1 scaffold)

- package metadata and module name `spl_token_metadata`
- standalone package build/test wiring
- consumer-style import fixtures for metadata-only and
  metadata+group usage
- interface-only public roots (`id`, `instruction`, `state`)
- raw instruction-builder boundary helpers that stay caller-program-id
  and borrowed-slice scoped

## Not in scope

- processors, rent/realloc logic, or runtime mutation helpers
- RPC clients, transaction assembly, recent-blockhash/signature
  management, keypair/wallet helpers, searcher flows, or external JSON
  fetching
- full metadata instruction/state parity surfaces (follow-up features)

## Commands

```console
# Package host tests
zig build --build-file packages/spl-token-metadata/build.zig test --summary all
```

## Notes

- Metadata programs are caller-supplied, so the scaffold does not
  export a fixed `PROGRAM_ID`.
- Public APIs stay on-chain/interface scoped and use borrowed raw
  instruction slices instead of full transaction orchestration.
