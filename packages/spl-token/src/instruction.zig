//! SPL Token instruction builders — dual-target.
//!
//! Each builder returns a `sol.cpi.Instruction` referencing
//! caller-provided `AccountMeta` scratch. The instruction is valid
//! for both on-chain CPI (`sol.cpi.invoke(&ix, ...)`) and off-chain
//! transaction construction.
//!
//! Reference: <https://github.com/solana-program/token/blob/main/program/src/instruction.rs>
//!
//! ## Single source of truth: `Spec`
//!
//! Every instruction is described by a comptime `Spec` value that
//! pins down the *three* numbers the on-chain wire format is built
//! from — discriminant byte, number of `AccountMeta`s, payload byte
//! count. Both the builder signatures and the CPI wrapper scratch
//! buffers derive their array lengths from these specs (via
//! `metasArray(spec)` / `dataArray(spec)`), so the constants live in
//! exactly one place.
//!
//! A `comptime` audit block at the bottom of this file re-derives
//! the canonical numbers from first principles (1-byte disc + named
//! field sizes) and `@compileError`s if any spec drifts — that's
//! the editor-typo-catcher you want when the SPL Token protocol
//! gains a new field or someone fat-fingers a count.

const std = @import("std");
const sol = @import("solana_program_sdk");
const id = @import("id.zig");
const state = @import("state.zig");

const Pubkey = sol.Pubkey;
const AccountMeta = sol.cpi.AccountMeta;
const Instruction = sol.cpi.Instruction;

pub const TokenInstruction = enum(u8) {
    initialize_mint = 0,
    initialize_account = 1,
    transfer = 3,
    mint_to = 7,
    burn = 8,
    close_account = 9,
    transfer_checked = 12,
    mint_to_checked = 14,
    burn_checked = 15,
    initialize_account3 = 18,
    initialize_mint2 = 20,
};

// =============================================================================
// Spec — single source of truth per instruction.
// =============================================================================

/// Per-instruction wire-format spec. All three fields are part of
/// the on-chain protocol — change them only if upstream SPL Token
/// changes its layout.
///
/// Consumers should read these as `transfer_spec.accounts_len` /
/// `.data_len` rather than re-deriving the numbers; the comptime
/// audit block at the bottom of this file verifies each spec
/// against the canonical 1-byte-disc + field-byte-count formula.
pub const Spec = struct {
    /// First byte of the wire-format `data` buffer.
    disc: TokenInstruction,
    /// Number of `AccountMeta`s the instruction's metas slice
    /// carries (NOT counting the token-program account itself,
    /// which is appended to the CPI `accounts` slice separately).
    accounts_len: usize,
    /// Total `data` length in bytes (1 discriminator + payload).
    data_len: usize,
};

pub const transfer_spec: Spec = .{ .disc = .transfer, .accounts_len = 3, .data_len = 1 + 8 };
pub const transfer_checked_spec: Spec = .{ .disc = .transfer_checked, .accounts_len = 4, .data_len = 1 + 8 + 1 };
pub const mint_to_spec: Spec = .{ .disc = .mint_to, .accounts_len = 3, .data_len = 1 + 8 };
pub const mint_to_checked_spec: Spec = .{ .disc = .mint_to_checked, .accounts_len = 3, .data_len = 1 + 8 + 1 };
pub const burn_spec: Spec = .{ .disc = .burn, .accounts_len = 3, .data_len = 1 + 8 };
pub const burn_checked_spec: Spec = .{ .disc = .burn_checked, .accounts_len = 3, .data_len = 1 + 8 + 1 };
pub const close_account_spec: Spec = .{ .disc = .close_account, .accounts_len = 3, .data_len = 1 };
pub const initialize_account3_spec: Spec = .{ .disc = .initialize_account3, .accounts_len = 2, .data_len = 1 + 32 };
pub const initialize_mint2_spec: Spec = .{ .disc = .initialize_mint2, .accounts_len = 1, .data_len = 1 + 1 + 32 + 4 + 32 };

/// Builder/wrapper-side helper: typed scratch-array sizes derived
/// from a `Spec`. Using the function form means every call site
/// reads `metasArray(transfer_spec)` instead of a bare `[3]`, so
/// rebinding the spec to a different instruction propagates.
pub fn metasArray(comptime spec: Spec) type {
    return [spec.accounts_len]AccountMeta;
}

pub fn dataArray(comptime spec: Spec) type {
    return [spec.data_len]u8;
}

