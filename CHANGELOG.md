# Changelog

All notable changes to the Solana SDK Zig implementation will be documented in this file.

### Session 2026-01-15-084

**Date**: 2026-01-15
**Goal**: Anchor DSL event emission, realloc safety, and PDA seed automation

#### Completed Work
1. Added event emission helpers and context emit support
2. Hardened realloc with payer requirement and 10KB growth limit
3. Added runtime seed resolution + PDA validation helpers
4. Updated docs, exports, and examples

#### Test Results
- Not run in this session (user-reported: anchor 195/195, sdk 363/363)

### Session 2026-01-15-085

**Date**: 2026-01-15
**Goal**: Anchor token helpers, SystemAccount, and sysvar parsing

#### Completed Work
1. Added SPL token wrappers and CPI helpers
2. Added SystemAccount wrappers
3. Added SysvarData parsing helper
4. Updated docs and examples

#### Test Results
- Not run in this session

### Session 2026-01-13-083

**Date**: 2026-01-13
**Goal**: Add InterfaceProgram unchecked variants

#### Completed Work
1. Added InterfaceProgramAny and InterfaceProgramUnchecked wrappers
2. Exported helpers and updated docs
3. Added tests for executable/unchecked behavior

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-13-082

**Date**: 2026-01-13
**Goal**: Add meta merge strategy for anchor interface CPI

#### Completed Work
1. Added meta merge strategy for Interface CPI builders
2. Applied merge to instruction metas and invoke infos
3. Updated docs and roadmap tracking

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-13-081

**Date**: 2026-01-13
**Goal**: Add rent_exempt checks for anchor interface accounts

#### Completed Work
1. Added rent_exempt config for InterfaceAccount/InterfaceAccountInfo
2. Enforced rent exemption via Rent.getOrDefault
3. Updated docs and roadmap tracking

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-13-080

**Date**: 2026-01-13
**Goal**: Extend anchor interface CPI invoke helpers

#### Completed Work
1. Added executable checks for InterfaceAccount/InterfaceAccountInfo
2. Added AccountMeta override wrapper for CPI metas
3. Added invoke/invokeSigned helpers and updated docs

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-13-079

**Date**: 2026-01-13
**Goal**: Add AccountMeta support to anchor interface CPI

#### Completed Work
1. Allowed AccountMeta inputs for Interface CPI accounts
2. Allowed AccountMeta slices for remaining accounts
3. Updated docs and roadmap tracking

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-13-078

**Date**: 2026-01-13
**Goal**: Extend anchor interface CPI helpers

#### Completed Work
1. Added `InterfaceAccountInfo` wrapper
2. Added remaining accounts support in Interface CPI builder
3. Updated docs and roadmap tracking

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-13-077

**Date**: 2026-01-13
**Goal**: Anchor interface accounts and CPI helpers

#### Completed Work
1. Added `InterfaceProgram`/`InterfaceAccount` wrappers
2. Added `Interface` CPI instruction builder
3. Updated docs and roadmap tracking

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-13-074

**Date**: 2026-01-13
**Goal**: Anchor typed program entry dispatch

#### Completed Work
1. Added `ProgramEntry` for discriminator-based dispatch
2. Added fallback handler support and optional error mapping
3. Updated documentation and roadmap tracking

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-13-075

**Date**: 2026-01-13
**Goal**: Anchor AccountLoader zero-copy access

#### Completed Work
1. Added `AccountLoader` for zero-copy account access
2. Exported loader from anchor root module
3. Updated docs and roadmap tracking

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-13-076

**Date**: 2026-01-13
**Goal**: Anchor LazyAccount on-demand decoding

#### Completed Work
1. Added `LazyAccount` with cached Borsh decoding
2. Exported LazyAccount from anchor root module
3. Updated docs and roadmap tracking

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-13-073

**Date**: 2026-01-13
**Goal**: Anchor constraint expression expansion

#### Completed Work
1. Expanded constraint expression parser with boolean/comparison operators
2. Updated docs and roadmap tracking

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-072

**Date**: 2026-01-13
**Goal**: Expand token alias inference coverage

#### Completed Work
1. Added token mint key/address aliases and authority key/address aliases
2. Added AccountsDerive tests for key/address alias inference

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-071

**Date**: 2026-01-13
**Goal**: Auto-bind Program fields by alias name

#### Completed Work
1. Applied program auto binding to Program fields
2. Added AccountsDerive test coverage
3. Updated docs, story, and roadmap

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-070

**Date**: 2026-01-13
**Goal**: Expand token alias inference in AccountsDerive

#### Completed Work
1. Added extended token/mint authority alias lists
2. Added AccountsDerive test coverage for new aliases
3. Updated docs, story, and roadmap

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-069

**Date**: 2026-01-13
**Goal**: Add runtime validation for associated token constraints

#### Completed Work
1. Validated associated token ATA address derivation, token owner field, and token program owner
2. Added tests and updated docs/story/roadmap

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-068

**Date**: 2026-01-13
**Goal**: Add runtime validation for token/mint constraints

#### Completed Work
1. Validated token account mint/authority and token program owner at runtime
2. Validated mint authority/freeze/decimals and mint program owner at runtime
3. Enforced default token program owner when custom program is absent
4. Added tests and updated docs/story/roadmap

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-067

**Date**: 2026-01-13
**Goal**: Expand program auto bindings in AccountsDerive

#### Completed Work
1. Added auto bindings for compute budget/address lookup table/ed25519/secp256/vote/feature gate programs
2. Extended AccountsDerive auto-bind tests
3. Updated docs, story, and roadmap

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-066

**Date**: 2026-01-13
**Goal**: Add zero/space/dup constraint validation

#### Completed Work
1. Enforced `zero` discriminator checks and explicit `space` validation
2. Added duplicate mutable account checks with `dup` escape hatch
3. Added tests and updated Anchor docs/story/roadmap

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-065

**Date**: 2026-01-13
**Goal**: Require token_program for associated token inference

#### Completed Work
1. Required token_program presence for associated token inference
2. Updated docs, story, and roadmap

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-064

**Date**: 2026-01-13
**Goal**: Expand AccountsDerive alias coverage

#### Completed Work
1. Expanded token/mint alias lists for inference
2. Added tests for alias-based inference
3. Updated docs, story, and roadmap

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-063

**Date**: 2026-01-13
**Goal**: Extend associated token inference to authority field

#### Completed Work
1. Allowed associated token inference when account data uses `authority`
2. Added AccountsDerive tests for authority-based inference
3. Updated docs, story, and roadmap

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-062

