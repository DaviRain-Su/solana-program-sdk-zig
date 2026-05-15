//! Token-2022 fixed-length extension metadata and read-only views.

const std = @import("std");
const state = @import("state.zig");
const tlv = @import("tlv.zig");

pub const Error = tlv.Error || error{
    InvalidExtensionLength,
    UnsupportedExtension,
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

pub const ConfidentialTransferMintView = extern struct {
    authority: [32]u8,
    auto_approve_new_accounts: u8,
    auditor_elgamal_pubkey: [32]u8,

    pub const TYPE = ExtensionType.confidential_transfer_mint;
    pub const PAYLOAD_LEN: usize = 65;

    pub fn fromBytes(bytes: []const u8) Error!*align(1) const ConfidentialTransferMintView {
        return castPayload(ConfidentialTransferMintView, bytes, PAYLOAD_LEN);
    }
};

pub const ConfidentialTransferAccountView = extern struct {
    approved: u8,
    elgamal_pubkey: [32]u8,
    pending_balance_lo: [64]u8,
    pending_balance_hi: [64]u8,
    available_balance: [64]u8,
    decryptable_available_balance: [36]u8,
    allow_confidential_credits: u8,
    allow_non_confidential_credits: u8,
    pending_balance_credit_counter: [8]u8,
    maximum_pending_balance_credit_counter: [8]u8,
    expected_pending_balance_credit_counter: [8]u8,
    actual_pending_balance_credit_counter: [8]u8,

    pub const TYPE = ExtensionType.confidential_transfer_account;
    pub const PAYLOAD_LEN: usize = 295;

    pub fn fromBytes(bytes: []const u8) Error!*align(1) const ConfidentialTransferAccountView {
        return castPayload(ConfidentialTransferAccountView, bytes, PAYLOAD_LEN);
    }
};

pub const ConfidentialTransferFeeConfigView = extern struct {
    authority: [32]u8,
    withdraw_withheld_authority_elgamal_pubkey: [32]u8,
    harvest_to_mint_enabled: u8,
    withheld_amount: [64]u8,

    pub const TYPE = ExtensionType.confidential_transfer_fee_config;
    pub const PAYLOAD_LEN: usize = 129;

    pub fn fromBytes(bytes: []const u8) Error!*align(1) const ConfidentialTransferFeeConfigView {
        return castPayload(ConfidentialTransferFeeConfigView, bytes, PAYLOAD_LEN);
    }
};

pub const ConfidentialTransferFeeAmountView = extern struct {
    withheld_amount: [64]u8,

    pub const TYPE = ExtensionType.confidential_transfer_fee_amount;
    pub const PAYLOAD_LEN: usize = 64;

    pub fn fromBytes(bytes: []const u8) Error!*align(1) const ConfidentialTransferFeeAmountView {
        return castPayload(ConfidentialTransferFeeAmountView, bytes, PAYLOAD_LEN);
    }
};

pub const ConfidentialMintBurnView = extern struct {
    confidential_supply: [64]u8,
    decryptable_supply: [36]u8,
    supply_elgamal_pubkey: [32]u8,
    pending_burn: [64]u8,

    pub const TYPE = ExtensionType.confidential_mint_burn;
    pub const PAYLOAD_LEN: usize = 196;

    pub fn fromBytes(bytes: []const u8) Error!*align(1) const ConfidentialMintBurnView {
        return castPayload(ConfidentialMintBurnView, bytes, PAYLOAD_LEN);
    }
};

pub const TransferFeeAmountView = extern struct {
    withheld_amount: u64 align(1),

    pub const TYPE = ExtensionType.transfer_fee_amount;
    pub const PAYLOAD_LEN: usize = 8;

    pub fn fromBytes(bytes: []const u8) Error!*align(1) const TransferFeeAmountView {
        return castPayload(TransferFeeAmountView, bytes, PAYLOAD_LEN);
    }
};

pub const ImmutableOwnerView = struct {
    pub const TYPE = ExtensionType.immutable_owner;
    pub const PAYLOAD_LEN: usize = 0;

    pub fn fromBytes(bytes: []const u8) Error!ImmutableOwnerView {
        if (bytes.len != 0) return error.InvalidExtensionLength;
        return .{};
    }
};

pub const MemoTransferView = extern struct {
    require_incoming_transfer_memos: u8,

    pub const TYPE = ExtensionType.memo_transfer;
    pub const PAYLOAD_LEN: usize = 1;

    pub fn fromBytes(bytes: []const u8) Error!*align(1) const MemoTransferView {
        return castPayload(MemoTransferView, bytes, PAYLOAD_LEN);
    }
};

pub const CpiGuardView = extern struct {
    lock_cpi: u8,

    pub const TYPE = ExtensionType.cpi_guard;
    pub const PAYLOAD_LEN: usize = 1;

    pub fn fromBytes(bytes: []const u8) Error!*align(1) const CpiGuardView {
        return castPayload(CpiGuardView, bytes, PAYLOAD_LEN);
    }
};

pub const NonTransferableAccountView = struct {
    pub const TYPE = ExtensionType.non_transferable_account;
    pub const PAYLOAD_LEN: usize = 0;

    pub fn fromBytes(bytes: []const u8) Error!NonTransferableAccountView {
        if (bytes.len != 0) return error.InvalidExtensionLength;
        return .{};
    }
};

pub const TransferHookAccountView = extern struct {
    transferring: u8,

    pub const TYPE = ExtensionType.transfer_hook_account;
    pub const PAYLOAD_LEN: usize = 1;

    pub fn fromBytes(bytes: []const u8) Error!*align(1) const TransferHookAccountView {
        return castPayload(TransferHookAccountView, bytes, PAYLOAD_LEN);
    }
};

pub const PausableAccountView = struct {
    pub const TYPE = ExtensionType.pausable_account;
    pub const PAYLOAD_LEN: usize = 0;

    pub fn fromBytes(bytes: []const u8) Error!PausableAccountView {
        if (bytes.len != 0) return error.InvalidExtensionLength;
        return .{};
    }
};

pub const MINT_FIXED_LEN_SUPPORT = [_]SupportRow{
    .{
        .name = "ConfidentialTransferMint",
        .account_type = .mint,
        .extension_type = .confidential_transfer_mint,
        .payload_len = ConfidentialTransferMintView.PAYLOAD_LEN,
        .exposed_fields = &.{
            "authority",
            "auto_approve_new_accounts",
            "auditor_elgamal_pubkey",
        },
    },
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
    .{
        .name = "ConfidentialTransferFeeConfig",
        .account_type = .mint,
        .extension_type = .confidential_transfer_fee_config,
        .payload_len = ConfidentialTransferFeeConfigView.PAYLOAD_LEN,
        .exposed_fields = &.{
            "authority",
            "withdraw_withheld_authority_elgamal_pubkey",
            "harvest_to_mint_enabled",
            "withheld_amount",
        },
    },
    .{
        .name = "ConfidentialMintBurn",
        .account_type = .mint,
        .extension_type = .confidential_mint_burn,
        .payload_len = ConfidentialMintBurnView.PAYLOAD_LEN,
        .exposed_fields = &.{
            "confidential_supply",
            "decryptable_supply",
            "supply_elgamal_pubkey",
            "pending_burn",
        },
    },
};

pub const ACCOUNT_FIXED_LEN_SUPPORT = [_]SupportRow{
    .{
        .name = "ConfidentialTransferAccount",
        .account_type = .account,
        .extension_type = .confidential_transfer_account,
        .payload_len = ConfidentialTransferAccountView.PAYLOAD_LEN,
        .exposed_fields = &.{
            "approved",
            "elgamal_pubkey",
            "pending_balance_lo",
            "pending_balance_hi",
            "available_balance",
            "decryptable_available_balance",
            "allow_confidential_credits",
            "allow_non_confidential_credits",
            "pending_balance_credit_counter",
            "maximum_pending_balance_credit_counter",
            "expected_pending_balance_credit_counter",
            "actual_pending_balance_credit_counter",
        },
    },
    .{
        .name = "TransferFeeAmount",
        .account_type = .account,
        .extension_type = .transfer_fee_amount,
        .payload_len = TransferFeeAmountView.PAYLOAD_LEN,
        .exposed_fields = &.{"withheld_amount"},
    },
    .{
        .name = "ImmutableOwner",
        .account_type = .account,
        .extension_type = .immutable_owner,
        .payload_len = ImmutableOwnerView.PAYLOAD_LEN,
        .exposed_fields = &.{},
    },
    .{
        .name = "MemoTransfer",
        .account_type = .account,
        .extension_type = .memo_transfer,
        .payload_len = MemoTransferView.PAYLOAD_LEN,
        .exposed_fields = &.{"require_incoming_transfer_memos"},
    },
    .{
        .name = "CpiGuard",
        .account_type = .account,
        .extension_type = .cpi_guard,
        .payload_len = CpiGuardView.PAYLOAD_LEN,
        .exposed_fields = &.{"lock_cpi"},
    },
    .{
        .name = "NonTransferableAccount",
        .account_type = .account,
        .extension_type = .non_transferable_account,
        .payload_len = NonTransferableAccountView.PAYLOAD_LEN,
        .exposed_fields = &.{},
    },
    .{
        .name = "TransferHookAccount",
        .account_type = .account,
        .extension_type = .transfer_hook_account,
        .payload_len = TransferHookAccountView.PAYLOAD_LEN,
        .exposed_fields = &.{"transferring"},
    },
    .{
        .name = "PausableAccount",
        .account_type = .account,
        .extension_type = .pausable_account,
        .payload_len = PausableAccountView.PAYLOAD_LEN,
        .exposed_fields = &.{},
    },
    .{
        .name = "ConfidentialTransferFeeAmount",
        .account_type = .account,
        .extension_type = .confidential_transfer_fee_amount,
        .payload_len = ConfidentialTransferFeeAmountView.PAYLOAD_LEN,
        .exposed_fields = &.{"withheld_amount"},
    },
};

pub const KNOWN_UNSUPPORTED_FIXED_VIEW_TYPES = [_]ExtensionType{
    .token_metadata,
    .token_group,
    .token_group_member,
    .permissioned_burn,
};

fn castPayload(comptime T: type, bytes: []const u8, expected_len: usize) Error!*align(1) const T {
    if (bytes.len != expected_len) return error.InvalidExtensionLength;
    return @ptrCast(bytes.ptr);
}

fn findSupportRow(rows: []const SupportRow, extension_type: ExtensionType) ?SupportRow {
    for (rows) |row| {
        if (row.extension_type == extension_type) return row;
    }
    return null;
}

fn requireMintSupport(extension_type: ExtensionType) Error!SupportRow {
    if (findSupportRow(MINT_FIXED_LEN_SUPPORT[0..], extension_type)) |row| return row;
    if (findSupportRow(ACCOUNT_FIXED_LEN_SUPPORT[0..], extension_type) != null) {
        return error.WrongAccountType;
    }
    return error.UnsupportedExtension;
}

fn requireAccountSupport(extension_type: ExtensionType) Error!SupportRow {
    if (findSupportRow(ACCOUNT_FIXED_LEN_SUPPORT[0..], extension_type)) |row| return row;
    if (findSupportRow(MINT_FIXED_LEN_SUPPORT[0..], extension_type) != null) {
        return error.WrongAccountType;
    }
    return error.UnsupportedExtension;
}

pub fn getMintViewPayload(mint_bytes: []const u8, extension_type: ExtensionType) Error![]const u8 {
    const row = try requireMintSupport(extension_type);
    const record = try tlv.findMintExtension(mint_bytes, @intFromEnum(extension_type));
    if (record.value.len != row.payload_len) return error.InvalidExtensionLength;
    return record.value;
}

pub fn getAccountViewPayload(account_bytes: []const u8, extension_type: ExtensionType) Error![]const u8 {
    const row = try requireAccountSupport(extension_type);
    const record = try tlv.findAccountExtension(account_bytes, @intFromEnum(extension_type));
    if (record.value.len != row.payload_len) return error.InvalidExtensionLength;
    return record.value;
}

pub fn getTransferFeeConfig(mint_bytes: []const u8) Error!*align(1) const TransferFeeConfigView {
    return TransferFeeConfigView.fromBytes(try getMintViewPayload(mint_bytes, .transfer_fee_config));
}

pub fn getMintCloseAuthority(mint_bytes: []const u8) Error!*align(1) const MintCloseAuthorityView {
    return MintCloseAuthorityView.fromBytes(try getMintViewPayload(mint_bytes, .mint_close_authority));
}

pub fn getDefaultAccountState(mint_bytes: []const u8) Error!*align(1) const DefaultAccountStateView {
    return DefaultAccountStateView.fromBytes(try getMintViewPayload(mint_bytes, .default_account_state));
}

pub fn getNonTransferable(mint_bytes: []const u8) Error!NonTransferableView {
    return NonTransferableView.fromBytes(try getMintViewPayload(mint_bytes, .non_transferable));
}

pub fn getInterestBearingConfig(mint_bytes: []const u8) Error!*align(1) const InterestBearingConfigView {
    return InterestBearingConfigView.fromBytes(try getMintViewPayload(mint_bytes, .interest_bearing_config));
}

pub fn getPermanentDelegate(mint_bytes: []const u8) Error!*align(1) const PermanentDelegateView {
    return PermanentDelegateView.fromBytes(try getMintViewPayload(mint_bytes, .permanent_delegate));
}

pub fn getTransferHook(mint_bytes: []const u8) Error!*align(1) const TransferHookView {
    return TransferHookView.fromBytes(try getMintViewPayload(mint_bytes, .transfer_hook));
}

pub fn getMetadataPointer(mint_bytes: []const u8) Error!*align(1) const MetadataPointerView {
    return MetadataPointerView.fromBytes(try getMintViewPayload(mint_bytes, .metadata_pointer));
}

pub fn getGroupPointer(mint_bytes: []const u8) Error!*align(1) const GroupPointerView {
    return GroupPointerView.fromBytes(try getMintViewPayload(mint_bytes, .group_pointer));
}

pub fn getGroupMemberPointer(mint_bytes: []const u8) Error!*align(1) const GroupMemberPointerView {
    return GroupMemberPointerView.fromBytes(try getMintViewPayload(mint_bytes, .group_member_pointer));
}

pub fn getScaledUiAmount(mint_bytes: []const u8) Error!*align(1) const ScaledUiAmountView {
    return ScaledUiAmountView.fromBytes(try getMintViewPayload(mint_bytes, .scaled_ui_amount));
}

pub fn getPausable(mint_bytes: []const u8) Error!*align(1) const PausableView {
    return PausableView.fromBytes(try getMintViewPayload(mint_bytes, .pausable));
}

pub fn getConfidentialTransferMint(mint_bytes: []const u8) Error!*align(1) const ConfidentialTransferMintView {
    return ConfidentialTransferMintView.fromBytes(try getMintViewPayload(mint_bytes, .confidential_transfer_mint));
}

pub fn getConfidentialTransferFeeConfig(mint_bytes: []const u8) Error!*align(1) const ConfidentialTransferFeeConfigView {
    return ConfidentialTransferFeeConfigView.fromBytes(try getMintViewPayload(mint_bytes, .confidential_transfer_fee_config));
}

pub fn getConfidentialMintBurn(mint_bytes: []const u8) Error!*align(1) const ConfidentialMintBurnView {
    return ConfidentialMintBurnView.fromBytes(try getMintViewPayload(mint_bytes, .confidential_mint_burn));
}

pub fn getTransferFeeAmount(account_bytes: []const u8) Error!*align(1) const TransferFeeAmountView {
    return TransferFeeAmountView.fromBytes(try getAccountViewPayload(account_bytes, .transfer_fee_amount));
}

pub fn getImmutableOwner(account_bytes: []const u8) Error!ImmutableOwnerView {
    return ImmutableOwnerView.fromBytes(try getAccountViewPayload(account_bytes, .immutable_owner));
}

pub fn getMemoTransfer(account_bytes: []const u8) Error!*align(1) const MemoTransferView {
    return MemoTransferView.fromBytes(try getAccountViewPayload(account_bytes, .memo_transfer));
}

pub fn getCpiGuard(account_bytes: []const u8) Error!*align(1) const CpiGuardView {
    return CpiGuardView.fromBytes(try getAccountViewPayload(account_bytes, .cpi_guard));
}

pub fn getNonTransferableAccount(account_bytes: []const u8) Error!NonTransferableAccountView {
    return NonTransferableAccountView.fromBytes(try getAccountViewPayload(account_bytes, .non_transferable_account));
}

pub fn getTransferHookAccount(account_bytes: []const u8) Error!*align(1) const TransferHookAccountView {
    return TransferHookAccountView.fromBytes(try getAccountViewPayload(account_bytes, .transfer_hook_account));
}

pub fn getPausableAccount(account_bytes: []const u8) Error!PausableAccountView {
    return PausableAccountView.fromBytes(try getAccountViewPayload(account_bytes, .pausable_account));
}

pub fn getConfidentialTransferAccount(account_bytes: []const u8) Error!*align(1) const ConfidentialTransferAccountView {
    return ConfidentialTransferAccountView.fromBytes(try getAccountViewPayload(account_bytes, .confidential_transfer_account));
}

pub fn getConfidentialTransferFeeAmount(account_bytes: []const u8) Error!*align(1) const ConfidentialTransferFeeAmountView {
    return ConfidentialTransferFeeAmountView.fromBytes(try getAccountViewPayload(account_bytes, .confidential_transfer_fee_amount));
}

fn fillSequence(bytes: []u8, start: u8) void {
    for (bytes, 0..) |*byte, i| {
        byte.* = start +% @as(u8, @truncate(i));
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

    var buf = [_]u8{0} ** 320;
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
    try std.testing.expectEqual(@as(u16, 4), @intFromEnum(ExtensionType.confidential_transfer_mint));
    try std.testing.expectEqual(@as(u16, 5), @intFromEnum(ExtensionType.confidential_transfer_account));
    try std.testing.expectEqual(@as(u16, 1), @intFromEnum(ExtensionType.transfer_fee_config));
    try std.testing.expectEqual(@as(u16, 3), @intFromEnum(ExtensionType.mint_close_authority));
    try std.testing.expectEqual(@as(u16, 6), @intFromEnum(ExtensionType.default_account_state));
    try std.testing.expectEqual(@as(u16, 9), @intFromEnum(ExtensionType.non_transferable));
    try std.testing.expectEqual(@as(u16, 10), @intFromEnum(ExtensionType.interest_bearing_config));
    try std.testing.expectEqual(@as(u16, 12), @intFromEnum(ExtensionType.permanent_delegate));
    try std.testing.expectEqual(@as(u16, 14), @intFromEnum(ExtensionType.transfer_hook));
    try std.testing.expectEqual(@as(u16, 16), @intFromEnum(ExtensionType.confidential_transfer_fee_config));
    try std.testing.expectEqual(@as(u16, 17), @intFromEnum(ExtensionType.confidential_transfer_fee_amount));
    try std.testing.expectEqual(@as(u16, 18), @intFromEnum(ExtensionType.metadata_pointer));
    try std.testing.expectEqual(@as(u16, 20), @intFromEnum(ExtensionType.group_pointer));
    try std.testing.expectEqual(@as(u16, 22), @intFromEnum(ExtensionType.group_member_pointer));
    try std.testing.expectEqual(@as(u16, 24), @intFromEnum(ExtensionType.confidential_mint_burn));
    try std.testing.expectEqual(@as(u16, 25), @intFromEnum(ExtensionType.scaled_ui_amount));
    try std.testing.expectEqual(@as(u16, 26), @intFromEnum(ExtensionType.pausable));
}

test "mint support table rows lock canonical type ids, payload lengths, and raw field names" {
    try std.testing.expectEqual(@as(usize, 15), MINT_FIXED_LEN_SUPPORT.len);

    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[0],
        "ConfidentialTransferMint",
        .confidential_transfer_mint,
        65,
        &.{
            "authority",
            "auto_approve_new_accounts",
            "auditor_elgamal_pubkey",
        },
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[1],
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
        MINT_FIXED_LEN_SUPPORT[2],
        "MintCloseAuthority",
        .mint_close_authority,
        32,
        &.{"close_authority"},
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[3],
        "DefaultAccountState",
        .default_account_state,
        1,
        &.{"state"},
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[4],
        "NonTransferable",
        .non_transferable,
        0,
        &.{},
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[5],
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
        MINT_FIXED_LEN_SUPPORT[6],
        "PermanentDelegate",
        .permanent_delegate,
        32,
        &.{"delegate"},
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[7],
        "TransferHook",
        .transfer_hook,
        64,
        &.{
            "authority",
            "program_id",
        },
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[8],
        "MetadataPointer",
        .metadata_pointer,
        64,
        &.{
            "authority",
            "metadata_address",
        },
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[9],
        "GroupPointer",
        .group_pointer,
        64,
        &.{
            "authority",
            "group_address",
        },
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[10],
        "GroupMemberPointer",
        .group_member_pointer,
        64,
        &.{
            "authority",
            "member_address",
        },
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[11],
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
        MINT_FIXED_LEN_SUPPORT[12],
        "Pausable",
        .pausable,
        33,
        &.{
            "authority",
            "paused",
        },
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[13],
        "ConfidentialTransferFeeConfig",
        .confidential_transfer_fee_config,
        129,
        &.{
            "authority",
            "withdraw_withheld_authority_elgamal_pubkey",
            "harvest_to_mint_enabled",
            "withheld_amount",
        },
    );
    try expectSupportRow(
        MINT_FIXED_LEN_SUPPORT[14],
        "ConfidentialMintBurn",
        .confidential_mint_burn,
        196,
        &.{
            "confidential_supply",
            "decryptable_supply",
            "supply_elgamal_pubkey",
            "pending_burn",
        },
    );
}

test "mint view payload lengths match canonical serialized sizes" {
    try std.testing.expectEqual(@as(usize, 65), ConfidentialTransferMintView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 65), @sizeOf(ConfidentialTransferMintView));
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
    try std.testing.expectEqual(@as(usize, 129), ConfidentialTransferFeeConfigView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 129), @sizeOf(ConfidentialTransferFeeConfigView));
    try std.testing.expectEqual(@as(usize, 196), ConfidentialMintBurnView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 196), @sizeOf(ConfidentialMintBurnView));
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

