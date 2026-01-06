const std = @import("std");
const sdk = @import("solana_sdk");
const PublicKey = sdk.public_key.PublicKey;
const Hash = sdk.hash.Hash;
const Signature = sdk.signature.Signature;
const Keypair = sdk.keypair.Keypair;
const EpochInfo = sdk.epoch_info.EpochInfo;
const ShortU16 = sdk.short_vec.ShortU16;
const short_vec = sdk.short_vec;
const signature_mod = sdk.signature;
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

const SignatureTestVector = struct {
    name: []const u8,
    bytes: [64]u8,
    base58: []const u8,
};

const PdaTestVector = struct {
    program_id: [32]u8,
    seeds: []const []const u8,
    expected_pubkey: [32]u8,
    expected_bump: u8,
};

const KeypairTestVector = struct {
    name: []const u8,
    seed: []const u8,
    keypair_bytes: []const u8,
    pubkey: []const u8,
    message: []const u8,
    signature: []const u8,
};

const EpochInfoTestVector = struct {
    name: []const u8,
    epoch: u64,
    slot_index: u64,
    slots_in_epoch: u64,
    absolute_slot: u64,
    block_height: u64,
    transaction_count: ?u64,
};

const ShortVecTestVector = struct {
    name: []const u8,
    value: u16,
    encoded: []const u8,
};

const Sha256TestVector = struct {
    name: []const u8,
    input: []const u8,
    hash: []const u8,
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

test "signature: base58 encoding compatibility with Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "signature_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const SignatureTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        const sig = Signature{ .bytes = vector.bytes };
        var base58_buffer: [signature_mod.MAX_BASE58_LEN]u8 = undefined;
        const encoded = sig.toBase58(&base58_buffer);

        try std.testing.expectEqualStrings(vector.base58, encoded);
    }
}

test "signature: base58 decoding compatibility with Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "signature_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const SignatureTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        const decoded = try Signature.fromBase58(vector.base58);
        try std.testing.expectEqualSlices(u8, &vector.bytes, &decoded.bytes);
    }
}

test "pda: derivation compatibility with Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "pda_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const PdaTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        const program_id = PublicKey.from(vector.program_id);
        const pda = try PublicKey.findProgramAddressSlice(vector.seeds, program_id);

        try std.testing.expectEqualSlices(u8, &vector.expected_pubkey, &pda.address.bytes);
        try std.testing.expectEqual(vector.expected_bump, pda.bump_seed[0]);
    }
}

test "keypair: seed to pubkey compatibility with Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "keypair_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const KeypairTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        if (vector.seed.len != 32) continue;

        var seed: [32]u8 = undefined;
        @memcpy(&seed, vector.seed);

        const keypair = try Keypair.fromSeed(seed);
        const pubkey = keypair.pubkey();

        try std.testing.expectEqualSlices(u8, vector.pubkey, &pubkey.bytes);
    }
}

test "keypair: signing compatibility with Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "keypair_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const KeypairTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        if (vector.seed.len != 32) continue;

        var seed: [32]u8 = undefined;
        @memcpy(&seed, vector.seed);

        const keypair = try Keypair.fromSeed(seed);
        const signature = keypair.sign(vector.message);

        try std.testing.expectEqualSlices(u8, vector.signature, &signature.bytes);
    }
}

test "epoch_info: field values compatibility with Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "epoch_info_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const EpochInfoTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        const epoch_info = EpochInfo.init(
            vector.epoch,
            vector.slot_index,
            vector.slots_in_epoch,
            vector.absolute_slot,
            vector.block_height,
            vector.transaction_count,
        );

        try std.testing.expectEqual(vector.epoch, epoch_info.epoch);
        try std.testing.expectEqual(vector.slot_index, epoch_info.slot_index);
        try std.testing.expectEqual(vector.slots_in_epoch, epoch_info.slots_in_epoch);
        try std.testing.expectEqual(vector.absolute_slot, epoch_info.absolute_slot);
        try std.testing.expectEqual(vector.block_height, epoch_info.block_height);
        try std.testing.expectEqual(vector.transaction_count, epoch_info.transaction_count);

        const expected_first = vector.absolute_slot - vector.slot_index;
        try std.testing.expectEqual(expected_first, epoch_info.getFirstSlotInEpoch());
    }
}

test "short_vec: encoding compatibility with Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "short_vec_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const ShortVecTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        var buffer: [short_vec.MAX_ENCODING_LENGTH]u8 = undefined;
        const len = short_vec.encodeU16(vector.value, &buffer);

        try std.testing.expectEqualSlices(u8, vector.encoded, buffer[0..len]);
    }
}

test "short_vec: decoding compatibility with Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "short_vec_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const ShortVecTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        const result = try short_vec.decodeU16Len(vector.encoded);
        try std.testing.expectEqual(vector.value, @as(u16, @intCast(result.value)));
        try std.testing.expectEqual(vector.encoded.len, result.bytes_read);
    }
}

test "sha256: hash computation compatibility with Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "sha256_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const Sha256TestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        var hash_bytes: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(vector.input, &hash_bytes, .{});

        try std.testing.expectEqualSlices(u8, vector.hash, &hash_bytes);
    }
}
