# Compute Budget Guide

Use the Compute Budget program to control compute limits, priority fees, and heap size.

## Module

```zig
const compute_budget = @import("solana_program_sdk").compute_budget;
```

Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/compute-budget-interface/src/lib.rs

## Key Constants

- `MAX_COMPUTE_UNIT_LIMIT` (1,400,000)
- `DEFAULT_INSTRUCTION_COMPUTE_UNIT_LIMIT` (200,000)
- `MAX_HEAP_FRAME_BYTES` (256 KB)
- `MIN_HEAP_FRAME_BYTES` (32 KB)
- `MAX_LOADED_ACCOUNTS_DATA_SIZE_BYTES` (64 MB)
- `MICRO_LAMPORTS_PER_LAMPORT` (1,000,000)

## Instruction Builders

### Set Compute Unit Limit

```zig
const limit_ix = compute_budget.setComputeUnitLimitInstruction(400_000);
const ix = limit_ix.toInstruction();
```

### Set Compute Unit Price (Priority Fee)

```zig
const price_ix = compute_budget.setComputeUnitPriceInstruction(1_000);
const ix = price_ix.toInstruction();
```

Priority fee formula:

```
fee_lamports = (micro_lamports * compute_units) / 1_000_000
```

### Request Heap Frame

```zig
const heap_ix = compute_budget.requestHeapFrameInstruction(64 * 1024);
const ix = heap_ix.toInstruction();
```

### Set Loaded Accounts Data Size Limit

```zig
const limit_ix = compute_budget.setLoadedAccountsDataSizeLimitInstruction(10 * 1024 * 1024);
const ix = limit_ix.toInstruction();
```

## Transaction Example

```zig
const sdk = @import("solana_program_sdk");
const compute_budget = sdk.compute_budget;

// Add compute budget instructions first
const limit_ix = compute_budget.setComputeUnitLimitInstruction(300_000);
const price_ix = compute_budget.setComputeUnitPriceInstruction(500);

try tx_builder.addInstruction(limit_ix.toInstruction());
try tx_builder.addInstruction(price_ix.toInstruction());
try tx_builder.addInstruction(program_ix);
```

## Notes

- Heap frame requests must be a multiple of 1024 bytes.
- Compute budget instructions should be placed first in the transaction.
- Use `setComputeUnitLimitInstruction` to avoid the default 200k limit.

## Related

- `src/compute_budget.zig`
- [Testing Guide](TESTING.md)
- [Deployment Guide](DEPLOYMENT.md)
