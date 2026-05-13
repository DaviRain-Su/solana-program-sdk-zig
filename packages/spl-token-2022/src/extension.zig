//! Token-2022 fixed-length extension metadata and read-only mint views.

const std = @import("std");
const state = @import("state.zig");
const tlv = @import("tlv.zig");

pub const Error = tlv.Error || error{
    InvalidExtensionLength,
};

pub const ExtensionType = enum(u16) {
    uninitialized = 0,
    transfer_fee_config = 1,
    transfer_fee_amount = 2,
    mint_close_authority = 3,
    confidential_transfer_mint = 4,
    confidential_transfer_account = 5,
    default_account_state = 6,
    immutable_owner = 7,
    memo_transfer = 8,
    non_transferable = 9,
    interest_bearing_config = 10,
    cpi_guard = 11,
    permanent_delegate = 12,
    non_transferable_account = 13,
    transfer_hook = 14,
    transfer_hook_account = 15,
    confidential_transfer_fee_config = 16,
    confidential_transfer_fee_amount = 17,
    metadata_pointer = 18,
    token_metadata = 19,
    group_pointer = 20,
    token_group = 21,
    group_member_pointer = 22,
    token_group_member = 23,
    confidential_mint_burn = 24,
    scaled_ui_amount = 25,
    pausable = 26,
    pausable_account = 27,
    permissioned_burn = 28,
};

pub const SupportRow = struct {
    name: []const u8,
    account_type: state.AccountType,
    extension_type: ExtensionType,
    payload_len: usize,
    exposed_fields: []const []const u8,
};

pub const TransferFeeView = extern struct {
    epoch: u64 align(1),
    maximum_fee: u64 align(1),
    transfer_fee_basis_points: u16 align(1),
};

pub const TransferFeeConfigView = extern struct {
    transfer_fee_config_authority: [32]u8,
    withdraw_withheld_authority: [32]u8,
    withheld_amount: u64 align(1),
    older_transfer_fee: TransferFeeView align(1),
    newer_transfer_fee: TransferFeeView align(1),

    pub const TYPE = ExtensionType.transfer_fee_config;
    pub const PAYLOAD_LEN: usize = 108;

    pub fn fromBytes(bytes: []const u8) Error!*align(1) const TransferFeeConfigView {
        return castPayload(TransferFeeConfigView, bytes, PAYLOAD_LEN);
    }
};

pub const MintCloseAuthorityView = extern struct {
    close_authority: [32]u8,

    pub const TYPE = ExtensionType.mint_close_authority;
    pub const PAYLOAD_LEN: usize = 32;

    pub fn fromBytes(bytes: []const u8) Error!*align(1) const MintCloseAuthorityView {
        return castPayload(MintCloseAuthorityView, bytes, PAYLOAD_LEN);
    }
};

pub const DefaultAccountStateView = extern struct {
    state: u8,

    pub const TYPE = ExtensionType.default_account_state;
    pub const PAYLOAD_LEN: usize = 1;

    pub fn fromBytes(bytes: []const u8) Error!*align(1) const DefaultAccountStateView {
        return castPayload(DefaultAccountStateView, bytes, PAYLOAD_LEN);
    }
};

pub const NonTransferableView = struct {
    pub const TYPE = ExtensionType.non_transferable;
    pub const PAYLOAD_LEN: usize = 0;

    pub fn fromBytes(bytes: []const u8) Error!NonTransferableView {
        if (bytes.len != 0) return error.InvalidExtensionLength;
        return .{};
    }
};

pub const InterestBearingConfigView = extern struct {
    rate_authority: [32]u8,
    initialization_timestamp: i64 align(1),
    pre_update_average_rate: i16 align(1),
    last_update_timestamp: i64 align(1),
    current_rate: i16 align(1),

    pub const TYPE = ExtensionType.interest_bearing_config;
    pub const PAYLOAD_LEN: usize = 52;

    pub fn fromBytes(bytes: []const u8) Error!*align(1) const InterestBearingConfigView {
        return castPayload(InterestBearingConfigView, bytes, PAYLOAD_LEN);
    }
};