test "confidential mint views preserve raw POD ciphertext and authority fields" {
    var mint_payload = [_]u8{0} ** ConfidentialTransferMintView.PAYLOAD_LEN;
    fillSequence(mint_payload[0..32], 71);
    mint_payload[32] = 1;
    fillSequence(mint_payload[33..65], 171);

    const mint_view = try expectParsedView(ConfidentialTransferMintView, &mint_payload);
    try std.testing.expectEqualSlices(u8, mint_payload[0..32], mint_view.authority[0..]);
    try std.testing.expectEqual(@as(u8, 1), mint_view.auto_approve_new_accounts);
    try std.testing.expectEqualSlices(u8, mint_payload[33..65], mint_view.auditor_elgamal_pubkey[0..]);
    try expectWrongLengths(ConfidentialTransferMintView);

    var fee_payload = [_]u8{0} ** ConfidentialTransferFeeConfigView.PAYLOAD_LEN;
    fillSequence(fee_payload[0..32], 81);
    fillSequence(fee_payload[32..64], 181);
    fee_payload[64] = 1;
    fillSequence(fee_payload[65..129], 21);

    const fee_view = try expectParsedView(ConfidentialTransferFeeConfigView, &fee_payload);
    try std.testing.expectEqualSlices(u8, fee_payload[0..32], fee_view.authority[0..]);
    try std.testing.expectEqualSlices(u8, fee_payload[32..64], fee_view.withdraw_withheld_authority_elgamal_pubkey[0..]);
    try std.testing.expectEqual(@as(u8, 1), fee_view.harvest_to_mint_enabled);
    try std.testing.expectEqualSlices(u8, fee_payload[65..129], fee_view.withheld_amount[0..]);
    try expectWrongLengths(ConfidentialTransferFeeConfigView);

    var mint_burn_payload = [_]u8{0} ** ConfidentialMintBurnView.PAYLOAD_LEN;
    fillSequence(mint_burn_payload[0..64], 91);
    fillSequence(mint_burn_payload[64..100], 121);
    fillSequence(mint_burn_payload[100..132], 151);
    fillSequence(mint_burn_payload[132..196], 31);

    const mint_burn_view = try expectParsedView(ConfidentialMintBurnView, &mint_burn_payload);
    try std.testing.expectEqualSlices(u8, mint_burn_payload[0..64], mint_burn_view.confidential_supply[0..]);
    try std.testing.expectEqualSlices(u8, mint_burn_payload[64..100], mint_burn_view.decryptable_supply[0..]);
    try std.testing.expectEqualSlices(u8, mint_burn_payload[100..132], mint_burn_view.supply_elgamal_pubkey[0..]);
    try std.testing.expectEqualSlices(u8, mint_burn_payload[132..196], mint_burn_view.pending_burn[0..]);
    try expectWrongLengths(ConfidentialMintBurnView);
}

