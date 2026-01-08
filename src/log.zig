const std = @import("std");
const bpf = @import("bpf.zig");

pub inline fn log(message: []const u8) void {
    if (bpf.is_bpf_program) {
        const Syscall = struct {
            extern fn sol_log_(ptr: [*]const u8, len: u64) callconv(.c) void;
        };
        Syscall.sol_log_(message.ptr, message.len);
    } else {
        std.debug.print("{s}\n", .{message});
    }
}

pub fn print(comptime format: []const u8, args: anytype) void {
    if (!bpf.is_bpf_program) {
        return std.debug.print(format ++ "\n", args);
    }

    if (args.len == 0) {
        return log(format);
    }

    var buffer: [1024]u8 = undefined;
    const message = std.fmt.bufPrint(&buffer, format, args) catch return;
    return log(message);
}

pub inline fn logComputeUnits() void {
    if (bpf.is_bpf_program) {
        const Syscall = struct {
            extern fn sol_log_compute_units_() callconv(.c) void;
        };
        Syscall.sol_log_compute_units_();
    } else {
        std.debug.print("Compute units not available\n");
    }
}

pub inline fn logData(data: []const []const u8) void {
    if (bpf.is_bpf_program) {
        const Syscall = struct {
            extern fn sol_log_data(ptr: [*]const []const u8, len: u64) callconv(.c) void;
        };
        Syscall.sol_log_data(data.ptr, data.len);
    } else {
        // Format matches Solana's Program Log output: "Program data: <base64>..."
        std.debug.print("Program data:", .{});
        for (data) |slice| {
            const encoder = std.base64.standard.Encoder;
            var buf: [1024]u8 = undefined;
            const encoded = encoder.encode(&buf, slice);
            std.debug.print(" {s}", .{encoded});
        }
        std.debug.print("\n", .{});
    }
}

/// Formats data slices as base64-encoded strings (for non-BPF testing/debugging).
/// Returns a buffer containing "Program data: <base64> <base64> ..." format.
pub fn formatLogData(data: []const []const u8, out_buf: []u8) []const u8 {
    var stream = std.io.fixedBufferStream(out_buf);
    const writer = stream.writer();

    writer.writeAll("Program data:") catch return out_buf[0..0];
    for (data) |slice| {
        const encoder = std.base64.standard.Encoder;
        var buf: [1024]u8 = undefined;
        const encoded = encoder.encode(&buf, slice);
        writer.print(" {s}", .{encoded}) catch break;
    }

    return stream.getWritten();
}

test "logData: base64 encoding format" {
    const data1 = "Hello";
    const data2 = [_]u8{ 0x01, 0x02, 0x03 };

    const slices = [_][]const u8{ data1, &data2 };

    var buf: [256]u8 = undefined;
    const result = formatLogData(&slices, &buf);

    // "Hello" -> "SGVsbG8=" in base64
    // [0x01, 0x02, 0x03] -> "AQID" in base64
    try std.testing.expectEqualStrings("Program data: SGVsbG8= AQID", result);
}

test "logData: empty data" {
    const slices = [_][]const u8{};
    var buf: [256]u8 = undefined;
    const result = formatLogData(&slices, &buf);
    try std.testing.expectEqualStrings("Program data:", result);
}

test "logData: single slice" {
    const data = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
    const slices = [_][]const u8{&data};
    var buf: [256]u8 = undefined;
    const result = formatLogData(&slices, &buf);
    // 0xDEADBEEF -> "3q2+7w==" in base64
    try std.testing.expectEqualStrings("Program data: 3q2+7w==", result);
}
