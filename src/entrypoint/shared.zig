pub const std = @import("std");
pub const account = @import("../account/root.zig");
pub const account_cursor = @import("../account_cursor/root.zig");
pub const pubkey = @import("../pubkey/root.zig");
pub const program_error = @import("../program_error/root.zig");
pub const error_code = @import("../error_code.zig");
pub const instruction_mod = @import("../instruction/root.zig");

pub const Account = account.Account;
pub const AccountInfo = account.AccountInfo;
pub const AccountCursor = account_cursor.AccountCursor;
pub const MaybeAccount = account.MaybeAccount;
pub const Pubkey = pubkey.Pubkey;
pub const ProgramResult = program_error.ProgramResult;
pub const ProgramError = program_error.ProgramError;
pub const SUCCESS = program_error.SUCCESS;

pub const HEAP_START_ADDRESS: u64 = 0x300000000;
pub const HEAP_LENGTH: usize = 32 * 1024;
pub const MAX_PERMITTED_DATA_INCREASE: usize = account.MAX_PERMITTED_DATA_INCREASE;

pub inline fn alignPointer(ptr: usize) usize {
    return (ptr + 7) & ~@as(usize, 7);
}

pub inline fn unlikely(b: bool) bool {
    if (b) {
        @branchHint(.cold);
        return true;
    }
    return false;
}

pub inline fn likely(b: bool) bool {
    if (!b) {
        @branchHint(.cold);
        return false;
    }
    return true;
}
