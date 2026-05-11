# solana-program-sdk-zig

Write Solana on-chain programs in Zig.

This SDK requires the [solana-zig fork][fork] of Zig 0.16 for building
on-chain programs. Stock Zig 0.16 is sufficient for host-side unit tests.

[fork]: https://github.com/joncinque/solana-zig-bootstrap/releases/tag/solana-v1.53.0

## Quick start

```console
# Download solana-zig fork (Linux x86_64)
curl -LO https://github.com/joncinque/solana-zig-bootstrap/releases/download/solana-v1.53.0/zig-x86_64-linux-musl.tar.bz2
tar -xjf zig-x86_64-linux-musl.tar.bz2
export SOLANA_ZIG="$(pwd)/zig-x86_64-linux-musl-baseline/zig"

# Run tests
"$SOLANA_ZIG" build test --summary all
./program-test/test.sh "$SOLANA_ZIG"
```

## Writing a program

**推荐使用 lazy entrypoint**（与 Pinocchio `entrypoint!` 行为一致，零拷贝、最优 CU）：

```zig
const sol = @import("solana_program_sdk");

fn processInstruction(context: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const payer = context.nextAccount() orelse return error.NotEnoughAccountKeys;
    const account = context.nextAccount() orelse return error.NotEnoughAccountKeys;
    const data = context.instructionData();
    // ...
}

export fn entrypoint(input: [*]u8) u64 {
    return @call(.always_inline, sol.entrypoint.lazyEntrypoint(processInstruction), .{input});
}
```

**兼容模式**（eager entrypoint，预解析所有 accounts）：

```zig
fn processInstruction(
    program_id: *const sol.Pubkey,
    accounts: []sol.AccountInfo,
    instruction_data: []const u8,
) sol.ProgramResult {
    // ...
}

export fn entrypoint(input: [*]u8) u64 {
    return @call(.always_inline, sol.entrypoint.entrypoint(10, processInstruction), .{input});
}
```

## Comptime Safety Levels

The SDK provides compile-time selectable safety levels for zero-cost
abstractions:

```zig
// Safe: full bounds checking (default)
const account = context.nextAccountEx(.safe);

// Fast: skip bounds check, keep duplicate resolution
const account = context.nextAccountEx(.fast);

// Unchecked: no checks (max performance, caller guarantees correctness)
const account = context.nextAccountEx(.unchecked);
```

**Performance comparison** (pubkey comparison benchmark):

| Safety Level | CU | Binary Size |
|-------------|-----|-------------|
| `.safe` | 35 | 2512 bytes |
| `.fast` | 33 | 2424 bytes |
| `.unchecked` | 26 | 1592 bytes |

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

Run with the solana-zig fork:

```console
"$SOLANA_ZIG" build
```

One step. The SDK sets `sbf_target`, installs the bpf.ld linker script, and
writes `zig-out/lib/my_program.so`.

## Prerequisites

### solana-zig fork (required for on-chain program builds)

Download from [GitHub Releases](https://github.com/joncinque/solana-zig-bootstrap/releases/tag/solana-v1.53.0):

```console
# Linux x86_64
curl -LO https://github.com/joncinque/solana-zig-bootstrap/releases/download/solana-v1.53.0/zig-x86_64-linux-musl.tar.bz2
tar -xjf zig-x86_64-linux-musl.tar.bz2
export SOLANA_ZIG="$(pwd)/zig-x86_64-linux-musl-baseline/zig"
```

Other platforms: see the release page for `zig-aarch64-linux-musl`,
`zig-x86_64-macos-none`, etc.

### Stock Zig 0.16 (host unit tests only)

```console
zig version
# -> 0.16.x
```

## Unit tests

Stock Zig is fine for host-side tests:

```console
zig build test --summary all
```

## Integration tests

```console
./program-test/test.sh "$SOLANA_ZIG"
```

## Branch layout

- `main` — original upstream solana-zig based SDK (legacy reference).
- **`solana-zig-fork-0.16`** (this branch) — solana-zig fork only, recommended default.
