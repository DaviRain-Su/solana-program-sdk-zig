# spl-token (Zig)

Status: ✅ **v0.3** — instruction builders + on-chain CPI helpers
for the fungible-token, authority, multisig, native-SOL sync,
utility/return-data helpers, and p-token-style batch surface. The
classic SPL Token subset is validated against the real on-chain SPL
Token program inside Mollusk (see `program-test/tests/spl_token.rs`);
the batch helper is covered by Zig wire/staging tests because the
bundled classic token fixture currently rejects discriminator `255`.

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

// Wrapped SOL / native mint helpers:
try spl_token.cpi.syncNative(a.token_program.toCpiInfo(), wrapped_sol.toCpiInfo());
const uses_native_mint = spl_token.isNativeMint(&spl_token.NATIVE_MINT);

// Return-data utilities:
try spl_token.cpi.getAccountDataSize(a.token_program.toCpiInfo(), a.mint.toCpiInfo());
var return_buf: [16]u8 = undefined;
const returned = sol.cpi.getReturnData(return_buf[0..]) orelse return error.InvalidInstructionData;
const account_size = try spl_token.return_data.parseGetAccountDataSizeReturn(returned);

// Local zero-allocation UI-amount formatting/parsing:
var ui_buf: [spl_token.ui_amount.MAX_FORMATTED_UI_AMOUNT_LEN]u8 = undefined;
const ui = try spl_token.ui_amount.amountToUiAmountStringTrimmed(1_230_000, 6, ui_buf[0..]);
const parsed_amount = try spl_token.ui_amount.tryUiAmountIntoAmount(ui, 6);

// ──────────── Zero-copy state views ────────────
const mint = try spl_token.Mint.fromBytes(mint_account.data());
const balance = (try spl_token.Account.fromBytes(token_account.data())).amount;
const owner = spl_token.unpackAccountOwnerUnchecked(token_account.data());
const mint_key = spl_token.unpackAccountMintUnchecked(token_account.data());
```

## Scope (v0.3)

Instructions:

- `transfer` (3) / `transferChecked` (12)
- `approve` (4) / `approveChecked` (13)
- `revoke` (5)
- `setAuthority` (6)
- `mintTo` (7) / `mintToChecked` (14)
- `burn` (8) / `burnChecked` (15)
- `closeAccount` (9)
- `freezeAccount` (10) / `thawAccount` (11)
- `syncNative` (17)
- `initializeAccount2` (16)
- `initializeMint2` (20) / `initializeAccount3` (18)
- `initializeMultisig2` (19)
  (modern "2"/"3" variants — no Rent sysvar, owner/freeze authority
  passed in instruction data)
- `getAccountDataSize` (21)
- `initializeImmutableOwner` (22)
- `amountToUiAmount` (23)
- `uiAmountToAmount` (24)
  (`getAccountDataSize`, `amountToUiAmount`, and `uiAmountToAmount`
  return their answers via `sol.cpi.getReturnData(...)` after CPI;
  decode them with `spl_token.return_data.*` helpers)
- local zero-allocation UI amount helpers via `spl_token.ui_amount.*`
  for formatting / parsing amounts without CPI
- `batch` (255)
  (p-token / Pinocchio-style concatenated child-instruction envelope;
  available as both `spl_token.instruction.batch(...)` and
  `spl_token.cpi.batch(...)`)

Authority-based operations include single-authority and explicit
multisig builders/CPI variants where the SPL Token program supports
multisig signing.

State (zero-copy `extern struct`):

- `Mint` — 82 bytes, `mint_authority` + `supply` + `decimals` +
  `is_initialized` + `freeze_authority`
- `Account` — 165 bytes, `mint` + `owner` + `amount` + `delegate` +
  `state` + `is_native` + `delegated_amount` + `close_authority`
- `Multisig` — 355 bytes, `m`, `n`, `is_initialized` + up to 11 signer keys
- `AccountState` enum (Uninitialized / Initialized / Frozen)
- `ACCOUNT_MINT_OFFSET` / `ACCOUNT_OWNER_OFFSET` fast-path offsets
- `validAccountData(...)`, `unpackAccountMintUnchecked(...)`,
  `unpackAccountOwnerUnchecked(...)` for GenericTokenAccount-style
  mint/owner inspection without full parsing
- `MIN_SIGNERS` / `MAX_SIGNERS` parity constants
- `isValidSignerIndex(...)` parity helper
- `NATIVE_MINT` constant + `isNativeMint(...)` helper for wrapped SOL flows
- `checkProgramAccount(...)` parity helper for the classic Token program ID

## Not yet covered

Legacy Rent-sysvar initializers (`initializeMint`,
`initializeAccount`, `initializeMultisig`) and Token-2022 extension
instructions. Add when there's a concrete consumer — these are
mechanically the same patterns as above (single comptime
instruction-data builder + CPI wrapper).

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
