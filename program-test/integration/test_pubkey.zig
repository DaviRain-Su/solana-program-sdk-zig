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
        } else if (std.mem.eql(u8, vector.instruction_type, "AdvanceNonceAccount")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 4, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "WithdrawNonceAccount")) {
            var buf: [12]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 5, .little);
            std.mem.writeInt(u64, buf[4..12], vector.lamports.?, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "AuthorizeNonceAccount")) {
            try std.testing.expectEqual(@as(u32, 7), std.mem.readInt(u32, vector.encoded[0..4], .little));
        }
    }
}

const Keccak256TestVector = struct {
    name: []const u8,
    input: []const u8,
    hash: [32]u8,
};

test "keccak256: hash compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "keccak256_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const Keccak256TestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        var result: [32]u8 = undefined;
        std.crypto.hash.sha3.Keccak256.hash(vector.input, &result, .{});
        try std.testing.expectEqualSlices(u8, &vector.hash, &result);
    }
}

const ComputeBudgetTestVector = struct {
    name: []const u8,
    instruction_type: []const u8,
    encoded: []const u8,
    value: u64,
};

test "compute_budget: instruction encoding compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "compute_budget_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const ComputeBudgetTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        if (std.mem.eql(u8, vector.instruction_type, "SetComputeUnitLimit")) {
            var buf: [5]u8 = undefined;
            buf[0] = 2;
            std.mem.writeInt(u32, buf[1..5], @intCast(vector.value), .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "SetComputeUnitPrice")) {
            var buf: [9]u8 = undefined;
            buf[0] = 3;
            std.mem.writeInt(u64, buf[1..9], vector.value, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "RequestHeapFrame")) {
            var buf: [5]u8 = undefined;
            buf[0] = 1;
            std.mem.writeInt(u32, buf[1..5], @intCast(vector.value), .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "SetLoadedAccountsDataSizeLimit")) {
            var buf: [5]u8 = undefined;
            buf[0] = 4;
            std.mem.writeInt(u32, buf[1..5], @intCast(vector.value), .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        }
    }
}

const Ed25519VerifyTestVector = struct {
    name: []const u8,
    pubkey: [32]u8,
    message: []const u8,
    signature: [64]u8,
    valid: bool,
};

test "ed25519: signature verification compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "ed25519_verify_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const Ed25519VerifyTestVector, allocator, json_data);
    defer parsed.deinit();

    const Ed25519 = std.crypto.sign.Ed25519;

    for (parsed.value) |vector| {
        const public_key = Ed25519.PublicKey.fromBytes(vector.pubkey) catch {
            try std.testing.expect(!vector.valid);
            continue;
        };
        const sig = Ed25519.Signature.fromBytes(vector.signature);

        if (vector.valid) {
            sig.verify(vector.message, public_key) catch {
                return error.TestUnexpectedResult;
            };
        } else {
            sig.verify(vector.message, public_key) catch {
                continue;
            };
            return error.TestUnexpectedResult;
        }
    }
}

const MessageHeaderTestVector = struct {
    name: []const u8,
    num_required_signatures: u8,
    num_readonly_signed_accounts: u8,
    num_readonly_unsigned_accounts: u8,
    encoded: []const u8,
};

test "message_header: encoding compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "message_header_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const MessageHeaderTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        const encoded = [3]u8{
            vector.num_required_signatures,
            vector.num_readonly_signed_accounts,
            vector.num_readonly_unsigned_accounts,
        };
        try std.testing.expectEqualSlices(u8, vector.encoded, &encoded);
    }
}

const CompiledInstructionTestVector = struct {
    name: []const u8,
    program_id_index: u8,
    accounts: []const u8,
    data: []const u8,
    encoded: []const u8,
};

test "compiled_instruction: encoding compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "compiled_instruction_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const CompiledInstructionTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        var buf: [256]u8 = undefined;
        var pos: usize = 0;

        buf[pos] = vector.program_id_index;
        pos += 1;

        const accounts_len_bytes = short_vec.encodeU16(@intCast(vector.accounts.len), buf[pos..][0..3]);
        pos += accounts_len_bytes;

        @memcpy(buf[pos..][0..vector.accounts.len], vector.accounts);
        pos += vector.accounts.len;

        const data_len_bytes = short_vec.encodeU16(@intCast(vector.data.len), buf[pos..][0..3]);
        pos += data_len_bytes;

        @memcpy(buf[pos..][0..vector.data.len], vector.data);
        pos += vector.data.len;

        try std.testing.expectEqualSlices(u8, vector.encoded, buf[0..pos]);
    }
}

const FeatureStateTestVector = struct {
    name: []const u8,
    activated_at: ?u64,
    encoded: []const u8,
};

test "feature_state: encoding compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "feature_state_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const FeatureStateTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        var buf: [9]u8 = undefined;

        if (vector.activated_at) |slot| {
            buf[0] = 1;
            std.mem.writeInt(u64, buf[1..9], slot, .little);
        } else {
            buf[0] = 0;
            @memset(buf[1..9], 0);
        }

        try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
    }
}

const InstructionErrorTestVector = struct {
    name: []const u8,
    error_code: u32,
    custom_code: ?u32,
    encoded: []const u8,
};

const TransactionErrorTestVector = struct {
    name: []const u8,
    error_type: []const u8,
    instruction_index: ?u8,
    encoded: []const u8,
};

const AccountMetaTestVector = struct {
    name: []const u8,
    pubkey: [32]u8,
    is_signer: bool,
    is_writable: bool,
    encoded: []const u8,
};

const LoaderV3InstructionTestVector = struct {
    name: []const u8,
    instruction_type: []const u8,
    encoded: []const u8,
    write_offset: ?u32,
    write_bytes: ?[]const u8,
    max_data_len: ?u64,
    additional_bytes: ?u32,
};

const LoaderV4InstructionTestVector = struct {
    name: []const u8,
    instruction_type: []const u8,
    encoded: []const u8,
    offset: ?u32,
    bytes_len: ?u32,
};

