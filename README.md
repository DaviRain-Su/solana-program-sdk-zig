# solana-program-sdk-zig

Write Solana on-chain programs in Zig.

This branch (`solana-zig-fork-0.16`) supports **two build paths** so one
SDK serves both audiences:

| Path | Compiler | Linker | CU | Install size |
|------|----------|--------|-----|--------------|
| **Primary** — `buildProgram` | [solana-zig fork][fork] (Zig 0.16-dev) | built-in `lld` | best (matches `solana-zig` baseline) | ~200 MB |
| **Fallback** — `buildProgramElf2sbpf` | stock Zig 0.16 | [`elf2sbpf`][elf2sbpf] | ~80–95 % of baseline with `--peephole` | stock Zig + ~2 MB |

[fork]: https://github.com/DaviRain-Su/solana-zig-bootstrap/tree/solana-1.52-zig0.16
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

If you want the D.7.10 peephole pass (closes most of the CU gap), point
`ELF2SBPF_BIN` at a wrapper that passes `--peephole`:

```console
cat > elf2sbpf-peephole <<'EOF'
#!/usr/bin/env bash
exec /path/to/elf2sbpf --peephole "$@"
EOF
chmod +x elf2sbpf-peephole
export ELF2SBPF_BIN=$PWD/elf2sbpf-peephole
```

## Prerequisites

### Stock Zig 0.16 (host tests + fallback program builds)

```console
zig version
# -> 0.16.x
```

### solana-zig fork (primary program builds)

Clone & build:

```console
git clone -b solana-1.52-zig0.16 \
  https://github.com/DaviRain-Su/solana-zig-bootstrap \
  ../solana-zig-bootstrap
cd ../solana-zig-bootstrap
git submodule update --init --recursive
./build native-macos-none baseline   # or native-linux-musl baseline
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

See `program-test/test.sh` for CLI options.

## Branch layout

- `main` — original upstream solana-zig based SDK (legacy reference).
- `dev` / `elf2sbpf-from-4589040` — stock Zig + elf2sbpf only (simpler, narrower
  scope).
- **`solana-zig-fork-0.16`** (this branch) — dual path, recommended default.
