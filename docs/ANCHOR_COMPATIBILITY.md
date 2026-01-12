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

## Not Implemented Yet

- IDL generation
- Client code generation
- Account macro-style derives (Zig uses comptime helpers instead)

## Compatibility Table

| Feature | Anchor (Rust) | sol-anchor-zig | Status |
|---|---|---|---|
| Discriminators | `#[account]` / `#[instruction]` | `accountDiscriminator`, `instructionDiscriminator` | ✅ |
| Account wrapper | `Account<T>` | `anchor.Account(T, config)` | ✅ |
| Context | `Context<T>` | `anchor.Context(T)` | ✅ |
| Constraints | `#[account(mut, signer, ...)]` | `constraints.zig` | ✅ |
| PDA helpers | `Pubkey::find_program_address` | `anchor.pda` helpers | ✅ |
| Init/close/realloc | `#[account(init/close/realloc)]` | `init.zig`, `close.zig`, `realloc.zig` | ✅ |
| IDL | `anchor idl` | Not available | ⏳ |
| Client codegen | `anchor client` | Not available | ⏳ |

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

## Related

- `anchor/src/root.zig`
- `anchor/src/error.zig`
- [Error Handling](ERROR_HANDLING.md)
