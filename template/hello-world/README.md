# hello-world template

A minimal Solana Zig starter with host-side tests plus a verified
`solana-zig` path for building and validating SBF artifacts.

## Quick start

```bash
./scripts/bootstrap.sh
zig build test --summary all
./program-test/test.sh
```

Then edit:

- `src/main.zig`

## Build the program

### With a verified solana-zig fork (required for SBF builds)

```bash
# Download prebuilt binary from https://github.com/joncinque/solana-zig-bootstrap/releases
export SOLANA_ZIG_BIN=/path/to/solana-zig-bootstrap/zig
"$SOLANA_ZIG_BIN" build -Dbuild-program
```

### Host tests only (stock Zig 0.16 is fine)

```bash
zig build test --summary all
```

## Run integration tests

```bash
# Auto-detects a verified solana-zig fork
./program-test/test.sh

# Or specify a Zig binary explicitly
./program-test/test.sh /path/to/solana-zig
```
