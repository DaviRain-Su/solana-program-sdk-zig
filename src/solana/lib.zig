/// Solana Program SDK for Zig
pub const pubkey = @import("pubkey.zig");
pub const account = @import("account.zig");
pub const log = @import("log.zig");
pub const syscalls = @import("syscalls.zig");
pub const entrypoint = @import("entrypoint.zig");
pub const err = @import("error.zig");
pub const base58 = @import("base58.zig");
pub const bincode = @import("bincode.zig");
pub const context = @import("context.zig");

// 重新导出常用类型
pub const Pubkey = pubkey.Pubkey;
pub const AccountInfo = account.AccountInfo;
pub const AccountMeta = account.AccountMeta;
pub const AccountInfoIter = account.AccountInfoIter;
pub const ProgramError = err.ProgramError;
pub const ProgramResult = entrypoint.ProgramResult;
pub const ProcessInstruction = entrypoint.ProcessInstruction;
pub const Context = context.Context;

// 重新导出常用函数
pub const declareEntrypoint = entrypoint.declareEntrypoint;
pub const logPrint = log.logPrint;
pub const require = err.require;
pub const requireSigner = err.requireSigner;
pub const requireWritable = err.requireWritable;

// 系统程序 ID
pub const system_program_id = Pubkey.system_program_id;

// 测试所有模块
test {
    _ = @import("pubkey.zig");
    _ = @import("account.zig");
    _ = @import("log.zig");
    _ = @import("syscalls.zig");
    _ = @import("entrypoint.zig");
    _ = @import("error.zig");
    _ = @import("base58.zig");
    _ = @import("bincode.zig");
}