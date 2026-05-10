# solana-program-sdk-zig

Write Solana on-chain programs in Zig.

This branch (`solana-zig-fork-0.16`) supports **two build paths** so one
SDK serves both audiences:

| Path | Compiler | Linker | CU | Install size |
|------|----------|--------|-----|--------------|
| **Primary** — `buildProgram` | [solana-zig fork][fork] (Zig 0.16) | built-in `lld` | best (matches `solana-zig` baseline) | ~200 MB |
| **Fallback** — `buildProgramElf2sbpf` | stock Zig 0.16 | [`elf2sbpf`][elf2sbpf] | worse than baseline (no CU optimizer) | stock Zig + ~2 MB |

[fork]: https://github.com/joncinque/solana-zig-bootstrap/releases/tag/solana-v1.53.0
[elf2sbpf]: https://github.com/DaviRain-Su/elf2sbpf

Which to pick:

- **have solana-zig fork installed** → use `buildProgram` (fork path) — one
  call, direct `.so`, optimal CU.
- **only have stock Zig** → use `buildProgramElf2sbpf` — slightly more CU,
  zero extra dependencies beyond the `elf2sbpf` binary.

## Quick start

```console
./scripts/bootstrap.sh
zig build test --summary all
./program-test/test.sh
```

`bootstrap.sh` detects both toolchains and prints the environment variables
to export:

```text
export SOLANA_ZIG_BIN=/path/to/solana-zig-bootstrap/out-smoke/host/bin/zig
export ELF2SBPF_BIN=/path/to/elf2sbpf
```

## Using the SDK from your `build.zig`

### Primary path (fork Zig, best CU)

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

Run with the fork Zig:

```console
"$SOLANA_ZIG_BIN" build
```

One step. The SDK sets `sbf_target`, installs the bpf.ld linker script, and
writes `zig-out/lib/my_program.so`.

### Fallback path (stock Zig + elf2sbpf)

```zig
const std = @import("std");
const solana = @import("solana_program_sdk");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(solana.bpf_target);
    const optimize = .ReleaseFast;
    const elf2sbpf_bin = b.option(
        []const u8,
        "elf2sbpf-bin",
        "Path to the elf2sbpf executable",
    );

    _ = solana.buildProgramElf2sbpf(b, .{
        .name = "my_program",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .elf2sbpf_bin = elf2sbpf_bin,
    });
}
```

Run with stock Zig:

```console
zig build  # elf2sbpf auto-resolved from ELF2SBPF_BIN / .tools / PATH
```

For CU-optimal Zig programs, use the solana-zig fork path (primary)
instead — the elf2sbpf fallback path is for users who can't install
the fork. A `--peephole` rewriter existed in earlier elf2sbpf
versions but was rolled back 2026-04-19 (miscompile on escrow-class
programs).

## Prerequisites

### Stock Zig 0.16 (host tests + fallback program builds)

```console
zig version
# -> 0.16.x
```

### solana-zig fork (primary program builds)

#### Option 1: Download prebuilt binary (recommended)

Download from [GitHub Releases](https://github.com/joncinque/solana-zig-bootstrap/releases/tag/solana-v1.53.0):

```console
# Linux x86_64
curl -LO https://github.com/joncinque/solana-zig-bootstrap/releases/download/solana-v1.53.0/zig-x86_64-linux-musl.tar.bz2
tar -xjf zig-x86_64-linux-musl.tar.bz2
export SOLANA_ZIG_BIN="$(pwd)/zig-x86_64-linux-musl-baseline/zig"
```

Other platforms: see the release page for `zig-aarch64-linux-musl`,
`zig-x86_64-macos-none`, etc.

#### Option 2: Build from source

```console
git clone -b solana-1.52 \
  https://github.com/joncinque/solana-zig-bootstrap \
  ../solana-zig-bootstrap
cd ../solana-zig-bootstrap
git submodule update --init --recursive
./build native-linux-musl baseline   # or native-macos-none baseline
```

When done:

```console
export SOLANA_ZIG_BIN=$(pwd)/out-smoke/host/bin/zig
```

`bootstrap.sh` in this repo also auto-detects a sibling `../solana-zig-bootstrap`
checkout.

## Exported targets

- `sbf_target` — `.cpu_arch = .sbf`, `.os_tag = .solana`, `.cpu_model = v2`.
  Only recognized by the fork Zig.
- `bpf_target` — `.cpu_arch = .bpfel`, `.os_tag = .freestanding`, `.cpu_model = v2`.
  Works on stock Zig (kernel-BPF-flavored output, then run through `elf2sbpf`).

## Unit tests

Stock Zig is fine:

```console
zig build test --summary all
```

## Integration tests

```console
./program-test/test.sh
```

The test script auto-detects the solana-zig fork and uses the optimal
`buildProgram` path when available. Pass a specific Zig binary as the
first argument if needed:

```console
./program-test/test.sh /path/to/solana-zig
./program-test/test.sh /usr/bin/zig        # force stock Zig path
```

## Branch layout

- `main` — original upstream solana-zig based SDK (legacy reference).
- `dev` / `elf2sbpf-from-4589040` — stock Zig + elf2sbpf only (simpler, narrower
  scope).
- **`solana-zig-fork-0.16`** (this branch) — dual path, recommended default.
