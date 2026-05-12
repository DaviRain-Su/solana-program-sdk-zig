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
const pda = @import("pda.zig");

const Pubkey = pubkey.Pubkey;
const CpiAccountInfo = account_mod.CpiAccountInfo;
const ProgramResult = program_error.ProgramResult;
const MAX_SEED_LEN = pda.MAX_SEED_LEN;
const DISCRIMINANT_BYTES = @sizeOf(u32);
const U64_BYTES = @sizeOf(u64);
const PUBKEY_BYTES = @sizeOf(Pubkey);
pub const NONCE_STATE_SIZE: u64 = 80;

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

const CreateAccountPayload = extern struct {
    lamports: u64,
    space: u64,
    owner: Pubkey,
};

const TransferPayload = extern struct {
    lamports: u64,
};

const AssignPayload = extern struct {
    owner: Pubkey,
};

const AllocatePayload = extern struct {
    space: u64,
};

const NonceAuthorityPayload = extern struct {
    authority: Pubkey,
};

fn fixedIxData(comptime discriminant: SystemInstruction, comptime Payload: type, payload: Payload) [DISCRIMINANT_BYTES + @sizeOf(Payload)]u8 {
    return instruction.comptimeInstructionData(u32, Payload).initWithDiscriminant(
        @intFromEnum(discriminant),
        payload,
    );
}

fn variableSeedIxCapacity(comptime fixed_bytes_without_seed: usize) usize {
    return fixed_bytes_without_seed + MAX_SEED_LEN;
}

fn StackIxDataWriter(comptime capacity: usize) type {
    return struct {
        buf: [capacity]u8 = undefined,
        len: usize = 0,

        const Self = @This();

        inline fn init() Self {
            return .{};
        }

        inline fn writeDiscriminant(self: *Self, discriminant: SystemInstruction) void {
            self.writeU32(@intFromEnum(discriminant));
        }

        inline fn writeU32(self: *Self, value: u32) void {
            std.mem.writeInt(u32, self.buf[self.len..][0..DISCRIMINANT_BYTES], value, .little);
            self.len += DISCRIMINANT_BYTES;
        }

        inline fn writeU64(self: *Self, value: u64) void {
            std.mem.writeInt(u64, self.buf[self.len..][0..U64_BYTES], value, .little);
            self.len += U64_BYTES;
        }

        inline fn writePubkey(self: *Self, key: *const Pubkey) void {
            self.writeBytes(key[0..PUBKEY_BYTES]);
        }

        inline fn writeSeed(self: *Self, seed: []const u8) void {
            self.writeU64(seed.len);
            self.writeBytes(seed);
        }

        inline fn writeBytes(self: *Self, bytes: []const u8) void {
            @memcpy(self.buf[self.len..][0..bytes.len], bytes);
            self.len += bytes.len;
        }

        inline fn written(self: *const Self) []const u8 {
            return self.buf[0..self.len];
        }
    };
}

