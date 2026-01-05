# solana-program-sdk-zig

Complete Zig implementation of the [Solana SDK](https://github.com/anza-xyz/solana-sdk), enabling Solana blockchain development in Zig.

This project provides a comprehensive, type-safe Zig SDK that mirrors the Rust `solana-sdk` crate, allowing developers to build Solana programs and clients using Zig's modern, memory-safe language.

## Features

- **Complete Solana SDK Implementation** - Full feature parity with Rust `solana-sdk`
- **Standard Zig Compiler** - No custom compiler forks required
- **Type-Safe API** - Zero-cost abstractions matching Rust SDK
- **BPF Program Development** - Write on-chain programs in Zig
- **Client Development** - Build off-chain clients and tools

## Architecture

### Two-Stage Build Pipeline

For on-chain programs:
```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│   Zig Code  │───>│ LLVM Bitcode │───>│ Solana eBPF │
│             │    │   (.bc)      │    │   (.so)     │
└─────────────┘    └──────────────┘    └─────────────┘
    zig build        sbpf-linker        deploy
```

### Module Structure

```
solana-program-sdk-zig/
├── src/
│   ├── pubkey.zig          # Public key types
│   ├── hash.zig            # Hash functions
│   ├── signature.zig       # Digital signatures
│   ├── keypair.zig         # Key pair management
│   ├── instruction.zig     # Program instructions
│   ├── account.zig         # Account types
│   ├── message.zig         # Transaction messages
│   ├── transaction.zig     # Transactions
│   ├── program_error.zig   # Program errors
│   └── syscalls.zig        # Solana syscalls
├── tools/
│   └── murmur3.zig         # Hash utilities
├── program-test/           # Integration tests
└── build.zig               # Build system
```

## Prerequisites

### For All Development
- **Zig 0.15.2+** - [Download](https://ziglang.org/download/)
  - *Alternative*: **Solana Zig** - Specialized Zig fork for Solana development
- **LLVM 18** - Required for sbpf-linker
- **sbpf-linker** - Solana BPF linker

### Solana Zig Setup (Recommended for On-Chain Programs)
```bash
# Install solana-zig compiler
./install-solana-zig.sh

# Or set custom version
SOLANA_ZIG_VERSION=v1.52.0 ./install-solana-zig.sh
```

**Note**: Solana Zig provides better integration with Solana's BPF runtime and may have performance optimizations.

### For On-Chain Programs
```bash
# Ubuntu/Debian
sudo apt-get install llvm-18 llvm-18-dev

# Install sbpf-linker
cargo install --git https://github.com/blueshift-gg/sbpf-linker.git
```

### For Client Development
```bash
# Solana CLI for deployment
sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"
```

## Quick Start

### 1. Building On-Chain Programs

```zig
// src/main.zig
const sdk = @import("solana_program_sdk");

fn processInstruction(
    program_id: *sdk.Pubkey,
    accounts: []sdk.Account,
    data: []const u8,
) sdk.ProgramResult {
    // Your program logic here
    return .ok;
}

comptime {
    sdk.entrypoint(&processInstruction);
}
```

```zig
// build.zig
const solana = @import("solana_program_sdk");

pub fn build(b: *std.Build) void {
    const program = solana.addSolanaProgram(b, .{
        .name = "my_program",
        .root_source_file = b.path("src/main.zig"),
    });
    b.getInstallStep().dependOn(program.getInstallStep());
}
```

### 2. Client Development

```zig
const sdk = @import("solana_program_sdk");

pub fn main() !void {
    // Create a public key
    const pubkey = try sdk.Pubkey.fromBase58("11111111111111111111111111111112");
    
    // Create a keypair
    const keypair = sdk.Keypair.generate();
    
    // Build a transaction
    var transaction = sdk.Transaction.new();
    // ... add instructions
    
    std.debug.print("Public key: {f}\n", .{pubkey});
}
```

## Development Status

See [ROADMAP.md](ROADMAP.md) for current implementation status and priorities.

## Testing

```bash
# With standard Zig
zig build test
zig test src/pubkey.zig

# With solana-zig (recommended)
./solana-zig/zig build test
./solana-zig/zig test src/pubkey.zig

# Run integration tests (requires solana-zig)
cd program-test && ../solana-zig/zig build --summary all --verbose
cargo test --manifest-path program-test/Cargo.toml
```

## Contributing

This project follows a **documentation-driven development** process:

1. **Documentation First** - Update ROADMAP.md and create Story files
2. **Implementation** - Write code with comprehensive tests
3. **Validation** - Ensure all tests pass and documentation is complete

See [AGENTS.md](AGENTS.md) for detailed development guidelines.

## Building with Solana Zig

For on-chain program development, solana-zig is recommended:

```bash
# Install solana-zig
./install-solana-zig.sh

# Use solana-zig for all builds
export ZIG="./solana-zig/zig"
$ZIG build
$ZIG build test

# Or use the provided convenience script
./build-solana-zig.sh
./build-solana-zig.sh test

# For integration testing
./program-test/test.sh ./solana-zig/zig
```

## License

MIT
