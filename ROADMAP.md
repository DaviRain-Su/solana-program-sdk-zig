# Solana SDK Zig Implementation Roadmap

This roadmap outlines the implementation of the [Solana SDK](https://github.com/anza-xyz/solana-sdk) in Zig.

## 📊 Implementation Summary

| Category | Implemented | Total | Coverage |
|----------|-------------|-------|----------|
| Core Types | 8 | 8 | 100% |
| Serialization | 3 | 6 | 50% |
| Program Foundation | 9 | 12 | 75% |
| Sysvars | 5 | 11 | 45% |
| Hash Functions | 3 | 4 | 75% |
| Native Programs | 6 | 11 | 55% |
| Crypto | 0 | 4 | 0% |
| **Total (On-chain)** | **34** | **56** | **61%** |

> Note: Client/RPC and Validator modules are excluded as they're not needed for on-chain program development.

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

### Serialization (3/6 - 50%)

| Zig Module | Rust Crate | Status | Tests |
|------------|------------|--------|-------|
| `bincode.zig` | `bincode` | ✅ | ✅ |
| `borsh.zig` | `borsh` | ✅ | ✅ |
| `short_vec.zig` | `short-vec` | ✅ | ✅ |
| - | `serde` | ⏳ | - |
| - | `serde-varint` | ⏳ | - |
| - | `serialize-utils` | ⏳ | - |

### Program Foundation (9/12 - 75%)

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
| - | `cpi` | ⏳ | - |
| - | `program-memory` | ⏳ | - |
| - | `program-option` | ⏳ | - |
| - | `program-pack` | ⏳ | - |

### Sysvars (5/11 - 45%)

| Zig Module | Rust Crate | Status | Tests |
|------------|------------|--------|-------|
| `clock.zig` | `clock` | ✅ | ✅ |
| `rent.zig` | `rent` | ✅ | ✅ |
| `slot_hashes.zig` | `slot-hashes` | ✅ | ✅ |
| `slot_history.zig` | `slot-history` | ✅ | ✅ |
| `epoch_schedule.zig` | `epoch-schedule` | ✅ | ✅ |
| - | `epoch-info` | ⏳ | - |
| - | `epoch-rewards` | ⏳ | - |
| - | `last-restart-slot` | ⏳ | - |
| - | `instructions-sysvar` | ⏳ | - |
| - | `sysvar` | ⏳ | - |
| - | `sysvar-id` | ⏳ | - |

### Hash Functions (3/4 - 75%)

| Zig Module | Rust Crate | Status | Tests |
|------------|------------|--------|-------|
| `blake3.zig` | `blake3-hasher` | ✅ | ✅ |
| `sha256_hasher.zig` | `sha256-hasher` | ✅ | ✅ |
| `keccak_hasher.zig` | `keccak-hasher` | ✅ | ✅ |
| - | `epoch-rewards-hasher` | ⏳ | - |

### Native Programs (6/11 - 55%)

| Zig Module | Rust Crate | Status | Tests |
|------------|------------|--------|-------|
| `system_program.zig` | `system-interface` | ✅ | ✅ |
| `bpf_loader.zig` | `loader-v2-interface` | ✅ | ✅ |
| `bpf_loader.zig` | `loader-v3-interface` | ✅ | ✅ |
| `ed25519_program.zig` | `ed25519-program` | ✅ | ✅ |
| `secp256k1_program.zig` | `secp256k1-program` | ✅ | ✅ |
| - | `loader-v4-interface` | ⏳ | - |
| - | `secp256r1-program` | ⏳ | - |
| - | `compute-budget-interface` | ⏳ | - |
| - | `address-lookup-table-interface` | ⏳ | - |
| - | `vote-interface` | ⏳ | - |
| - | `feature-gate-interface` | ⏳ | - |

---

## ⏳ Pending Modules (Priority Order)

### High Priority (Essential for common programs)

| Module | Rust Crate | Description | Effort |
|--------|------------|-------------|--------|
| `cpi.zig` | `cpi` | Cross-Program Invocation | High |
| `compute_budget.zig` | `compute-budget-interface` | Compute budget instructions | Medium |
| `address_lookup_table.zig` | `address-lookup-table-interface` | ALT for versioned txns | Medium |
| `instructions_sysvar.zig` | `instructions-sysvar` | Introspection sysvar | Low |

### Medium Priority (Extended functionality)

| Module | Rust Crate | Description | Effort |
|--------|------------|-------------|--------|
| `native_token.zig` | `native-token` | SOL token utilities | Low |
| `nonce.zig` | `nonce` | Durable nonce types | Medium |
| `loader_v4.zig` | `loader-v4-interface` | New loader interface | Medium |
| `secp256r1_program.zig` | `secp256r1-program` | P-256 signatures | Medium |
| `last_restart_slot.zig` | `last-restart-slot` | Restart slot sysvar | Low |

### Low Priority (Specialized use cases)

| Module | Rust Crate | Description | Effort |
|--------|------------|-------------|--------|
| `vote_interface.zig` | `vote-interface` | Vote program | High |
| `feature_gate.zig` | `feature-gate-interface` | Feature gates | Low |
| `sanitize.zig` | `sanitize` | Input validation | Medium |
| `bn254.zig` | `bn254` | BN254 curve ops | High |
| `big_mod_exp.zig` | `big-mod-exp` | Modular exponentiation | Medium |

---

## 🚫 Out of Scope (Client/Validator modules)

These modules are NOT needed for on-chain program development:

- `client-traits` - RPC client interfaces
- `commitment-config` - RPC commitment levels
- `derivation-path` - HD wallet paths
- `seed-phrase` - Mnemonic handling
- `presigner` - Pre-signed transactions
- `file-download` - File utilities
- `genesis-config` - Genesis configuration
- `hard-forks` - Network hard forks
- `inflation` - Inflation parameters
- `poh-config` - PoH configuration
- `validator-exit` - Validator shutdown
- `quic-definitions` - QUIC networking
- `shred-version` - Shred versioning

---

## 📈 Version History

### v0.17.1 (Current) - Extended SDK Release
- ✅ Core types complete (pubkey, hash, signature, keypair)
- ✅ Serialization (Borsh, Bincode, ShortVec)
- ✅ Program foundation (entrypoint, error, log, syscalls)
- ✅ Basic sysvars (clock, rent, slot_hashes, slot_history, epoch_schedule)
- ✅ Hash functions (Blake3, SHA256, Keccak)
- ✅ Native programs (System, BPF Loader, Ed25519, Secp256k1)
- ✅ Transaction system (message, transaction, signer)
- ✅ Program test integration (cargo test passing)

### Next: v0.18.0 - CPI & Compute Budget
- [ ] `cpi.zig` - Cross-Program Invocation
- [ ] `compute_budget.zig` - Compute budget interface
- [ ] `address_lookup_table.zig` - Address Lookup Tables
- [ ] `native_token.zig` - Native token utilities

---

## 🎯 Development Guidelines

1. **Reference Implementation**: Always reference the Rust source in file headers
2. **Test Coverage**: Match or exceed Rust SDK test coverage
3. **API Compatibility**: Maintain similar API surface where possible
4. **Zig Idioms**: Use Zig best practices (comptime, error unions, slices)

## 📚 Resources

- [Solana SDK (Rust)](https://github.com/anza-xyz/solana-sdk)
- [Solana Zig Compiler](https://github.com/joncinque/solana-zig)
- [Zig Language](https://ziglang.org/)
