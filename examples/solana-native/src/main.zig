const std = @import("std");
const solana = @import("solana");

/// 简单的 Solana 程序，使用 Solana 兼容的 Zig 编译器
export fn entrypoint(input: [*]u8) callconv(.C) u64 {
    // 使用 Solana 日志
    solana.log.log("Solana Native Zig Program!");
    
    // 解析输入（简化版本）
    var offset: usize = 0;
    
    // 读取账户数量
    const num_accounts = @as(*const u64, @ptrCast(@alignCast(input + offset))).*;
    offset += 8;
    
    solana.log.logPrint("Number of accounts: {}", .{num_accounts});
    
    // 成功返回
    return 0;
}

// 备用：使用 SDK 的处理函数方式
fn processInstruction(
    program_id: *const solana.Pubkey,
    accounts: []solana.AccountInfo,
    instruction_data: []const u8,
) solana.ProgramResult {
    solana.log.log("Processing instruction with SDK");
    solana.log.logPrint("Program ID: {}", .{program_id});
    solana.log.logPrint("Accounts: {}", .{accounts.len});
    solana.log.logPrint("Data length: {}", .{instruction_data.len});
    
    return;
}

// 如果使用 SDK 的声明式方法
// comptime {
//     solana.declareEntrypoint(processInstruction);
// }