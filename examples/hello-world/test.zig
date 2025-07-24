const std = @import("std");
const solana = @import("solana_program_sdk_zig_lib").solana;

// 导入处理函数
const processInstruction = @import("root.zig").processInstruction;

pub fn main() !void {
    std.debug.print("\n=== Testing Hello World Program ===\n", .{});
    
    // 创建测试数据
    var program_id = solana.Pubkey.init([_]u8{1} ** 32);
    
    // 创建测试账户
    var account1_key = solana.Pubkey.init([_]u8{2} ** 32);
    var account1_owner = solana.Pubkey.system_program_id;
    var account1_lamports: u64 = 1000000;
    var account1_data = [_]u8{0} ** 64;
    
    var account2_key = solana.Pubkey.init([_]u8{3} ** 32);
    var account2_owner = program_id;
    var account2_lamports: u64 = 500000;
    var account2_data = [_]u8{42} ** 32;
    
    var accounts = [_]solana.AccountInfo{
        .{
            .key = &account1_key,
            .is_signer = true,
            .is_writable = true,
            .lamports = &account1_lamports,
            .data = &account1_data,
            .owner = &account1_owner,
            .executable = false,
            .rent_epoch = 0,
        },
        .{
            .key = &account2_key,
            .is_signer = false,
            .is_writable = false,
            .lamports = &account2_lamports,
            .data = &account2_data,
            .owner = &account2_owner,
            .executable = false,
            .rent_epoch = 0,
        },
    };
    
    // 测试 1: 无指令数据
    std.debug.print("\nTest 1: No instruction data\n", .{});
    try solana.entrypoint.testEntrypoint(
        processInstruction,
        &program_id,
        &accounts,
        &[_]u8{},
    );
    
    // 测试 2: Initialize 命令
    std.debug.print("\nTest 2: Initialize command\n", .{});
    const init_data = [_]u8{ 0, 1, 2, 3, 4 };
    try solana.entrypoint.testEntrypoint(
        processInstruction,
        &program_id,
        &accounts,
        &init_data,
    );
    
    // 测试 3: Update 命令
    std.debug.print("\nTest 3: Update command\n", .{});
    const update_data = [_]u8{ 1, 10, 20, 30 };
    try solana.entrypoint.testEntrypoint(
        processInstruction,
        &program_id,
        &accounts,
        &update_data,
    );
    
    // 测试 4: Query 命令
    std.debug.print("\nTest 4: Query command\n", .{});
    const query_data = [_]u8{2};
    try solana.entrypoint.testEntrypoint(
        processInstruction,
        &program_id,
        &accounts,
        &query_data,
    );
    
    // 测试 5: 无效命令（应该失败）
    std.debug.print("\nTest 5: Invalid command (should fail)\n", .{});
    const invalid_data = [_]u8{99};
    solana.entrypoint.testEntrypoint(
        processInstruction,
        &program_id,
        &accounts,
        &invalid_data,
    ) catch |err| {
        std.debug.print("Expected error: {}\n", .{err});
    };
    
    std.debug.print("\n=== All tests completed ===\n", .{});
}