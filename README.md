# solana-program-sdk-zig

Complete Zig implementation of the [Solana SDK](https://github.com/anza-xyz/solana-sdk), enabling Solana blockchain development in Zig.

This project provides a comprehensive, type-safe Zig SDK that mirrors the Rust `solana-sdk` crate, allowing developers to build Solana programs and clients using Zig's modern, memory-safe language.

## Features

- **Complete Solana SDK Implementation** - Full feature parity with Rust `solana-sdk`
- **Native SBF Support** - solana-zig compiles directly to Solana BPF target
- **Type-Safe API** - Zero-cost abstractions matching Rust SDK
- **Two-Layer Architecture** - Shared SDK types + Program SDK with syscalls

## Architecture

### Build Pipeline

```
┌─────────────┐                    ┌─────────────┐
│   Zig Code  │───────────────────>│ Solana eBPF │
│             │    solana-zig      │   (.so)     │
└─────────────┘                    └─────────────┘
```

### Module Structure

```
solana-program-sdk-zig/
├── sdk/                    # Shared SDK (no syscalls)
│   └── src/
│       ├── public_key.zig  # PublicKey type (pure SHA256 PDA)
│       ├── hash.zig        # Hash type
│       ├── signature.zig   # Signature type
│       ├── keypair.zig     # Keypair type
│       ├── instruction.zig # Instruction types (no CPI)
│       ├── bincode.zig     # Bincode serialization
│       ├── borsh.zig       # Borsh serialization
│       └── ...
├── src/                    # Program SDK (with syscalls)
│   ├── public_key.zig      # Re-exports SDK + syscall PDA
│   ├── instruction.zig     # Re-exports SDK + CPI
│   ├── account.zig         # Account types
│   ├── syscalls.zig        # Solana syscalls
│   ├── entrypoint.zig      # Program entrypoint
│   ├── log.zig             # Logging
│   └── ...
├── anchor/                 # Anchor framework subpackage
│   └── src/
│       └── root.zig
├── program-test/           # Integration tests
└── build.zig
```

## Anchor Framework

The Anchor-like framework is now a dedicated subpackage under `anchor/`.

```zig
const sol = @import("solana_program_sdk");
const anchor = @import("sol_anchor_zig");
```

Build/tests for anchor:

```bash
cd anchor
../solana-zig/zig build test --summary all
```

## Prerequisites

### solana-zig (Required)

```bash
./install-solana-zig.sh

# Or set custom version
SOLANA_ZIG_VERSION=v1.52.0 ./install-solana-zig.sh
```

solana-zig is a modified Zig compiler with native Solana SBF target support. It compiles directly to `.so` files without external linkers.

### For Deployment (Optional)

```bash
# Solana CLI
sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"
```

## Quick Start

### 1. Building On-Chain Programs

```zig
// src/main.zig
const sdk = @import("solana_program_sdk");

fn processInstruction(
    program_id: *sdk.PublicKey,
    accounts: []sdk.Account,
    data: []const u8,
) sdk.ProgramResult {
    sdk.log.sol_log("Hello from Zig!");
    return .ok;
}

comptime {
    sdk.entrypoint.define(processInstruction);
}
```

```bash
# Build for Solana
./solana-zig/zig build -Dtarget=sbf-solana
```

### 2. Using SDK Types (Off-Chain)

```zig
const sdk = @import("solana_sdk");

pub fn main() !void {
    const pubkey = try sdk.PublicKey.fromBase58("11111111111111111111111111111112");
    const keypair = sdk.Keypair.generate();
    
    std.debug.print("Public key: {s}\n", .{pubkey.toBase58()});
}
```

## Testing

```bash
# Test Program SDK (285 tests)
./solana-zig/zig build test --summary all

# Test SDK only (105 tests)
cd sdk && ../solana-zig/zig build test --summary all

# Integration tests
./program-test/test.sh
```

### Testing with MCL (Optional)

For off-chain BN254 elliptic curve operations:

```bash
git submodule update --init vendor/mcl
./solana-zig/zig build test -Dwith-mcl
```

MCL is optional. On-chain programs use Solana's native syscalls (`sol_alt_bn128_*`).

## Development Status

See [ROADMAP.md](ROADMAP.md) for current implementation status.

## License

MIT