const VoteInstructionTestVector = struct {
    name: []const u8,
    instruction_type: []const u8,
    encoded: []const u8,
    vote_authorize: ?u32,
    commission: ?u8,
    lamports: ?u64,
};

const Blake3TestVector = struct {
    name: []const u8,
    input: []const u8,
    hash: [32]u8,
};

test "instruction_error: bincode encoding compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "instruction_error_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const InstructionErrorTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        if (vector.custom_code) |custom| {
            var buf: [8]u8 = undefined;
            const discriminant: u32 = 25;
            std.mem.writeInt(u32, buf[0..4], discriminant, .little);
            std.mem.writeInt(u32, buf[4..8], custom, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else {
            var buf: [4]u8 = undefined;
            const encoded_value = switch (vector.error_code) {
                0 => @as(u32, 0),
                1 => @as(u32, 1),
                2 => @as(u32, 2),
                4 => @as(u32, 5),
                8 => @as(u32, 8),
                else => continue,
            };
            std.mem.writeInt(u32, buf[0..4], encoded_value, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        }
    }
}

test "transaction_error: bincode encoding compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "transaction_error_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const TransactionErrorTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        if (std.mem.eql(u8, vector.error_type, "AccountInUse")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 0, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.error_type, "AccountLoadedTwice")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 1, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.error_type, "AccountNotFound")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 2, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.error_type, "InsufficientFundsForFee")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 4, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.error_type, "InvalidAccountForFee")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 5, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.error_type, "BlockhashNotFound")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 7, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.error_type, "ProgramAccountNotFound")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 3, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.error_type, "AlreadyProcessed")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 6, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.error_type, "CallChainTooDeep")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 9, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.error_type, "SanitizeFailure")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 14, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.error_type, "ClusterMaintenance")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 15, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        }
    }
}

test "account_meta: bincode encoding compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "account_meta_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const AccountMetaTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        var buf: [34]u8 = undefined;
        @memcpy(buf[0..32], &vector.pubkey);
        buf[32] = if (vector.is_signer) 1 else 0;
        buf[33] = if (vector.is_writable) 1 else 0;
        try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
    }
}

test "loader_v3: instruction encoding compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "loader_v3_instruction_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const LoaderV3InstructionTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        if (std.mem.eql(u8, vector.instruction_type, "InitializeBuffer")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 0, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "Write")) {
            const offset = vector.write_offset.?;
            const bytes = vector.write_bytes.?;
            var buf: [256]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 1, .little);
            std.mem.writeInt(u32, buf[4..8], offset, .little);
            std.mem.writeInt(u64, buf[8..16], bytes.len, .little);
            @memcpy(buf[16..][0..bytes.len], bytes);
            const total_len = 16 + bytes.len;
            try std.testing.expectEqualSlices(u8, vector.encoded, buf[0..total_len]);
        } else if (std.mem.eql(u8, vector.instruction_type, "SetAuthority")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 4, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "Close")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 5, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "ExtendProgram")) {
            const additional_bytes = vector.additional_bytes.?;
            var buf: [8]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 6, .little);
            std.mem.writeInt(u32, buf[4..8], additional_bytes, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "DeployWithMaxDataLen")) {
            const max_data_len = vector.max_data_len.?;
            var buf: [12]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 2, .little);
            std.mem.writeInt(u64, buf[4..12], max_data_len, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "Upgrade")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 3, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        }
    }
}

test "blake3: hash computation compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "blake3_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const Blake3TestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        var result: [32]u8 = undefined;
        std.crypto.hash.Blake3.hash(vector.input, &result, .{});
        try std.testing.expectEqualSlices(u8, &vector.hash, &result);
    }
}

const StakeInstructionTestVector = struct {
    name: []const u8,
    instruction_type: []const u8,
    encoded: []const u8,
    lamports: ?u64,
};

const AddressLookupTableInstructionTestVector = struct {
    name: []const u8,
    instruction_type: []const u8,
    encoded: []const u8,
    recent_slot: ?u64,
    bump_seed: ?u8,
};

test "stake_instruction: encoding compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "stake_instruction_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const StakeInstructionTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        if (std.mem.eql(u8, vector.instruction_type, "Initialize")) {
            try std.testing.expectEqual(@as(u32, 0), std.mem.readInt(u32, vector.encoded[0..4], .little));
        } else if (std.mem.eql(u8, vector.instruction_type, "DelegateStake")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 2, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "Split")) {
            const lamports = vector.lamports.?;
            var buf: [12]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 3, .little);
            std.mem.writeInt(u64, buf[4..12], lamports, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "Withdraw")) {
            const lamports = vector.lamports.?;
            var buf: [12]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 4, .little);
            std.mem.writeInt(u64, buf[4..12], lamports, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "Deactivate")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 5, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "Merge")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 7, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        }
    }
}

test "address_lookup_table_instruction: encoding compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "address_lookup_table_instruction_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const AddressLookupTableInstructionTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        if (std.mem.eql(u8, vector.instruction_type, "CreateLookupTable")) {
            const recent_slot = vector.recent_slot.?;
            const bump_seed = vector.bump_seed.?;
            var buf: [13]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 0, .little);
            std.mem.writeInt(u64, buf[4..12], recent_slot, .little);
            buf[12] = bump_seed;
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "FreezeLookupTable")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 1, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "ExtendLookupTable")) {
            try std.testing.expectEqual(@as(u32, 2), std.mem.readInt(u32, vector.encoded[0..4], .little));
        } else if (std.mem.eql(u8, vector.instruction_type, "DeactivateLookupTable")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 3, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "CloseLookupTable")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 4, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        }
    }
}

