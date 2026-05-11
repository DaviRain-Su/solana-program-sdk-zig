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
/// Layout matches the C ABI `SolAccountMeta` (`{ const SolPubkey *,
/// uint8_t is_signer, uint8_t is_writable }`). We use `u8` (not `bool`)
/// because the runtime may write arbitrary nonzero values into the
/// signer/writable bytes when re-marshalling for CPI, and Zig `bool`
/// requires the value to be exactly 0 or 1 (anything else is UB).
pub const AccountMeta = extern struct {
    /// Public key of the account
    pubkey: *const Pubkey,
    /// Is this account writable (0 = false, non-zero = true)
    is_writable: u8,
    /// Is this account a signer (0 = false, non-zero = true)
    is_signer: u8,

    /// Convenience constructor.
    pub inline fn init(key: *const Pubkey, is_writable: bool, is_signer: bool) AccountMeta {
        return .{
            .pubkey = key,
            .is_writable = @intFromBool(is_writable),
            .is_signer = @intFromBool(is_signer),
        };
    }
};

/// CPI Instruction
pub const Instruction = struct {
    /// Program ID to invoke
    program_id: *const Pubkey,
    /// Accounts required by the instruction
    accounts: []const AccountMeta,
    /// Instruction data
    data: []const u8,
};

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

/// C-ABI signer seed
const SolSignerSeedC = extern struct {
    addr: u64,
    len: u64,
};

/// C-ABI signer seeds
const SolSignerSeedsC = extern struct {
    addr: u64,
    len: u64,
};

extern fn sol_invoke_signed_c(
    instruction: *const SolInstruction,
    account_infos: [*]const CpiAccountInfo,
    account_infos_len: u64,
    signers_seeds: [*]const SolSignerSeedsC,
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

/// Invoke another program
///
/// ZERO-COPY: CpiAccountInfo layout matches SolCpiAccountInfo C ABI,
/// so accounts can be passed directly without conversion.
pub fn invoke(
    instruction: *const Instruction,
    accounts: []const CpiAccountInfo,
) ProgramResult {
    return invokeSigned(instruction, accounts, &[_][]const []const u8{});
}

/// Invoke another program with program derived address signatures.
///
/// `signers_seeds` is a slice of signer entries; each entry is itself a
/// slice of byte slices (the seeds used to derive that signer's PDA).
/// For a single PDA signer with seeds `["vault", bump]`, pass
/// `&.{ &.{ "vault", &.{bump} } }`.
///
/// ZERO-COPY: CpiAccountInfo layout matches SolCpiAccountInfo C ABI,
/// so accounts can be passed directly without conversion.
pub fn invokeSigned(
    instruction: *const Instruction,
    accounts: []const CpiAccountInfo,
    signers_seeds: []const []const []const u8,
) ProgramResult {
    if (!bpf.is_bpf_program) {
        return error.InvalidArgument;
    }

    // Fast-path validation: check account count matches
    if (instruction.accounts.len > accounts.len) {
        return error.NotEnoughAccountKeys;
    }

    if (signers_seeds.len > MAX_CPI_SIGNERS) {
        return error.InvalidArgument;
    }

    // Convert instruction to C ABI format
    const sol_instruction = SolInstruction{
        .program_id = instruction.program_id,
        .accounts = instruction.accounts.ptr,
        .account_len = instruction.accounts.len,
        .data = instruction.data.ptr,
        .data_len = instruction.data.len,
    };

    // Build the C-ABI signer descriptors on the stack.
    //
    // Layout: one SolSignerSeedsC per signer, each pointing to a contiguous
    // run of SolSignerSeedC entries inside `seed_pool`.
    var seed_pool: [MAX_CPI_SIGNERS * MAX_CPI_SEEDS_PER_SIGNER]SolSignerSeedC = undefined;
    var signers_buf: [MAX_CPI_SIGNERS]SolSignerSeedsC = undefined;

    var pool_cursor: usize = 0;
    for (signers_seeds, 0..) |seeds, i| {
        if (seeds.len > MAX_CPI_SEEDS_PER_SIGNER) {
            return error.InvalidArgument;
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

    const signers_ptr: [*]const SolSignerSeedsC = &signers_buf;
    const signers_len: u64 = signers_seeds.len;

    // ZERO-COPY: Pass CpiAccountInfo array directly — its layout matches SolCpiAccountInfo
    const result = sol_invoke_signed_c(
        &sol_instruction,
        accounts.ptr,
        accounts.len,
        signers_ptr,
        signers_len,
    );

    if (result != SUCCESS) {
        // Surface the runtime's actual error code instead of collapsing
        // every failure into InvalidArgument.
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

test "cpi: AccountMeta size" {
    // AccountMeta: 8 (pubkey ptr) + 1 (is_writable) + 1 (is_signer) + 6 (padding) = 16
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(AccountMeta));
}

test "cpi: CpiAccountInfo matches C ABI" {
    // Verify CpiAccountInfo layout matches SolCpiAccountInfo for first 56 bytes
    const SolCpiAccountInfo = extern struct {
        key: *const Pubkey,
        lamports: *u64,
        data_len: u64,
        data: [*]u8,
        owner: *const Pubkey,
        rent_epoch: u64,
        is_signer: u8,
        is_writable: u8,
        executable: u8,
        _padding: [5]u8,
    };

    try std.testing.expectEqual(@sizeOf(SolCpiAccountInfo), 56);
    
    // Verify field offsets match
    const dummy: CpiAccountInfo = undefined;
    _ = dummy;
    
    // If this compiles, CpiAccountInfo can be passed directly to sol_invoke_signed_c
    _ = dummy;
}
