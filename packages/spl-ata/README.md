# spl-ata (Zig)

Status: ✅ **v0.1** — released.

Zig client for the [SPL Associated Token Account](https://github.com/solana-program/associated-token-account)
program. Dual-target (on-chain CPI + off-chain ix builder), mirroring
the Rust [`spl-associated-token-account`](https://docs.rs/spl-associated-token-account)
crate.

## API

```zig
const spl_ata = @import("spl_ata");

// PDA derivation for classic SPL Token or Token-2022:
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
    .token_program = token_program_id,
});
```

## Implemented scope

- ATA PDA derivation for both classic SPL Token and Token-2022.
- `create` / `createIdempotent` instruction builders.
- On-chain CPI wrappers for ATA creation.
- Real Mollusk integration coverage via `program-test/tests/spl_ata.rs`.