**Date**: 2026-01-13
**Goal**: Expand AccountsDerive program/sysvar aliases

#### Completed Work
1. Added alias-based program auto bindings (system/memo/bpf_loader/loader_v4)
2. Added `_sysvar` alias support for common sysvars
3. Updated docs, story, and roadmap

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-061

**Date**: 2026-01-13
**Goal**: Enforce rent_exempt constraint at runtime

#### Completed Work
1. Added rent_exempt validation to account constraint checks
2. Added tests for rent exemption validation
3. Updated docs, story, and roadmap

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-060

**Date**: 2026-01-13
**Goal**: Validate AccountsDerive AccountInfo targets

#### Completed Work
1. Added payer/close/realloc target validation for toAccountInfo/AccountInfo
2. Updated docs, story, and roadmap

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-059

**Date**: 2026-01-13
**Goal**: Enforce AccountsDerive cross-field program requirements

#### Completed Work
1. Added system_program requirement for init/init_if_needed
2. Added token/mint/associated token program field requirements
3. Updated docs, story, and roadmap

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-058

**Date**: 2026-01-13
**Goal**: Enforce AccessFor owner program references

#### Completed Work
1. Added AccessFor owner validation for Program/UncheckedProgram fields
2. Updated docs, story, and roadmap

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-057

**Date**: 2026-01-13
**Goal**: Validate AccountsDerive program references

#### Completed Work
1. Added program reference validation for token/mint/associated token constraints
2. Updated docs, story, and roadmap

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-056

**Date**: 2026-01-13
**Goal**: Validate AccountsDerive cross-field references

#### Completed Work
1. Added cross-field validation for token/mint/associated token references
2. Added AccountsDerive tests for ref validation
3. Updated docs, story, and roadmap

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-055

**Date**: 2026-01-13
**Goal**: Expand AccountsDerive sysvar defaults

#### Completed Work
1. Added auto-wrapping for epoch_schedule/recent_blockhashes/fees sysvar fields
2. Expanded AccountsDerive tests for sysvar defaults
3. Updated docs, story, and roadmap

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-054

**Date**: 2026-01-13
**Goal**: Expand AccountsDerive alias inference

#### Completed Work
1. Added alias lists for token/mint/ata inference (mint_account, wallet, etc.)
2. Added AccountsDerive tests for alias-based inference
3. Updated docs, story, and roadmap

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-053

**Date**: 2026-01-13
**Goal**: Enhance event index semantics validation

#### Completed Work
1. Restricted indexed event fields to bool, fixed-size ints, or PublicKey (reject usize/isize)
2. Added clearer compile-time errors for invalid index types and index overflow
3. Added tests for fixed-size indexed event fields
4. Updated docs, story, and roadmap

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-043

**Date**: 2026-01-13
**Goal**: Expand AccountsDerive auto inference for token program constraints

#### Completed Work
1. Added auto token program inference for token/mint/associated token constraints
2. Added AccountsDerive tests for auto token program inference
3. Updated roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-044

**Date**: 2026-01-13
**Goal**: Add common program auto bindings in AccountsDerive

#### Completed Work
1. Added auto bindings for memo/stake program fields
2. Expanded AccountsDerive tests for common programs
3. Updated roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-045

**Date**: 2026-01-13
**Goal**: Add token program alias auto bindings in AccountsDerive

#### Completed Work
1. Added token program alias support for AccountsDerive auto bindings
2. Added AccountsDerive tests for token program aliases
3. Updated roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-046

**Date**: 2026-01-13
**Goal**: Add associated token program alias auto bindings in AccountsDerive

#### Completed Work
1. Added associated token program alias support for AccountsDerive auto bindings
2. Added AccountsDerive tests for associated token program aliases
3. Updated roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-047

**Date**: 2026-01-13
**Goal**: Add token shape inference in AccountsDerive

#### Completed Work
1. Added token mint/authority inference from account data shape
2. Added AccountsDerive tests for token shape inference
3. Updated roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-048

**Date**: 2026-01-13
**Goal**: Expand token/mint/ata shape inference in AccountsDerive

#### Completed Work
1. Added associated token and mint shape inference for AccountsDerive
2. Added DECIMALS constant inference for mint shape
3. Added AccountsDerive tests for token/mint/ata shape inference
4. Updated roadmap/story and docs

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-049

**Date**: 2026-01-13
**Goal**: Expand AccountsDerive alias-based inference

#### Completed Work
1. Added alias-based inference for token/ata account fields
2. Added mint authority/decimals alias support
3. Added tests for alias-based inference
4. Applied merged constraint config for runtime validation
5. Updated roadmap/story and anchor docs

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-050

**Date**: 2026-01-13
**Goal**: Enforce token/mint/ata constraint combinations

#### Completed Work
1. Added compile-time checks for conflicting token/mint/ata constraints
2. Added tests for valid token/ata/mint combinations
3. Updated docs and roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-051

**Date**: 2026-01-13
**Goal**: Extend init/close/realloc runtime checks

#### Completed Work
1. Added validateInitConstraint for init/init_if_needed runtime validation
2. Enforced writable checks for close/realloc constraints
3. Added init constraint tests
4. Updated docs and roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-052

**Date**: 2026-01-13
**Goal**: Enforce owner/address/executable combination rules

#### Completed Work
1. Added owner/address expression conflict checks in Account config
2. Enforced executable constraint combination rules
3. Added executable-only test coverage
4. Updated docs and roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-042

**Date**: 2026-01-13
**Goal**: Add typed access helper for AttrsFor

#### Completed Work
1. Added AccessFor helper and AttrsFor support
2. Allowed space attr overrides for AccountField-based helpers
3. Added tests and updated roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-041

**Date**: 2026-01-13
**Goal**: Add typed init/close/realloc helpers for AttrsFor

#### Completed Work
1. Added InitFor/CloseFor/ReallocFor helpers
2. Enabled AttrsFor init_with/close_to/realloc_with and added tests
3. Updated roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-040

**Date**: 2026-01-13
**Goal**: Add typed token helpers for AttrsFor

#### Completed Work
1. Added AssociatedTokenFor/TokenFor/MintFor helpers
2. Enabled AttrsFor typed token configs and added tests
3. Updated roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-039

**Date**: 2026-01-13
**Goal**: Detect Attrs/AttrsFor conflicts with Account config

#### Completed Work
1. Added conflict checks for Attrs vs Account config
2. Updated roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-038

