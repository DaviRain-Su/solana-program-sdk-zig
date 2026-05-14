# solana-codec

Shared Solana byte-codec primitives for Zig packages.

This package is intentionally small and allocation-free. It provides the
wire formats that appear across Solana programs and client packages, so
SPL packages and off-chain builders can share one tested implementation.

## Scope

- Solana shortvec length encoding and decoding
- Borsh primitive/string/byte-vector helpers
- Bincode-style `COption<Pubkey>` and `COption<u64>` helpers

It does not attempt to be a full reflection-based serializer. Callers
compose these primitives into explicit instruction and account layouts.