pub const PermanentDelegateView = extern struct {
    delegate: [32]u8,

    pub const TYPE = ExtensionType.permanent_delegate;
    pub const PAYLOAD_LEN: usize = 32;

    pub fn fromBytes(bytes: []const u8) Error!*align(1) const PermanentDelegateView {
        return castPayload(PermanentDelegateView, bytes, PAYLOAD_LEN);
    }
};

pub const TransferHookView = extern struct {
    authority: [32]u8,
    program_id: [32]u8,

    pub const TYPE = ExtensionType.transfer_hook;
    pub const PAYLOAD_LEN: usize = 64;

    pub fn fromBytes(bytes: []const u8) Error!*align(1) const TransferHookView {
        return castPayload(TransferHookView, bytes, PAYLOAD_LEN);
    }
};

pub const MetadataPointerView = extern struct {
    authority: [32]u8,
    metadata_address: [32]u8,

    pub const TYPE = ExtensionType.metadata_pointer;
    pub const PAYLOAD_LEN: usize = 64;

    pub fn fromBytes(bytes: []const u8) Error!*align(1) const MetadataPointerView {
        return castPayload(MetadataPointerView, bytes, PAYLOAD_LEN);
    }
};

pub const GroupPointerView = extern struct {
    authority: [32]u8,
    group_address: [32]u8,

    pub const TYPE = ExtensionType.group_pointer;
    pub const PAYLOAD_LEN: usize = 64;

    pub fn fromBytes(bytes: []const u8) Error!*align(1) const GroupPointerView {
        return castPayload(GroupPointerView, bytes, PAYLOAD_LEN);
    }
};

pub const GroupMemberPointerView = extern struct {
    authority: [32]u8,
    member_address: [32]u8,

    pub const TYPE = ExtensionType.group_member_pointer;
    pub const PAYLOAD_LEN: usize = 64;

    pub fn fromBytes(bytes: []const u8) Error!*align(1) const GroupMemberPointerView {
        return castPayload(GroupMemberPointerView, bytes, PAYLOAD_LEN);
    }
};

pub const ScaledUiAmountView = extern struct {
    authority: [32]u8,
    multiplier: [8]u8,
    new_multiplier_effective_timestamp: i64 align(1),
    new_multiplier: [8]u8,

    pub const TYPE = ExtensionType.scaled_ui_amount;
    pub const PAYLOAD_LEN: usize = 56;

    pub fn fromBytes(bytes: []const u8) Error!*align(1) const ScaledUiAmountView {
        return castPayload(ScaledUiAmountView, bytes, PAYLOAD_LEN);
    }
};

pub const PausableView = extern struct {
    authority: [32]u8,
    paused: u8,

    pub const TYPE = ExtensionType.pausable;
    pub const PAYLOAD_LEN: usize = 33;

    pub fn fromBytes(bytes: []const u8) Error!*align(1) const PausableView {
        return castPayload(PausableView, bytes, PAYLOAD_LEN);
    }
};

