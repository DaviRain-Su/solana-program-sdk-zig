//! Token-2022 foundation state declarations.

const std = @import("std");

pub const AccountType = enum(u8) {
    uninitialized = 0,
    mint = 1,
    account = 2,
};

pub fn parseAccountType(tag: u8) error{InvalidAccountData}!AccountType {
    return switch (tag) {
        0 => .uninitialized,
        1 => .mint,
        2 => .account,
        else => error.InvalidAccountData,
    };
}

test "AccountType discriminants are canonical" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(AccountType.uninitialized));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(AccountType.mint));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(AccountType.account));
}

test "parseAccountType accepts only canonical tags" {
    try std.testing.expectEqual(AccountType.uninitialized, try parseAccountType(0));
    try std.testing.expectEqual(AccountType.mint, try parseAccountType(1));
    try std.testing.expectEqual(AccountType.account, try parseAccountType(2));
    try std.testing.expectError(error.InvalidAccountData, parseAccountType(3));
    try std.testing.expectError(error.InvalidAccountData, parseAccountType(255));
}