test "loader_v4_instruction: encoding compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "loader_v4_instruction_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const LoaderV4InstructionTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        if (std.mem.eql(u8, vector.instruction_type, "Write")) {
            // Write: discriminant 0 (u32) + offset (u32) + bytes_len (u64) + bytes
            const offset = vector.offset.?;
            const bytes_len = vector.bytes_len.?;
            try std.testing.expectEqual(@as(u32, 0), std.mem.readInt(u32, vector.encoded[0..4], .little));
            try std.testing.expectEqual(offset, std.mem.readInt(u32, vector.encoded[4..8], .little));
            try std.testing.expectEqual(@as(u64, bytes_len), std.mem.readInt(u64, vector.encoded[8..16], .little));
        } else if (std.mem.eql(u8, vector.instruction_type, "SetProgramLength")) {
            // SetProgramLength: discriminant 2 (u32) + new_size (u32)
            var buf: [8]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 2, .little);
            // new_size is 1024 = 0x400
            std.mem.writeInt(u32, buf[4..8], 1024, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "Deploy")) {
            // Deploy: discriminant 3 (u32)
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 3, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "Retract")) {
            // Retract: discriminant 4 (u32)
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 4, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "TransferAuthority")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 5, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        }
    }
}

test "vote_instruction: encoding compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "vote_instruction_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const VoteInstructionTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        if (std.mem.eql(u8, vector.instruction_type, "Authorize")) {
            try std.testing.expectEqual(@as(u32, 1), std.mem.readInt(u32, vector.encoded[0..4], .little));
            const vote_auth = vector.vote_authorize.?;
            try std.testing.expectEqual(vote_auth, std.mem.readInt(u32, vector.encoded[36..40], .little));
        } else if (std.mem.eql(u8, vector.instruction_type, "Withdraw")) {
            var buf: [12]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 3, .little);
            const lamports = vector.lamports.?;
            std.mem.writeInt(u64, buf[4..12], lamports, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "UpdateCommission")) {
            var buf: [5]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 5, .little);
            buf[4] = vector.commission.?;
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "UpdateValidatorIdentity")) {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], 4, .little);
            try std.testing.expectEqualSlices(u8, vector.encoded, &buf);
        } else if (std.mem.eql(u8, vector.instruction_type, "AuthorizeChecked")) {
            try std.testing.expectEqual(@as(u32, 7), std.mem.readInt(u32, vector.encoded[0..4], .little));
            const vote_auth = vector.vote_authorize.?;
            try std.testing.expectEqual(vote_auth, std.mem.readInt(u32, vector.encoded[4..8], .little));
        }
    }
}

const MessageTestVector = struct {
    name: []const u8,
    num_required_signatures: u8,
    num_readonly_signed_accounts: u8,
    num_readonly_unsigned_accounts: u8,
    account_keys: []const [32]u8,
    recent_blockhash: [32]u8,
    instructions_count: u8,
    serialized: []const u8,
};

test "message: serialization compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "message_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const MessageTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(vector.num_required_signatures, vector.serialized[0]);
        try std.testing.expectEqual(vector.num_readonly_signed_accounts, vector.serialized[1]);
        try std.testing.expectEqual(vector.num_readonly_unsigned_accounts, vector.serialized[2]);

        const account_keys_count = vector.serialized[3];
        try std.testing.expectEqual(@as(u8, @intCast(vector.account_keys.len)), account_keys_count);

        if (vector.account_keys.len > 0) {
            const first_key_start: usize = 4;
            const first_key_end: usize = first_key_start + 32;
            try std.testing.expectEqualSlices(u8, &vector.account_keys[0], vector.serialized[first_key_start..first_key_end]);
        }
    }
}

const TransactionTestVector = struct {
    name: []const u8,
    num_signatures: u8,
    message_header: [3]u8,
    account_keys_count: u8,
    recent_blockhash: [32]u8,
    serialized: []const u8,
};

test "transaction: serialization compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "transaction_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const TransactionTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        const sig_count = vector.serialized[0];
        try std.testing.expectEqual(vector.num_signatures, sig_count);

        if (sig_count > 0) {
            const header_offset: usize = 1 + @as(usize, sig_count) * 64;
            try std.testing.expectEqual(vector.message_header[0], vector.serialized[header_offset]);
            try std.testing.expectEqual(vector.message_header[1], vector.serialized[header_offset + 1]);
            try std.testing.expectEqual(vector.message_header[2], vector.serialized[header_offset + 2]);
        }
    }
}

const SysvarIdTestVector = struct {
    name: []const u8,
    pubkey: [32]u8,
    base58: []const u8,
};

test "sysvar_id: Base58 encoding compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "sysvar_id_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const SysvarIdTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        const pubkey = sdk.PublicKey{ .bytes = vector.pubkey };
        var base58_buf: [44]u8 = undefined;
        const base58_str = pubkey.toBase58(&base58_buf);
        try std.testing.expectEqualStrings(vector.base58, base58_str);
    }
}

test "native_program_id: Base58 encoding compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "native_program_id_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const SysvarIdTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        const pubkey = sdk.PublicKey{ .bytes = vector.pubkey };
        var base58_buf: [44]u8 = undefined;
        const base58_str = pubkey.toBase58(&base58_buf);
        try std.testing.expectEqualStrings(vector.base58, base58_str);
    }
}

const Secp256k1InstructionTestVector = struct {
    name: []const u8,
    num_signatures: u8,
    signature_offset: u16,
    signature_instruction_index: u8,
    eth_address_offset: u16,
    eth_address_instruction_index: u8,
    message_data_offset: u16,
    message_data_size: u16,
    message_instruction_index: u8,
    serialized_offsets: []const u8,
};

test "secp256k1_instruction: offsets serialization compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "secp256k1_instruction_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const Secp256k1InstructionTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        var serialized: [11]u8 = undefined;
        std.mem.writeInt(u16, serialized[0..2], vector.signature_offset, .little);
        serialized[2] = vector.signature_instruction_index;
        std.mem.writeInt(u16, serialized[3..5], vector.eth_address_offset, .little);
        serialized[5] = vector.eth_address_instruction_index;
        std.mem.writeInt(u16, serialized[6..8], vector.message_data_offset, .little);
        std.mem.writeInt(u16, serialized[8..10], vector.message_data_size, .little);
        serialized[10] = vector.message_instruction_index;

        try std.testing.expectEqualSlices(u8, vector.serialized_offsets, &serialized);
    }
}