pub const MINT_FIXED_LEN_SUPPORT = [_]SupportRow{
    .{
        .name = "TransferFeeConfig",
        .account_type = .mint,
        .extension_type = .transfer_fee_config,
        .payload_len = TransferFeeConfigView.PAYLOAD_LEN,
        .exposed_fields = &.{
            "transfer_fee_config_authority",
            "withdraw_withheld_authority",
            "withheld_amount",
            "older_transfer_fee",
            "newer_transfer_fee",
        },
    },
    .{
        .name = "MintCloseAuthority",
        .account_type = .mint,
        .extension_type = .mint_close_authority,
        .payload_len = MintCloseAuthorityView.PAYLOAD_LEN,
        .exposed_fields = &.{"close_authority"},
    },
    .{
        .name = "DefaultAccountState",
        .account_type = .mint,
        .extension_type = .default_account_state,
        .payload_len = DefaultAccountStateView.PAYLOAD_LEN,
        .exposed_fields = &.{"state"},
    },
    .{
        .name = "NonTransferable",
        .account_type = .mint,
        .extension_type = .non_transferable,
        .payload_len = NonTransferableView.PAYLOAD_LEN,
        .exposed_fields = &.{},
    },
    .{
        .name = "InterestBearingConfig",
        .account_type = .mint,
        .extension_type = .interest_bearing_config,
        .payload_len = InterestBearingConfigView.PAYLOAD_LEN,
        .exposed_fields = &.{
            "rate_authority",
            "initialization_timestamp",
            "pre_update_average_rate",
            "last_update_timestamp",
            "current_rate",
        },
    },
    .{
        .name = "PermanentDelegate",
        .account_type = .mint,
        .extension_type = .permanent_delegate,
        .payload_len = PermanentDelegateView.PAYLOAD_LEN,
        .exposed_fields = &.{"delegate"},
    },
    .{
        .name = "TransferHook",
        .account_type = .mint,
        .extension_type = .transfer_hook,
        .payload_len = TransferHookView.PAYLOAD_LEN,
        .exposed_fields = &.{
            "authority",
            "program_id",
        },
    },
    .{
        .name = "MetadataPointer",
        .account_type = .mint,
        .extension_type = .metadata_pointer,
        .payload_len = MetadataPointerView.PAYLOAD_LEN,
        .exposed_fields = &.{
            "authority",
            "metadata_address",
        },
    },
    .{
        .name = "GroupPointer",
        .account_type = .mint,
        .extension_type = .group_pointer,
        .payload_len = GroupPointerView.PAYLOAD_LEN,
        .exposed_fields = &.{
            "authority",
            "group_address",
        },
    },
    .{
        .name = "GroupMemberPointer",
        .account_type = .mint,
        .extension_type = .group_member_pointer,
        .payload_len = GroupMemberPointerView.PAYLOAD_LEN,
        .exposed_fields = &.{
            "authority",
            "member_address",
        },
    },
    .{
        .name = "ScaledUiAmount",
        .account_type = .mint,
        .extension_type = .scaled_ui_amount,
        .payload_len = ScaledUiAmountView.PAYLOAD_LEN,
        .exposed_fields = &.{
            "authority",
            "multiplier",
            "new_multiplier_effective_timestamp",
            "new_multiplier",
        },
    },
    .{
        .name = "Pausable",
        .account_type = .mint,
        .extension_type = .pausable,
        .payload_len = PausableView.PAYLOAD_LEN,
        .exposed_fields = &.{
            "authority",
            "paused",
        },
    },
};

fn castPayload(comptime T: type, bytes: []const u8, expected_len: usize) Error!*align(1) const T {
    if (bytes.len != expected_len) return error.InvalidExtensionLength;
    return @ptrCast(bytes.ptr);
}

fn findMintPayload(bytes: []const u8, extension_type: ExtensionType) Error![]const u8 {
    const record = try tlv.findMintExtension(bytes, @intFromEnum(extension_type));
    return record.value;
}

pub fn getTransferFeeConfig(mint_bytes: []const u8) Error!*align(1) const TransferFeeConfigView {
    return TransferFeeConfigView.fromBytes(try findMintPayload(mint_bytes, .transfer_fee_config));
}

pub fn getMintCloseAuthority(mint_bytes: []const u8) Error!*align(1) const MintCloseAuthorityView {
    return MintCloseAuthorityView.fromBytes(try findMintPayload(mint_bytes, .mint_close_authority));
}

pub fn getDefaultAccountState(mint_bytes: []const u8) Error!*align(1) const DefaultAccountStateView {
    return DefaultAccountStateView.fromBytes(try findMintPayload(mint_bytes, .default_account_state));
}

