const std = @import("std");
const builtin = @import("builtin");
const Pubkey = @import("pubkey.zig").Pubkey;

/// 系统调用错误码
pub const SyscallError = error{
    InvalidArgument,
    InvokeContextBorrowFailed,
    ComputeBudgetExceeded,
    PrivilegeEscalation,
    ProgramEnvironmentSetupFailure,
    ProgramFailedToComplete,
    ProgramFailedToCompile,
    AccountDataTooSmall,
    AccountNotExecutable,
    InvalidAccountData,
    InvalidSeeds,
    InvalidRealloc,
    Other,
};

/// 将系统调用返回值转换为错误
fn syscallResultToError(result: u64) !void {
    if (result == 0) return;
    
    return switch (result) {
        1 => error.InvalidArgument,
        2 => error.InvokeContextBorrowFailed,
        3 => error.ComputeBudgetExceeded,
        4 => error.PrivilegeEscalation,
        5 => error.ProgramEnvironmentSetupFailure,
        6 => error.ProgramFailedToComplete,
        7 => error.ProgramFailedToCompile,
        8 => error.AccountDataTooSmall,
        9 => error.AccountNotExecutable,
        10 => error.InvalidAccountData,
        11 => error.InvalidSeeds,
        12 => error.InvalidRealloc,
        else => error.Other,
    };
}

// 声明 Solana 系统调用
extern fn sol_sha256(vals: [*]const u8, val_len: u64, hash_result: [*]u8) callconv(.C) u64;
extern fn sol_keccak256(vals: [*]const u8, val_len: u64, hash_result: [*]u8) callconv(.C) u64;
extern fn sol_blake3(vals: [*]const u8, val_len: u64, hash_result: [*]u8) callconv(.C) u64;
extern fn sol_secp256k1_recover(
    hash: [*]const u8,
    recovery_id: u64,
    signature: [*]const u8,
    pubkey: [*]u8,
) callconv(.C) u64;

extern fn sol_get_clock_sysvar(ret: *Clock) callconv(.C) u64;
extern fn sol_get_rent_sysvar(ret: *Rent) callconv(.C) u64;
extern fn sol_get_epoch_schedule_sysvar(ret: *EpochSchedule) callconv(.C) u64;

extern fn sol_memcpy_(dst: [*]u8, src: [*]const u8, n: u64) callconv(.C) void;
extern fn sol_memmove_(dst: [*]u8, src: [*]const u8, n: u64) callconv(.C) void;
extern fn sol_memcmp_(s1: [*]const u8, s2: [*]const u8, n: u64, result: *i32) callconv(.C) void;
extern fn sol_memset_(s: [*]u8, c: u8, n: u64) callconv(.C) void;

extern fn sol_create_program_address(
    seeds: [*]const u8,
    seeds_len: u64,
    program_id: [*]const u8,
    address: [*]u8,
) callconv(.C) u64;

extern fn sol_try_find_program_address(
    seeds: [*]const u8,
    seeds_len: u64,
    program_id: [*]const u8,
    address: [*]u8,
    bump_seed: *u8,
) callconv(.C) u64;

/// 时钟系统变量
pub const Clock = extern struct {
    slot: u64,
    epoch_start_timestamp: i64,
    epoch: u64,
    leader_schedule_epoch: u64,
    unix_timestamp: i64,
};

/// 租金系统变量
pub const Rent = extern struct {
    lamports_per_byte_year: u64,
    exemption_threshold: f64,
    burn_percent: u8,
};

/// 纪元计划系统变量
pub const EpochSchedule = extern struct {
    slots_per_epoch: u64,
    leader_schedule_slot_offset: u64,
    warmup: bool,
    first_normal_epoch: u64,
    first_normal_slot: u64,
};

/// SHA256 哈希
pub fn sha256(data: []const u8, result: *[32]u8) !void {
    if (builtin.target.cpu.arch == .bpfel or builtin.target.cpu.arch == .bpfeb) {
        const ret = sol_sha256(data.ptr, data.len, result);
        try syscallResultToError(ret);
    } else {
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(data);
        hasher.final(result);
    }
}

/// Keccak256 哈希
pub fn keccak256(data: []const u8, result: *[32]u8) !void {
    if (builtin.target.cpu.arch == .bpfel or builtin.target.cpu.arch == .bpfeb) {
        const ret = sol_keccak256(data.ptr, data.len, result);
        try syscallResultToError(ret);
    } else {
        var hasher = std.crypto.hash.sha3.Keccak256.init(.{});
        hasher.update(data);
        hasher.final(result);
    }
}

/// Blake3 哈希
pub fn blake3(data: []const u8, result: *[32]u8) !void {
    if (builtin.target.cpu.arch == .bpfel or builtin.target.cpu.arch == .bpfeb) {
        const ret = sol_blake3(data.ptr, data.len, result);
        try syscallResultToError(ret);
    } else {
        // Blake3 在标准库中可能不可用，这里简化处理
        return error.NotImplemented;
    }
}

/// 获取时钟系统变量
pub fn getClock() !Clock {
    var clock: Clock = undefined;
    if (builtin.target.cpu.arch == .bpfel or builtin.target.cpu.arch == .bpfeb) {
        const ret = sol_get_clock_sysvar(&clock);
        try syscallResultToError(ret);
        return clock;
    } else {
        // 非 BPF 环境返回模拟数据
        return Clock{
            .slot = 0,
            .epoch_start_timestamp = 0,
            .epoch = 0,
            .leader_schedule_epoch = 0,
            .unix_timestamp = std.time.timestamp(),
        };
    }
}

