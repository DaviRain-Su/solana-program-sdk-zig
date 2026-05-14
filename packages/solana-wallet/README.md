# solana-wallet

Host-side wallet/keypair helpers for Zig.

This v0.1 package handles the Solana CLI keypair JSON shape:

```json
[12,34, ... 64 total bytes ...]
```

It also exposes BIP39 seed derivation, caller-supplied wordlist checksum
validation, Solana hardened derivation-path handling, SLIP-0010 Ed25519
derivation, a minimal wallet-adapter interface, and an encrypted-keystore
metadata envelope with concrete AEAD payload encryption helpers.

## Scope

- Parse a 64-byte Solana CLI secret-key JSON array
- Recover a `solana_keypair.Keypair` from that JSON
- Write a 64-byte secret key back to canonical compact JSON
- Derive a BIP39 seed with PBKDF2-HMAC-SHA512
- Recover entropy from a BIP39 mnemonic and validate checksum bits through a
  caller-supplied `WordlistResolver`
- Parse/write hardened Solana derivation paths such as `m/44'/501'/0'/0'`
- Derive Solana Ed25519 keypairs from mnemonic seed material using
  SLIP-0010 hardened children
- Sign through a caller-owned `WalletAdapter`
- Parse, validate, and write encrypted-keystore metadata envelopes
- Encrypt/decrypt keystore payloads with XChaCha20-Poly1305 or AES-256-GCM
- Derive keystore keys with scrypt or PBKDF2-HMAC-SHA256

The package does not embed the 2048-word BIP39 English wordlist.
