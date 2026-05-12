# spl-memo (Zig)

Status: 🚧 **planned** — not yet implemented.

Zig client for the [SPL Memo](https://github.com/solana-program/memo)
program. Dual-target (on-chain CPI + off-chain ix builder), mirroring
the Rust [`spl-memo`](https://docs.rs/spl-memo) crate.

The simplest of the SPL programs — used as the reference skeleton for
new sub-packages.

## Planned API

```zig
const spl_memo = @import("spl_memo");

// On-chain CPI — `signers` is the list of accounts that must
// co-sign the memo (can be empty for a simple log).
try spl_memo.cpi.memo("hello on-chain", &.{});

// Off-chain ix:
const ix = spl_memo.instruction.memo("hello off-chain", &.{signer_pubkey});
```

## Scope

- `memo(message, signers)` — the program's single instruction.
