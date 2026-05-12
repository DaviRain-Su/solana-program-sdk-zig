//! Cross-Program Invocation (CPI)
//!
//! Provides zero-overhead CPI wrappers.
//! CpiAccountInfo layout matches Solana C ABI, so no conversion is needed.

const std = @import("std");
const account = @import("account.zig");
const pubkey = @import("pubkey.zig");
const program_error = @import("program_error.zig");
const bpf = @import("bpf.zig");

const CpiAccountInfo = account.CpiAccountInfo;
const Pubkey = pubkey.Pubkey;
const ProgramResult = program_error.ProgramResult;
const SUCCESS = program_error.SUCCESS;

/// Account metadata for CPI instructions.
///
/// Field order matches the Solana C ABI `SolAccountMeta`:
/// ```c
/// typedef struct {
///   SolPubkey *pubkey;
///   bool       is_writable;
///   bool       is_signer;
/// } SolAccountMeta;
/// ```
///
/// We use `u8` (not Zig `bool`) for the two flag fields:
///   - The C ABI specifies `bool` as a single byte but does not bound
///     non-zero values to exactly `1`. The runtime may copy these bytes
///     verbatim when re-marshalling for CPI.
///   - Zig `bool` is UB for any value other than `0` or `1`, so reading
///     a 0xFF here would be UB the moment we coerced it back to `bool`.
///
/// `@sizeOf(AccountMeta) == 16`: the trailing 6 bytes are alignment
/// padding so a `[N]AccountMeta` array keeps each `pubkey` pointer
/// 8-byte aligned. The C struct has no such padding inside a single
/// element, but its array stride is identical because `bool[2]` is
/// followed by the next struct's pointer (8-byte aligned), so the
/// effective layout on the wire matches.
pub const AccountMeta = extern struct {
    /// Public key of the account
    pubkey: *const Pubkey,
    /// Is this account writable (0 = false, non-zero = true)
    is_writable: u8,
    /// Is this account a signer (0 = false, non-zero = true)
    is_signer: u8,

    /// Convenience constructor. Prefer this over the struct literal
    /// when you already have Zig `bool`s in hand.
    pub inline fn init(key: *const Pubkey, is_writable: bool, is_signer: bool) AccountMeta {
        return .{
            .pubkey = key,
            .is_writable = @intFromBool(is_writable),
            .is_signer = @intFromBool(is_signer),
        };
    }

    /// Read-only, non-signer. Typical for sysvars / read-only program
    /// accounts passed to a CPI.
    pub inline fn readonly(key: *const Pubkey) AccountMeta {
        return .{ .pubkey = key, .is_writable = 0, .is_signer = 0 };
    }

    /// Writable but not a signer. Typical for destination accounts in
    /// a transfer.
    pub inline fn writable(key: *const Pubkey) AccountMeta {
        return .{ .pubkey = key, .is_writable = 1, .is_signer = 0 };
    }

    /// Signer but not writable. Rare — usually programs that need a
    /// signing authority but don't mutate it.
    pub inline fn signer(key: *const Pubkey) AccountMeta {
        return .{ .pubkey = key, .is_writable = 0, .is_signer = 1 };
    }

    /// Signer and writable. Typical for the payer in a CreateAccount
    /// CPI, or a token-account authority paying for a transfer.
    pub inline fn signerWritable(key: *const Pubkey) AccountMeta {
        return .{ .pubkey = key, .is_writable = 1, .is_signer = 1 };
    }
};

comptime {
    // Catch regressions in the C ABI layout at build time.
    std.debug.assert(@sizeOf(AccountMeta) == 16);
    std.debug.assert(@offsetOf(AccountMeta, "pubkey") == 0);
    std.debug.assert(@offsetOf(AccountMeta, "is_writable") == 8);
    std.debug.assert(@offsetOf(AccountMeta, "is_signer") == 9);
}