test "mint helpers look up canonical TLV records and return typed read-only views" {
    var mint = makeExtensionCapableMint();
    var fee_payload = [_]u8{0} ** TransferFeeConfigView.PAYLOAD_LEN;
    fillSequence(fee_payload[0..], 1);
    var confidential_payload = [_]u8{0} ** ConfidentialTransferMintView.PAYLOAD_LEN;
    fillSequence(confidential_payload[0..], 55);
    var metadata_payload = [_]u8{0} ** MetadataPointerView.PAYLOAD_LEN;
    fillSequence(metadata_payload[0..], 99);
    const marker_payload = [_]u8{};

    var off: usize = tlv.TLV_START_OFFSET;
    off += writeRecord(mint[off .. off + 4 + fee_payload.len], .transfer_fee_config, &fee_payload);
    off += writeRecord(mint[off .. off + 4 + confidential_payload.len], .confidential_transfer_mint, &confidential_payload);
    off += writeRecord(mint[off .. off + 4 + metadata_payload.len], .metadata_pointer, &metadata_payload);
    off += writeRecord(mint[off .. off + 4 + marker_payload.len], .non_transferable, marker_payload[0..]);

    const fee = try getTransferFeeConfig(mint[0..off]);
    try std.testing.expectEqualSlices(u8, fee_payload[0..], std.mem.asBytes(fee));

    const metadata = try getMetadataPointer(mint[0..off]);
    try std.testing.expectEqualSlices(u8, metadata_payload[0..], std.mem.asBytes(metadata));

    const confidential = try getConfidentialTransferMint(mint[0..off]);
    try std.testing.expectEqualSlices(u8, confidential_payload[0..], std.mem.asBytes(confidential));

    _ = try getNonTransferable(mint[0..off]);
}