pub fn getNonTransferable(mint_bytes: []const u8) Error!NonTransferableView {
    return NonTransferableView.fromBytes(try findMintPayload(mint_bytes, .non_transferable));
}

pub fn getInterestBearingConfig(mint_bytes: []const u8) Error!*align(1) const InterestBearingConfigView {
    return InterestBearingConfigView.fromBytes(try findMintPayload(mint_bytes, .interest_bearing_config));
}

pub fn getPermanentDelegate(mint_bytes: []const u8) Error!*align(1) const PermanentDelegateView {
    return PermanentDelegateView.fromBytes(try findMintPayload(mint_bytes, .permanent_delegate));
}

pub fn getTransferHook(mint_bytes: []const u8) Error!*align(1) const TransferHookView {
    return TransferHookView.fromBytes(try findMintPayload(mint_bytes, .transfer_hook));
}

pub fn getMetadataPointer(mint_bytes: []const u8) Error!*align(1) const MetadataPointerView {
    return MetadataPointerView.fromBytes(try findMintPayload(mint_bytes, .metadata_pointer));
}

pub fn getGroupPointer(mint_bytes: []const u8) Error!*align(1) const GroupPointerView {
    return GroupPointerView.fromBytes(try findMintPayload(mint_bytes, .group_pointer));
}

pub fn getGroupMemberPointer(mint_bytes: []const u8) Error!*align(1) const GroupMemberPointerView {
    return GroupMemberPointerView.fromBytes(try findMintPayload(mint_bytes, .group_member_pointer));
}

pub fn getScaledUiAmount(mint_bytes: []const u8) Error!*align(1) const ScaledUiAmountView {
    return ScaledUiAmountView.fromBytes(try findMintPayload(mint_bytes, .scaled_ui_amount));
}

pub fn getPausable(mint_bytes: []const u8) Error!*align(1) const PausableView {
    return PausableView.fromBytes(try findMintPayload(mint_bytes, .pausable));
}

fn fillSequence(bytes: []u8, start: u8) void {
    for (bytes, 0..) |*byte, i| {
        byte.* = start +% @as(u8, @intCast(i));
    }
}

fn writeIntLe(comptime T: type, dst: []u8, value: T) void {
    std.mem.writeInt(T, dst[0..@sizeOf(T)], value, .little);
}

fn writeRecord(dst: []u8, extension_type: ExtensionType, value: []const u8) usize {
    writeIntLe(u16, dst[0..2], @intFromEnum(extension_type));
    writeIntLe(u16, dst[2..4], @intCast(value.len));
    @memcpy(dst[4 .. 4 + value.len], value);
    return 4 + value.len;
}

fn makeExtensionCapableMint() [512]u8 {
    var buf = [_]u8{0} ** 512;
    buf[tlv.ACCOUNT_TYPE_OFFSET] = @intFromEnum(state.AccountType.mint);
    return buf;
}

fn expectSupportRow(
    actual: SupportRow,
    expected_name: []const u8,
    expected_type: ExtensionType,
    expected_len: usize,
    expected_fields: []const []const u8,
) !void {
    try std.testing.expectEqual(state.AccountType.mint, actual.account_type);
    try std.testing.expectEqualStrings(expected_name, actual.name);
    try std.testing.expectEqual(expected_type, actual.extension_type);
    try std.testing.expectEqual(expected_len, actual.payload_len);
    try std.testing.expectEqual(expected_fields.len, actual.exposed_fields.len);
    for (expected_fields, actual.exposed_fields) |expected, got| {
        try std.testing.expectEqualStrings(expected, got);
    }
}

fn expectWrongLengths(comptime View: type) !void {
    if (View.PAYLOAD_LEN == 0) return;

    var buf = [_]u8{0} ** 128;
    try std.testing.expectError(
        error.InvalidExtensionLength,
        View.fromBytes(buf[0 .. View.PAYLOAD_LEN - 1]),
    );
    try std.testing.expectError(
        error.InvalidExtensionLength,
        View.fromBytes(buf[0 .. View.PAYLOAD_LEN + 1]),
    );
}

