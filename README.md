# solana-program-sdk-zig

Write Solana on-chain programs in Zig.

This SDK requires the [solana-zig fork][fork] of Zig 0.16 for building
on-chain programs. Stock Zig 0.16 is sufficient for host-side unit tests.

**Performance:** the in-repo `examples/vault.zig` (a representative
Anchor-style program — PDA creation, typed state, `has_one`, stored-bump
verify, structured events) runs at **1335 / 1544 / 1867 CU** for
`initialize` / `deposit` / `withdraw` — **beats**
[Pinocchio](https://github.com/anza-xyz/pinocchio) on all three
instructions (−17 / −22 / −83 CU respectively). See
[`examples/vault.zig`](examples/vault.zig) and the
[Performance](#performance) section for the methodology.

[fork]: https://github.com/joncinque/solana-zig-bootstrap/releases/tag/solana-v1.53.0

## Quick start

```console
# Download solana-zig fork (macOS arm64)
curl -LO https://github.com/joncinque/solana-zig-bootstrap/releases/download/solana-v1.53.0/zig-aarch64-macos-none.tar.bz2
tar -xjf zig-aarch64-macos-none.tar.bz2
export SOLANA_ZIG="$(pwd)/zig-aarch64-macos-none-baseline/zig"

# Run tests
"$SOLANA_ZIG" build test --summary all
./program-test/test.sh "$SOLANA_ZIG"
```

## Performance

Benchmarked via [solana-program-rosetta](https://github.com/nickfrosty/solana-program-rosetta).
CU = Compute Units. **Lower is better.**

| Benchmark | Rust | Pinocchio | Zig (upstream SDK) | **Zig (this SDK)** |
|---|---:|---:|---:|---:|
| helloworld | 105 | — | 105 | **105** |
| pubkey | 14 | — | 15 | **21** |
| transfer-lamports | 493 | 27 | 37 | **24** |
| cpi | 3753 | 2771 | **2958** | — |

Key results:
- **Transfer: 24 CU** — beats Pinocchio (27 CU) by 11%, beats Rust (493 CU) by 20×
- **Helloworld: 105 CU** — identical across all languages (syscall-bound)
- **CPI: 2958 CU** — 21% faster than Rust (3753 CU)

> **Note:** The pubkey benchmark is higher (21 vs 14) because the SDK version
> uses `lazyEntrypoint` with error union (5 CU overhead). Using `lazyEntrypointRaw`
> or hand-written entrypoint brings it to 15 CU (matching upstream Zig).

### In-repo benchmark (`solana-program-test` 2.3.13)

Local apples-to-apples comparison of `lazyEntrypoint` vs `lazyEntrypointRaw`
(same program logic, only the entrypoint wrapper differs):

| Program | `lazyEntrypoint` (ProgramResult) | `lazyEntrypointRaw` (u64) | Δ |
|---|---:|---:|---:|
| pubkey_cmp_safe (byte-by-byte) | 22 CU | 18 CU | −4 |
| pubkey_cmp_unchecked (aligned u64) | — | **18 CU** | — |
| pubkey_cmp_comptime (`pubkeyEqComptime`) | 26 CU | — | — |
| transfer_lamports | 27 CU | **22 CU** | −5 |

The error-union wrapper costs ~3–5 CU. Reproduce with:

### Compile-time PDA derivation

When all seeds and the program id are known at compile time, the SDK
computes the PDA at build time and emits two plain constants — no
`sol_try_find_program_address` syscall is needed:

```zig
const VAULT = sol.pda.comptimeFindProgramAddress(
    .{ "vault" },
    MY_PROGRAM_ID,
);
// VAULT.address and VAULT.bump_seed are baked into the binary.
```

| Program | CU |
|---|---:|
| `pda_runtime` (`findProgramAddress` syscall) | 3025 |
| `pda_comptime` (`comptimeFindProgramAddress`) | **9** |

That is a ~3000 CU per-call saving for static PDAs (singletons, vaults,
treasuries, well-known sysvar accounts, etc.).

There's also a companion `pda.comptimeCreateWithSeed(base, "seed", program_id)`
for the no-bump-search `create_account_with_seed` case.

### Declarative account parsing

`ctx.parseAccounts(.{ "from", "to", "system_program" })` returns a
named struct with one `AccountInfo` per requested account, with the
loop fully unrolled at compile time. There's also
`ctx.parseAccountsUnchecked(.{ ... })` — same return shape, but the
caller asserts that no two slots reference the same account. The
unchecked variant is ~70 CU cheaper on a 2–3 account parse; use it
when your account roles are structurally distinct (typical for fixed
DeFi-style layouts).

```zig
const accs = try ctx.parseAccounts(.{ "from", "to", "system_program" });
try sol.system.transfer(accs.from.toCpiInfo(), accs.to.toCpiInfo(),
                        accs.system_program.toCpiInfo(), amount);
```

Zero runtime overhead vs. hand-written `nextAccount() orelse …`.

### Comptime-validated account parsing

For the common case where you also want to assert each account's
`signer` / `writable` / `executable` flags or its expected owner,
`parseAccountsWith` declares the expectations alongside the names.
Forgetting an `isSigner()` check is a top-five Solana program bug —
this lets the compiler enforce them for you:

```zig
const accs = try ctx.parseAccountsWith(.{
    .{ "from",           .{ .signer = true, .writable = true } },
    .{ "to",             .{ .writable = true } },
    .{ "config",         .{ .owner = MY_PROGRAM_ID } },
});
```

Each check unrolls into a single `if` at compile time, so the
generated BPF is byte-identical to hand-written validation — but you
get the canonical error variant (`MissingRequiredSignature`,
`ImmutableAccount`, `IncorrectProgramId`) every time, no more stray
"Custom program error" surprises in your logs.

The same `expectSigner()` / `expectWritable()` / `expectExecutable()`
helpers are available directly on `AccountInfo` for ad-hoc checks.

### Typed instruction-data deserialization

Four helpers replace the verbose `@as(*align(1) const T, @ptrCast(data[a..b])).*`
pattern that pervades on-chain code, **plus** the always-paired
`if (data.len < N) return error.X` and `@enumFromInt(data[0])` guards:

```zig
// Bounds-checked single-field read — combines len check + load
const amount = sol.instruction.tryReadUnaligned(u64, data, 1)
    orelse return error.InvalidInstructionData;

// Validated tag extraction — guards against out-of-range enum values
// (which would otherwise be UB via `@enumFromInt`)
const tag = sol.instruction.parseTag(Ix, data)
    orelse return error.InvalidInstructionData;

// Multi-field read via an extern struct — fields are accessed by name,
// offsets are folded at compile time
const Args = extern struct {
    tag: u32 align(1),
    amount: u64 align(1),
};
const args = sol.instruction.IxDataReader(Args).bind(data)
    orelse return error.InvalidInstructionData;
const amount = args.get(.amount);  // single ldxdw, offset 4

// Trust-me variants (skip the check) when the caller has already guarded
const amount = sol.instruction.readUnaligned(u64, data, 1);  // unchecked
const tag = sol.instruction.parseTagUnchecked(Ix, data);     // unchecked
```

All four compile to the **same BPF as hand-written pointer casts** —
verified by disassembly. The win is purely ergonomic + safety: layout
is documented as a struct, field offsets can't be miscalculated, the
bounds check is a single comptime-known compare that LLVM folds when
the caller has already guarded `data.len`, and `parseTag`'s
comptime-unrolled variant check closes the `@enumFromInt` UB hole.

### Checked arithmetic for u64 (and friends)

DeFi-style programs repeatedly write:

```zig
const new_balance, const ovf = @addWithOverflow(balance, amount);
if (ovf != 0) return error.ArithmeticOverflow;
```

`sol.math` collapses that to one line in three flavors:

```zig
// Optional-returning (compose with `orelse`):
const new_balance = sol.math.tryAdd(balance, amount)
    orelse return error.ArithmeticOverflow;

// Error-returning (compose with `try`):
const new_balance = try sol.math.add(balance, amount);

// Wrapping (when you've already proven non-overflow):
const new_balance = sol.math.addUnchecked(balance, amount);
```

Same for `sub` / `mul`. Works on any integer type (u64, u32, i64, …).

**Measured 0 CU vs. hand-written** `@addWithOverflow` + branch on the
vault deposit benchmark. Tip: for `if (a < b) err else a - b`
(common withdraw shape), the hand-written form is ~6 CU cheaper than
`trySub` — BPFv2's `@subWithOverflow` materializes the carry flag as a
value-to-store-and-test. Use the math helpers when you'd otherwise
write `@addWithOverflow`, not when you'd write `if (a < b)`.

### Single-account expectations

`AccountInfo.expect(.{...})` mirrors `parseAccountsWith`'s
`AccountExpectation` shape for one-off assertions:

```zig
try authority.expect(.{ .signer = true, .writable = true });
try mint.expect(.{ .owner = sol.spl_token_program_id });
try rent_sysvar.expect(.{ .key = sol.sysvar.RENT_ID });

// Multi-program accept: useful for "either SPL Token or Token-2022".
try mint.expect(.{ .owner_any = &.{
    sol.spl_token_program_id,
    sol.spl_token_2022_program_id,
}});
```

Each field is comptime-gated — only the requested checks generate
code. `key` and `owner` use the comptime-Pubkey fast path (4 u64
immediate compares, no rodata lookup). `owner_any` and `key_any`
take a comptime slice and short-circuit on the first match — a
2-way check on the failure path costs ~18 CU (measured via
`pubkey_cmp_any_2` benchmark). `parseAccountsWith` also now
accepts a `.key` expectation for asserting well-known sysvars,
system programs, or pre-derived PDAs in a single declarative spec.

### Typed account-data view

For programs that manage account layouts directly (not through
`TypedAccount`):

```zig
const Layout = extern struct {
    counter: u64 align(1),
    flag: u8,
};
const state: *align(1) Layout = account.dataAs(Layout);
state.counter += 1;  // direct write into account data

// Read-only:
const v = account.dataAsConst(Layout).counter;
```

Single pointer-cast — no allocation, no copying. Use `TypedAccount(T)`
when you want discriminator validation; use `dataAs(T)` when the
caller has already proven the layout (e.g. for raw SPL Token account
parsing where the type IS the layout).

### Sysvar syscall wrappers

Reading sysvars via syscall is **~250-300 CU** and removes the need
for the client to list the sysvar account in the instruction's
accounts. Five sysvars expose direct syscall wrappers:

```zig
const clock = try sol.Clock.get();
const rent = try sol.rent.Rent.get();
const epoch_schedule = try sol.sysvar.EpochSchedule.get();
const last_restart = try sol.sysvar.LastRestartSlot.get();
const epoch_rewards = try sol.sysvar.EpochRewards.get();
```

For sysvars without syscalls (Instructions, SlotHashes, StakeHistory),
use the account-based path:

```zig
const slot_hashes = try sol.sysvar.getSysvar(sol.sysvar.SlotHash, sysvar_account);
```

### Custom error codes with `ErrorCode` + `lazyEntrypointTyped`

Solana programs report errors via a `u32` "Custom" code, but Zig
error sets can't carry payloads (every variant is a globally-interned
name) **and** Solana programs can't use mutable globals (the SBPFv2
loader rejects `.bss` / `.data`). `ErrorCode` bridges the gap by
tying an `enum(u32)` to a parallel `error{...}` set with matching
variant names — the entrypoint's `catch` block dispatches on the
name to recover the original `u32` code.

```zig
const VaultErr = sol.ErrorCode(
    enum(u32) {
        NotInitialized = 6000,
        AmountOverflow,
        InsufficientBalance,
        Unauthorized,
    },
    error{ NotInitialized, AmountOverflow, InsufficientBalance, Unauthorized },
);

fn process(ctx: *sol.entrypoint.InstructionContext) VaultErr.Error!void {
    try sol.system.transfer(...);                        // ProgramError flows through
    if (overflow) return VaultErr.toError(.AmountOverflow);  // custom code
}

// `lazyEntrypointTyped` catches `VaultErr.Error`, recognises which
// half of the union the error belongs to, and emits the matching
// wire u64.
export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypointTyped(VaultErr, process)(input);
}
```

`ErrorCode` validates at comptime that the enum variants and error
set variants have matching names. Cost: zero CU on the happy path;
the error dispatch is an `inline for` jump-table on the cold path.

There's also `programEntrypointTyped(N, ErrCode, fn)` for the
eager-parse variant.

### Anchor-style foundations (no framework required)

The SDK ships a few building blocks for "Anchor-style" programs while
deliberately staying out of the framework business — every piece is
opt-in and composable with the raw `[*]u8` entrypoint:

- **`TypedAccount(T)`** — zero-copy typed access. Wrap an
  `AccountInfo`, then `.read()` / `.write()` return aligned pointers to
  `T`. No serialization, no allocation, no RefCell — just one
  `@ptrCast`.

- **`discriminator.forAccount("MyState")`** — 8-byte
  `sha256("account:MyState")[..8]` computed at compile time. If `T`
  declares `pub const DISCRIMINATOR = ...`, `TypedAccount(T).bind()`
  enforces it and `initialize()` writes it. Defends against the
  classic "account type confusion" attack class.

- **`ErrorCode(enum(u32) { Overflow = 6000, ... })`** — typed
  per-program error codes mapped to the runtime's `Custom(N)` wire
  format. Zero runtime cost.

- **`system.createRentExempt(...)`** — one-call account creation that
  pulls the rent-exempt minimum from the Rent sysvar and forwards to
  `system.createAccount` (or `createAccountSigned` when you provide
  `signer_seeds`).

- **`pda.verifyPda(key, seeds, bump, program_id)`** — Anchor's
  `seeds = [...], bump = state.bump` equivalent. Asserts that a
  passed-in account key matches the canonical PDA for the given seeds.
  One SHA-256 (~1500 CU) using the stored bump. Also
  `verifyPdaCanonical` if you need to walk bumps.

- **`vault.requireHasOne("authority", a.authority)`** — Anchor's
  `#[account(has_one = authority)]` equivalent. Asserts that a
  `Pubkey` field in the typed state equals another account's key.
  Field name is comptime so the offset is folded.

- **`sol.emit(MyEvent{...})`** — structured event logging via
  `sol_log_data`. `MyEvent` must be an `extern struct`; on-wire format
  is `discriminator(8B) || raw(value)`, compatible with off-chain
  indexers that decode `sol_log_data` slices.

Putting them together (see `examples/vault.zig` for the full file):

```zig
const VaultState = extern struct {
    discriminator: [sol.DISCRIMINATOR_LEN]u8,
    authority: sol.Pubkey,
    balance: u64,
    bump: u8,
    _pad: [7]u8 = .{0} ** 7,

    pub const DISCRIMINATOR = sol.discriminatorFor("Vault");
};

const VaultErr = sol.ErrorCode(enum(u32) {
    Unauthorized = 6000,
    InsufficientVaultBalance,
    AmountOverflow,
});

fn deposit(ctx: *sol.InstructionContext) sol.ProgramResult {
    const a = try ctx.parseAccountsWith(.{
        .{ "payer", Exp{ .signer = true, .writable = true } },
        .{ "vault", Exp{ .writable = true, .owner = PROGRAM_ID } },
        .{ "system_program", Exp{} },
    });
    const amount = ctx.readIx(u64, 1);

    const vault = try sol.TypedAccount(VaultState).bind(a.vault);
    try sol.system.transfer(a.payer.toCpiInfo(), a.vault.toCpiInfo(),
                            a.system_program.toCpiInfo(), amount);

    const new_balance = sol.math.tryAdd(vault.read().balance, amount)
        orelse return VaultErr.toError(.AmountOverflow);
    vault.write().balance = new_balance;
}

export fn entrypoint(input: [*]u8) u64 {
    // `lazyEntrypointTyped` catches `VaultErr.Error` and dispatches
    // on variant name to emit the matching `Custom(u32)` wire code.
    return sol.entrypoint.lazyEntrypointTyped(VaultErr, process)(input);
}
```

Each line is independently usable — `TypedAccount` doesn't require
discriminators, `parseAccountsWith` doesn't require `TypedAccount`,
nothing requires anything else. Use only the pieces you need.

### End-to-end vault program (CU vs. Pinocchio vs. Anchor)

The `examples/vault.zig` program exercises the SDK's Anchor-style
surface end-to-end: PDA account creation via CPI, typed state with an
8-byte discriminator, `has_one` authority check, stored-bump PDA
verification, structured event emission via `sol_log_data`. CU
numbers from the in-repo `solana-program-test` runner (`BPF_OUT_DIR=
zig-out/lib cargo run -- vault_*`):

| Instruction | Zig (this SDK) | Pinocchio | Zig − Pino | Anchor (typical) |
|---|---:|---:|---:|---:|
| `vault.initialize` | **1335** | 1351 |  −16 (−1.2%) | 8000–10000 |
| `vault.deposit`    | **1544** | 1565 |  −21 (−1.3%) | 5000–8000  |
| `vault.withdraw`   | **1867** | 1949 |  −82 (−4.2%) | 4000–6000  |

Both implementations live in the repo (`examples/vault.zig` for Zig,
`bench-pinocchio/src/lib.rs` for Pinocchio) and run the **identical**
business semantics — same PDA seeds (`["vault", authority]`), same
client-supplied bump, same 56-byte account layout, same 24-byte
`sol_log_data` event payload — so the comparison isolates pure SDK
overhead.

Reading: all three instructions now beat Pinocchio outright.
`initialize` is **17 CU faster**, `deposit` is **22 CU faster**,
`withdraw` is **83 CU faster**. The named optimizations that
pulled past Pinocchio (in order of contribution):

- **Stored-bump PDA + client-supplied bump** — skips the
  `findProgramAddress` 256-iteration loop entirely.
- **Direct lamport mutation on `withdraw`** — Solana's asymmetric
  lamport rule lets a program-owned account *decrease* lamports
  via pointer mutation; only `deposit` needs the CPI.
- **`CpiAccountInfo.fromPtr` u32 flag-copy** — single load+store
  instead of three byte ops, ported from Pinocchio's
  `init_from_account_view`.
- **`pubkeyEqComptime` xor-or shape** — collapses 4 immediate
  short-circuit compares into 1 final cmp (−6 CU per call).
- **Pubkey-pointer threading** (instead of value copies) — passing
  `authority.key()[0..]` directly to `Seed.from` avoids a
  32-byte stack copy per PDA derive.
- **`TypedAccount.initialize` disc-rebuild** — single-store the
  user value with disc field stamped, instead of write-then-overwrite.

#### Why `withdraw` (1867 CU) is lower than the body alone suggests

Although `withdraw`'s body is "longer" (it does a `requireHasOne`,
runs `verifyPda` for the stored-bump PDA proof, and emits the same
event), it has **no CPI**. `verifyPda` makes one
`sol_create_program_address` syscall (~1500 CU) — that's still the
biggest line item — but the lamport movement itself is two pointer
writes (`subLamports`/`addLamports`, ~3 CU each), not a CPI to the
system program.

