# Module Dependency Graph - SDK Restructure Design

> This document analyzes module dependencies to guide the SDK restructure.

## Dependency Analysis

### Legend

- `std` - Zig standard library (always allowed)
- `base58` - External dependency (allowed in SDK)
- `builtin` - Zig builtin (always allowed)
- `syscalls` - **Syscall dependency (NOT allowed in SDK)**
- `bpf` - **BPF-specific code (NOT allowed in SDK)**
- `log` - **Logging via syscall (NOT allowed in SDK)**

### Module Categories

#### Category A: Pure Modules (No syscall dependency)

These modules can be moved directly to `solana-sdk-zig`:

| Module | Dependencies | Notes |
|--------|--------------|-------|
| `hash.zig` | std, base58 | Pure type definition |
| `signature.zig` | std, builtin, hash | Pure type definition |
| `bincode.zig` | std | Pure serialization |
| `borsh.zig` | std | Pure serialization |
| `short_vec.zig` | std | Pure encoding |
| `error.zig` | std | Pure error types |
| `native_token.zig` | std | Pure constants |
| `epoch_rewards.zig` | std | Pure type definition |
| `last_restart_slot.zig` | std | Pure type definition |
| `program_option.zig` | std | Pure option type |
| `stable_layout.zig` | std | Pure layout utilities |
| `big_mod_exp.zig` | std | Pure math operations |
| `bls_signatures.zig` | std | Pure type definitions |

#### Category B: Modules Requiring Modification

These modules have syscall dependencies that need to be split:

| Module | Current Dependencies | Syscall Usage | Modification Needed |
|--------|---------------------|---------------|---------------------|
| `public_key.zig` | std, base58, **syscalls**, **log** | `createProgramAddress`, `findProgramAddress` | Split: pure type + syscall PDA |
| `instruction.zig` | std, account, public_key, **bpf** | CPI invoke functions | Split: pure types + CPI functions |
| `account.zig` | std, public_key | None directly, but public_key has syscalls | Keep if public_key is fixed |
| `keypair.zig` | std, base58, public_key, signature | None | Pure after public_key fix |
| `message.zig` | std, public_key, hash, short_vec, instruction | None directly | Pure after instruction fix |
| `transaction.zig` | std, public_key, hash, signature, message | None | Pure after dependencies fix |
| `nonce.zig` | std, public_key, hash | None | Pure after public_key fix |
| `signer.zig` | std, public_key, signature, keypair | None | Pure after keypair fix |

#### Category C: Program-Only Modules (Keep in program-sdk)

These modules have inherent syscall/BPF dependencies:

| Module | Dependencies | Reason |
|--------|--------------|--------|
| `syscalls.zig` | builtin | Core syscall definitions |
| `entrypoint.zig` | public_key, account, error, context | BPF entrypoint |
| `allocator.zig` | std | BPF heap allocator |
| `log.zig` | std, **bpf** | Syscall-based logging |
| `context.zig` | std, account, allocator, public_key, **bpf** | Entrypoint parsing |
| `bpf.zig` | std, builtin, public_key | BPF utilities |
| `program_memory.zig` | std, **bpf** | Syscall memory ops |
| `blake3.zig` | **syscalls**, **log**, hash | Syscall hasher |
| `sha256_hasher.zig` | std, **syscalls**, **log**, hash | Syscall hasher |
| `keccak_hasher.zig` | std, **syscalls**, **log**, hash | Syscall hasher |
| `clock.zig` | **bpf**, **log**, public_key | Sysvar access |
| `rent.zig` | **bpf**, **log**, public_key | Sysvar access |
| `epoch_schedule.zig` | std, **bpf**, **log**, public_key | Sysvar access |
| `slot_hashes.zig` | std, public_key | Sysvar type |
| `slot_history.zig` | std, **bpf**, **log**, public_key | Sysvar access |
| `instructions_sysvar.zig` | std, public_key, **bpf** | Sysvar access |
| `sysvar.zig` | std, public_key, clock, rent, ... | Sysvar utilities |
| `sysvar_id.zig` | std, public_key | Pure, but sysvar-specific |
| `system_program.zig` | std, public_key, instruction | Native program |
| `bpf_loader.zig` | std, public_key | Native program |
| `compute_budget.zig` | std, public_key, instruction, account | Native program |
| `address_lookup_table.zig` | std, public_key | Native program |
| `ed25519_program.zig` | std, public_key | Native program |
| `secp256k1_program.zig` | std, public_key | Native program |
| `secp256r1_program.zig` | std, public_key, instruction | Native program |
| `loader_v4.zig` | std, public_key, instruction, account, system_program | Native program |
| `feature_gate.zig` | std, public_key, instruction, system_program, rent | Native program |
| `vote_interface.zig` | std, public_key | Native program |
| `epoch_rewards_hasher.zig` | std, public_key, hash | Program-specific hasher |
| `bn254.zig` | syscalls | ZK crypto syscalls |
| `msg.zig` | std, **log** | Log utilities |
| `program_pack.zig` | std, error | Pack/Unpack for accounts |

