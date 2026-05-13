//! Interface-state scaffold for `spl_token_metadata`.

const std = @import("std");
const sol = @import("solana_program_sdk");
const id = @import("id.zig");

pub const INTERFACE_NAMESPACE = id.INTERFACE_NAMESPACE;
pub const INTERFACE_DISCRIMINATOR_LEN: usize = sol.DISCRIMINATOR_LEN;
pub const SURFACE = "interface-only";

test "state scaffold exposes canonical namespace and discriminator width" {
    try std.testing.expectEqualStrings("spl_token_metadata_interface", INTERFACE_NAMESPACE);
    try std.testing.expectEqual(sol.DISCRIMINATOR_LEN, INTERFACE_DISCRIMINATOR_LEN);
    try std.testing.expectEqual(@as(usize, 8), INTERFACE_DISCRIMINATOR_LEN);
    try std.testing.expectEqualStrings("interface-only", SURFACE);
}

test "state scaffold stays parser-only placeholder" {
    try std.testing.expect(!@hasDecl(@This(), "processor"));
    try std.testing.expect(!@hasDecl(@This(), "mutate"));
    try std.testing.expect(!@hasDecl(@This(), "realloc"));
    try std.testing.expect(!@hasDecl(@This(), "transaction"));
}

test {
    std.testing.refAllDecls(@This());
}
