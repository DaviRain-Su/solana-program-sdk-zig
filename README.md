# solana-program-sdk-zig

Write Solana on-chain programs in Zig.

This maintenance branch acts as a **starter template** for a stock Zig +
`elf2sbpf` Solana program workflow. The goal is to make first use easy:
bootstrap the toolchain, edit the sample program, build, and run tests.

## Quick start

```console
./scripts/bootstrap.sh
zig build test --summary all
./program-test/test.sh
```

What `bootstrap.sh` does:

- checks that Zig is available
- reuses `ELF2SBPF_BIN` if you already set it
- reuses a sibling `../elf2sbpf` checkout if present
- otherwise clones and builds `elf2sbpf` into `.tools/elf2sbpf/`

After that, you can start by editing:

- `program-test/pubkey/main.zig`

## What this branch gives you

- stock Zig 0.16.x workflow
- automatic `elf2sbpf` bootstrap for local development
- CI already wired for Zig + Rust + `elf2sbpf`
- a minimal starter program plus integration test harness

## Prerequisites

### Library / host tests

Use stock Zig:

```console
zig version
zig build test --summary all
```

### On-chain program builds

For program builds in this branch, the pipeline is:

1. stock Zig emits LLVM bitcode
2. `zig cc` produces a BPF ELF object
3. `elf2sbpf` converts that object into a deployable Solana `.so`

`elf2sbpf` is the required stage-2 linker/post-processor for this branch's
on-chain build path.

## Using this branch as a starter template

### Bootstrap tools

```console
./scripts/bootstrap.sh
```

This branch stores auto-prepared local tools under:

```text
.tools/elf2sbpf/
```

You can also override the binary explicitly with either:

```console
export ELF2SBPF_BIN=/absolute/path/to/elf2sbpf
```

or

```console
zig build -Delf2sbpf-bin=/absolute/path/to/elf2sbpf
```

### Edit the sample program

The starter program lives at:

```text
program-test/pubkey/main.zig
```

Current sample:

```zig
const sol = @import("solana_program_sdk");

export fn entrypoint(input: [*]u8) u64 {
    _ = sol.context.Context.load(input) catch return 1;
    sol.log.log("Hello zig program");
    return 0;
}
```

Replace the body with your own program logic as needed.

### Build the sample program

```console
cd program-test
zig build
```

If `ELF2SBPF_BIN` is unset, the build first looks in local `.tools/` and then on
`PATH`.

## Reusing the helper in your own project

The root `build.zig` exports `buildProgramElf2sbpf(...)` for consumers that want
to reuse the same stock Zig + `elf2sbpf` pipeline.

```zig
const std = @import("std");
const solana = @import("solana_program_sdk");

pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseFast;
    const target = b.resolveTargetQuery(solana.bpf_target);
    const elf2sbpf_bin = b.option(
        []const u8,
        "elf2sbpf-bin",
        "Path to the elf2sbpf executable",
    );

    _ = solana.buildProgramElf2sbpf(b, .{
        .name = "program_name",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .elf2sbpf_bin = elf2sbpf_bin,
    });
}
```

If `elf2sbpf_bin` is omitted, the helper resolves in this order:

1. `ELF2SBPF_BIN`
2. local `.tools/` install
3. `PATH`

## Build model on this branch

The maintained on-chain target is:

- `bpf_target` -> stock Zig BPF codegen + `elf2sbpf`

This branch documents and maintains only the stock Zig + `elf2sbpf` build path.

## Unit tests

Run all library tests with stock Zig:

```console
zig build test --summary all
```

## Integration tests

This repo includes `program-test/` integration tests that build a test program
and run it against the Agave runtime using the
[`solana-program-test` crate](https://crates.io/crates/solana-program-test).

Run them with:

```console
./program-test/test.sh
```

The script defaults to `zig` for the compiler, resolves `elf2sbpf`
automatically, and still accepts an explicit path when you want one:

```console
./program-test/test.sh zig /absolute/path/to/elf2sbpf
```