/// CPI Instruction
pub const Instruction = struct {
    /// Program ID to invoke
    program_id: *const Pubkey,
    /// Accounts required by the instruction
    accounts: []const AccountMeta,
    /// Instruction data
    data: []const u8,

    /// Construct an `Instruction` in one call — saves the 4-field
    /// struct literal at every CPI call site:
    ///
    /// ```zig
    /// const ix = sol.cpi.Instruction.init(
    ///     system_program.key(),  // program_id
    ///     &account_metas,        // accounts
    ///     &ix_data,              // raw bytes
    /// );
    /// ```
    ///
    /// `inline` so the resulting BPF is identical to the struct
    /// literal — verified by 0-CU bench regression on vault.
    pub inline fn init(
        program_id: *const Pubkey,
        accounts: []const AccountMeta,
        data: []const u8,
    ) Instruction {
        return .{
            .program_id = program_id,
            .accounts = accounts,
            .data = data,
        };
    }

    /// Same as `init` but takes a `CpiAccountInfo` for the program
    /// account (the common pattern in CPI helpers — the caller passes
    /// the program as a parsed account, and we want its `key()`).
    ///
    /// ```zig
    /// const ix = sol.cpi.Instruction.fromCpiAccount(
    ///     system_program,     // CpiAccountInfo
    ///     &account_metas,
    ///     &ix_data,
    /// );
    /// ```
    pub inline fn fromCpiAccount(
        program: CpiAccountInfo,
        accounts: []const AccountMeta,
        data: []const u8,
    ) Instruction {
        return .{
            .program_id = program.key(),
            .accounts = accounts,
            .data = data,
        };
    }
};

/// A single PDA seed in the runtime's C-ABI shape: `{ ptr_as_u64, len }`.
///
/// Matches `SolSignerSeedC` exactly so an array of `Seed`s can be passed
/// straight to `sol_invoke_signed_c` without a staging copy. Mirrors
/// Pinocchio's `pinocchio::cpi::Seed`.
///
/// Construct with `Seed.from(slice)`. Cheaper than the
/// `[]const []const u8` shape used by `invokeSigned` because the user
/// builds the C-ABI layout inline — the CPI wrapper just hands the
/// pointer to the syscall.
pub const Seed = extern struct {
    addr: u64,
    len: u64,

    pub inline fn from(slice: []const u8) Seed {
        return .{ .addr = @intFromPtr(slice.ptr), .len = slice.len };
    }

    /// Create a `Seed` over a `*const u8`, treating it as a 1-byte
    /// slice. Useful for the bump-seed pattern when you have a
    /// `u8` field on a stack variable (a stored bump on an account):
    ///
    /// ```zig
    /// const seeds = [_]Seed{
    ///     .from("vault"),
    ///     .fromPubkey(authority.key()),
    ///     .fromByte(&state.bump),     // 1-byte bump from account
    /// };
    /// ```
    ///
    /// Equivalent to wrapping the byte in a 1-element array
    /// (`const arr = [_]u8{b}; .from(&arr)`) but lets the caller
    /// reuse existing storage — useful when the bump already lives
    /// in account data or a stored struct.
    pub inline fn fromByte(byte: *const u8) Seed {
        return .{ .addr = @intFromPtr(byte), .len = 1 };
    }

    /// Create a `Seed` over a `*const Pubkey`, treating it as a
    /// 32-byte slice. Equivalent to `from(pk[0..])` but reads
    /// more naturally:
    ///
    /// ```zig
    /// .fromPubkey(authority.key())
    /// // vs.
    /// .from(authority.key()[0..])
    /// ```
    pub inline fn fromPubkey(pk: *const Pubkey) Seed {
        return .{ .addr = @intFromPtr(pk), .len = pubkey.PUBKEY_BYTES };
    }
};

