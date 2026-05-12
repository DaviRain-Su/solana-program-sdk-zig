# spl-memo (Zig)

Status: ✅ **v0.1** — instruction builder + on-chain CPI helpers.

Zig client for the [SPL Memo](https://github.com/solana-program/memo)
program. Dual-target (on-chain CPI + off-chain ix builder), mirroring
the Rust [`spl-memo`](https://docs.rs/spl-memo) crate.

This is the simplest of the SPL programs — used as the reference
skeleton for new sub-packages in this monorepo.

## API

```zig
const sol = @import("solana_program_sdk");
const spl_memo = @import("spl_memo");

// ──────────── On-chain (inside your program) ────────────

// Pure-log memo, no signers required:
try spl_memo.cpi.memoNoSigners("hello on-chain", memo_program.toCpi());

// Memo enforcing one or more signers:
try spl_memo.cpi.memo("audit:withdraw", memo_program.toCpi(), &.{authority.toCpi()});

// ──────────── Off-chain (host code building a tx) ────────────

var metas: [1]sol.cpi.AccountMeta = undefined;
const ix = spl_memo.instruction.memo("audit:withdraw", &.{&authority_pubkey}, &metas);
// `ix` is a `sol.cpi.Instruction` — serialise into a transaction.

// Or no-signer convenience:
const ix2 = spl_memo.instruction.memoNoSigners("hello off-chain");
```

## Scope

- `instruction.memo(message, signers, account_metas)` — full builder, caller-provided scratch
- `instruction.memoNoSigners(message)` — convenience for the empty-signer case
- `cpi.memo(message, memo_program, signers)` — on-chain wrapper, stack-allocates scratch
- `cpi.memoNoSigners(message, memo_program)` — on-chain convenience
- Constants: `PROGRAM_ID` (v2 modern), `PROGRAM_ID_V1` (legacy)

## Notes

- Memo instruction data is raw UTF-8 — no discriminator, no length prefix
- Both v2 (`MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr`) and v1
  (`Memo1UhkJRfHyvLMcVucJwxXeuD728EqVDDwQDxFMNo`) program IDs are
  exported; new code should always use v2.
- The on-chain `cpi.memo` caps signers at 11 to keep stack scratch
  bounded; that's well beyond any realistic memo's needs.