---

## Dependency Graph (ASCII)

```
                    SDK Layer (No syscalls)
    ┌─────────────────────────────────────────────────────┐
    │                                                     │
    │   ┌─────────┐                                      │
    │   │  std    │                                      │
    │   └────┬────┘                                      │
    │        │                                           │
    │   ┌────▼────┐    ┌──────────┐                     │
    │   │ base58  │    │ builtin  │                     │
    │   └────┬────┘    └────┬─────┘                     │
    │        │              │                            │
    │   ┌────▼──────────────▼────┐                      │
    │   │        hash.zig        │                      │
    │   └────────────┬───────────┘                      │
    │                │                                   │
    │   ┌────────────▼───────────┐                      │
    │   │     signature.zig      │                      │
    │   └────────────┬───────────┘                      │
    │                │                                   │
    │   ┌────────────▼───────────────┐                  │
    │   │  public_key.zig (PURE)     │◄─────┐           │
    │   │  - Type definition only    │      │           │
    │   │  - No syscall PDA          │      │           │
    │   └────────────┬───────────────┘      │           │
    │                │                       │           │
    │   ┌────────────▼───────────┐   ┌──────┴────────┐  │
    │   │    account.zig        │   │  keypair.zig  │  │
    │   └────────────┬──────────┘   └───────┬───────┘  │
    │                │                       │          │
    │   ┌────────────▼───────────┐          │          │
    │   │ instruction.zig (PURE) │          │          │
    │   │ - Type definitions only │          │          │
    │   │ - No CPI functions     │          │          │
    │   └────────────┬───────────┘          │          │
    │                │                       │          │
    │   ┌────────────▼───────────┐          │          │
    │   │     message.zig        │          │          │
    │   └────────────┬───────────┘          │          │
    │                │                       │          │
    │   ┌────────────▼───────────────────────▼────┐    │
    │   │         transaction.zig                 │    │
    │   └─────────────────────────────────────────┘    │
    │                                                   │
    │   Other SDK modules:                             │
    │   bincode, borsh, short_vec, error,              │
    │   native_token, nonce, signer, big_mod_exp,      │
    │   bls_signatures, program_option, stable_layout  │
    │                                                   │
    └─────────────────────────────────────────────────────┘

                    Program SDK Layer (Syscall-dependent)
    ┌─────────────────────────────────────────────────────┐
    │                                                     │
    │   ┌─────────────────┐    ┌────────────────────┐    │
    │   │  syscalls.zig   │◄───┤     bpf.zig        │    │
    │   └────────┬────────┘    └──────────┬─────────┘    │
    │            │                         │              │
    │   ┌────────▼────────┐    ┌──────────▼─────────┐    │
    │   │    log.zig      │    │   allocator.zig    │    │
    │   └────────┬────────┘    └──────────┬─────────┘    │
    │            │                         │              │
    │   ┌────────▼─────────────────────────▼────────┐    │
    │   │              context.zig                   │    │
    │   └──────────────────┬────────────────────────┘    │
    │                      │                              │
    │   ┌──────────────────▼────────────────────────┐    │
    │   │           entrypoint.zig                   │    │
    │   └───────────────────────────────────────────┘    │
    │                                                     │
    │   PDA with syscalls:                               │
    │   ┌───────────────────────────────────────────┐    │
    │   │  public_key_pda.zig (syscall version)     │    │
    │   │  - createProgramAddress (syscall)         │    │
    │   │  - findProgramAddress (syscall)           │    │
    │   └───────────────────────────────────────────┘    │
    │                                                     │
    │   CPI functions:                                   │
    │   ┌───────────────────────────────────────────┐    │
    │   │  cpi.zig (syscall version)                │    │
    │   │  - invoke()                               │    │
    │   │  - invokeSignedUnchecked()                │    │
    │   └───────────────────────────────────────────┘    │
    │                                                     │
    │   Sysvars, Native Programs, Crypto...              │
    │                                                     │
    └─────────────────────────────────────────────────────┘
```

