# solana-keypair (Zig)

Status: 🚧 **v0.1 signing foundation** — deterministic Ed25519 keypair
recovery from 32-byte seeds, public-key export, and detached message
signing.

This is a host-only package that complements `solana_tx`. It does not
parse wallet files, fetch blockhashes, or send transactions.

## Scope (v0.1)

- derive an Ed25519 keypair from a 32-byte seed
- recover a keypair from Solana-style 64-byte `seed || pubkey` bytes
- export the 32-byte public key as `solana_program_sdk.Pubkey`
- sign arbitrary message bytes
- verify detached signatures

## Not in scope

- filesystem keypair JSON
- mnemonic derivation
- hardware wallets
- RPC send/confirm
- transaction object assembly

## Example

```zig
const solana_keypair = @import("solana_keypair");

const kp = try solana_keypair.Keypair.fromSeed(seed);
const pubkey = kp.publicKey();
const signature = try kp.sign(message_bytes);
try solana_keypair.verify(signature, message_bytes, &pubkey);
```