// =============================================================================
// Comptime audit — re-derive each spec from first principles.
//
// If the SPL Token protocol ever adds a field, the canonical
// formula here will disagree with the spec's `data_len` constant
// and the build will fail with a precise message — no silent
// misencoding shipping to the cluster.
// =============================================================================

comptime {
    const PUBKEY_LEN: usize = 32;
    const COPTION_PUBKEY_LEN: usize = 4 + PUBKEY_LEN; // bincode COption<Pubkey>
    const AMOUNT_LEN: usize = 8;
    const DECIMALS_LEN: usize = 1;
    const DISC_LEN: usize = 1;

    // Each tuple = ( spec , expected accounts , expected payload-byte sum )
    const audits = .{
        .{ transfer_spec, 3, AMOUNT_LEN },
        .{ transfer_checked_spec, 4, AMOUNT_LEN + DECIMALS_LEN },
        .{ mint_to_spec, 3, AMOUNT_LEN },
        .{ mint_to_checked_spec, 3, AMOUNT_LEN + DECIMALS_LEN },
        .{ burn_spec, 3, AMOUNT_LEN },
        .{ burn_checked_spec, 3, AMOUNT_LEN + DECIMALS_LEN },
        .{ close_account_spec, 3, 0 },
        .{ initialize_account3_spec, 2, PUBKEY_LEN },
        .{ initialize_mint2_spec, 1, DECIMALS_LEN + PUBKEY_LEN + COPTION_PUBKEY_LEN },
    };

    for (audits) |a| {
        const spec: Spec = a[0];
        const want_accounts: usize = a[1];
        const want_payload: usize = a[2];
        const want_data = DISC_LEN + want_payload;
        if (spec.accounts_len != want_accounts) {
            @compileError(std.fmt.comptimePrint(
                "spl-token spec drift: {s} accounts_len={d} but protocol says {d}",
                .{ @tagName(spec.disc), spec.accounts_len, want_accounts },
            ));
        }
        if (spec.data_len != want_data) {
            @compileError(std.fmt.comptimePrint(
                "spl-token spec drift: {s} data_len={d} but protocol says {d}={d}+payload({d})",
                .{ @tagName(spec.disc), spec.data_len, want_data, DISC_LEN, want_payload },
            ));
        }
    }
}

// =============================================================================
// Comptime instruction-data builders — one extern struct per shape.
// =============================================================================

const AmountIx = sol.instruction.comptimeInstructionData(
    u8,
    extern struct { amount: u64 align(1) },
);

// `align(1)` on every field prevents the extern struct from
// inserting trailing padding to round its size up to the largest
// field's alignment — without it `sizeOf({u64, u8}) == 16`, and we
// need the on-the-wire layout to be exactly 9 bytes.
const AmountDecimalsIx = sol.instruction.comptimeInstructionData(
    u8,
    extern struct { amount: u64 align(1), decimals: u8 },
);

const InitAccount3Ix = sol.instruction.comptimeInstructionData(
    u8,
    extern struct { owner: Pubkey align(1) },
);

// Sanity-check: the comptime-builder byte counts agree with the
// matching specs. Without this, the two layers could drift silently
// (spec says 10, builder writes 17 because someone forgot
// `align(1)`). The audit fires *before* the build emits any
// program code.
comptime {
    std.debug.assert(AmountIx.bytes == transfer_spec.data_len);
    std.debug.assert(AmountIx.bytes == mint_to_spec.data_len);
    std.debug.assert(AmountIx.bytes == burn_spec.data_len);
    std.debug.assert(AmountDecimalsIx.bytes == transfer_checked_spec.data_len);
    std.debug.assert(AmountDecimalsIx.bytes == mint_to_checked_spec.data_len);
    std.debug.assert(AmountDecimalsIx.bytes == burn_checked_spec.data_len);
    std.debug.assert(InitAccount3Ix.bytes == initialize_account3_spec.data_len);
}

// =============================================================================
// Account-meta wiring — every instruction below documents its
// expected meta order and lets the caller hand us scratch storage
// so the builders are allocation-free.
// =============================================================================

