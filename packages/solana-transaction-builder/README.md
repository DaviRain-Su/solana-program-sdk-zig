# solana-transaction-builder

Host-side transaction assembly helpers.

This package composes `solana_tx`, `solana_keypair`,
`solana_address_lookup_table`, and selected shared instruction packages:
it compiles a legacy message from raw instructions, serializes the
message bytes, signs required signer slots in canonical account-key
order, and writes the final transaction bytes into caller-provided
buffers. It also compiles v0 messages with supplied lookup-table
accounts, selects eligible ALT addresses, signs, and serializes v0
transactions.
Remote lookup-table fetching stays in `solana_client.fetchAddressLookupTable`;
this package only accepts parsed `LookupTableCandidate` values.
It also provides small multi-instruction helpers for common transaction
preludes such as Compute Budget instructions plus a System transfer.

## Scope

- Legacy message compilation
- Required-signer lookup by public key
- Detached signing of canonical message bytes
- Legacy transaction serialization
- v0 message signing and transaction serialization
- v0 message compilation from raw instructions with supplied or client-fetched
  ALT accounts
- automatic ALT selection for non-signer, non-program accounts
- Durable nonce account create + initialize instruction-pair assembly
- Compute Budget prelude assembly
- Compute Budget + System transfer assembly

It does not fetch blockhashes, talk to RPC directly, or own wallet/key-storage
policy.