fn makeExtensionCapableAccount() [512]u8 {
    var buf = [_]u8{0} ** 512;
    @memset(buf[0..tlv.ACCOUNT_BASE_LEN], 0xA5);
    buf[tlv.ACCOUNT_TYPE_OFFSET] = @intFromEnum(state.AccountType.account);
    return buf;
}

fn expectSupportRowForKind(
    actual: SupportRow,
    expected_account_type: state.AccountType,
    expected_name: []const u8,
    expected_type: ExtensionType,
    expected_len: usize,
    expected_fields: []const []const u8,
) !void {
    try std.testing.expectEqual(expected_account_type, actual.account_type);
    try std.testing.expectEqualStrings(expected_name, actual.name);
    try std.testing.expectEqual(expected_type, actual.extension_type);
    try std.testing.expectEqual(expected_len, actual.payload_len);
    try std.testing.expectEqual(expected_fields.len, actual.exposed_fields.len);
    for (expected_fields, actual.exposed_fields) |expected, got| {
        try std.testing.expectEqualStrings(expected, got);
    }
}

test "account support table rows lock canonical type ids, payload lengths, and raw field names" {
    try std.testing.expectEqual(@as(usize, 9), ACCOUNT_FIXED_LEN_SUPPORT.len);

    try expectSupportRowForKind(
        ACCOUNT_FIXED_LEN_SUPPORT[0],
        .account,
        "ConfidentialTransferAccount",
        .confidential_transfer_account,
        295,
        &.{
            "approved",
            "elgamal_pubkey",
            "pending_balance_lo",
            "pending_balance_hi",
            "available_balance",
            "decryptable_available_balance",
            "allow_confidential_credits",
            "allow_non_confidential_credits",
            "pending_balance_credit_counter",
            "maximum_pending_balance_credit_counter",
            "expected_pending_balance_credit_counter",
            "actual_pending_balance_credit_counter",
        },
    );
    try expectSupportRowForKind(
        ACCOUNT_FIXED_LEN_SUPPORT[1],
        .account,
        "TransferFeeAmount",
        .transfer_fee_amount,
        8,
        &.{"withheld_amount"},
    );
    try expectSupportRowForKind(
        ACCOUNT_FIXED_LEN_SUPPORT[2],
        .account,
        "ImmutableOwner",
        .immutable_owner,
        0,
        &.{},
    );
    try expectSupportRowForKind(
        ACCOUNT_FIXED_LEN_SUPPORT[3],
        .account,
        "MemoTransfer",
        .memo_transfer,
        1,
        &.{"require_incoming_transfer_memos"},
    );
    try expectSupportRowForKind(
        ACCOUNT_FIXED_LEN_SUPPORT[4],
        .account,
        "CpiGuard",
        .cpi_guard,
        1,
        &.{"lock_cpi"},
    );
    try expectSupportRowForKind(
        ACCOUNT_FIXED_LEN_SUPPORT[5],
        .account,
        "NonTransferableAccount",
        .non_transferable_account,
        0,
        &.{},
    );
    try expectSupportRowForKind(
        ACCOUNT_FIXED_LEN_SUPPORT[6],
        .account,
        "TransferHookAccount",
        .transfer_hook_account,
        1,
        &.{"transferring"},
    );
    try expectSupportRowForKind(
        ACCOUNT_FIXED_LEN_SUPPORT[7],
        .account,
        "PausableAccount",
        .pausable_account,
        0,
        &.{},
    );
    try expectSupportRowForKind(
        ACCOUNT_FIXED_LEN_SUPPORT[8],
        .account,
        "ConfidentialTransferFeeAmount",
        .confidential_transfer_fee_amount,
        64,
        &.{"withheld_amount"},
    );
}

