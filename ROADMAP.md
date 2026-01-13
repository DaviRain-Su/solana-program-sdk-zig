# Solana SDK Zig Implementation Roadmap

This roadmap outlines the implementation of the [Solana SDK](https://github.com/anza-xyz/solana-sdk) in Zig.

## 📊 Implementation Summary

| Category | Implemented | Total | Coverage |
|----------|-------------|-------|----------|
| Core Types | 8 | 8 | 100% |
| Serialization | 3 | 3 | 100% |
| Program Foundation | 14 | 14 | 100% |
| Sysvars | 10 | 10 | 100% |
| Hash Functions | 4 | 4 | 100% |
| Native Programs | 12 | 12 | 100% |
| Native Token | 1 | 1 | 100% |
| Crypto (Advanced) | 3 | 3 | 100% |
| Error Types | 3 | 3 | 100% |
| Other (epoch_info, c_option) | 2 | 2 | 100% |
| SPL Programs | 3 | 3 | 100% |
| **Total (On-chain)** | **63** | **63** | **100%** |

> Note: Client/RPC and Validator-only modules are excluded.
> v2.2.0 complete: Added Stake program interface with full StakeStateV2 support.

---

## ✅ Implemented Modules

### Core Types (8/8 - 100%)

| Zig Module | Rust Crate | Status | Tests |
|------------|------------|--------|-------|
| `public_key.zig` | `pubkey` | ✅ | ✅ |
| `hash.zig` | `hash` | ✅ | ✅ |
| `signature.zig` | `signature` | ✅ | ✅ |
| `keypair.zig` | `keypair` | ✅ | ✅ |
| `account.zig` | `account-info` | ✅ | ✅ |
| `instruction.zig` | `instruction` | ✅ | ✅ |
| `message.zig` | `message` | ✅ | ✅ |
| `transaction.zig` | `transaction` | ✅ | ✅ |

### Serialization (3/3 - 100%)

| Zig Module | Rust Crate | Status | Tests |
|------------|------------|--------|-------|
| `bincode.zig` | `bincode` | ✅ | ✅ |
| `borsh.zig` | `borsh` | ✅ | ✅ |
| `short_vec.zig` | `short-vec` | ✅ | ✅ |

> Note: `serde`, `serde-varint`, `serialize-utils` are client-only and out of scope.

### Program Foundation (14/14 - 100%)

| Zig Module | Rust Crate | Status | Tests |
|------------|------------|--------|-------|
| `entrypoint.zig` | `program-entrypoint` | ✅ | ✅ |
| `error.zig` | `program-error` | ✅ | ✅ |
| `log.zig` | `program-log` | ✅ | ✅ |
| `syscalls.zig` | `define-syscall` | ✅ | ✅ |
| `context.zig` | (entrypoint parsing) | ✅ | ✅ |
| `allocator.zig` | (BPF allocator) | ✅ | ✅ |
| `bpf.zig` | (BPF utilities) | ✅ | ✅ |
| `signer.zig` | `signer` | ✅ | ✅ |
| `instruction.zig` | `cpi` | ✅ | ✅ |
| `program_memory.zig` | `program-memory` | ✅ | ✅ |
| `program_option.zig` | `program-option` | ✅ | ✅ |
| `program_pack.zig` | `program-pack` | ✅ | ✅ |
| `msg.zig` | `msg` | ✅ | ✅ |
| `stable_layout.zig` | `stable-layout` | ✅ | ✅ |

### Sysvars (10/10 - 100%)

| Zig Module | Rust Crate | Status | Tests |
|------------|------------|--------|-------|
| `clock.zig` | `clock` | ✅ | ✅ |
| `rent.zig` | `rent` | ✅ | ✅ |
| `slot_hashes.zig` | `slot-hashes` | ✅ | ✅ |
| `slot_history.zig` | `slot-history` | ✅ | ✅ |
| `epoch_schedule.zig` | `epoch-schedule` | ✅ | ✅ |
| `instructions_sysvar.zig` | `instructions-sysvar` | ✅ | ✅ |
| `last_restart_slot.zig` | `last-restart-slot` | ✅ | ✅ |
| `sysvar.zig` | `sysvar` | ✅ | ✅ |
| `sysvar_id.zig` | `sysvar-id` | ✅ | ✅ |
| `epoch_rewards.zig` | `epoch-rewards` | ✅ | ✅ |

### Hash Functions (4/4 - 100%)

| Zig Module | Rust Crate | Status | Tests |
|------------|------------|--------|-------|
| `blake3.zig` | `blake3-hasher` | ✅ | ✅ |
| `sha256_hasher.zig` | `sha256-hasher` | ✅ | ✅ |
| `keccak_hasher.zig` | `keccak-hasher` | ✅ | ✅ |
| `epoch_rewards_hasher.zig` | `epoch-rewards-hasher` | ✅ | ✅ |

### Native Programs (12/12 - 100%)

| Zig Module | Rust Crate | Status | Tests |
|------------|------------|--------|-------|
| `system_program.zig` | `system-interface` | ✅ | ✅ |
| `bpf_loader.zig` | `loader-v2-interface` | ✅ | ✅ |
| `bpf_loader.zig` | `loader-v3-interface` | ✅ | ✅ |
| `ed25519_program.zig` | `ed25519-program` | ✅ | ✅ |
| `secp256k1_program.zig` | `secp256k1-program` | ✅ | ✅ |
| `compute_budget.zig` | `compute-budget-interface` | ✅ | ✅ |
| `address_lookup_table.zig` | `address-lookup-table-interface` | ✅ | ✅ |
| `loader_v4.zig` | `loader-v4-interface` | ✅ | ✅ |
| `secp256r1_program.zig` | `secp256r1-program` | ✅ | ✅ |
| `nonce.zig` | `nonce` | ✅ | ✅ |
| `feature_gate.zig` | `feature-gate-interface` | ✅ | ✅ |
| `vote_interface.zig` | `vote-interface` | ✅ | ✅ |

### Native Token (1/1 - 100%)

| Zig Module | Rust Crate | Status | Tests |
|------------|------------|--------|-------|
| `native_token.zig` | `native-token` | ✅ | ✅ |

### Advanced Crypto (3/3 - 100%)

| Zig Module | Rust Crate | Status | Tests |
|------------|------------|--------|-------|
| `bn254.zig` | `bn254` | ✅ | ✅ |
| `big_mod_exp.zig` | `big-mod-exp` | ✅ | ✅ |
| `bls_signatures.zig` | `bls-signatures` | ✅ | ✅ |

---

## ✅ v1.2.0 - WebSocket PubSub Client (Complete)

Real-time subscription client for Solana events via WebSocket.

### Subscription Methods (9/9 implemented)

| Method | Description | Status |
|--------|-------------|--------|
| `accountSubscribe` | Subscribe to account changes | ✅ |
| `blockSubscribe` | Subscribe to new blocks | ✅ |
| `logsSubscribe` | Subscribe to transaction logs | ✅ |
| `programSubscribe` | Subscribe to program account changes | ✅ |
| `rootSubscribe` | Subscribe to root slot changes | ✅ |
| `signatureSubscribe` | Subscribe to signature confirmation | ✅ |
| `slotSubscribe` | Subscribe to slot updates | ✅ |
| `slotsUpdatesSubscribe` | Subscribe to detailed slot updates | ✅ |
| `voteSubscribe` | Subscribe to vote notifications | ✅ |

### Infrastructure

| Module | Description | Status |
|--------|-------------|--------|
| `client/src/pubsub/types.zig` | Notification types (SlotInfo, UiAccount, etc.) | ✅ |
| `client/src/pubsub/pubsub_client.zig` | WebSocket PubSub client | ✅ |
| `client/src/pubsub/root.zig` | Module exports | ✅ |

> **See**: `stories/v1.2.0-websocket-pubsub.md` for implementation details.

---

## ✅ v1.1.0 - Client SDK (Complete)

The following client-side modules are implemented in `client/`:

### RPC Methods (52/52 implemented)

| Priority | Count | Status | Examples |
|----------|-------|--------|----------|
| **P0** | 6/6 | ✅ Complete | `getBalance`, `getAccountInfo`, `getLatestBlockhash`, `sendTransaction` |
| **P1** | 18/18 | ✅ Complete | `getMultipleAccounts`, `simulateTransaction`, `requestAirdrop`, `getBlock` |
| **P2** | 28/28 | ✅ Complete | `getBlockCommitment`, `getClusterNodes`, `getVoteAccounts`, `getSupply` |

### Infrastructure
| Module | Description | Status |
|--------|-------------|--------|
| `client/src/json_rpc.zig` | JSON-RPC 2.0 client | ✅ Complete |
| `client/src/error.zig` | RPC error types | ✅ Complete |
| `client/src/commitment.zig` | Commitment levels | ✅ Complete |
| `client/src/types.zig` | Response types | ✅ Complete |
| `client/src/rpc_client.zig` | Main RPC client (52 methods + convenience) | ✅ Complete |

### Convenience Methods
| Method | Description | Status |
|--------|-------------|--------|
| `sendAndConfirmTransaction` | Send and wait for confirmation | ✅ Complete |
| `confirmTransaction` | Wait for transaction confirmation | ✅ Complete |
| `pollForSignatureStatus` | Poll signature status with timeout | ✅ Complete |
| `getNewBlockhash` | Get a fresh blockhash | ✅ Complete |
| `isHealthy` | Check node health (returns bool) | ✅ Complete |
| `getBalanceInSol` | Get balance in SOL (not lamports) | ✅ Complete |

### Transaction Building
| Module | Description | Status |
|--------|-------------|--------|
| `transaction/builder.zig` | Transaction builder | ✅ Complete |
| `transaction/signer.zig` | Transaction signing | ✅ Complete |

> **See**: `stories/v1.1.0-client-sdk.md` for detailed 52-method implementation plan.

---

## 🏗️ v1.0.0 - SDK Architecture Restructure ✅

The SDK has been restructured into a two-layer architecture for better separation of concerns:

### Current Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              sdk/ (共享核心类型 - 185 tests)                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  PublicKey, Hash, Signature, Keypair                │   │
│  │  Instruction, AccountMeta (types only)              │   │
│  │  bincode, borsh, short_vec, error, native_token     │   │
│  │  nonce, instruction_error, transaction_error        │   │
│  │  epoch_info, c_option (COption<T>)                  │   │
│  │  spl/token (Mint, Account, Multisig, TokenError)    │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                    ▲                       ▲
                    │ depends on            │ depends on
        ┌───────────┴───────────┐ ┌────────┴────────────┐
        │                       │ │                     │
┌───────▼───────────────┐  ┌────▼────────────────────┐
│ src/ (Program SDK)    │  │ client/ (Client SDK)    │
│ (294 tests)           │  │ (130 tests)             │
│ ┌───────────────────┐ │  │ ┌────────────────────┐  │
│ │ syscalls          │ │  │ │ RPC Client (52)    │  │
│ │ entrypoint        │ │  │ │ JSON-RPC 2.0       │  │
│ │ CPI (invokeSigned)│ │  │ │ SPL Token builders │  │
│ │ sysvars           │ │  │ │ Associated Token   │  │
│ │ native programs   │ │  │ │ WebSocket PubSub   │  │
│ │ crypto (syscall)  │ │  │ └────────────────────┘  │
│ └───────────────────┘ │  │                         │
└───────────────────────┘  └─────────────────────────┘
```

### Restructure Phases

| Phase | Goal | Status |
|-------|------|--------|
| Phase 1 | Extract shared types to `sdk/` directory | ✅ Complete |
| Phase 2 | Refactor program-sdk to depend on sdk/ | ✅ Complete |
| Phase 3 | Create client-sdk with RPC client | ✅ Complete (v1.1.0) |

> **See**: `stories/v1.0.0-sdk-restructure.md` for implementation details.

---

## ✅ v0.29.0 - Program SDK Completion (Complete)

Based on full analysis of [solana-sdk](https://github.com/anza-xyz/solana-sdk) (107 crates), all critical on-chain modules are now implemented.

### Implemented Modules

| Zig Module | Rust Crate | Priority | Status | Tests |
|------------|------------|----------|--------|-------|
| `bpf_loader.zig` (extend) | `loader-v3-interface` instructions | P1 | ✅ | 15 |
| `instruction_error.zig` | `instruction-error` | P1 | ✅ | 6 |
| `transaction_error.zig` | `transaction-error` | P2 | ✅ | 10 |
| `epoch_info.zig` | `epoch-info` | P2 | ✅ | 11 |

### loader-v3 Instructions (UpgradeableLoaderInstruction)

| Instruction | Description | Status |
|-------------|-------------|--------|
| `InitializeBuffer` | Initialize buffer account | ✅ |
| `Write` | Write program data to buffer | ✅ |
| `DeployWithMaxDataLen` | Deploy upgradeable program | ✅ |
| `Upgrade` | Upgrade program | ✅ |
| `SetAuthority` | Set upgrade authority | ✅ |
| `Close` | Close account | ✅ |
| `ExtendProgram` | Extend program data | ✅ |
| `SetAuthorityChecked` | Set authority (with signer) | ✅ |
| `Migrate` | Migrate to loader-v4 | ✅ |
| `ExtendProgramChecked` | Extend program (with signer) | ✅ |

> **See**: `stories/v0.29.0-program-sdk-completion.md` for details.

---

## ✅ v0.30.0 - Rust-Zig Integration Tests (Complete)

使用官方 Rust SDK 生成测试向量，验证 Zig SDK 实现的兼容性和正确性。

### 成果

✅ **180 个测试向量**，覆盖 33 个测试用例，全部通过。

### 测试覆盖

| Category | Vectors | Tests | Status |
|----------|---------|-------|--------|
| Core Types (PublicKey, Hash, Signature, Keypair) | 14 | 5 | ✅ |
| PDA Derivation | 4 | 1 | ✅ |
| Serialization (Bincode, Borsh, ShortVec) | 31 | 3 | ✅ |
| Sysvars (Clock, Rent, EpochSchedule, EpochInfo) | 26 | 4 | ✅ |
| Crypto (SHA256, Keccak256, Ed25519, Blake3) | 26 | 4 | ✅ |
| Instructions (System, ComputeBudget, LoaderV3, Stake, ALT) | 31 | 5 | ✅ |
| Message (MessageHeader, CompiledInstruction) | 7 | 2 | ✅ |
| Native Token (Lamports) | 15 | 1 | ✅ |
| Nonce (DurableNonce) | 4 | 1 | ✅ |
| Feature Gate (FeatureState) | 4 | 1 | ✅ |
| Errors (InstructionError, TransactionError) | 14 | 2 | ✅ |
| Account (AccountMeta) | 4 | 1 | ✅ |
| **Total** | **180** | **33** | ✅ |

### 架构

```
program-test/
├── src/lib.rs           # Rust test vector generator (26+ functions)
├── test-vectors/        # Generated JSON files (gitignored)
└── integration/
    └── test_pubkey.zig  # Zig integration tests (33 tests)
```

> **See**: `stories/v0.30.0-integration-tests.md` for details.

---

## 🚫 Out of Scope (Validator-only modules)

These modules are NOT needed for on-chain program development or client development:

### Validator-Only
- `genesis-config` - Genesis configuration
- `hard-forks` - Network hard forks
- `inflation` - Inflation parameters
- `poh-config` - PoH configuration
- `validator-exit` - Validator shutdown
- `quic-definitions` - QUIC networking
- `shred-version` - Shred versioning
- `epoch-stake` - Epoch stake information
- `cluster-type` - Network cluster type

---

## 📈 Version History

### v0.19.0 - Memory, Instructions Sysvar & Address Lookup Tables
- ✅ `program_memory.zig` - Memory operations (sol_memcpy, sol_memmove, sol_memset, sol_memcmp)
- ✅ `instructions_sysvar.zig` - Instruction introspection sysvar
- ✅ `address_lookup_table.zig` - Address Lookup Tables for versioned transactions

### v0.20.0 - Pack/Unpack & Nonce Support
- ✅ `program_pack.zig` - Pack/Unpack traits for accounts
- ✅ `nonce.zig` - Durable nonce support

### v0.21.0 - Remaining Program Foundation
- ✅ `program_option.zig` - Option types for programs
- ✅ `msg.zig` - Message utilities
- ✅ `stable-layout.zig` - Stable layout traits

### v0.22.0 - Sysvar Completion ✅
- ✅ `last_restart_slot.zig` - Restart slot sysvar
- ✅ `sysvar.zig` - Sysvar utilities
- ✅ `sysvar_id.zig` - Sysvar ID constants
- ✅ `epoch_rewards.zig` - Epoch rewards sysvar

### v0.18.0 - CPI, Compute Budget & Stack Optimization
- ✅ CPI enhancements (`setReturnData`, `getReturnData` in instruction.zig)
- ✅ `compute_budget.zig` - Compute budget program interface
- ✅ `native_token.zig` - Native SOL token utilities (Sol, solStrToLamports)
- ✅ Stack overflow fix - accounts array moved from stack to heap
- ✅ Zero-copy, zero-allocation entrypoint (like `solana-nostd-entrypoint`)

### v0.17.1 - Extended SDK Release
- ✅ Core types complete (pubkey, hash, signature, keypair)
- ✅ Serialization (Borsh, Bincode, ShortVec)
- ✅ Program foundation (entrypoint, error, log, syscalls)
- ✅ Basic sysvars (clock, rent, slot_hashes, slot_history, epoch_schedule)
- ✅ Hash functions (Blake3, SHA256, Keccak)
- ✅ Native programs (System, BPF Loader, Ed25519, Secp256k1)
- ✅ Transaction system (message, transaction, signer)
- ✅ Program test integration (cargo test passing)

### v0.23.0 - Advanced Crypto ✅
- ✅ `bn254.zig` - BN254 curve for ZK proofs
- ✅ `big-mod-exp.zig` - Modular exponentiation

### v0.24.0 - Extended Native Programs ✅
- ✅ `loader_v4.zig` - New loader interface for advanced program deployment
- ✅ `secp256r1_program.zig` - P-256/WebAuthn signature verification

### v0.25.0 - Epoch Rewards Hasher ✅
- ✅ `epoch_rewards_hasher.zig` - SipHash-1-3 based deterministic partition hasher
- Hash Functions now at 100% (4/4 modules)

### v0.26.0 - Feature Gate ✅
- ✅ `feature_gate.zig` - Feature Gate program interface for runtime feature activation
- Native Programs now at 92% (11/12 modules)

### v0.27.0 - Vote Interface ✅
- ✅ `vote_interface.zig` - Vote program interface for validator voting
- Core types: Lockout, LandedVote, Vote, VoteInit, VoteAuthorize
- VoteError enum with 21 error types
- Instruction builders: initializeAccount, authorize, withdraw, updateCommission, etc.
- Native Programs now at 100% (12/12 modules)

### v0.28.0 - BLS Signatures ✅
- ✅ `bls_signatures.zig` - BLS12-381 signature types for consensus
- Core types: Pubkey (96 bytes), PubkeyCompressed (48 bytes)
- Signature types: Signature (192 bytes), SignatureCompressed (96 bytes)
- ProofOfPossession types for rogue key attack prevention
- BlsError enum with 7 error types
- Base64 encoding for display formatting

### v2.0.0 - SPL Token & Associated Token Account ✅
- ✅ SPL Token types in SDK layer: Mint (82B), Account (165B), Multisig (355B)
- ✅ TokenInstruction enum with all 25 variants and Rust-style documentation
- ✅ TokenError enum with message()/toStr() methods
- ✅ COption<T> generic type with correct 4-byte tag layout
- ✅ Associated Token Account: PDA derivation, Create, CreateIdempotent, RecoverNested
- ✅ Client instruction builders: transfer, mintTo, burn, approve, etc.
- ✅ Tests: SDK 185, Program 294, Client 130 (total 609)

### v1.2.0 - WebSocket PubSub Client ✅
- ✅ WebSocket connection management with karlseguin/websocket.zig
- ✅ 9 subscription methods (account, block, logs, program, root, signature, slot, slotsUpdates, vote)
- ✅ JSON-RPC 2.0 over WebSocket protocol
- ✅ Notification types: SlotInfo, UiAccount, RpcLogsResponse, etc.
- ✅ 11 new PubSub tests (Client SDK total: 102 tests)

### v1.1.0 - Client SDK ✅
- ✅ 52 RPC methods with full response parsing
- ✅ 6 convenience methods (sendAndConfirmTransaction, confirmTransaction, etc.)
- ✅ Transaction builder and signer
- ✅ JSON-RPC 2.0 HTTP client
- ✅ 71 unit tests + 37 integration tests

### v1.0.0 - SDK Architecture Restructure ✅
- ✅ Two-layer architecture: `sdk/` (shared) + `src/` (program)
- ✅ SDK layer: 105 tests (no syscall dependencies)
- ✅ Program SDK layer: 285 tests (with syscall support)
- ✅ Clean separation of pure types and BPF-specific code

### v0.30.0 - Rust-Zig Integration Tests ✅
- ✅ Rust test vector generator with 26+ functions
- ✅ 180 test vectors across 33 test cases
- ✅ Core types: PublicKey, Hash, Signature, Keypair
- ✅ Serialization: Bincode, Borsh, ShortVec
- ✅ Sysvars: Clock, Rent, EpochSchedule, EpochInfo
- ✅ Crypto: SHA256, Keccak256, Ed25519, Blake3
- ✅ Instructions: System, ComputeBudget, LoaderV3, Stake, AddressLookupTable
- ✅ Message: MessageHeader, CompiledInstruction
- ✅ Errors: InstructionError, TransactionError
- ✅ Account: AccountMeta
- ✅ Full compatibility with Rust SDK verified

### v0.29.0 - Program SDK Completion ✅
- ✅ `loader-v3` instruction builders (UpgradeableLoaderInstruction)
- ✅ `instruction_error.zig` - Runtime instruction errors
- ✅ `transaction_error.zig` - Transaction errors (for Client SDK)
- ✅ `epoch_info.zig` - EpochInfo type (for Client SDK)

---

## 🎯 Development Guidelines

1. **Reference Implementation**: Always reference the Rust source in file headers
2. **Test Coverage**: Match or exceed Rust SDK test coverage
3. **API Compatibility**: Maintain similar API surface where possible
4. **Zig Idioms**: Use Zig best practices (comptime, error unions, slices)
5. **Zero-Copy**: Prefer pointer operations over memory copies
6. **Stack Safety**: Use heap allocation for large arrays (>1KB)

---

## 🔮 Future Roadmap

The following features are planned for future development. Based on analysis of the [solana-program](https://github.com/solana-program) organization (35 repositories), priorities are assigned as:
- **P0**: Essential for most smart contract developers
- **P1**: Important for DeFi/NFT developers
- **P2**: Nice-to-have utilities

---

### ✅ v2.0.0 - SPL Token & Associated Token Account (Complete)

Implementation of the most critical SPL programs for token operations.

#### SPL Token Program (`TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA`)

**Source**: https://github.com/solana-program/token

| Module | Description | Status |
|--------|-------------|--------|
| `sdk/src/spl/token/state.zig` | Mint (82 bytes), Account (165 bytes), Multisig (355 bytes) | ✅ |
| `sdk/src/spl/token/instruction.zig` | 25 instructions with full Rust-style documentation | ✅ |
| `sdk/src/spl/token/error.zig` | TokenError enum with message()/toStr() methods | ✅ |
| `sdk/src/c_option.zig` | COption<T> with correct 4-byte tag layout | ✅ |
| `client/src/spl/token/instruction.zig` | Instruction builders (transfer, mintTo, etc.) | ✅ |

**All 25 Instructions Implemented**:

| ID | Instruction | Status | Description |
|----|-------------|--------|-------------|
| 0 | `InitializeMint` | ✅ | Initialize token mint |
| 1 | `InitializeAccount` | ✅ | Initialize token account |
| 2 | `InitializeMultisig` | ✅ | Initialize multisig |
| 3 | `Transfer` | ✅ | Transfer tokens |
| 4 | `Approve` | ✅ | Approve delegate |
| 5 | `Revoke` | ✅ | Revoke delegate |
| 6 | `SetAuthority` | ✅ | Change mint/account authority |
| 7 | `MintTo` | ✅ | Mint new tokens |
| 8 | `Burn` | ✅ | Burn tokens |
| 9 | `CloseAccount` | ✅ | Close token account |
| 10 | `FreezeAccount` | ✅ | Freeze account |
| 11 | `ThawAccount` | ✅ | Thaw frozen account |
| 12-15 | `*Checked` variants | ✅ | Safety-enhanced versions |
| 16-20 | Modern variants | ✅ | No rent sysvar required |
| 21-24 | Utility instructions | ✅ | GetAccountDataSize, etc. |

#### Associated Token Account (`ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL`)

**Source**: https://github.com/solana-program/associated-token-account

| Module | Description | Status |
|--------|-------------|--------|
| `client/src/spl/associated_token.zig` | ATA address derivation and instruction builders | ✅ |

**PDA Derivation Seeds** (order critical):
```zig
seeds = [wallet_address, token_program_id, mint_address]
```

**Instructions**:
| ID | Instruction | Status | Description |
|----|-------------|--------|-------------|
| 0 | `Create` | ✅ | Create ATA (fails if exists) |
| 1 | `CreateIdempotent` | ✅ | Create ATA (succeeds if exists) - **Recommended** |
| 2 | `RecoverNested` | ✅ | Recover tokens from nested ATA |

> **See**: `stories/v2.0.0-spl-token.md` for implementation details.

---

### ⏳ v2.1.0 - Token-2022 Extensions

Implement Token-2022 with TLV extension architecture.

**Program ID**: `TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb`

**Source**: https://github.com/solana-program/token-2022

#### TLV Extension System

```
[Base State] [Padding] [AccountType: 1 byte] [TLV Data]
                                               ↓
                        [Type: u16][Length: u16][Value: N bytes]
```

#### Supported Extensions (20+)

| Extension | Type ID | Level | Description |
|-----------|---------|-------|-------------|
| `TransferFeeConfig` | 1 | Mint | Transfer fee configuration |
| `TransferFeeAmount` | 2 | Account | Withheld transfer fees |
| `MintCloseAuthority` | 3 | Mint | Authority to close mint |
| `ConfidentialTransferMint` | 4 | Mint | Confidential transfer config |
| `ConfidentialTransferAccount` | 5 | Account | Confidential transfer state |
| `DefaultAccountState` | 6 | Mint | New accounts frozen by default |
| `ImmutableOwner` | 7 | Account | Prevent owner reassignment |
| `MemoTransfer` | 8 | Account | Require memo on transfers |
| `NonTransferable` | 9 | Mint | Soulbound tokens |
| `InterestBearingConfig` | 10 | Mint | Interest accumulation |
| `CpiGuard` | 11 | Account | Block CPI privilege escalation |
| `PermanentDelegate` | 12 | Mint | Permanent delegate authority |
| `TransferHook` | 14 | Mint | Custom transfer logic |
| `MetadataPointer` | 18 | Mint | Pointer to metadata account |
| `GroupPointer` | 21 | Mint | Token group pointer |
| `GroupMemberPointer` | 22 | Mint | Group member pointer |

#### Implementation Phases

**Phase 1 - Core**:
- [ ] `ExtensionType` enum (u16)
- [ ] TLV parser/serializer
- [ ] `GetAccountDataSize` instruction
- [ ] Basic extensions: `ImmutableOwner`, `MintCloseAuthority`

**Phase 2 - Common Extensions**:
- [ ] `TransferFeeConfig` + `TransferFeeAmount`
- [ ] `MetadataPointer`
- [ ] `PermanentDelegate`
- [ ] `NonTransferable`

**Phase 3 - Advanced**:
- [ ] `ConfidentialTransfer` (requires ZK proofs)
- [ ] `InterestBearingConfig`
- [ ] `TransferHook`

---

### ✅ v2.2.0 - Stake Program Interface

Implement Solana's core staking program interface.

**Program ID**: `Stake11111111111111111111111111111111111111`

**Source**: https://github.com/solana-program/stake

| Module | Description | Status |
|--------|-------------|--------|
| `spl/stake/state.zig` | StakeStateV2, Meta, Stake, Delegation, StakeFlags | ✅ |
| `spl/stake/instruction.zig` | 18 StakeInstruction variants | ✅ |
| `spl/stake/error.zig` | 17 StakeError variants | ✅ |
| `spl/stake/root.zig` | Module exports | ✅ |

**Features**:
- ✅ Complete StakeStateV2 state machine (Uninitialized, Initialized, Stake, RewardsPool)
- ✅ All 18 instruction variants with builders
- ✅ 17 error types with message() and toStr() methods
- ✅ StakeFlags bitfield with deprecated MUST_FULLY_ACTIVATE flag
- ✅ Pack/unpack serialization (Borsh compatible)
- ✅ 53 unit tests covering state, instructions, and errors

**Usage**:
```zig
const stake = sdk.spl.stake;

// Parse stake account state
const state = try stake.StakeStateV2.unpack(account_data);
if (state.stake()) |s| {
    const voter = s.delegation.voter_pubkey;
    const amount = s.delegation.stake;
}

// Create instructions
const ix = stake.instruction.initialize(
    stake_pubkey,
    stake.Authorized.auto(authority),
    stake.Lockup.DEFAULT,
);
```

---

### ✅ v2.3.0 - Memo Program

Simple utility program for on-chain memos.

**Program ID**: `MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr`

**Source**: https://github.com/solana-program/memo

| Module | Description | Status |
|--------|-------------|--------|
| `spl/memo.zig` | Memo instruction builder | ✅ |

**Features**:
- ✅ UTF-8 validation (`isValidUtf8`, `findInvalidUtf8Position`)
- ✅ Optional signer verification (`createSignerAccounts`)
- ✅ MemoInstruction builder with `init` and `initValidated`
- ✅ Both v1 and v2/v3 program IDs (`MEMO_PROGRAM_ID`, `MEMO_V1_PROGRAM_ID`)
- ✅ 11 unit tests covering UTF-8 validation, emoji handling, and signer accounts

**Implementation**:
```zig
const memo = sdk.spl.memo;

// Create memo instruction (no UTF-8 validation)
const memo_ix = memo.MemoInstruction.init("Hello, Solana!");

// Create memo instruction with UTF-8 validation
const memo_ix = try memo.MemoInstruction.initValidated("🐆");

// Get instruction data (raw UTF-8 bytes)
const data = memo_ix.getData();

// Create signer account metas
var buffer: [10]AccountMeta = undefined;
const accounts = memo.MemoInstruction.createSignerAccounts(&signers, &buffer);
```

---

### ⏳ v2.4.0 - Metaplex NFT Programs

Essential programs for NFT development on Solana.

#### Token Metadata Program (`metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s`)

**Source**: https://github.com/metaplex-foundation/mpl-token-metadata

| Module | Description | Status |
|--------|-------------|--------|
| `metaplex/token_metadata.zig` | Metadata account creation and management | ⏳ |

**Key Instructions**:
- `CreateMetadataAccountV3` - Create metadata for token
- `CreateMasterEditionV3` - Create master edition (NFT proof)
- `UpdateMetadataAccountV2` - Update metadata
- `Verify/UnverifyCollection` - Collection verification
- `Burn` - Burn NFTs

**Data Structures**:
- `Metadata` - Name, symbol, URI, creators, collection
- `MasterEdition` - Supply, max_supply
- `Edition` - Edition number, parent

#### Metaplex Core (`CoREENxT6tW1HoK8ypY1SxRMZTcVPm7R94rH4PZNhX7d`)

**Source**: https://github.com/metaplex-foundation/mpl-core

Next-generation lightweight NFT standard:
- Single-account design (82% cheaper than Token Metadata)
- Plugin system (Freeze, Royalty, Transfer Delegate, etc.)
- Better CPI composability

#### Bubblegum - Compressed NFTs (`BGUMAp9Gq7iTEuizy4pqaxsTyUCBK68MDfK752saRPUY`)

**Source**: https://github.com/metaplex-foundation/mpl-bubblegum

Compressed NFTs using Merkle trees:
- Mint millions of NFTs at fraction of cost
- Requires SPL Account Compression dependency

**Dependencies**:
- SPL Account Compression: `cmtDvXumGCrqC1Age74AVPhSRVXJMd8PJS91L8KbNCK`
- SPL Noop: `noopb9bkMVfRPU8AsbpTUg8AQkHtKwMYZiFUjNRtMmV`

---

### ⏳ v2.5.0 - Oracle & Utility Programs

#### Pyth Oracle (`pythWSnswVUd12oZpeFP8e9CVaEqJg25g1Vtc2biRsTC`)

**Source**: https://github.com/pyth-network/pyth-sdk-solana

Real-time price feeds for 500+ assets:
- Price account parsing
- Confidence intervals
- EMA price support

#### Switchboard Oracle (`SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f`)

**Source**: https://github.com/switchboard-xyz/solana-sdk

Permissionless oracle network:
- Custom data feeds
- VRF (Verifiable Random Function)

#### Config Program (`Config1111111111111111111111111111111111111`)

**Source**: https://github.com/solana-program/config

On-chain configuration storage:
- Validator config
- Protocol parameters

#### Name Service (`namesLPneVptA9Z5rqUDD9tMTWEJwofgaYwp8cawRkX`)

.sol domain registration and resolution.

---

### ⏳ v2.6.0 - Additional SPL Programs

#### Stake Pool (`SPoo1Ku8WFXoNDMHPsrGSTSG1Y47rzgn41SLUNakuHy`)

**Source**: https://github.com/solana-program/stake-pool

Liquid staking pool implementation for:
- Stake delegation to multiple validators
- Pool token minting/burning
- Fee collection

#### Candy Machine v3 (`CndyV3LdqHUfDLmE5naZjVN8rBZz4tqhdefbAnjHG3JR`)

**Source**: https://github.com/metaplex-foundation/mpl-candy-machine

NFT collection distribution:
- Configurable guards (allowlist, payment, limits)
- Fair launch mechanics

---

### ⏳ v2.7.0 - Example Programs

Comprehensive example programs demonstrating SDK usage.

```
examples/
├── hello_world/           # Simplest possible program
│   ├── src/main.zig       # Just logs a message
│   └── README.md
├── counter/               # State management example
│   ├── src/main.zig       # Increment/decrement counter
│   ├── src/state.zig      # Account state serialization
│   └── README.md
├── escrow/                # CPI example
│   ├── src/main.zig       # Token escrow with CPI
│   └── README.md
├── token_transfer/        # SPL Token interaction
│   ├── src/main.zig       # Transfer SPL tokens via CPI
│   └── README.md
└── pda_vault/             # PDA and signer seeds
    ├── src/main.zig       # Vault using PDAs
    └── README.md
```

**Goals:**
- [ ] Step-by-step tutorials in README
- [ ] Deployment scripts for each example
- [ ] Client-side interaction scripts
- [ ] Test coverage for each program

---

### ⏳ v3.0.0 - Zig Anchor Framework (sol-anchor-zig)

A native Zig framework inspired by Anchor, using comptime metaprogramming instead of Rust proc macros.

> 从 v3.0.1 起，代码已迁移到仓库内 `anchor/` 子包。

#### Design Philosophy

| Anchor (Rust) | sol-anchor-zig (Zig) |
|---------------|---------------------|
| `#[program]` proc macro | `comptime` dispatch generation |
| `#[derive(Accounts)]` | `comptime` struct introspection |
| `#[account(mut, signer)]` | Struct field constraints |
| Runtime IDL generation | Comptime IDL embedding |

#### Core Architecture

```zig
//! Example: Counter Program in sol-anchor-zig

const anchor = @import("sol_anchor_zig");
const sdk = anchor.sdk;

// ============================================
// 1. Account Definitions (like #[account])
// ============================================
pub const Counter = anchor.Account(struct {
    count: u64,
    authority: sdk.PublicKey,
    bump: u8,
}, .{
    .discriminator = anchor.accountDiscriminator("Counter"),
    .space = 8 + 8 + 32 + 1, // discriminator + count + authority + bump
});

// ============================================
// 2. Instruction Contexts (like #[derive(Accounts)])
// ============================================
pub const InitializeAccounts = anchor.Accounts(.{
    .counter = anchor.Account(Counter, .{
        .init = true,
        .payer = "payer",
        .seeds = &.{ "counter", .{ .field = "authority" } },
        .bump = true,
    }),
    .authority = anchor.Signer(.{}),
    .payer = anchor.Signer(.{ .mut = true }),
    .system_program = anchor.Program(sdk.system_program),
});

pub const IncrementAccounts = anchor.Accounts(.{
    .counter = anchor.Account(Counter, .{
        .mut = true,
        .has_one = "authority",
    }),
    .authority = anchor.Signer(.{}),
});

// ============================================
// 3. Instruction Handlers
// ============================================
pub fn initialize(ctx: anchor.Context(InitializeAccounts)) !void {
    ctx.accounts.counter.data.count = 0;
    ctx.accounts.counter.data.authority = ctx.accounts.authority.key.*;
    ctx.accounts.counter.data.bump = ctx.bumps.counter;
}

pub fn increment(ctx: anchor.Context(IncrementAccounts)) !void {
    ctx.accounts.counter.data.count += 1;
}

// ============================================
// 4. Program Definition (like #[program])
// ============================================
pub const program = anchor.Program(.{
    .id = sdk.PublicKey.comptimeFromBase58("Counter111111111111111111111111111111111111"),
    .instructions = .{
        .initialize = initialize,
        .increment = increment,
    },
});

// Entry point
comptime {
    anchor.declareEntrypoint(program);
}
```

#### Constraint System

| Constraint | Anchor Rust | sol-anchor-zig | Description |
|------------|-------------|----------------|-------------|
| `mut` | `#[account(mut)]` | `.mut = true` | Account is writable |
| `signer` | `#[account(signer)]` | `anchor.Signer(.{})` | Account must sign |
| `init` | `#[account(init, payer, space)]` | `.init = true, .payer = "x", .space = n` | Create account |
| `seeds` | `#[account(seeds = [b"x"])]` | `.seeds = &.{"x"}` | PDA seeds |
| `bump` | `#[account(bump)]` | `.bump = true` | Store/validate bump |
| `has_one` | `#[account(has_one = field)]` | `.has_one = "field"` | Field must match |
| `address` | `#[account(address = X)]` | `.address = X` | Exact pubkey |
| `owner` | `#[account(owner = X)]` | `.owner = X` | Account owner |
| `constraint` | `#[account(constraint = expr)]` | `.constraint = fn` | Custom validation |
| `close` | `#[account(close = dest)]` | `.close = "dest"` | Close account |
| `realloc` | `#[account(realloc = n)]` | `.realloc = n` | Resize account |

#### Discriminator Generation

```zig
/// Comptime discriminator generation (8-byte SHA256 prefix)
pub fn accountDiscriminator(comptime name: []const u8) [8]u8 {
    return sighash("account", name);
}

pub fn instructionDiscriminator(comptime name: []const u8) [8]u8 {
    return sighash("global", name);
}

fn sighash(comptime namespace: []const u8, comptime name: []const u8) [8]u8 {
    const preimage = namespace ++ ":" ++ name;
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(preimage, &hash, .{});
    return hash[0..8].*;
}
```

#### Comptime Validation Generation

```zig
/// Generate validation code at compile time
pub fn Accounts(comptime spec: anytype) type {
    return struct {
        // Fields generated from spec
        ...
        
        pub fn validate(self: @This(), program_id: *const PublicKey) !void {
            const info = @typeInfo(@TypeOf(spec));
            inline for (info.Struct.fields) |field| {
                const constraints = @field(spec, field.name);
                const account = @field(self, field.name);
                
                // Comptime-generated validation checks
                if (constraints.mut and !account.info.is_writable) {
                    return error.ConstraintMut;
                }
                if (constraints.signer and !account.info.is_signer) {
                    return error.ConstraintSigner;
                }
                if (constraints.has_one) |field_name| {
                    // Validate has_one constraint
                }
                // ... more constraints
            }
        }
    };
}
```

#### Error Codes (Anchor Compatible)

```zig
pub const AnchorError = enum(u32) {
    // Framework errors (0-99)
    InstructionMissing = 100,
    InstructionFallbackNotFound = 101,
    InstructionDidNotDeserialize = 102,
    
    // Constraint errors (2000-2999)
    ConstraintMut = 2000,
    ConstraintHasOne = 2001,
    ConstraintSigner = 2002,
    ConstraintRaw = 2003,
    ConstraintOwner = 2004,
    ConstraintAddress = 2005,
    ConstraintSeeds = 2006,
    // ... 
    
    // Account errors (3000-3999)
    AccountDiscriminatorMismatch = 3000,
    AccountDiscriminatorNotFound = 3001,
    AccountNotInitialized = 3002,
    // ...
};

// Custom errors start at 6000 (like Anchor)
pub fn CustomError(comptime start: u32) type {
    return struct {
        pub fn code(e: anytype) u32 {
            return start + @intFromEnum(e);
        }
    };
}
```

#### IDL Generation (Comptime)

```zig
/// Generate IDL at compile time
pub fn generateIdl(comptime program: anytype) []const u8 {
    comptime {
        var idl = IdlBuilder.init();
        
        idl.setAddress(program.id);
        idl.setName(@typeName(program));
        
        // Generate instruction metadata
        inline for (@typeInfo(program.instructions).Struct.fields) |field| {
            idl.addInstruction(.{
                .name = field.name,
                .discriminator = instructionDiscriminator(field.name),
                .accounts = extractAccounts(field.type),
                .args = extractArgs(field.type),
            });
        }
        
        return idl.toJson();
    }
}
```

#### Implementation Phases

**Phase 1 - Core Framework**:
- [ ] `anchor.Account` - Account wrapper with discriminator
- [ ] `anchor.Signer` - Signer account type
- [ ] `anchor.Program` - Program account type
- [ ] `anchor.Context` - Instruction context
- [ ] Discriminator generation (SHA256)
- [ ] Basic constraints: `mut`, `signer`, `owner`

**Phase 2 - PDA Support**:
- [ ] `seeds` constraint with comptime seed parsing
- [ ] `bump` storage and validation
- [ ] `init` with PDA creation via CPI
- [ ] Bump seed derivation

**Phase 3 - Advanced Constraints**:
- [ ] `has_one` field validation
- [ ] `constraint` custom expressions
- [ ] `close` account closing
- [ ] `realloc` account resizing
- [ ] `address` exact pubkey check

**Phase 4 - Serialization**:
- [ ] Borsh serialization with discriminator
- [ ] Auto-derive serialize/deserialize
- [ ] Zero-copy account access
- [ ] Instruction argument parsing

**Phase 5 - Developer Experience**:
- [ ] IDL generation at comptime
- [ ] Client code generation
- [ ] Error messages with source location
- [ ] Testing utilities

#### Advantages Over Anchor

| Aspect | Anchor (Rust) | sol-anchor-zig |
|--------|---------------|----------------|
| **Compile Time** | Slow (proc macros) | Fast (native comptime) |
| **Error Messages** | Opaque macro errors | Clear Zig errors |
| **Debugging** | Hard to debug macros | Standard Zig debugging |
| **Binary Size** | ~200KB+ | Target <50KB |
| **Compute Units** | Higher overhead | Minimal overhead |
| **Learning Curve** | Rust + macro DSL | Just Zig |

---

### ⏳ v3.0.1 - Anchor Extraction (Monorepo)

将 `sol-anchor-zig` 从主 SDK 中拆分为仓库内独立子包 `anchor/`，并建立独立构建与测试流程。

- [x] 新增 `anchor/` 子包（独立 `build.zig`/`build.zig.zon`）
- [x] `anchor/` 通过路径依赖 `solana_program_sdk`
- [x] 迁移 `src/anchor/*` 至 `anchor/src/*`
- [x] 主 SDK 移除 `anchor` 导出与旧路径
- [ ] 新增 `anchor` 独立 CI 与测试

---

### ✅ v3.0.2 - Documentation P0

- [x] Add deployment guide (`docs/DEPLOYMENT.md`)
- [x] Add testing guide (`docs/TESTING.md`)
- [x] Link docs from README

---

### ✅ v3.0.3 - Documentation P1/P2

- [x] Add compute budget guide (`docs/COMPUTE_BUDGET.md`)
- [x] Add token programs guide (`docs/TOKEN_PROGRAMS.md`)
- [x] Add anchor compatibility guide (`docs/ANCHOR_COMPATIBILITY.md`)
- [x] Add error handling guide (`docs/ERROR_HANDLING.md`)
- [x] Add Token-2022 status to README

---

### ✅ v3.0.4 - Anchor IDL + Zig Client

- [x] Add comptime IDL JSON generation
- [x] Add Zig client codegen
- [x] Document IDL/codegen usage

---

### ✅ v3.0.5 - Anchor Comptime Derives

- [x] Add Accounts/Event DSL helpers
- [x] Document derives usage

---

### ✅ v3.0.6 - Anchor IDL Extensions

- [x] Add events/constants/metadata to IDL JSON
- [x] Add constraint hints (seeds/bump/close/realloc/hasOne)
- [x] Add IDL tests for new sections

---

### ✅ v3.0.7 - Anchor Zig Client (High-level)

- [x] Add ProgramClient RPC wrapper to codegen
- [x] Add account decode helpers to codegen
- [x] Integrate anchor client helpers under client/

---

### ✅ v3.0.8 - Anchor IDL Output

- [x] Add IDL JSON file output helper
- [x] Add build step to generate IDL JSON
- [x] Document IDL build usage

---

### ✅ v3.0.9 - Anchor Constraint DSL

- [x] Add `anchor.constraint()` helper
- [x] Emit constraint expression in IDL
- [x] Document constraint usage

---

### ✅ v3.1.0 - Anchor Event Index

- [x] Add eventField wrapper for indexed fields
- [x] Emit indexed fields in IDL
- [x] Document event index usage

---

### ✅ v3.1.1 - Anchor Event Index Rules

- [x] Enforce max indexed field count
- [x] Add multi-index event tests

---

### ✅ v3.1.2 - Anchor Account Attrs

- [x] Add `anchor.attr.*` helpers
- [x] Support `.attrs` in AccountConfig
- [x] Document account attribute usage

---

### ✅ v3.1.3 - Anchor IDL Root Build

- [x] Add root `zig build idl` integration
- [x] Document root IDL build usage

---

### ✅ v3.1.4 - Root IDL Default Output

- [x] Default root `zig build idl` output to `idl/`
- [x] Add `idl-output-dir` and `idl-output` overrides
- [x] Document default output and flags

---

### ✅ v3.1.5 - Anchor Event Index Semantics

- [x] Enforce scalar/PublicKey-only indexed event fields
- [x] Update docs and tests

---

### ✅ v3.1.6 - Anchor Account Attr Sugar

- [x] Add macro-style account attribute config
- [x] Support has_one shorthand mapping
- [x] Update docs and tests

---

### ✅ v3.1.7 - Anchor Account Attr Parsing

- [x] Add bump field and seeds::program mapping
- [x] Emit seeds::program in IDL pda
- [x] Update docs and tests

---

### ✅ v3.1.8 - Anchor Account Attr Parser

- [x] Add `#[account(...)]` string parser
- [x] Update docs and tests

---

### ✅ v3.1.9 - Anchor Attr Type Checks

- [x] Add compile-time validation for account/Accounts field references
- [x] Update docs and tests

---

### ✅ v3.2.0 - Anchor Typed Field Refs

- [x] Add typed field helper utilities
- [x] Update docs and tests

---

### ✅ v3.2.1 - Anchor Accounts Field Attrs

- [x] Add `AccountField` for field-level attrs
- [x] Update docs and tests

---

### ✅ v3.2.2 - Anchor Account Semantics

- [x] Add init_if_needed and token/associated token constraints
- [x] Update docs and tests

---

### ✅ v3.2.3 - Anchor Constraint Runtime

- [x] Execute constraint expressions at runtime
- [x] Update docs and tests

---

### ✅ v3.2.4 - Anchor Accounts Derive

- [x] Add AccountsWith helper
- [x] Update docs and tests

---

### ✅ v3.2.5 - Anchor Macro Parsing

- [x] Expand parseAccount macro syntax coverage (rent_exempt=skip/enforce, realloc::payer/zero, token::token_program, mint::*, zero/dup, constraint @ error, b"seed")
- [x] Allow AccountsWith string attrs
- [x] Update docs and tests

---

### ✅ v3.2.6 - Anchor Macro Expr Support

- [x] Support owner/address/space expressions in macro-style attrs
- [x] Runtime validation for owner/address expressions
- [x] Update docs and tests

---

### ✅ v3.2.7 - Anchor Typed-Only Attrs

- [x] Remove string attr parsing (`parseAccount`)
- [x] Remove AccountsWith string attr path
- [x] Update docs and tests

---

### ✅ v3.2.8 - Anchor Accounts Derive Signer Attrs

- [x] Apply typed attrs to Signer fields in AccountsWith/AccountsDerive
- [x] Update docs and tests

---

### ✅ v3.2.9 - Anchor Accounts Derive Program Attrs

- [x] Apply typed attrs to Program/UncheckedProgram fields
- [x] Update docs and tests

---

### ✅ v3.2.10 - Anchor Derive Program Auto Bind

- [x] Auto-bind system_program/token_program fields
- [x] Update docs and tests

---

### ✅ v3.2.11 - Anchor Derive Auto Bind Common Accounts

- [x] Auto-bind associated_token_program field
- [x] Auto-wrap rent sysvar account
- [x] Update docs and tests

---

### ✅ v3.2.12 - Anchor Derive Auto Bind Sysvars

- [x] Auto-wrap clock/rent/slot_hashes/slot_history
- [x] Auto-wrap stake_history/instructions/epoch_rewards/last_restart_slot
- [x] Update docs and tests

---

### ✅ v3.2.13 - Anchor Derive Constraint Inference

- [x] Auto-apply mut on init/realloc/close account fields
- [x] Auto-apply signer+mut on payer/realloc payer fields
- [x] Update docs and tests

---

### ✅ v3.2.14 - Anchor Derive HasOne/Seeds Ref Validation

- [x] Validate has_one target field types
- [x] Validate seedAccount/seedBump references
- [x] Update docs and tests

---

### ✅ v3.2.15 - Anchor Derive Typed Attrs Marker

- [x] Add Attrs/AttrsWith helpers for typed field annotations
- [x] Export Attrs/AttrsWith
- [x] Update docs and tests

---

### ✅ v3.2.16 - Anchor Derive Typed Attrs For

- [x] Add AttrsFor to resolve field enums into AccountAttrConfig
- [x] Export AttrsFor
- [x] Update docs and tests

---

### ✅ v3.2.17 - Anchor Derive Typed Seeds

- [x] Add typed seed specs for Accounts/Data enums
- [x] Allow AttrsFor to accept typed seeds for seeds/seeds_program
- [x] Update docs and tests

---

### ✅ v3.2.18 - Anchor Derive Typed HasOne

- [x] Add typed has_one specs for Accounts/Data enums
- [x] Allow AttrsFor to accept typed has_one specs for has_one
- [x] Update docs and tests

---

### ✅ v3.2.19 - Anchor Attrs Conflict Detection

- [x] Add conflict detection for Attrs/AttrsFor vs Account config
- [x] Update docs and tests

---

### ✅ v3.2.20 - Anchor Typed Token Helpers

- [x] Add typed token/associated-token/mint helpers for AttrsFor
- [x] Export typed token helpers
- [x] Update docs and tests

---

### ✅ v3.2.21 - Anchor Typed Init/Close/Realloc Helpers

- [x] Add typed init/close/realloc helpers for AttrsFor
- [x] Export InitFor/CloseFor/ReallocFor
- [x] Update docs and tests

---

### ✅ v3.2.22 - Anchor Typed Access Helper

- [x] Add typed access helper for AttrsFor
- [x] Export AccessFor
- [x] Update docs and tests

---

### ✅ v3.2.23 - AccountsDerive Auto Token Program

- [x] Auto-fill token_program for token/mint/associated token constraints
- [x] Add AccountsDerive tests for auto token program inference
- [x] Update docs and tests

---

### ✅ v3.2.24 - AccountsDerive Common Program Auto Bindings

- [x] Auto-bind memo_program/stake_program/stake_config_program
- [x] Add AccountsDerive tests for common program auto bindings
- [x] Update docs and tests

---

### ✅ v3.2.25 - AccountsDerive Token Program Aliases

- [x] Recognize token program alias field names
- [x] Add AccountsDerive tests for token program aliases
- [x] Update docs and tests

---

### ✅ v3.2.26 - AccountsDerive Associated Token Program Aliases

- [x] Recognize associated token program alias field names
- [x] Add AccountsDerive tests for associated token program aliases
- [x] Update docs and tests

---

### ✅ v3.2.27 - AccountsDerive Token Shape Inference

- [x] Infer token mint/authority from token account data shape
- [x] Add AccountsDerive tests for token shape inference
- [x] Update docs and tests

---

### ✅ v3.2.28 - AccountsDerive Token/Mint/ATA Shape Inference

- [x] Infer associated token constraints from account data shape
- [x] Infer mint authority/freeze/decimals from account data shape
- [x] Add AccountsDerive tests for token/mint/ata shape inference
- [x] Update docs and tests

---

### ✅ v3.2.29 - AccountsDerive Field Alias Inference

- [x] Infer token/ata constraints from token_* account field names
- [x] Infer mint authority/decimals from alias field names
- [x] Add AccountsDerive tests for alias-based inference
- [x] Update docs and tests

---

### ✅ v3.2.30 - Token/Mint/ATA Constraint Combos

- [x] Enforce token/ata/mint constraint combination rules
- [x] Add tests for valid token/ata/mint combinations
- [x] Update docs

---

### ✅ v3.2.31 - Init/Close/Realloc Runtime Constraints

- [x] Extend init/close/realloc runtime checks
- [x] Add tests for init constraint validation
- [x] Update docs

---

### ✅ v3.2.32 - Owner/Address/Executable Combos

- [x] Enforce owner/address/executable combination rules
- [x] Add tests for executable-only configs
- [x] Update docs

---

### ✅ v3.2.33 - Anchor Event Index Semantics

- [x] Restrict indexed event fields to bool/fixed-size ints/PublicKey (no usize/isize)
- [x] Improve compile-time errors for invalid index types and index overflow
- [x] Update docs

---

### ✅ v3.2.34 - AccountsDerive Alias Inference

- [x] Expand token/mint/ata inference alias lists (mint_account, wallet, etc.)
- [x] Add alias-based AccountsDerive tests
- [x] Update docs

---

### ✅ v3.2.35 - AccountsDerive Sysvar Defaults

- [x] Auto-wrap epoch_schedule/recent_blockhashes/fees sysvar fields
- [x] Add AccountsDerive tests for sysvar defaults
- [x] Update docs

---

### ✅ v3.2.36 - AccountsDerive Ref Validation

- [x] Validate cross-field token/mint/associated token references
- [x] Add AccountsDerive tests for ref validation
- [x] Update docs

---

### ✅ v3.2.37 - AccountsDerive Program Ref Checks

- [x] Validate token/mint/associated token program references
- [x] Update docs

---

### ✅ v3.2.38 - AccountsDerive Owner Ref Checks

- [x] Enforce Program/UncheckedProgram owner references for AccessFor
- [x] Update docs

---

### ⏳ v3.1.0 - Advanced Features

| Feature | Description |
|---------|-------------|
| Versioned Transactions | Full v0 transaction support with ALT |
| Priority Fees | Dynamic priority fee estimation |
| Jito Integration | MEV bundle support |
| Compute Optimization | Profiling and optimization tools |

---

## 📊 solana-program Organization Coverage

Based on https://github.com/solana-program (35 repositories):

### Already Implemented in SDK ✅

| Program | Program ID | Module | Status |
|---------|-----------|--------|--------|
| System | `11111111111111111111111111111111` | `system_program.zig` | ✅ Complete |
| Compute Budget | `ComputeBudget111111111111111111111111111111` | `compute_budget.zig` | ✅ Complete |
| Address Lookup Table | `AddressLookupTab1e1111111111111111111111111` | `address_lookup_table.zig` | ✅ Complete |
| BPF Loader v1 | `BPFLoader1111111111111111111111111111111111` | `bpf_loader.zig` | ✅ Complete |
| BPF Loader v2 | `BPFLoader2111111111111111111111111111111111` | `bpf_loader.zig` | ✅ Complete |
| BPF Loader v3 | `BPFLoaderUpgradeab1e11111111111111111111111` | `bpf_loader.zig` | ✅ Complete |
| BPF Loader v4 | `LoaderV411111111111111111111111111111111111` | `loader_v4.zig` | ✅ Complete |
| Vote | `Vote111111111111111111111111111111111111111` | `vote_interface.zig` | ✅ Complete |
| Feature Gate | `Feature111111111111111111111111111111111111` | `feature_gate.zig` | ✅ Complete |
| Ed25519 | `Ed25519SigVerify111111111111111111111111111` | `ed25519_program.zig` | ✅ Complete |
| Secp256k1 | `KeccakSecp256k11111111111111111111111111111` | `secp256k1_program.zig` | ✅ Complete |
| Secp256r1 | `Secp256r11111111111111111111111111111111111` | `secp256r1_program.zig` | ✅ Complete |
| Native Loader | `NativeLoader1111111111111111111111111111111` | `root.zig` | ✅ Complete |
| Incinerator | `1nc1nerator11111111111111111111111111111111` | `root.zig` | ✅ Complete |

### Planned for v2.x ⏳

| Program | Program ID | Priority | Version |
|---------|-----------|----------|---------|
| SPL Token | `TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA` | P0 | v2.0.0 |
| Associated Token Account | `ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL` | P0 | v2.0.0 |
| Token-2022 | `TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb` | P0 | v2.1.0 |
| Stake | `Stake11111111111111111111111111111111111111` | P0 | v2.2.0 |
| Memo | `MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr` | P2 | v2.3.0 |
| Token Metadata | `metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s` | P1 | v2.4.0 |
| Metaplex Core | `CoREENxT6tW1HoK8ypY1SxRMZTcVPm7R94rH4PZNhX7d` | P1 | v2.4.0 |
| Bubblegum (cNFT) | `BGUMAp9Gq7iTEuizy4pqaxsTyUCBK68MDfK752saRPUY` | P1 | v2.4.0 |
| Pyth Oracle | `pythWSnswVUd12oZpeFP8e9CVaEqJg25g1Vtc2biRsTC` | P1 | v2.5.0 |
| Config | `Config1111111111111111111111111111111111111` | P2 | v2.5.0 |
| Stake Pool | `SPoo1Ku8WFXoNDMHPsrGSTSG1Y47rzgn41SLUNakuHy` | P1 | v2.6.0 |
| Candy Machine v3 | `CndyV3LdqHUfDLmE5naZjVN8rBZz4tqhdefbAnjHG3JR` | P2 | v2.6.0 |

### Third-Party DeFi Programs (Interface Only)

For CPI integration, SDK may provide instruction builders:

| Program | Program ID | Usage |
|---------|-----------|-------|
| Jupiter V6 | `JUP6LkbZbjS1jKKwapdHNy74zcZ3tLUZoi5QNyVTaV4` | DEX aggregation (10% of chain activity) |
| Raydium AMM V4 | `675kPX9MHTjS2zt1qfr1NYHuzeLXfQM9H24wFSUt1Mp8` | AMM swaps (7% of chain activity) |
| Orca Whirlpool | `whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc` | Concentrated liquidity |

### Out of Scope (for now)

| Program | Reason |
|---------|--------|
| ZK ElGamal Proof | Temporarily disabled (security vulnerability June 2025) |
| Slashing | Validator-specific |
| Single Pool | Specialized staking |

---

## 📚 Resources

- [Solana SDK (Rust)](https://github.com/anza-xyz/solana-sdk)
- [Solana Zig Compiler](https://github.com/joncinque/solana-zig)
- [Zig Language](https://ziglang.org/)
- [solana-nostd-entrypoint](https://github.com/cavemanloverboy/solana-nostd-entrypoint) - Reference for zero-copy design
