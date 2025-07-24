const std = @import("std");
const builtin = @import("builtin");

/// Bincode 序列化错误
pub const Error = error{
    EndOfStream,
    BufferTooSmall,
    InvalidEnum,
    InvalidBool,
    InvalidOptional,
    Overflow,
    NoSpaceLeft,
    OutOfMemory,
};

/// 写入器接口
pub fn Writer(comptime WriterType: type) type {
    return struct {
        writer: WriterType,
        
        const Self = @This();
        
        pub fn writeByte(self: *Self, byte: u8) !void {
            try self.writer.writeByte(byte);
        }
        
        pub fn writeAll(self: *Self, bytes: []const u8) !void {
            try self.writer.writeAll(bytes);
        }
        
        pub fn writeInt(self: *Self, comptime T: type, value: T) !void {
            var bytes: [@sizeOf(T)]u8 = undefined;
            std.mem.writeInt(T, &bytes, value, .little);
            try self.writeAll(&bytes);
        }
        
        pub fn writeBool(self: *Self, value: bool) !void {
            try self.writeByte(if (value) 1 else 0);
        }
        
        pub fn writeOptional(self: *Self, value: anytype) !void {
            if (value) |v| {
                try self.writeByte(1);
                try write(self, v);
            } else {
                try self.writeByte(0);
            }
        }
        
        pub fn writeSlice(self: *Self, comptime T: type, slice: []const T) !void {
            try self.writeInt(u64, slice.len);
            for (slice) |item| {
                try write(self, item);
            }
        }
    };
}

/// 读取器接口
pub fn Reader(comptime ReaderType: type) type {
    return struct {
        reader: ReaderType,
        
        const Self = @This();
        
        pub fn readByte(self: *Self) !u8 {
            return self.reader.readByte();
        }
        
        pub fn readAll(self: *Self, buffer: []u8) !void {
            const n = try self.reader.readAll(buffer);
            if (n < buffer.len) return error.EndOfStream;
        }
        
        pub fn readInt(self: *Self, comptime T: type) !T {
            var bytes: [@sizeOf(T)]u8 = undefined;
            try self.readAll(&bytes);
            return std.mem.readInt(T, &bytes, .little);
        }
        
        pub fn readBool(self: *Self) !bool {
            const byte = try self.readByte();
            return switch (byte) {
                0 => false,
                1 => true,
                else => error.InvalidBool,
            };
        }
        
        pub fn readOptional(self: *Self, comptime T: type, allocator: std.mem.Allocator) !?T {
            const tag = try self.readByte();
            return switch (tag) {
                0 => null,
                1 => try read(self, T, allocator),
                else => error.InvalidOptional,
            };
        }
        
        pub fn readSlice(self: *Self, comptime T: type, allocator: std.mem.Allocator) ![]T {
            const len = try self.readInt(u64);
            if (len > 1024 * 1024) return error.Overflow; // 防止过大分配
            
            const slice = try allocator.alloc(T, len);
            errdefer allocator.free(slice);
            
            for (slice) |*item| {
                item.* = try read(self, T, allocator);
            }
            
            return slice;
        }
    };
}

/// 序列化任意类型
pub fn write(writer: anytype, value: anytype) Error!void {
    const T = @TypeOf(value);
    const type_info = @typeInfo(T);
    
    switch (type_info) {
        .int => try writer.writeInt(T, value),
        .float => {
            const Int = std.meta.Int(.unsigned, @bitSizeOf(T));
            try writer.writeInt(Int, @bitCast(value));
        },
        .bool => try writer.writeBool(value),
        .optional => try writer.writeOptional(value),
        .@"enum" => {
            const Tag = std.meta.Tag(T);
            try writer.writeInt(Tag, @intFromEnum(value));
        },
        .@"struct" => |s| {
            inline for (s.fields) |field| {
                try write(writer, @field(value, field.name));
            }
        },
        .array => {
            for (value) |item| {
                try write(writer, item);
            }
        },
        .pointer => |p| {
            switch (p.size) {
                .slice => {
                    try writer.writeSlice(p.child, value);
                },
                .one => {
                    try write(writer, value.*);
                },
                else => @compileError("Unsupported pointer type"),
            }
        },
        else => @compileError("Unsupported type: " ++ @typeName(T)),
    }
}

