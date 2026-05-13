# Devnet SPL Token batch proof

Minimal real-cluster proof for `spl_token` batch support.

## What it measures

One deployed Zig program compares three paths over the same two
`TransferChecked` child operations:

1. `double_transfer_checked` — two normal SPL Token CPIs
2. `batch_transfer_checked` — one `Batch` CPI built via `spl_token.cpi.batch(...)`
3. `batch_prepared_transfer_checked` — one `Batch` CPI via `spl_token.cpi.batchPrepared(...)`

The script creates a fresh mint + token accounts on devnet, sends all
three instructions, and prints:

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

## Run

```bash
cd scripts/devnet-batch-proof
npm install
BATCH_PROOF_PROGRAM_ID=<DEPLOYED_PROGRAM_ID> node run.mjs
```

## Current observed devnet result (2026-05-13)

- `double_transfer_checked` → `2452 CU`, token invokes: `2`
- `batch_transfer_checked` → `3069 CU`, token invokes: `1`
- `batch_prepared_transfer_checked` → `3050 CU`, token invokes: `1`

So on current devnet for this exact minimal `TransferChecked` shape:

- batch is **functionally working** (one token-program invoke)
- `batchPrepared` is slightly cheaper than `batch` (`-19 CU`)
- but both are still **more expensive** than two direct `TransferChecked` CPIs in this scenario
