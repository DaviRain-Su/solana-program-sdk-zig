# Error Handling Guide

This guide covers ProgramError, TokenError, and AnchorError usage.

## ProgramError (Program SDK)

```zig
const sdk = @import("solana_program_sdk");
const ProgramError = sdk.ProgramError;
const ProgramResult = sdk.ProgramResult;

fn process(data: []const u8) ProgramResult {
    if (data.len == 0) return ProgramError.InvalidInstructionData;
    return null; // success
}
```

### Custom Errors

```zig
const ProgramError = @import("solana_sdk").ProgramError;

pub const MyError = enum(u32) {
    InvalidAmount = 1,
    Unauthorized = 2,
};

pub fn toProgramError(err: MyError) ProgramError {
    return ProgramError.custom(@intFromEnum(err));
}
```

### Decode

```zig
const ProgramError = @import("solana_sdk").ProgramError;

const code: u64 = some_error_code;
const err = ProgramError.fromU64(code);
const msg = err.toString();
```

## TokenError (SPL Token)

```zig
const TokenError = @import("solana_sdk").spl.token.TokenError;

if (TokenError.fromCode(err_code)) |err| {
    std.debug.print("Token error: {s}\n", .{err.message()});
}
```

## AnchorError (sol-anchor-zig)

```zig
const AnchorError = @import("sol_anchor_zig").AnchorError;

if (AnchorError.fromU32(err_code)) |err| {
    std.debug.print("Anchor error: {s}\n", .{err.message()});
}
```

### Custom Anchor Errors

```zig
const anchor = @import("sol_anchor_zig");

pub const MyAnchorError = enum(u32) {
    InvalidAmount = anchor.customErrorCode(0),
    Unauthorized = anchor.customErrorCode(1),
};
```

## Related

- `sdk/src/error.zig`
- `sdk/src/spl/token/error.zig`
- `anchor/src/error.zig`
- [Token Programs](TOKEN_PROGRAMS.md)
