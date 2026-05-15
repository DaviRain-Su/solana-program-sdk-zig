# solana-tx (Zig)

Status: 🚧 **v0.1 transaction foundation** — host-side legacy message
compilation, legacy/v0 message serialization, address table lookup
serialization, and signed transaction byte serialization.

`solana_tx` is the first off-chain companion package for the monorepo.
It consumes `solana_program_sdk` instruction builders, including SPL
package builders that return `sol.cpi.Instruction`, and turns them into
canonical legacy and versioned Solana message bytes.

## Scope (v0.1)

- canonical account-key collection for legacy messages
- payer-first signer/writable ordering
- compiled instruction account-index resolution
- Solana shortvec length encoding through `solana-codec`
- allocation-free serialization into a caller-provided buffer
- legacy transaction byte serialization from caller-supplied signatures
- v0 message serialization with address table lookup records
- v0 transaction byte serialization from caller-supplied signatures

## Not in scope

- keypair generation or signing
- address lookup table account fetching or lookup resolution
- RPC, recent blockhash fetching, simulation, or send/confirm

## Example

```zig
const solana_tx = @import("solana_tx");

var keys: [8]solana_tx.Pubkey = undefined;
var compiled: [1]solana_tx.CompiledInstruction = undefined;
var ix_indices: [4]u8 = undefined;

const message = try solana_tx.compileLegacyMessage(
    &payer,
    &recent_blockhash,
    &.{memo_ix},
    &keys,
    &compiled,
    &ix_indices,
);

var out: [512]u8 = undefined;
const bytes = try solana_tx.serializeLegacyMessage(message, &out);

// After signing `bytes`, serialize the full transaction:
const tx_bytes = try solana_tx.serializeLegacyTransaction(&.{signature}, message, &out);

// For already-compiled v0 messages:
const lookup = solana_tx.MessageAddressTableLookup{
    .account_key = &address_lookup_table,
    .writable_indexes = &.{0},
    .readonly_indexes = &.{1, 2},
};
const v0_message = solana_tx.V0Message{
    .header = message.header,
    .account_keys = message.account_keys,
    .recent_blockhash = message.recent_blockhash,
    .instructions = message.instructions,
    .address_table_lookups = &.{lookup},
};
const v0_tx_bytes = try solana_tx.serializeV0Transaction(&.{signature}, v0_message, &out);
```
