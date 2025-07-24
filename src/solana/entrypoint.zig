const std = @import("std");
const builtin = @import("builtin");
const Pubkey = @import("pubkey.zig").Pubkey;
const AccountInfo = @import("account.zig").AccountInfo;
const log = @import("log.zig");

/// 程序结果类型
pub const ProgramResult = anyerror!void;

/// 处理指令的函数类型
pub const ProcessInstruction = fn (
    program_id: *const Pubkey,
    accounts: []AccountInfo,
    instruction_data: []const u8,
) ProgramResult;

/// 反序列化输入数据
fn deserializeInput(input: [*]const u8) !struct {
    program_id: *const Pubkey,
    accounts: []AccountInfo,
    instruction_data: []const u8,
} {
    var offset: usize = 0;
    
    // 读取账户数量
    const num_accounts = @as(*const u64, @ptrCast(@alignCast(input + offset))).*;
    offset += @sizeOf(u64);
    
    // 分配账户数组
    const allocator = std.heap.page_allocator;
    const accounts = try allocator.alloc(AccountInfo, num_accounts);
    
    // 反序列化每个账户
    for (accounts) |*account| {
        // 跳过 is_duplicate 标志
        const is_duplicate = input[offset];
        offset += 1;
        
        // 跳过填充
        offset += 7;
        
        // 读取 key
        account.key = @as(*const Pubkey, @ptrCast(@alignCast(input + offset)));
        offset += 32;
        
        // 读取 owner
        account.owner = @as(*const Pubkey, @ptrCast(@alignCast(input + offset)));
        offset += 32;
        
        // 读取 lamports
        account.lamports = @as(*u64, @ptrCast(@alignCast(input + offset)));
        offset += 8;
        
        // 读取数据长度
        const data_len = @as(*const u64, @ptrCast(@alignCast(input + offset))).*;
        offset += 8;
        
        // 设置数据指针
        if (data_len > 0) {
            account.data = @as([*]u8, @ptrCast(@constCast(input + offset)))[0..data_len];
            offset += data_len;
            
            // 对齐到 8 字节
            offset = (offset + 7) & ~@as(usize, 7);
        } else {
            account.data = &[_]u8{};
        }
        
        // 读取 executable
        account.executable = input[offset] != 0;
        offset += 1;
        
        // 跳过填充
        offset += 7;
        
        // 读取 rent_epoch
        account.rent_epoch = @as(*const u64, @ptrCast(@alignCast(input + offset))).*;
        offset += 8;
        
        // 处理重复账户
        if (is_duplicate != 0) {
            // 对于重复账户，某些字段可能需要引用之前的账户
            // 这里简化处理
        }
        
        // 设置权限标志（从输入数据的其他部分读取）
        // 这里简化为默认值
        account.is_signer = false;
        account.is_writable = false;
    }
    
    // 读取指令数据长度
    const instruction_data_len = @as(*const u64, @ptrCast(@alignCast(input + offset))).*;
    offset += 8;
    
    // 读取指令数据
    const instruction_data = if (instruction_data_len > 0)
        input[offset..offset + instruction_data_len]
    else
        &[_]u8{};
    offset += instruction_data_len;
    
    // 读取 program_id
    const program_id = @as(*const Pubkey, @ptrCast(@alignCast(input + offset)));
    
    return .{
        .program_id = program_id,
        .accounts = accounts,
        .instruction_data = instruction_data,
    };
}

/// 创建程序入口点
pub fn entrypoint(comptime process_instruction: ProcessInstruction) fn ([*]const u8) callconv(.C) u64 {
    return struct {
        fn entry(input: [*]const u8) callconv(.C) u64 {
            log.log("Program entrypoint");
            
            // 反序列化输入
            const parsed = deserializeInput(input) catch |err| {
                log.logPrint("Failed to deserialize input: {}", .{err});
                return 1;
            };
            
            // 调用处理函数
            process_instruction(
                parsed.program_id,
                parsed.accounts,
                parsed.instruction_data,
            ) catch |err| {
                log.logPrint("Program failed: {}", .{err});
                return @intFromError(err);
            };
            
            log.log("Program succeeded");
            return 0;
        }
    }.entry;
}

/// 声明程序入口点宏
pub fn declareEntrypoint(comptime process_instruction: ProcessInstruction) void {
    // 只在 BPF 目标上导出入口点
    if (builtin.target.cpu.arch == .bpfel or builtin.target.cpu.arch == .bpfeb) {
        const entrypointFn = entrypoint(process_instruction);
        @export(entrypointFn, .{
            .name = "entrypoint",
            .linkage = .strong,
        });
    }
}

/// 导出入口点的便捷函数
pub fn exportEntrypoint(comptime process_instruction: ProcessInstruction) void {
    if (builtin.target.cpu.arch == .bpfel or builtin.target.cpu.arch == .bpfeb) {
        const ep = struct {
            fn entrypoint_export(input: [*]u8) callconv(.C) u64 {
                return entrypoint(process_instruction)(input);
            }
        };
        @export(ep.entrypoint_export, .{
            .name = "entrypoint",
            .linkage = .strong,
        });
    }
}

/// 用于测试的模拟入口点
pub fn testEntrypoint(
    process_instruction: ProcessInstruction,
    program_id: *const Pubkey,
    accounts: []AccountInfo,
    instruction_data: []const u8,
) !void {
    try process_instruction(program_id, accounts, instruction_data);
}

// 示例处理函数
fn exampleProcessInstruction(
    program_id: *const Pubkey,
    accounts: []AccountInfo,
    instruction_data: []const u8,
) ProgramResult {
    log.logPrint("Processing instruction for program: {}", .{program_id});
    log.logPrint("Number of accounts: {}", .{accounts.len});
    log.logPrint("Instruction data length: {}", .{instruction_data.len});
    return;
}

// 测试
test "entrypoint creation" {
    const testing = std.testing;
    _ = testing;
    
    // 创建测试数据
    var program_id = Pubkey.zero;
    var key = Pubkey.system_program_id;
    var owner = Pubkey.system_program_id;
    var lamports: u64 = 1000;
    var data = [_]u8{0} ** 32;
    
    var accounts = [_]AccountInfo{
        .{
            .key = &key,
            .is_signer = true,
            .is_writable = true,
            .lamports = &lamports,
            .data = &data,
            .owner = &owner,
            .executable = false,
            .rent_epoch = 0,
        },
    };
    
    const instruction_data = [_]u8{ 1, 2, 3, 4 };
    
    // 测试处理函数
    try testEntrypoint(
        exampleProcessInstruction,
        &program_id,
        &accounts,
        &instruction_data,
    );
}