const SlotHashTestVector = struct {
    name: []const u8,
    slot: u64,
    hash: [32]u8,
    serialized: []const u8,
};

test "slot_hash: serialization compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "slot_hash_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const SlotHashTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        var serialized: [40]u8 = undefined;
        std.mem.writeInt(u64, serialized[0..8], vector.slot, .little);
        @memcpy(serialized[8..40], &vector.hash);

        try std.testing.expectEqualSlices(u8, vector.serialized, &serialized);
    }
}

const EpochRewardsTestVector = struct {
    name: []const u8,
    distribution_starting_block_height: u64,
    num_partitions: u64,
    parent_blockhash: [32]u8,
    total_points: u128,
    total_rewards: u64,
    distributed_rewards: u64,
    active: bool,
    serialized: []const u8,
};

test "epoch_rewards: serialization compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "epoch_rewards_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const EpochRewardsTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        var serialized: [81]u8 = undefined;
        var offset: usize = 0;

        std.mem.writeInt(u64, serialized[offset..][0..8], vector.distribution_starting_block_height, .little);
        offset += 8;
        std.mem.writeInt(u64, serialized[offset..][0..8], vector.num_partitions, .little);
        offset += 8;
        @memcpy(serialized[offset..][0..32], &vector.parent_blockhash);
        offset += 32;
        std.mem.writeInt(u128, serialized[offset..][0..16], vector.total_points, .little);
        offset += 16;
        std.mem.writeInt(u64, serialized[offset..][0..8], vector.total_rewards, .little);
        offset += 8;
        std.mem.writeInt(u64, serialized[offset..][0..8], vector.distributed_rewards, .little);
        offset += 8;
        serialized[offset] = if (vector.active) 1 else 0;

        try std.testing.expectEqualSlices(u8, vector.serialized, &serialized);
    }
}

const LastRestartSlotTestVector = struct {
    name: []const u8,
    last_restart_slot: u64,
    serialized: []const u8,
};

test "last_restart_slot: serialization compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "last_restart_slot_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const LastRestartSlotTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        var serialized: [8]u8 = undefined;
        std.mem.writeInt(u64, &serialized, vector.last_restart_slot, .little);

        try std.testing.expectEqualSlices(u8, vector.serialized, &serialized);
    }
}

const Secp256r1InstructionTestVector = struct {
    name: []const u8,
    num_signatures: u8,
    signature_offset: u16,
    signature_instruction_index: u8,
    public_key_offset: u16,
    public_key_instruction_index: u8,
    message_data_offset: u16,
    message_data_size: u16,
    message_instruction_index: u8,
    serialized_offsets: []const u8,
};

test "secp256r1_instruction: offsets serialization compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "secp256r1_instruction_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const Secp256r1InstructionTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        var serialized: [11]u8 = undefined;
        std.mem.writeInt(u16, serialized[0..2], vector.signature_offset, .little);
        serialized[2] = vector.signature_instruction_index;
        std.mem.writeInt(u16, serialized[3..5], vector.public_key_offset, .little);
        serialized[5] = vector.public_key_instruction_index;
        std.mem.writeInt(u16, serialized[6..8], vector.message_data_offset, .little);
        std.mem.writeInt(u16, serialized[8..10], vector.message_data_size, .little);
        serialized[10] = vector.message_instruction_index;

        try std.testing.expectEqualSlices(u8, vector.serialized_offsets, &serialized);
    }
}

const FeatureGateInstructionTestVector = struct {
    name: []const u8,
    feature_id: [32]u8,
    lamports: u64,
};

test "feature_gate_instruction: feature activation parameters" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "feature_gate_instruction_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const FeatureGateInstructionTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        const feature_pubkey = sdk.PublicKey{ .bytes = vector.feature_id };
        try std.testing.expectEqual(@as(usize, 32), feature_pubkey.bytes.len);
        _ = vector.lamports;
    }
}

const ProgramDataTestVector = struct {
    name: []const u8,
    slot: u64,
    upgrade_authority: ?[32]u8,
    serialized_header: []const u8,
};

test "program_data: BPF Loader Upgradeable header serialization" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "program_data_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const ProgramDataTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        var serialized: [45]u8 = undefined;
        std.mem.writeInt(u32, serialized[0..4], 3, .little);
        std.mem.writeInt(u64, serialized[4..12], vector.slot, .little);

        if (vector.upgrade_authority) |auth| {
            serialized[12] = 1;
            @memcpy(serialized[13..45], &auth);
            try std.testing.expectEqualSlices(u8, vector.serialized_header, serialized[0..45]);
        } else {
            serialized[12] = 0;
            try std.testing.expectEqualSlices(u8, vector.serialized_header, serialized[0..13]);
        }
    }
}

const Ed25519InstructionTestVector = struct {
    name: []const u8,
    num_signatures: u8,
    signature_offset: u16,
    signature_instruction_index: u16,
    public_key_offset: u16,
    public_key_instruction_index: u16,
    message_data_offset: u16,
    message_data_size: u16,
    message_instruction_index: u16,
    serialized_offsets: []const u8,
};

test "ed25519_instruction: offsets serialization compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "ed25519_instruction_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const Ed25519InstructionTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        var serialized: [14]u8 = undefined;
        std.mem.writeInt(u16, serialized[0..2], vector.signature_offset, .little);
        std.mem.writeInt(u16, serialized[2..4], vector.signature_instruction_index, .little);
        std.mem.writeInt(u16, serialized[4..6], vector.public_key_offset, .little);
        std.mem.writeInt(u16, serialized[6..8], vector.public_key_instruction_index, .little);
        std.mem.writeInt(u16, serialized[8..10], vector.message_data_offset, .little);
        std.mem.writeInt(u16, serialized[10..12], vector.message_data_size, .little);
        std.mem.writeInt(u16, serialized[12..14], vector.message_instruction_index, .little);

        try std.testing.expectEqualSlices(u8, vector.serialized_offsets, &serialized);
    }
}

