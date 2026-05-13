# Devnet SPL Token batch proof

Minimal real-cluster proof for `spl_token` batch support.

## What it measures

One deployed Zig program compares three path families:

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

The script creates fresh devnet mints + token accounts, initializes the proof PDA when needed, sends every instruction, and prints:

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

- `double_transfer` → `2375 CU`, token invokes: `2`
- `batch_transfer` → `2693 CU`, token invokes: `1`
- `batch_prepared_transfer` → `2677 CU`, token invokes: `1`

### TransferChecked

- `double_transfer_checked` → `2492 CU`, token invokes: `2`
- `batch_transfer_checked` → `3107 CU`, token invokes: `1`
- `batch_prepared_transfer_checked` → `3085 CU`, token invokes: `1`

### Mixed signer TransferChecked

- `double_mixed_transfer_checked` → `2554 CU`, token invokes: `2`
- `batch_mixed_transfer_checked` → `3211 CU`, token invokes: `1`
- `batch_prepared_mixed_transfer_checked` → `3172 CU`, token invokes: `1`

## Interpretation

Across all three families on current devnet:

- batch is **functionally working**
- batch consistently collapses **2 token-program invokes → 1 token-program invoke**
- `batchPrepared*` is consistently cheaper than the higher-level `batch*` wrapper
- but neither batch variant beats the direct two-CPI baseline in these minimal proofs

Current deltas vs the direct double-CPI baseline:

- `Transfer`: `batch +318 CU`, `batchPrepared +302 CU`
- `TransferChecked`: `batch +615 CU`, `batchPrepared +593 CU`
- mixed signer `TransferChecked`: `batch +657 CU`, `batchPrepared +618 CU`

So the repo can now reproduce the **one-invoke batch shape** on a real cluster, including a **mixed outer-signer + PDA-signer** path, but this exact minimal proof still does **not** reproduce the CU win claimed by more complex p-token / AMM-style examples.