/// 反序列化任意类型
pub fn read(reader: anytype, comptime T: type, allocator: std.mem.Allocator) Error!T {
    const type_info = @typeInfo(T);
    
    switch (type_info) {
        .int => return reader.readInt(T),
        .float => {
            const Int = std.meta.Int(.unsigned, @bitSizeOf(T));
            const bits = try reader.readInt(Int);
            return @bitCast(bits);
        },
        .bool => return reader.readBool(),
        .optional => |o| {
            return reader.readOptional(o.child, allocator);
        },
        .@"enum" => {
            const Tag = std.meta.Tag(T);
            const tag = try reader.readInt(Tag);
            return std.meta.intToEnum(T, tag) catch error.InvalidEnum;
        },
        .@"struct" => |s| {
            var result: T = undefined;
            inline for (s.fields) |field| {
                @field(result, field.name) = try read(reader, field.type, allocator);
            }
            return result;
        },
        .array => |a| {
            var result: T = undefined;
            for (&result) |*item| {
                item.* = try read(reader, a.child, allocator);
            }
            return result;
        },
        .pointer => |p| {
            switch (p.size) {
                .slice => {
                    return reader.readSlice(p.child, allocator);
                },
                else => @compileError("Unsupported pointer type"),
            }
        },
        else => @compileError("Unsupported type: " ++ @typeName(T)),
    }
}

/// 序列化到字节切片
pub fn writeToSlice(buffer: []u8, value: anytype) ![]u8 {
    var stream = std.io.fixedBufferStream(buffer);
    var writer = Writer(@TypeOf(stream.writer())){
        .writer = stream.writer(),
    };
    try write(&writer, value);
    return buffer[0..stream.pos];
}

/// 从字节切片反序列化
pub fn readFromSlice(comptime T: type, buffer: []const u8, allocator: std.mem.Allocator) !T {
    var stream = std.io.fixedBufferStream(buffer);
    var reader = Reader(@TypeOf(stream.reader())){
        .reader = stream.reader(),
    };
    return read(&reader, T, allocator);
}

/// 计算序列化后的大小
pub fn sizeOf(value: anytype) usize {
    const T = @TypeOf(value);
    const type_info = @typeInfo(T);
    
    switch (type_info) {
        .int, .float => return @sizeOf(T),
        .bool => return 1,
        .optional => {
            if (value) |v| {
                return 1 + sizeOf(v);
            } else {
                return 1;
            }
        },
        .@"enum" => return @sizeOf(std.meta.Tag(T)),
        .@"struct" => |s| {
            var size: usize = 0;
            inline for (s.fields) |field| {
                size += sizeOf(@field(value, field.name));
            }
            return size;
        },
        .array => {
            var size: usize = 0;
            for (value) |item| {
                size += sizeOf(item);
            }
            return size;
        },
        .pointer => |p| {
            switch (p.size) {
                .slice => {
                    var size: usize = 8; // 长度
                    for (value) |item| {
                        size += sizeOf(item);
                    }
                    return size;
                },
                .One => return sizeOf(value.*),
                else => @compileError("Unsupported pointer type"),
            }
        },
        else => @compileError("Unsupported type: " ++ @typeName(T)),
    }
}

// 测试
test "bincode basic types" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    // 整数
    {
        var buffer: [8]u8 = undefined;
        const result = try writeToSlice(&buffer, @as(u64, 0x0123456789ABCDEF));
        try testing.expectEqualSlices(u8, &[_]u8{ 0xEF, 0xCD, 0xAB, 0x89, 0x67, 0x45, 0x23, 0x01 }, result);
        
        const decoded = try readFromSlice(u64, result, allocator);
        try testing.expectEqual(@as(u64, 0x0123456789ABCDEF), decoded);
    }
    
    // 布尔值
    {
        var buffer: [1]u8 = undefined;
        _ = try writeToSlice(&buffer, true);
        try testing.expectEqual(@as(u8, 1), buffer[0]);
        
        _ = try writeToSlice(&buffer, false);
        try testing.expectEqual(@as(u8, 0), buffer[0]);
    }
}

test "bincode struct" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    const TestStruct = struct {
        a: u32,
        b: bool,
        c: u64,
    };
    
    const value = TestStruct{
        .a = 42,
        .b = true,
        .c = 1000,
    };
    
    var buffer: [128]u8 = undefined;
    const encoded = try writeToSlice(&buffer, value);
    
    const decoded = try readFromSlice(TestStruct, encoded, allocator);
    try testing.expectEqual(value.a, decoded.a);
    try testing.expectEqual(value.b, decoded.b);
    try testing.expectEqual(value.c, decoded.c);
}

test "bincode optional" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    // Some
    {
        var buffer: [16]u8 = undefined;
        const value: ?u32 = 42;
        const encoded = try writeToSlice(&buffer, value);
        
        const decoded = try readFromSlice(?u32, encoded, allocator);
        try testing.expectEqual(value, decoded);
    }
    
    // None
    {
        var buffer: [16]u8 = undefined;
        const value: ?u32 = null;
        const encoded = try writeToSlice(&buffer, value);
        
        const decoded = try readFromSlice(?u32, encoded, allocator);
        try testing.expectEqual(value, decoded);
    }
}

test "bincode slice" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    const data = [_]u32{ 1, 2, 3, 4, 5 };
    
    var buffer: [128]u8 = undefined;
    const encoded = try writeToSlice(&buffer, data[0..]);
    
    const decoded = try readFromSlice([]u32, encoded, allocator);
    defer allocator.free(decoded);
    
    try testing.expectEqualSlices(u32, &data, decoded);
}