fn expectParsedView(comptime View: type, bytes: []const u8) !*align(1) const View {
    const view = try View.fromBytes(bytes);
    try std.testing.expectEqual(@intFromPtr(bytes.ptr), @intFromPtr(std.mem.asBytes(view).ptr));
    try std.testing.expectEqualSlices(u8, bytes, std.mem.asBytes(view));
    return view;
}

test "ExtensionType discriminants are canonical for v0.1 mint views" {
    try std.testing.expectEqual(@as(u16, 1), @intFromEnum(ExtensionType.transfer_fee_config));
    try std.testing.expectEqual(@as(u16, 3), @intFromEnum(ExtensionType.mint_close_authority));
    try std.testing.expectEqual(@as(u16, 6), @intFromEnum(ExtensionType.default_account_state));
    try std.testing.expectEqual(@as(u16, 9), @intFromEnum(ExtensionType.non_transferable));
    try std.testing.expectEqual(@as(u16, 10), @intFromEnum(ExtensionType.interest_bearing_config));
    try std.testing.expectEqual(@as(u16, 12), @intFromEnum(ExtensionType.permanent_delegate));
    try std.testing.expectEqual(@as(u16, 14), @intFromEnum(ExtensionType.transfer_hook));
    try std.testing.expectEqual(@as(u16, 18), @intFromEnum(ExtensionType.metadata_pointer));
    try std.testing.expectEqual(@as(u16, 20), @intFromEnum(ExtensionType.group_pointer));
    try std.testing.expectEqual(@as(u16, 22), @intFromEnum(ExtensionType.group_member_pointer));
    try std.testing.expectEqual(@as(u16, 25), @intFromEnum(ExtensionType.scaled_ui_amount));
    try std.testing.expectEqual(@as(u16, 26), @intFromEnum(ExtensionType.pausable));
}

test "mint support table rows lock canonical type ids, payload lengths, and raw field names" {
    try std.testing.expectEqual(@as(usize, 12), MINT_FIXED_LEN_SUPPORT.len);

    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[0],
        "TransferFeeConfig",
        .transfer_fee_config,
        108,
        &.{
            "transfer_fee_config_authority",
            "withdraw_withheld_authority",
            "withheld_amount",
            "older_transfer_fee",
            "newer_transfer_fee",
        },
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[1],
        "MintCloseAuthority",
        .mint_close_authority,
        32,
        &.{"close_authority"},
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[2],
        "DefaultAccountState",
        .default_account_state,
        1,
        &.{"state"},
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[3],
        "NonTransferable",
        .non_transferable,
        0,
        &.{},
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[4],
        "InterestBearingConfig",
        .interest_bearing_config,
        52,
        &.{
            "rate_authority",
            "initialization_timestamp",
            "pre_update_average_rate",
            "last_update_timestamp",
            "current_rate",
        },
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[5],
        "PermanentDelegate",
        .permanent_delegate,
        32,
        &.{"delegate"},
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[6],
        "TransferHook",
        .transfer_hook,
        64,
        &.{
            "authority",
            "program_id",
        },
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[7],
        "MetadataPointer",
        .metadata_pointer,
        64,
        &.{
            "authority",
            "metadata_address",
        },
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[8],
        "GroupPointer",
        .group_pointer,
        64,
        &.{
            "authority",
            "group_address",
        },
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[9],
        "GroupMemberPointer",
        .group_member_pointer,
        64,
        &.{
            "authority",
            "member_address",
        },
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[10],
        "ScaledUiAmount",
        .scaled_ui_amount,
        56,
        &.{
            "authority",
            "multiplier",
            "new_multiplier_effective_timestamp",
            "new_multiplier",
        },
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[11],
        "Pausable",
        .pausable,
        33,
        &.{
            "authority",
            "paused",
        },
    );
}

