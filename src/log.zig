//! Logging utilities for Solana programs
//!
//! Provides wrappers around Solana logging syscalls with host fallbacks.

const std = @import("std");
const bpf = @import("bpf.zig");

extern fn sol_log_(ptr: [*]const u8, len: u64) callconv(.c) void;
extern fn sol_log_64_(arg1: u64, arg2: u64, arg3: u64, arg4: u64, arg5: u64) callconv(.c) void;
extern fn sol_log_compute_units_() callconv(.c) void;
extern fn sol_log_data(ptr: [*]const []const u8, len: u64) callconv(.c) void;
extern fn sol_get_compute_budget() callconv(.c) u64;

/// Log a message
pub inline fn log(message: []const u8) void {
    if (bpf.is_bpf_program) {
        sol_log_(message.ptr, message.len);
    } else {
        std.debug.print("[solana] {s}\n", .{message});
    }
}

/// Log a formatted message (host only)
pub fn print(comptime format: []const u8, args: anytype) void {
    if (!bpf.is_bpf_program) {
        return std.debug.print("[solana] " ++ format ++ "\n", args);
    }

    if (args.len == 0) {
        return log(format);
    }

    var buffer: [1024]u8 = undefined;
    const message = std.fmt.bufPrint(&buffer, format, args) catch return;
    return log(message);
}

/// Log 5 u64 values (useful for debugging)
pub inline fn log64(
    arg1: u64,
    arg2: u64,
    arg3: u64,
    arg4: u64,
    arg5: u64,
) void {
    if (bpf.is_bpf_program) {
        sol_log_64_(arg1, arg2, arg3, arg4, arg5);
    } else {
        std.debug.print("[solana] {d} {d} {d} {d} {d}\n", .{ arg1, arg2, arg3, arg4, arg5 });
    }
}

/// Log the current compute unit consumption
pub inline fn logComputeUnits() void {
    if (bpf.is_bpf_program) {
        sol_log_compute_units_();
    } else {
        std.debug.print("[solana] Compute units not available\n", .{});
    }
}

/// Log structured data
pub inline fn logData(data: []const []const u8) void {
    if (bpf.is_bpf_program) {
        sol_log_data(data.ptr, data.len);
    } else {
        std.debug.print("[solana] data: {any}\n", .{data});
    }
}

/// Get remaining compute units
///
/// Returns the number of compute units remaining for this transaction.
/// Note: This syscall may not be available on all Solana versions.
pub inline fn getRemainingComputeUnits() u64 {
    if (bpf.is_bpf_program) {
        return sol_get_compute_budget();
    } else {
        return 0;
    }
}

// =============================================================================
// Tests
// =============================================================================

test "log: basic" {
    log("test message");
}

test "log: print" {
    print("test format: {d}", .{42});
}

test "log: log64" {
    log64(1, 2, 3, 4, 5);
}

test "log: logComputeUnits" {
    logComputeUnits();
}

test "log: getRemainingComputeUnits" {
    _ = getRemainingComputeUnits();
}
