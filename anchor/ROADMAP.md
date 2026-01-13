# sol-anchor-zig Roadmap

## ✅ v3.2.52 - Constraint Expr Expansion

- [x] Expand constraint expression parsing for boolean/comparison ops

## ✅ v3.2.51 - AccountsDerive Program Auto Bindings (Typed)

- [x] Auto-bind Program fields by alias name

## ✅ v3.2.50 - AccountsDerive Token Alias Expansion

- [x] Expand token/mint authority alias inference

## ✅ v3.2.49 - Anchor Associated Token Constraint Runtime

- [x] Validate ATA address derivation and token owner

## ✅ v3.2.48 - Anchor Token/Mint Constraint Runtime

- [x] Validate token account state for token constraints
- [x] Validate mint state for mint constraints
- [x] Validate token/mint program owner constraints

## ✅ v3.2.47 - AccountsDerive Program Auto Bindings (Extended)

- [x] Add auto bindings for compute budget/address lookup table/ed25519/secp256/vote/feature gate
- [x] Extend AccountsDerive tests and docs

## ✅ v3.2.46 - Anchor Zero/Space/Dup Constraints

- [x] Enforce zero constraint via discriminator check
- [x] Enforce explicit space constraint with exact size
- [x] Reject duplicate mutable accounts without dup

## ✅ v3.0.4 - Anchor IDL + Zig Client

- [x] IDL JSON generation
- [x] Zig client codegen

## ✅ v3.1.2 - Anchor Account Attrs

- [x] Account attribute DSL
- [x] Account attrs example

## ✅ v3.1.1 - Anchor Event Index Rules

- [x] Event index limit (<=4)
- [x] Multi-index tests

## ✅ v3.1.0 - Anchor Event Index

- [x] eventField wrapper
- [x] IDL event index output

## ✅ v3.0.9 - Anchor Constraint DSL

- [x] Constraint expression helper
- [x] IDL constraint output

## ✅ v3.0.8 - Anchor IDL Output

- [x] IDL file output helper
- [x] Build step for IDL generation

## ✅ v3.0.7 - Anchor Zig Client (High-level)

- [x] ProgramClient RPC wrapper
- [x] Account decode helpers
- [x] Client module integration

## ✅ v3.0.6 - Anchor IDL Extensions

- [x] IDL events/constants/metadata
- [x] Account constraint hints

## ✅ v3.0.5 - Anchor Comptime Derives

- [x] Accounts/Event DSL helpers
- [x] Documentation updates

## ⏳ v3.0.1 - Anchor Extraction (Monorepo)

- [x] Build as standalone subpackage in `anchor/`
- [x] Path dependency on `solana_program_sdk`
- [ ] CI workflow for anchor tests

## ✅ v3.0.0 - Anchor Framework Core

Phases 1-3 implemented and tracked in stories:
- `stories/v3.0.0-anchor-phase1.md`
- `stories/v3.0.0-anchor-phase2.md`
- `stories/v3.0.0-anchor-phase3.md`
