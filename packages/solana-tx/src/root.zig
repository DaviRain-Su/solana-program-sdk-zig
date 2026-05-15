//! `solana_tx` — off-chain transaction message foundations.
//!
//! v0.1 covers legacy message compilation plus legacy/v0 message and
//! transaction serialization. Signing, keypair management, and RPC live
//! in separate off-chain packages.

const std = @import("std");
const sol = @import("solana_program_sdk");
const codec = @import("solana_codec");

pub const Pubkey = sol.Pubkey;
pub const AccountMeta = sol.cpi.AccountMeta;
pub const Instruction = sol.cpi.Instruction;

pub const HASH_BYTES: usize = 32;
pub const SIGNATURE_BYTES: usize = 64;
pub const MAX_LEGACY_ACCOUNT_KEYS: usize = 256;
pub const VERSIONED_MESSAGE_PREFIX: u8 = 0x80;
pub const V0_MESSAGE_VERSION: u8 = 0;
pub const Signature = [SIGNATURE_BYTES]u8;

pub const Error = codec.Error || error{
    TooManyAccountKeys,
    TooManyInstructionAccounts,
    AccountKeyBufferTooSmall,
    CompiledInstructionBufferTooSmall,
    InstructionAccountIndexBufferTooSmall,
    UnknownProgramId,
    OutputTooSmall,
    SignatureCountMismatch,
};

pub const MessageHeader = extern struct {
    num_required_signatures: u8,
    num_readonly_signed_accounts: u8,
    num_readonly_unsigned_accounts: u8,
};

pub const CompiledInstruction = struct {
    program_id_index: u8,
    accounts: []const u8,
    data: []const u8,
};

pub const LegacyMessage = struct {
    header: MessageHeader,
    account_keys: []const Pubkey,
    recent_blockhash: *const [HASH_BYTES]u8,
    instructions: []const CompiledInstruction,
};

pub const MessageAddressTableLookup = struct {
    account_key: *const Pubkey,
    writable_indexes: []const u8,
    readonly_indexes: []const u8,
};

pub const V0Message = struct {
    header: MessageHeader,
    account_keys: []const Pubkey,
    recent_blockhash: *const [HASH_BYTES]u8,
    instructions: []const CompiledInstruction,
    address_table_lookups: []const MessageAddressTableLookup,
};

const KeyFlags = struct {
    key: Pubkey,
    is_signer: bool,
    is_writable: bool,
};

pub fn compileLegacyMessage(
    payer: *const Pubkey,
    recent_blockhash: *const [HASH_BYTES]u8,
    instructions: []const Instruction,
    account_keys_out: []Pubkey,
    compiled_instructions_out: []CompiledInstruction,
    instruction_account_indices_out: []u8,
) Error!LegacyMessage {
    if (compiled_instructions_out.len < instructions.len) {
        return error.CompiledInstructionBufferTooSmall;
    }

    var keys: [MAX_LEGACY_ACCOUNT_KEYS]KeyFlags = undefined;
    var key_count: usize = 0;

    try upsertKey(&keys, &key_count, payer, true, true);

    for (instructions) |ix| {
        for (ix.accounts) |meta| {
            try upsertKey(
                &keys,
                &key_count,
                meta.pubkey,
                meta.is_signer != 0,
                meta.is_writable != 0,
            );
        }
        try upsertKey(&keys, &key_count, ix.program_id, false, false);
    }

    if (account_keys_out.len < key_count) return error.AccountKeyBufferTooSmall;

    const counts = writeCanonicalKeys(keys[0..key_count], account_keys_out);
    if (counts.signed_writable + counts.signed_readonly > std.math.maxInt(u8)) {
        return error.TooManyAccountKeys;
    }
    const account_keys = account_keys_out[0..key_count];

    var index_cursor: usize = 0;
    for (instructions, 0..) |ix, i| {
        if (ix.accounts.len > std.math.maxInt(u8)) {
            return error.TooManyInstructionAccounts;
        }
        if (index_cursor + ix.accounts.len > instruction_account_indices_out.len) {
            return error.InstructionAccountIndexBufferTooSmall;
        }

        const program_index = findKey(account_keys, ix.program_id) orelse {
            return error.UnknownProgramId;
        };

        const start = index_cursor;
        for (ix.accounts) |meta| {
            instruction_account_indices_out[index_cursor] = findKey(account_keys, meta.pubkey) orelse {
                return error.UnknownProgramId;
            };
            index_cursor += 1;
        }

        compiled_instructions_out[i] = .{
            .program_id_index = program_index,
            .accounts = instruction_account_indices_out[start..index_cursor],
            .data = ix.data,
        };
    }

    return .{
        .header = .{
            .num_required_signatures = @intCast(counts.signed_writable + counts.signed_readonly),
            .num_readonly_signed_accounts = @intCast(counts.signed_readonly),
            .num_readonly_unsigned_accounts = @intCast(counts.unsigned_readonly),
        },
        .account_keys = account_keys,
        .recent_blockhash = recent_blockhash,
        .instructions = compiled_instructions_out[0..instructions.len],
    };
}

