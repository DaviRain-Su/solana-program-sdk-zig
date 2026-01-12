# Testing Guide

This guide summarizes testing layers and commands in this repository.

## Test Layers

1. **SDK unit tests** (`sdk/`) — core types, serialization
2. **Program SDK tests** (`src/`) — syscall stubs and on-chain helpers
3. **Client SDK tests** (`client/`) — RPC and transaction utilities
4. **Integration tests** (`program-test/`, `client/integration/`)
5. **Anchor tests** (`anchor/`)

## Run Tests

### Program SDK

```bash
./solana-zig/zig build test --summary all
```

### SDK Only

```bash
cd sdk
../solana-zig/zig build test --summary all
```

### Client SDK

```bash
cd client
../solana-zig/zig build test --summary all
```

### Client Integration (requires validator)

```bash
# Option A: surfpool (CI uses this)
surfpool start --no-tui &

# Option B: solana-test-validator
solana-test-validator &

cd client
../solana-zig/zig build integration-test --summary all
```

### Program Integration

```bash
./program-test/test.sh
```

### Anchor

```bash
cd anchor
../solana-zig/zig build test --summary all
```

### Examples

```bash
cd examples/programs
../../solana-zig/zig build
```

## CI Summary

- **Format**: `./solana-zig/zig fmt --check` for `sdk/src`, `src`, `client/src`, `examples/programs`
- **SDK**: `cd sdk && ../solana-zig/zig build test --summary all`
- **Client**: `cd client && ../solana-zig/zig build test --summary all`
- **Program SDK**: `./solana-zig/zig build test --summary all`
- **Integration**: `./program-test/test.sh`
- **Examples**: `cd examples/programs && ../../solana-zig/zig build`
- **Anchor**: `cd anchor && ../solana-zig/zig build test --summary all`

## Notes

- Always use `./solana-zig/zig` instead of system Zig.
- Some tests require a local validator (see Client Integration).
