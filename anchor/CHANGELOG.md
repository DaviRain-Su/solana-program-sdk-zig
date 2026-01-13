# Changelog

All notable changes to sol-anchor-zig will be documented in this file.

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