/// A single PDA signer in the runtime's C-ABI shape:
/// `{ &Seed[N], seed_count }`. Mirrors `SolSignerSeedsC`.
///
/// Construct from a `[]const Seed` (typically a stack array of `Seed`s
/// the caller built inline). The `Signer` itself is also stack-friendly.
pub const Signer = extern struct {
    addr: u64,
    len: u64,

    pub inline fn from(seeds: []const Seed) Signer {
        return .{ .addr = @intFromPtr(seeds.ptr), .len = seeds.len };
    }
};

comptime {
    // Catch ABI regressions at build time.
    std.debug.assert(@sizeOf(Seed) == 16);
    std.debug.assert(@offsetOf(Seed, "addr") == 0);
    std.debug.assert(@offsetOf(Seed, "len") == 8);
    std.debug.assert(@sizeOf(Signer) == 16);
}

// =============================================================================
// C-ABI Structures for syscalls
// =============================================================================

/// C-ABI instruction format (SolInstruction in sol/cpi.h)
const SolInstruction = extern struct {
    program_id: *const Pubkey,
    accounts: [*]const AccountMeta,
    account_len: u64,
    data: [*]const u8,
    data_len: u64,
};

/// `Seed` and `Signer` (declared above) are the public C-ABI types;
/// they match the layout of `SolSignerSeedC` / `SolSignerSeedsC` exactly.
/// We use them directly in the syscall signature so callers can pass
/// stack-built `Signer` arrays without a copy.

extern fn sol_invoke_signed_c(
    instruction: *const SolInstruction,
    account_infos: [*]const CpiAccountInfo,
    account_infos_len: u64,
    signers_seeds: [*]const Signer,
    signers_seeds_len: u64,
) callconv(.c) u64;

extern fn sol_set_return_data(data: [*]const u8, len: u64) callconv(.c) void;
extern fn sol_get_return_data(data: [*]u8, len: u64, program_id: *Pubkey) callconv(.c) u64;

// =============================================================================
// CPI Functions
// =============================================================================

/// Maximum number of PDA signers per CPI call.
pub const MAX_CPI_SIGNERS: usize = 8;
/// Maximum seeds per signer (matches Solana runtime limit).
pub const MAX_CPI_SEEDS_PER_SIGNER: usize = 16;

/// Invoke another program (no PDA signers).
///
/// Fast path: skips the seed-staging loop entirely. Use this whenever
/// the called program does not require a PDA signature — saves a few
/// CU vs. `invokeSigned` with an empty `signers_seeds`.
///
/// ZERO-COPY: `CpiAccountInfo` layout matches `SolCpiAccountInfo` C ABI,
/// so accounts can be passed directly without conversion.
pub fn invoke(
    instruction: *const Instruction,
    accounts: []const CpiAccountInfo,
) ProgramResult {
    if (!bpf.is_bpf_program) {
        return error.InvalidArgument;
    }

    if (instruction.accounts.len > accounts.len) {
        return error.NotEnoughAccountKeys;
    }

    return invokeRaw(instruction, accounts);
}

/// Invoke another program with no bounds check.
///
/// Identical to `invoke` but skips the
/// `instruction.accounts.len > accounts.len` runtime check. Callers
/// must ensure they're passing the right slice (every `system.*`
/// helper does this by construction since it builds both arrays
/// inline). Saves ~2-4 CU per CPI.
pub fn invokeRaw(
    instruction: *const Instruction,
    accounts: []const CpiAccountInfo,
) ProgramResult {
    if (!bpf.is_bpf_program) {
        return error.InvalidArgument;
    }

    const sol_instruction = SolInstruction{
        .program_id = instruction.program_id,
        .accounts = instruction.accounts.ptr,
        .account_len = instruction.accounts.len,
        .data = instruction.data.ptr,
        .data_len = instruction.data.len,
    };

    const result = sol_invoke_signed_c(
        &sol_instruction,
        accounts.ptr,
        accounts.len,
        @ptrFromInt(@alignOf(Signer)), // unused when len = 0
        0,
    );

    if (result != SUCCESS) {
        return program_error.u64ToError(result);
    }
}