test "mint view payload lengths match canonical serialized sizes" {
    try std.testing.expectEqual(@as(usize, 108), TransferFeeConfigView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 108), @sizeOf(TransferFeeConfigView));
    try std.testing.expectEqual(@as(usize, 32), MintCloseAuthorityView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(MintCloseAuthorityView));
    try std.testing.expectEqual(@as(usize, 1), DefaultAccountStateView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(DefaultAccountStateView));
    try std.testing.expectEqual(@as(usize, 0), NonTransferableView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 52), InterestBearingConfigView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 52), @sizeOf(InterestBearingConfigView));
    try std.testing.expectEqual(@as(usize, 32), PermanentDelegateView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(PermanentDelegateView));
    try std.testing.expectEqual(@as(usize, 64), TransferHookView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 64), @sizeOf(TransferHookView));
    try std.testing.expectEqual(@as(usize, 64), MetadataPointerView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 64), @sizeOf(MetadataPointerView));
    try std.testing.expectEqual(@as(usize, 64), GroupPointerView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 64), @sizeOf(GroupPointerView));
    try std.testing.expectEqual(@as(usize, 64), GroupMemberPointerView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 64), @sizeOf(GroupMemberPointerView));
    try std.testing.expectEqual(@as(usize, 56), ScaledUiAmountView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 56), @sizeOf(ScaledUiAmountView));
    try std.testing.expectEqual(@as(usize, 33), PausableView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 33), @sizeOf(PausableView));
}

test "TransferFeeConfig view preserves raw authorities, withheld amount, and fee fields" {
    var payload = [_]u8{0} ** TransferFeeConfigView.PAYLOAD_LEN;
    fillSequence(payload[0..32], 1);
    fillSequence(payload[32..64], 101);
    writeIntLe(u64, payload[64..72], 0x1122334455667788);
    writeIntLe(u64, payload[72..80], 0x0102030405060708);
    writeIntLe(u64, payload[80..88], 0x1112131415161718);
    writeIntLe(u16, payload[88..90], 321);
    writeIntLe(u64, payload[90..98], 0x2122232425262728);
    writeIntLe(u64, payload[98..106], 0x3132333435363738);
    writeIntLe(u16, payload[106..108], 654);

    const view = try expectParsedView(TransferFeeConfigView, &payload);
    try std.testing.expectEqualSlices(u8, payload[0..32], std.mem.asBytes(&view.transfer_fee_config_authority));
    try std.testing.expectEqualSlices(u8, payload[32..64], std.mem.asBytes(&view.withdraw_withheld_authority));
    try std.testing.expectEqual(@as(u64, 0x1122334455667788), view.withheld_amount);
    try std.testing.expectEqual(@as(u64, 0x0102030405060708), view.older_transfer_fee.epoch);
    try std.testing.expectEqual(@as(u64, 0x1112131415161718), view.older_transfer_fee.maximum_fee);
    try std.testing.expectEqual(@as(u16, 321), view.older_transfer_fee.transfer_fee_basis_points);
    try std.testing.expectEqual(@as(u64, 0x2122232425262728), view.newer_transfer_fee.epoch);
    try std.testing.expectEqual(@as(u64, 0x3132333435363738), view.newer_transfer_fee.maximum_fee);
    try std.testing.expectEqual(@as(u16, 654), view.newer_transfer_fee.transfer_fee_basis_points);
    try expectWrongLengths(TransferFeeConfigView);
}

test "MintCloseAuthority view preserves absent and present authority bytes" {
    var absent = [_]u8{0} ** MintCloseAuthorityView.PAYLOAD_LEN;
    const absent_view = try expectParsedView(MintCloseAuthorityView, &absent);
    try std.testing.expectEqualSlices(u8, absent[0..], std.mem.asBytes(&absent_view.close_authority));

    var present = [_]u8{0} ** MintCloseAuthorityView.PAYLOAD_LEN;
    fillSequence(present[0..], 77);
    const present_view = try expectParsedView(MintCloseAuthorityView, &present);
    try std.testing.expectEqualSlices(u8, present[0..], std.mem.asBytes(&present_view.close_authority));
    try expectWrongLengths(MintCloseAuthorityView);
}

