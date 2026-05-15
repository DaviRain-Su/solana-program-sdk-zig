# solana-stake

Stake Program instruction builders.

This package exposes caller-buffer builders for common Stake Program
instructions. It uses the root `solana_program_sdk` core types and
shared `solana_codec` bincode primitives for seeded authority and
lockup payloads, returning `sol.cpi.Instruction` values that can be
used by host-side transaction tooling or on-chain CPI wrappers.

## Scope

- Initialize / InitializeChecked
- Authorize / AuthorizeChecked
- AuthorizeWithSeed / AuthorizeCheckedWithSeed
- SetLockup / SetLockupChecked
- Delegate, Split, Withdraw, Deactivate, Merge
- DeactivateDelinquent
- GetMinimumDelegation
- MoveStake / MoveLamports
