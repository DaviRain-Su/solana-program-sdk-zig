const std = @import("std");

/// Solana 程序错误类型
pub const ProgramError = error{
    // 账户相关错误
    AccountAlreadyInitialized,
    AccountBorrowFailed,
    AccountDataTooSmall,
    AccountNotFound,
    AccountNotOwnedByProgram,
    AccountNotRentExempt,
    AccountNotWritable,
    AccountNotSigner,
    AccountNotExecutable,
    
    // 指令相关错误
    InvalidInstruction,
    InvalidInstructionData,
    InvalidAccountData,
    InvalidArgument,
    InvalidSeeds,
    
    // 算术错误
    ArithmeticOverflow,
    ArithmeticUnderflow,
    DivisionByZero,
    
    // 程序错误
    Custom,
    IncorrectProgramId,
    MissingRequiredSignature,
    ProgramFailedToComplete,
    
    // 系统错误
    InsufficientFunds,
    InvalidRent,
    MaxSeedLengthExceeded,
    
    // Borsh 序列化错误
    BorshIoError,
    BorshSerializationError,
    
    // 其他错误
    Uninitialized,
    NotEnoughAccountKeys,
    UnsupportedSysvar,
};

/// 将程序错误转换为错误码
pub fn errorToCode(err: ProgramError) u32 {
    return switch (err) {
        error.AccountAlreadyInitialized => 0,
        error.InvalidAccountData => 1,
        error.AccountNotOwnedByProgram => 2,
        error.AccountDataTooSmall => 3,
        error.InsufficientFunds => 4,
        error.IncorrectProgramId => 5,
        error.MissingRequiredSignature => 6,
        error.AccountNotRentExempt => 7,
        error.InvalidInstruction => 8,
        error.AccountBorrowFailed => 9,
        error.AccountNotExecutable => 10,
        error.AccountNotFound => 11,
        error.InvalidArgument => 12,
        error.InvalidInstructionData => 13,
        error.InvalidSeeds => 14,
        error.ArithmeticOverflow => 15,
        error.Uninitialized => 16,
        error.NotEnoughAccountKeys => 17,
        error.AccountNotWritable => 18,
        error.AccountNotSigner => 19,
        error.MaxSeedLengthExceeded => 20,
        error.InvalidRent => 21,
        error.UnsupportedSysvar => 22,
        error.ArithmeticUnderflow => 23,
        error.DivisionByZero => 24,
        error.BorshIoError => 25,
        error.BorshSerializationError => 26,
        error.ProgramFailedToComplete => 27,
        error.Custom => 100,
    };
}

/// 从错误码创建错误
pub fn codeToError(code: u32) ?ProgramError {
    return switch (code) {
        0 => error.AccountAlreadyInitialized,
        1 => error.InvalidAccountData,
        2 => error.AccountNotOwnedByProgram,
        3 => error.AccountDataTooSmall,
        4 => error.InsufficientFunds,
        5 => error.IncorrectProgramId,
        6 => error.MissingRequiredSignature,
        7 => error.AccountNotRentExempt,
        8 => error.InvalidInstruction,
        9 => error.AccountBorrowFailed,
        10 => error.AccountNotExecutable,
        11 => error.AccountNotFound,
        12 => error.InvalidArgument,
        13 => error.InvalidInstructionData,
        14 => error.InvalidSeeds,
        15 => error.ArithmeticOverflow,
        16 => error.Uninitialized,
        17 => error.NotEnoughAccountKeys,
        18 => error.AccountNotWritable,
        19 => error.AccountNotSigner,
        20 => error.MaxSeedLengthExceeded,
        21 => error.InvalidRent,
        22 => error.UnsupportedSysvar,
        23 => error.ArithmeticUnderflow,
        24 => error.DivisionByZero,
        25 => error.BorshIoError,
        26 => error.BorshSerializationError,
        27 => error.ProgramFailedToComplete,
        100 => error.Custom,
        else => null,
    };
}

