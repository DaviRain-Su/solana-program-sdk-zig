# sol-anchor-zig

Anchor-like framework for Solana program development in Zig.

This package is extracted from `solana_program_sdk` and lives as a subpackage in the same repository. It depends on `solana_program_sdk` via a path dependency.

## Usage

```zig
const sol = @import("solana_program_sdk");
const anchor = @import("sol_anchor_zig");

const CounterData = struct {
    count: u64,
    authority: sol.PublicKey,
};

const Counter = anchor.Account(CounterData, .{
    .discriminator = anchor.accountDiscriminator("Counter"),
});
```

## Build & Test

```bash
cd anchor
../solana-zig/zig build test --summary all
```
