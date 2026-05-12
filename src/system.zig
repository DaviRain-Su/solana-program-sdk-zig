//! System Program CPI wrappers
//!
//! High-level Zig API for common System Program operations.
//!
//! ⚠️ WARNING (Zig 0.16 BPF): Always use stack copies for Program IDs.
//! Module-scope const arrays may be placed at invalid low addresses.

const std = @import("std");
const pubkey = @import("pubkey.zig");
const account_mod = @import("account.zig");
const cpi = @import("cpi.zig");
const program_error = @import("program_error.zig");
const instruction = @import("instruction.zig");

const Pubkey = pubkey.Pubkey;
const CpiAccountInfo = account_mod.CpiAccountInfo;
const ProgramResult = program_error.ProgramResult;

/// System Program instruction discriminants
pub const SystemInstruction = enum(u32) {
    CreateAccount = 0,
    Assign = 1,
    Transfer = 2,
    CreateAccountWithSeed = 3,
    AdvanceNonceAccount = 4,
    WithdrawNonceAccount = 5,
    InitializeNonceAccount = 6,
    AuthorizeNonceAccount = 7,
    Allocate = 8,
    AllocateWithSeed = 9,
    AssignWithSeed = 10,
    TransferWithSeed = 11,
    UpgradeNonceAccount = 12,
};

/// System Program ID (all zeros).
///
/// ⚠️ On Zig 0.16 BPF builds, module-scope const arrays can land at
/// invalid low VM addresses, so you generally must **not** take this
/// constant's address and pass it to a syscall directly. For CPI calls,
/// always derive the program ID from the System Program account that
/// the caller passed into the program's input (e.g.
/// `system_program.key()` from the parsed `CpiAccountInfo`). The
/// high-level wrappers in this module enforce that pattern.
pub const SYSTEM_PROGRAM_ID: Pubkey = .{0} ** 32;

// Compile-time instruction data builders
const CreateAccountData = instruction.comptimeInstructionData(
    u32,
    extern struct {
        lamports: u64,
        space: u64,
        owner: Pubkey,
    },
);

const TransferData = instruction.comptimeInstructionData(
    u32,
    extern struct {
        lamports: u64,
    },
);

const AssignData = instruction.comptimeInstructionData(
    u32,
    extern struct {
        owner: Pubkey,
    },
);

const AllocateData = instruction.comptimeInstructionData(
    u32,
    extern struct {
        space: u64,
    },
);

/// Create a new account via System Program CPI.
///
/// Accounts:
/// - `from`: signer, writable — pays for the new account
/// - `to`: signer, writable — the account being created
/// - `system_program`: read-only — the System Program account, parsed
///   from the program's input. Required so the syscall can resolve
///   `instruction.program_id` against a known account.
pub fn createAccount(
    from: CpiAccountInfo,
    to: CpiAccountInfo,
    system_program: CpiAccountInfo,
    lamports: u64,
    space: u64,
    owner: *const Pubkey,
) ProgramResult {
    const ix_data = CreateAccountData.initWithDiscriminant(
        @intFromEnum(SystemInstruction.CreateAccount),
        .{ .lamports = lamports, .space = space, .owner = owner.* },
    );

    const account_metas = [_]cpi.AccountMeta{
        .{ .pubkey = from.key(), .is_writable = 1, .is_signer = 1 },
        .{ .pubkey = to.key(), .is_writable = 1, .is_signer = 1 },
    };

    const ix = cpi.Instruction{
        .program_id = system_program.key(),
        .accounts = &account_metas,
        .data = &ix_data,
    };

    // We construct both `account_metas` and the accounts slice inline,
    // so the bounds check in `cpi.invoke` is provably-true at compile
    // time — skip it.
    try cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ from, to, system_program });
}

/// Create a new account with PDA signing.
///
/// `signers_seeds` follows `cpi.invokeSigned`'s shape: one entry per PDA
/// signer, each containing the seed slices used to derive that PDA.
///
/// For maximum CU performance — typical 1-signer, 3-seed PDA case —
/// use `createAccountSignedRaw` instead and build the `Signer` array
/// at the call site. This wrapper has to stage the seeds through a
/// 128-entry scratch buffer.
pub fn createAccountSigned(
    from: CpiAccountInfo,
    to: CpiAccountInfo,
    system_program: CpiAccountInfo,
    lamports: u64,
    space: u64,
    owner: *const Pubkey,
    signers_seeds: []const []const []const u8,
) ProgramResult {
    const ix_data = CreateAccountData.initWithDiscriminant(
        @intFromEnum(SystemInstruction.CreateAccount),
        .{ .lamports = lamports, .space = space, .owner = owner.* },
    );

    const account_metas = [_]cpi.AccountMeta{
        .{ .pubkey = from.key(), .is_writable = 1, .is_signer = 1 },
        .{ .pubkey = to.key(), .is_writable = 1, .is_signer = 1 },
    };

    const ix = cpi.Instruction{
        .program_id = system_program.key(),
        .accounts = &account_metas,
        .data = &ix_data,
    };

    try cpi.invokeSigned(&ix, &[_]CpiAccountInfo{ from, to, system_program }, signers_seeds);
}

