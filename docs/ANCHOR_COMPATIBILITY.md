# Anchor Compatibility Guide

This document summarizes Anchor feature coverage in `sol-anchor-zig`.

## Module

```zig
const anchor = @import("sol_anchor_zig");
const sol = anchor.sdk;
```

## Implemented Features

- Discriminator helpers (`accountDiscriminator`, `instructionDiscriminator`)
- Account wrapper (`anchor.Account`)
- Context (`anchor.Context`)
- Constraints (`constraints.zig`)
- PDA helpers (`pda.zig`, `seeds.zig`)
- Init/close/realloc helpers (`init.zig`, `close.zig`, `realloc.zig`)
- Anchor error codes (`AnchorError`)
- AccountsDerive auto inference for token/mint/ata shapes and common program aliases
- AccountsDerive auto binding for compute budget/address lookup table/vote/ed25519/secp256 programs
- AccountsDerive auto binding for Program fields by alias name
- Runtime validation for token/mint constraints (token account + mint state checks, program owner validation)
- Runtime validation for associated token constraints (ATA address + owner checks)

## Not Implemented Yet

- Full Rust macro parsing parity for `#[account(...)]`/`#[derive(Accounts)]` (typed DSL only; no string parser)

## Compatibility Table

| Feature | Anchor (Rust) | sol-anchor-zig | Status |
|---|---|---|---|
| Discriminators | `#[account]` / `#[instruction]` | `accountDiscriminator`, `instructionDiscriminator` | ✅ |
| Account wrapper | `Account<T>` | `anchor.Account(T, config)` | ✅ |
| Context | `Context<T>` | `anchor.Context(T)` | ✅ |
| Constraints | `#[account(mut, signer, ...)]` | `constraints.zig` | ✅ |
| PDA helpers | `Pubkey::find_program_address` | `anchor.pda` helpers | ✅ |
| Init/close/realloc | `#[account(init/init_if_needed/close/realloc)]` | `init.zig`, `close.zig`, `realloc.zig` | ✅ |
| IDL | `anchor idl` | `anchor.generateIdlJson` (events/constants/metadata, constraint hints) | ✅ |
| Client codegen | `anchor client` | `anchor.generateZigClient` | ✅ |
| IDL file output | `anchor idl --out` | `anchor.idl.writeJsonFile` / `zig build idl` (root or `anchor/`) | ✅ |
| RPC client wrapper | `AnchorClient` | `ProgramClient` (generated) | ✅ |
| Constraint expr | `constraint = <expr>` | `anchor.constraint()` | ✅ |
| Constraint runtime | `constraint = <expr>` | Runtime eval (==/!=, key(), field access) | ✅ |
| Rent exempt | `#[account(rent_exempt)]` | Runtime rent exemption check | ✅ |
| Zero/Space/Dup constraints | `#[account(zero/space/dup)]` | Zeroed discriminator check, exact space check, duplicate mutable account check | ✅ |
| Account attrs | `#[account(...)]` | `anchor.attr.*` + `.attrs` / `anchor.attr.account(...)` / `anchor.AccountField(...)` / `anchor.AccountsWith(...)` | ✅ |
| Token constraints | `token::mint/authority`, `associated_token::*` | `anchor.attr.tokenMint/tokenAuthority/associatedToken*` | ✅ |
| Accounts derive | `#[derive(Accounts)]` | `anchor.Accounts(T)` / `anchor.AccountsDerive(T)` | ✅ |
| Event derive | `#[event]` | `anchor.Event(T)` | ✅ |
| Event index | `#[index]` | `anchor.eventField(..., .{ .index = true })` (<=4, bool/fixed-size int/pubkey only) | ✅ |

## Example

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

const Accounts = struct {
    authority: anchor.Signer,
    counter: Counter,
};

fn increment(ctx: anchor.Context(Accounts)) !void {
    ctx.accounts.counter.data.count += 1;
}
```

## IDL + Client Codegen

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

Root `zig build idl` defaults to writing under `idl/` using the program metadata name (or program type name). Use `-Didl-output` to override the full output path, or `-Didl-output-dir` to change the directory.

## High-level Client

```zig
const client = @import("solana_client");
const RpcClient = client.RpcClient;

var rpc = RpcClient.init(allocator, "http://localhost:8899");
var program = ProgramClient.init(allocator, &rpc);

const sig = try program.sendInitialize(authority, payer, counter, args, &.{ &payer_kp, &authority_kp });
```

## Comptime Derives

```zig
const Accounts = anchor.Accounts(struct {
    authority: anchor.Signer,
    counter: anchor.Account(CounterData, .{
        .discriminator = anchor.accountDiscriminator("Counter"),
    }),
});

const CounterEvent = anchor.Event(struct {
    amount: u64,
    owner: sol.PublicKey,
});
```

## Related

- `anchor/src/root.zig`
- `anchor/src/error.zig`
- [Error Handling](ERROR_HANDLING.md)