**Date**: 2026-01-13
**Goal**: Add typed has_one specs for AttrsFor

#### Completed Work
1. Added HasOneSpecFor typed builder
2. Enabled AttrsFor to accept typed has_one specs
3. Added tests and updated roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-037

**Date**: 2026-01-13
**Goal**: Add typed seed specs for AttrsFor

#### Completed Work
1. Added SeedSpecFor/seedSpecsFor typed seed builders
2. Enabled AttrsFor to accept typed seeds for seeds/seeds_program
3. Added tests and updated roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-036

**Date**: 2026-01-13
**Goal**: Add AttrsFor with typed field enums

#### Completed Work
1. Added AttrsFor to resolve field enums into AccountAttrConfig
2. Added AttrsFor tests and export
3. Updated roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-035

**Date**: 2026-01-13
**Goal**: Add typed Attrs marker for AccountsDerive fields

#### Completed Work
1. Added Attrs/AttrsWith helpers for typed field annotations
2. Added Attrs marker tests and exports
3. Updated roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-034

**Date**: 2026-01-13
**Goal**: Validate has_one/seeds references in AccountsDerive

#### Completed Work
1. Added has_one target type validation in AccountsDerive
2. Added seedAccount/seedBump reference validation in AccountsDerive
3. Added tests and updated roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-033

**Date**: 2026-01-13
**Goal**: Infer init/payer/realloc/close constraints in AccountsDerive

#### Completed Work
1. Added derived mut/signer inference for init/realloc/close/payer fields
2. Added tests and updated roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-032

**Date**: 2026-01-13
**Goal**: Auto-bind common sysvar fields in AccountsDerive

#### Completed Work
1. Added SysvarId helper for sysvars without data types
2. Auto-bound common sysvar fields (clock/instructions/stake_history/etc.)
3. Added tests and updated roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-031

**Date**: 2026-01-13
**Goal**: Auto-bind common program/sysvar fields in AccountsDerive

#### Completed Work
1. Added Sysvar account wrapper for address validation
2. Auto-bound associated_token_program and rent sysvar fields
3. Added tests and updated roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-030

**Date**: 2026-01-13
**Goal**: Auto-bind common program fields in AccountsDerive

#### Completed Work
1. Added auto-binding for system_program/token_program UncheckedProgram fields
2. Added tests and updated roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-029

**Date**: 2026-01-13
**Goal**: Apply typed attrs to Program fields in AccountsDerive

#### Completed Work
1. Added ProgramField to apply address/owner/executable attrs
2. Applied Program/UncheckedProgram attrs in AccountsWith/AccountsDerive
3. Added tests and updated roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-028

**Date**: 2026-01-13
**Goal**: Apply typed attrs to Signer fields in AccountsDerive

#### Completed Work
1. Allowed AccountsWith/AccountsDerive to map mut attrs onto Signer fields
2. Added Signer attr mapping tests
3. Updated roadmap and story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-027

**Date**: 2026-01-13
**Goal**: Remove string-based account attrs

#### Completed Work
1. Removed `attr.parseAccount` and string attr parsing paths
2. Migrated examples/tests to typed attr config and AccountsDerive
3. Updated docs, roadmap, and story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

---

### Session 2026-01-13-026

**Date**: 2026-01-13
**Goal**: Add macro expression support for owner/address/space

#### Completed Work
1. Added owner/address/space expression support in macro-style parsing
2. Implemented space expression resolution and runtime owner/address checks
3. Updated docs, roadmap, and story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ./solana-zig/zig build test --summary all`

---

### Session 2026-01-13-025

**Date**: 2026-01-13
**Goal**: Expand Anchor macro-style account parsing

#### Completed Work
1. Extended parseAccount to support macro-style syntax (rent_exempt modes, realloc:: keys, token/mint constraints, zero/dup, unquoted constraint expressions, byte seeds)
2. Added AccountsWith support for string attrs and expanded tests
3. Updated docs, roadmap, and story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ./solana-zig/zig build test --summary all`

---

### Session 2026-01-12-024

**Date**: 2026-01-12
**Goal**: Add AccountsWith derive helper

#### Completed Work
1. Added AccountsWith to apply field attrs in a derive-like config
2. Added AccountsWith tests and updated docs
3. Updated roadmap and story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ./solana-zig/zig build test --summary all`

---

### Session 2026-01-12-023

**Date**: 2026-01-12
**Goal**: Execute constraint expressions at runtime

#### Completed Work
1. Added constraint expression parser and evaluator
2. Integrated runtime constraint checks in account validation
3. Updated docs, roadmap, and story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ./solana-zig/zig build test --summary all`

---

### Session 2026-01-12-022

**Date**: 2026-01-12
**Goal**: Add account semantics for init_if_needed and token constraints

#### Completed Work
1. Added init_if_needed and token/associated token attrs/config fields
2. Added parseAccount support for token/associated token keys
3. Validated Accounts references for token constraints
4. Updated docs, roadmap, and story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ./solana-zig/zig build test --summary all`

---

### Session 2026-01-12-021

**Date**: 2026-01-12
**Goal**: Add Accounts field-level attrs helper

#### Completed Work
1. Added `AccountField` helper to merge attrs into Account config
2. Updated root exports and tests for field-level attrs
3. Updated docs, roadmap, and story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ./solana-zig/zig build test --summary all`

---

### Session 2026-01-12-020

**Date**: 2026-01-12
**Goal**: Add typed field helper utilities

#### Completed Work
1. Added typed field selectors for Accounts/data fields and lists
2. Added typed helpers for seeds and has_one specs
3. Updated docs, roadmap, and story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ./solana-zig/zig build test --summary all`

---

### Session 2026-01-12-019

**Date**: 2026-01-12
**Goal**: Add compile-time account attr type checks

#### Completed Work
1. Validated has_one/seed/bump field references against account data
2. Validated payer/close/has_one/seeds account references against Accounts struct
3. Updated docs, roadmap, and story for typed constraint enforcement

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ./solana-zig/zig build test --summary all`

---

### Session 2026-01-12-018

**Date**: 2026-01-12
**Goal**: Add account attribute string parser

