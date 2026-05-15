# solana-compute-budget

Allocation-free builders for Solana Compute Budget instructions.

This package produces `sol.cpi.Instruction` values that can be inserted
into off-chain transactions or invoked through the same byte-level
instruction surface used by the rest of the monorepo.

## Scope

- `requestHeapFrame`
- `setComputeUnitLimit`
- `setComputeUnitPrice`
- `setLoadedAccountsDataSizeLimit`

The package does not simulate, estimate, or choose fee policy for the
caller.