test "account view payload lengths match canonical serialized sizes" {
    try std.testing.expectEqual(@as(usize, 295), ConfidentialTransferAccountView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 295), @sizeOf(ConfidentialTransferAccountView));
    try std.testing.expectEqual(@as(usize, 8), TransferFeeAmountView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(TransferFeeAmountView));
    try std.testing.expectEqual(@as(usize, 0), ImmutableOwnerView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 1), MemoTransferView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(MemoTransferView));
    try std.testing.expectEqual(@as(usize, 1), CpiGuardView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(CpiGuardView));
    try std.testing.expectEqual(@as(usize, 0), NonTransferableAccountView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 1), TransferHookAccountView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(TransferHookAccountView));
    try std.testing.expectEqual(@as(usize, 0), PausableAccountView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 64), ConfidentialTransferFeeAmountView.PAYLOAD_LEN);
    try std.testing.expectEqual(@as(usize, 64), @sizeOf(ConfidentialTransferFeeAmountView));
}

test "TransferFeeAmount account view exposes withheld amount" {
    var payload = [_]u8{0} ** TransferFeeAmountView.PAYLOAD_LEN;
    writeIntLe(u64, payload[0..8], 0x8877665544332211);

    const view = try expectParsedView(TransferFeeAmountView, &payload);
    try std.testing.expectEqual(@as(u64, 0x8877665544332211), view.withheld_amount);
    try expectWrongLengths(TransferFeeAmountView);
}