#### Completed Work
1. Added `anchor.attr.parseAccount` for `#[account(...)]`-style strings
2. Implemented seed/program/bump/has_one/realloc parsing
3. Added parser tests and updated docs/roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ./solana-zig/zig build test --summary all`

---

### Session 2026-01-12-017

**Date**: 2026-01-12
**Goal**: Extend account attr parsing for bump and seeds::program

#### Completed Work
1. Added bump field and seeds::program support to account attr DSL
2. Emitted `pda.program` for seeds::program in IDL output
3. Added account/IDL tests for program seed mapping
4. Updated docs, roadmap, and story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ./solana-zig/zig build test --summary all`

---

### Session 2026-01-12-016

**Date**: 2026-01-12
**Goal**: Add macro-style account attribute sugar

#### Completed Work
1. Added `AccountAttrConfig` with `anchor.attr.account(...)` helper
2. Added has_one shorthand mapping for account attributes
3. Updated docs, roadmap, and story for account attr sugar
4. Added tests covering macro-style attribute mapping

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ./solana-zig/zig build test --summary all`

---

### Session 2026-01-12-014

**Date**: 2026-01-12
**Goal**: Default root IDL output to idl/

#### Completed Work
1. Added root IDL output directory option with default naming
2. Updated root IDL CLI to derive file name from program metadata/type name
3. Synced README, compatibility docs, ROADMAP, and Story

#### Test Results
- `./solana-zig/zig build idl`

---

### Session 2026-01-12-015

**Date**: 2026-01-12
**Goal**: Tighten event index validation

#### Completed Work
1. Restricted indexed event fields to scalar and PublicKey types
2. Updated Anchor compatibility docs and roadmap/story

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ./solana-zig/zig build test --summary all`

---

### Session 2026-01-12-013

**Date**: 2026-01-12
**Goal**: Integrate root IDL build step

#### Completed Work
1. Added root `zig build idl` step with anchor IDL CLI
2. Updated README and compatibility docs for root IDL usage
3. Added roadmap/story entries for root IDL integration

#### Test Results
- Not run (build tooling changes)

---

### Session 2026-01-12-012

**Date**: 2026-01-12
**Goal**: Add event index validation rules

#### Completed Work
1. Enforced max 4 indexed fields in event DSL
2. Added multi-index event tests
3. Updated docs and roadmap entries

#### Test Results
- Anchor: `zig build test` 154 passed

---

### Session 2026-01-12-011

**Date**: 2026-01-12
**Goal**: Add Account attribute DSL

#### Completed Work
1. Added `anchor.attr` helpers and `.attrs` support
2. Added Account attr merge tests
3. Updated docs and roadmap entries

#### Test Results
- Anchor: `zig build test` 154 passed


---

### Session 2026-01-12-009

**Date**: 2026-01-12
**Goal**: Add Anchor constraint expression DSL

#### Completed Work
1. Added `anchor.constraint()` helper and account config support
2. Emitted constraint expressions in IDL
3. Updated docs and roadmap entries

#### Test Results
- Anchor: `zig build test` 153 passed

---

### Session 2026-01-12-008

**Date**: 2026-01-12
**Goal**: Add IDL JSON output tooling

#### Completed Work
1. Added `anchor.idl.writeJsonFile` helper
2. Added `zig build idl` step with `idl-program`/`idl-output` options
3. Added IDL CLI and example program module
4. Updated docs and roadmap entries

#### Test Results
- Not run (build tooling changes)

---

### Session 2026-01-12-007

**Date**: 2026-01-12
**Goal**: Add high-level Anchor client codegen

#### Completed Work
1. Added anchor client helper module under client/
2. Extended codegen with ProgramClient wrapper and decode helpers
3. Updated documentation and roadmap entries

#### Test Results
- Anchor: `zig build test` 153 passed

---

### Session 2026-01-12-006

**Date**: 2026-01-12
**Goal**: Extend Anchor IDL sections

#### Completed Work
1. Added events/constants/metadata to IDL output
2. Added account constraint hints to IDL (including rent_exempt)
3. Added tests covering new IDL sections
4. Updated ROADMAP and compatibility docs

#### Test Results
- Anchor: `zig build test` 153 passed


---

### Session 2026-01-12-004

**Date**: 2026-01-12
**Goal**: Add Anchor IDL + Zig client codegen

#### Completed Work
1. Added Anchor IDL JSON generation (comptime reflection)
2. Added Zig client code generator for instructions
3. Updated Anchor docs and README for IDL/codegen
4. Added ROADMAP entry for v3.0.4

#### Test Results
- Anchor: `zig build test` 152 passed

---

### Session 2026-01-12-003

**Date**: 2026-01-12
**Goal**: Add P1/P2 documentation guides

#### Completed Work
1. Added compute budget guide
2. Added token programs guide and Token-2022 status
3. Added anchor compatibility guide
4. Added error handling guide
5. Updated ROADMAP for v3.0.3 docs

#### Test Results
- Not run (documentation-only changes)

---

### Session 2026-01-12-002

**Date**: 2026-01-12
**Goal**: Add P0 deployment/testing docs

#### Completed Work
1. Added deployment guide and testing guide
2. Linked docs from README
3. Added ROADMAP entry for documentation P0

#### Test Results
- Not run (documentation-only changes)

---

### Session 2026-01-12-001

**Date**: 2026-01-12
**Goal**: Extract anchor into monorepo subpackage

#### Completed Work
1. Added `anchor/` subpackage with standalone build files
2. Moved anchor sources and updated imports to use `solana_program_sdk`
3. Removed anchor export from main SDK root
4. Added `Rent.getOrDefault()` to avoid noisy non-BPF logs
5. Re-exported `solana_program_sdk` as `anchor.sdk`
6. Ensured keypair generation creates install directories
7. Switched example programs to ReleaseSmall for SBF
8. Updated roadmap and stories for new layout

#### Test Results
- Anchor: `zig build test` 152 passed
- Examples: `zig build` (examples/programs)

---

## [v2.4.0] - 2026-01-08 - SDK Enhancements & Cross-Validation

**Goal**: Enhance SDK APIs for Rust compatibility, improve security, and add comprehensive cross-validation tests

### Added

#### PublicKey Auto-Conversion (`sdk/src/public_key.zig`)
- `createProgramAddress` now auto-converts `PublicKey` seeds to byte slices (matches `findProgramAddress`)
- 3 new tests for auto-conversion

#### Keypair Security & API (`sdk/src/keypair.zig`)
- **BREAKING**: `fromBytes` now validates embedded public key matches derived key
- **BREAKING**: `sign` now returns `!Signature` (error on failure) instead of zero signature
- Added `SigningFailed` error to `SignerError` enums
- Rust API aliases: `new`, `fromSeedBytes`, `fromBase58String`, `toBase58String`, `secret`, `signMessage`, `tryPubkey`
- 5 new tests

