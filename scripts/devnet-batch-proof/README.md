# Devnet SPL Token batch proof

Minimal real-cluster proof for `spl_token` batch support.

## What it measures

One deployed Zig program compares five path families:

### 1. Plain `Transfer`

1. `double_transfer` — two normal SPL Token `Transfer` CPIs
2. `batch_transfer` — one `Batch` CPI built via `spl_token.cpi.batch(...)`
3. `batch_prepared_transfer` — one `Batch` CPI via `spl_token.cpi.batchPrepared(...)`

### 2. Plain `TransferChecked`

1. `double_transfer_checked` — two normal SPL Token `TransferChecked` CPIs
2. `batch_transfer_checked` — one `Batch` CPI built via `spl_token.cpi.batch(...)`
3. `batch_prepared_transfer_checked` — one `Batch` CPI via `spl_token.cpi.batchPrepared(...)`

### 3. Mixed signer `TransferChecked`

1. `double_mixed_transfer_checked` — one outer tx-signer `TransferChecked` plus one PDA-signed `TransferChecked`
2. `batch_mixed_transfer_checked` — same child operations inside one `Batch` CPI via `spl_token.cpi.batchSignedSingle(...)`
3. `batch_prepared_mixed_transfer_checked` — same mixed child operations via `spl_token.cpi.batchPreparedSignedSingle(...)`

### 4. Swap-style two-mint `TransferChecked`

1. `double_swap_checked` — user-signed transfer into vault A plus PDA-signed transfer out of vault B
2. `batch_swap_checked` — same two-mint flow inside one `Batch` CPI via `spl_token.cpi.batchSignedSingle(...)`
3. `batch_prepared_swap_checked` — same flow via `spl_token.cpi.batchPreparedSignedSingle(...)`

### 5. Router-style stateful swap `TransferChecked`

1. `init_router` — initialize a program-owned router state account that stores signer + vault + mint config
2. `double_router_swap_checked` — router-state validation + counter updates around the two direct child CPIs
3. `batch_router_swap_checked` — same router wrapper around one batched token invoke
4. `batch_prepared_router_swap_checked` — same router wrapper via `spl_token.cpi.batchPreparedSignedSingle(...)`

The script creates fresh devnet mints + token accounts, initializes the proof PDA when needed, sends every instruction, and prints:

For a deeper attribution write-up, see [`COST_ANALYSIS.md`](./COST_ANALYSIS.md).

- transaction signature
- `meta.computeUnitsConsumed`
- number of token-program invoke log lines

## Build

```bash
SOLANA_ZIG_BIN="$(./scripts/ensure-solana-zig.sh)" \
  "$SOLANA_ZIG_BIN" build --build-file scripts/devnet-batch-proof/build.zig
```

Artifact:

- `scripts/devnet-batch-proof/zig-out/lib/batch_proof.so`

## Deploy

```bash
solana-keygen new --no-bip39-passphrase -o scripts/devnet-batch-proof/.artifacts/batch-proof-keypair.json
solana program deploy -u devnet \
  scripts/devnet-batch-proof/zig-out/lib/batch_proof.so \
  --program-id scripts/devnet-batch-proof/.artifacts/batch-proof-keypair.json
```

Latest measured deployment:

- program: `C8hsNpoQx1HunGBxkdUsBJLGK7YVwNau3smREgfrixcb`
- PDA state: `8WmxZR38Q6dwrRtsq6RY2Dovjti4DiGxmZCxvvJyYdPB`

## Run

```bash
cd scripts/devnet-batch-proof
npm install
BATCH_PROOF_PROGRAM_ID=<DEPLOYED_PROGRAM_ID> node run.mjs
```

## Current observed devnet results (2026-05-13)

### Transfer

- `double_transfer` → `2408 CU`, token invokes: `2`
- `batch_transfer` → `2728 CU`, token invokes: `1`
- `batch_prepared_transfer` → `2713 CU`, token invokes: `1`

### TransferChecked

- `double_transfer_checked` → `2538 CU`, token invokes: `2`
- `batch_transfer_checked` → `3144 CU`, token invokes: `1`
- `batch_prepared_transfer_checked` → `3125 CU`, token invokes: `1`

### Mixed signer TransferChecked

- `double_mixed_transfer_checked` → `2590 CU`, token invokes: `2`
- `batch_mixed_transfer_checked` → `3246 CU`, token invokes: `1`
- `batch_prepared_mixed_transfer_checked` → `3211 CU`, token invokes: `1`

### Swap-style two-mint TransferChecked

- `double_swap_checked` → `2596 CU`, token invokes: `2`
- `batch_swap_checked` → `3277 CU`, token invokes: `1`
- `batch_prepared_swap_checked` → `3235 CU`, token invokes: `1`

### Router-style stateful swap TransferChecked

- `init_router` → `244 CU`, token invokes: `0`
- `double_router_swap_checked` → `2807 CU`, token invokes: `2`
- `batch_router_swap_checked` → `3485 CU`, token invokes: `1`
- `batch_prepared_router_swap_checked` → `3426 CU`, token invokes: `1`
- router state after the three swap calls:
  - `swap_count = 3`
  - `total_in = 120000`
  - `total_out = 54000`

## Interpretation

Across all five families on current devnet:

- batch is **functionally working**
- batch consistently collapses **2 token-program invokes → 1 token-program invoke**
- `batchPrepared*` is consistently cheaper than the higher-level `batch*` wrapper
- but neither batch variant beats the direct two-CPI baseline in these minimal proofs

Current deltas vs the direct double-CPI baseline:

- `Transfer`: `batch +320 CU`, `batchPrepared +305 CU`
- `TransferChecked`: `batch +606 CU`, `batchPrepared +587 CU`
- mixed signer `TransferChecked`: `batch +656 CU`, `batchPrepared +621 CU`
- swap-style two-mint `TransferChecked`: `batch +681 CU`, `batchPrepared +639 CU`
- router-style stateful swap `TransferChecked`: `batch +678 CU`, `batchPrepared +619 CU`

So the repo can now reproduce the **one-invoke batch shape** on a real cluster across plain, mixed-signer, two-mint swap, and **stateful router-style** wrappers. Even after adding program-owned config validation and mutable swap counters around the token flow, these devnet proofs still do **not** reproduce the CU win claimed by more complex p-token / AMM-style examples.

See [`COST_ANALYSIS.md`](./COST_ANALYSIS.md) for the breakdown showing that:

- local `batchPrepared*` only saves tens of CU over `batch*`
- Tokenkeg's inner Batch execution is already ~`+217` to `+242` CU above the sum of the direct child transfers
- the remaining penalty is shared between token-program Batch internals and caller-side residual cost, not primarily the Zig wrapper itself
