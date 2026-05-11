# hello-world template

A minimal Solana Zig starter supporting both **solana-zig fork** (best CU)
and **stock Zig + elf2sbpf** (fallback) build paths.

## Quick start

```bash
./scripts/bootstrap.sh
zig build test --summary all
./program-test/test.sh
```

Then edit:

- `src/main.zig`

## Build the program

### With solana-zig fork (recommended, best CU)

```bash
# Download prebuilt binary from https://github.com/joncinque/solana-zig-bootstrap/releases
export SOLANA_ZIG_BIN=/path/to/solana-zig-bootstrap/zig
"$SOLANA_ZIG_BIN" build -Dsolana-zig
```

### With stock Zig (fallback)

```bash
zig build
```

## Run integration tests

```bash
# Auto-detects solana-zig fork
./program-test/test.sh

# Or specify a Zig binary explicitly
./program-test/test.sh /path/to/solana-zig
./program-test/test.sh /usr/bin/zig  # force stock Zig path
```
