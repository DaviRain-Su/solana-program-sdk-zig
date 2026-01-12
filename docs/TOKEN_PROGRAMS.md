# Token Programs Guide

This guide covers SPL Token, Associated Token Accounts (ATA), and Token-2022 status.

## Modules

```zig
const sdk_token = @import("solana_sdk").spl.token;
const spl = @import("solana_client").spl;
```

Rust sources:
- https://github.com/solana-program/token
- https://github.com/solana-program/associated-token-account

## SPL Token (v2.0.0)

### State Types

```zig
const Mint = sdk_token.Mint;
const Account = sdk_token.Account;
const Multisig = sdk_token.Multisig;

// Sizes
const mint_size = Mint.SIZE;        // 82 bytes
const account_size = Account.SIZE;  // 165 bytes
const multisig_size = Multisig.SIZE; // 355 bytes
```

```zig
const mint = try Mint.unpackFromSlice(mint_data);
const account = try Account.unpackFromSlice(account_data);
```

### Instructions (Client)

```zig
const token_ix = spl.token;

const transfer_ix = token_ix.transfer(source, destination, owner, amount);
const mint_to_ix = token_ix.mintTo(mint, destination, authority, amount);
const burn_ix = token_ix.burn(source, mint, owner, amount);
```

## Associated Token Account (ATA)

```zig
const ata = spl.associated_token;

const result = ata.findAssociatedTokenAddress(wallet, mint);
const ata_address = result.address;

const create_ix = ata.createIdempotent(payer, wallet, mint);
```

## Token-2022 Status

Token-2022 extensions are **not implemented yet**. Current SDK support includes:

- SPL Token state types (`Mint`, `Account`, `Multisig`)
- ATA derivation and instruction builders

When working with Token-2022 accounts, you can still parse base fields:

```zig
// For token-2022 accounts with extensions
const mint = try sdk_token.Mint.unpackUnchecked(account_data);
```

Planned work (see ROADMAP v2.1.0):
- TLV extension parser
- Token-2022 instruction builders
- Extension types (transfer fee, metadata, interest bearing)

## Error Handling

```zig
const TokenError = @import("solana_sdk").spl.token.TokenError;

if (TokenError.fromCode(err_code)) |err| {
    std.debug.print("Token error: {s}\n", .{err.message()});
}
```

## Related

- `sdk/src/spl/token/state.zig`
- `sdk/src/spl/token/error.zig`
- `client/src/spl/associated_token.zig`
- [Error Handling](ERROR_HANDLING.md)