test "ImmutableOwner account marker accepts only empty payload" {
    const empty = [_]u8{};
    _ = try ImmutableOwnerView.fromBytes(empty[0..]);

    const wrong = [_]u8{1};
    try std.testing.expectError(error.InvalidExtensionLength, ImmutableOwnerView.fromBytes(wrong[0..]));
}

test "MemoTransfer account view exposes required memo flag" {
    inline for ([_]u8{ 0, 1, 0xFE }) |flag| {
        const payload = [_]u8{flag};
        const view = try expectParsedView(MemoTransferView, &payload);
        try std.testing.expectEqual(flag, view.require_incoming_transfer_memos);
    }
    try expectWrongLengths(MemoTransferView);
}

test "CpiGuard account view exposes CPI guard flag" {
    inline for ([_]u8{ 0, 1, 0x7F }) |flag| {
        const payload = [_]u8{flag};
        const view = try expectParsedView(CpiGuardView, &payload);
        try std.testing.expectEqual(flag, view.lock_cpi);
    }
    try expectWrongLengths(CpiGuardView);
}

test "NonTransferableAccount marker accepts only empty payload" {
    const empty = [_]u8{};
    _ = try NonTransferableAccountView.fromBytes(empty[0..]);

    const wrong = [_]u8{1};
    try std.testing.expectError(error.InvalidExtensionLength, NonTransferableAccountView.fromBytes(wrong[0..]));
}