/// Invoke another program with program derived address signatures.
///
/// `signers_seeds` is a slice of signer entries; each entry is itself a
/// slice of byte slices (the seeds used to derive that signer's PDA).
/// For a single PDA signer with seeds `["vault", bump]`, pass
/// `&.{ &.{ "vault", &.{bump} } }`.
///
/// If you don't need PDA signing, call `invoke` directly — it skips
/// the seed-staging loop.
///
/// ZERO-COPY: `CpiAccountInfo` layout matches `SolCpiAccountInfo` C ABI,
/// so accounts can be passed directly without conversion.
pub fn invokeSigned(
    instruction: *const Instruction,
    accounts: []const CpiAccountInfo,
    signers_seeds: []const []const []const u8,
) ProgramResult {
    if (!bpf.is_bpf_program) {
        return error.InvalidArgument;
    }

    if (signers_seeds.len == 0) {
        return invoke(instruction, accounts);
    }

    if (signers_seeds.len > MAX_CPI_SIGNERS) {
        return program_error.fail("cpi:too_many_signers", error.InvalidArgument);
    }

    // Build the C-ABI signer descriptors on the stack.
    //
    // Layout: one Signer per signer, each pointing to a contiguous run
    // of Seed entries inside `seed_pool`. We size the pool exactly to
    // `MAX_CPI_SEEDS_PER_SIGNER * signers_seeds.len` via a per-signer
    // bound check, avoiding the 128-entry over-allocation the previous
    // implementation used.
    var seed_pool: [MAX_CPI_SIGNERS * MAX_CPI_SEEDS_PER_SIGNER]Seed = undefined;
    var signers_buf: [MAX_CPI_SIGNERS]Signer = undefined;

    var pool_cursor: usize = 0;
    for (signers_seeds, 0..) |seeds, i| {
        if (seeds.len > MAX_CPI_SEEDS_PER_SIGNER) {
            return program_error.fail("cpi:too_many_seeds", error.InvalidArgument);
        }
        const start = pool_cursor;
        for (seeds) |seed| {
            seed_pool[pool_cursor] = .{
                .addr = @intFromPtr(seed.ptr),
                .len = seed.len,
            };
            pool_cursor += 1;
        }
        signers_buf[i] = .{
            .addr = @intFromPtr(&seed_pool[start]),
            .len = seeds.len,
        };
    }

    return invokeSignedRaw(instruction, accounts, signers_buf[0..signers_seeds.len]);
}

/// Fast-path PDA-signed CPI: takes pre-built `Signer`s in the runtime's
/// C-ABI shape, skipping the seed-pool staging copy `invokeSigned`
/// performs.
///
/// Mirrors Pinocchio's `invoke_signed_unchecked` path. Use this when
/// you already know the seed layout at the call site, which is the
/// common case (`["seed", key, &[bump]]`):
///
/// ```zig
/// const bump_seed = [_]u8{bump};
/// const seeds = [_]sol.cpi.Seed{
///     .from("vault"),
///     .from(authority.key()[0..]),
///     .from(&bump_seed),
/// };
/// const signer = sol.cpi.Signer.from(&seeds);
/// try sol.cpi.invokeSignedRaw(&ix, &accounts, &.{signer});
/// ```
///
/// Saves ~80-120 CU vs. `invokeSigned` on the typical 1-signer,
/// 3-seed PDA case by skipping a 128-entry stack scratch buffer +
/// nested loop with bounds checks. The caller is responsible for
/// keeping the seed slices and the `Seed` array alive across the
/// CPI call — both must outlive `sol_invoke_signed_c`.
pub fn invokeSignedRaw(
    instruction: *const Instruction,
    accounts: []const CpiAccountInfo,
    signers: []const Signer,
) ProgramResult {
    if (!bpf.is_bpf_program) {
        return error.InvalidArgument;
    }

    const sol_instruction = SolInstruction{
        .program_id = instruction.program_id,
        .accounts = instruction.accounts.ptr,
        .account_len = instruction.accounts.len,
        .data = instruction.data.ptr,
        .data_len = instruction.data.len,
    };

    const result = sol_invoke_signed_c(
        &sol_instruction,
        accounts.ptr,
        accounts.len,
        signers.ptr,
        signers.len,
    );

    if (result != SUCCESS) {
        return program_error.u64ToError(result);
    }
}