/// `Transfer { amount }` — discriminant 3.
///
/// Account metas (in order):
///   0. source       — writable
///   1. destination  — writable
///   2. authority    — signer
///
/// The token program **also** accepts a multisig authority by
/// passing additional signer accounts after the authority; we
/// expose only the single-authority case here (covers 99% of usage)
/// and route through `TransferChecked` for any consumer that needs
/// the safety net. Multisig can be added later without breaking
/// this signature.
pub fn transfer(
    source: *const Pubkey,
    destination: *const Pubkey,
    authority: *const Pubkey,
    amount: u64,
    /// Caller-owned scratch — must be sized exactly to
    /// `transfer_spec.accounts_len` / `.data_len`. Both arrays are
    /// declared via `metasArray(transfer_spec)` /
    /// `dataArray(transfer_spec)` so the type checker rejects any
    /// caller whose buffer doesn't match the on-chain protocol.
    metas: *metasArray(transfer_spec),
    data: *dataArray(transfer_spec),
) Instruction {
    data.* = AmountIx.initWithDiscriminant(
        @intFromEnum(TokenInstruction.transfer),
        .{ .amount = amount },
    );
    metas[0] = AccountMeta.writable(source);
    metas[1] = AccountMeta.writable(destination);
    metas[2] = AccountMeta.signer(authority);
    return .{
        .program_id = &id.PROGRAM_ID,
        .accounts = metas,
        .data = data,
    };
}

/// `TransferChecked { amount, decimals }` — discriminant 12.
///
/// Account metas (in order):
///   0. source       — writable
///   1. mint         — readonly  (decimals checked against this)
///   2. destination  — writable
///   3. authority    — signer
pub fn transferChecked(
    source: *const Pubkey,
    mint: *const Pubkey,
    destination: *const Pubkey,
    authority: *const Pubkey,
    amount: u64,
    decimals: u8,
    metas: *metasArray(transfer_checked_spec),
    data: *dataArray(transfer_checked_spec),
) Instruction {
    data.* = AmountDecimalsIx.initWithDiscriminant(
        @intFromEnum(TokenInstruction.transfer_checked),
        .{ .amount = amount, .decimals = decimals },
    );
    metas[0] = AccountMeta.writable(source);
    metas[1] = AccountMeta.readonly(mint);
    metas[2] = AccountMeta.writable(destination);
    metas[3] = AccountMeta.signer(authority);
    return .{
        .program_id = &id.PROGRAM_ID,
        .accounts = metas,
        .data = data,
    };
}

/// `MintTo { amount }` — discriminant 7.
///
/// Account metas (in order):
///   0. mint                — writable
///   1. destination account — writable
///   2. mint authority      — signer
pub fn mintTo(
    mint: *const Pubkey,
    destination: *const Pubkey,
    authority: *const Pubkey,
    amount: u64,
    metas: *metasArray(mint_to_spec),
    data: *dataArray(mint_to_spec),
) Instruction {
    data.* = AmountIx.initWithDiscriminant(
        @intFromEnum(TokenInstruction.mint_to),
        .{ .amount = amount },
    );
    metas[0] = AccountMeta.writable(mint);
    metas[1] = AccountMeta.writable(destination);
    metas[2] = AccountMeta.signer(authority);
    return .{
        .program_id = &id.PROGRAM_ID,
        .accounts = metas,
        .data = data,
    };
}

/// `MintToChecked { amount, decimals }` — discriminant 14. Same
/// account order as `mintTo`, additional decimals safety check.
pub fn mintToChecked(
    mint: *const Pubkey,
    destination: *const Pubkey,
    authority: *const Pubkey,
    amount: u64,
    decimals: u8,
    metas: *metasArray(mint_to_checked_spec),
    data: *dataArray(mint_to_checked_spec),
) Instruction {
    data.* = AmountDecimalsIx.initWithDiscriminant(
        @intFromEnum(TokenInstruction.mint_to_checked),
        .{ .amount = amount, .decimals = decimals },
    );
    metas[0] = AccountMeta.writable(mint);
    metas[1] = AccountMeta.writable(destination);
    metas[2] = AccountMeta.signer(authority);
    return .{
        .program_id = &id.PROGRAM_ID,
        .accounts = metas,
        .data = data,
    };
}

/// `Burn { amount }` — discriminant 8.
///
/// Account metas (in order):
///   0. source    — writable
///   1. mint      — writable
///   2. authority — signer
pub fn burn(
    source: *const Pubkey,
    mint: *const Pubkey,
    authority: *const Pubkey,
    amount: u64,
    metas: *metasArray(burn_spec),
    data: *dataArray(burn_spec),
) Instruction {
    data.* = AmountIx.initWithDiscriminant(
        @intFromEnum(TokenInstruction.burn),
        .{ .amount = amount },
    );
    metas[0] = AccountMeta.writable(source);
    metas[1] = AccountMeta.writable(mint);
    metas[2] = AccountMeta.signer(authority);
    return .{
        .program_id = &id.PROGRAM_ID,
        .accounts = metas,
        .data = data,
    };
}