test "TransferHookAccount account view exposes transferring flag" {
    inline for ([_]u8{ 0, 1, 0xA5 }) |flag| {
        const payload = [_]u8{flag};
        const view = try expectParsedView(TransferHookAccountView, &payload);
        try std.testing.expectEqual(flag, view.transferring);
    }
    try expectWrongLengths(TransferHookAccountView);
}

test "PausableAccount marker accepts only empty payload" {
    const empty = [_]u8{};
    _ = try PausableAccountView.fromBytes(empty[0..]);

    const wrong = [_]u8{1};
    try std.testing.expectError(error.InvalidExtensionLength, PausableAccountView.fromBytes(wrong[0..]));
}

test "confidential account views preserve raw POD ciphertext and counter fields" {
    var account_payload = [_]u8{0} ** ConfidentialTransferAccountView.PAYLOAD_LEN;
    account_payload[0] = 1;
    fillSequence(account_payload[1..33], 11);
    fillSequence(account_payload[33..97], 21);
    fillSequence(account_payload[97..161], 31);
    fillSequence(account_payload[161..225], 41);
    fillSequence(account_payload[225..261], 51);
    account_payload[261] = 1;
    account_payload[262] = 0;
    writeIntLe(u64, account_payload[263..271], 7);
    writeIntLe(u64, account_payload[271..279], 65_536);
    writeIntLe(u64, account_payload[279..287], 5);
    writeIntLe(u64, account_payload[287..295], 6);

    const account_view = try expectParsedView(ConfidentialTransferAccountView, &account_payload);
    try std.testing.expectEqual(@as(u8, 1), account_view.approved);
    try std.testing.expectEqualSlices(u8, account_payload[1..33], account_view.elgamal_pubkey[0..]);
    try std.testing.expectEqualSlices(u8, account_payload[33..97], account_view.pending_balance_lo[0..]);
    try std.testing.expectEqualSlices(u8, account_payload[97..161], account_view.pending_balance_hi[0..]);
    try std.testing.expectEqualSlices(u8, account_payload[161..225], account_view.available_balance[0..]);
    try std.testing.expectEqualSlices(u8, account_payload[225..261], account_view.decryptable_available_balance[0..]);
    try std.testing.expectEqual(@as(u8, 1), account_view.allow_confidential_credits);
    try std.testing.expectEqual(@as(u8, 0), account_view.allow_non_confidential_credits);
    try std.testing.expectEqualSlices(u8, account_payload[263..271], account_view.pending_balance_credit_counter[0..]);
    try std.testing.expectEqualSlices(u8, account_payload[271..279], account_view.maximum_pending_balance_credit_counter[0..]);
    try std.testing.expectEqualSlices(u8, account_payload[279..287], account_view.expected_pending_balance_credit_counter[0..]);
    try std.testing.expectEqualSlices(u8, account_payload[287..295], account_view.actual_pending_balance_credit_counter[0..]);
    try expectWrongLengths(ConfidentialTransferAccountView);

    var fee_payload = [_]u8{0} ** ConfidentialTransferFeeAmountView.PAYLOAD_LEN;
    fillSequence(fee_payload[0..], 222);
    const fee_view = try expectParsedView(ConfidentialTransferFeeAmountView, &fee_payload);
    try std.testing.expectEqualSlices(u8, fee_payload[0..], fee_view.withheld_amount[0..]);
    try expectWrongLengths(ConfidentialTransferFeeAmountView);
}

