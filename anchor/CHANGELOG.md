# Changelog

All notable changes to sol-anchor-zig will be documented in this file.

### Session 2026-01-15-015

**Date**: 2026-01-15
**Goal**: Improve token CPI error detail

#### Completed Work
1. Added `InvokeFailedWithCode` branch to `TokenCpiError`
2. Updated token CPI helpers and examples to surface error codes

#### Test Results
- `./solana-zig/zig build test --summary all`

### Session 2026-01-15-014

**Date**: 2026-01-15
**Goal**: Add Memo/Stake wrappers and CPI helpers

#### Completed Work
1. Added `anchor.memo` CPI helpers for SPL Memo program
2. Added `anchor.stake` CPI helpers for SPL Stake program
3. Added StakeAccount wrapper and DSL markers
4. Updated docs and examples

#### Test Results
- `./solana-zig/zig build test --summary all`

### Session 2026-01-15-012

**Date**: 2026-01-15
**Goal**: Add event emission, realloc safety, and PDA seed automation

#### Completed Work
1. Added event emission helpers with runtime logging support
2. Hardened realloc with payer requirement and 10KB growth limit
3. Added runtime seed resolution with PDA validation helpers
4. Updated docs, exports, and examples

#### Test Results
- Not run in this session (user-reported: anchor 195/195, sdk 363/363)

### Session 2026-01-15-013

**Date**: 2026-01-15
**Goal**: Add token helpers, system account wrappers, and sysvar parsing

#### Completed Work
1. Added SPL token wrappers and token CPI helpers
2. Added SystemAccount wrappers
3. Added SysvarData parsing helper
4. Updated docs and examples

#### Test Results
- Not run in this session

### Session 2026-01-13-011

**Date**: 2026-01-13
**Goal**: Add InterfaceProgram unchecked variants

#### Completed Work
1. Added InterfaceProgramAny and InterfaceProgramUnchecked wrappers
2. Exported helpers and updated docs
3. Added tests for executable/unchecked behavior

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-13-010

**Date**: 2026-01-13
**Goal**: Add meta merge strategy for interface CPI

#### Completed Work
1. Added meta merge strategy for Interface CPI builders
2. Applied merge to instruction metas and invoke infos
3. Updated docs and roadmap tracking

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-13-009

**Date**: 2026-01-13
**Goal**: Add rent_exempt checks for interface accounts

#### Completed Work
1. Added rent_exempt config for InterfaceAccount/InterfaceAccountInfo
2. Enforced rent exemption via Rent.getOrDefault
3. Updated docs and roadmap tracking

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-13-008

**Date**: 2026-01-13
**Goal**: Extend interface CPI invoke helpers

#### Completed Work
1. Added executable checks for InterfaceAccount/InterfaceAccountInfo
2. Added AccountMeta override wrapper for CPI metas
3. Added invoke/invokeSigned helpers and updated docs

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-13-007

**Date**: 2026-01-13
**Goal**: Add AccountMeta support to interface CPI

#### Completed Work
1. Allowed AccountMeta inputs for Interface CPI accounts
2. Allowed AccountMeta slices for remaining accounts
3. Updated docs and roadmap tracking

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-13-006

**Date**: 2026-01-13
**Goal**: Extend interface CPI helpers

#### Completed Work
1. Added `InterfaceAccountInfo` wrapper
2. Added remaining accounts support in Interface CPI builder
3. Updated docs and roadmap tracking

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-13-005

**Date**: 2026-01-13
**Goal**: Add interface accounts and CPI helpers

#### Completed Work
1. Added `InterfaceProgram`/`InterfaceAccount` wrappers
2. Added `Interface` CPI instruction builder
3. Updated docs and roadmap tracking

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-13-002

**Date**: 2026-01-13
**Goal**: Add typed program entry dispatch

#### Completed Work
1. Added `ProgramEntry` for discriminator-based dispatch
2. Added fallback handler support and optional error mapping
3. Added tests and documentation updates

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-13-003

**Date**: 2026-01-13
**Goal**: Add AccountLoader zero-copy access

#### Completed Work
1. Added `AccountLoader` for zero-copy account access
2. Exported loader from anchor root module
3. Updated docs and roadmap tracking

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-13-004

**Date**: 2026-01-13
**Goal**: Add LazyAccount on-demand deserialization

#### Completed Work
1. Added `LazyAccount` with cached Borsh decoding
2. Exported LazyAccount from anchor root module
3. Updated docs and roadmap tracking

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-13-001

**Date**: 2026-01-13
**Goal**: Expand constraint expression parsing

#### Completed Work
1. Expanded constraint expression parsing with boolean/comparison ops
2. Added tests and documentation updates

#### Test Results
- `ZIG_GLOBAL_CACHE_DIR=.zig-cache ZIG_LOCAL_CACHE_DIR=.zig-cache ../solana-zig/zig build test --summary all`

### Session 2026-01-12-001

**Date**: 2026-01-12
**Goal**: Extract anchor into monorepo subpackage

#### Completed Work
1. Initialized `anchor/` subpackage structure and build files
2. Migrated anchor sources to `anchor/src`
3. Updated imports to use `solana_program_sdk`
4. Removed noisy rent log via `Rent.getOrDefault()`
5. Re-exported SDK as `anchor.sdk`
6. Updated stories and roadmap for new layout

#### Test Results
- `zig build test` 152 passed