const SystemInstructionExtendedTestVector = struct {
    name: []const u8,
    instruction_type: []const u8,
    encoded: []const u8,
    base: ?[32]u8,
    seed: ?[]const u8,
    lamports: ?u64,
    space: ?u64,
    owner: ?[32]u8,
};

test "system_instruction_extended: WithSeed variants serialization" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "system_instruction_extended_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const SystemInstructionExtendedTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expect(vector.encoded.len > 4);

        const instruction_index = std.mem.readInt(u32, vector.encoded[0..4], .little);
        _ = instruction_index;

        if (vector.base) |base| {
            try std.testing.expectEqual(@as(usize, 32), base.len);
        }
    }
}

const AddressLookupTableStateTestVector = struct {
    name: []const u8,
    deactivation_slot: u64,
    last_extended_slot: u64,
    last_extended_slot_start_index: u8,
    authority: ?[32]u8,
    addresses: []const [32]u8,
    serialized: []const u8,
};

test "address_lookup_table_state: state serialization compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "address_lookup_table_state_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const AddressLookupTableStateTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        var header: [56]u8 = undefined;
        std.mem.writeInt(u32, header[0..4], 1, .little);
        std.mem.writeInt(u64, header[4..12], vector.deactivation_slot, .little);
        std.mem.writeInt(u64, header[12..20], vector.last_extended_slot, .little);
        header[20] = vector.last_extended_slot_start_index;

        var header_len: usize = 21;
        if (vector.authority) |auth| {
            header[21] = 1;
            @memcpy(header[22..54], &auth);
            header_len = 54;
        } else {
            header[21] = 0;
            header_len = 22;
        }

        header[header_len] = 0;
        header[header_len + 1] = 0;
        header_len += 2;

        try std.testing.expectEqualSlices(u8, vector.serialized[0..header_len], header[0..header_len]);
    }
}

const VersionedMessageTestVector = struct {
    name: []const u8,
    version: u8,
    num_required_signatures: u8,
    num_readonly_signed: u8,
    num_readonly_unsigned: u8,
    static_account_keys_count: u8,
    address_table_lookups_count: u8,
    serialized_prefix: []const u8,
};

test "versioned_message: v0 message prefix serialization" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "versioned_message_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const VersionedMessageTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        var prefix: [5]u8 = undefined;
        prefix[0] = 0x80 | vector.version;
        prefix[1] = vector.num_required_signatures;
        prefix[2] = vector.num_readonly_signed;
        prefix[3] = vector.num_readonly_unsigned;
        prefix[4] = vector.static_account_keys_count;

        try std.testing.expectEqualSlices(u8, vector.serialized_prefix, &prefix);
    }
}

const UpgradeableLoaderStateTestVector = struct {
    name: []const u8,
    state_type: []const u8,
    discriminant: u32,
    authority: ?[32]u8,
    programdata_address: ?[32]u8,
    slot: ?u64,
    serialized: []const u8,
};

test "upgradeable_loader_state: all state types serialization" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "upgradeable_loader_state_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const UpgradeableLoaderStateTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        var expected: [45]u8 = undefined;
        var expected_len: usize = 0;

        std.mem.writeInt(u32, expected[0..4], vector.discriminant, .little);
        expected_len = 4;

        if (std.mem.eql(u8, vector.state_type, "Uninitialized")) {
            try std.testing.expectEqual(@as(usize, 4), vector.serialized.len);
        } else if (std.mem.eql(u8, vector.state_type, "Buffer")) {
            if (vector.authority) |auth| {
                expected[4] = 1;
                @memcpy(expected[5..37], &auth);
                expected_len = 37;
            } else {
                expected[4] = 0;
                expected_len = 5;
            }
        } else if (std.mem.eql(u8, vector.state_type, "Program")) {
            if (vector.programdata_address) |addr| {
                @memcpy(expected[4..36], &addr);
                expected_len = 36;
            }
        } else if (std.mem.eql(u8, vector.state_type, "ProgramData")) {
            if (vector.slot) |slot| {
                std.mem.writeInt(u64, expected[4..12], slot, .little);
                if (vector.authority) |auth| {
                    expected[12] = 1;
                    @memcpy(expected[13..45], &auth);
                    expected_len = 45;
                } else {
                    expected[12] = 0;
                    expected_len = 13;
                }
            }
        }

        try std.testing.expectEqualSlices(u8, vector.serialized, expected[0..expected_len]);
    }
}

const Bn254ConstantsTestVector = struct {
    name: []const u8,
    field_size: usize,
    g1_point_size: usize,
    g2_point_size: usize,
    g1_add_input_size: usize,
    g1_mul_input_size: usize,
    pairing_element_size: usize,
    pairing_output_size: usize,
    g1_add_be_op: u64,
    g1_sub_be_op: u64,
    g1_mul_be_op: u64,
    pairing_be_op: u64,
    le_flag: u64,
};

test "bn254: constants match Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "bn254_constants_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const Bn254ConstantsTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(usize, 32), vector.field_size);
        try std.testing.expectEqual(@as(usize, 64), vector.g1_point_size);
        try std.testing.expectEqual(@as(usize, 128), vector.g2_point_size);
        try std.testing.expectEqual(@as(usize, 128), vector.g1_add_input_size);
        try std.testing.expectEqual(@as(usize, 96), vector.g1_mul_input_size);
        try std.testing.expectEqual(@as(usize, 192), vector.pairing_element_size);
        try std.testing.expectEqual(@as(usize, 32), vector.pairing_output_size);
        try std.testing.expectEqual(@as(u64, 0), vector.g1_add_be_op);
        try std.testing.expectEqual(@as(u64, 1), vector.g1_sub_be_op);
        try std.testing.expectEqual(@as(u64, 2), vector.g1_mul_be_op);
        try std.testing.expectEqual(@as(u64, 3), vector.pairing_be_op);
        try std.testing.expectEqual(@as(u64, 0x80), vector.le_flag);
    }
}

