# spl-token (Zig)

Status: ✅ **v0.1** — instruction builders + on-chain CPI helpers
for the fungible-token subset. Validated against the real on-chain
SPL Token program inside Mollusk
(see `program-test/tests/spl_token.rs`).

Zig client for the [SPL Token](https://github.com/solana-program/token)
program. Dual-target:

- **on-chain**: CPI helpers (`spl_token.cpi.transfer(...)`)
- **off-chain**: instruction builders (`spl_token.instruction.transfer(...)`)
  returning `sol.cpi.Instruction` byte buffers ready to embed in a
  host-built transaction.

Works against both **classic SPL Token** (`TokenkegQ…`) and
**Token-2022** (`TokenzQd…`) for the fungible subset — the CPI
wrappers take the token program account from the caller, so the
same call site works for either by just passing the right program.

## API

```zig
const sol = @import("solana_program_sdk");
const spl_token = @import("spl_token");

// ──────────── On-chain (inside your program) ────────────
try spl_token.cpi.transfer(
    a.token_program.toCpiInfo(),
    a.source.toCpiInfo(),
    a.destination.toCpiInfo(),
    a.authority.toCpiInfo(),
    100,
);

// `transferChecked` adds a decimals safety net:
try spl_token.cpi.transferChecked(
    a.token_program.toCpiInfo(),
    a.source.toCpiInfo(),
    a.mint.toCpiInfo(),
    a.destination.toCpiInfo(),
    a.authority.toCpiInfo(),
    100, /* amount */
    6,   /* decimals */
);

// PDA-signed flavours follow the same pattern with `Signed` suffix:
try spl_token.cpi.transferSigned(
    /* … */, &.{ signer },
);

// ──────────── Off-chain (host code constructing a transaction) ────────────
var metas: [3]sol.cpi.AccountMeta = undefined;
var data: [9]u8 = undefined;
const ix = spl_token.instruction.transfer(
    &source_pk, &dest_pk, &authority_pk, 100,
    &metas, &data,
);
// `ix` is a `sol.cpi.Instruction` — serialise into a transaction.

// ──────────── Zero-copy state views ────────────
const mint = try spl_token.Mint.fromBytes(mint_account.data());
const balance = (try spl_token.Account.fromBytes(token_account.data())).amount;
```

## Scope (v0.1)

Instructions:

- `transfer` (3) / `transferChecked` (12)
- `mintTo` (7) / `mintToChecked` (14)
- `burn` (8) / `burnChecked` (15)
- `closeAccount` (9)
- `initializeMint2` (20) / `initializeAccount3` (18)
  (modern "2"/"3" variants — no Rent sysvar, owner/freeze authority
  passed in instruction data)

State (zero-copy `extern struct`):

- `Mint` — 82 bytes, `mint_authority` + `supply` + `decimals` +
  `is_initialized` + `freeze_authority`
- `Account` — 165 bytes, `mint` + `owner` + `amount` + `delegate` +
  `state` + `is_native` + `delegated_amount` + `close_authority`
- `AccountState` enum (Uninitialized / Initialized / Frozen)

## Not yet covered

Approve / Revoke / SetAuthority / FreezeAccount / ThawAccount /
multisig flows / Token-2022 extension instructions. Add when there's
a concrete consumer — these are mechanically the same patterns as
above (single comptime instruction-data builder + CPI wrapper).

## Notes

- The builders are **allocation-free**: every function takes a
  caller-supplied scratch buffer for the `AccountMeta` array and
  the instruction-data bytes, so the resulting `Instruction` can
  outlive the call without involving an allocator.
- Use `*Checked` variants whenever the caller knows the decimals —
  it eliminates an entire class of "wrong-mint" bugs and only costs
  a single extra byte over the wire + a tiny CU bump.
- The state structs use `align(1)` on every multi-byte field so the
  byte layout matches the canonical Rust `Pack` encoding without
  trailing padding. The host-side tests assert critical offsets at
  comptime — any silent regression trips at build time, not at run
  time.
