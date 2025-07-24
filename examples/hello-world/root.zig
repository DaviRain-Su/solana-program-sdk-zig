const std = @import("std");
const solana = @import("solana_program_sdk_zig_lib").solana;

/// Hello World 程序的处理函数
pub fn processInstruction(
    program_id: *const solana.Pubkey,
    accounts: []solana.AccountInfo,
    instruction_data: []const u8,
) solana.ProgramResult {
    // 记录程序被调用
    solana.log.log("Hello World from Zig!");

    // 记录程序 ID
    solana.log.logPubkey("Program ID:", &program_id.bytes);

    // 记录账户数量
    solana.log.logPrint("Number of accounts: {}", .{accounts.len});

    // 记录指令数据
    solana.log.logPrint("Instruction data length: {}", .{instruction_data.len});
    if (instruction_data.len > 0) {
        solana.log.log("Instruction data:");
        for (instruction_data, 0..) |byte, i| {
            if (i >= 16) break; // 最多显示前 16 个字节
            solana.log.logPrint("  [{d}]: {d} (0x{x:0>2})", .{ i, byte, byte });
        }
    }

    // 遍历所有账户
    for (accounts, 0..) |*account, i| {
        solana.log.logPrint("Account {}:", .{i});
        solana.log.logPubkey("  Key:", &account.key.bytes);
        solana.log.logPrint("  Lamports: {}", .{account.lamports.*});
        solana.log.logPrint("  Data length: {}", .{account.data.len});
        solana.log.logPrint("  Owner:", .{});
        solana.log.logPubkey("    ", &account.owner.bytes);
        solana.log.logPrint("  Executable: {}", .{account.executable});
        solana.log.logPrint("  Rent epoch: {}", .{account.rent_epoch});
        solana.log.logPrint("  Is signer: {}", .{account.is_signer});
        solana.log.logPrint("  Is writable: {}", .{account.is_writable});
    }

    // 如果有指令数据，根据第一个字节执行不同操作
    if (instruction_data.len > 0) {
        const command = instruction_data[0];
        switch (command) {
            0 => {
                solana.log.log("Command: Initialize");
                // TODO: 实现初始化逻辑
            },
            1 => {
                solana.log.log("Command: Update");
                // TODO: 实现更新逻辑
            },
            2 => {
                solana.log.log("Command: Query");
                // TODO: 实现查询逻辑
            },
            else => {
                solana.log.logPrint("Unknown command: {}", .{command});
                return solana.ProgramError.InvalidInstruction;
            },
        }
    }

    solana.log.log("Hello World program completed successfully!");
    return;
}
