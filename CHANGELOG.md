# Changelog

All notable changes to the Solana SDK Zig implementation will be documented in this file.

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