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

Runtime vote submission, vote-state updates, and tower sync builders are
intentionally left out of v0.1.
