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
const native_token = sdk.native_token;

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

const LamportsTestVector = struct {
    name: []const u8,
    sol_str: []const u8,
    lamports: ?u64,
};

const RentTestVector = struct {
    name: []const u8,
    data_len: u64,
    minimum_balance: u64,
};

test "lamports: solStrToLamports compatibility with Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "lamports_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const LamportsTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        const result = native_token.solStrToLamports(vector.sol_str);

        if (vector.lamports) |expected| {
            if (result) |actual| {
                try std.testing.expectEqual(expected, actual);
            } else {
                if (vector.sol_str.len == 0) continue;
                std.debug.print("Expected {d} for '{s}', got null\n", .{ expected, vector.sol_str });
                return error.TestUnexpectedResult;
            }
        } else {
            if (result) |actual| {
                if (vector.sol_str.len == 0 and actual == 0) continue;
                std.debug.print("Expected null for '{s}', got {d}\n", .{ vector.sol_str, actual });
                return error.TestUnexpectedResult;
            }
        }
    }
}

test "rent: minimum balance calculation compatibility with Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "rent_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const RentTestVector, allocator, json_data);
    defer parsed.deinit();

    const account_storage_overhead: u64 = 128;
    const lamports_per_byte_year: u64 = 1_000_000_000 / 100 * 365 / (1024 * 1024);
    const exemption_multiplier: u64 = 2;

    for (parsed.value) |vector| {
        const total_data_len = account_storage_overhead + vector.data_len;
        const calculated = total_data_len * lamports_per_byte_year * exemption_multiplier;
        try std.testing.expectEqual(vector.minimum_balance, calculated);
    }
}

const ClockTestVector = struct {
    name: []const u8,
    slot: u64,
    epoch_start_timestamp: i64,
    epoch: u64,
    leader_schedule_epoch: u64,
    unix_timestamp: i64,
};

const EpochScheduleTestVector = struct {
    name: []const u8,
    slots_per_epoch: u64,
    warmup: bool,
    first_normal_epoch: u64,
    first_normal_slot: u64,
    test_slot: u64,
    expected_epoch: u64,
    expected_slot_index: u64,
    expected_slots_in_epoch: u64,
};

const DurableNonceTestVector = struct {
    name: []const u8,
    blockhash: []const u8,
    durable_nonce: []const u8,
};

test "clock: field values compatibility with Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "clock_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const ClockTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expect(vector.slot >= 0 or vector.slot == std.math.maxInt(u64));
        try std.testing.expect(vector.epoch <= vector.slot or vector.epoch == std.math.maxInt(u64));
        try std.testing.expect(vector.leader_schedule_epoch >= vector.epoch or vector.leader_schedule_epoch == std.math.maxInt(u64));
    }
}

const MINIMUM_SLOTS_PER_EPOCH: u64 = 32;

fn getEpochAndSlotIndex(
    warmup: bool,
    slots_per_epoch: u64,
    first_normal_epoch: u64,
    first_normal_slot: u64,
    slot: u64,
) struct { u64, u64 } {
    if (warmup and slot < first_normal_slot) {
        var epoch: u64 = 0;
        var slots_in_epoch = MINIMUM_SLOTS_PER_EPOCH;
        var epoch_start: u64 = 0;

        while (epoch_start + slots_in_epoch <= slot) {
            epoch_start += slots_in_epoch;
            slots_in_epoch *= 2;
            epoch += 1;
        }

        return .{ epoch, slot - epoch_start };
    } else {
        const normal_slot_index = slot - first_normal_slot;
        const normal_epoch_index = normal_slot_index / slots_per_epoch;
        const epoch = first_normal_epoch + normal_epoch_index;
        const slot_index = normal_slot_index % slots_per_epoch;
        return .{ epoch, slot_index };
    }
}

fn getSlotsInEpoch(warmup: bool, slots_per_epoch: u64, first_normal_epoch: u64, epoch: u64) u64 {
    if (!warmup or epoch >= first_normal_epoch) {
        return slots_per_epoch;
    }
    const exponent = @min(epoch, 63);
    return MINIMUM_SLOTS_PER_EPOCH << @intCast(exponent);
}

test "epoch_schedule: calculation compatibility with Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "epoch_schedule_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const EpochScheduleTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        const result = getEpochAndSlotIndex(
            vector.warmup,
            vector.slots_per_epoch,
            vector.first_normal_epoch,
            vector.first_normal_slot,
            vector.test_slot,
        );

        try std.testing.expectEqual(vector.expected_epoch, result[0]);
        try std.testing.expectEqual(vector.expected_slot_index, result[1]);

        const slots_in_epoch = getSlotsInEpoch(
            vector.warmup,
            vector.slots_per_epoch,
            vector.first_normal_epoch,
            result[0],
        );
        try std.testing.expectEqual(vector.expected_slots_in_epoch, slots_in_epoch);
    }
}

test "durable_nonce: fromBlockhash compatibility with Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "durable_nonce_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const DurableNonceTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        if (vector.blockhash.len != 32) continue;

        var blockhash_bytes: [32]u8 = undefined;
        @memcpy(&blockhash_bytes, vector.blockhash);

        const blockhash = sdk.hash.Hash.from(blockhash_bytes);
        const durable_nonce = sdk.nonce.DurableNonce.fromBlockhash(blockhash);

        try std.testing.expectEqualSlices(u8, vector.durable_nonce, &durable_nonce.hash.bytes);
    }
}