pub fn serializedLegacyMessageLen(message: LegacyMessage) Error!usize {
    var len: usize = @sizeOf(MessageHeader);
    len += try shortVecLen(message.account_keys.len);
    len += message.account_keys.len * @sizeOf(Pubkey);
    len += HASH_BYTES;
    len += try shortVecLen(message.instructions.len);
    for (message.instructions) |ix| {
        len += 1;
        len += (try shortVecLen(ix.accounts.len)) + ix.accounts.len;
        len += (try shortVecLen(ix.data.len)) + ix.data.len;
    }
    return len;
}

pub fn serializeLegacyMessage(message: LegacyMessage, out: []u8) Error![]u8 {
    const needed = try serializedLegacyMessageLen(message);
    if (out.len < needed) return error.OutputTooSmall;

    var pos: usize = 0;
    out[pos] = message.header.num_required_signatures;
    out[pos + 1] = message.header.num_readonly_signed_accounts;
    out[pos + 2] = message.header.num_readonly_unsigned_accounts;
    pos += @sizeOf(MessageHeader);

    pos += try writeShortVec(message.account_keys.len, out[pos..]);
    for (message.account_keys) |key| {
        @memcpy(out[pos..][0..PUBKEY_BYTES], &key);
        pos += PUBKEY_BYTES;
    }

    @memcpy(out[pos..][0..HASH_BYTES], message.recent_blockhash);
    pos += HASH_BYTES;

    pos += try writeShortVec(message.instructions.len, out[pos..]);
    for (message.instructions) |ix| {
        out[pos] = ix.program_id_index;
        pos += 1;

        pos += try writeShortVec(ix.accounts.len, out[pos..]);
        @memcpy(out[pos..][0..ix.accounts.len], ix.accounts);
        pos += ix.accounts.len;

        pos += try writeShortVec(ix.data.len, out[pos..]);
        @memcpy(out[pos..][0..ix.data.len], ix.data);
        pos += ix.data.len;
    }

    return out[0..pos];
}

pub fn serializedLegacyTransactionLen(signatures: []const Signature, message: LegacyMessage) Error!usize {
    return (try shortVecLen(signatures.len)) +
        signatures.len * SIGNATURE_BYTES +
        (try serializedLegacyMessageLen(message));
}

pub fn serializeLegacyTransaction(
    signatures: []const Signature,
    message: LegacyMessage,
    out: []u8,
) Error![]u8 {
    if (signatures.len != message.header.num_required_signatures) {
        return error.SignatureCountMismatch;
    }

    const needed = try serializedLegacyTransactionLen(signatures, message);
    if (out.len < needed) return error.OutputTooSmall;

    var pos: usize = 0;
    pos += try writeShortVec(signatures.len, out[pos..]);
    for (signatures) |signature| {
        @memcpy(out[pos..][0..SIGNATURE_BYTES], &signature);
        pos += SIGNATURE_BYTES;
    }

    const message_bytes = try serializeLegacyMessage(message, out[pos..]);
    pos += message_bytes.len;
    return out[0..pos];
}

pub fn serializedV0MessageLen(message: V0Message) Error!usize {
    var len: usize = 1;
    len += try serializedLegacyMessageLen(.{
        .header = message.header,
        .account_keys = message.account_keys,
        .recent_blockhash = message.recent_blockhash,
        .instructions = message.instructions,
    });
    len += try shortVecLen(message.address_table_lookups.len);
    for (message.address_table_lookups) |lookup| {
        len += PUBKEY_BYTES;
        len += (try shortVecLen(lookup.writable_indexes.len)) + lookup.writable_indexes.len;
        len += (try shortVecLen(lookup.readonly_indexes.len)) + lookup.readonly_indexes.len;
    }
    return len;
}