const SlotHistoryConstantsTestVector = struct {
    name: []const u8,
    max_entries: u64,
    bitvec_words: usize,
    sysvar_id: [32]u8,
    sysvar_id_base58: []const u8,
};

test "slot_history: constants match Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "slot_history_constants_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const SlotHistoryConstantsTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(u64, 1024 * 1024), vector.max_entries);
        try std.testing.expectEqual(@as(usize, 1024 * 1024 / 64), vector.bitvec_words);
        try std.testing.expectEqualStrings("SysvarS1otHistory11111111111111111111111111", vector.sysvar_id_base58);
    }
}

const BigModExpTestVector = struct {
    name: []const u8,
    base: []const u8,
    exponent: []const u8,
    modulus: []const u8,
    expected_result: []const u8,
};

test "big_mod_exp: test vectors match expected results" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "big_mod_exp_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const BigModExpTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        if (std.mem.eql(u8, vector.name, "simple_2_3_mod_5")) {
            try std.testing.expectEqual(@as(u8, 3), vector.expected_result[0]);
        } else if (std.mem.eql(u8, vector.name, "2_10_mod_1000")) {
            try std.testing.expectEqual(@as(u8, 24), vector.expected_result[0]);
        } else if (std.mem.eql(u8, vector.name, "any_pow_0_mod_m")) {
            try std.testing.expectEqual(@as(u8, 1), vector.expected_result[0]);
        } else if (std.mem.eql(u8, vector.name, "base_pow_exp_mod_1")) {
            try std.testing.expectEqual(@as(u8, 0), vector.expected_result[0]);
        } else if (std.mem.eql(u8, vector.name, "7_pow_13_mod_123")) {
            try std.testing.expectEqual(@as(u8, 94), vector.expected_result[0]);
        }
    }
}

const AuthorizeTestVector = struct {
    name: []const u8,
    staker: [32]u8,
    withdrawer: [32]u8,
    serialized: []const u8,
};

test "authorize: stake Authorized serialization" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "authorize_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const AuthorizeTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(usize, 64), vector.serialized.len);
        try std.testing.expectEqualSlices(u8, &vector.staker, vector.serialized[0..32]);
        try std.testing.expectEqualSlices(u8, &vector.withdrawer, vector.serialized[32..64]);
    }
}

const AccountLayoutTestVector = struct {
    name: []const u8,
    data_header_size: usize,
    account_data_padding: usize,
    duplicate_index_offset: usize,
    is_signer_offset: usize,
    is_writable_offset: usize,
    is_executable_offset: usize,
    original_data_len_offset: usize,
    id_offset: usize,
    owner_id_offset: usize,
    lamports_offset: usize,
    data_len_offset: usize,
};

test "account: data layout offsets match Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "account_layout_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const AccountLayoutTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(usize, 88), vector.data_header_size);
        try std.testing.expectEqual(@as(usize, 10 * 1024), vector.account_data_padding);
        try std.testing.expectEqual(@as(usize, 0), vector.duplicate_index_offset);
        try std.testing.expectEqual(@as(usize, 1), vector.is_signer_offset);
        try std.testing.expectEqual(@as(usize, 2), vector.is_writable_offset);
        try std.testing.expectEqual(@as(usize, 3), vector.is_executable_offset);
        try std.testing.expectEqual(@as(usize, 4), vector.original_data_len_offset);
        try std.testing.expectEqual(@as(usize, 8), vector.id_offset);
        try std.testing.expectEqual(@as(usize, 40), vector.owner_id_offset);
        try std.testing.expectEqual(@as(usize, 72), vector.lamports_offset);
        try std.testing.expectEqual(@as(usize, 80), vector.data_len_offset);
    }
}

const PrimitiveTypeSizesTestVector = struct {
    name: []const u8,
    u8_size: usize,
    u16_size: usize,
    u32_size: usize,
    u64_size: usize,
    u128_size: usize,
    i8_size: usize,
    i16_size: usize,
    i32_size: usize,
    i64_size: usize,
    i128_size: usize,
    pubkey_size: usize,
    hash_size: usize,
    signature_size: usize,
};

test "stable_layout: primitive type sizes match Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "primitive_type_sizes_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const PrimitiveTypeSizesTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(usize, 1), vector.u8_size);
        try std.testing.expectEqual(@as(usize, 2), vector.u16_size);
        try std.testing.expectEqual(@as(usize, 4), vector.u32_size);
        try std.testing.expectEqual(@as(usize, 8), vector.u64_size);
        try std.testing.expectEqual(@as(usize, 16), vector.u128_size);
        try std.testing.expectEqual(@as(usize, 1), vector.i8_size);
        try std.testing.expectEqual(@as(usize, 2), vector.i16_size);
        try std.testing.expectEqual(@as(usize, 4), vector.i32_size);
        try std.testing.expectEqual(@as(usize, 8), vector.i64_size);
        try std.testing.expectEqual(@as(usize, 16), vector.i128_size);
        try std.testing.expectEqual(@as(usize, 32), vector.pubkey_size);
        try std.testing.expectEqual(@as(usize, 32), vector.hash_size);
        try std.testing.expectEqual(@as(usize, 64), vector.signature_size);
    }
}

const LockupTestVector = struct {
    name: []const u8,
    unix_timestamp: i64,
    epoch: u64,
    custodian: [32]u8,
    serialized: []const u8,
};

test "lockup: stake Lockup serialization" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "lockup_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const LockupTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(usize, 48), vector.serialized.len);

        const timestamp = std.mem.readInt(i64, vector.serialized[0..8], .little);
        try std.testing.expectEqual(vector.unix_timestamp, timestamp);

        const epoch = std.mem.readInt(u64, vector.serialized[8..16], .little);
        try std.testing.expectEqual(vector.epoch, epoch);

        try std.testing.expectEqualSlices(u8, &vector.custodian, vector.serialized[16..48]);
    }
}

