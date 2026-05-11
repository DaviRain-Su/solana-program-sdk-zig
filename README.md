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

Benchmarked via [solana-program-rosetta](https://github.com/nickfrosty/solana-program-rosetta).
CU = Compute Units. **Lower is better.**

| Benchmark | Rust | Pinocchio | Zig (upstream SDK) | **Zig (this SDK)** |
|---|---:|---:|---:|---:|
| helloworld | 105 | — | 105 | **105** |
| pubkey | 14 | — | 15 | **21** |
| transfer-lamports | 493 | 27 | 37 | **24** |
| cpi | 3753 | 2771 | **2958** | — |

Key results:
- **Transfer: 24 CU** — beats Pinocchio (27 CU) by 11%, beats Rust (493 CU) by 20×
- **Helloworld: 105 CU** — identical across all languages (syscall-bound)
- **CPI: 2958 CU** — 21% faster than Rust (3753 CU)

> **Note:** The pubkey benchmark is higher (21 vs 14) because the SDK version
> uses `lazyEntrypoint` with error union (5 CU overhead). Using `lazyEntrypointRaw`
> or hand-written entrypoint brings it to 15 CU (matching upstream Zig).

### In-repo benchmark (`solana-program-test` 2.3.13)

Local apples-to-apples comparison of `lazyEntrypoint` vs `lazyEntrypointRaw`
(same program logic, only the entrypoint wrapper differs):

| Program | `lazyEntrypoint` (ProgramResult) | `lazyEntrypointRaw` (u64) | Δ |
|---|---:|---:|---:|
| pubkey_cmp_safe (byte-by-byte) | 22 CU | 18 CU | −4 |
| pubkey_cmp_unchecked (aligned u64) | — | **18 CU** | — |
| pubkey_cmp_comptime (`pubkeyEqComptime`) | 26 CU | — | — |
| transfer_lamports | 27 CU | **22 CU** | −5 |

The error-union wrapper costs ~3–5 CU. Reproduce with:

### Compile-time PDA derivation

When all seeds and the program id are known at compile time, the SDK
computes the PDA at build time and emits two plain constants — no
`sol_try_find_program_address` syscall is needed:

```zig
const VAULT = sol.pda.comptimeFindProgramAddress(
    .{ "vault" },
    MY_PROGRAM_ID,
);
// VAULT.address and VAULT.bump_seed are baked into the binary.
```

| Program | CU |
|---|---:|
| `pda_runtime` (`findProgramAddress` syscall) | 3025 |
| `pda_comptime` (`comptimeFindProgramAddress`) | **9** |

That is a ~3000 CU per-call saving for static PDAs (singletons, vaults,
treasuries, well-known sysvar accounts, etc.).

There's also a companion `pda.comptimeCreateWithSeed(base, "seed", program_id)`
for the no-bump-search `create_account_with_seed` case.

### Declarative account parsing

`ctx.parseAccounts(.{ "from", "to", "system_program" })` returns a
named struct with one `AccountInfo` per requested account, with the
loop fully unrolled at compile time:

```zig
const accs = try ctx.parseAccounts(.{ "from", "to", "system_program" });
try sol.system.transfer(accs.from.toCpiInfo(), accs.to.toCpiInfo(),
                        accs.system_program.toCpiInfo(), amount);
```

Zero runtime overhead vs. hand-written `nextAccount() orelse …`.

### Reproduce

```console
cd benchmark
$SOLANA_ZIG build
cargo run --release -- transfer_lamports_raw
```

## Architecture

### Core types

| Type | Size | Purpose |
|---|---|---|
| `InstructionContext` | 16 B | Entrypoint context — on-demand account parsing |
| `AccountInfo` | 8 B | Account wrapper — single pointer, Pinocchio-style |
| `CpiAccountInfo` | 72 B | C-ABI-compatible view for CPI calls |
| `MaybeAccount` | 8+ B | Result of `nextAccount()` |

### Entrypoints

| Function | Returns | CU overhead | Use case |
|---|---|---|---|
| `lazyEntrypointRaw` | `u64` | 0 | Maximum performance |
| `lazyEntrypoint` | `ProgramResult` | +5 | Ergonomic error handling |

## Usage

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

### AccountInfo accessors

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

### CPI calls

Convert `AccountInfo` to `CpiAccountInfo` for CPI:

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

- **`main`** (default) — solana-zig fork based SDK with the Pinocchio-style
  redesign (current development line).
- `solana-zig-fork-0.16` — historical staging branch for the rewrite; now
  merged into `main` and kept for reference.