pub fn serializeV0Message(message: V0Message, out: []u8) Error![]u8 {
    const needed = try serializedV0MessageLen(message);
    if (out.len < needed) return error.OutputTooSmall;

    var pos: usize = 0;
    out[pos] = VERSIONED_MESSAGE_PREFIX | V0_MESSAGE_VERSION;
    pos += 1;

    const legacy_body = try serializeLegacyMessage(.{
        .header = message.header,
        .account_keys = message.account_keys,
        .recent_blockhash = message.recent_blockhash,
        .instructions = message.instructions,
    }, out[pos..]);
    pos += legacy_body.len;

    pos += try writeShortVec(message.address_table_lookups.len, out[pos..]);
    for (message.address_table_lookups) |lookup| {
        @memcpy(out[pos..][0..PUBKEY_BYTES], lookup.account_key);
        pos += PUBKEY_BYTES;

        pos += try writeShortVec(lookup.writable_indexes.len, out[pos..]);
        @memcpy(out[pos..][0..lookup.writable_indexes.len], lookup.writable_indexes);
        pos += lookup.writable_indexes.len;

        pos += try writeShortVec(lookup.readonly_indexes.len, out[pos..]);
        @memcpy(out[pos..][0..lookup.readonly_indexes.len], lookup.readonly_indexes);
        pos += lookup.readonly_indexes.len;
    }

    return out[0..pos];
}

pub fn serializedV0TransactionLen(signatures: []const Signature, message: V0Message) Error!usize {
    return (try shortVecLen(signatures.len)) +
        signatures.len * SIGNATURE_BYTES +
        (try serializedV0MessageLen(message));
}

pub fn serializeV0Transaction(
    signatures: []const Signature,
    message: V0Message,
    out: []u8,
) Error![]u8 {
    if (signatures.len != message.header.num_required_signatures) {
        return error.SignatureCountMismatch;
    }

    const needed = try serializedV0TransactionLen(signatures, message);
    if (out.len < needed) return error.OutputTooSmall;

    var pos: usize = 0;
    pos += try writeShortVec(signatures.len, out[pos..]);
    for (signatures) |signature| {
        @memcpy(out[pos..][0..SIGNATURE_BYTES], &signature);
        pos += SIGNATURE_BYTES;
    }

    const message_bytes = try serializeV0Message(message, out[pos..]);
    pos += message_bytes.len;
    return out[0..pos];
}

pub fn shortVecLen(value: usize) Error!usize {
    return codec.shortVecLen(value);
}

pub fn writeShortVec(value: usize, out: []u8) Error!usize {
    return codec.writeShortVec(value, out);
}

const PUBKEY_BYTES = sol.PUBKEY_BYTES;

fn upsertKey(
    keys: *[MAX_LEGACY_ACCOUNT_KEYS]KeyFlags,
    key_count: *usize,
    key: *const Pubkey,
    is_signer: bool,
    is_writable: bool,
) Error!void {
    for (keys[0..key_count.*]) |*entry| {
        if (sol.pubkey.pubkeyEq(&entry.key, key)) {
            entry.is_signer = entry.is_signer or is_signer;
            entry.is_writable = entry.is_writable or is_writable;
            return;
        }
    }

    if (key_count.* >= MAX_LEGACY_ACCOUNT_KEYS) return error.TooManyAccountKeys;
    keys[key_count.*] = .{
        .key = key.*,
        .is_signer = is_signer,
        .is_writable = is_writable,
    };
    key_count.* += 1;
}

fn writeCanonicalKeys(keys: []const KeyFlags, out: []Pubkey) struct {
    signed_writable: usize,
    signed_readonly: usize,
    unsigned_writable: usize,
    unsigned_readonly: usize,
} {
    var cursor: usize = 0;
    var signed_writable: usize = 0;
    var signed_readonly: usize = 0;
    var unsigned_writable: usize = 0;
    var unsigned_readonly: usize = 0;

    for (keys) |entry| {
        if (entry.is_signer and entry.is_writable) {
            out[cursor] = entry.key;
            cursor += 1;
            signed_writable += 1;
        }
    }
    for (keys) |entry| {
        if (entry.is_signer and !entry.is_writable) {
            out[cursor] = entry.key;
            cursor += 1;
            signed_readonly += 1;
        }
    }
    for (keys) |entry| {
        if (!entry.is_signer and entry.is_writable) {
            out[cursor] = entry.key;
            cursor += 1;
            unsigned_writable += 1;
        }
    }
    for (keys) |entry| {
        if (!entry.is_signer and !entry.is_writable) {
            out[cursor] = entry.key;
            cursor += 1;
            unsigned_readonly += 1;
        }
    }

    return .{
        .signed_writable = signed_writable,
        .signed_readonly = signed_readonly,
        .unsigned_writable = unsigned_writable,
        .unsigned_readonly = unsigned_readonly,
    };
}

