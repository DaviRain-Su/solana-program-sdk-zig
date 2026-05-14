//! Shared `Field` equality assertions for package tests (not public API).

const std = @import("std");
const state = @import("state.zig");

pub fn expectField(actual: state.Field, expected: state.Field) !void {
    switch (expected) {
        .name => try std.testing.expect(switch (actual) {
            .name => true,
            else => false,
        }),
        .symbol => try std.testing.expect(switch (actual) {
            .symbol => true,
            else => false,
        }),
        .uri => try std.testing.expect(switch (actual) {
            .uri => true,
            else => false,
        }),
        .key => |expected_key| switch (actual) {
            .key => |actual_key| try std.testing.expectEqualStrings(expected_key, actual_key),
            else => return error.TestUnexpectedResult,
        },
    }
}
