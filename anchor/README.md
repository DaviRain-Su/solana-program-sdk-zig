# sol-anchor-zig

Anchor-like framework for Solana program development in Zig.

This package is extracted from `solana_program_sdk` and lives as a subpackage in the same repository. It depends on `solana_program_sdk` via a path dependency.

## Usage

```zig
const anchor = @import("sol_anchor_zig");
const sol = anchor.sdk;

const CounterData = struct {
    count: u64,
    authority: sol.PublicKey,
};

const Counter = anchor.Account(CounterData, .{
    .discriminator = anchor.accountDiscriminator("Counter"),
});
```

## IDL + Zig Client

```zig
const anchor = @import("sol_anchor_zig");
const sol = anchor.sdk;

const MyProgram = struct {
    pub const id = sol.PublicKey.comptimeFromBase58("11111111111111111111111111111111");

    pub const instructions = struct {
        pub const initialize = anchor.Instruction(.{
            .Accounts = InitializeAccounts,
            .Args = InitializeArgs,
        });
    };
};

const idl_json = try anchor.generateIdlJson(allocator, MyProgram, .{});
const client_src = try anchor.generateZigClient(allocator, MyProgram, .{});
```

## Build & Test

```bash
cd anchor
../solana-zig/zig build test --summary all
```