fn findKey(keys: []const Pubkey, target: *const Pubkey) ?u8 {
    for (keys, 0..) |*key, i| {
        if (sol.pubkey.pubkeyEq(key, target)) return @intCast(i);
    }
    return null;
}

test "shortvec encodes Solana compact-u16 style lengths" {
    var buf: [4]u8 = undefined;

    try std.testing.expectEqual(@as(usize, 1), try writeShortVec(0, &buf));
    try std.testing.expectEqual(@as(u8, 0), buf[0]);

    try std.testing.expectEqual(@as(usize, 1), try writeShortVec(127, &buf));
    try std.testing.expectEqual(@as(u8, 127), buf[0]);

    try std.testing.expectEqual(@as(usize, 2), try writeShortVec(128, &buf));
    try std.testing.expectEqualSlices(u8, &.{ 0x80, 0x01 }, buf[0..2]);

    try std.testing.expectEqual(@as(usize, 2), try shortVecLen(16_383));
    try std.testing.expectEqual(@as(usize, 3), try shortVecLen(16_384));
    try std.testing.expectError(error.LengthOverflow, writeShortVec(65_536, &buf));
}

test "compileLegacyMessage orders payer signers writable accounts and programs canonically" {
    const payer: Pubkey = .{1} ** 32;
    const source: Pubkey = .{2} ** 32;
    const owner: Pubkey = .{3} ** 32;
    const mint: Pubkey = .{4} ** 32;
    const token_program: Pubkey = .{5} ** 32;
    const recent: [HASH_BYTES]u8 = .{9} ** HASH_BYTES;

    var metas = [_]AccountMeta{
        AccountMeta.writable(&source),
        AccountMeta.readonly(&mint),
        AccountMeta.signer(&owner),
    };
    const data = [_]u8{ 12, 1, 0, 0, 0, 0, 0, 0, 0, 6 };
    const ix = Instruction.init(&token_program, &metas, &data);

    var keys: [8]Pubkey = undefined;
    var compiled: [1]CompiledInstruction = undefined;
    var ix_indices: [4]u8 = undefined;
    const message = try compileLegacyMessage(
        &payer,
        &recent,
        &.{ix},
        &keys,
        &compiled,
        &ix_indices,
    );

    try std.testing.expectEqual(@as(u8, 2), message.header.num_required_signatures);
    try std.testing.expectEqual(@as(u8, 1), message.header.num_readonly_signed_accounts);
    try std.testing.expectEqual(@as(u8, 2), message.header.num_readonly_unsigned_accounts);
    try std.testing.expectEqual(@as(usize, 5), message.account_keys.len);
    try std.testing.expectEqualSlices(u8, &payer, &message.account_keys[0]);
    try std.testing.expectEqualSlices(u8, &owner, &message.account_keys[1]);
    try std.testing.expectEqualSlices(u8, &source, &message.account_keys[2]);
    try std.testing.expectEqualSlices(u8, &mint, &message.account_keys[3]);
    try std.testing.expectEqualSlices(u8, &token_program, &message.account_keys[4]);

    try std.testing.expectEqual(@as(u8, 4), message.instructions[0].program_id_index);
    try std.testing.expectEqualSlices(u8, &.{ 2, 3, 1 }, message.instructions[0].accounts);
}

