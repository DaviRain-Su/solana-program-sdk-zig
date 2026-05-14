//! Token-2022 foundation state declarations.

const std = @import("std");

pub const AccountType = enum(u8) {
    uninitialized = 0,
    mint = 1,
    account = 2,
};

pub const AccountState = enum(u8) {
    uninitialized = 0,
    initialized = 1,
    frozen = 2,
};

pub fn parseAccountType(tag: u8) error{InvalidAccountData}!AccountType {
    return switch (tag) {
        0 => .uninitialized,
        1 => .mint,
        2 => .account,
        else => error.InvalidAccountData,
    };
}

pub fn parseAccountState(tag: u8) error{InvalidAccountData}!AccountState {
    return switch (tag) {
        0 => .uninitialized,
        1 => .initialized,
        2 => .frozen,
        else => error.InvalidAccountData,
    };
}

test "AccountType discriminants are canonical" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(AccountType.uninitialized));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(AccountType.mint));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(AccountType.account));
}

test "AccountState discriminants are canonical" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(AccountState.uninitialized));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(AccountState.initialized));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(AccountState.frozen));
}

test "parseAccountType accepts only canonical tags" {
    try std.testing.expectEqual(AccountType.uninitialized, try parseAccountType(0));
    try std.testing.expectEqual(AccountType.mint, try parseAccountType(1));
    try std.testing.expectEqual(AccountType.account, try parseAccountType(2));
    try std.testing.expectError(error.InvalidAccountData, parseAccountType(3));
    try std.testing.expectError(error.InvalidAccountData, parseAccountType(255));
}

test "parseAccountState accepts only canonical tags" {
    try std.testing.expectEqual(AccountState.uninitialized, try parseAccountState(0));
    try std.testing.expectEqual(AccountState.initialized, try parseAccountState(1));
    try std.testing.expectEqual(AccountState.frozen, try parseAccountState(2));
    try std.testing.expectError(error.InvalidAccountData, parseAccountState(3));
    try std.testing.expectError(error.InvalidAccountData, parseAccountState(255));
}