/// `BurnChecked { amount, decimals }` — discriminant 15.
pub fn burnChecked(
    source: *const Pubkey,
    mint: *const Pubkey,
    authority: *const Pubkey,
    amount: u64,
    decimals: u8,
    metas: *metasArray(burn_checked_spec),
    data: *dataArray(burn_checked_spec),
) Instruction {
    data.* = AmountDecimalsIx.initWithDiscriminant(
        @intFromEnum(TokenInstruction.burn_checked),
        .{ .amount = amount, .decimals = decimals },
    );
    metas[0] = AccountMeta.writable(source);
    metas[1] = AccountMeta.writable(mint);
    metas[2] = AccountMeta.signer(authority);
    return .{
        .program_id = &id.PROGRAM_ID,
        .accounts = metas,
        .data = data,
    };
}

/// `CloseAccount` — discriminant 9.
///
/// Account metas (in order):
///   0. account   — writable (the token account being closed)
///   1. destination — writable (where the rent lamports go)
///   2. authority   — signer  (close authority or owner)
pub fn closeAccount(
    account: *const Pubkey,
    destination: *const Pubkey,
    authority: *const Pubkey,
    metas: *metasArray(close_account_spec),
    data: *dataArray(close_account_spec),
) Instruction {
    data[0] = @intFromEnum(TokenInstruction.close_account);
    metas[0] = AccountMeta.writable(account);
    metas[1] = AccountMeta.writable(destination);
    metas[2] = AccountMeta.signer(authority);
    return .{
        .program_id = &id.PROGRAM_ID,
        .accounts = metas,
        .data = data,
    };
}

/// `InitializeAccount3 { owner }` — discriminant 18.
///
/// Account metas (in order):
///   0. account — writable
///   1. mint    — readonly
///
/// (`Account3` skips the rent sysvar and the separate "owner"
/// account that `InitializeAccount` requires.)
pub fn initializeAccount3(
    account: *const Pubkey,
    mint: *const Pubkey,
    owner: *const Pubkey,
    metas: *metasArray(initialize_account3_spec),
    data: *dataArray(initialize_account3_spec),
) Instruction {
    data.* = InitAccount3Ix.initWithDiscriminant(
        @intFromEnum(TokenInstruction.initialize_account3),
        .{ .owner = owner.* },
    );
    metas[0] = AccountMeta.writable(account);
    metas[1] = AccountMeta.readonly(mint);
    return .{
        .program_id = &id.PROGRAM_ID,
        .accounts = metas,
        .data = data,
    };
}

/// `InitializeMint2 { decimals, mint_authority, freeze_authority }`
/// — discriminant 20.
///
/// Account metas: just the mint account itself (writable). Pass
/// `null` for `freeze_authority` to leave it disabled.
///
/// Body layout: `[disc(1), decimals(1), mint_auth(32),
/// freeze_tag(4 LE), freeze_pk(32)]`. When `freeze_authority` is
/// `null`, `freeze_tag` is zero and the 32 freeze-pubkey bytes are
/// zero-padding (still part of the on-the-wire payload — `Mint2`
/// always reads the fixed 67 bytes).
pub fn initializeMint2(
    mint: *const Pubkey,
    decimals: u8,
    mint_authority: *const Pubkey,
    freeze_authority: ?*const Pubkey,
    metas: *metasArray(initialize_mint2_spec),
    data: *dataArray(initialize_mint2_spec),
) Instruction {
    data[0] = @intFromEnum(TokenInstruction.initialize_mint2);
    data[1] = decimals;
    @memcpy(data[2..34], mint_authority);
    if (freeze_authority) |fa| {
        std.mem.writeInt(u32, data[34..38], state.COPTION_SOME, .little);
        @memcpy(data[38..70], fa);
    } else {
        std.mem.writeInt(u32, data[34..38], state.COPTION_NONE, .little);
        @memset(data[38..70], 0);
    }
    metas[0] = AccountMeta.writable(mint);
    return .{
        .program_id = &id.PROGRAM_ID,
        .accounts = metas,
        .data = data,
    };
}