#### Signature API (`sdk/src/signature.zig`)
- Rust API aliases: `new`, `fromStr`, `toString`, `asRef`, `toBytes`

#### Error Serialization (`sdk/src/error.zig`, `sdk/src/instruction_error.zig`)
- Comprehensive tests for all 26 builtin ProgramError values
- `InstructionError.fromU64()` and `toU64()` helpers for RPC serialization
- 6 new tests

#### Instruction Type (`sdk/src/instruction.zig`)
- Added `Instruction` struct matching Rust's `solana_instruction::Instruction`
- Constructors: `newWithBytes`, `newWithBorsh`, `newWithBincode`, `initBorrowed`
- `AccountMeta` accessors: `getPubkey()`, `isSigner()`, `isWritable()`
- `Instruction` accessors: `getProgramId()`, `getAccounts()`, `getData()`
- 8 new tests

#### TransactionError Helpers (`sdk/src/transaction_error.zig`)
- `encodeInstructionError()` and `decodeInstructionError()` for RPC serialization
- 2 new tests

#### Nonce Strict Validation (`sdk/src/nonce.zig`)
- **BREAKING**: `serialize` and `deserialize` now require **exact** 80-byte buffer (was >= 80)
- Matches Rust SDK behavior, prevents misinterpreting extended/truncated data
- 2 new tests

#### Program Logging (`src/log.zig`)
- `logData` now outputs base64-encoded data in non-BPF mode (was raw bytes)
- Added `formatLogData` helper for testing
- 3 new tests

#### Integration Tests (`program-test/integration/test_pubkey.zig`)
- **Bincode/Borsh complex type serialization**: struct, optional, array, nested struct roundtrips
- **End-to-end transaction tests**: instruction building, message header encoding, complete transaction structure, keypair sign/verify, PDA derivation consistency
- 11 new integration tests

### Changed
- Updated all callers of `Keypair.sign` to handle errors: `src/signer.zig`, `src/transaction.zig`, `client/src/transaction/signer.zig`, `client/src/transaction/builder.zig`

### Tests
- SDK: 305 tests (+7)
- Program SDK: 297 tests (+3)
- Client: 159 tests
- Integration: 105 tests (+11)
- **Total: 866 tests**

### Verified
- All tests pass in Debug and ReleaseFast modes
- No undefined behavior detected

---

## [v2.2.0] - 2026-01-07 - Stake Program Interface

**Goal**: Implement Solana Stake program interface for staking operations and validator delegation

### Added

#### Stake Program State Types (`sdk/src/spl/stake/state.zig`)
- `STAKE_PROGRAM_ID` - Stake program ID
- `STAKE_CONFIG_PROGRAM_ID` - Stake config program ID (deprecated)
- `StakeStateV2` enum - Main stake account state (Uninitialized, Initialized, Stake, RewardsPool)
- `Meta` struct (120 bytes) - Stake account metadata (rent_exempt_reserve, authorized, lockup)
- `Authorized` struct (64 bytes) - Staker and withdrawer authorities
- `Lockup` struct (48 bytes) - Lockup configuration (unix_timestamp, epoch, custodian)
- `Stake` struct (72 bytes) - Active stake information (delegation, credits_observed)
- `Delegation` struct (64 bytes) - Delegation details (voter_pubkey, stake, activation/deactivation epochs)
- `StakeFlags` packed struct - Bitflags for stake state
- `StakeAuthorize` enum - Staker (0), Withdrawer (1)
- `LockupArgs` and `LockupCheckedArgs` - Lockup modification arguments
- Pack/unpack methods for all types
- Constants: `DEFAULT_WARMUP_COOLDOWN_RATE`, `NEW_WARMUP_COOLDOWN_RATE`, `DEFAULT_SLASH_PENALTY`, `MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION`
- Functions: `warmupCooldownRate()` - Get rate based on epoch/feature activation
- `Delegation` methods: `isBootstrap()`, `getStake()`, `stakeActivatingAndDeactivating()`
- `Stake` methods: `getStake()`, `split()`

#### Stake History (`sdk/src/spl/stake/stake_history.zig`) - NEW
- `MAX_ENTRIES` constant (512)
- `StakeHistoryEntry` struct (24 bytes) - effective, activating, deactivating amounts
- `StakeHistory` struct - Collection of history entries with epoch lookup
- `StakeHistoryGetEntry` trait - Interface for history lookup
- Constructor methods: `withEffective()`, `withEffectiveAndActivating()`, `withDeactivating()`
- 10 unit tests

#### Stake Tools (`sdk/src/spl/stake/tools.zig`) - NEW
- `EpochCredits` struct - Epoch credits tuple (epoch, credits, prev_credits)
- `acceptableReferenceEpochCredits()` - Check if vote account is acceptable reference for deactivate_delinquent
- `eligibleForDeactivateDelinquent()` - Check if vote account is eligible for deactivation
- 5 unit tests

#### Stake Program Instructions (`sdk/src/spl/stake/instruction.zig`)
- `StakeInstruction` enum - All 18 instruction variants (0-17)
- `AuthorizeWithSeedArgs` struct
- `AuthorizeCheckedWithSeedArgs` struct
- Instruction builders: `initialize()`, `authorize()`, `delegateStake()`, `split()`, `withdraw()`, `deactivate()`, `setLockup()`, `merge()`, `getMinimumDelegation()`, `deactivateDelinquent()`, `moveStake()`, `moveLamports()`
- 14 unit tests

#### Stake Program Errors (`sdk/src/spl/stake/error.zig`)
- `StakeError` enum - All 17 error variants (0-16)
- `fromCode()` and `toCode()` conversion methods
- `message()` and `toStr()` for error descriptions
- 5 unit tests

#### Stake Client Instructions (`client/src/spl/stake/instruction.zig`) - NEW
- Full instruction builders for all 18 instructions
- Proper account meta setup for each instruction
- Integration with client Instruction type

#### Module Exports
- Created `sdk/src/spl/stake/root.zig` - Module exports
- Updated `sdk/src/spl/root.zig` to export `stake` module
- Created `client/src/spl/stake/root.zig` - Client module exports
- Updated `client/src/spl/root.zig` to export `stake` module
- Added `STAKE_PROGRAM_ID` convenience re-export

### Documentation
- Updated `stories/v2.2.0-stake-program.md` - Story file marked complete
- Updated `ROADMAP.md` - Marked v2.2.0 as complete