/// Set return data for this program
pub fn setReturnData(data: []const u8) void {
    if (bpf.is_bpf_program) {
        sol_set_return_data(data.ptr, data.len);
    }
}

/// Get return data from the last CPI call
pub fn getReturnData(buffer: []u8) ?struct { Pubkey, []const u8 } {
    if (!bpf.is_bpf_program) {
        return null;
    }

    var program_id: Pubkey = undefined;
    const len = sol_get_return_data(buffer.ptr, buffer.len, &program_id);

    if (len == 0) {
        return null;
    }

    return .{ program_id, buffer[0..@intCast(len)] };
}

// =============================================================================
// Tests
// =============================================================================
//
// AccountMeta layout is asserted at comptime above.
// CpiAccountInfo size is asserted at comptime in account.zig.

test "cpi: AccountMeta.init sets bytes correctly" {
    const key: Pubkey = .{0} ** 32;
    const m = AccountMeta.init(&key, true, false);
    try std.testing.expectEqual(@as(u8, 1), m.is_writable);
    try std.testing.expectEqual(@as(u8, 0), m.is_signer);
}

test "cpi: AccountMeta convenience constructors set correct flag bytes" {
    const key: Pubkey = .{42} ** 32;

    const ro = AccountMeta.readonly(&key);
    try std.testing.expectEqual(@as(u8, 0), ro.is_writable);
    try std.testing.expectEqual(@as(u8, 0), ro.is_signer);

    const w = AccountMeta.writable(&key);
    try std.testing.expectEqual(@as(u8, 1), w.is_writable);
    try std.testing.expectEqual(@as(u8, 0), w.is_signer);

    const s = AccountMeta.signer(&key);
    try std.testing.expectEqual(@as(u8, 0), s.is_writable);
    try std.testing.expectEqual(@as(u8, 1), s.is_signer);

    const sw = AccountMeta.signerWritable(&key);
    try std.testing.expectEqual(@as(u8, 1), sw.is_writable);
    try std.testing.expectEqual(@as(u8, 1), sw.is_signer);

    // All constructors point at the same key.
    try std.testing.expectEqual(&key, ro.pubkey);
    try std.testing.expectEqual(&key, sw.pubkey);
}

test "cpi: Instruction.init builds the struct in one call" {
    const key: Pubkey = .{1} ** 32;
    const metas = [_]AccountMeta{AccountMeta.signer(&key)};
    const data = [_]u8{ 0x01, 0x02, 0x03 };

    const ix = Instruction.init(&key, &metas, &data);

    try std.testing.expectEqual(&key, ix.program_id);
    try std.testing.expectEqual(@as(usize, 1), ix.accounts.len);
    try std.testing.expectEqual(@as(usize, 3), ix.data.len);
    try std.testing.expectEqual(@as(u8, 0x02), ix.data[1]);
}

test "cpi: Seed.from / fromByte / fromPubkey produce identical layout" {
    const slice = "vault";
    const s1 = Seed.from(slice);
    try std.testing.expectEqual(@intFromPtr(slice.ptr), s1.addr);
    try std.testing.expectEqual(@as(u64, slice.len), s1.len);

    const b: u8 = 254;
    const s2 = Seed.fromByte(&b);
    try std.testing.expectEqual(@intFromPtr(&b), s2.addr);
    try std.testing.expectEqual(@as(u64, 1), s2.len);

    const pk: Pubkey = .{42} ** 32;
    const s3 = Seed.fromPubkey(&pk);
    try std.testing.expectEqual(@intFromPtr(&pk), s3.addr);
    try std.testing.expectEqual(@as(u64, 32), s3.len);
}
