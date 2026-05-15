# solana-vote

Vote Program instruction builders.

This package exposes caller-buffer builders for common vote-account
management instructions. It uses the root `solana_program_sdk` core
types and returns `sol.cpi.Instruction` values that can be used by
host-side transaction tooling or on-chain CPI wrappers.

## Scope

- InitializeAccount
- Authorize / AuthorizeChecked
- AuthorizeWithSeed / AuthorizeCheckedWithSeed
- UpdateValidatorIdentity
- UpdateCommission
- Withdraw
- Raw runtime vote / vote-switch builders for caller-serialized payloads
- Typed `Vote` / vote-switch payload encoders and builders
- Typed `VoteStateUpdate` encoders and builders for normal and compact update
  instructions
- Typed compact `TowerSync` encoders and builders

All runtime payload encoders are caller-buffer and allocation-free. The compact
vote-state and tower-sync encoders follow the upstream `solana-vote-interface`
serde layout: root slot, shortvec lockout offsets, bank hash, optional
timestamp, and tower block id where applicable.