/// Fast-path PDA-signed CreateAccount: takes pre-built `Signer`s in
/// the runtime's C-ABI shape, skipping the seed-staging copy that
/// `createAccountSigned` performs.
///
/// ```zig
/// const bump_seed = [_]u8{bump};
/// const seeds = [_]sol.cpi.Seed{
///     .from("vault"),
///     .from(auth_key[0..]),
///     .from(&bump_seed),
/// };
/// const signer = sol.cpi.Signer.from(&seeds);
/// try sol.system.createAccountSignedRaw(
///     payer.toCpiInfo(),
///     vault.toCpiInfo(),
///     system_program.toCpiInfo(),
///     lamports,
///     space,
///     &MY_PROGRAM_ID,
///     &.{signer},
/// );
/// ```
pub fn createAccountSignedRaw(
    from: CpiAccountInfo,
    to: CpiAccountInfo,
    system_program: CpiAccountInfo,
    lamports: u64,
    space: u64,
    owner: *const Pubkey,
    signers: []const cpi.Signer,
) ProgramResult {
    const ix_data = CreateAccountData.initWithDiscriminant(
        @intFromEnum(SystemInstruction.CreateAccount),
        .{ .lamports = lamports, .space = space, .owner = owner.* },
    );

    const account_metas = [_]cpi.AccountMeta{
        .{ .pubkey = from.key(), .is_writable = 1, .is_signer = 1 },
        .{ .pubkey = to.key(), .is_writable = 1, .is_signer = 1 },
    };

    const ix = cpi.Instruction{
        .program_id = system_program.key(),
        .accounts = &account_metas,
        .data = &ix_data,
    };

    try cpi.invokeSignedRaw(
        &ix,
        &[_]CpiAccountInfo{ from, to, system_program },
        signers,
    );
}

/// Transfer lamports via System Program CPI.
///
/// Accounts:
/// - `from`: signer, writable — source of lamports
/// - `to`: writable — destination for lamports
/// - `system_program`: read-only — the System Program account, parsed
///   from the program's input.
pub fn transfer(
    from: CpiAccountInfo,
    to: CpiAccountInfo,
    system_program: CpiAccountInfo,
    lamports: u64,
) ProgramResult {
    const ix_data = TransferData.initWithDiscriminant(
        @intFromEnum(SystemInstruction.Transfer),
        .{ .lamports = lamports },
    );

    const account_metas = [_]cpi.AccountMeta{
        .{ .pubkey = from.key(), .is_writable = 1, .is_signer = 1 },
        .{ .pubkey = to.key(), .is_writable = 1, .is_signer = 0 },
    };

    const ix = cpi.Instruction{
        .program_id = system_program.key(),
        .accounts = &account_metas,
        .data = &ix_data,
    };

    // We construct both `account_metas` and the accounts slice inline,
    // so the bounds check in `cpi.invoke` is provably-true at compile
    // time — skip it.
    try cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ from, to, system_program });
}

/// Assign a new owner to an account.
pub fn assign(
    account: CpiAccountInfo,
    system_program: CpiAccountInfo,
    owner: *const Pubkey,
) ProgramResult {
    const ix_data = AssignData.initWithDiscriminant(
        @intFromEnum(SystemInstruction.Assign),
        .{ .owner = owner.* },
    );

    const account_metas = [_]cpi.AccountMeta{
        .{ .pubkey = account.key(), .is_writable = 1, .is_signer = 1 },
    };

    const ix = cpi.Instruction{
        .program_id = system_program.key(),
        .accounts = &account_metas,
        .data = &ix_data,
    };

    try cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ account, system_program });
}

/// Allocate space in an account.
pub fn allocate(
    account: CpiAccountInfo,
    system_program: CpiAccountInfo,
    space: u64,
) ProgramResult {
    const ix_data = AllocateData.initWithDiscriminant(
        @intFromEnum(SystemInstruction.Allocate),
        .{ .space = space },
    );

    const account_metas = [_]cpi.AccountMeta{
        .{ .pubkey = account.key(), .is_writable = 1, .is_signer = 1 },
    };

    const ix = cpi.Instruction{
        .program_id = system_program.key(),
        .accounts = &account_metas,
        .data = &ix_data,
    };

    try cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ account, system_program });
}