// =============================================================================
// Tests — byte-level fidelity vs. canonical Rust encoding.
// =============================================================================

test "transfer: 9-byte body with correct discriminant + LE amount" {
    const a: Pubkey = .{1} ** 32;
    const b: Pubkey = .{2} ** 32;
    const c: Pubkey = .{3} ** 32;
    var metas: [3]AccountMeta = undefined;
    var data: [9]u8 = undefined;
    const ix = transfer(&a, &b, &c, 12345, &metas, &data);

    try std.testing.expectEqual(@as(u8, 3), data[0]);
    try std.testing.expectEqual(@as(u64, 12345), std.mem.readInt(u64, data[1..9], .little));
    try std.testing.expectEqual(@as(usize, 3), ix.accounts.len);
    // metas: source writable; dest writable; authority signer
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[0].is_writable);
    try std.testing.expectEqual(@as(u8, 0), ix.accounts[0].is_signer);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[1].is_writable);
    try std.testing.expectEqual(@as(u8, 0), ix.accounts[2].is_writable);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[2].is_signer);
    try std.testing.expectEqualSlices(u8, &id.PROGRAM_ID, ix.program_id);
}

test "transferChecked: 10-byte body" {
    const a: Pubkey = .{1} ** 32;
    const m: Pubkey = .{4} ** 32;
    const b: Pubkey = .{2} ** 32;
    const c: Pubkey = .{3} ** 32;
    var metas: [4]AccountMeta = undefined;
    var data: [10]u8 = undefined;
    _ = transferChecked(&a, &m, &b, &c, 999, 6, &metas, &data);

    try std.testing.expectEqual(@as(u8, 12), data[0]);
    try std.testing.expectEqual(@as(u64, 999), std.mem.readInt(u64, data[1..9], .little));
    try std.testing.expectEqual(@as(u8, 6), data[9]);
    // mint must be readonly (no writable, no signer)
    try std.testing.expectEqual(@as(u8, 0), metas[1].is_writable);
    try std.testing.expectEqual(@as(u8, 0), metas[1].is_signer);
}

test "mintTo / burn / closeAccount discriminants" {
    const a: Pubkey = .{1} ** 32;
    const b: Pubkey = .{2} ** 32;
    const c: Pubkey = .{3} ** 32;

    var metas: [3]AccountMeta = undefined;
    var data9: [9]u8 = undefined;
    _ = mintTo(&a, &b, &c, 7, &metas, &data9);
    try std.testing.expectEqual(@as(u8, 7), data9[0]);

    _ = burn(&a, &b, &c, 8, &metas, &data9);
    try std.testing.expectEqual(@as(u8, 8), data9[0]);

    var data1: [1]u8 = undefined;
    _ = closeAccount(&a, &b, &c, &metas, &data1);
    try std.testing.expectEqual(@as(u8, 9), data1[0]);
}

test "initializeMint2: Some-vs-None freeze authority encoding" {
    const m: Pubkey = .{0x11} ** 32;
    const auth: Pubkey = .{0x22} ** 32;
    const fa: Pubkey = .{0x33} ** 32;
    var metas: [1]AccountMeta = undefined;
    var data: dataArray(initialize_mint2_spec) = undefined;

    _ = initializeMint2(&m, 9, &auth, &fa, &metas, &data);
    try std.testing.expectEqual(@as(u8, 20), data[0]);
    try std.testing.expectEqual(@as(u8, 9), data[1]);
    try std.testing.expectEqual(state.COPTION_SOME, std.mem.readInt(u32, data[34..38], .little));
    try std.testing.expectEqualSlices(u8, &fa, data[38..70]);

    _ = initializeMint2(&m, 0, &auth, null, &metas, &data);
    try std.testing.expectEqual(state.COPTION_NONE, std.mem.readInt(u32, data[34..38], .little));
    for (data[38..70]) |b| try std.testing.expectEqual(@as(u8, 0), b);
}

test "initializeAccount3: 33-byte body carries owner pubkey" {
    const acct: Pubkey = .{0xAA} ** 32;
    const mint: Pubkey = .{0xBB} ** 32;
    const owner: Pubkey = .{0xCC} ** 32;
    var metas: [2]AccountMeta = undefined;
    var data: [33]u8 = undefined;
    _ = initializeAccount3(&acct, &mint, &owner, &metas, &data);
    try std.testing.expectEqual(@as(u8, 18), data[0]);
    try std.testing.expectEqualSlices(u8, &owner, data[1..33]);
}