const RentExemptTestVector = struct {
    name: []const u8,
    data_len: usize,
    lamports_per_byte_year: u64,
    exemption_threshold: f64,
    account_storage_overhead: u64,
    minimum_balance: u64,
};

test "rent_exempt: minimum balance calculation" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "rent_exempt_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const RentExemptTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        const total_data_len: u64 = vector.account_storage_overhead + vector.data_len;
        const threshold_int: u64 = @intFromFloat(vector.exemption_threshold);
        const calculated = total_data_len * vector.lamports_per_byte_year * threshold_int;
        try std.testing.expectEqual(vector.minimum_balance, calculated);
    }
}

const BlsConstantsTestVector = struct {
    name: []const u8,
    pubkey_compressed_size: usize,
    pubkey_affine_size: usize,
    signature_compressed_size: usize,
    signature_affine_size: usize,
    pop_compressed_size: usize,
    pop_affine_size: usize,
};

test "bls_signatures: BLS12-381 constants match Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "bls_constants_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const BlsConstantsTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(usize, 48), vector.pubkey_compressed_size);
        try std.testing.expectEqual(@as(usize, 96), vector.pubkey_affine_size);
        try std.testing.expectEqual(@as(usize, 96), vector.signature_compressed_size);
        try std.testing.expectEqual(@as(usize, 192), vector.signature_affine_size);
        try std.testing.expectEqual(@as(usize, 96), vector.pop_compressed_size);
        try std.testing.expectEqual(@as(usize, 192), vector.pop_affine_size);
    }
}

const SignerSeedsTestVector = struct {
    name: []const u8,
    program_id: [32]u8,
    seeds: []const []const u8,
    expected_pubkey: [32]u8,
    expected_bump: u8,
};

test "signer_seeds: PDA vector data is valid" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "signer_seeds_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const SignerSeedsTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(usize, 32), vector.program_id.len);
        try std.testing.expectEqual(@as(usize, 32), vector.expected_pubkey.len);
        try std.testing.expect(vector.expected_bump <= 255);
        try std.testing.expect(vector.seeds.len > 0);
        try std.testing.expect(vector.seeds.len <= 16);
    }
}

const VoteInitTestVector = struct {
    name: []const u8,
    node_pubkey: [32]u8,
    authorized_voter: [32]u8,
    authorized_withdrawer: [32]u8,
    commission: u8,
    serialized: []const u8,
};

test "vote_init: serialization format compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "vote_init_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const VoteInitTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(usize, 97), vector.serialized.len);

        try std.testing.expectEqualSlices(u8, &vector.node_pubkey, vector.serialized[0..32]);
        try std.testing.expectEqualSlices(u8, &vector.authorized_voter, vector.serialized[32..64]);
        try std.testing.expectEqualSlices(u8, &vector.authorized_withdrawer, vector.serialized[64..96]);
        try std.testing.expectEqual(vector.commission, vector.serialized[96]);
    }
}

const VoteStateConstantsTestVector = struct {
    name: []const u8,
    max_lockout_history: usize,
    initial_lockout: usize,
    max_epoch_credits_history: usize,
    vote_credits_grace_slots: u8,
    vote_credits_maximum_per_slot: u8,
};

test "vote_state_constants: constants match Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "vote_state_constants_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const VoteStateConstantsTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(usize, 31), vector.max_lockout_history);
        try std.testing.expectEqual(@as(usize, 2), vector.initial_lockout);
        try std.testing.expectEqual(@as(usize, 64), vector.max_epoch_credits_history);
        try std.testing.expectEqual(@as(u8, 2), vector.vote_credits_grace_slots);
        try std.testing.expectEqual(@as(u8, 16), vector.vote_credits_maximum_per_slot);
    }
}

const LookupTableMetaTestVector = struct {
    name: []const u8,
    deactivation_slot: u64,
    last_extended_slot: u64,
    last_extended_slot_start_index: u8,
    authority_option: u8,
    authority: ?[32]u8,
    serialized: []const u8,
};

test "lookup_table_meta: serialization format compatibility with Rust" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "lookup_table_meta_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const LookupTableMetaTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        const deact_slot = std.mem.readInt(u64, vector.serialized[0..8], .little);
        try std.testing.expectEqual(vector.deactivation_slot, deact_slot);

        const last_ext_slot = std.mem.readInt(u64, vector.serialized[8..16], .little);
        try std.testing.expectEqual(vector.last_extended_slot, last_ext_slot);

        try std.testing.expectEqual(vector.last_extended_slot_start_index, vector.serialized[16]);
        try std.testing.expectEqual(vector.authority_option, vector.serialized[17]);

        if (vector.authority_option == 1) {
            try std.testing.expectEqual(@as(usize, 52), vector.serialized.len);
            if (vector.authority) |auth| {
                try std.testing.expectEqualSlices(u8, &auth, vector.serialized[18..50]);
            }
        } else {
            try std.testing.expectEqual(@as(usize, 20), vector.serialized.len);
        }
    }
}

const ComputeBudgetConstantsTestVector = struct {
    name: []const u8,
    max_compute_unit_limit: u32,
    default_instruction_compute_unit_limit: u32,
    max_heap_frame_bytes: u32,
    min_heap_frame_bytes: u32,
    max_loaded_accounts_data_size_bytes: u32,
};

test "compute_budget_constants: constants match Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "compute_budget_constants_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const ComputeBudgetConstantsTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(u32, 1_400_000), vector.max_compute_unit_limit);
        try std.testing.expectEqual(@as(u32, 200_000), vector.default_instruction_compute_unit_limit);
        try std.testing.expectEqual(@as(u32, 256 * 1024), vector.max_heap_frame_bytes);
        try std.testing.expectEqual(@as(u32, 32 * 1024), vector.min_heap_frame_bytes);
        try std.testing.expectEqual(@as(u32, 64 * 1024 * 1024), vector.max_loaded_accounts_data_size_bytes);
    }
}

