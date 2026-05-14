# solana-config

Config Program instruction builders.

This package exposes caller-buffer builders for Config Program `store`
instructions plus typed views over stored ConfigKeys account data. It uses
`solana_program_sdk` core types and the shared `solana_codec` shortvec
encoder.

## Scope

- Config Program ID and key metadata encoding
- Raw `store` instruction builder
- Raw initialize-store helper for an empty key set
- Serialized-size helpers for caller buffer planning
- `ConfigStateView` parser for ConfigKeys plus caller-owned payload bytes

The caller owns serialization of the config-state payload. This package
appends and exposes the already-serialized state bytes after the canonical
ConfigKeys prefix.
