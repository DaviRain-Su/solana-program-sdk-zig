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
        ///
        /// Builds an extern struct on the stack with the comptime
        /// discriminant baked into the field initializer, then
        /// bitcasts to the byte array. This lets LLVM emit a single
        /// sized-immediate store for the discriminant instead of a
        /// `@memcpy` of 1-8 bytes — matches what Pinocchio's
        /// `CreateAccount.invoke_signed` does with raw
        /// `copy_nonoverlapping` calls.
        pub inline fn initWithDiscriminant(comptime discriminant: Discriminant, data: Data) [total_bytes]u8 {
            const Packed = extern struct {
                disc: Discriminant align(1),
                payload: Data align(1),
            };
            const packed_val = Packed{ .disc = discriminant, .payload = data };
            return @bitCast(packed_val);
        }
    };
}

/// Compile-time fixed instruction data with no variable fields.
/// Useful for instructions that only need a discriminant.
pub inline fn comptimeDiscriminantOnly(comptime discriminant: anytype) [(@bitSizeOf(@TypeOf(discriminant)) / 8)]u8 {
    return std.mem.asBytes(&discriminant).*;
}

// =============================================================================
// Unaligned typed reads — zero-cost deserialization helpers
// =============================================================================

/// Read a value of type `T` from `bytes` at `offset`, treating the
/// source as unaligned. Compiles to a single `ldxdw`/`ldxw`/etc.
/// instruction — identical BPF to the raw pointer-cast pattern.
///
/// **Bounds**: requires `bytes.len >= offset + @sizeOf(T)`. The check
/// is a runtime branch; if `offset` is comptime and `bytes.len` has a
/// known lower bound (e.g. the caller did `if (data.len < N) return …;`)
/// LLVM eliminates it.
///
/// Replaces the verbose:
/// ```zig
/// const amount: u64 = @as(*align(1) const u64, @ptrCast(data[1..9])).*;
/// ```
/// with:
/// ```zig
/// const amount = sol.instruction.readUnaligned(u64, data, 1);
/// ```
///
/// `T` must be a pointer-bitcast-safe type (primitive, `extern struct`
/// with `align(1)`, fixed-size array, packed struct). Verified at
/// comptime via `@sizeOf(T)`.
pub inline fn readUnaligned(comptime T: type, bytes: []const u8, comptime offset: usize) T {
    return @as(*align(1) const T, @ptrCast(bytes[offset..][0..@sizeOf(T)])).*;
}

/// Same as `readUnaligned` but takes a `[*]const u8` raw pointer.
/// Useful when you have a pointer into a larger buffer and want to
/// avoid forming a slice first.
pub inline fn readUnalignedPtr(comptime T: type, ptr: [*]const u8) T {
    return @as(*align(1) const T, @ptrCast(ptr)).*;
}

/// Bounds-checked `readUnaligned`. Returns `null` if `bytes` is too
/// short to contain a `T` starting at `offset`. Combines the two
/// always-paired statements:
/// ```zig
/// if (data.len < 9) return error.InvalidInstructionData;
/// const amount = readUnaligned(u64, data, 1);
/// ```
/// into:
/// ```zig
/// const amount = tryReadUnaligned(u64, data, 1)
///     orelse return error.InvalidInstructionData;
/// ```
///
/// Compiles to the same `ldxdw` + bounds-check as the explicit form —
/// LLVM merges the comptime-known length compare with any prior guard
/// in the caller.
pub inline fn tryReadUnaligned(comptime T: type, bytes: []const u8, comptime offset: usize) ?T {
    const end = offset + @sizeOf(T);
    if (bytes.len < end) return null;
    return @as(*align(1) const T, @ptrCast(bytes[offset..][0..@sizeOf(T)])).*;
}