/// 获取租金系统变量
pub fn getRent() !Rent {
    var rent: Rent = undefined;
    if (builtin.target.cpu.arch == .bpfel or builtin.target.cpu.arch == .bpfeb) {
        const ret = sol_get_rent_sysvar(&rent);
        try syscallResultToError(ret);
        return rent;
    } else {
        // 非 BPF 环境返回默认值
        return Rent{
            .lamports_per_byte_year = 3480,
            .exemption_threshold = 2.0,
            .burn_percent = 50,
        };
    }
}

/// 内存复制（使用 Solana 优化版本）
pub fn memcpy(dst: []u8, src: []const u8) void {
    if (builtin.target.cpu.arch == .bpfel or builtin.target.cpu.arch == .bpfeb) {
        sol_memcpy_(dst.ptr, src.ptr, @min(dst.len, src.len));
    } else {
        @memcpy(dst[0..@min(dst.len, src.len)], src[0..@min(dst.len, src.len)]);
    }
}

/// 内存移动（处理重叠区域）
pub fn memmove(dst: []u8, src: []const u8) void {
    if (builtin.target.cpu.arch == .bpfel or builtin.target.cpu.arch == .bpfeb) {
        sol_memmove_(dst.ptr, src.ptr, @min(dst.len, src.len));
    } else {
        std.mem.copyForwards(u8, dst[0..@min(dst.len, src.len)], src[0..@min(dst.len, src.len)]);
    }
}

/// 内存比较
pub fn memcmp(s1: []const u8, s2: []const u8) i32 {
    var result: i32 = 0;
    if (builtin.target.cpu.arch == .bpfel or builtin.target.cpu.arch == .bpfeb) {
        sol_memcmp_(s1.ptr, s2.ptr, @min(s1.len, s2.len), &result);
        return result;
    } else {
        return std.mem.order(u8, s1[0..@min(s1.len, s2.len)], s2[0..@min(s1.len, s2.len)]).compare(std.math.CompareOperator.eq);
    }
}

/// 内存设置
pub fn memset(dst: []u8, value: u8) void {
    if (builtin.target.cpu.arch == .bpfel or builtin.target.cpu.arch == .bpfeb) {
        sol_memset_(dst.ptr, value, dst.len);
    } else {
        @memset(dst, value);
    }
}

/// 创建程序派生地址
pub fn createProgramAddress(
    seeds: []const []const u8,
    program_id: *const Pubkey,
) !Pubkey {
    // 计算种子总长度
    var seeds_len: u64 = 0;
    for (seeds) |seed| {
        seeds_len += seed.len;
    }
    
    // 创建连续的种子缓冲区
    var seeds_buffer: [256]u8 = undefined;
    var offset: usize = 0;
    for (seeds) |seed| {
        @memcpy(seeds_buffer[offset..offset + seed.len], seed);
        offset += seed.len;
    }
    
    var address: Pubkey = undefined;
    
    if (builtin.target.cpu.arch == .bpfel or builtin.target.cpu.arch == .bpfeb) {
        const ret = sol_create_program_address(
            &seeds_buffer,
            seeds_len,
            &program_id.bytes,
            &address.bytes,
        );
        try syscallResultToError(ret);
    } else {
        // 非 BPF 环境使用纯 Zig 实现
        address = try Pubkey.createProgramAddress(seeds, program_id.*);
    }
    
    return address;
}

/// 尝试查找程序地址（带 bump）
pub fn tryFindProgramAddress(
    seeds: []const []const u8,
    program_id: *const Pubkey,
) !struct { address: Pubkey, bump: u8 } {
    // 准备种子缓冲区
    var seeds_len: u64 = 0;
    for (seeds) |seed| {
        seeds_len += seed.len;
    }
    
    var seeds_buffer: [256]u8 = undefined;
    var offset: usize = 0;
    for (seeds) |seed| {
        @memcpy(seeds_buffer[offset..offset + seed.len], seed);
        offset += seed.len;
    }
    
    var address: Pubkey = undefined;
    var bump: u8 = undefined;
    
    if (builtin.target.cpu.arch == .bpfel or builtin.target.cpu.arch == .bpfeb) {
        const ret = sol_try_find_program_address(
            &seeds_buffer,
            seeds_len,
            &program_id.bytes,
            &address.bytes,
            &bump,
        );
        try syscallResultToError(ret);
    } else {
        // 非 BPF 环境使用纯 Zig 实现
        const result = try Pubkey.findProgramAddress(seeds, program_id.*);
        address = result.pubkey;
        bump = result.bump;
    }
    
    return .{ .address = address, .bump = bump };
}

// 测试
test "hash functions" {
    const testing = std.testing;
    
    const data = "hello world";
    var hash: [32]u8 = undefined;
    
    // SHA256
    try sha256(data, &hash);
    // 在非 BPF 环境中验证结果
    if (builtin.target.cpu.arch != .bpfel and builtin.target.cpu.arch != .bpfeb) {
        var expected: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(data, &expected, .{});
        try testing.expectEqualSlices(u8, &expected, &hash);
    }
    
    // Keccak256
    try keccak256(data, &hash);
}

test "memory operations" {
    const testing = std.testing;
    
    var dst = [_]u8{0} ** 10;
    const src = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    
    // memcpy
    memcpy(&dst, &src);
    try testing.expectEqualSlices(u8, &src, &dst);
    
    // memset
    memset(&dst, 42);
    for (dst) |byte| {
        try testing.expectEqual(@as(u8, 42), byte);
    }
}