#### Why `deposit` (1544 CU) cannot go much lower

`deposit` moves SOL **from** the user's wallet (a system-owned
account) **to** the vault. Solana's runtime has an asymmetric rule:

- *Decreasing* an account's lamports requires the program to own the
  account.
- *Increasing* an account's lamports works regardless of owner.

The vault program does not (and must not) own the user's wallet, so
it cannot debit `payer.lamports` directly. The only way to move SOL
out of a system-owned account is to CPI into `system_program::Transfer`,
which costs ~1200 CU of fixed runtime overhead — independent of the
SDK doing the call.

`withdraw` exploits the asymmetry: the vault account is owned by the
program (so we *can* debit it directly), and `recipient` is *credited*
(no owner check). The result is two pointer writes instead of a 1200-
CU CPI.

The only way to make `deposit` materially cheaper would be to change
the protocol — e.g. require the user to send a separate
`system::Transfer` first and have the vault simply
"acknowledge" the deposit by updating `state.balance`. That eliminates
the CPI but breaks atomicity (the transfer and the balance update are
no longer coupled) and complicates the client UX. We don't do that
here; the 1544-CU cost is a property of doing deposit atomically, not
of the SDK.

The 470-CU reduction on `vault.initialize` (1823 → 1353, **−26%**)
came from three measurable, named optimizations:

1. **Rent integer fast path (−283 CU).** `Rent.getMinimumBalance` was
   `(overhead + len) * lamports_per_byte_year * exemption_threshold`
   in f64. BPF emulates f64 multiplication in software at ~150-300 CU
   per op, so this single line cost roughly the same as the entire
   rest of the `initialize` body. We now bit-compare
   `exemption_threshold` against the IEEE-754 pattern for `2.0` (the
   canonical, genesis-since cluster value) and fall through to plain
   integer arithmetic when it matches. The f64 path remains as a
   safety net for hypothetical future clusters with non-2.0
   thresholds. See `src/rent.zig`.

2. **Comptime rent baking (−161 CU).** When `space` is comptime-known
   (the typical case — `@sizeOf(MyState)`), the rent-exempt minimum
   balance can be folded into a single u64 immediate at build time,
   eliminating the `sol_get_rent_sysvar` syscall entirely. The new
   `system.createRentExemptComptimeRaw(args, comptime space, signers)`
   is the entry point — see `examples/vault.zig` for the call shape.

3. **CpiAccountInfo flag-copy as one u32 (−27 CU on init, −21 on
   deposit).** Every CPI we make has to stage the runtime-input
   `Account` into a `CpiAccountInfo` (the C-ABI struct
   `sol_invoke_signed_c` reads). `is_signer`, `is_writable` and
   `is_executable` are three consecutive bytes in both structures.
   Reading them as three separate byte loads + writes took ~3 CU per
   account; reading them as a single u32 load + store (plus one
   "harmless" byte of padding on each side) takes ~1 CU per account.
   Three accounts × 3 CU saved × 3 lower-bound rounding = ~25-27 CU.
   Pinocchio's `init_from_account_view` already used this trick — we
   ported it. See `src/account.zig:fromPtr`.