---

## Implementation Strategy

### Phase 1: Modify Modules

#### 1.1 Split `public_key.zig`

**Before** (current):
```zig
// public_key.zig - has syscall dependency
const syscalls = @import("syscalls.zig");

pub const PublicKey = struct {
    // ... type definition
    
    pub fn createProgramAddress(...) !PublicKey {
        // Uses syscalls
    }
    
    pub fn findProgramAddress(...) struct {...} {
        // Uses syscalls
    }
};
```

**After** (SDK version):
```zig
// sdk/src/public_key.zig - pure, no syscalls
pub const PublicKey = struct {
    // ... type definition only
    // NO createProgramAddress
    // NO findProgramAddress
};
```

**After** (Program SDK version):
```zig
// src/pda.zig - syscall implementations
const sdk = @import("solana-sdk-zig");
const syscalls = @import("syscalls.zig");

pub fn createProgramAddress(seeds: []const []const u8, program_id: *const sdk.PublicKey) !sdk.PublicKey {
    // Syscall implementation
}

pub fn findProgramAddress(seeds: []const []const u8, program_id: *const sdk.PublicKey) struct {...} {
    // Syscall implementation
}
```

#### 1.2 Split `instruction.zig`

**Before** (current):
```zig
// instruction.zig - has CPI functions
const bpf = @import("bpf.zig");

pub const Instruction = struct { ... };
pub const AccountMeta = struct { ... };

pub fn invoke(...) ProgramError!void {
    // CPI via syscall
}
```

**After** (SDK version):
```zig
// sdk/src/instruction.zig - pure types only
pub const Instruction = struct { ... };
pub const AccountMeta = struct { ... };
// NO invoke functions
```

**After** (Program SDK version):
```zig
// src/cpi.zig - CPI functions
const sdk = @import("solana-sdk-zig");
const bpf = @import("bpf.zig");

pub fn invoke(instruction: *const sdk.Instruction, account_infos: []const sdk.Account) !void {
    // CPI syscall
}
```

### Phase 2: Create SDK Directory

```
sdk/
├── build.zig
├── build.zig.zon
└── src/
    ├── root.zig           # Re-exports all
    ├── public_key.zig     # Pure type
    ├── hash.zig
    ├── signature.zig
    ├── keypair.zig
    ├── account.zig
    ├── instruction.zig    # Pure types only
    ├── message.zig
    ├── transaction.zig
    ├── bincode.zig
    ├── borsh.zig
    ├── short_vec.zig
    ├── error.zig
    ├── native_token.zig
    ├── nonce.zig
    ├── signer.zig
    ├── big_mod_exp.zig
    ├── bls_signatures.zig
    ├── program_option.zig
    └── stable_layout.zig
```

### Phase 3: Update Program SDK

```
src/
├── root.zig               # Re-exports SDK + program modules
├── pda.zig                # PDA syscall functions
├── cpi.zig                # CPI syscall functions
├── syscalls.zig
├── entrypoint.zig
├── allocator.zig
├── log.zig
├── context.zig
├── bpf.zig
├── program_memory.zig
├── (sysvars...)
├── (native programs...)
└── (crypto syscalls...)
```

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Circular dependency | Start with leaf modules (hash, signature) |
| Missing exports | Run full test suite after each module move |
| API breakage | Keep module names, just change import paths |
| Import path changes | Use SDK re-exports for compatibility |

---

## Verification Checklist

- [x] All SDK modules compile independently (`sdk/build.zig`)
- [x] No SDK module imports syscalls, bpf, or log
- [x] Program SDK depends on SDK (`build.zig.zon`)
- [x] All tests pass after restructure (current total: 363 across SDK/Program SDK/Client/Integration)
- [x] Example programs still work
