/// Solana Program SDK for Zig
/// 
/// This SDK provides a Zig interface for developing Solana programs.
const lib = @import("solana/lib.zig");

// Re-export everything from lib
pub const Pubkey = lib.Pubkey;
pub const AccountInfo = lib.AccountInfo;
pub const AccountMeta = lib.AccountMeta;
pub const AccountInfoIter = lib.AccountInfoIter;
pub const ProgramError = lib.ProgramError;
pub const ProgramResult = lib.ProgramResult;
pub const ProcessInstruction = lib.ProcessInstruction;
pub const Context = lib.Context;

// Re-export modules
pub const log = lib.log;
pub const syscalls = lib.syscalls;
pub const base58 = lib.base58;
pub const bincode = lib.bincode;

// Re-export functions
pub const declareEntrypoint = lib.declareEntrypoint;
pub const logPrint = lib.logPrint;

test {
    _ = @import("solana/lib.zig");
}
