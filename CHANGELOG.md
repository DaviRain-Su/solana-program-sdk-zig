# Changelog

All notable changes to the Solana SDK Zig implementation will be documented in this file.

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