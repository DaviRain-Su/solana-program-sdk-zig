# spl-name-service

Allocation-free helpers for the SPL Name Service program.

The package mirrors the stable `spl-name-service = 0.3.1` instruction
and account-header layouts while staying usable from on-chain code:
dynamic instruction payloads are written into caller-owned buffers, and
PDA derivation accepts caller-owned seed scratch.

## Scope

- Program ID and name-record header constants.
- Name hash helper for `SHA256("SPL Name Service" || name)`.
- Name account PDA derivation with class and parent seeds.
- Borsh-compatible create, update, transfer, delete, and realloc
  instruction data writers.
- Instruction builders using `sol.cpi.Instruction` and `AccountMeta`.
- Rust parity fixtures pinned to `spl-name-service = 0.3.1`.

RPC lookups, reverse registry conventions, and UI/domain-specific record
schemas are intentionally out of scope.