// Note: there is no System Program `Realloc` instruction. Accounts that
// the program owns can be resized in-place (within
// `MAX_PERMITTED_DATA_INCREASE`) by writing directly to the runtime's
// `data_len` slot — no CPI is required. We intentionally do not expose
// a `system.realloc` wrapper to avoid suggesting otherwise.

/// Rent-exempt-aware account creation helper.
///
/// Computes the rent-exempt minimum balance at runtime via the Rent
/// sysvar and forwards to `createAccount` / `createAccountSigned`.
///
/// `space` is `u64` (not `comptime`) so dynamic sizes work; pass a
/// comptime-known constant to let LLVM fold the surrounding arithmetic.
///
/// Usage (non-PDA new account):
/// ```zig
/// try sol.system.createRentExempt(.{
///     .payer = a.payer,
///     .new_account = a.vault,
///     .system_program = a.system_program,
///     .space = @sizeOf(VaultState),
///     .owner = &MY_PROGRAM_ID,
/// });
/// ```
///
/// Usage (PDA new account — `new_account` must be a PDA):
/// ```zig
/// const bump_seed = [_]u8{bump};
/// try sol.system.createRentExempt(.{
///     .payer = a.payer,
///     .new_account = a.vault,
///     .system_program = a.system_program,
///     .space = @sizeOf(VaultState),
///     .owner = &MY_PROGRAM_ID,
///     .signer_seeds = &.{ &.{ "vault", a.payer.key().*[0..], &bump_seed } },
/// });
/// ```
pub const CreateRentExemptArgs = struct {
    payer: CpiAccountInfo,
    new_account: CpiAccountInfo,
    system_program: CpiAccountInfo,
    space: u64,
    owner: *const Pubkey,
    /// Optional PDA signer seeds. Pass `null` if the new account is a
    /// fresh keypair signed by the user; pass seeds when the new
    /// account is a PDA whose signature must come from this program.
    signer_seeds: ?[]const []const []const u8 = null,
};

pub fn createRentExempt(args: CreateRentExemptArgs) ProgramResult {
    const rent_mod = @import("rent.zig");
    const rent_data = rent_mod.Rent.get() catch return error.UnsupportedSysvar;
    const lamports = rent_data.getMinimumBalance(args.space);

    if (args.signer_seeds) |seeds| {
        return createAccountSigned(
            args.payer,
            args.new_account,
            args.system_program,
            lamports,
            args.space,
            args.owner,
            seeds,
        );
    }

    return createAccount(
        args.payer,
        args.new_account,
        args.system_program,
        lamports,
        args.space,
        args.owner,
    );
}

/// Comptime rent-exempt account creation with pre-built PDA signers.
///
/// `space` is a `comptime` parameter so the rent-exempt minimum
/// balance is computed at build time and baked into the binary as a
/// single u64 immediate — no `sol_get_rent_sysvar` syscall (~85 CU)
/// runs at execution time.
///
/// This assumes the cluster's rent parameters never change from the
/// canonical values (lamports_per_byte_year = 3480,
/// exemption_threshold = 2.0). They've been stable since genesis and
/// changing them would require a feature gate, so for >99.99% of
/// programs this is a free win. If you genuinely need to read live
/// rent params (e.g. you're writing tooling that has to handle
/// future cluster changes), use `createRentExemptRaw` instead.
///
/// ```zig
/// const seeds = [_]sol.cpi.Seed{ .from("vault"), .from(auth_key[0..]), .from(&bump_seed) };
/// const signer = sol.cpi.Signer.from(&seeds);
/// try sol.system.createRentExemptComptimeRaw(
///     .{ .payer = ..., .new_account = ..., .system_program = ..., .owner = &PROGRAM_ID },
///     @sizeOf(VaultState),
///     &.{signer},
/// );
/// ```
pub fn createRentExemptComptimeRaw(
    args: struct {
        payer: CpiAccountInfo,
        new_account: CpiAccountInfo,
        system_program: CpiAccountInfo,
        owner: *const Pubkey,
    },
    comptime space: u64,
    signers: []const cpi.Signer,
) ProgramResult {
    const rent_mod = @import("rent.zig");
    // Comptime-folded: (128 + space) * 3480 * 2.
    const lamports: u64 = comptime blk: {
        const total: u64 = rent_mod.Rent.account_storage_overhead + space;
        break :blk total * rent_mod.Rent.default_lamports_per_byte_year * 2;
    };

    return createAccountSignedRaw(
        args.payer,
        args.new_account,
        args.system_program,
        lamports,
        space,
        args.owner,
        signers,
    );
}

