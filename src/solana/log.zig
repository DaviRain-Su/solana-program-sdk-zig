const std = @import("std");
const builtin = @import("builtin");

/// Solana 日志系统调用
extern fn sol_log_(message: [*]const u8, len: u64) callconv(.C) void;
extern fn sol_log_64_(a: u64, b: u64, c: u64, d: u64, e: u64) callconv(.C) void;
extern fn sol_log_pubkey(pubkey: [*]const u8) callconv(.C) void;
extern fn sol_log_compute_units_() callconv(.C) void;

/// 记录消息到 Solana 日志
pub fn log(message: []const u8) void {
    if (builtin.target.cpu.arch == .bpfel or builtin.target.cpu.arch == .bpfeb) {
        sol_log_(message.ptr, message.len);
    } else {
        // 在非 BPF 环境中，使用标准输出
        std.debug.print("{s}\n", .{message});
    }
}

/// 记录格式化消息
pub fn logPrint(comptime fmt: []const u8, args: anytype) void {
    var buffer: [256]u8 = undefined;
    const message = std.fmt.bufPrint(&buffer, fmt, args) catch |print_err| {
        switch (print_err) {
            error.NoSpaceLeft => {
                log("Log message too long, truncated");
                log(buffer[0..255]);
                return;
            },
        }
    };
    log(message);
}

/// 记录公钥
pub fn logPubkey(label: []const u8, pubkey: [*]const u8) void {
    log(label);
    if (builtin.target.cpu.arch == .bpfel or builtin.target.cpu.arch == .bpfeb) {
        sol_log_pubkey(pubkey);
    } else {
        // 在非 BPF 环境中，打印公钥的十六进制表示
        const hex = std.fmt.bytesToHex(pubkey[0..32], .lower);
        std.debug.print("  {s}\n", .{hex});
    }
}

/// 记录最多 5 个 u64 值
pub fn logData(a: u64, b: u64, c: u64, d: u64, e: u64) void {
    if (builtin.target.cpu.arch == .bpfel or builtin.target.cpu.arch == .bpfeb) {
        sol_log_64_(a, b, c, d, e);
    } else {
        std.debug.print("Data: {} {} {} {} {}\n", .{ a, b, c, d, e });
    }
}

/// 记录计算单元消耗
pub fn logComputeUnits() void {
    if (builtin.target.cpu.arch == .bpfel or builtin.target.cpu.arch == .bpfeb) {
        sol_log_compute_units_();
    } else {
        log("Compute units logging not available in non-BPF environment");
    }
}

/// 断言宏，在失败时记录错误
pub fn assert(condition: bool, message: []const u8) void {
    if (!condition) {
        logPrint("Assertion failed: {s}", .{message});
        // 在 BPF 环境中，触发程序失败
        if (builtin.target.cpu.arch == .bpfel or builtin.target.cpu.arch == .bpfeb) {
            @panic("assertion failed");
        }
    }
}

/// 记录错误并返回
pub fn logError(error_value: anyerror, context: []const u8) anyerror {
    logPrint("Error: {} - {s}", .{ error_value, context });
    return error_value;
}

/// 日志级别
pub const LogLevel = enum {
    debug,
    info,
    warn,
    err,
    
    pub fn toString(self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "[DEBUG]",
            .info => "[INFO]",
            .warn => "[WARN]",
            .err => "[ERROR]",
        };
    }
};

/// 带级别的日志记录器
pub const Logger = struct {
    level: LogLevel = .info,
    
    pub fn init(level: LogLevel) Logger {
        return .{ .level = level };
    }
    
    pub fn debug(self: Logger, comptime fmt: []const u8, args: anytype) void {
        if (@intFromEnum(self.level) <= @intFromEnum(LogLevel.debug)) {
            logPrint("[DEBUG] " ++ fmt, args);
        }
    }
    
    pub fn info(self: Logger, comptime fmt: []const u8, args: anytype) void {
        if (@intFromEnum(self.level) <= @intFromEnum(LogLevel.info)) {
            logPrint("[INFO] " ++ fmt, args);
        }
    }
    
    pub fn warn(self: Logger, comptime fmt: []const u8, args: anytype) void {
        if (@intFromEnum(self.level) <= @intFromEnum(LogLevel.warn)) {
            logPrint("[WARN] " ++ fmt, args);
        }
    }
    
    pub fn err(self: Logger, comptime fmt: []const u8, args: anytype) void {
        if (@intFromEnum(self.level) <= @intFromEnum(LogLevel.err)) {
            logPrint("[ERROR] " ++ fmt, args);
        }
    }
};

/// 默认日志记录器
pub const default_logger = Logger.init(.info);

// 便捷函数
pub const debug = default_logger.debug;
pub const info = default_logger.info;
pub const warn = default_logger.warn;
pub const err = default_logger.err;

// 测试
test "log functions" {
    const testing = std.testing;
    _ = testing;
    
    // 基本日志
    log("Test log message");
    
    // 格式化日志
    logPrint("Test formatted: {} {s}", .{ 42, "hello" });
    
    // 数据日志
    logData(1, 2, 3, 4, 5);
    
    // 日志级别
    const logger = Logger.init(.debug);
    logger.debug("Debug message", .{});
    logger.info("Info message", .{});
    logger.warn("Warning message", .{});
    logger.err("Error message", .{});
}

test "assert" {
    assert(true, "This should not fail");
    // assert(false, "This would fail"); // 会导致 panic
}