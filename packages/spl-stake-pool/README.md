# spl-stake-pool

Allocation-free interface helpers for the SPL Stake Pool program.

The package mirrors a focused subset of `spl-stake-pool = 2.0.3`:
program IDs, stake-pool PDA helpers, validator-list parsing, and common
instruction builders. It intentionally exposes only raw instruction/state
boundaries and leaves transaction orchestration, stake-authorize prelude
instructions, RPC fetching, and CLI policy to higher-level packages.

## Scope

- Mainnet and devnet program IDs.
- Deposit, withdraw, validator, transient, and ephemeral PDA helpers.
- Fee, validator-list header, validator stake info, and stake-pool header
  parsers.
- Initialize, add/remove validator, update balance, cleanup, deposit SOL,
  withdraw SOL, withdraw stake, and final deposit-stake instruction builders.
- Rust parity fixtures pinned to `spl-stake-pool = 2.0.3`.
