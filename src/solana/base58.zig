const std = @import("std");

/// Base58 字母表（Bitcoin 变体）
const ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
const ALPHABET_SIZE: u8 = 58;

/// Base58 解码表
const DECODE_TABLE = blk: {
    var table: [256]u8 = [_]u8{0xFF} ** 256;
    for (ALPHABET, 0..) |c, i| {
        table[c] = @intCast(i);
    }
    break :blk table;
};

/// 编码错误
pub const EncodeError = error{
    BufferTooSmall,
};

/// 解码错误
pub const DecodeError = error{
    InvalidCharacter,
    InvalidLength,
    BufferTooSmall,
};

/// 编码字节数组为 Base58 字符串
pub fn encode(data: []const u8, out: []u8) EncodeError![]const u8 {
    if (data.len == 0) return out[0..0];
    
    // 计算前导零的数量
    var zero_count: usize = 0;
    for (data) |byte| {
        if (byte == 0) {
            zero_count += 1;
        } else {
            break;
        }
    }
    
    // 临时缓冲区用于计算
    // Base58 编码后的最大长度约为原始数据的 1.37 倍
    const max_size = (data.len * 138) / 100 + 10; // 加一些额外空间
    if (out.len < max_size) return error.BufferTooSmall;
    
    var buf: [512]u8 = undefined; // 足够大的临时缓冲区
    var buf_len: usize = 0;
    
    // 将数据复制到工作缓冲区
    var work: [256]u8 = undefined;
    @memcpy(work[0..data.len], data);
    
    // 转换为 Base58
    var work_len = data.len;
    while (work_len > 0) {
        var carry: u16 = 0;
        var i: usize = 0;
        
        // 除以 58
        while (i < work_len) {
            carry = carry * 256 + work[i];
            work[i] = @intCast(carry / ALPHABET_SIZE);
            carry = carry % ALPHABET_SIZE;
            i += 1;
        }
        
        // 存储余数
        buf[buf_len] = @intCast(carry);
        buf_len += 1;
        
        // 移除前导零
        while (work_len > 0 and work[0] == 0) {
            std.mem.copyForwards(u8, work[0..work_len - 1], work[1..work_len]);
            work_len -= 1;
        }
    }
    
    // 添加前导 '1'
    var out_idx: usize = 0;
    var i: usize = 0;
    while (i < zero_count) : (i += 1) {
        out[out_idx] = '1';
        out_idx += 1;
    }
    
    // 反转并转换为字符
    i = buf_len;
    while (i > 0) {
        i -= 1;
        out[out_idx] = ALPHABET[buf[i]];
        out_idx += 1;
    }
    
    return out[0..out_idx];
}

/// 解码 Base58 字符串为字节数组
pub fn decode(str: []const u8, out: []u8) DecodeError![]const u8 {
    if (str.len == 0) return out[0..0];
    
    // 计算前导 '1' 的数量
    var one_count: usize = 0;
    for (str) |c| {
        if (c == '1') {
            one_count += 1;
        } else {
            break;
        }
    }
    
    // 临时缓冲区
    var buf: [256]u8 = [_]u8{0} ** 256;
    var buf_len: usize = 1;
    
    // 解码非 '1' 字符
    for (str[one_count..]) |c| {
        const val = DECODE_TABLE[c];
        if (val == 0xFF) return error.InvalidCharacter;
        
        // 乘以 58 并加上新值
        var carry: u32 = val;
        var i: usize = 0;
        while (i < buf_len) : (i += 1) {
            carry += @as(u32, buf[i]) * ALPHABET_SIZE;
            buf[i] = @intCast(carry & 0xFF);
            carry >>= 8;
        }
        
        while (carry > 0) {
            if (buf_len >= buf.len) return error.BufferTooSmall;
            buf[buf_len] = @intCast(carry & 0xFF);
            carry >>= 8;
            buf_len += 1;
        }
    }
    
    // 计算输出大小
    const out_size = one_count + buf_len - 1;
    if (out.len < out_size) return error.BufferTooSmall;
    
    // 写入前导零
    @memset(out[0..one_count], 0);
    
    // 反转并复制结果
    var i: usize = 0;
    var j = buf_len - 1;
    while (j > 0) : (j -= 1) {
        out[one_count + i] = buf[j];
        i += 1;
    }
    
    return out[0..out_size];
}

/// 编码到新分配的缓冲区
pub fn encodeAlloc(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const max_len = data.len * 2; // 保守估计
    const buffer = try allocator.alloc(u8, max_len);
    errdefer allocator.free(buffer);
    
    const result = try encode(data, buffer);
    // 调整大小以匹配实际长度
    if (result.len < buffer.len) {
        return try allocator.realloc(buffer, result.len);
    }
    return buffer;
}

/// 解码到新分配的缓冲区
pub fn decodeAlloc(allocator: std.mem.Allocator, str: []const u8) ![]u8 {
    const buffer = try allocator.alloc(u8, str.len);
    errdefer allocator.free(buffer);
    
    const result = try decode(str, buffer);
    // 调整大小以匹配实际长度
    if (result.len < buffer.len) {
        return try allocator.realloc(buffer, result.len);
    }
    return buffer;
}

// 测试
test "base58 encode empty" {
    const testing = std.testing;
    var out: [10]u8 = undefined;
    const result = try encode(&[_]u8{}, &out);
    try testing.expectEqualSlices(u8, "", result);
}

test "base58 encode single zero" {
    const testing = std.testing;
    var out: [10]u8 = undefined;
    const result = try encode(&[_]u8{0}, &out);
    try testing.expectEqualSlices(u8, "1", result);
}

test "base58 encode multiple zeros" {
    const testing = std.testing;
    var out: [10]u8 = undefined;
    const result = try encode(&[_]u8{ 0, 0, 0 }, &out);
    try testing.expectEqualSlices(u8, "111", result);
}

test "base58 round trip" {
    const testing = std.testing;
    const data = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    
    var encoded: [64]u8 = undefined;
    const enc_result = try encode(&data, &encoded);
    
    var decoded: [64]u8 = undefined;
    const dec_result = try decode(enc_result, &decoded);
    
    try testing.expectEqualSlices(u8, &data, dec_result);
}

test "base58 known vectors" {
    const testing = std.testing;
    
    // 测试向量
    const TestCase = struct {
        hex: []const u8,
        base58: []const u8,
    };
    
    const cases = [_]TestCase{
        .{ .hex = "", .base58 = "" },
        .{ .hex = "00", .base58 = "1" },
        .{ .hex = "0000", .base58 = "11" },
        .{ .hex = "01", .base58 = "2" },
        .{ .hex = "0102", .base58 = "5Q" },
    };
    
    for (cases) |case| {
        var data: [32]u8 = undefined;
        const data_len = case.hex.len / 2;
        
        // 解析十六进制
        var i: usize = 0;
        while (i < data_len) : (i += 1) {
            const byte_str = case.hex[i * 2 .. i * 2 + 2];
            data[i] = try std.fmt.parseInt(u8, byte_str, 16);
        }
        
        var encoded: [64]u8 = undefined;
        const result = try encode(data[0..data_len], &encoded);
        try testing.expectEqualSlices(u8, case.base58, result);
    }
}