/// Read the first byte(s) of `bytes` as a tag (enum) value.
/// Returns `null` if `bytes` is empty or the value doesn't correspond
/// to any variant of `Tag`. Replaces the boilerplate:
/// ```zig
/// if (data.len < 1) return error.InvalidInstructionData;
/// const tag: Ix = @enumFromInt(data[0]);  // UB if out of range!
/// ```
/// with:
/// ```zig
/// const tag = parseTag(Ix, data) orelse return error.InvalidInstructionData;
/// ```
///
/// `Tag` must be an `enum` with an integer tag type. The
/// discriminator is read from offset 0 as a comptime-sized unaligned
/// load. The validity check is an unrolled comptime switch over the
/// declared variants — no runtime table lookup.
pub inline fn parseTag(comptime Tag: type, bytes: []const u8) ?Tag {
    const info = @typeInfo(Tag);
    if (info != .@"enum") {
        @compileError("parseTag requires an enum type (got " ++ @typeName(Tag) ++ ")");
    }
    const TagInt = info.@"enum".tag_type;
    const raw = tryReadUnaligned(TagInt, bytes, 0) orelse return null;
    // Comptime-unrolled validity check against each declared variant.
    inline for (info.@"enum".fields) |field| {
        if (raw == field.value) return @enumFromInt(raw);
    }
    return null;
}

/// Faster `parseTag` variant for **exhaustive** enums whose variant
/// values span a dense `0..N-1` range. Skips the
/// `std.meta.intToEnum` bounds check (which compiles to a `switch`
/// over all variants). Caller must guarantee the source byte is
/// already in range — typically the case when the program's wire
/// protocol uses `@enumFromInt` directly anyway.
///
/// In benchmarks this saves 2-4 CU per dispatch on programs with
/// 3-4 ix variants vs. `parseTag`.
pub inline fn parseTagUnchecked(comptime Tag: type, bytes: []const u8) ?Tag {
    const info = @typeInfo(Tag);
    if (info != .@"enum") {
        @compileError("parseTagUnchecked requires an enum type");
    }
    const TagInt = info.@"enum".tag_type;
    const raw = tryReadUnaligned(TagInt, bytes, 0) orelse return null;
    return @enumFromInt(raw);
}

