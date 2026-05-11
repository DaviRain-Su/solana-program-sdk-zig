const std = @import("std");
const account = @import("account.zig");
const pubkey = @import("pubkey.zig");
const program_error = @import("program_error.zig");
const bpf = @import("bpf.zig");

const AccountInfo = account.AccountInfo;
const Pubkey = pubkey.Pubkey;
const ProgramResult = program_error.ProgramResult;

/// Legacy instruction struct for CPI
/// Will be replaced by cpi.zig in Phase 4
pub const Instruction = extern struct {
    program_id: *const Pubkey,
    accounts: [*]const AccountMeta,
    accounts_len: usize,
    data: [*]const u8,
    data_len: usize,

    extern fn sol_invoke_signed_c(
        instruction: *const Instruction,
        account_infos: ?[*]const AccountInfo,
        account_infos_len: usize,
        signer_seeds: ?[*]const []const []const u8,
        signer_seeds_len: usize,
    ) callconv(.c) u64;

    pub fn from(params: struct {
        program_id: *const Pubkey,
        accounts: []const AccountMeta,
        data: []const u8,
    }) Instruction {
        return .{
            .program_id = params.program_id,
            .accounts = params.accounts.ptr,
            .accounts_len = params.accounts.len,
            .data = params.data.ptr,
            .data_len = params.data.len,
        };
    }

    pub fn invoke(self: *const Instruction, accounts: []const AccountInfo) ProgramResult {
        if (bpf.is_bpf_program) {
            return switch (sol_invoke_signed_c(self, accounts.ptr, accounts.len, null, 0)) {
                0 => {},
                else => error.InvalidArgument,
            };
        }
        return error.InvalidArgument;
    }

    pub fn invokeSigned(self: *const Instruction, accounts: []const AccountInfo, signer_seeds: []const []const []const u8) ProgramResult {
        if (bpf.is_bpf_program) {
            return switch (sol_invoke_signed_c(self, accounts.ptr, accounts.len, signer_seeds.ptr, signer_seeds.len)) {
                0 => {},
                else => error.InvalidArgument,
            };
        }
        return error.InvalidArgument;
    }
};

/// Account metadata for CPI
pub const AccountMeta = extern struct {
    pubkey: *const Pubkey,
    is_writable: bool,
    is_signer: bool,
};

/// Helper for no-alloc CPIs
pub fn InstructionData(comptime Discriminant: type, comptime Data: type) type {
    comptime {
        if (@bitSizeOf(Discriminant) % 8 != 0) {
            @panic("Discriminant bit size is not divisible by 8");
        }
        if (@bitSizeOf(Data) % 8 != 0) {
            @panic("Data bit size is not divisible by 8");
        }
    }
    return packed struct {
        discriminant: Discriminant,
        data: Data,
        const Self = @This();
        pub fn asBytes(self: *const Self) []const u8 {
            return std.mem.asBytes(self)[0..((@bitSizeOf(Discriminant) + @bitSizeOf(Data)) / 8)];
        }
    };
}

test "instruction: data transmute" {
    const Discriminant = enum(u32) {
        zero,
        one,
        two,
        three,
    };

    const Data = packed struct {
        a: u8,
        b: u16,
        c: u64,
    };

    const instruction = InstructionData(Discriminant, Data){ .discriminant = Discriminant.three, .data = Data{ .a = 1, .b = 2, .c = 3 } };
    try std.testing.expectEqualSlices(u8, instruction.asBytes(), &[_]u8{ 3, 0, 0, 0, 1, 2, 0, 3, 0, 0, 0, 0, 0, 0, 0 });
}