test "account helpers look up canonical TLV records and return typed read-only views" {
    var account = makeExtensionCapableAccount();
    var fee_payload = [_]u8{0} ** TransferFeeAmountView.PAYLOAD_LEN;
    writeIntLe(u64, fee_payload[0..8], 0x0102030405060708);
    var confidential_payload = [_]u8{0} ** ConfidentialTransferAccountView.PAYLOAD_LEN;
    fillSequence(confidential_payload[0..], 13);
    const immutable_payload = [_]u8{};
    const memo_payload = [_]u8{1};
    const hook_payload = [_]u8{0xCC};

    var off: usize = tlv.TLV_START_OFFSET;
    off += writeRecord(account[off .. off + 4 + fee_payload.len], .transfer_fee_amount, &fee_payload);
    off += writeRecord(account[off .. off + 4 + confidential_payload.len], .confidential_transfer_account, &confidential_payload);
    off += writeRecord(account[off .. off + 4 + immutable_payload.len], .immutable_owner, immutable_payload[0..]);
    off += writeRecord(account[off .. off + 4 + memo_payload.len], .memo_transfer, memo_payload[0..]);
    off += writeRecord(account[off .. off + 4 + hook_payload.len], .transfer_hook_account, hook_payload[0..]);

    const fee = try getTransferFeeAmount(account[0..off]);
    try std.testing.expectEqualSlices(u8, fee_payload[0..], std.mem.asBytes(fee));

    const confidential = try getConfidentialTransferAccount(account[0..off]);
    try std.testing.expectEqualSlices(u8, confidential_payload[0..], std.mem.asBytes(confidential));

    _ = try getImmutableOwner(account[0..off]);

    const memo = try getMemoTransfer(account[0..off]);
    try std.testing.expectEqual(@as(u8, 1), memo.require_incoming_transfer_memos);

    const hook = try getTransferHookAccount(account[0..off]);
    try std.testing.expectEqual(@as(u8, 0xCC), hook.transferring);
}

test "wrong-kind helper calls return deterministic mismatch results" {
    var mint = makeExtensionCapableMint();
    const memo_payload = [_]u8{1};
    var mint_off: usize = tlv.TLV_START_OFFSET;
    mint_off += writeRecord(mint[mint_off .. mint_off + 4 + memo_payload.len], .memo_transfer, memo_payload[0..]);

    try std.testing.expectError(
        error.WrongAccountType,
        getMintViewPayload(mint[0..mint_off], .transfer_fee_amount),
    );
    try std.testing.expectError(
        error.WrongAccountType,
        getAccountViewPayload(mint[0..mint_off], .memo_transfer),
    );

    var account = [_]u8{0} ** 512;
    account[tlv.ACCOUNT_TYPE_OFFSET] = @intFromEnum(state.AccountType.account);
    var fee_payload = [_]u8{0} ** TransferFeeConfigView.PAYLOAD_LEN;
    fillSequence(fee_payload[0..], 9);
    var account_off: usize = tlv.TLV_START_OFFSET;
    account_off += writeRecord(account[account_off .. account_off + 4 + fee_payload.len], .transfer_fee_config, &fee_payload);

    try std.testing.expectError(
        error.WrongAccountType,
        getAccountViewPayload(account[0..account_off], .transfer_fee_config),
    );
    try std.testing.expectError(
        error.WrongAccountType,
        getMintViewPayload(account[0..account_off], .transfer_fee_config),
    );
}

test "unsupported known out-of-scope extensions stay unparsed while scanner skipping still works" {
    try std.testing.expect(!@hasDecl(@This(), "TokenMetadataView"));
    try std.testing.expect(!@hasDecl(@This(), "TokenGroupView"));
    try std.testing.expect(!@hasDecl(@This(), "TokenGroupMemberView"));

    var mint = makeExtensionCapableMint();
    var mint_off: usize = tlv.TLV_START_OFFSET;
    inline for (KNOWN_UNSUPPORTED_FIXED_VIEW_TYPES, 0..) |extension_type, i| {
        const payload = [_]u8{@as(u8, @intCast(i))};
        mint_off += writeRecord(mint[mint_off .. mint_off + 4 + payload.len], extension_type, payload[0..]);
    }
    var hook_payload = [_]u8{0} ** TransferHookView.PAYLOAD_LEN;
    fillSequence(hook_payload[0..], 171);
    mint_off += writeRecord(mint[mint_off .. mint_off + 4 + hook_payload.len], .transfer_hook, &hook_payload);

    const mint_view = try getTransferHook(mint[0..mint_off]);
    try std.testing.expectEqualSlices(u8, hook_payload[0..], std.mem.asBytes(mint_view));
    inline for (KNOWN_UNSUPPORTED_FIXED_VIEW_TYPES) |extension_type| {
        try std.testing.expectError(
            error.UnsupportedExtension,
            getMintViewPayload(mint[0..mint_off], extension_type),
        );
    }

    var account = makeExtensionCapableAccount();
    var account_off: usize = tlv.TLV_START_OFFSET;
    inline for (KNOWN_UNSUPPORTED_FIXED_VIEW_TYPES, 0..) |extension_type, i| {
        const payload = [_]u8{@as(u8, @intCast(0xF0 + i))};
        account_off += writeRecord(account[account_off .. account_off + 4 + payload.len], extension_type, payload[0..]);
    }
    const memo_payload = [_]u8{1};
    account_off += writeRecord(account[account_off .. account_off + 4 + memo_payload.len], .memo_transfer, memo_payload[0..]);

    const memo_view = try getMemoTransfer(account[0..account_off]);
    try std.testing.expectEqual(@as(u8, 1), memo_view.require_incoming_transfer_memos);
    inline for (KNOWN_UNSUPPORTED_FIXED_VIEW_TYPES) |extension_type| {
        try std.testing.expectError(
            error.UnsupportedExtension,
            getAccountViewPayload(account[0..account_off], extension_type),
        );
    }
}

test {
    std.testing.refAllDecls(@This());
}
