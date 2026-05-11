const std = @import("std");

/// Helper for no-alloc instruction data serialization.
///
/// By providing a discriminant and data type, the dynamic type can be
/// constructed in-place and used for instruction data:
///
/// ```zig
/// const Discriminant = enum(u32) {
///     one,
/// };
/// const Data = packed struct {
///     field: u64
/// };
/// const data = InstructionData(Discriminant, Data){
///     .discriminant = Discriminant.one,
///     .data = .{ .field = 1 }
/// };
/// const instruction = cpi.Instruction{
///     .program_id = &program_id,
///     .accounts = &accounts,
///     .data = data.asBytes(),
/// };
/// ```
pub fn InstructionData(comptime Discriminant: type, comptime Data: type) type {
    comptime {
        if (@bitSizeOf(Discriminant) % 8 != 0) {
            @panic("Discriminant bit size is not divisible by 8");
        }
        if (@bitSizeOf(Data) % 8 != 0) {
            @panic("Data bit size is not divisible by 8");
        }
    }
    return packed struct {
        discriminant: Discriminant,
        data: Data,

        const Self = @This();

        /// Get the instruction data as a byte slice
        pub fn asBytes(self: *const Self) []const u8 {
            return std.mem.asBytes(self)[0..((@bitSizeOf(Discriminant) + @bitSizeOf(Data)) / 8)];
        }
    };
}

/// Compile-time instruction data builder.
///
/// Creates a fixed-size instruction data buffer where the discriminant
/// is set at compile time, and only variable fields are filled at runtime.
///
/// Example:
/// ```zig
/// const CreateAccountData = comptimeInstructionData(u32, struct {
///     lamports: u64,
///     space: u64,
///     owner: [32]u8,
/// });
/// var data = CreateAccountData.init(.{
///     .discriminant = 0,  // CreateAccount
///     .lamports = 500,
///     .space = 128,
///     .owner = owner_pubkey,
/// });
/// ```
pub fn comptimeInstructionData(
    comptime Discriminant: type,
    comptime Data: type,
) type {
    comptime {
        if (@bitSizeOf(Discriminant) % 8 != 0) {
            @panic("Discriminant bit size is not divisible by 8");
        }
        if (@bitSizeOf(Data) % 8 != 0) {
            @panic("Data bit size is not divisible by 8");
        }
    }

    const total_bytes = (@bitSizeOf(Discriminant) + @bitSizeOf(Data)) / 8;

    return struct {
        pub const bytes = total_bytes;

        /// Initialize instruction data with compile-time discriminant and runtime data.
        pub inline fn init(comptime discriminant: Discriminant, data: Data) [total_bytes]u8 {
            return initWithDiscriminant(discriminant, data);
        }

        /// Create instruction data with a compile-time fixed discriminant.
        /// Only data fields are passed at runtime.
        pub inline fn initWithDiscriminant(comptime discriminant: Discriminant, data: Data) [total_bytes]u8 {
            var result: [total_bytes]u8 = undefined;

            // Write compile-time discriminant
            const d_bytes = std.mem.asBytes(&discriminant);
            @memcpy(result[0..d_bytes.len], d_bytes);

            // Write runtime data
            const data_start = d_bytes.len;
            const data_bytes = std.mem.asBytes(&data);
            @memcpy(result[data_start..][0..data_bytes.len], data_bytes);

            return result;
        }
    };
}

/// Compile-time fixed instruction data with no variable fields.
/// Useful for instructions that only need a discriminant.
pub inline fn comptimeDiscriminantOnly(comptime discriminant: anytype) [(@bitSizeOf(@TypeOf(discriminant)) / 8)]u8 {
    return std.mem.asBytes(&discriminant).*;
}

// =============================================================================
// Tests
// =============================================================================

test "instruction: data transmute" {
    const Discriminant = enum(u32) {
        zero,
        one,
        two,
        three,
    };

    const Data = packed struct {
        a: u8,
        b: u16,
        c: u64,
    };

    const instruction = InstructionData(Discriminant, Data){
        .discriminant = Discriminant.three,
        .data = .{ .a = 1, .b = 2, .c = 3 },
    };
    try std.testing.expectEqualSlices(u8, instruction.asBytes(), &[_]u8{ 3, 0, 0, 0, 1, 2, 0, 3, 0, 0, 0, 0, 0, 0, 0 });
}

test "instruction: comptimeInstructionData init" {
    const Data = extern struct {
        lamports: u64,
        space: u64,
    };

    const Builder = comptimeInstructionData(u32, Data);
    const ix_data = Builder.init(2, .{ .lamports = 100, .space = 200 });

    try std.testing.expectEqual(@as(u32, 2), std.mem.readInt(u32, ix_data[0..4], .little));
    try std.testing.expectEqual(@as(u64, 100), std.mem.readInt(u64, ix_data[4..12], .little));
    try std.testing.expectEqual(@as(u64, 200), std.mem.readInt(u64, ix_data[12..20], .little));
}

test "instruction: comptimeInstructionData initWithDiscriminant" {
    const Data = extern struct {
        lamports: u64,
        space: u64,
    };

    const Builder = comptimeInstructionData(u32, Data);
    const ix_data = Builder.initWithDiscriminant(2, .{ .lamports = 100, .space = 200 });

    try std.testing.expectEqual(@as(u32, 2), std.mem.readInt(u32, ix_data[0..4], .little));
    try std.testing.expectEqual(@as(u64, 100), std.mem.readInt(u64, ix_data[4..12], .little));
    try std.testing.expectEqual(@as(u64, 200), std.mem.readInt(u64, ix_data[12..20], .little));
}

test "instruction: discriminant only" {
    const ix_data = comptimeDiscriminantOnly(@as(u32, 5));
    try std.testing.expectEqual(@as(u32, 5), std.mem.readInt(u32, &ix_data, .little));
}