### Tests
- SDK: 253 tests
- Program SDK: 294 tests  
- Client: 148 tests
- **Total: 695 tests**

---

## [v2.3.0] - 2026-01-07 - SPL Memo Program

**Goal**: Implement SPL Memo program interface for attaching UTF-8 text to transactions

### Added

#### SPL Memo Program (`sdk/src/spl/memo.zig`)
- `MEMO_PROGRAM_ID` - Current Memo program ID (v2/v3)
- `MEMO_V1_PROGRAM_ID` - Legacy Memo program ID (v1)
- `MemoInstruction` struct - Memo instruction builder
  - `init()` - Create memo instruction (no validation)
  - `initValidated()` - Create memo instruction with UTF-8 validation
  - `getData()` - Get raw UTF-8 instruction data
  - `getProgramId()` - Get memo program ID
  - `createSignerAccounts()` - Create AccountMeta array for signers
- `isValidUtf8()` - Validate UTF-8 data
- `findInvalidUtf8Position()` - Find position of invalid UTF-8 byte

#### Module Exports
- Updated `sdk/src/spl/root.zig` to export `memo` module
- Added `MEMO_PROGRAM_ID` convenience re-export

### Documentation
- Created `stories/v2.3.0-memo-program.md` - Story file with acceptance criteria
- Updated `ROADMAP.md` - Marked v2.3.0 as complete

### Tests
- SDK: 196 tests (11 new memo tests)
- Program SDK: 294 tests
- **Total: 620+ tests**

---

## [v2.0.0] - 2026-01-07 - SPL Token & Associated Token Account

**Goal**: Implement SPL Token program interface for the Zig Client SDK

### Added

#### SPL Token State Types (`client/src/spl/token/state.zig`)
- `COption(T)` - Generic C-style optional type with 4-byte tag + value encoding
- `AccountState` enum - Uninitialized (0), Initialized (1), Frozen (2)
- `Mint` struct (82 bytes) - Token mint account with pack/unpack
- `Account` struct (165 bytes) - Token account with pack/unpack
- `Multisig` struct (355 bytes) - Multisig account with pack/unpack
- `TOKEN_PROGRAM_ID` constant
- Comprehensive unit tests for all types

#### SPL Token Instructions (`client/src/spl/token/instruction.zig`)
- `TokenInstruction` enum - All 25 instruction types (0-24)
- `AuthorityType` enum - MintTokens, FreezeAccount, AccountOwner, CloseAccount
- Instruction builders:
  - `initializeMint()`, `initializeMint2()`
  - `initializeAccount()`, `initializeAccount2()`, `initializeAccount3()`
  - `initializeMultisig()`, `initializeMultisig2()`
  - `transfer()`, `transferMultisig()`, `transferChecked()`
  - `approve()`, `approveChecked()`, `revoke()`
  - `setAuthority()`
  - `mintTo()`, `mintToChecked()`
  - `burn()`, `burnChecked()`
  - `closeAccount()`
  - `freezeAccount()`, `thawAccount()`
  - `syncNative()`
  - `getAccountDataSize()`, `initializeImmutableOwner()`
  - `amountToUiAmount()`, `uiAmountToAmount()`
- Unit tests for instruction data format validation

#### SPL Token Errors (`client/src/spl/token/error.zig`)
- `TokenError` enum - All 20 error codes (0-19)
- `fromCode()` - Convert error code to enum
- `toCode()` - Convert enum to error code
- `message()` - Human-readable error descriptions

#### Associated Token Account (`client/src/spl/associated_token.zig`)
- `ASSOCIATED_TOKEN_PROGRAM_ID` constant
- `AssociatedTokenInstruction` enum - Create (0), CreateIdempotent (1), RecoverNested (2)
- `findAssociatedTokenAddress()` - PDA derivation with correct seed order [wallet, token_program, mint]
- `findAssociatedTokenAddressWithProgram()` - Custom token program support
- `getAssociatedTokenAddress()` - Convenience wrapper
- `create()` - Create ATA instruction
- `createIdempotent()` - Create ATA idempotent instruction (recommended)
- `createIdempotentWithProgram()` - Create with custom token program
- `recoverNested()` - Recover nested ATA instruction
- Comprehensive unit tests

#### Module Exports
- `client/src/spl/token/root.zig` - Token module exports
- `client/src/spl/root.zig` - SPL module exports
- Updated `client/src/root.zig` to export `spl` module

### Documentation
- Created `docs/design/spl-token.md` - Detailed design document
- Created `stories/v2.0.0-spl-token.md` - Story file with acceptance criteria

### Tests
- SDK: 185 tests (including Rust SDK test coverage port)
- Program SDK: 294 tests
- Client SDK: 130 tests
- **Total: 609 tests**

### Test Coverage Enhancement
- Ported all Rust SPL Token `#[test]` functions to Zig
- Added `pack()` methods to all instruction Data types for roundtrip testing
- Added `unpackAccountOwner()` and `unpackAccountMint()` helper functions
- Added fuzz test: 256 instruction tags × 10 data lengths
- Added exhaustive `TokenError` roundtrip test (all 20 error codes)

---

## Session 2026-01-07-003

**Date**: 2026-01-07
**Goal**: Research SPL Programs and Update Roadmap

#### Completed Work

1. **Researched solana-program Organization (35 repositories)**:
   - Analyzed https://github.com/solana-program and https://github.com/solana-labs/solana-program-library
   - Categorized programs by priority (P0/P1/P2) for Zig SDK implementation
   - Identified 7 programs already implemented, 7 planned for v2.x

2. **Detailed Research on Key Programs**:

   **SPL Token** (`TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA`):
   - 25 instructions documented
   - Data structures: Mint (82 bytes), Account (165 bytes), Multisig (355 bytes)
   - AuthorityType enum, COption encoding format

   **Token-2022** (`TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb`):
   - TLV extension architecture (Type-Length-Value)
   - 20+ extensions documented (TransferFee, ConfidentialTransfer, MetadataPointer, etc.)
   - Extension instruction prefixes (26-44)

   **Associated Token Account** (`ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL`):
   - PDA derivation: seeds = [wallet, token_program, mint]
   - 3 instructions: Create, CreateIdempotent, RecoverNested

   **Stake Program** (`Stake11111111111111111111111111111111111111`):
   - 17 active instructions (Initialize, Delegate, Withdraw, etc.)
   - StakeStateV2 enum (200 bytes fixed)
   - Data structures: Meta, Authorized, Lockup, Delegation, Stake

   **Memo Program** (`MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr`):
   - Simple UTF-8 validation + optional signer verification
   - No discriminator - data is raw UTF-8 bytes

