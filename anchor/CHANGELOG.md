# Changelog

All notable changes to sol-anchor-zig will be documented in this file.

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
