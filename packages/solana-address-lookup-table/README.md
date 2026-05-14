# solana-address-lookup-table

Address Lookup Table account parsing, index resolution, and instruction builders.

This package handles the byte-level account state used by Solana v0
transactions. It parses the lookup table account header, exposes the
stored addresses, resolves writable/readonly indexes into caller-owned
buffers, creates `solana_tx.MessageAddressTableLookup` records, and builds
ALT management instructions.

## Scope

- Parse lookup table metadata from account data
- Expose address slices after the 56-byte metadata header
- Resolve writable and readonly index lists
- Build `solana_tx.MessageAddressTableLookup`
- Derive lookup table PDAs from authority + recent slot
- Build `createLookupTable`, `freezeLookupTable`, `extendLookupTable`,
  `deactivateLookupTable`, and `closeLookupTable` instructions
- Rust parity fixtures against `solana-address-lookup-table-interface = 2.2.2`

It does not fetch accounts from RPC or decide which accounts should be
loaded through lookup tables.
