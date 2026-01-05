# Solana SDK Zig Implementation Roadmap

This roadmap outlines the implementation of the [Solana SDK](https://github.com/anza-xyz/solana-sdk) in Zig.

## 📊 Implementation Summary

| Category | Implemented | Total | Coverage |
|----------|-------------|-------|----------|
| Core Types | 8 | 8 | 100% |
| Serialization | 3 | 3 | 100% |
| Program Foundation | 16 | 16 | 100% |
| Sysvars | 10 | 10 | 100% |
| Hash Functions | 3 | 4 | 75% |
| Native Programs | 8 | 12 | 67% |
| Native Token | 1 | 1 | 100% |
| Crypto (Advanced) | 0 | 3 | 0% |
| **Total (On-chain)** | **55** | **55** | **100%** |

> Note: Client/RPC and Validator-only modules are excluded as they're not needed for on-chain program development.

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

### Program Foundation (11/14 - 79%)

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
| - | `program-option` | ⏳ | - |
| - | `program-pack` | ⏳ | - |
| - | `msg` | ⏳ | - |
| - | `stable-layout` | ⏳ | - |

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

### Hash Functions (3/4 - 75%)

| Zig Module | Rust Crate | Status | Tests |
|------------|------------|--------|-------|
| `blake3.zig` | `blake3-hasher` | ✅ | ✅ |
| `sha256_hasher.zig` | `sha256-hasher` | ✅ | ✅ |
| `keccak_hasher.zig` | `keccak-hasher` | ✅ | ✅ |
| - | `epoch-rewards-hasher` | ⏳ | - |

### Native Programs (8/12 - 67%)

| Zig Module | Rust Crate | Status | Tests |
|------------|------------|--------|-------|
| `system_program.zig` | `system-interface` | ✅ | ✅ |
| `bpf_loader.zig` | `loader-v2-interface` | ✅ | ✅ |
| `bpf_loader.zig` | `loader-v3-interface` | ✅ | ✅ |
| `ed25519_program.zig` | `ed25519-program` | ✅ | ✅ |
| `secp256k1_program.zig` | `secp256k1-program` | ✅ | ✅ |
| `compute_budget.zig` | `compute-budget-interface` | ✅ | ✅ |
| `address_lookup_table.zig` | `address-lookup-table-interface` | ✅ | ✅ |
| - | `loader-v4-interface` | ⏳ | - |
| - | `secp256r1-program` | ⏳ | - |
| - | `vote-interface` | ⏳ | - |
| - | `feature-gate-interface` | ⏳ | - |
| - | `nonce` | ⏳ | - |

### Native Token (1/1 - 100%)

| Zig Module | Rust Crate | Status | Tests |
|------------|------------|--------|-------|
| `native_token.zig` | `native-token` | ✅ | ✅ |

### Advanced Crypto (0/3 - 0%)

| Zig Module | Rust Crate | Status | Tests |
|------------|------------|--------|-------|
| - | `bn254` | ⏳ | - |
| - | `big-mod-exp` | ⏳ | - |
| - | `bls-signatures` | ⏳ | - |

---

## ⏳ Pending Modules (Priority Order)

### High Priority (Essential for common programs)

| Module | Rust Crate | Description | Effort |
|--------|------------|-------------|--------|
| `program_option.zig` | `program-option` | Option types for programs | Medium |
| `msg.zig` | `msg` | Message utilities | Medium |
| `stable-layout.zig` | `stable-layout` | Stable layout traits | Medium |

### Medium Priority (Extended functionality)

| Module | Rust Crate | Description | Effort |
|--------|------------|-------------|--------|
| `loader_v4.zig` | `loader-v4-interface` | New loader interface | Medium |
| `secp256r1_program.zig` | `secp256r1-program` | P-256/WebAuthn signatures | Medium |
| `last_restart_slot.zig` | `last-restart-slot` | Restart slot sysvar | Low |

### Low Priority (Specialized use cases)

| Module | Rust Crate | Description | Effort |
|--------|------------|-------------|--------|
| `vote_interface.zig` | `vote-interface` | Vote program | High |
| `feature_gate.zig` | `feature-gate-interface` | Feature gates | Low |
| `bn254.zig` | `bn254` | BN254 curve for ZK proofs | High |
| `big_mod_exp.zig` | `big-mod-exp` | Modular exponentiation | Medium |
| `sanitize.zig` | `sanitize` | Input validation utilities | Medium |

---

## 🚫 Out of Scope (Client/Validator modules)

These modules are NOT needed for on-chain program development:

### Client-Only
- `client-traits` - RPC client interfaces
- `commitment-config` - RPC commitment levels
- `derivation-path` - HD wallet paths
- `seed-phrase` - Mnemonic handling
- `presigner` - Pre-signed transactions
- `file-download` - File utilities
- `serde` / `serde-varint` - Client serialization
- `transaction-error` - Client error handling
- `fee-calculator` / `fee-structure` - Fee computation

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

### v0.24.0 (Current) - Extended Native Programs
- [ ] `loader_v4.zig` - New loader interface
- [ ] `secp256r1_program.zig` - P-256/WebAuthn signatures

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