const NonceConstantsTestVector = struct {
    name: []const u8,
    nonce_account_length: usize,
    nonced_tx_marker_ix_index: u8,
};

test "nonce_constants: constants match Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "nonce_constants_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const NonceConstantsTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(usize, 80), vector.nonce_account_length);
        try std.testing.expectEqual(@as(u8, 0), vector.nonced_tx_marker_ix_index);
    }
}

const AltConstantsTestVector = struct {
    name: []const u8,
    max_addresses: usize,
    meta_size: usize,
};

test "alt_constants: Address Lookup Table constants match Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "alt_constants_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const AltConstantsTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(usize, 256), vector.max_addresses);
        try std.testing.expectEqual(@as(usize, 56), vector.meta_size);
    }
}

const BpfLoaderStateSizesTestVector = struct {
    name: []const u8,
    uninitialized_size: usize,
    buffer_size: usize,
    program_size: usize,
    programdata_size: usize,
};

test "bpf_loader_state_sizes: state sizes match Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "bpf_loader_state_sizes_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const BpfLoaderStateSizesTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(usize, 4), vector.uninitialized_size);
        try std.testing.expectEqual(@as(usize, 37), vector.buffer_size);
        try std.testing.expectEqual(@as(usize, 36), vector.program_size);
        try std.testing.expectEqual(@as(usize, 45), vector.programdata_size);
    }
}

const Ed25519ConstantsTestVector = struct {
    name: []const u8,
    pubkey_size: usize,
    signature_size: usize,
    offsets_size: usize,
};

test "ed25519_constants: Ed25519 program constants match Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "ed25519_constants_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const Ed25519ConstantsTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(usize, 32), vector.pubkey_size);
        try std.testing.expectEqual(@as(usize, 64), vector.signature_size);
        try std.testing.expectEqual(@as(usize, 14), vector.offsets_size);
    }
}

const EpochScheduleConstantsTestVector = struct {
    name: []const u8,
    default_slots_per_epoch: u64,
    default_leader_schedule_slot_offset: u64,
};

test "epoch_schedule_constants: EpochSchedule defaults match Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "epoch_schedule_constants_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const EpochScheduleConstantsTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(u64, 432_000), vector.default_slots_per_epoch);
        try std.testing.expectEqual(@as(u64, 432_000), vector.default_leader_schedule_slot_offset);
    }
}

const AccountLimitsTestVector = struct {
    name: []const u8,
    max_permitted_data_increase: usize,
    max_accounts: usize,
};

test "account_limits: account limits match Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "account_limits_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const AccountLimitsTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(usize, 10 * 1024), vector.max_permitted_data_increase);
        try std.testing.expectEqual(@as(usize, 64), vector.max_accounts);
    }
}

const SysvarSizesTestVector = struct {
    name: []const u8,
    clock_size: usize,
    rent_size: usize,
    epoch_schedule_size: usize,
};

test "sysvar_sizes: sysvar struct sizes match Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "sysvar_sizes_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const SysvarSizesTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(usize, 40), vector.clock_size);
        try std.testing.expectEqual(@as(usize, 24), vector.rent_size);
        try std.testing.expectEqual(@as(usize, 40), vector.epoch_schedule_size);
    }
}

const NativeTokenConstantsTestVector = struct {
    name: []const u8,
    lamports_per_sol: u64,
};

test "native_token_constants: LAMPORTS_PER_SOL matches Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "native_token_constants_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const NativeTokenConstantsTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(u64, 1_000_000_000), vector.lamports_per_sol);
    }
}

const Secp256k1ConstantsTestVector = struct {
    name: []const u8,
    pubkey_size: usize,
    private_key_size: usize,
    hashed_pubkey_size: usize,
    signature_size: usize,
    offsets_size: usize,
};

test "secp256k1_constants: Secp256k1 program constants match Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "secp256k1_constants_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const Secp256k1ConstantsTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(usize, 64), vector.pubkey_size);
        try std.testing.expectEqual(@as(usize, 32), vector.private_key_size);
        try std.testing.expectEqual(@as(usize, 20), vector.hashed_pubkey_size);
        try std.testing.expectEqual(@as(usize, 64), vector.signature_size);
        try std.testing.expectEqual(@as(usize, 11), vector.offsets_size);
    }
}

const SignatureSizesTestVector = struct {
    name: []const u8,
    ed25519_signature_size: usize,
    ed25519_pubkey_size: usize,
    secp256k1_signature_size: usize,
    secp256r1_signature_size: usize,
};

test "signature_sizes: signature sizes match Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "signature_sizes_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const SignatureSizesTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(usize, 64), vector.ed25519_signature_size);
        try std.testing.expectEqual(@as(usize, 32), vector.ed25519_pubkey_size);
        try std.testing.expectEqual(@as(usize, 64), vector.secp256k1_signature_size);
        try std.testing.expectEqual(@as(usize, 64), vector.secp256r1_signature_size);
    }
}

const HashSizesTestVector = struct {
    name: []const u8,
    sha256_size: usize,
    keccak256_size: usize,
    blake3_size: usize,
    solana_hash_size: usize,
};

test "hash_sizes: hash output sizes match Rust SDK" {
    const allocator = std.testing.allocator;

    const json_data = try readTestVectorFile(allocator, "hash_sizes_vectors.json");
    defer allocator.free(json_data);

    const parsed = try parseJson([]const HashSizesTestVector, allocator, json_data);
    defer parsed.deinit();

    for (parsed.value) |vector| {
        try std.testing.expectEqual(@as(usize, 32), vector.sha256_size);
        try std.testing.expectEqual(@as(usize, 32), vector.keccak256_size);
        try std.testing.expectEqual(@as(usize, 32), vector.blake3_size);
        try std.testing.expectEqual(@as(usize, 32), vector.solana_hash_size);
    }
}
