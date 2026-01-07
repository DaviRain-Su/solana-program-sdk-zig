# Changelog

All notable changes to the Solana SDK Zig implementation will be documented in this file.

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