# spl-ata (Zig)

Status: 🚧 **planned** — not yet implemented.

Zig client for the [SPL Associated Token Account](https://github.com/solana-program/associated-token-account)
program. Dual-target (on-chain CPI + off-chain ix builder), mirroring
the Rust [`spl-associated-token-account`](https://docs.rs/spl-associated-token-account)
crate.

## Planned API

```zig
const spl_ata = @import("spl_ata");

// PDA derivation — comptime when wallet & mint are comptime-known,
// runtime otherwise:
const ata = spl_ata.findAddress(&wallet, &mint, &token_program_id);

// On-chain: create the ATA via CPI
try spl_ata.cpi.createIdempotent(.{
    .payer = payer,
    .ata = ata_account,
    .wallet = wallet,
    .mint = mint,
    .system_program = sp,
    .token_program = tp,
});

// Off-chain: build the ix bytes
const ix = spl_ata.instruction.createIdempotent(.{
    .payer = payer_pubkey,
    .wallet = wallet_pubkey,
    .mint = mint_pubkey,
});
```

## First-pass scope

- `findAddress` — PDA derivation (comptime + runtime variants)
- `createAssociatedTokenAccount`
- `createIdempotent` (recommended over the non-idempotent form)
