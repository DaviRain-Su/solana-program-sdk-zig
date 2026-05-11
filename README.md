# solana-program-sdk-zig

Write Solana on-chain programs in Zig.

This SDK requires the [solana-zig fork][fork] of Zig 0.16 for building
on-chain programs. Stock Zig 0.16 is sufficient for host-side unit tests.

[fork]: https://github.com/joncinque/solana-zig-bootstrap/releases/tag/solana-v1.53.0

## Quick start

```console
# Download solana-zig fork (macOS arm64)
curl -LO https://github.com/joncinque/solana-zig-bootstrap/releases/download/solana-v1.53.0/zig-aarch64-macos-none.tar.bz2
tar -xjf zig-aarch64-macos-none.tar.bz2
export SOLANA_ZIG="$(pwd)/zig-aarch64-macos-none-baseline/zig"

# Run tests
"$SOLANA_ZIG" build test --summary all
./program-test/test.sh "$SOLANA_ZIG"
```

## Performance

Transfer-lamports benchmark (CU = Compute Units):

| Implementation | CU | Notes |
|---|---|---|
| **Zig SDK** | **24** | ← Best |
| Pinocchio (Rust) | 27 | |
| Assembly | 30 | |
| C | 104 | |
| Rust (solana-program) | 459 | |

## Entrypoint

The SDK provides a single entrypoint style — `InstructionContext` — inspired by
Pinocchio's `lazy_program_entrypoint!`. 16 bytes of stack, on-demand parsing,
zero-copy.

### With `ProgramResult` (error union)

```zig
const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const source = ctx.nextAccount() orelse return error.NotEnoughAccountKeys;
    const dest = ctx.nextAccount() orelse return error.NotEnoughAccountKeys;
    const ix_data = ctx.instructionData();
    if (ix_data.len < 8) return error.InvalidInstructionData;

    const amount: u64 = @as(*align(1) const u64, @ptrCast(ix_data[0..8])).*;
    source.raw.lamports -= amount;
    dest.raw.lamports += amount;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
```

### With raw `u64` (maximum performance)

Skips the error union entirely. Return `0` for success, non-zero for error.

```zig
const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

fn process(ctx: *sol.entrypoint.InstructionContext) u64 {
    if (ctx.remainingAccounts() != 2) return 1;

    const source = ctx.nextAccountUnchecked();
    const dest = ctx.nextAccountUnchecked();
    const ix_data = ctx.instructionData();
    if (ix_data.len < 8) return 1;

    const amount: u64 = @as(*align(1) const u64, @ptrCast(ix_data[0..8])).*;
    source.raw.lamports -= amount;
    dest.raw.lamports += amount;
    return 0;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypointRaw(process)(input);
}
```

## AccountInfo

`AccountInfo` is 8 bytes — a single pointer to the runtime's `Account` struct.
All accessors are inline with zero overhead.

```zig
const account = ctx.nextAccountUnchecked();
_ = account.key();           // *const Pubkey
_ = account.owner();         // *const Pubkey
_ = account.lamports();      // u64
_ = account.dataLen();       // usize
_ = account.data();          // []u8
_ = account.isSigner();      // bool
_ = account.isWritable();    // bool
account.raw.lamports += 100; // direct field access
```

For CPI calls, convert to `CpiAccountInfo`:

```zig
const cpi_info = account.toCpiInfo();
try sol.cpi.invoke(&instruction, &.{cpi_info});
```

## Using the SDK from your `build.zig`

```zig
const std = @import("std");
const solana = @import("solana_program_sdk");

pub fn build(b: *std.Build) void {
    _ = solana.buildProgram(b, .{
        .name = "my_program",
        .root_source_file = b.path("src/main.zig"),
        .optimize = .ReleaseFast,
    });
}
```

## Prerequisites

### solana-zig fork (required for on-chain program builds)

Download from [GitHub Releases](https://github.com/joncinque/solana-zig-bootstrap/releases/tag/solana-v1.53.0).

### Stock Zig 0.16 (host unit tests only)

```console
zig version
# -> 0.16.x
```

## Tests

```console
# Host unit tests (any Zig 0.16)
zig build test --summary all

# Integration tests (requires solana-zig fork)
./program-test/test.sh "$SOLANA_ZIG"
```

## Branch layout

- `main` — original upstream solana-zig based SDK (legacy reference).
- **`solana-zig-fork-0.16`** (this branch) — solana-zig fork only, recommended default.