3. **Updated ROADMAP.md with Comprehensive Plan**:
   - v2.0.0: SPL Token + Associated Token Account (P0)
   - v2.1.0: Token-2022 Extensions (P0)
   - v2.2.0: Stake Program Interface (P0)
   - v2.3.0: Memo Program (P2)
   - v2.4.0: Stake Pool + Token Metadata (P1)
   - v2.5.0: Example Programs
   - v3.0.0: Advanced Features

4. **Added Coverage Summary**:
   - Already implemented: System, Compute Budget, ALT, BPF Loaders, Vote, Feature Gate
   - Planned: Token, ATA, Token-2022, Stake, Memo, Stake Pool, Metadata

4. **Extended Research - Missing Programs Identified**:

   **Native Programs (Already in SDK)**:
   - 14 programs already implemented (System, Compute Budget, ALT, BPF Loaders, Vote, Feature Gate, Ed25519, Secp256k1, Secp256r1, Native Loader, Incinerator)

   **Metaplex NFT Programs (Added to Roadmap v2.4.0)**:
   - Token Metadata: `metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s`
   - Metaplex Core: `CoREENxT6tW1HoK8ypY1SxRMZTcVPm7R94rH4PZNhX7d`
   - Bubblegum (cNFT): `BGUMAp9Gq7iTEuizy4pqaxsTyUCBK68MDfK752saRPUY`
   - SPL Account Compression: `cmtDvXumGCrqC1Age74AVPhSRVXJMd8PJS91L8KbNCK`

   **Oracle Programs (Added to Roadmap v2.5.0)**:
   - Pyth: `pythWSnswVUd12oZpeFP8e9CVaEqJg25g1Vtc2biRsTC`
   - Switchboard: `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f`

   **Additional Programs (Added)**:
   - Config Program: `Config1111111111111111111111111111111111111`
   - Name Service: `namesLPneVptA9Z5rqUDD9tMTWEJwofgaYwp8cawRkX`
   - Candy Machine v3: `CndyV3LdqHUfDLmE5naZjVN8rBZz4tqhdefbAnjHG3JR`

   **Third-Party DeFi (Interface Only)**:
   - Jupiter V6: 10% of chain activity
   - Raydium AMM V4: 7% of chain activity
   - Orca Whirlpool

5. **Updated ROADMAP.md**:
   - v2.4.0: Metaplex NFT Programs (Token Metadata, Core, Bubblegum)
   - v2.5.0: Oracle & Utility Programs (Pyth, Switchboard, Config, Name Service)
   - v2.6.0: Additional SPL (Stake Pool, Candy Machine)
   - v2.7.0: Example Programs (renumbered)
   - Added complete Program ID list for all implemented programs
   - Added Third-Party DeFi section for CPI integration

#### Reference Links Collected
- SPL Token: https://github.com/solana-program/token
- Token-2022: https://github.com/solana-program/token-2022
- ATA: https://github.com/solana-program/associated-token-account
- Stake: https://github.com/solana-program/stake
- Memo: https://github.com/solana-program/memo
- Token Metadata: https://github.com/metaplex-foundation/mpl-token-metadata
- Metaplex Core: https://github.com/metaplex-foundation/mpl-core
- Bubblegum: https://github.com/metaplex-foundation/mpl-bubblegum
- Pyth: https://github.com/pyth-network/pyth-sdk-solana

6. **Designed sol-anchor-zig Framework (v3.0.0)**:

   **Anchor Architecture Research**:
   - `#[program]` macro → comptime dispatch generation
   - `#[derive(Accounts)]` → comptime struct introspection
   - Discriminator: 8-byte SHA256("namespace:name")[0..8]
   - Error codes: Framework (0-5999), Custom (6000+)
   - Constraints: mut, signer, init, seeds, bump, has_one, address, owner, constraint, close, realloc

   **Zig Comptime Capabilities**:
   - `@typeInfo` for struct field inspection
   - `@Type` for type generation
   - `@field` for dynamic field access
   - `inline for` for compile-time iteration
   - No heap allocation at comptime (limitation)

   **sol-anchor-zig Design**:
   - `anchor.Account(T, constraints)` - Account wrapper with validation
   - `anchor.Signer(.{})` - Signer account type
   - `anchor.Context(Accounts)` - Instruction context
   - `anchor.Program(config)` - Program definition
   - Comptime discriminator generation
   - Comptime IDL generation
   - Anchor-compatible error codes

   **Implementation Phases**:
   - Phase 1: Core framework (Account, Signer, Context, basic constraints)
   - Phase 2: PDA support (seeds, bump, init with CPI)
   - Phase 3: Advanced constraints (has_one, close, realloc)
   - Phase 4: Serialization (Borsh with discriminator)
   - Phase 5: Developer experience (IDL, client codegen)

#### Current Status
- Program SDK: 300/300 tests passed
- Client SDK: 102/102 unit tests passed
- Integration tests: 57/65 passed (8 skipped - validator config dependent)

---

## Session 2026-01-07-002

**Date**: 2026-01-07
**Goal**: Implement v1.2.0 WebSocket PubSub Client

#### Completed Work
1. **Implemented WebSocket PubSub Client**:
   - Created `client/src/pubsub/types.zig` - Notification types (SlotInfo, UiAccount, RpcLogsResponse, etc.)
   - Created `client/src/pubsub/pubsub_client.zig` - Core WebSocket client with 9 subscription methods
   - Created `client/src/pubsub/root.zig` - Module exports

2. **9 Subscription Methods Implemented**:
   - `accountSubscribe` / `accountUnsubscribe` - Account change notifications
   - `blockSubscribe` / `blockUnsubscribe` - New block notifications
   - `logsSubscribe` / `logsUnsubscribe` - Transaction log notifications
   - `programSubscribe` / `programUnsubscribe` - Program account changes
   - `rootSubscribe` / `rootUnsubscribe` - Root slot changes
   - `signatureSubscribe` / `signatureUnsubscribe` - Signature confirmation
   - `slotSubscribe` / `slotUnsubscribe` - Slot updates
   - `slotsUpdatesSubscribe` / `slotsUpdatesUnsubscribe` - Detailed slot updates
   - `voteSubscribe` / `voteUnsubscribe` - Vote notifications