/// 获取错误描述
pub fn errorDescription(err: ProgramError) []const u8 {
    return switch (err) {
        error.AccountAlreadyInitialized => "The account cannot be initialized because it is already being used",
        error.InvalidAccountData => "The account data is invalid",
        error.AccountNotOwnedByProgram => "The account is not owned by this program",
        error.AccountDataTooSmall => "The account data is too small",
        error.InsufficientFunds => "Insufficient funds for the operation",
        error.IncorrectProgramId => "The program ID is incorrect",
        error.MissingRequiredSignature => "Missing required signature",
        error.AccountNotRentExempt => "The account is not rent exempt",
        error.InvalidInstruction => "Invalid instruction",
        error.AccountBorrowFailed => "Failed to borrow account",
        error.AccountNotExecutable => "The account is not executable",
        error.AccountNotFound => "Account not found",
        error.InvalidArgument => "Invalid argument",
        error.InvalidInstructionData => "Invalid instruction data",
        error.InvalidSeeds => "Invalid seeds for PDA",
        error.ArithmeticOverflow => "Arithmetic overflow",
        error.Uninitialized => "The account has not been initialized",
        error.NotEnoughAccountKeys => "Not enough account keys provided",
        error.AccountNotWritable => "The account is not writable",
        error.AccountNotSigner => "The account is not a signer",
        error.MaxSeedLengthExceeded => "Max seed length exceeded",
        error.InvalidRent => "Invalid rent",
        error.UnsupportedSysvar => "Unsupported sysvar",
        error.ArithmeticUnderflow => "Arithmetic underflow",
        error.DivisionByZero => "Division by zero",
        error.BorshIoError => "Borsh I/O error",
        error.BorshSerializationError => "Borsh serialization error",
        error.ProgramFailedToComplete => "Program failed to complete",
        error.Custom => "Custom program error",
    };
}

/// 自定义错误类型，可以包含额外信息
pub const CustomError = struct {
    code: u32,
    message: []const u8,
    
    pub fn init(code: u32, message: []const u8) CustomError {
        return .{ .code = code, .message = message };
    }
    
    pub fn toError(self: CustomError) ProgramError {
        _ = self;
        return error.Custom;
    }
};

/// 结果类型别名
pub fn Result(comptime T: type) type {
    return ProgramError!T;
}

/// 检查条件，如果为假则返回错误
pub fn require(condition: bool, err: ProgramError) !void {
    if (!condition) {
        return err;
    }
}

/// 检查账户是否为签名者
pub fn requireSigner(is_signer: bool) !void {
    try require(is_signer, error.MissingRequiredSignature);
}

/// 检查账户是否可写
pub fn requireWritable(is_writable: bool) !void {
    try require(is_writable, error.AccountNotWritable);
}

/// 检查账户所有者
pub fn requireOwner(actual_owner: anytype, expected_owner: anytype) !void {
    try require(actual_owner.equals(expected_owner), error.AccountNotOwnedByProgram);
}

/// 检查账户是否已初始化
pub fn requireInitialized(data: []const u8) !void {
    try require(data.len > 0, error.Uninitialized);
}

/// 检查账户是否未初始化
pub fn requireUninitialized(data: []const u8) !void {
    try require(data.len == 0, error.AccountAlreadyInitialized);
}

// 测试
test "error conversions" {
    const testing = std.testing;
    
    // 测试错误到代码的转换
    try testing.expectEqual(@as(u32, 0), errorToCode(error.AccountAlreadyInitialized));
    try testing.expectEqual(@as(u32, 8), errorToCode(error.InvalidInstruction));
    try testing.expectEqual(@as(u32, 100), errorToCode(error.Custom));
    
    // 测试代码到错误的转换
    try testing.expectEqual(@as(?ProgramError, error.AccountAlreadyInitialized), codeToError(0));
    try testing.expectEqual(@as(?ProgramError, error.InvalidInstruction), codeToError(8));
    try testing.expectEqual(@as(?ProgramError, null), codeToError(999));
}

test "require functions" {
    const testing = std.testing;
    
    // 测试 require
    try require(true, error.InvalidArgument);
    try testing.expectError(error.InvalidArgument, require(false, error.InvalidArgument));
    
    // 测试 requireSigner
    try requireSigner(true);
    try testing.expectError(error.MissingRequiredSignature, requireSigner(false));
    
    // 测试 requireWritable
    try requireWritable(true);
    try testing.expectError(error.AccountNotWritable, requireWritable(false));
}

test "error descriptions" {
    const testing = std.testing;
    
    const desc = errorDescription(error.AccountAlreadyInitialized);
    try testing.expect(desc.len > 0);
}