test "serializeLegacyMessage emits canonical legacy message bytes" {
    const payer: Pubkey = .{1} ** 32;
    const memo_program: Pubkey = .{2} ** 32;
    const recent: [HASH_BYTES]u8 = .{3} ** HASH_BYTES;
    const data = "hi";
    const ix = Instruction.init(&memo_program, &.{}, data);

    var keys: [4]Pubkey = undefined;
    var compiled: [1]CompiledInstruction = undefined;
    var ix_indices: [1]u8 = undefined;
    const message = try compileLegacyMessage(
        &payer,
        &recent,
        &.{ix},
        &keys,
        &compiled,
        &ix_indices,
    );

    var out: [128]u8 = undefined;
    const bytes = try serializeLegacyMessage(message, &out);

    try std.testing.expectEqual(try serializedLegacyMessageLen(message), bytes.len);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 1, 2 }, bytes[0..4]);
    try std.testing.expectEqualSlices(u8, &payer, bytes[4..36]);
    try std.testing.expectEqualSlices(u8, &memo_program, bytes[36..68]);
    try std.testing.expectEqualSlices(u8, &recent, bytes[68..100]);
    try std.testing.expectEqualSlices(u8, &.{ 1, 1, 0, 2, 'h', 'i' }, bytes[100..]);
}

test "serializeLegacyTransaction prefixes signatures before message bytes" {
    const payer: Pubkey = .{1} ** 32;
    const program: Pubkey = .{2} ** 32;
    const recent: [HASH_BYTES]u8 = .{3} ** HASH_BYTES;
    const ix = Instruction.init(&program, &.{}, &.{});

    var keys: [4]Pubkey = undefined;
    var compiled: [1]CompiledInstruction = undefined;
    var ix_indices: [1]u8 = undefined;
    const message = try compileLegacyMessage(
        &payer,
        &recent,
        &.{ix},
        &keys,
        &compiled,
        &ix_indices,
    );

    const signature: Signature = .{0xaa} ** SIGNATURE_BYTES;
    var out: [192]u8 = undefined;
    const bytes = try serializeLegacyTransaction(&.{signature}, message, &out);

    try std.testing.expectEqual(try serializedLegacyTransactionLen(&.{signature}, message), bytes.len);
    try std.testing.expectEqual(@as(u8, 1), bytes[0]);
    try std.testing.expectEqualSlices(u8, &signature, bytes[1..65]);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 1 }, bytes[65..68]);
}

test "serializeLegacyTransaction enforces required signature count" {
    const payer: Pubkey = .{1} ** 32;
    const program: Pubkey = .{2} ** 32;
    const recent: [HASH_BYTES]u8 = .{3} ** HASH_BYTES;
    const ix = Instruction.init(&program, &.{}, &.{});

    var keys: [4]Pubkey = undefined;
    var compiled: [1]CompiledInstruction = undefined;
    var ix_indices: [1]u8 = undefined;
    const message = try compileLegacyMessage(
        &payer,
        &recent,
        &.{ix},
        &keys,
        &compiled,
        &ix_indices,
    );

    var out: [128]u8 = undefined;
    try std.testing.expectError(
        error.SignatureCountMismatch,
        serializeLegacyTransaction(&.{}, message, &out),
    );
}

test "serializeV0Message appends address table lookups after the message body" {
    const payer: Pubkey = .{1} ** 32;
    const program: Pubkey = .{2} ** 32;
    const recent: [HASH_BYTES]u8 = .{3} ** HASH_BYTES;
    const table: Pubkey = .{4} ** 32;
    const ix = Instruction.init(&program, &.{}, &.{9});

    var keys: [4]Pubkey = undefined;
    var compiled: [1]CompiledInstruction = undefined;
    var ix_indices: [1]u8 = undefined;
    const legacy = try compileLegacyMessage(
        &payer,
        &recent,
        &.{ix},
        &keys,
        &compiled,
        &ix_indices,
    );
    const lookup: MessageAddressTableLookup = .{
        .account_key = &table,
        .writable_indexes = &.{ 2, 5 },
        .readonly_indexes = &.{7},
    };
    const message: V0Message = .{
        .header = legacy.header,
        .account_keys = legacy.account_keys,
        .recent_blockhash = legacy.recent_blockhash,
        .instructions = legacy.instructions,
        .address_table_lookups = &.{lookup},
    };

    var out: [192]u8 = undefined;
    const bytes = try serializeV0Message(message, &out);
    try std.testing.expectEqual(try serializedV0MessageLen(message), bytes.len);
    try std.testing.expectEqual(@as(u8, 0x80), bytes[0]);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 1, 2 }, bytes[1..5]);

    const lookup_start = (try serializedLegacyMessageLen(legacy)) + 1;
    try std.testing.expectEqual(@as(u8, 1), bytes[lookup_start]);
    try std.testing.expectEqualSlices(u8, &table, bytes[lookup_start + 1 .. lookup_start + 33]);
    try std.testing.expectEqualSlices(u8, &.{ 2, 2, 5, 1, 7 }, bytes[lookup_start + 33 ..]);
}