3. **Build System Updates**:
   - Added websocket.zig dependency to `client/build.zig.zon`
   - Updated `client/build.zig` with websocket module import
   - Exported pubsub module from `client/src/root.zig`

4. **Documentation Updates**:
   - Created `stories/v1.2.0-websocket-pubsub.md`
   - Updated `ROADMAP.md` with v1.2.0 section

#### Test Results
- Client SDK tests: 102 passed (was 91, added 11 PubSub tests)
- Program SDK tests: 300 passed

#### Technical Details
- WebSocket library: karlseguin/websocket.zig (TLS 1.3 only)
- Protocol: JSON-RPC 2.0 over WebSocket
- Default Solana WebSocket port: 8900

---

## Session 2026-01-07-001

**Date**: 2026-01-07
**Goal**: Complete v1.1.0 Client SDK + CI Integration Tests with Surfpool

#### Completed Work
1. **Completed v1.1.0 Client SDK**:
   - All 52 RPC methods implemented
   - 6 convenience methods (sendAndConfirmTransaction, confirmTransaction, etc.)
   - All response parsers fully implemented (no TODOs)

2. **Separated Integration Tests**:
   - Created `client/integration/test_rpc.zig` with 37 RPC integration tests
   - Updated `client/build.zig` with `integration-test` build step
   - Removed integration tests from `rpc_client.zig` (now unit tests only)

3. **Added CI Integration with Surfpool**:
   - Added `client-test` job for Client SDK unit tests
   - Added `client-integration-test` job with Surfpool for RPC tests
   - Added format check for `client/src/`

4. **Documentation Updates**:
   - Updated `stories/v1.1.0-client-sdk.md` - marked as ✅ complete
   - Updated `ROADMAP.md` - marked v1.1.0 as complete

#### Test Results
- Client unit tests: 71/71 passed
- Client integration tests: 37/37 passed (with local validator)
- Main project: 300/300 tests passed

#### CI Commands
```bash
# Client unit tests
cd client && ../solana-zig/zig build test

# Client integration tests (requires surfpool or solana-test-validator)
surfpool start --no-tui &
cd client && ../solana-zig/zig build integration-test
```

---

## Session 2026-01-06-002

**日期**: 2026-01-06
**目标**: Bug Fix - big_mod_exp.zig compilation error

#### 完成的工作
1. Fixed `src/big_mod_exp.zig` compilation error:
   - Added missing `initFromBytes()` helper function for initializing `Managed` big integers from little-endian byte arrays
   - Fixed `writeTwosComplement()` API call - Zig 0.15 only takes 2 parameters (removed `.unsigned`)
2. Updated `stories/v0.2.0-serialization.md`:
   - Marked `serialize_utils.zig` as out of scope (client-only)
   - Updated status to ✅ completed

#### 测试结果
- 375/375 tests passed ✅

---

## Session 2026-01-06-001

**日期**: 2026-01-06
**目标**: MCL Integration for Off-Chain BN254 Operations

#### 完成的工作
1. Created `src/mcl.zig` - Complete MCL (Multiprecision Computing Library) bindings
   - High-level Zig wrapper types: `G1`, `G2`, `GT`, `Fr`, etc.
   - Extern C declarations for MCL BN254 API
   - `mcl_available` compile-time flag controlled by build options
   - `init()`, `pairing()`, serialization/deserialization functions
2. Updated `src/bn254.zig` to use MCL when available for off-chain operations
   - `g1AdditionLE()` now uses MCL for off-chain mode
   - Dual implementation: syscalls (on-chain) + MCL (off-chain)
3. Updated `build.zig` with MCL build options:
   - `-Dwith-mcl`: Auto-build MCL from source (requires clang)
   - `-Dmcl-lib=<path>`: Use pre-compiled MCL static library
   - Clang version auto-detection (clang-20, clang)
4. Added MCL as git submodule in `vendor/mcl/`
5. Updated `src/root.zig` to export mcl module

#### Build Commands
```bash
# Without MCL (syscalls only, for on-chain)
./solana-zig/zig build test

# With MCL (off-chain testing) - auto-builds if needed
./solana-zig/zig build test -Dwith-mcl
```

#### 测试结果
- Without MCL: 370/370 tests passed
- With MCL: 370/370 tests passed
- MCL auto-build: Works with clang-20/clang + libc++

#### 技术说明
- MCL must be compiled with Clang + libc++ for Zig ABI compatibility
- MCL provides native BN254 operations for off-chain testing/development
- On-chain programs use Solana syscalls (sol_alt_bn128_*)

---

## Session 2026-01-05-002

**日期**: 2026-01-05
**目标**: Complete v0.23.0 - Advanced Crypto

#### 完成的工作
1. Implemented `bn254.zig` - BN254 elliptic curve operations for ZK proofs
2. Implemented `big-mod-exp.zig` - Modular exponentiation with BigInt support
3. Added curve parameter constants and basic elliptic curve operations
4. Implemented point compression/decompression for BN254
5. Added comprehensive test coverage for crypto operations
6. Updated root.zig to export new crypto modules
7. Updated ROADMAP.md to mark v0.23.0 as completed (96% → 98% coverage)
8. Added CHANGELOG.md entry for v0.23.0 completion

#### 测试结果
- 单元测试: 292 tests passed
- 集成测试: passed
- 编译测试: all modules compile successfully with solana-zig
- 内存安全: no leaks detected in crypto operations

#### 下一步
- [ ] Begin v0.24.0 - Extended Native Programs
- [ ] Implement loader-v4 interface
- [ ] Add secp256r1 program support

---

## Session 2026-01-05-001

**日期**: 2026-01-05
**目标**: Complete v0.22.0 - Sysvar Completion

#### 完成的工作
1. Implemented `last_restart_slot.zig` - Restart slot sysvar tracking
2. Implemented `sysvar_id.zig` - All system variable public key constants
3. Implemented `epoch_rewards.zig` - Epoch reward distribution tracking
4. Completed `sysvar.zig` - Unified sysvar access functions and validation
5. Added comprehensive test coverage for all sysvar functionality
6. Updated ROADMAP.md to reflect completion status
7. Added SIZE constants to all sysvar structs for API compatibility

#### 测试结果
- 单元测试: 285 tests passed
- 集成测试: passed
- 编译测试: all modules compile successfully with solana-zig

#### 下一步
- [ ] Begin v0.24.0 - Extended Native Programs
- [ ] Implement loader-v4 interface
- [ ] Add secp256r1 program support</content>
<parameter name="filePath">CHANGELOG.md
