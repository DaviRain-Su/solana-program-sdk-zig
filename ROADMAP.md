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
| Other (epoch_info) | 1 | 1 | 100% |
| **Total (On-chain)** | **59** | **59** | **100%** |

> Note: Client/RPC and Validator-only modules are excluded.
> v0.29.0 complete: Added loader-v3 instructions, instruction_error, transaction_error, epoch_info.

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

## 🔮 v1.1.0 - Client SDK (Planned)

The following client-side modules are planned for implementation in `client/`:

### RPC Methods (52 total)

| Priority | Count | Examples |
|----------|-------|----------|
| **P0** | 6 | `getBalance`, `getAccountInfo`, `getLatestBlockhash`, `sendTransaction` |
| **P1** | 18 | `getMultipleAccounts`, `simulateTransaction`, `requestAirdrop` |
| **P2** | 28 | Remaining methods |

### Infrastructure
| Module | Description | Status |
|--------|-------------|--------|
| `client/src/json_rpc.zig` | JSON-RPC 2.0 client | ⏳ Planned |
| `client/src/error.zig` | RPC error types | ⏳ Planned |
| `client/src/commitment.zig` | Commitment levels | ⏳ Planned |
| `client/src/types.zig` | Response types | ⏳ Planned |

### Transaction Building
| Module | Description | Status |
|--------|-------------|--------|
| `transaction/builder.zig` | Transaction builder | ⏳ Planned |
| `transaction/signer.zig` | Transaction signing | ⏳ Planned |

> **See**: `stories/v1.1.0-client-sdk.md` for detailed 52-method implementation plan.

---

## 🏗️ v1.0.0 - SDK Architecture Restructure ✅

The SDK has been restructured into a two-layer architecture for better separation of concerns:

### Current Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              sdk/ (共享核心类型 - 132 tests)                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  PublicKey, Hash, Signature, Keypair                │   │
│  │  Instruction, AccountMeta (types only)              │   │
│  │  bincode, borsh, short_vec, error, native_token     │   │
│  │  nonce, instruction_error, transaction_error        │   │
│  │  epoch_info (pure types via SHA256)                 │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                    ▲                       ▲
                    │ depends on            │ depends on
        ┌───────────┴───────────┐ ┌────────┴────────────┐
        │                       │ │                     │
┌───────▼───────────────┐  ┌────▼────────────────────┐
│ src/ (Program SDK)    │  │ client/ (Planned)       │
│ (300 tests)           │  │                         │
│ ┌───────────────────┐ │  │ ┌────────────────────┐  │
│ │ syscalls          │ │  │ │ RPC Client         │  │
│ │ entrypoint        │ │  │ │ Connection API     │  │
│ │ CPI (invokeSigned)│ │  │ │ Transaction Signer │  │
│ │ sysvars           │ │  │ │ Wallet Integration │  │
│ │ native programs   │ │  │ └────────────────────┘  │
│ │ crypto (syscall)  │ │  │                         │
│ └───────────────────┘ │  │                         │
└───────────────────────┘  └─────────────────────────┘
```

### Restructure Phases

| Phase | Goal | Status |
|-------|------|--------|
| Phase 1 | Extract shared types to `sdk/` directory | ✅ Complete |
| Phase 2 | Refactor program-sdk to depend on sdk/ | ✅ Complete |
| Phase 3 | Create client-sdk with RPC client | ⏳ Planned (v1.1.0) |

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

### v1.0.0 - SDK Architecture Restructure ✅
- ✅ Two-layer architecture: `sdk/` (shared) + `src/` (program)
- ✅ SDK layer: 105 tests (no syscall dependencies)
- ✅ Program SDK layer: 285 tests (with syscall support)
- ✅ Clean separation of pure types and BPF-specific code

### v0.29.0 - Program SDK Completion ⏳
- ⏳ `loader-v3` instruction builders (UpgradeableLoaderInstruction)
- ⏳ `instruction_error.zig` - Runtime instruction errors
- ⏳ `transaction_error.zig` - Transaction errors (for Client SDK)
- ⏳ `epoch_info.zig` - EpochInfo type (for Client SDK)
- ⏳ `sdk_ids.zig` - Centralized program ID constants

---

## 🎯 Development Guidelines

1. **Reference Implementation**: Always reference the Rust source in file headers
2. **Test Coverage**: Match or exceed Rust SDK test coverage
3. **API Compatibility**: Maintain similar API surface where possible
4. **Zig Idioms**: Use Zig best practices (comptime, error unions, slices)
5. **Zero-Copy**: Prefer pointer operations over memory copies
6. **Stack Safety**: Use heap allocation for large arrays (>1KB)

## 📚 Resources

- [Solana SDK (Rust)](https://github.com/anza-xyz/solana-sdk)
- [Solana Zig Compiler](https://github.com/joncinque/solana-zig)
- [Zig Language](https://ziglang.org/)
- [solana-nostd-entrypoint](https://github.com/cavemanloverboy/solana-nostd-entrypoint) - Reference for zero-copy design