test "DefaultAccountState view exposes raw state byte" {
    inline for ([_]u8{ 1, 2, 0xFE }) |raw_state| {
        const payload = [_]u8{raw_state};
        const view = try expectParsedView(DefaultAccountStateView, &payload);
        try std.testing.expectEqual(raw_state, view.state);
    }
    try expectWrongLengths(DefaultAccountStateView);
}

test "NonTransferable marker accepts only empty payload" {
    const empty = [_]u8{};
    _ = try NonTransferableView.fromBytes(empty[0..]);

    const wrong = [_]u8{1};
    try std.testing.expectError(error.InvalidExtensionLength, NonTransferableView.fromBytes(wrong[0..]));
}

test "InterestBearingConfig view preserves raw authority, timestamps, and rates" {
    var payload = [_]u8{0} ** InterestBearingConfigView.PAYLOAD_LEN;
    fillSequence(payload[0..32], 19);
    writeIntLe(i64, payload[32..40], -1234567890);
    writeIntLe(i16, payload[40..42], -321);
    writeIntLe(i64, payload[42..50], 9876543210);
    writeIntLe(i16, payload[50..52], 654);

    const view = try expectParsedView(InterestBearingConfigView, &payload);
    try std.testing.expectEqualSlices(u8, payload[0..32], std.mem.asBytes(&view.rate_authority));
    try std.testing.expectEqual(@as(i64, -1234567890), view.initialization_timestamp);
    try std.testing.expectEqual(@as(i16, -321), view.pre_update_average_rate);
    try std.testing.expectEqual(@as(i64, 9876543210), view.last_update_timestamp);
    try std.testing.expectEqual(@as(i16, 654), view.current_rate);
    try expectWrongLengths(InterestBearingConfigView);
}

test "PermanentDelegate view preserves absent and present delegate bytes" {
    var absent = [_]u8{0} ** PermanentDelegateView.PAYLOAD_LEN;
    const absent_view = try expectParsedView(PermanentDelegateView, &absent);
    try std.testing.expectEqualSlices(u8, absent[0..], std.mem.asBytes(&absent_view.delegate));

    var present = [_]u8{0} ** PermanentDelegateView.PAYLOAD_LEN;
    fillSequence(present[0..], 155);
    const present_view = try expectParsedView(PermanentDelegateView, &present);
    try std.testing.expectEqualSlices(u8, present[0..], std.mem.asBytes(&present_view.delegate));
    try expectWrongLengths(PermanentDelegateView);
}

test "TransferHook view preserves authority and program id bytes" {
    var payload = [_]u8{0} ** TransferHookView.PAYLOAD_LEN;
    fillSequence(payload[0..32], 11);
    fillSequence(payload[32..64], 211);

    const view = try expectParsedView(TransferHookView, &payload);
    try std.testing.expectEqualSlices(u8, payload[0..32], std.mem.asBytes(&view.authority));
    try std.testing.expectEqualSlices(u8, payload[32..64], std.mem.asBytes(&view.program_id));
    try expectWrongLengths(TransferHookView);
}

test "MetadataPointer view preserves authority and metadata address bytes" {
    var payload = [_]u8{0} ** MetadataPointerView.PAYLOAD_LEN;
    fillSequence(payload[0..32], 21);
    fillSequence(payload[32..64], 121);

    const view = try expectParsedView(MetadataPointerView, &payload);
    try std.testing.expectEqualSlices(u8, payload[0..32], std.mem.asBytes(&view.authority));
    try std.testing.expectEqualSlices(u8, payload[32..64], std.mem.asBytes(&view.metadata_address));
    try expectWrongLengths(MetadataPointerView);
}