/// Fast-path rent-exempt account creation with pre-built PDA signers.
///
/// Saves ~80-120 CU vs. `createRentExempt` on the common PDA case
/// by handing the runtime the C-ABI signer descriptors directly,
/// skipping the `[]const []const []const u8` → C-ABI staging copy.
///
/// ```zig
/// const bump_seed = [_]u8{bump};
/// const seeds = [_]sol.cpi.Seed{
///     .from("vault"),
///     .from(auth_key[0..]),
///     .from(&bump_seed),
/// };
/// const signer = sol.cpi.Signer.from(&seeds);
/// try sol.system.createRentExemptRaw(.{
///     .payer = a.payer,
///     .new_account = a.vault,
///     .system_program = a.system_program,
///     .space = @sizeOf(VaultState),
///     .owner = &MY_PROGRAM_ID,
/// }, &.{signer});
/// ```
pub fn createRentExemptRaw(
    args: CreateRentExemptArgs,
    signers: []const cpi.Signer,
) ProgramResult {
    const rent_mod = @import("rent.zig");
    const rent_data = rent_mod.Rent.get() catch return error.UnsupportedSysvar;
    const lamports = rent_data.getMinimumBalance(args.space);

    return createAccountSignedRaw(
        args.payer,
        args.new_account,
        args.system_program,
        lamports,
        args.space,
        args.owner,
        signers,
    );
}

/// Create account with seed.
pub fn createAccountWithSeed(
    from: CpiAccountInfo,
    to: CpiAccountInfo,
    system_program: CpiAccountInfo,
    base: *const Pubkey,
    seed: []const u8,
    lamports: u64,
    space: u64,
    owner: *const Pubkey,
) ProgramResult {
    // Variable-length seed requires runtime construction
    var ix_data: [84]u8 = undefined;
    @memset(&ix_data, 0);

    std.mem.writeInt(u32, ix_data[0..4], @intFromEnum(SystemInstruction.CreateAccountWithSeed), .little);
    @memcpy(ix_data[4..36], base[0..32]);
    std.mem.writeInt(u64, ix_data[36..44], seed.len, .little);
    @memcpy(ix_data[44..44 + seed.len], seed);
    const lamports_offset = 44 + seed.len;
    std.mem.writeInt(u64, ix_data[lamports_offset..][0..8], lamports, .little);
    std.mem.writeInt(u64, ix_data[lamports_offset + 8..][0..8], space, .little);
    @memcpy(ix_data[lamports_offset + 16..][0..32], owner[0..32]);

    const account_metas = [_]cpi.AccountMeta{
        .{ .pubkey = from.key(), .is_writable = 1, .is_signer = 1 },
        .{ .pubkey = to.key(), .is_writable = 1, .is_signer = 0 },
    };

    const ix = cpi.Instruction{
        .program_id = system_program.key(),
        .accounts = &account_metas,
        .data = ix_data[0 .. 44 + seed.len + 16 + 32],
    };

    // We construct both `account_metas` and the accounts slice inline,
    // so the bounds check in `cpi.invoke` is provably-true at compile
    // time — skip it.
    try cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ from, to, system_program });
}

// =============================================================================
// Tests
// =============================================================================

test "system: SYSTEM_PROGRAM_ID is all zero" {
    const expected: Pubkey = .{0} ** 32;
    try std.testing.expectEqual(expected, SYSTEM_PROGRAM_ID);
}

test "system: instruction data format" {
    const ix_data = CreateAccountData.initWithDiscriminant(
        @intFromEnum(SystemInstruction.CreateAccount),
        .{ .lamports = 500, .space = 128, .owner = .{3} ** 32 },
    );

    try std.testing.expectEqual(@as(u32, 0), std.mem.readInt(u32, ix_data[0..4], .little));
    try std.testing.expectEqual(@as(u64, 500), std.mem.readInt(u64, ix_data[4..12], .little));
    try std.testing.expectEqual(@as(u64, 128), std.mem.readInt(u64, ix_data[12..20], .little));
    const expected_owner: Pubkey = .{3} ** 32;
    try std.testing.expectEqual(expected_owner, ix_data[20..52].*);
}

test "system: transfer instruction data" {
    const ix_data = TransferData.initWithDiscriminant(
        @intFromEnum(SystemInstruction.Transfer),
        .{ .lamports = 100 },
    );

    try std.testing.expectEqual(@as(u32, 2), std.mem.readInt(u32, ix_data[0..4], .little));
    try std.testing.expectEqual(@as(u64, 100), std.mem.readInt(u64, ix_data[4..12], .little));
}

test "system: SystemInstruction discriminant values" {
    try std.testing.expectEqual(@as(u32, 0), @intFromEnum(SystemInstruction.CreateAccount));
    try std.testing.expectEqual(@as(u32, 1), @intFromEnum(SystemInstruction.Assign));
    try std.testing.expectEqual(@as(u32, 2), @intFromEnum(SystemInstruction.Transfer));
    try std.testing.expectEqual(@as(u32, 3), @intFromEnum(SystemInstruction.CreateAccountWithSeed));
}
