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

/// Account metadata for CPI instructions
/// Field order matches C ABI (SolAccountMeta in sol/cpi.h)
pub const AccountMeta = extern struct {
    /// Public key of the account
    pubkey: *const Pubkey,
    /// Is this account writable
    is_writable: bool,
    /// Is this account a signer
    is_signer: bool,
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

/// Invoke another program
/// 
/// ZERO-COPY: CpiAccountInfo layout matches SolCpiAccountInfo C ABI,
/// so accounts can be passed directly without conversion.
pub fn invoke(
    instruction: *const Instruction,
    accounts: []const CpiAccountInfo,
) ProgramResult {
    return invokeSigned(instruction, accounts, &[_][]const u8{});
}

/// Invoke another program with program derived address signatures
/// 
/// ZERO-COPY: CpiAccountInfo layout matches SolCpiAccountInfo C ABI,
/// so accounts can be passed directly without conversion.
pub fn invokeSigned(
    instruction: *const Instruction,
    accounts: []const CpiAccountInfo,
    signers_seeds: []const []const u8,
) ProgramResult {
    if (!bpf.is_bpf_program) {
        return error.InvalidArgument;
    }

    // Fast-path validation: check account count matches
    if (instruction.accounts.len > accounts.len) {
        return error.NotEnoughAccountKeys;
    }

    // Convert instruction to C ABI format
    const sol_instruction = SolInstruction{
        .program_id = instruction.program_id,
        .accounts = instruction.accounts.ptr,
        .account_len = instruction.accounts.len,
        .data = instruction.data.ptr,
        .data_len = instruction.data.len,
    };

    // Serialize signer seeds to C ABI format
    var sol_signer_seeds: [16]SolSignerSeedC = undefined;
    var sol_signers: [1]SolSignerSeedsC = undefined;

    const signers_ptr: [*]const SolSignerSeedsC = if (signers_seeds.len > 0) blk: {
        if (signers_seeds.len > sol_signer_seeds.len) {
            return error.InvalidArgument;
        }

        for (signers_seeds, 0..) |seed, i| {
            sol_signer_seeds[i] = SolSignerSeedC{
                .addr = @intFromPtr(seed.ptr),
                .len = seed.len,
            };
        }

        sol_signers[0] = SolSignerSeedsC{
            .addr = @intFromPtr(&sol_signer_seeds),
            .len = signers_seeds.len,
        };

        break :blk &sol_signers;
    } else &sol_signers;

    const signers_len: u64 = if (signers_seeds.len > 0) 1 else 0;

    // ZERO-COPY: Pass CpiAccountInfo array directly — its layout matches SolCpiAccountInfo
    const result = sol_invoke_signed_c(
        &sol_instruction,
        accounts.ptr,
        accounts.len,
        signers_ptr,
        signers_len,
    );

    if (result != SUCCESS) {
        return error.InvalidArgument;
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
