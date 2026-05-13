//! Token-2022 base layout constants.

const std = @import("std");

/// Canonical base mint payload length before any extension storage.
pub const MINT_BASE_LEN: usize = 82;
/// Canonical base token account payload length.
pub const ACCOUNT_BASE_LEN: usize = 165;
/// Mint extension padding starts immediately after the 82-byte mint base.
pub const MINT_PADDING_START: usize = MINT_BASE_LEN;
/// AccountType byte offset for extension-capable mint/account buffers.
pub const ACCOUNT_TYPE_OFFSET: usize = ACCOUNT_BASE_LEN;
/// TLV records begin immediately after the AccountType byte.
pub const TLV_START_OFFSET: usize = ACCOUNT_TYPE_OFFSET + 1;
/// One-past-the-end offset for the zero-padded mint extension prefix.
pub const MINT_PADDING_END: usize = ACCOUNT_TYPE_OFFSET;

test "base layout constants are canonical" {
    try std.testing.expectEqual(@as(usize, 82), MINT_BASE_LEN);
    try std.testing.expectEqual(@as(usize, 165), ACCOUNT_BASE_LEN);
    try std.testing.expectEqual(@as(usize, 82), MINT_PADDING_START);
    try std.testing.expectEqual(@as(usize, 165), ACCOUNT_TYPE_OFFSET);
    try std.testing.expectEqual(@as(usize, 166), TLV_START_OFFSET);
    try std.testing.expectEqual(@as(usize, 165), MINT_PADDING_END);
}