test "serializeV0Transaction prefixes signatures before versioned message bytes" {
    const payer: Pubkey = .{1} ** 32;
    const program: Pubkey = .{2} ** 32;
    const recent: [HASH_BYTES]u8 = .{3} ** HASH_BYTES;
    const ix = Instruction.init(&program, &.{}, &.{});

    var keys: [4]Pubkey = undefined;
    var compiled: [1]CompiledInstruction = undefined;
    var ix_indices: [1]u8 = undefined;
    const legacy = try compileLegacyMessage(
        &payer,
        &recent,
        &.{ix},
        &keys,
        &compiled,
        &ix_indices,
    );
    const message: V0Message = .{
        .header = legacy.header,
        .account_keys = legacy.account_keys,
        .recent_blockhash = legacy.recent_blockhash,
        .instructions = legacy.instructions,
        .address_table_lookups = &.{},
    };

    const signature: Signature = .{0xbb} ** SIGNATURE_BYTES;
    var out: [192]u8 = undefined;
    const bytes = try serializeV0Transaction(&.{signature}, message, &out);

    try std.testing.expectEqual(try serializedV0TransactionLen(&.{signature}, message), bytes.len);
    try std.testing.expectEqual(@as(u8, 1), bytes[0]);
    try std.testing.expectEqualSlices(u8, &signature, bytes[1..65]);
    try std.testing.expectEqual(@as(u8, 0x80), bytes[65]);
}

test "serializeV0Transaction enforces required signature count" {
    const message: V0Message = .{
        .header = .{
            .num_required_signatures = 1,
            .num_readonly_signed_accounts = 0,
            .num_readonly_unsigned_accounts = 0,
        },
        .account_keys = &.{},
        .recent_blockhash = &(.{0} ** HASH_BYTES),
        .instructions = &.{},
        .address_table_lookups = &.{},
    };
    var out: [64]u8 = undefined;
    try std.testing.expectError(
        error.SignatureCountMismatch,
        serializeV0Transaction(&.{}, message, &out),
    );
}

test "compileLegacyMessage reports caller buffer sizing errors" {
    const payer: Pubkey = .{1} ** 32;
    const program: Pubkey = .{2} ** 32;
    const account: Pubkey = .{3} ** 32;
    const recent: [HASH_BYTES]u8 = .{4} ** HASH_BYTES;
    var metas = [_]AccountMeta{AccountMeta.writable(&account)};
    const ix = Instruction.init(&program, &metas, &.{});

    var one_key: [1]Pubkey = undefined;
    var compiled: [1]CompiledInstruction = undefined;
    var ix_indices: [1]u8 = undefined;
    try std.testing.expectError(
        error.AccountKeyBufferTooSmall,
        compileLegacyMessage(&payer, &recent, &.{ix}, &one_key, &compiled, &ix_indices),
    );

    var keys: [4]Pubkey = undefined;
    var no_indices: [0]u8 = .{};
    try std.testing.expectError(
        error.InstructionAccountIndexBufferTooSmall,
        compileLegacyMessage(&payer, &recent, &.{ix}, &keys, &compiled, &no_indices),
    );
}

test "@import(\"solana_tx\") exposes the intended v0.1 surface" {
    try std.testing.expect(@hasDecl(@This(), "compileLegacyMessage"));
    try std.testing.expect(@hasDecl(@This(), "serializeLegacyMessage"));
    try std.testing.expect(@hasDecl(@This(), "serializeLegacyTransaction"));
    try std.testing.expect(@hasDecl(@This(), "serializeV0Message"));
    try std.testing.expect(@hasDecl(@This(), "serializeV0Transaction"));
    try std.testing.expect(@hasDecl(@This(), "MessageAddressTableLookup"));
    try std.testing.expect(@hasDecl(@This(), "CompiledInstruction"));
    try std.testing.expect(!@hasDecl(@This(), "rpc"));
    try std.testing.expect(!@hasDecl(@This(), "client"));
    try std.testing.expect(!@hasDecl(@This(), "keypair"));
    try std.testing.expect(!@hasDecl(@This(), "sign"));
}
