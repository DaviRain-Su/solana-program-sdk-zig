# spl-token (Zig)

Status: 🚧 **planned** — not yet implemented.

Zig client for the [SPL Token](https://github.com/solana-program/token)
program. Dual-target:

- **on-chain**: CPI helpers (`spl_token.cpi.transfer(...)`)
- **off-chain**: instruction builders (`spl_token.instruction.transfer(...)`)
  returning `sol.cpi.Instruction` byte buffers ready to embed in a
  host-built transaction.

Mirrors the Rust [`spl-token`](https://docs.rs/spl-token) crate's
public surface.

## Planned API

```zig
const spl_token = @import("spl_token");

// On-chain (in your program's `process` function):
try spl_token.cpi.transfer(.{
    .source = a, .destination = b, .authority = auth,
    .amount = 100, .token_program = tp,
});

// Off-chain (host code constructing a transaction):
const ix = spl_token.instruction.transfer(.{
    .source = a_pubkey, .destination = b_pubkey,
    .authority = auth_pubkey, .amount = 100,
});
```

## First-pass scope

Only the most-used fungible-token instructions:

- `initializeMint`
- `initializeAccount`
- `transfer` / `transferChecked`
- `mintTo` / `mintToChecked`
- `burn` / `burnChecked`
- `approve` / `revoke`
- `closeAccount`

Plus the `Mint` (82 B) and `Account` (165 B) state structs as
zero-copy `extern struct`s.

Token-2022 extensions go in a separate package
(`packages/spl-token-2022`) when added.