/// Typed reader over a `[]const u8` instruction-data buffer.
///
/// Wraps a slice and exposes typed field accessors at comptime-known
/// offsets. The discriminator byte (or u32) is treated as field 0;
/// remaining fields follow contiguously. All accessors are inline and
/// fold to single unaligned loads — identical BPF to hand-written
/// pointer casts.
///
/// Layout `Fields` must be an `extern struct` (so offsets are
/// deterministic at comptime). Field order matches the on-wire byte
/// order.
///
/// Example:
/// ```zig
/// const VaultDepositArgs = extern struct {
///     tag: u8,
///     amount: u64 align(1),
/// };
/// const args = sol.instruction.IxDataReader(VaultDepositArgs).bind(data)
///     orelse return error.InvalidInstructionData;
/// const amount = args.get(.amount); // single ldxdw, offset 1
/// ```
///
/// The `bind` constructor returns `null` if the slice is too short;
/// `bindUnchecked` skips the length check (caller asserts via prior
/// `data.len < N` guard, which LLVM then folds into a no-op).
pub fn IxDataReader(comptime Fields: type) type {
    comptime {
        const info = @typeInfo(Fields);
        if (info != .@"struct" or info.@"struct".layout != .@"extern") {
            @compileError("IxDataReader requires an extern struct (got " ++
                @typeName(Fields) ++ ")");
        }
    }

    return struct {
        const Self = @This();
        const size = @sizeOf(Fields);

        ptr: *align(1) const Fields,

        /// Bind a slice. Returns `null` if too short.
        pub inline fn bind(bytes: []const u8) ?Self {
            if (bytes.len < size) return null;
            return .{ .ptr = @ptrCast(bytes.ptr) };
        }

        /// Bind a slice without bounds check. Caller must have
        /// already verified `bytes.len >= @sizeOf(Fields)`.
        pub inline fn bindUnchecked(bytes: []const u8) Self {
            return .{ .ptr = @ptrCast(bytes.ptr) };
        }

        /// Read a single field by name. Comptime field-name → comptime
        /// offset → single unaligned load.
        pub inline fn get(self: Self, comptime field: std.meta.FieldEnum(Fields)) @FieldType(Fields, @tagName(field)) {
            return @field(self.ptr.*, @tagName(field));
        }

        /// Return a pointer to the whole struct. Useful when you want
        /// to pass the parsed args around as a single value.
        pub inline fn all(self: Self) *align(1) const Fields {
            return self.ptr;
        }
    };
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

test "instruction: readUnaligned primitive" {
    const data = [_]u8{ 0x01, 0xef, 0xcd, 0xab, 0x90, 0x78, 0x56, 0x34, 0x12 };
    const amount = readUnaligned(u64, &data, 1);
    try std.testing.expectEqual(@as(u64, 0x1234567890abcdef), amount);

    const tag = readUnaligned(u8, &data, 0);
    try std.testing.expectEqual(@as(u8, 1), tag);
}

test "instruction: readUnaligned struct" {
    const Args = extern struct {
        a: u32 align(1),
        b: u64 align(1),
    };
    const data = [_]u8{
        0x78, 0x56, 0x34, 0x12, // a = 0x12345678
        0xef, 0xcd, 0xab, 0x90, 0x78, 0x56, 0x34, 0x12, // b
    };
    const args = readUnaligned(Args, &data, 0);
    try std.testing.expectEqual(@as(u32, 0x12345678), args.a);
    try std.testing.expectEqual(@as(u64, 0x1234567890abcdef), args.b);
}

test "instruction: IxDataReader basic" {
    const VaultArgs = extern struct {
        tag: u8,
        amount: u64 align(1),
    };

    const data = [_]u8{
        2, // tag
        0xef, 0xcd, 0xab, 0x90, 0x78, 0x56, 0x34, 0x12, // amount
    };

    const r = IxDataReader(VaultArgs).bind(&data) orelse unreachable;
    try std.testing.expectEqual(@as(u8, 2), r.get(.tag));
    try std.testing.expectEqual(@as(u64, 0x1234567890abcdef), r.get(.amount));
}

test "instruction: IxDataReader bind returns null on short slice" {
    const VaultArgs = extern struct {
        tag: u8,
        amount: u64 align(1),
    };
    const short = [_]u8{ 1, 2, 3 };
    try std.testing.expect(IxDataReader(VaultArgs).bind(&short) == null);
}

test "instruction: tryReadUnaligned bounds" {
    const data = [_]u8{ 1, 0, 0, 0, 0, 0, 0, 0, 42 };
    try std.testing.expectEqual(@as(?u8, 1), tryReadUnaligned(u8, &data, 0));
    try std.testing.expectEqual(@as(?u64, 1), tryReadUnaligned(u64, &data, 0));
    try std.testing.expectEqual(@as(?u64, null), tryReadUnaligned(u64, &data, 2));
    try std.testing.expectEqual(@as(?u8, 42), tryReadUnaligned(u8, &data, 8));
    try std.testing.expectEqual(@as(?u8, null), tryReadUnaligned(u8, &data, 9));
}

test "instruction: parseTag" {
    const Ix = enum(u8) { initialize, deposit, withdraw };
    try std.testing.expectEqual(Ix.initialize, parseTag(Ix, &.{0}).?);
    try std.testing.expectEqual(Ix.deposit, parseTag(Ix, &.{ 1, 0xff }).?);
    try std.testing.expectEqual(Ix.withdraw, parseTag(Ix, &.{2}).?);
    try std.testing.expect(parseTag(Ix, &.{5}) == null); // out-of-range
    try std.testing.expect(parseTag(Ix, &.{}) == null); // empty
}

test "instruction: parseTag u32" {
    const Tag = enum(u32) { transfer, burn, mint };
    const data = [_]u8{ 2, 0, 0, 0, 0xff };
    try std.testing.expectEqual(Tag.mint, parseTag(Tag, &data).?);
}

test "instruction: parseTagUnchecked" {
    const Ix = enum(u8) { initialize, deposit, withdraw };
    try std.testing.expectEqual(Ix.deposit, parseTagUnchecked(Ix, &.{1}).?);
    try std.testing.expect(parseTagUnchecked(Ix, &.{}) == null);
}
