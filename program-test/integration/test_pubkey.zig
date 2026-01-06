const std = @import("std");
const sdk = @import("solana_sdk");
const PublicKey = sdk.public_key.PublicKey;
const Hash = sdk.hash.Hash;
const hash_mod = sdk.hash;

const PubkeyTestVector = struct {
    name: []const u8,
    bytes: [32]u8,
    base58: []const u8,
};

const HashTestVector = struct {
    name: []const u8,
    bytes: [32]u8,
    hex: []const u8,
};

fn readTestVectorFile(allocator: std.mem.Allocator, filename: []const u8) ![]const u8 {
    const path = try std.fs.path.join(allocator, &.{ "..", "test-vectors", filename });
    defer allocator.free(path);

    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    return file.readToEndAlloc(allocator, 1024 * 1024);
}

fn parseJson(comptime T: type, allocator: std.mem.Allocator, json_data: []const u8) !std.json.Parsed(T) {
    return std.json.parseFromSlice(T, allocator, json_data, .{
        .allocate = .alloc_always,
    });
}

test "pubkey: base58 encoding compatibility with Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "pubkey_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const PubkeyTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        const pubkey = PublicKey.from(vector.bytes);
        var base58_buffer: [PublicKey.max_base58_len]u8 = undefined;
        const encoded = pubkey.toBase58(&base58_buffer);

        try std.testing.expectEqualStrings(vector.base58, encoded);
    }
}

test "pubkey: base58 decoding compatibility with Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "pubkey_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const PubkeyTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        const decoded = try PublicKey.fromBase58(vector.base58);
        try std.testing.expectEqualSlices(u8, &vector.bytes, &decoded.bytes);
    }
}

test "hash: base58 encoding compatibility with Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "hash_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const HashTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        const hash = Hash{ .bytes = vector.bytes };
        var base58_buffer: [hash_mod.MAX_BASE58_LEN]u8 = undefined;
        const encoded = hash.toBase58(&base58_buffer);

        try std.testing.expectEqualStrings(vector.hex, encoded);
    }
}
