//! SPL Token instruction builders — dual-target.
//!
//! Each builder returns a `sol.cpi.Instruction` referencing
//! caller-provided `AccountMeta` scratch. The instruction is valid
//! for both on-chain CPI (`sol.cpi.invoke(&ix, ...)`) and off-chain
//! transaction construction.
//!
//! Reference: <https://github.com/solana-program/token/blob/main/program/src/instruction.rs>
//!
//! ## Discriminant table (first byte of `data`)
//!
//! |  # | Instruction        | Body                                         |
//! |---:|--------------------|----------------------------------------------|
//! |  3 | Transfer           | `u64 amount`                                 |
//! |  7 | MintTo             | `u64 amount`                                 |
//! |  8 | Burn               | `u64 amount`                                 |
//! |  9 | CloseAccount       | —                                            |
//! | 12 | TransferChecked    | `u64 amount, u8 decimals`                    |
//! | 14 | MintToChecked      | `u64 amount, u8 decimals`                    |
//! | 15 | BurnChecked        | `u64 amount, u8 decimals`                    |
//! | 18 | InitializeAccount3 | `Pubkey owner`                               |
//! | 20 | InitializeMint2    | `u8 decimals, Pubkey mint_auth, COption fa`  |
//!
//! We use the "3" / "2" suffixed initialize-* variants because they
//! drop the rent sysvar requirement and embed the owner /
//! freeze-authority directly in the data payload — they're what
//! modern client code (and Token-2022) emits.

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

// `InitializeMint2` has a variable suffix (COption<Pubkey> for the
// freeze authority — 4-byte tag + 32 bytes that are zero when the
// option is None). Easier to fill byte-by-byte; total = 67 bytes.
const INIT_MINT2_LEN: usize = 1 + 1 + 32 + 4 + 32;

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
    /// Caller-owned scratch buffer for the three account metas.
    metas: *[3]AccountMeta,
    /// Caller-owned scratch buffer for the 9-byte instruction body
    /// (1 disc + 8 amount). Keeping the buffer external lets the
    /// returned `Instruction` outlive this function without an
    /// allocator.
    data: *[1 + 8]u8,
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
    metas: *[4]AccountMeta,
    data: *[1 + 8 + 1]u8,
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
    metas: *[3]AccountMeta,
    data: *[1 + 8]u8,
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
    metas: *[3]AccountMeta,
    data: *[1 + 8 + 1]u8,
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
    metas: *[3]AccountMeta,
    data: *[1 + 8]u8,
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
    metas: *[3]AccountMeta,
    data: *[1 + 8 + 1]u8,
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
    metas: *[3]AccountMeta,
    data: *[1]u8,
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
    metas: *[2]AccountMeta,
    data: *[1 + 32]u8,
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
    metas: *[1]AccountMeta,
    data: *[INIT_MINT2_LEN]u8,
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
    var data: [INIT_MINT2_LEN]u8 = undefined;

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
