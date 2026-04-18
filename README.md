# solana-program-sdk-zig

Write Solana on-chain programs in Zig.

This maintenance branch uses a **stock Zig + `elf2sbpf`** pipeline for on-chain
program builds instead of the old custom `solana-zig` compiler flow.

If you want a more complete example repo, see
[`solana-helloworld-zig`](https://github.com/joncinque/solana-helloworld-zig).

## Other Zig packages for Solana development

- [Base-58](https://github.com/joncinque/base58-zig)
- [Bincode](https://github.com/joncinque/bincode-zig)
- [Borsh](https://github.com/joncinque/borsh-zig)
- [Solana Program Library](https://github.com/joncinque/solana-program-library-zig)
- [Metaplex Token-Metadata](https://github.com/joncinque/mpl-token-metadata-zig)

## Prerequisites

### Library / host tests

Use stock Zig:

```console
zig version
zig build test --summary all
```

### On-chain program builds

For program builds in this branch, use:

1. stock Zig to emit LLVM bitcode
2. `zig cc` to produce a BPF ELF object
3. `elf2sbpf` to convert that object into a deployable Solana `.so`

Build `elf2sbpf` once and keep its path handy:

```console
cd ../elf2sbpf
zig build
```

The legacy `./install-solana-zig.sh` script is kept only as historical
compatibility tooling. It is **not** the primary path for this branch.

## How to use

### 1. Add this package to your project

```console
zig fetch --save https://github.com/joncinque/solana-program-sdk-zig/archive/refs/tags/v0.17.0.tar.gz
```

### 2. Use the `buildProgramElf2sbpf` helper in `build.zig`

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
    ) orelse "elf2sbpf";

    _ = solana.buildProgramElf2sbpf(b, .{
        .name = "program_name",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .elf2sbpf_bin = elf2sbpf_bin,
    });
}
```

### 3. Define your program entrypoint

```zig
const solana = @import("solana_program_sdk");

export fn entrypoint(_: [*]u8) callconv(.c) u64 {
    solana.print("Hello world!", .{});
    return 0;
}
```

### 4. Build a Solana `.so`

```console
zig build -Delf2sbpf-bin=/absolute/path/to/elf2sbpf --summary all
```

The generated program is installed to `zig-out/lib/<name>.so`.

## Build model on this branch

The maintained on-chain target is:

- `bpf_target` -> stock Zig BPF codegen + `elf2sbpf`

The previous custom `solana-zig` / direct-SBF flow is no longer the documented
build path for this branch.

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
cd program-test
./test.sh zig /absolute/path/to/elf2sbpf
```

The script defaults to `zig` for the compiler and also accepts the `ELF2SBPF_BIN`
environment variable if you prefer not to pass the path explicitly.
