# solana-program-sdk-zig

Complete Zig implementation of the [Solana SDK](https://github.com/anza-xyz/solana-sdk), enabling Solana blockchain development in Zig.

This project provides a comprehensive, type-safe Zig SDK that mirrors the Rust `solana-sdk` crate, allowing developers to build Solana programs and clients using Zig's modern, memory-safe language.

## Features

- **Complete Solana SDK Implementation** - Full feature parity with Rust `solana-sdk`
- **Native SBF Support** - solana-zig compiles directly to Solana BPF target
- **Type-Safe API** - Zero-cost abstractions matching Rust SDK
- **Two-Layer Architecture** - Shared SDK types + Program SDK with syscalls

### Token-2022 Support

| Feature | Status |
|---------|--------|
| SPL Token (Original) | ✅ Complete (v2.0.0) |
| Associated Token Account | ✅ Complete (v2.0.0) |
| Token-2022 Extensions | ⏳ Planned (v2.1.0) |

See [docs/TOKEN_PROGRAMS.md](docs/TOKEN_PROGRAMS.md) for details.

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
const anchor = @import("sol_anchor_zig");
const sol = anchor.sdk;
```

IDL + Zig client codegen:

```zig
const idl_json = try anchor.generateIdlJson(allocator, MyProgram, .{});
const client_src = try anchor.generateZigClient(allocator, MyProgram, .{});
```

IDL output (build step):

```bash
./solana-zig/zig build idl \
  -Didl-program=anchor/src/idl_example.zig \
  -Didl-output-dir=idl
```

`idl-program` must export `pub const Program`. By default, the IDL file name is derived from the program metadata name (or the program type name) and written under `idl/`. Use `-Didl-output` to override the full path.

Comptime derives:

```zig
const Accounts = anchor.Accounts(struct {
    authority: anchor.Signer,
    counter: anchor.Account(CounterData, .{
        .discriminator = anchor.accountDiscriminator("Counter"),
        .attrs = &.{
            anchor.attr.seeds(&.{ anchor.seed("counter"), anchor.seedAccount("authority") }),
            anchor.attr.bump(),
            anchor.attr.constraint("authority.key() == counter.authority"),
        },
    }),
});

const CounterEvent = anchor.Event(struct {
    amount: anchor.eventField(u64, .{ .index = true }),
    owner: sol.PublicKey,
});
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

See [docs/TESTING.md](docs/TESTING.md) for the full test matrix.

### Testing with MCL (Optional)

For off-chain BN254 elliptic curve operations:

```bash
git submodule update --init vendor/mcl
./solana-zig/zig build test -Dwith-mcl
```

MCL is optional. On-chain programs use Solana's native syscalls (`sol_alt_bn128_*`).

## Deployment

Build for Solana SBF and deploy with Solana CLI. See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for step-by-step workflows.

```bash
./solana-zig/zig build -Dtarget=sbf-solana
```

## Development Status

See [ROADMAP.md](ROADMAP.md) for current implementation status.

## License

MIT