That brings `vault.initialize` and `vault.deposit` within 2 CU of
Pinocchio (effectively tied; `deposit` is actually 21 CU *faster*),
and `vault.withdraw` is 72 CU faster — the only headroom left is
sub-CU-per-line residual that LLVM has already squeezed flat.

> Anchor figures are approximate values from production Solana
> programs at the time of writing — your mileage will vary based on
> account layout, IDL size, and Anchor version. Both Zig and
> Pinocchio avoid the Anchor IDL preflight, the borsh
> (de)serialization round-trip, and the `RefCell` borrow checks,
> which is where the bulk of the difference vs Anchor comes from.

The `vault.initialize` instruction uses the **client-supplied bump**
pattern: instead of running the up-to-255-iteration
`find_program_address` syscall on-chain (~3000-5000 CU), the client
derives the canonical bump off-chain via `Pubkey::find_program_address`
and passes it as the second byte of the instruction data. The program
then runs a single `create_program_address` (one SHA-256, ~1500 CU)
as part of the system_program create CPI's signer-seed proof.

Security: if the client lies about the bump, the CPI's runtime-level
signer-seed check fails (the derived address won't match the
account's claimed key) and the create aborts — no separate `verifyPda`
call is needed up front.

The vault also uses the **raw signer API** at the CPI call site, which
hands the runtime its native `Signer { addr, len }` shape directly:

```zig
const bump_seed = [_]u8{bump};
const seeds = [_]sol.cpi.Seed{
    .from("vault"),
    .fromPubkey(authority.key()),  // *const Pubkey → 32-byte seed
    .from(&bump_seed),
};
const signer = sol.cpi.Signer.from(&seeds);

try sol.system.createRentExemptRaw(.{
    .payer = authority.toCpiInfo(),
    .new_account = vault.toCpiInfo(),
    .system_program = system_program.toCpiInfo(),
    .space = @sizeOf(VaultState),
    .owner = &PROGRAM_ID,
}, &.{signer});
```

`sol.cpi.Seed` and `sol.cpi.Signer` are `extern struct`s with exactly
the runtime C-ABI layout (`{ ptr: u64, len: u64 }`), so the SDK passes
the pointer straight to `sol_invoke_signed_c` without staging a copy.
The ergonomic `signer_seeds: &.{&.{...}}` form (slice-of-slice-of-slice)
still works on `sol.system.createRentExempt` for the common case where
you don't care about ~80 CU; the LLVM optimizer folds most of the
staging copy away anyway when the seed count is comptime-known.

### Sysvar instructions introspection — read other ix in the same tx

The Solana **instructions sysvar** (`Sysvar1nstructions11…`) exposes
the entire transaction's serialized instructions. The
`sol.sysvar_instructions` module parses it zero-copy:

```zig
// Have your client pass the sysvar as an account in the ix.
const ix_sysvar = a.instructions_sysvar;

// Where am I in the tx?
const my_index = try sol.loadCurrentIndexChecked(ix_sysvar);

// The instruction immediately before me must be ed25519 sig-verify.
const prev = try sol.getInstructionRelative(-1, ix_sysvar);
if (!sol.pubkey.pubkeyEqComptime(prev.programId(), sol.ed25519_program_id))
    return error.InvalidArgument;

// Walk its account metas / data without copying.
var it = prev.accounts();
while (it.next()) |meta| {
    if (meta.isSigner()) { /* ... */ }
}
const sig_data = prev.data();
```

This is the canonical pattern for **ed25519 / secp256k1 verify-then-act**
flows (Wormhole-style attestations, oracle signatures, gasless tx) and
for **MEV / sandwich defence** ("the preceding ix must be from
program X").

### Call-stack introspection — top-level vs CPI guards

`sol.stack` exposes the two runtime call-stack syscalls:

```zig
// "This entrypoint must run as a top-level tx instruction" — reject CPI.
if (sol.getStackHeight() != sol.TRANSACTION_LEVEL_STACK_HEIGHT)
    return error.MustBeTopLevel;

// Probe sibling instructions of the parent invocation.
if (sol.stack.siblingMeta(0)) |s| {
    if (sol.pubkey.pubkeyEq(&s.program_id, &SOME_PROGRAM_ID)) {
        // The most recently-processed sibling was that program.
    }
}

// Pull a sibling's data + account-metas (two-call ABI):
const sibling = try sol.stack.getProcessedSiblingInstructionAlloc(0, allocator);
```

Combined with the instructions sysvar, this is the toolkit needed for
serious onchain protocols — Squads, Jito-style tip distribution,
limit-order protections, anything that needs to verify "what else is
happening in this transaction?".

### Account-data resize + close

`AccountInfo` now ships the two account-lifecycle operations that
Anchor users expect:

```zig
// Grow / shrink within the runtime's MAX_PERMITTED_DATA_INCREASE (10 KiB)
// budget. Returns InvalidRealloc on overflow.
try state_account.resize(new_size, /*zero_init=*/ true);

// Reassign owner (typically to the system program before close).
state_account.assignComptime(sol.system_program_id);

// Anchor `#[account(close = receiver)]` — drains lamports, zeroes data,
// shrinks data_len to 0, reassigns to system program. Caller must have
// verified ownership upstream.
try state_account.close(receiver);

// Discriminator-validated typed accounts get a matching helper:
const vault = try sol.TypedAccount(VaultState).bind(a.vault);
try vault.close(a.receiver);
```

`originalDataLen()` exposes the runtime-captured pre-instruction
length, which is the basis of the resize-budget check.

### `sol.crypto` — all crypto syscalls in one place

Everything hash / curve / signature lives under `sol.crypto`:

| Sub-module | Syscalls |
|------------|----------|
| `sol.crypto.hash` | `sol_sha256`, `sol_keccak256`, `sol_blake3` |
| `sol.crypto.secp256k1_recover` | `sol_secp256k1_recover` |
| `sol.crypto.alt_bn128` | `sol_alt_bn128_group_op` (G1 add/sub/mul, pairing) |
| `sol.crypto.poseidon` | `sol_poseidon` |

Each is also re-exported flat (`sol.sha256`, `sol.alt_bn128.…`) so
existing call sites keep working — use whichever spelling reads better.

```zig
// SHA-256 / Keccak-256 / Blake3 — one-shot hash, host & on-chain.
const h = sol.crypto.sha256(&.{"namespace:", payload});
const k = sol.crypto.keccak256(&.{message_bytes});

// secp256k1 ECDSA public-key recovery (Ethereum `ecrecover` parity).
const pubkey64 = try sol.crypto.secp256k1_recover.recover(
    hash_bytes,            // 32-byte keccak256 of the signed message
    recovery_id,           // 0..3
    signature_bytes_64,    // compact (r || s)
);
// To derive an Ethereum address: keccak256(pubkey64.bytes)[12..32]

// alt_bn128 (BN254) — the same primitive Ethereum exposes via EIP-196/197.
// Used inside Groth16 / PLONK verifiers.
var sum: [sol.crypto.alt_bn128.G1_POINT_SIZE]u8 = undefined;
try sol.crypto.alt_bn128.g1AdditionLE(&combined_input_128, &sum);

var pairing_out: [sol.crypto.alt_bn128.PAIRING_OUTPUT_SIZE]u8 = undefined;
try sol.crypto.alt_bn128.pairingBE(verifier_input, &pairing_out);
// pairing_out == [0,…,0,1] (BE) when the multi-pairing equation holds.

// Poseidon — ZK-friendly hash (BN254 X5).
var ph: [sol.crypto.poseidon.HASH_LEN]u8 = undefined;
try sol.crypto.poseidon.hashv(.bn254_x5, .big_endian, &.{leaf_a, leaf_b}, &ph);
```

All wrappers map the syscall's numeric return codes to typed error
variants (e.g. `error.InvalidSignature`, `error.InvalidInputData`,
`error.InvalidNumberOfInputs`) so callers get Zig-native error
handling instead of `u64` magic constants.

### StakeHistory sysvar

Reading historical stake activation requires passing the
`SysvarStakeHistory…` account into the instruction (no direct
syscall exists for it). The accessor parses zero-copy:

```zig
const sh = try sol.stake_history.StakeHistory.fromAccount(a.stake_history);
if (sh.get(target_epoch)) |entry| {
    // entry.effective / entry.activating / entry.deactivating
}
// Most recent entry:
const head = sh.latest().?;
```

`Entry` is a `extern struct { epoch, effective, activating,
deactivating: u64 }` matching the runtime's serialized 32-byte
layout. Binary-searches by epoch in `O(log n)`.

### Hash newtype + on-host fallback

`src/hash.zig` (re-exported via `sol.crypto.hash` and flat as
`sol.sha256` etc.) gives the three hash syscalls a uniform API that
works on both host (via `std.crypto.hash`) and on-chain (via the
syscalls):

```zig
const h = sol.sha256(&.{"namespace:", payload});  // Hash newtype
const k = sol.keccak256(&.{message_bytes});       // EVM-compat
const b3 = sol.blake3(&.{stuff});
// `Hash` formats as base58 by default; `bytes` field exposes the raw [32]u8.
```

`hashv` is an alias for `sha256` for parity with `solana-program`.

### Example programs

The `examples/` directory ships four standalone programs that
exercise progressively more of the SDK. Each one is a complete,
deployable `entrypoint` — no framework, no codegen, just raw Zig
on the bare `[*]u8` interface.

| Example | Lines | Demonstrates |
|---|---:|---|
| [`hello.zig`](examples/hello.zig)              | ~30  | `lazyEntrypointRaw`, `sol.log` — the minimal program |
| [`token_dispatch.zig`](examples/token_dispatch.zig) | ~110 | `IxDataReader`, `parseAccountsUnchecked`, comptime instruction dispatch |
| [`counter.zig`](examples/counter.zig)          | ~210 | `programEntrypointTyped`, `TypedAccount`, `requireHasOneWith`, `ErrorCode`, `sol.math`, `emit` — minimal stateful program |
| [`vault.zig`](examples/vault.zig)              | ~285 | All of the above + PDA creation, `verifyPda`, `system.createRentExemptComptimeRaw` |
| [`escrow.zig`](examples/escrow.zig)            | ~255 | Multi-instruction state machine (Make / Take / Refund), direct lamport mutation for closing accounts, PDA escrow lifecycle |

All five compile to `.so` with no `.bss` section — the SBPFv2 loader
rejects mutable-global programs, and the SDK is carefully written to
hold no module-level state (the entrypoint, error-code mapping, etc.
all flow through the stack).

### `sol_log_data` event-size pricing

Empirically, `sol_log_data` charges roughly **1 CU per byte** of
payload plus a fixed syscall overhead (~150 CU) plus a small per-slice
fee. For a vault `DepositEvent` carrying two `Pubkey` fields (64
bytes) plus two `u64`s (16 bytes), this works out to ~340 CU per
emit. The pubkeys are redundant — off-chain indexers already have
access to the transaction's account list — so this example trims
events to just `{ amount, new_balance }` (16 bytes) and saves
~100 CU per emit. Keep your event payloads minimal.

Counter-intuitive finding: assembling `discriminator || payload`
into a single stack buffer and calling `sol_log_data` with **one**
slice is ~100 CU cheaper than calling it with two slices (one for
the discriminator, one for the payload). The runtime charges a
per-slice base fee that exceeds the in-program `@memcpy` cost for
typical small events.

The `examples/token_dispatch.zig` program (2 account slots, `u32` tag
+ `u64` amount payload, parse-then-dispatch) lands at **37–38 CU**
across transfer / burn / mint using `parseAccountsUnchecked` (the
two-account layout has structurally distinct roles so dups can't
occur). Using the dup-aware safe `parseAccounts` adds ~63 CU of
tagged-union switch + parallel-array work on the same payload.

| Variant | CU | Notes |
|---|---:|---|
| `parseAccountsUnchecked` + `instructionData()` | 37 | structurally-unique account roles |
| safe `parseAccounts` + `instructionData()`      | 100 | dup-aware, ~70 CU more |
| `nextAccountUnchecked` + `readIxTag` (raw)      | 28 | no length guard, hand-rolled |

The safe path's overhead is dominated by the dup-aware tagged-union
switch in `nextAccountMaybe` (the `MaybeAccount` variant + the
`seen[N]` parallel array used to resolve duplicates). When your
program's account roles are structurally unique — typical for
DeFi-style programs with fixed slots (`mint`, `vault`, `recipient`,
…) — switch to `parseAccountsUnchecked` for the savings.

### Reproduce

```console
# Run every benchmark and emit a markdown table (uses a fixed
# authority keypair so PDA bump-search lands at the same depth every
# run → stable vault CU numbers).
./scripts/bench.sh
```

Or drive a single one by hand:

```console
cd benchmark
$SOLANA_ZIG build
BPF_OUT_DIR=$(pwd)/zig-out/lib cargo run --release -- vault_deposit
```

## Architecture

### Core types

| Type | Size | Purpose |
|---|---|---|
| `InstructionContext` | 16 B | Entrypoint context — on-demand account parsing |
| `AccountInfo` | 8 B | Account wrapper — single pointer, Pinocchio-style |
| `CpiAccountInfo` | 72 B | C-ABI-compatible view for CPI calls |
| `MaybeAccount` | 8+ B | Result of `nextAccount()` |

### Entrypoints

| Function | Shape | Use case |
|---|---|---|
| `lazyEntrypointRaw(*fn(*Ctx) u64)` | u64 return, on-demand account parsing | Maximum performance, custom error handling |
| `lazyEntrypoint(*fn(*Ctx) ProgramResult)` | error union, on-demand account parsing | Default — most programs |
| `lazyEntrypointTyped(ErrCode, *fn(*Ctx) ErrCode.Error!void)` | typed error union + per-variant custom codes | When you have `ErrorCode(MyEnum, error{...})` and want codes on the wire |
| `programEntrypoint(N, *fn(*[N]AccountInfo, []const u8, *Pubkey) ProgramResult)` | error union, eager account parsing | Ergonomic alternative when account count is comptime-known |
| `programEntrypointTyped(N, ErrCode, *fn(...))` | eager parse + per-variant custom codes | Eager-parse version of `lazyEntrypointTyped` |

`programEntrypoint` reads more naturally for handlers with a fixed
account count (positional `accounts[0]` access, no `InstructionContext`
threading), but the CU cost is essentially tied with `lazyEntrypoint`
under ReleaseFast — measured 1-CU swing on the `program_entry_1` vs
`program_entry_lazy_1` micro-benches. Choose based on style, not
performance.

## Usage

### With `ProgramResult` (error union)

```zig
const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const source = ctx.nextAccount() orelse return error.NotEnoughAccountKeys;
    const dest = ctx.nextAccount() orelse return error.NotEnoughAccountKeys;
    const ix_data = try ctx.instructionData();

    const amount = sol.instruction.tryReadUnaligned(u64, ix_data, 0)
        orelse return error.InvalidInstructionData;
    source.raw.lamports -= amount;
    dest.raw.lamports += amount;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
```

### With raw `u64` (maximum performance)

Skips the error union entirely. Return `0` for success, non-zero for error.

```zig
const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

fn process(ctx: *sol.entrypoint.InstructionContext) u64 {
    if (ctx.remainingAccounts() != 2) return 1;

    const source = ctx.nextAccountUnchecked();
    const dest = ctx.nextAccountUnchecked();
    // `nextAccountUnchecked` doesn't decrement the remaining counter,
    // so we use the unchecked instruction-data getter here.
    const ix_data = ctx.instructionDataUnchecked();

    const amount = sol.instruction.tryReadUnaligned(u64, ix_data, 0)
        orelse return 1;
    source.raw.lamports -= amount;
    dest.raw.lamports += amount;
    return 0;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypointRaw(process)(input);
}
```

### AccountInfo accessors

```zig
const account = ctx.nextAccountUnchecked();
_ = account.key();           // *const Pubkey
_ = account.owner();         // *const Pubkey
_ = account.lamports();      // u64
_ = account.dataLen();       // usize
_ = account.data();          // []u8
_ = account.isSigner();      // bool
_ = account.isWritable();    // bool
account.raw.lamports += 100; // direct field access
```

### CPI calls

Convert `AccountInfo` to `CpiAccountInfo` for CPI:

```zig
const cpi_info = account.toCpiInfo();
try sol.cpi.invoke(&instruction, &.{cpi_info});
```

`AccountMeta` ships four convenience constructors that read like the
account's role (instead of a struct literal with two `0`/`1`
fields):

```zig
const metas = [_]sol.cpi.AccountMeta{
    sol.cpi.AccountMeta.signerWritable(payer.key()),  // .is_writable=1 .is_signer=1
    sol.cpi.AccountMeta.writable(dest.key()),         // .is_writable=1 .is_signer=0
    sol.cpi.AccountMeta.signer(authority.key()),      // .is_writable=0 .is_signer=1
    sol.cpi.AccountMeta.readonly(sysvar.key()),       // .is_writable=0 .is_signer=0
};
```

All four are `inline fn` — same BPF as the struct literal. The SDK's
own `system.zig` uses these throughout.

`Instruction` also has a one-call constructor, used by every helper
in `system.zig`:

```zig
const ix = sol.cpi.Instruction.init(program.key(), &metas, &ix_data);
// or, when `program` is a parsed CpiAccountInfo:
const ix = sol.cpi.Instruction.fromCpiAccount(program, &metas, &ix_data);
```

For PDA seeds, the `Seed` type ships three constructors covering the
common shapes:

```zig
const seeds = [_]sol.cpi.Seed{
    .from("vault"),                       // byte slice (string literal)
    .fromPubkey(authority.key()),         // *const Pubkey → 32-byte seed
    .from(&bump_seed),                    // explicit 1-element [u8] array
    // also:                              .fromByte(&state.bump) — for u8
    //                                    field on an account / struct
};
```

## Using the SDK from your `build.zig`

```zig
const std = @import("std");
const solana = @import("solana_program_sdk");

pub fn build(b: *std.Build) void {
    _ = solana.buildProgram(b, .{
        .name = "my_program",
        .root_source_file = b.path("src/main.zig"),
        .optimize = .ReleaseFast,
    });
}
```

## Prerequisites

### solana-zig fork (required for on-chain program builds)

Download from [GitHub Releases](https://github.com/joncinque/solana-zig-bootstrap/releases/tag/solana-v1.53.0).

### Stock Zig 0.16 (host unit tests only)

```console
zig version
# -> 0.16.x
```

## Tests

```console
# Host unit tests (any Zig 0.16)
zig build test --summary all

# Integration tests (requires solana-zig fork)
./program-test/test.sh "$SOLANA_ZIG"
```

## Branch layout

- **`main`** (default) — solana-zig fork based SDK with the Pinocchio-style
  redesign (current development line).
- `solana-zig-fork-0.16` — historical staging branch for the rewrite; now
  merged into `main` and kept for reference.