test "GroupPointer view preserves authority and group address bytes" {
    var payload = [_]u8{0} ** GroupPointerView.PAYLOAD_LEN;
    fillSequence(payload[0..32], 31);
    fillSequence(payload[32..64], 131);

    const view = try expectParsedView(GroupPointerView, &payload);
    try std.testing.expectEqualSlices(u8, payload[0..32], std.mem.asBytes(&view.authority));
    try std.testing.expectEqualSlices(u8, payload[32..64], std.mem.asBytes(&view.group_address));
    try expectWrongLengths(GroupPointerView);
}

test "GroupMemberPointer view preserves authority and member address bytes" {
    var payload = [_]u8{0} ** GroupMemberPointerView.PAYLOAD_LEN;
    fillSequence(payload[0..32], 41);
    fillSequence(payload[32..64], 141);

    const view = try expectParsedView(GroupMemberPointerView, &payload);
    try std.testing.expectEqualSlices(u8, payload[0..32], std.mem.asBytes(&view.authority));
    try std.testing.expectEqualSlices(u8, payload[32..64], std.mem.asBytes(&view.member_address));
    try expectWrongLengths(GroupMemberPointerView);
}

test "ScaledUiAmount view preserves raw multiplier fields and timestamp bytes" {
    var payload = [_]u8{0} ** ScaledUiAmountView.PAYLOAD_LEN;
    fillSequence(payload[0..32], 51);
    fillSequence(payload[32..40], 201);
    writeIntLe(i64, payload[40..48], 777777777);
    fillSequence(payload[48..56], 91);

    const view = try expectParsedView(ScaledUiAmountView, &payload);
    try std.testing.expectEqualSlices(u8, payload[0..32], std.mem.asBytes(&view.authority));
    try std.testing.expectEqualSlices(u8, payload[32..40], view.multiplier[0..]);
    try std.testing.expectEqual(@as(i64, 777777777), view.new_multiplier_effective_timestamp);
    try std.testing.expectEqualSlices(u8, payload[48..56], view.new_multiplier[0..]);
    try expectWrongLengths(ScaledUiAmountView);
}

test "Pausable view preserves authority bytes and paused flag" {
    inline for ([_]u8{ 0, 1 }) |paused| {
        var payload = [_]u8{0} ** PausableView.PAYLOAD_LEN;
        fillSequence(payload[0..32], 61);
        payload[32] = paused;

        const view = try expectParsedView(PausableView, &payload);
        try std.testing.expectEqualSlices(u8, payload[0..32], std.mem.asBytes(&view.authority));
        try std.testing.expectEqual(paused, view.paused);
    }
    try expectWrongLengths(PausableView);
}

test "mint helpers look up canonical TLV records and return typed read-only views" {
    var mint = makeExtensionCapableMint();
    var fee_payload = [_]u8{0} ** TransferFeeConfigView.PAYLOAD_LEN;
    fillSequence(fee_payload[0..], 1);
    var metadata_payload = [_]u8{0} ** MetadataPointerView.PAYLOAD_LEN;
    fillSequence(metadata_payload[0..], 99);
    const marker_payload = [_]u8{};

    var off: usize = tlv.TLV_START_OFFSET;
    off += writeRecord(mint[off .. off + 4 + fee_payload.len], .transfer_fee_config, &fee_payload);
    off += writeRecord(mint[off .. off + 4 + metadata_payload.len], .metadata_pointer, &metadata_payload);
    off += writeRecord(mint[off .. off + 4 + marker_payload.len], .non_transferable, marker_payload[0..]);

    const fee = try getTransferFeeConfig(mint[0..off]);
    try std.testing.expectEqualSlices(u8, fee_payload[0..], std.mem.asBytes(fee));

    const metadata = try getMetadataPointer(mint[0..off]);
    try std.testing.expectEqualSlices(u8, metadata_payload[0..], std.mem.asBytes(metadata));

    _ = try getNonTransferable(mint[0..off]);
}

test {
    std.testing.refAllDecls(@This());
}