fn discriminantOnlyData(comptime discriminant: SystemInstruction) [DISCRIMINANT_BYTES]u8 {
    return instruction.comptimeDiscriminantOnly(@as(u32, @intFromEnum(discriminant)));
}

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
    const ix_data = fixedIxData(SystemInstruction.CreateAccount, CreateAccountPayload, .{ .lamports = lamports, .space = space, .owner = owner.* });

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.signerWritable(from.key()),
        cpi.AccountMeta.signerWritable(to.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(system_program, &account_metas, &ix_data);

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
    const ix_data = fixedIxData(SystemInstruction.CreateAccount, CreateAccountPayload, .{ .lamports = lamports, .space = space, .owner = owner.* });

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.signerWritable(from.key()),
        cpi.AccountMeta.signerWritable(to.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(system_program, &account_metas, &ix_data);

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
    const ix_data = fixedIxData(SystemInstruction.CreateAccount, CreateAccountPayload, .{ .lamports = lamports, .space = space, .owner = owner.* });

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.signerWritable(from.key()),
        cpi.AccountMeta.signerWritable(to.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(system_program, &account_metas, &ix_data);

    try cpi.invokeSignedRaw(
        &ix,
        &[_]CpiAccountInfo{ from, to, system_program },
        signers,
    );
}

/// Single-PDA fast path for CreateAccount. Accepts a comptime tuple of
/// seed values and builds the raw signer descriptors inline, so callers
/// can keep the low-CU path without spelling out `Seed.from*` and
/// `Signer.from` at the call site.
///
/// ```zig
/// const bump_seed = [_]u8{bump};
/// try sol.system.createAccountSignedSingle(
///     payer.toCpiInfo(),
///     vault.toCpiInfo(),
///     system_program.toCpiInfo(),
///     lamports,
///     space,
///     &MY_PROGRAM_ID,
///     .{ "vault", authority.key(), &bump_seed },
/// );
/// ```
pub inline fn createAccountSignedSingle(
    from: CpiAccountInfo,
    to: CpiAccountInfo,
    system_program: CpiAccountInfo,
    lamports: u64,
    space: u64,
    owner: *const Pubkey,
    signer_seeds: anytype,
) ProgramResult {
    const ix_data = fixedIxData(SystemInstruction.CreateAccount, CreateAccountPayload, .{ .lamports = lamports, .space = space, .owner = owner.* });

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.signerWritable(from.key()),
        cpi.AccountMeta.signerWritable(to.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(system_program, &account_metas, &ix_data);

    try cpi.invokeSignedSingle(
        &ix,
        &[_]CpiAccountInfo{ from, to, system_program },
        signer_seeds,
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
    const ix_data = fixedIxData(SystemInstruction.Transfer, TransferPayload, .{ .lamports = lamports });

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.signerWritable(from.key()),
        cpi.AccountMeta.writable(to.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(system_program, &account_metas, &ix_data);

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
    const ix_data = fixedIxData(SystemInstruction.Assign, AssignPayload, .{ .owner = owner.* });

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.signerWritable(account.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(system_program, &account_metas, &ix_data);

    try cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ account, system_program });
}

/// Allocate space in an account.
pub fn allocate(
    account: CpiAccountInfo,
    system_program: CpiAccountInfo,
    space: u64,
) ProgramResult {
    const ix_data = fixedIxData(SystemInstruction.Allocate, AllocatePayload, .{ .space = space });

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.signerWritable(account.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(system_program, &account_metas, &ix_data);

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

/// Single-PDA fast path for comptime rent-exempt account creation.
///
/// Same win profile as `createRentExemptComptimeRaw`, but accepts a
/// comptime tuple of seed values for the common 1-signer PDA case.
///
/// ```zig
/// const bump_seed = [_]u8{bump};
/// try sol.system.createRentExemptComptimeSingle(.{
///     .payer = a.payer,
///     .new_account = a.vault,
///     .system_program = a.system_program,
///     .owner = &MY_PROGRAM_ID,
/// }, @sizeOf(VaultState), .{ "vault", authority.key(), &bump_seed });
/// ```
pub inline fn createRentExemptComptimeSingle(
    args: struct {
        payer: CpiAccountInfo,
        new_account: CpiAccountInfo,
        system_program: CpiAccountInfo,
        owner: *const Pubkey,
    },
    comptime space: u64,
    signer_seeds: anytype,
) ProgramResult {
    const rent_mod = @import("rent.zig");
    const lamports: u64 = comptime blk: {
        const total: u64 = rent_mod.Rent.account_storage_overhead + space;
        break :blk total * rent_mod.Rent.default_lamports_per_byte_year * 2;
    };

    return createAccountSignedSingle(
        args.payer,
        args.new_account,
        args.system_program,
        lamports,
        space,
        args.owner,
        signer_seeds,
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
///
/// The System Program encodes `base` into instruction data; there is no
/// separate base account meta for this instruction, so the CPI wrapper
/// only needs the funding account, destination account, and System
/// Program account.
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
    if (seed.len > MAX_SEED_LEN) return error.MaxSeedLengthExceeded;

    var ix_data = StackIxDataWriter(variableSeedIxCapacity(
        DISCRIMINANT_BYTES + PUBKEY_BYTES + U64_BYTES + U64_BYTES + U64_BYTES + PUBKEY_BYTES,
    )).init();
    ix_data.writeDiscriminant(SystemInstruction.CreateAccountWithSeed);
    ix_data.writePubkey(base);
    ix_data.writeSeed(seed);
    ix_data.writeU64(lamports);
    ix_data.writeU64(space);
    ix_data.writePubkey(owner);

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.signerWritable(from.key()),
        cpi.AccountMeta.writable(to.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(
        system_program,
        &account_metas,
        ix_data.written(),
    );

    // We construct both `account_metas` and the accounts slice inline,
    // so the bounds check in `cpi.invoke` is provably-true at compile
    // time — skip it.
    try cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ from, to, system_program });
}

/// Assign a derived account to a new owner using `(base, seed, owner)`.
pub fn assignWithSeed(
    account: CpiAccountInfo,
    base: CpiAccountInfo,
    system_program: CpiAccountInfo,
    seed: []const u8,
    owner: *const Pubkey,
) ProgramResult {
    if (seed.len > MAX_SEED_LEN) return error.MaxSeedLengthExceeded;

    var ix_data = StackIxDataWriter(variableSeedIxCapacity(
        DISCRIMINANT_BYTES + PUBKEY_BYTES + U64_BYTES + PUBKEY_BYTES,
    )).init();
    ix_data.writeDiscriminant(SystemInstruction.AssignWithSeed);
    ix_data.writePubkey(base.key());
    ix_data.writeSeed(seed);
    ix_data.writePubkey(owner);

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.writable(account.key()),
        cpi.AccountMeta.signer(base.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(
        system_program,
        &account_metas,
        ix_data.written(),
    );

    try cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ account, base, system_program });
}

/// Allocate space for a derived account using `(base, seed, owner)`.
pub fn allocateWithSeed(
    account: CpiAccountInfo,
    base: CpiAccountInfo,
    system_program: CpiAccountInfo,
    seed: []const u8,
    space: u64,
    owner: *const Pubkey,
) ProgramResult {
    if (seed.len > MAX_SEED_LEN) return error.MaxSeedLengthExceeded;

    var ix_data = StackIxDataWriter(variableSeedIxCapacity(
        DISCRIMINANT_BYTES + PUBKEY_BYTES + U64_BYTES + U64_BYTES + PUBKEY_BYTES,
    )).init();
    ix_data.writeDiscriminant(SystemInstruction.AllocateWithSeed);
    ix_data.writePubkey(base.key());
    ix_data.writeSeed(seed);
    ix_data.writeU64(space);
    ix_data.writePubkey(owner);

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.writable(account.key()),
        cpi.AccountMeta.signer(base.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(
        system_program,
        &account_metas,
        ix_data.written(),
    );

    try cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ account, base, system_program });
}

/// Transfer lamports from a derived system account.
pub fn transferWithSeed(
    from: CpiAccountInfo,
    base: CpiAccountInfo,
    to: CpiAccountInfo,
    system_program: CpiAccountInfo,
    from_seed: []const u8,
    from_owner: *const Pubkey,
    lamports: u64,
) ProgramResult {
    if (from_seed.len > MAX_SEED_LEN) return error.MaxSeedLengthExceeded;

    var ix_data = StackIxDataWriter(variableSeedIxCapacity(
        DISCRIMINANT_BYTES + U64_BYTES + U64_BYTES + PUBKEY_BYTES,
    )).init();
    ix_data.writeDiscriminant(SystemInstruction.TransferWithSeed);
    ix_data.writeU64(lamports);
    ix_data.writeSeed(from_seed);
    ix_data.writePubkey(from_owner);

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.writable(from.key()),
        cpi.AccountMeta.signer(base.key()),
        cpi.AccountMeta.writable(to.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(
        system_program,
        &account_metas,
        ix_data.written(),
    );

    try cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ from, base, to, system_program });
}

/// Initialize a nonce account after creation.
pub fn initializeNonceAccount(
    nonce_account: CpiAccountInfo,
    recent_blockhashes_sysvar: CpiAccountInfo,
    rent_sysvar: CpiAccountInfo,
    system_program: CpiAccountInfo,
    authority: *const Pubkey,
) ProgramResult {
    const ix_data = fixedIxData(SystemInstruction.InitializeNonceAccount, NonceAuthorityPayload, .{ .authority = authority.* });

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.writable(nonce_account.key()),
        cpi.AccountMeta.readonly(recent_blockhashes_sysvar.key()),
        cpi.AccountMeta.readonly(rent_sysvar.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(system_program, &account_metas, &ix_data);

    try cpi.invokeRaw(&ix, &[_]CpiAccountInfo{
        nonce_account,
        recent_blockhashes_sysvar,
        rent_sysvar,
        system_program,
    });
}

/// Create and initialize a nonce account.
pub fn createNonceAccount(
    from: CpiAccountInfo,
    nonce_account: CpiAccountInfo,
    recent_blockhashes_sysvar: CpiAccountInfo,
    rent_sysvar: CpiAccountInfo,
    system_program: CpiAccountInfo,
    authority: *const Pubkey,
    lamports: u64,
) ProgramResult {
    try createAccount(
        from,
        nonce_account,
        system_program,
        lamports,
        NONCE_STATE_SIZE,
        system_program.key(),
    );

    try initializeNonceAccount(
        nonce_account,
        recent_blockhashes_sysvar,
        rent_sysvar,
        system_program,
        authority,
    );
}

/// Create and initialize a nonce account at a seeded address.
pub fn createNonceAccountWithSeed(
    from: CpiAccountInfo,
    nonce_account: CpiAccountInfo,
    recent_blockhashes_sysvar: CpiAccountInfo,
    rent_sysvar: CpiAccountInfo,
    system_program: CpiAccountInfo,
    base: *const Pubkey,
    seed: []const u8,
    authority: *const Pubkey,
    lamports: u64,
) ProgramResult {
    try createAccountWithSeed(
        from,
        nonce_account,
        system_program,
        base,
        seed,
        lamports,
        NONCE_STATE_SIZE,
        system_program.key(),
    );

    try initializeNonceAccount(
        nonce_account,
        recent_blockhashes_sysvar,
        rent_sysvar,
        system_program,
        authority,
    );
}

/// Advance a durable transaction nonce.
pub fn advanceNonceAccount(
    nonce_account: CpiAccountInfo,
    recent_blockhashes_sysvar: CpiAccountInfo,
    authorized: CpiAccountInfo,
    system_program: CpiAccountInfo,
) ProgramResult {
    const ix_data = discriminantOnlyData(SystemInstruction.AdvanceNonceAccount);

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.writable(nonce_account.key()),
        cpi.AccountMeta.readonly(recent_blockhashes_sysvar.key()),
        cpi.AccountMeta.signer(authorized.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(system_program, &account_metas, &ix_data);

    try cpi.invokeRaw(&ix, &[_]CpiAccountInfo{
        nonce_account,
        recent_blockhashes_sysvar,
        authorized,
        system_program,
    });
}

/// Withdraw lamports from a nonce account.
pub fn withdrawNonceAccount(
    nonce_account: CpiAccountInfo,
    to: CpiAccountInfo,
    recent_blockhashes_sysvar: CpiAccountInfo,
    rent_sysvar: CpiAccountInfo,
    authorized: CpiAccountInfo,
    system_program: CpiAccountInfo,
    lamports: u64,
) ProgramResult {
    const ix_data = fixedIxData(SystemInstruction.WithdrawNonceAccount, TransferPayload, .{ .lamports = lamports });

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.writable(nonce_account.key()),
        cpi.AccountMeta.writable(to.key()),
        cpi.AccountMeta.readonly(recent_blockhashes_sysvar.key()),
        cpi.AccountMeta.readonly(rent_sysvar.key()),
        cpi.AccountMeta.signer(authorized.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(system_program, &account_metas, &ix_data);

    try cpi.invokeRaw(&ix, &[_]CpiAccountInfo{
        nonce_account,
        to,
        recent_blockhashes_sysvar,
        rent_sysvar,
        authorized,
        system_program,
    });
}

/// Change the authority of a nonce account.
pub fn authorizeNonceAccount(
    nonce_account: CpiAccountInfo,
    authorized: CpiAccountInfo,
    system_program: CpiAccountInfo,
    new_authority: *const Pubkey,
) ProgramResult {
    const ix_data = fixedIxData(SystemInstruction.AuthorizeNonceAccount, NonceAuthorityPayload, .{ .authority = new_authority.* });

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.writable(nonce_account.key()),
        cpi.AccountMeta.signer(authorized.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(system_program, &account_metas, &ix_data);

    try cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ nonce_account, authorized, system_program });
}

/// One-time idempotent upgrade of a legacy nonce account.
pub fn upgradeNonceAccount(
    nonce_account: CpiAccountInfo,
    system_program: CpiAccountInfo,
) ProgramResult {
    const ix_data = discriminantOnlyData(SystemInstruction.UpgradeNonceAccount);

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.writable(nonce_account.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(system_program, &account_metas, &ix_data);

    try cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ nonce_account, system_program });
}

// =============================================================================
// Tests
// =============================================================================

test "system: SYSTEM_PROGRAM_ID is all zero" {
    const expected: Pubkey = .{0} ** 32;
    try std.testing.expectEqual(expected, SYSTEM_PROGRAM_ID);
}

test "system: instruction data format" {
    const ix_data = fixedIxData(SystemInstruction.CreateAccount, CreateAccountPayload, .{ .lamports = 500, .space = 128, .owner = .{3} ** 32 });

    try std.testing.expectEqual(@as(u32, 0), std.mem.readInt(u32, ix_data[0..4], .little));
    try std.testing.expectEqual(@as(u64, 500), std.mem.readInt(u64, ix_data[4..12], .little));
    try std.testing.expectEqual(@as(u64, 128), std.mem.readInt(u64, ix_data[12..20], .little));
    const expected_owner: Pubkey = .{3} ** 32;
    try std.testing.expectEqual(expected_owner, ix_data[20..52].*);
}

test "system: transfer instruction data" {
    const ix_data = fixedIxData(SystemInstruction.Transfer, TransferPayload, .{ .lamports = 100 });

    try std.testing.expectEqual(@as(u32, 2), std.mem.readInt(u32, ix_data[0..4], .little));
    try std.testing.expectEqual(@as(u64, 100), std.mem.readInt(u64, ix_data[4..12], .little));
}

test "system: nonce instruction data formats" {
    const authority: Pubkey = .{7} ** 32;

    const initialize_data = fixedIxData(SystemInstruction.InitializeNonceAccount, NonceAuthorityPayload, .{ .authority = authority });
    try std.testing.expectEqual(@as(u32, 6), std.mem.readInt(u32, initialize_data[0..4], .little));
    try std.testing.expectEqual(authority, initialize_data[4..36].*);

    const withdraw_data = fixedIxData(SystemInstruction.WithdrawNonceAccount, TransferPayload, .{ .lamports = 42 });
    try std.testing.expectEqual(@as(u32, 5), std.mem.readInt(u32, withdraw_data[0..4], .little));
    try std.testing.expectEqual(@as(u64, 42), std.mem.readInt(u64, withdraw_data[4..12], .little));

    const authorize_data = fixedIxData(SystemInstruction.AuthorizeNonceAccount, NonceAuthorityPayload, .{ .authority = authority });
    try std.testing.expectEqual(@as(u32, 7), std.mem.readInt(u32, authorize_data[0..4], .little));
    try std.testing.expectEqual(authority, authorize_data[4..36].*);

    const advance_data = discriminantOnlyData(SystemInstruction.AdvanceNonceAccount);
    try std.testing.expectEqual(@as(u32, 4), std.mem.readInt(u32, advance_data[0..4], .little));

    const upgrade_data = discriminantOnlyData(SystemInstruction.UpgradeNonceAccount);
    try std.testing.expectEqual(@as(u32, 12), std.mem.readInt(u32, upgrade_data[0..4], .little));
}

test "system: seed-based helpers reject too-long seeds before CPI" {
    var account_acc: account_mod.Account = .{
        .borrow_state = account_mod.NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{1} ** 32,
        .owner = .{2} ** 32,
        .lamports = 1_000,
        .data_len = 0,
    };
    var base_acc: account_mod.Account = .{
        .borrow_state = account_mod.NOT_BORROWED,
        .is_signer = 1,
        .is_writable = 0,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{3} ** 32,
        .owner = .{4} ** 32,
        .lamports = 1_000,
        .data_len = 0,
    };
    var to_acc: account_mod.Account = .{
        .borrow_state = account_mod.NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{5} ** 32,
        .owner = .{6} ** 32,
        .lamports = 1_000,
        .data_len = 0,
    };
    var system_acc: account_mod.Account = .{
        .borrow_state = account_mod.NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 1,
        ._padding = .{0} ** 4,
        .key = SYSTEM_PROGRAM_ID,
        .owner = .{0} ** 32,
        .lamports = 1_000,
        .data_len = 0,
    };

    const account_info = account_mod.AccountInfo{ .raw = &account_acc };
    const base_info = account_mod.AccountInfo{ .raw = &base_acc };
    const to_info = account_mod.AccountInfo{ .raw = &to_acc };
    const system_program_info = account_mod.AccountInfo{ .raw = &system_acc };

    const account = account_info.toCpiInfo();
    const base = base_info.toCpiInfo();
    const to = to_info.toCpiInfo();
    const system_program = system_program_info.toCpiInfo();
    const too_long = [_]u8{0} ** (MAX_SEED_LEN + 1);
    const owner: Pubkey = .{9} ** 32;

    try std.testing.expectError(
        error.MaxSeedLengthExceeded,
        createAccountWithSeed(account, to, system_program, base.key(), &too_long, 1, 1, &owner),
    );
    try std.testing.expectError(
        error.MaxSeedLengthExceeded,
        assignWithSeed(account, base, system_program, &too_long, &owner),
    );
    try std.testing.expectError(
        error.MaxSeedLengthExceeded,
        allocateWithSeed(account, base, system_program, &too_long, 1, &owner),
    );
    try std.testing.expectError(
        error.MaxSeedLengthExceeded,
        transferWithSeed(account, base, to, system_program, &too_long, &owner, 1),
    );
}

test "system: nonce state size matches Solana ABI" {
    try std.testing.expectEqual(@as(u64, 80), NONCE_STATE_SIZE);
}

test "system: SystemInstruction discriminant values" {
    try std.testing.expectEqual(@as(u32, 0), @intFromEnum(SystemInstruction.CreateAccount));
    try std.testing.expectEqual(@as(u32, 1), @intFromEnum(SystemInstruction.Assign));
    try std.testing.expectEqual(@as(u32, 2), @intFromEnum(SystemInstruction.Transfer));
    try std.testing.expectEqual(@as(u32, 3), @intFromEnum(SystemInstruction.CreateAccountWithSeed));
    try std.testing.expectEqual(@as(u32, 4), @intFromEnum(SystemInstruction.AdvanceNonceAccount));
    try std.testing.expectEqual(@as(u32, 5), @intFromEnum(SystemInstruction.WithdrawNonceAccount));
    try std.testing.expectEqual(@as(u32, 6), @intFromEnum(SystemInstruction.InitializeNonceAccount));
    try std.testing.expectEqual(@as(u32, 7), @intFromEnum(SystemInstruction.AuthorizeNonceAccount));
    try std.testing.expectEqual(@as(u32, 8), @intFromEnum(SystemInstruction.Allocate));
    try std.testing.expectEqual(@as(u32, 9), @intFromEnum(SystemInstruction.AllocateWithSeed));
    try std.testing.expectEqual(@as(u32, 10), @intFromEnum(SystemInstruction.AssignWithSeed));
    try std.testing.expectEqual(@as(u32, 11), @intFromEnum(SystemInstruction.TransferWithSeed));
    try std.testing.expectEqual(@as(u32, 12), @intFromEnum(SystemInstruction.UpgradeNonceAccount));
}