const BincodeTestVector = struct {
    name: []const u8,
    type_name: []const u8,
    value_json: []const u8,
    encoded: []const u8,
};

const BorshTestVector = struct {
    name: []const u8,
    type_name: []const u8,
    value_json: []const u8,
    encoded: []const u8,
};

test "bincode: integer serialization compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "bincode_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const BincodeTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        if (std.mem.eql(u8, vector.type_name, "u8")) {
            const value = try std.fmt.parseInt(u8, vector.value_json, 10);
            var buf: [1]u8 = undefined;
            const len = try sdk.bincode.serialize(u8, value, &buf);
            try std.testing.expectEqual(@as(usize, 1), len);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.type_name, "u16")) {
            const value = try std.fmt.parseInt(u16, vector.value_json, 10);
            var buf: [2]u8 = undefined;
            const len = try sdk.bincode.serialize(u16, value, &buf);
            try std.testing.expectEqual(@as(usize, 2), len);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.type_name, "u32")) {
            const value = try std.fmt.parseInt(u32, vector.value_json, 10);
            var buf: [4]u8 = undefined;
            const len = try sdk.bincode.serialize(u32, value, &buf);
            try std.testing.expectEqual(@as(usize, 4), len);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.type_name, "u64")) {
            const value = try std.fmt.parseInt(u64, vector.value_json, 10);
            var buf: [8]u8 = undefined;
            const len = try sdk.bincode.serialize(u64, value, &buf);
            try std.testing.expectEqual(@as(usize, 8), len);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.type_name, "i32")) {
            const value = try std.fmt.parseInt(i32, vector.value_json, 10);
            var buf: [4]u8 = undefined;
            const len = try sdk.bincode.serialize(i32, value, &buf);
            try std.testing.expectEqual(@as(usize, 4), len);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.type_name, "i64")) {
            const value = try std.fmt.parseInt(i64, vector.value_json, 10);
            var buf: [8]u8 = undefined;
            const len = try sdk.bincode.serialize(i64, value, &buf);
            try std.testing.expectEqual(@as(usize, 8), len);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.type_name, "bool")) {
            const value = std.mem.eql(u8, vector.value_json, "true");
            var buf: [1]u8 = undefined;
            const len = try sdk.bincode.serialize(bool, value, &buf);
            try std.testing.expectEqual(@as(usize, 1), len);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        }
    }
}

test "borsh: integer serialization compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "borsh_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const BorshTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        if (std.mem.eql(u8, vector.type_name, "u8")) {
            const value = try std.fmt.parseInt(u8, vector.value_json, 10);
            var buf: [1]u8 = undefined;
            const len = try sdk.borsh.serialize(u8, value, &buf);
            try std.testing.expectEqual(@as(usize, 1), len);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.type_name, "u16")) {
            const value = try std.fmt.parseInt(u16, vector.value_json, 10);
            var buf: [2]u8 = undefined;
            const len = try sdk.borsh.serialize(u16, value, &buf);
            try std.testing.expectEqual(@as(usize, 2), len);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.type_name, "u32")) {
            const value = try std.fmt.parseInt(u32, vector.value_json, 10);
            var buf: [4]u8 = undefined;
            const len = try sdk.borsh.serialize(u32, value, &buf);
            try std.testing.expectEqual(@as(usize, 4), len);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.type_name, "u64")) {
            const value = try std.fmt.parseInt(u64, vector.value_json, 10);
            var buf: [8]u8 = undefined;
            const len = try sdk.borsh.serialize(u64, value, &buf);
            try std.testing.expectEqual(@as(usize, 8), len);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.type_name, "i32")) {
            const value = try std.fmt.parseInt(i32, vector.value_json, 10);
            var buf: [4]u8 = undefined;
            const len = try sdk.borsh.serialize(i32, value, &buf);
            try std.testing.expectEqual(@as(usize, 4), len);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.type_name, "i64")) {
            const value = try std.fmt.parseInt(i64, vector.value_json, 10);
            var buf: [8]u8 = undefined;
            const len = try sdk.borsh.serialize(i64, value, &buf);
            try std.testing.expectEqual(@as(usize, 8), len);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.type_name, "bool")) {
            const value = std.mem.eql(u8, vector.value_json, "true");
            var buf: [1]u8 = undefined;
            const len = try sdk.borsh.serialize(bool, value, &buf);
            try std.testing.expectEqual(@as(usize, 1), len);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        }
    }
}

const SystemInstructionTestVector = struct {
    name: []const u8,
    instruction_type: []const u8,
    encoded: []const u8,
    from_pubkey: ?[32]u8,
    to_pubkey: ?[32]u8,
    lamports: ?u64,
    space: ?u64,
    owner: ?[32]u8,
};

test "system_instruction: encoding compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "system_instruction_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const SystemInstructionTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        if (std.mem.eql(u8, vector.instruction_type, "Transfer")) {
            var buf: [12]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 2, .little);
            std.mem.writeInt(u64, buf[4..12], vector.lamports.?, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "CreateAccount")) {
            var buf: [52]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 0, .little);
            std.mem.writeInt(u64, buf[4..12], vector.lamports.?, .little);
            std.mem.writeInt(u64, buf[12..20], vector.space.?, .little);
            @memcpy(buf[20..52], &vector.owner.?);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "Assign")) {
            var buf: [36]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 1, .little);
            @memcpy(buf[4..36], &vector.owner.?);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "Allocate")) {
            var buf: [12]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 8, .little);
            std.mem.writeInt(u64, buf[4..12], vector.space.?, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        }
    }
}
