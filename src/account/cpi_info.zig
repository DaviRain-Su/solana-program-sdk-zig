const std = @import("std");
const shared = @import("shared.zig");

const Pubkey = shared.Pubkey;
const Account = shared.Account;

// =========================================================================
// CpiAccountInfo — C-ABI-compatible view for CPI (SolAccountInfo layout)
//
// Only use this when passing accounts to `cpi.invoke`.
// Normal programs should use `AccountInfo` instead.
// =========================================================================

pub const CpiAccountInfo = extern struct {
    key_ptr: *const Pubkey,
    lamports_ptr: *u64,
    data_len: u64,
    data_ptr: [*]u8,
    owner_ptr: *const Pubkey,
    rent_epoch: u64,
    is_signer: u8,
    is_writable: u8,
    is_executable: u8,
    _abi_padding: [5]u8,

    pub inline fn fromPtr(ptr: *Account) CpiAccountInfo {
        const dp: [*]u8 = @ptrFromInt(@intFromPtr(ptr) + @sizeOf(Account));
        // `is_signer`/`is_writable`/`is_executable` live at consecutive
        // offsets 1, 2, 3 in `Account`. We copy them as a single u32
        // load+store (4 bytes — pulling in one byte of `_padding` on
        // both sides, which is fine since both sides have padding
        // there). This mirrors Pinocchio's `CpiAccount::init_from_account_view`
        // and saves a few CU vs. three byte loads + three byte stores.
        //
        // Tried u64 copy (8 bytes) but the source's byte 8 is `key[0]`,
        // not zero, so it would write garbage into `_abi_padding`.
        // u32 is the safe maximum.
        const flags_src: *align(1) const u32 = @ptrCast(&ptr.is_signer);
        var out: CpiAccountInfo = .{
            .key_ptr = &ptr.key,
            .lamports_ptr = &ptr.lamports,
            .data_len = ptr.data_len,
            .data_ptr = dp,
            .owner_ptr = &ptr.owner,
            .rent_epoch = 0,
            .is_signer = undefined,
            .is_writable = undefined,
            .is_executable = undefined,
            ._abi_padding = undefined,
        };
        const flags_dst: *align(1) u32 = @ptrCast(&out.is_signer);
        flags_dst.* = flags_src.*;
        return out;
    }

    pub inline fn key(self: CpiAccountInfo) *const Pubkey {
        return self.key_ptr;
    }

    pub inline fn owner(self: CpiAccountInfo) *const Pubkey {
        return self.owner_ptr;
    }

    pub inline fn lamports(self: CpiAccountInfo) u64 {
        return self.lamports_ptr.*;
    }

    pub inline fn dataLen(self: CpiAccountInfo) usize {
        return @intCast(self.data_len);
    }

    pub inline fn isSigner(self: CpiAccountInfo) bool {
        return self.is_signer != 0;
    }

    pub inline fn isWritable(self: CpiAccountInfo) bool {
        return self.is_writable != 0;
    }

    pub inline fn data(self: CpiAccountInfo) []u8 {
        return self.data_ptr[0..self.dataLen()];
    }
};

comptime {
    // SolAccountInfo C ABI is 56 bytes; the syscall reads accounts at this stride.
    std.debug.assert(@sizeOf(CpiAccountInfo) == 56);
}
