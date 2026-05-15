//! Token-2022 base and selected extension instruction builders.
//!
//! These builders cover the shared SPL Token instruction subset that Token-2022
//! retains for ordinary mint/account flows plus selected extension instruction
//! families that benefit client-side transaction construction.

const std = @import("std");
const sol = @import("solana_program_sdk");
const id = @import("id.zig");
const state = @import("state.zig");
const extension = @import("extension.zig");

pub const Pubkey = sol.Pubkey;
pub const AccountMeta = sol.cpi.AccountMeta;
pub const Instruction = sol.cpi.Instruction;
pub const AccountState = state.AccountState;
pub const ExtensionType = extension.ExtensionType;

pub const Token2022Instruction = enum(u8) {
    initialize_mint = 0,
    initialize_account = 1,
    initialize_multisig = 2,
    transfer = 3,
    approve = 4,
    revoke = 5,
    set_authority = 6,
    mint_to = 7,
    burn = 8,
    close_account = 9,
    freeze_account = 10,
    thaw_account = 11,
    transfer_checked = 12,
    approve_checked = 13,
    mint_to_checked = 14,
    burn_checked = 15,
    initialize_account2 = 16,
    sync_native = 17,
    initialize_account3 = 18,
    initialize_multisig2 = 19,
    initialize_mint2 = 20,
    get_account_data_size = 21,
    initialize_immutable_owner = 22,
    amount_to_ui_amount = 23,
    ui_amount_to_amount = 24,
    initialize_mint_close_authority = 25,
    transfer_fee_extension = 26,
    confidential_transfer_extension = 27,
    default_account_state_extension = 28,
    reallocate = 29,
    memo_transfer_extension = 30,
    create_native_mint = 31,
    initialize_non_transferable_mint = 32,
    interest_bearing_mint_extension = 33,
    cpi_guard_extension = 34,
    initialize_permanent_delegate = 35,
    transfer_hook_extension = 36,
    confidential_transfer_fee_extension = 37,
    withdraw_excess_lamports = 38,
    metadata_pointer_extension = 39,
    group_pointer_extension = 40,
    group_member_pointer_extension = 41,
    scaled_ui_amount_extension = 43,
    pausable_extension = 44,
};

pub const AuthorityType = enum(u8) {
    mint_tokens = 0,
    freeze_account = 1,
    account_owner = 2,
    close_account = 3,
    transfer_fee_config = 4,
    withheld_withdraw = 5,
    close_mint = 6,
    interest_rate = 7,
    permanent_delegate = 8,
    confidential_transfer_mint = 9,
    transfer_hook_program_id = 10,
    confidential_transfer_fee_config = 11,
    metadata_pointer = 12,
    group_pointer = 13,
    group_member_pointer = 14,
    scaled_ui_amount = 15,
    pause = 16,
};

pub const TransferFeeInstruction = enum(u8) {
    initialize_transfer_fee_config = 0,
    transfer_checked_with_fee = 1,
    withdraw_withheld_tokens_from_mint = 2,
    withdraw_withheld_tokens_from_accounts = 3,
    harvest_withheld_tokens_to_mint = 4,
    set_transfer_fee = 5,
};

pub const ConfidentialTransferInstruction = enum(u8) {
    initialize_mint = 0,
    update_mint = 1,
    configure_account = 2,
    approve_account = 3,
    empty_account = 4,
    deposit = 5,
    withdraw = 6,
    transfer = 7,
    apply_pending_balance = 8,
    enable_confidential_credits = 9,
    disable_confidential_credits = 10,
    enable_non_confidential_credits = 11,
    disable_non_confidential_credits = 12,
    transfer_with_fee = 13,
    configure_account_with_registry = 14,
};

pub const ConfidentialTransferFeeInstruction = enum(u8) {
    initialize_confidential_transfer_fee_config = 0,
    withdraw_withheld_tokens_from_mint = 1,
    withdraw_withheld_tokens_from_accounts = 2,
    harvest_withheld_tokens_to_mint = 3,
    enable_harvest_to_mint = 4,
    disable_harvest_to_mint = 5,
};

pub const DefaultAccountStateInstruction = enum(u8) {
    initialize = 0,
    update = 1,
};

pub const RequiredMemoTransfersInstruction = enum(u8) {
    enable = 0,
    disable = 1,
};

pub const CpiGuardInstruction = enum(u8) {
    enable = 0,
    disable = 1,
};

pub const InterestBearingMintInstruction = enum(u8) {
    initialize = 0,
    update_rate = 1,
};

pub const PausableInstruction = enum(u8) {
    initialize = 0,
    pause_pausable = 1,
    resume_pausable = 2,
};

pub const PointerInstruction = enum(u8) {
    initialize = 0,
    update = 1,
};

pub const MetadataPointerInstruction = PointerInstruction;
pub const GroupPointerInstruction = PointerInstruction;
pub const GroupMemberPointerInstruction = PointerInstruction;
pub const TransferHookInstruction = PointerInstruction;

pub const ScaledUiAmountInstruction = enum(u8) {
    initialize = 0,
    update_multiplier = 1,
};

pub const ExtensionInstructionError = error{
    OutputTooSmall,
    TooManyAccounts,
    InvalidMultisigSignerCount,
    InvalidMultisigThreshold,
};

pub const ConfidentialProofLocation = union(enum) {
    instruction_offset: i8,
    context_state_account: *const Pubkey,
};

pub const TransferFeeInstructionError = ExtensionInstructionError;
pub const MultisigInstructionError = ExtensionInstructionError;

pub const MIN_SIGNERS: usize = 1;
pub const MAX_SIGNERS: usize = 11;

pub const Spec = struct {
    disc: Token2022Instruction,
    accounts_len: usize,
    data_len: usize,
};

pub const initialize_mint_none_data_len: usize = 1 + 1 + 32 + 1;
pub const initialize_mint_some_data_len: usize = initialize_mint_none_data_len + 32;
pub const initialize_mint_spec: Spec = .{ .disc = .initialize_mint, .accounts_len = 2, .data_len = initialize_mint_some_data_len };
pub const initialize_account_spec: Spec = .{ .disc = .initialize_account, .accounts_len = 4, .data_len = 1 };
pub const initialize_multisig_spec: Spec = .{ .disc = .initialize_multisig, .accounts_len = 2, .data_len = 1 + 1 };
pub const transfer_spec: Spec = .{ .disc = .transfer, .accounts_len = 3, .data_len = 1 + 8 };
pub const approve_spec: Spec = .{ .disc = .approve, .accounts_len = 3, .data_len = 1 + 8 };
pub const revoke_spec: Spec = .{ .disc = .revoke, .accounts_len = 2, .data_len = 1 };
pub const set_authority_none_data_len: usize = 1 + 1 + 1;
pub const set_authority_some_data_len: usize = 1 + 1 + 33;
pub const set_authority_spec: Spec = .{ .disc = .set_authority, .accounts_len = 2, .data_len = set_authority_some_data_len };
pub const mint_to_spec: Spec = .{ .disc = .mint_to, .accounts_len = 3, .data_len = 1 + 8 };
pub const burn_spec: Spec = .{ .disc = .burn, .accounts_len = 3, .data_len = 1 + 8 };
pub const close_account_spec: Spec = .{ .disc = .close_account, .accounts_len = 3, .data_len = 1 };
pub const freeze_account_spec: Spec = .{ .disc = .freeze_account, .accounts_len = 3, .data_len = 1 };
pub const thaw_account_spec: Spec = .{ .disc = .thaw_account, .accounts_len = 3, .data_len = 1 };
pub const transfer_checked_spec: Spec = .{ .disc = .transfer_checked, .accounts_len = 4, .data_len = 1 + 8 + 1 };
pub const approve_checked_spec: Spec = .{ .disc = .approve_checked, .accounts_len = 4, .data_len = 1 + 8 + 1 };
pub const mint_to_checked_spec: Spec = .{ .disc = .mint_to_checked, .accounts_len = 3, .data_len = 1 + 8 + 1 };
pub const burn_checked_spec: Spec = .{ .disc = .burn_checked, .accounts_len = 3, .data_len = 1 + 8 + 1 };
pub const initialize_account2_spec: Spec = .{ .disc = .initialize_account2, .accounts_len = 3, .data_len = 1 + 32 };
pub const sync_native_spec: Spec = .{ .disc = .sync_native, .accounts_len = 1, .data_len = 1 };
pub const initialize_account3_spec: Spec = .{ .disc = .initialize_account3, .accounts_len = 2, .data_len = 1 + 32 };
pub const initialize_multisig2_spec: Spec = .{ .disc = .initialize_multisig2, .accounts_len = 1, .data_len = 1 + 1 };
pub const initialize_mint2_none_data_len: usize = 1 + 1 + 32 + 1;
pub const initialize_mint2_some_data_len: usize = initialize_mint2_none_data_len + 32;
pub const initialize_mint2_spec: Spec = .{ .disc = .initialize_mint2, .accounts_len = 1, .data_len = initialize_mint2_some_data_len };
pub const get_account_data_size_spec: Spec = .{ .disc = .get_account_data_size, .accounts_len = 1, .data_len = 1 };
pub const initialize_immutable_owner_spec: Spec = .{ .disc = .initialize_immutable_owner, .accounts_len = 1, .data_len = 1 };
pub const amount_to_ui_amount_spec: Spec = .{ .disc = .amount_to_ui_amount, .accounts_len = 1, .data_len = 1 + 8 };
pub const ui_amount_to_amount_prefix_len: usize = 1;
pub const initialize_mint_close_authority_none_data_len: usize = 1 + 1;
pub const initialize_mint_close_authority_some_data_len: usize = 1 + 33;
pub const initialize_mint_close_authority_spec: Spec = .{ .disc = .initialize_mint_close_authority, .accounts_len = 1, .data_len = initialize_mint_close_authority_some_data_len };
pub const transfer_fee_prefix_len: usize = 2;
pub const transfer_fee_initialize_config_none_data_len: usize = transfer_fee_prefix_len + 1 + 1 + 2 + 8;
pub const transfer_fee_initialize_config_some_data_len: usize = transfer_fee_prefix_len + 33 + 33 + 2 + 8;
pub const transfer_fee_transfer_checked_with_fee_data_len: usize = transfer_fee_prefix_len + 8 + 1 + 8;
pub const transfer_fee_withdraw_withheld_tokens_from_mint_data_len: usize = transfer_fee_prefix_len;
pub const transfer_fee_withdraw_withheld_tokens_from_accounts_data_len: usize = transfer_fee_prefix_len + 1;
pub const transfer_fee_harvest_withheld_tokens_to_mint_data_len: usize = transfer_fee_prefix_len;
pub const transfer_fee_set_transfer_fee_data_len: usize = transfer_fee_prefix_len + 2 + 8;
pub const confidential_transfer_prefix_len: usize = 2;
pub const confidential_transfer_initialize_mint_data_len: usize = confidential_transfer_prefix_len + 32 + 1 + 32;
pub const confidential_transfer_update_mint_data_len: usize = confidential_transfer_prefix_len + 1 + 32;
pub const confidential_transfer_configure_account_data_len: usize = confidential_transfer_prefix_len + 36 + 8 + 1;
pub const confidential_transfer_approve_account_data_len: usize = confidential_transfer_prefix_len;
pub const confidential_transfer_empty_account_data_len: usize = confidential_transfer_prefix_len + 1;
pub const confidential_transfer_deposit_data_len: usize = confidential_transfer_prefix_len + 8 + 1;
pub const confidential_transfer_withdraw_data_len: usize = confidential_transfer_prefix_len + 8 + 1 + 36 + 1 + 1;
pub const confidential_transfer_transfer_data_len: usize = confidential_transfer_prefix_len + 36 + 64 + 64 + 1 + 1 + 1;
pub const confidential_transfer_transfer_with_fee_data_len: usize = confidential_transfer_prefix_len + 36 + 64 + 64 + 1 + 1 + 1 + 1 + 1;
pub const confidential_transfer_apply_pending_balance_data_len: usize = confidential_transfer_prefix_len + 8 + 36;
pub const confidential_transfer_toggle_credits_data_len: usize = confidential_transfer_prefix_len;
pub const confidential_transfer_configure_account_with_registry_data_len: usize = confidential_transfer_prefix_len;
pub const confidential_transfer_fee_prefix_len: usize = 2;
pub const confidential_transfer_fee_initialize_config_data_len: usize = confidential_transfer_fee_prefix_len + 32 + 32;
pub const confidential_transfer_fee_withdraw_withheld_tokens_from_mint_data_len: usize = confidential_transfer_fee_prefix_len + 1 + 36;
pub const confidential_transfer_fee_withdraw_withheld_tokens_from_accounts_data_len: usize = confidential_transfer_fee_prefix_len + 1 + 1 + 36;
pub const confidential_transfer_fee_harvest_withheld_tokens_to_mint_data_len: usize = confidential_transfer_fee_prefix_len;
pub const confidential_transfer_fee_toggle_harvest_to_mint_data_len: usize = confidential_transfer_fee_prefix_len;
pub const default_account_state_data_len: usize = 3;
pub const reallocate_prefix_len: usize = 1;
pub const memo_transfer_data_len: usize = 2;
pub const create_native_mint_spec: Spec = .{ .disc = .create_native_mint, .accounts_len = 3, .data_len = 1 };
pub const initialize_non_transferable_mint_spec: Spec = .{ .disc = .initialize_non_transferable_mint, .accounts_len = 1, .data_len = 1 };
pub const cpi_guard_data_len: usize = 2;
pub const interest_bearing_initialize_data_len: usize = 2 + 32 + 2;
pub const interest_bearing_update_rate_data_len: usize = 2 + 2;
pub const initialize_permanent_delegate_data_len: usize = 1 + 32;
pub const withdraw_excess_lamports_data_len: usize = 1;
pub const pointer_initialize_data_len: usize = 2 + 32 + 32;
pub const pointer_update_data_len: usize = 2 + 32;
pub const transfer_hook_initialize_data_len: usize = pointer_initialize_data_len;
pub const transfer_hook_update_data_len: usize = pointer_update_data_len;
pub const scaled_ui_amount_initialize_data_len: usize = 2 + 32 + 8;
pub const scaled_ui_amount_update_multiplier_data_len: usize = 2 + 8 + 8;
pub const pausable_initialize_data_len: usize = 2 + 32;
pub const pausable_toggle_data_len: usize = 2;

pub fn metasArray(comptime spec: Spec) type {
    return [spec.accounts_len]AccountMeta;
}

pub fn dataArray(comptime spec: Spec) type {
    return [spec.data_len]u8;
}

pub fn multisigMetasArray(comptime base_accounts_len: usize) type {
    return [base_accounts_len + MAX_SIGNERS]AccountMeta;
}

pub fn initializeMultisigAccountsLen(signers: []const Pubkey, base_accounts_len: usize) ?usize {
    return std.math.add(usize, base_accounts_len, signers.len) catch null;
}

pub fn getAccountDataSizeLen(extension_types: []const ExtensionType) ?usize {
    const extension_bytes = std.math.mul(usize, extension_types.len, 2) catch return null;
    return std.math.add(usize, get_account_data_size_spec.data_len, extension_bytes) catch null;
}

pub fn uiAmountToAmountLen(ui_amount: []const u8) ?usize {
    return std.math.add(usize, ui_amount_to_amount_prefix_len, ui_amount.len) catch null;
}

pub fn transferFeeInitializeConfigLen(
    transfer_fee_config_authority: ?*const Pubkey,
    withdraw_withheld_authority: ?*const Pubkey,
) usize {
    var len: usize = transfer_fee_prefix_len + 2 + 8;
    len += if (transfer_fee_config_authority == null) 1 else 33;
    len += if (withdraw_withheld_authority == null) 1 else 33;
    return len;
}

pub fn transferFeeAuthorityAccountsLen(signers: []const Pubkey, base_accounts_len: usize) ?usize {
    return std.math.add(usize, base_accounts_len, signers.len) catch null;
}

pub fn transferFeeWithdrawFromAccountsLen(signers: []const Pubkey, sources: []const Pubkey) ?usize {
    if (sources.len > std.math.maxInt(u8)) return null;
    const with_signers = std.math.add(usize, 3, signers.len) catch return null;
    return std.math.add(usize, with_signers, sources.len) catch null;
}

pub fn confidentialTransferFeeWithdrawFromAccountsLen(signers: []const Pubkey, sources: []const Pubkey) ?usize {
    if (sources.len > std.math.maxInt(u8)) return null;
    const with_signers = std.math.add(usize, 4, signers.len) catch return null;
    return std.math.add(usize, with_signers, sources.len) catch null;
}

pub fn transferFeeHarvestAccountsLen(sources: []const Pubkey) ?usize {
    return std.math.add(usize, 1, sources.len) catch null;
}

pub fn reallocateAccountsLen(signers: []const Pubkey) ?usize {
    return std.math.add(usize, 4, signers.len) catch null;
}

pub fn reallocateDataLen(extension_types: []const ExtensionType) ?usize {
    const extension_bytes = std.math.mul(usize, extension_types.len, 2) catch return null;
    return std.math.add(usize, reallocate_prefix_len, extension_bytes) catch null;
}

pub fn extensionAuthorityAccountsLen(signers: []const Pubkey, base_accounts_len: usize) ?usize {
    return transferFeeAuthorityAccountsLen(signers, base_accounts_len);
}

pub fn confidentialTransferWithdrawAccountsLen(
    signers: []const Pubkey,
    equality_proof_location: ConfidentialProofLocation,
    range_proof_location: ConfidentialProofLocation,
) ?usize {
    var len: usize = 3;
    if (proofLocationUsesInstructionOffset(equality_proof_location) or
        proofLocationUsesInstructionOffset(range_proof_location))
    {
        len += 1;
    }
    if (!proofLocationUsesInstructionOffset(equality_proof_location)) len += 1;
    if (!proofLocationUsesInstructionOffset(range_proof_location)) len += 1;
    return std.math.add(usize, len, signers.len) catch null;
}

pub fn confidentialTransferProofAccountsLen(
    signers: []const Pubkey,
    fixed_accounts_len: usize,
    proof_locations: []const ConfidentialProofLocation,
) ?usize {
    var len = std.math.add(usize, fixed_accounts_len, 1) catch return null;
    len = std.math.add(usize, len, signers.len) catch return null;
    if (proofLocationsUseInstructionOffset(proof_locations)) len += 1;
    for (proof_locations) |proof_location| {
        if (!proofLocationUsesInstructionOffset(proof_location)) len += 1;
    }
    return len;
}

pub fn confidentialTransferConfigureAccountWithRegistryAccountsLen(payer: ?*const Pubkey) usize {
    return if (payer == null) 3 else 5;
}

pub fn initializeMint(
    mint: *const Pubkey,
    decimals: u8,
    mint_authority: *const Pubkey,
    freeze_authority: ?*const Pubkey,
    metas: *metasArray(initialize_mint_spec),
    data: *dataArray(initialize_mint_spec),
) Instruction {
    data[0] = @intFromEnum(Token2022Instruction.initialize_mint);
    data[1] = decimals;
    @memcpy(data[2..34], mint_authority);
    const freeze_authority_len = writeOptionalPubkey(data[34..67], freeze_authority);
    metas[0] = AccountMeta.writable(mint);
    metas[1] = AccountMeta.readonly(&sol.rent_id);
    return ixSlice(metas, data[0 .. 34 + freeze_authority_len]);
}

pub fn initializeAccount(
    account: *const Pubkey,
    mint: *const Pubkey,
    owner: *const Pubkey,
    metas: *metasArray(initialize_account_spec),
    data: *dataArray(initialize_account_spec),
) Instruction {
    data[0] = @intFromEnum(Token2022Instruction.initialize_account);
    metas[0] = AccountMeta.writable(account);
    metas[1] = AccountMeta.readonly(mint);
    metas[2] = AccountMeta.readonly(owner);
    metas[3] = AccountMeta.readonly(&sol.rent_id);
    return ix(metas, data);
}

pub fn initializeMultisig(
    multisig: *const Pubkey,
    signers: []const Pubkey,
    threshold: u8,
    metas: *multisigMetasArray(initialize_multisig_spec.accounts_len),
    data: *dataArray(initialize_multisig_spec),
) MultisigInstructionError!Instruction {
    try validateMultisigThreshold(threshold, signers);
    data[0] = @intFromEnum(Token2022Instruction.initialize_multisig);
    data[1] = threshold;
    metas[0] = AccountMeta.writable(multisig);
    metas[1] = AccountMeta.readonly(&sol.rent_id);
    const accounts = try appendReadonlyMetas(metas, 2, signers);
    return ixSlice(accounts, data);
}

pub fn transfer(
    source: *const Pubkey,
    destination: *const Pubkey,
    authority: *const Pubkey,
    amount: u64,
    metas: *metasArray(transfer_spec),
    data: *dataArray(transfer_spec),
) Instruction {
    writeAmountData(data, .transfer, amount);
    metas[0] = AccountMeta.writable(source);
    metas[1] = AccountMeta.writable(destination);
    metas[2] = AccountMeta.signer(authority);
    return ix(metas, data);
}

pub fn approve(
    source: *const Pubkey,
    delegate: *const Pubkey,
    authority: *const Pubkey,
    amount: u64,
    metas: *metasArray(approve_spec),
    data: *dataArray(approve_spec),
) Instruction {
    writeAmountData(data, .approve, amount);
    metas[0] = AccountMeta.writable(source);
    metas[1] = AccountMeta.readonly(delegate);
    metas[2] = AccountMeta.signer(authority);
    return ix(metas, data);
}

pub fn revoke(
    source: *const Pubkey,
    owner: *const Pubkey,
    signers: []const Pubkey,
    metas: []AccountMeta,
    data: *dataArray(revoke_spec),
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillExtensionAuthorityMetas(
        metas,
        revoke_spec.accounts_len,
        owner,
        signers,
        .{AccountMeta.writable(source)},
    );
    data[0] = @intFromEnum(Token2022Instruction.revoke);
    return ixSlice(metas[0..accounts_len], data);
}

pub fn setAuthority(
    owned: *const Pubkey,
    current_authority: *const Pubkey,
    signers: []const Pubkey,
    authority_type: AuthorityType,
    new_authority: ?*const Pubkey,
    metas: []AccountMeta,
    data: *dataArray(set_authority_spec),
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillExtensionAuthorityMetas(
        metas,
        set_authority_spec.accounts_len,
        current_authority,
        signers,
        .{AccountMeta.writable(owned)},
    );
    data[0] = @intFromEnum(Token2022Instruction.set_authority);
    data[1] = @intFromEnum(authority_type);
    const authority_len = writeOptionalPubkey(data[2..35], new_authority);
    return ixSlice(metas[0..accounts_len], data[0 .. 2 + authority_len]);
}

pub fn mintTo(
    mint: *const Pubkey,
    destination: *const Pubkey,
    authority: *const Pubkey,
    amount: u64,
    metas: *metasArray(mint_to_spec),
    data: *dataArray(mint_to_spec),
) Instruction {
    writeAmountData(data, .mint_to, amount);
    metas[0] = AccountMeta.writable(mint);
    metas[1] = AccountMeta.writable(destination);
    metas[2] = AccountMeta.signer(authority);
    return ix(metas, data);
}

pub fn burn(
    source: *const Pubkey,
    mint: *const Pubkey,
    authority: *const Pubkey,
    amount: u64,
    metas: *metasArray(burn_spec),
    data: *dataArray(burn_spec),
) Instruction {
    writeAmountData(data, .burn, amount);
    metas[0] = AccountMeta.writable(source);
    metas[1] = AccountMeta.writable(mint);
    metas[2] = AccountMeta.signer(authority);
    return ix(metas, data);
}

pub fn closeAccount(
    account: *const Pubkey,
    destination: *const Pubkey,
    authority: *const Pubkey,
    metas: *metasArray(close_account_spec),
    data: *dataArray(close_account_spec),
) Instruction {
    data[0] = @intFromEnum(Token2022Instruction.close_account);
    metas[0] = AccountMeta.writable(account);
    metas[1] = AccountMeta.writable(destination);
    metas[2] = AccountMeta.signer(authority);
    return ix(metas, data);
}

pub fn syncNative(
    account: *const Pubkey,
    metas: *metasArray(sync_native_spec),
    data: *dataArray(sync_native_spec),
) Instruction {
    data[0] = @intFromEnum(Token2022Instruction.sync_native);
    metas[0] = AccountMeta.writable(account);
    return ix(metas, data);
}

pub fn initializeAccount2(
    account: *const Pubkey,
    mint: *const Pubkey,
    owner: *const Pubkey,
    metas: *metasArray(initialize_account2_spec),
    data: *dataArray(initialize_account2_spec),
) Instruction {
    data[0] = @intFromEnum(Token2022Instruction.initialize_account2);
    @memcpy(data[1..33], owner);
    metas[0] = AccountMeta.writable(account);
    metas[1] = AccountMeta.readonly(mint);
    metas[2] = AccountMeta.readonly(&sol.rent_id);
    return ix(metas, data);
}

pub fn freezeAccount(
    account: *const Pubkey,
    mint: *const Pubkey,
    freeze_authority: *const Pubkey,
    signers: []const Pubkey,
    metas: []AccountMeta,
    data: *dataArray(freeze_account_spec),
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillExtensionAuthorityMetas(
        metas,
        freeze_account_spec.accounts_len,
        freeze_authority,
        signers,
        .{
            AccountMeta.writable(account),
            AccountMeta.readonly(mint),
        },
    );
    data[0] = @intFromEnum(Token2022Instruction.freeze_account);
    return ixSlice(metas[0..accounts_len], data);
}

pub fn thawAccount(
    account: *const Pubkey,
    mint: *const Pubkey,
    freeze_authority: *const Pubkey,
    signers: []const Pubkey,
    metas: []AccountMeta,
    data: *dataArray(thaw_account_spec),
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillExtensionAuthorityMetas(
        metas,
        thaw_account_spec.accounts_len,
        freeze_authority,
        signers,
        .{
            AccountMeta.writable(account),
            AccountMeta.readonly(mint),
        },
    );
    data[0] = @intFromEnum(Token2022Instruction.thaw_account);
    return ixSlice(metas[0..accounts_len], data);
}

pub fn transferChecked(
    source: *const Pubkey,
    mint: *const Pubkey,
    destination: *const Pubkey,
    authority: *const Pubkey,
    amount: u64,
    decimals: u8,
    metas: *metasArray(transfer_checked_spec),
    data: *dataArray(transfer_checked_spec),
) Instruction {
    writeAmountDecimalsData(data, .transfer_checked, amount, decimals);
    metas[0] = AccountMeta.writable(source);
    metas[1] = AccountMeta.readonly(mint);
    metas[2] = AccountMeta.writable(destination);
    metas[3] = AccountMeta.signer(authority);
    return ix(metas, data);
}

pub fn approveChecked(
    source: *const Pubkey,
    mint: *const Pubkey,
    delegate: *const Pubkey,
    authority: *const Pubkey,
    amount: u64,
    decimals: u8,
    metas: *metasArray(approve_checked_spec),
    data: *dataArray(approve_checked_spec),
) Instruction {
    writeAmountDecimalsData(data, .approve_checked, amount, decimals);
    metas[0] = AccountMeta.writable(source);
    metas[1] = AccountMeta.readonly(mint);
    metas[2] = AccountMeta.readonly(delegate);
    metas[3] = AccountMeta.signer(authority);
    return ix(metas, data);
}

pub fn mintToChecked(
    mint: *const Pubkey,
    destination: *const Pubkey,
    authority: *const Pubkey,
    amount: u64,
    decimals: u8,
    metas: *metasArray(mint_to_checked_spec),
    data: *dataArray(mint_to_checked_spec),
) Instruction {
    writeAmountDecimalsData(data, .mint_to_checked, amount, decimals);
    metas[0] = AccountMeta.writable(mint);
    metas[1] = AccountMeta.writable(destination);
    metas[2] = AccountMeta.signer(authority);
    return ix(metas, data);
}

pub fn burnChecked(
    source: *const Pubkey,
    mint: *const Pubkey,
    authority: *const Pubkey,
    amount: u64,
    decimals: u8,
    metas: *metasArray(burn_checked_spec),
    data: *dataArray(burn_checked_spec),
) Instruction {
    writeAmountDecimalsData(data, .burn_checked, amount, decimals);
    metas[0] = AccountMeta.writable(source);
    metas[1] = AccountMeta.writable(mint);
    metas[2] = AccountMeta.signer(authority);
    return ix(metas, data);
}

pub fn initializeAccount3(
    account: *const Pubkey,
    mint: *const Pubkey,
    owner: *const Pubkey,
    metas: *metasArray(initialize_account3_spec),
    data: *dataArray(initialize_account3_spec),
) Instruction {
    data[0] = @intFromEnum(Token2022Instruction.initialize_account3);
    @memcpy(data[1..33], owner);
    metas[0] = AccountMeta.writable(account);
    metas[1] = AccountMeta.readonly(mint);
    return ix(metas, data);
}

pub fn initializeMultisig2(
    multisig: *const Pubkey,
    signers: []const Pubkey,
    threshold: u8,
    metas: *multisigMetasArray(initialize_multisig2_spec.accounts_len),
    data: *dataArray(initialize_multisig2_spec),
) MultisigInstructionError!Instruction {
    try validateMultisigThreshold(threshold, signers);
    data[0] = @intFromEnum(Token2022Instruction.initialize_multisig2);
    data[1] = threshold;
    metas[0] = AccountMeta.writable(multisig);
    const accounts = try appendReadonlyMetas(metas, 1, signers);
    return ixSlice(accounts, data);
}

pub fn initializeMint2(
    mint: *const Pubkey,
    decimals: u8,
    mint_authority: *const Pubkey,
    freeze_authority: ?*const Pubkey,
    metas: *metasArray(initialize_mint2_spec),
    data: *dataArray(initialize_mint2_spec),
) Instruction {
    data[0] = @intFromEnum(Token2022Instruction.initialize_mint2);
    data[1] = decimals;
    @memcpy(data[2..34], mint_authority);
    const data_len = 34 + writeOptionalPubkey(data[34..], freeze_authority);
    metas[0] = AccountMeta.writable(mint);
    return .{
        .program_id = &id.PROGRAM_ID,
        .accounts = metas,
        .data = data[0..data_len],
    };
}

pub fn getAccountDataSize(
    mint: *const Pubkey,
    metas: *metasArray(get_account_data_size_spec),
    data: *dataArray(get_account_data_size_spec),
) Instruction {
    data[0] = @intFromEnum(Token2022Instruction.get_account_data_size);
    metas[0] = AccountMeta.readonly(mint);
    return ix(metas, data);
}

pub fn getAccountDataSizeForExtensions(
    mint: *const Pubkey,
    extension_types: []const ExtensionType,
    metas: *metasArray(get_account_data_size_spec),
    data: []u8,
) ExtensionInstructionError!Instruction {
    const data_len = getAccountDataSizeLen(extension_types) orelse return error.TooManyAccounts;
    if (data.len < data_len) return error.OutputTooSmall;
    data[0] = @intFromEnum(Token2022Instruction.get_account_data_size);
    for (extension_types, 0..) |extension_type, i| {
        const offset = 1 + i * 2;
        std.mem.writeInt(u16, data[offset..][0..2], @intFromEnum(extension_type), .little);
    }
    metas[0] = AccountMeta.readonly(mint);
    return ixSlice(metas, data[0..data_len]);
}

pub fn initializeImmutableOwner(
    account: *const Pubkey,
    metas: *metasArray(initialize_immutable_owner_spec),
    data: *dataArray(initialize_immutable_owner_spec),
) Instruction {
    data[0] = @intFromEnum(Token2022Instruction.initialize_immutable_owner);
    metas[0] = AccountMeta.writable(account);
    return ix(metas, data);
}

pub fn amountToUiAmount(
    mint: *const Pubkey,
    amount: u64,
    metas: *metasArray(amount_to_ui_amount_spec),
    data: *dataArray(amount_to_ui_amount_spec),
) Instruction {
    writeAmountData(data, .amount_to_ui_amount, amount);
    metas[0] = AccountMeta.readonly(mint);
    return ix(metas, data);
}

pub fn uiAmountToAmount(
    mint: *const Pubkey,
    ui_amount: []const u8,
    metas: *metasArray(get_account_data_size_spec),
    data: []u8,
) error{OutputTooSmall}!Instruction {
    const data_len = uiAmountToAmountLen(ui_amount) orelse return error.OutputTooSmall;
    if (data.len < data_len) return error.OutputTooSmall;
    data[0] = @intFromEnum(Token2022Instruction.ui_amount_to_amount);
    @memcpy(data[1..data_len], ui_amount);
    metas[0] = AccountMeta.readonly(mint);
    return .{
        .program_id = &id.PROGRAM_ID,
        .accounts = metas,
        .data = data[0..data_len],
    };
}

pub fn initializeMintCloseAuthority(
    mint: *const Pubkey,
    close_authority: ?*const Pubkey,
    metas: *metasArray(initialize_mint_close_authority_spec),
    data: *dataArray(initialize_mint_close_authority_spec),
) Instruction {
    data[0] = @intFromEnum(Token2022Instruction.initialize_mint_close_authority);
    const close_authority_len = writeOptionalPubkey(data[1..34], close_authority);
    metas[0] = AccountMeta.writable(mint);
    return ixSlice(metas, data[0 .. 1 + close_authority_len]);
}

pub fn initializeTransferFeeConfig(
    mint: *const Pubkey,
    transfer_fee_config_authority: ?*const Pubkey,
    withdraw_withheld_authority: ?*const Pubkey,
    transfer_fee_basis_points: u16,
    maximum_fee: u64,
    metas: *metasArray(get_account_data_size_spec),
    data: []u8,
) ExtensionInstructionError!Instruction {
    const data_len = transferFeeInitializeConfigLen(
        transfer_fee_config_authority,
        withdraw_withheld_authority,
    );
    if (data.len < data_len) return error.OutputTooSmall;

    writeTransferFeePrefix(data, .initialize_transfer_fee_config);
    var offset: usize = transfer_fee_prefix_len;
    offset += writeOptionalPubkey(data[offset..], transfer_fee_config_authority);
    offset += writeOptionalPubkey(data[offset..], withdraw_withheld_authority);
    std.mem.writeInt(u16, data[offset..][0..2], transfer_fee_basis_points, .little);
    offset += 2;
    std.mem.writeInt(u64, data[offset..][0..8], maximum_fee, .little);
    offset += 8;

    metas[0] = AccountMeta.writable(mint);
    return ixSlice(metas, data[0..offset]);
}

pub fn transferCheckedWithFee(
    source: *const Pubkey,
    mint: *const Pubkey,
    destination: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    amount: u64,
    decimals: u8,
    fee: u64,
    metas: []AccountMeta,
    data: *[transfer_fee_transfer_checked_with_fee_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillTransferFeeAuthorityMetas(
        metas,
        4,
        authority,
        signers,
        .{
            AccountMeta.writable(source),
            AccountMeta.readonly(mint),
            AccountMeta.writable(destination),
        },
    );
    writeTransferFeeAmountDecimalsFeeData(data, .transfer_checked_with_fee, amount, decimals, fee);
    return ixSlice(metas[0..accounts_len], data);
}

pub fn withdrawWithheldTokensFromMint(
    mint: *const Pubkey,
    destination: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    metas: []AccountMeta,
    data: *[transfer_fee_withdraw_withheld_tokens_from_mint_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillTransferFeeAuthorityMetas(
        metas,
        3,
        authority,
        signers,
        .{
            AccountMeta.writable(mint),
            AccountMeta.writable(destination),
        },
    );
    writeTransferFeePrefix(data, .withdraw_withheld_tokens_from_mint);
    return ixSlice(metas[0..accounts_len], data);
}

pub fn withdrawWithheldTokensFromAccounts(
    mint: *const Pubkey,
    destination: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    sources: []const Pubkey,
    metas: []AccountMeta,
    data: *[transfer_fee_withdraw_withheld_tokens_from_accounts_data_len]u8,
) ExtensionInstructionError!Instruction {
    if (sources.len > std.math.maxInt(u8)) return error.TooManyAccounts;
    var offset = try fillTransferFeeAuthorityMetas(
        metas,
        3,
        authority,
        signers,
        .{
            AccountMeta.readonly(mint),
            AccountMeta.writable(destination),
        },
    );
    if (metas.len < offset + sources.len) return error.OutputTooSmall;
    for (sources, 0..) |_, i| {
        metas[offset + i] = AccountMeta.writable(&sources[i]);
    }
    offset += sources.len;

    writeTransferFeePrefix(data, .withdraw_withheld_tokens_from_accounts);
    data[2] = @intCast(sources.len);
    return ixSlice(metas[0..offset], data);
}

pub fn harvestWithheldTokensToMint(
    mint: *const Pubkey,
    sources: []const Pubkey,
    metas: []AccountMeta,
    data: *[transfer_fee_harvest_withheld_tokens_to_mint_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = transferFeeHarvestAccountsLen(sources) orelse return error.TooManyAccounts;
    if (metas.len < accounts_len) return error.OutputTooSmall;
    metas[0] = AccountMeta.writable(mint);
    for (sources, 0..) |_, i| {
        metas[1 + i] = AccountMeta.writable(&sources[i]);
    }
    writeTransferFeePrefix(data, .harvest_withheld_tokens_to_mint);
    return ixSlice(metas[0..accounts_len], data);
}

pub fn setTransferFee(
    mint: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    transfer_fee_basis_points: u16,
    maximum_fee: u64,
    metas: []AccountMeta,
    data: *[transfer_fee_set_transfer_fee_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillTransferFeeAuthorityMetas(
        metas,
        2,
        authority,
        signers,
        .{AccountMeta.writable(mint)},
    );
    writeTransferFeePrefix(data, .set_transfer_fee);
    std.mem.writeInt(u16, data[2..4], transfer_fee_basis_points, .little);
    std.mem.writeInt(u64, data[4..12], maximum_fee, .little);
    return ixSlice(metas[0..accounts_len], data);
}

pub fn initializeConfidentialTransferMint(
    mint: *const Pubkey,
    authority: ?*const Pubkey,
    auto_approve_new_accounts: bool,
    auditor_elgamal_pubkey: ?*const [32]u8,
    metas: *metasArray(get_account_data_size_spec),
    data: *[confidential_transfer_initialize_mint_data_len]u8,
) Instruction {
    writeConfidentialTransferPrefix(data, .initialize_mint);
    writeOptionalNonZeroPubkey(data[2..34], authority);
    data[34] = if (auto_approve_new_accounts) 1 else 0;
    writeOptionalBytes32(data[35..67], auditor_elgamal_pubkey);
    metas[0] = AccountMeta.writable(mint);
    return ix(metas, data);
}

pub fn updateConfidentialTransferMint(
    mint: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    auto_approve_new_accounts: bool,
    auditor_elgamal_pubkey: ?*const [32]u8,
    metas: []AccountMeta,
    data: *[confidential_transfer_update_mint_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillExtensionAuthorityMetas(
        metas,
        2,
        authority,
        signers,
        .{AccountMeta.writable(mint)},
    );
    writeConfidentialTransferPrefix(data, .update_mint);
    data[2] = if (auto_approve_new_accounts) 1 else 0;
    writeOptionalBytes32(data[3..35], auditor_elgamal_pubkey);
    return ixSlice(metas[0..accounts_len], data);
}

pub fn configureConfidentialTransferAccount(
    account: *const Pubkey,
    mint: *const Pubkey,
    decryptable_zero_balance: *const [36]u8,
    maximum_pending_balance_credit_counter: u64,
    authority: *const Pubkey,
    signers: []const Pubkey,
    proof_location: ConfidentialProofLocation,
    metas: []AccountMeta,
    data: *[confidential_transfer_configure_account_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = transferFeeAuthorityAccountsLen(signers, 4) orelse return error.TooManyAccounts;
    if (metas.len < accounts_len) return error.OutputTooSmall;
    metas[0] = AccountMeta.writable(account);
    metas[1] = AccountMeta.readonly(mint);
    const proof_instruction_offset = fillProofLocationMeta(metas, 2, proof_location);
    metas[3] = if (signers.len == 0)
        AccountMeta.signer(authority)
    else
        AccountMeta.readonly(authority);
    for (signers, 0..) |_, i| {
        metas[4 + i] = AccountMeta.signer(&signers[i]);
    }

    writeConfidentialTransferPrefix(data, .configure_account);
    @memcpy(data[2..38], decryptable_zero_balance);
    std.mem.writeInt(u64, data[38..46], maximum_pending_balance_credit_counter, .little);
    data[46] = @bitCast(proof_instruction_offset);
    return ixSlice(metas[0..accounts_len], data);
}

pub fn configureConfidentialTransferAccountWithRegistry(
    account: *const Pubkey,
    mint: *const Pubkey,
    elgamal_registry_account: *const Pubkey,
    payer: ?*const Pubkey,
    metas: []AccountMeta,
    data: *[confidential_transfer_configure_account_with_registry_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = confidentialTransferConfigureAccountWithRegistryAccountsLen(payer);
    if (metas.len < accounts_len) return error.OutputTooSmall;

    metas[0] = AccountMeta.writable(account);
    metas[1] = AccountMeta.readonly(mint);
    metas[2] = AccountMeta.readonly(elgamal_registry_account);
    if (payer) |payer_key| {
        metas[3] = AccountMeta{ .pubkey = payer_key, .is_signer = 1, .is_writable = 1 };
        metas[4] = AccountMeta.readonly(&sol.system_program_id);
    }

    writeConfidentialTransferPrefix(data, .configure_account_with_registry);
    return ixSlice(metas[0..accounts_len], data);
}

pub fn approveConfidentialTransferAccount(
    account: *const Pubkey,
    mint: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    metas: []AccountMeta,
    data: *[confidential_transfer_approve_account_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillExtensionAuthorityMetas(
        metas,
        3,
        authority,
        signers,
        .{
            AccountMeta.writable(account),
            AccountMeta.readonly(mint),
        },
    );
    writeConfidentialTransferPrefix(data, .approve_account);
    return ixSlice(metas[0..accounts_len], data);
}

pub fn emptyConfidentialTransferAccount(
    account: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    proof_location: ConfidentialProofLocation,
    metas: []AccountMeta,
    data: *[confidential_transfer_empty_account_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = transferFeeAuthorityAccountsLen(signers, 3) orelse return error.TooManyAccounts;
    if (metas.len < accounts_len) return error.OutputTooSmall;
    metas[0] = AccountMeta.writable(account);
    const proof_instruction_offset = fillProofLocationMeta(metas, 1, proof_location);
    metas[2] = if (signers.len == 0)
        AccountMeta.signer(authority)
    else
        AccountMeta.readonly(authority);
    for (signers, 0..) |_, i| {
        metas[3 + i] = AccountMeta.signer(&signers[i]);
    }

    writeConfidentialTransferPrefix(data, .empty_account);
    data[2] = @bitCast(proof_instruction_offset);
    return ixSlice(metas[0..accounts_len], data);
}

pub fn depositConfidentialTransfer(
    account: *const Pubkey,
    mint: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    amount: u64,
    decimals: u8,
    metas: []AccountMeta,
    data: *[confidential_transfer_deposit_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillExtensionAuthorityMetas(
        metas,
        3,
        authority,
        signers,
        .{
            AccountMeta.writable(account),
            AccountMeta.readonly(mint),
        },
    );
    writeConfidentialTransferPrefix(data, .deposit);
    std.mem.writeInt(u64, data[2..10], amount, .little);
    data[10] = decimals;
    return ixSlice(metas[0..accounts_len], data);
}

pub fn withdrawConfidentialTransfer(
    account: *const Pubkey,
    mint: *const Pubkey,
    amount: u64,
    decimals: u8,
    new_decryptable_available_balance: *const [36]u8,
    authority: *const Pubkey,
    signers: []const Pubkey,
    equality_proof_location: ConfidentialProofLocation,
    range_proof_location: ConfidentialProofLocation,
    metas: []AccountMeta,
    data: *[confidential_transfer_withdraw_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = confidentialTransferWithdrawAccountsLen(
        signers,
        equality_proof_location,
        range_proof_location,
    ) orelse return error.TooManyAccounts;
    if (metas.len < accounts_len) return error.OutputTooSmall;

    metas[0] = AccountMeta.writable(account);
    metas[1] = AccountMeta.readonly(mint);
    var offset: usize = 2;
    if (proofLocationUsesInstructionOffset(equality_proof_location) or
        proofLocationUsesInstructionOffset(range_proof_location))
    {
        metas[offset] = AccountMeta.readonly(&sol.instructions_sysvar_id);
        offset += 1;
    }
    const equality_proof_instruction_offset = appendContextProofLocationMeta(
        metas,
        &offset,
        equality_proof_location,
    );
    const range_proof_instruction_offset = appendContextProofLocationMeta(
        metas,
        &offset,
        range_proof_location,
    );
    metas[offset] = if (signers.len == 0)
        AccountMeta.signer(authority)
    else
        AccountMeta.readonly(authority);
    offset += 1;
    for (signers, 0..) |_, i| {
        metas[offset + i] = AccountMeta.signer(&signers[i]);
    }
    offset += signers.len;

    writeConfidentialTransferPrefix(data, .withdraw);
    std.mem.writeInt(u64, data[2..10], amount, .little);
    data[10] = decimals;
    @memcpy(data[11..47], new_decryptable_available_balance);
    data[47] = @bitCast(equality_proof_instruction_offset);
    data[48] = @bitCast(range_proof_instruction_offset);
    return ixSlice(metas[0..offset], data);
}

pub fn transferConfidentialTransfer(
    source: *const Pubkey,
    mint: *const Pubkey,
    destination: *const Pubkey,
    new_source_decryptable_available_balance: *const [36]u8,
    transfer_amount_auditor_ciphertext_lo: *const [64]u8,
    transfer_amount_auditor_ciphertext_hi: *const [64]u8,
    authority: *const Pubkey,
    signers: []const Pubkey,
    equality_proof_location: ConfidentialProofLocation,
    ciphertext_validity_proof_location: ConfidentialProofLocation,
    range_proof_location: ConfidentialProofLocation,
    metas: []AccountMeta,
    data: *[confidential_transfer_transfer_data_len]u8,
) ExtensionInstructionError!Instruction {
    const proof_locations = [_]ConfidentialProofLocation{
        equality_proof_location,
        ciphertext_validity_proof_location,
        range_proof_location,
    };
    const accounts_len = confidentialTransferProofAccountsLen(signers, 3, &proof_locations) orelse return error.TooManyAccounts;
    if (metas.len < accounts_len) return error.OutputTooSmall;

    metas[0] = AccountMeta.writable(source);
    metas[1] = AccountMeta.readonly(mint);
    metas[2] = AccountMeta.writable(destination);
    var offset: usize = 3;
    if (proofLocationsUseInstructionOffset(&proof_locations)) {
        metas[offset] = AccountMeta.readonly(&sol.instructions_sysvar_id);
        offset += 1;
    }
    const equality_proof_instruction_offset = appendContextProofLocationMeta(metas, &offset, equality_proof_location);
    const ciphertext_validity_proof_instruction_offset = appendContextProofLocationMeta(metas, &offset, ciphertext_validity_proof_location);
    const range_proof_instruction_offset = appendContextProofLocationMeta(metas, &offset, range_proof_location);
    offset = appendAuthorityAndSignerMetas(metas, offset, authority, signers);

    writeConfidentialTransferPrefix(data, .transfer);
    @memcpy(data[2..38], new_source_decryptable_available_balance);
    @memcpy(data[38..102], transfer_amount_auditor_ciphertext_lo);
    @memcpy(data[102..166], transfer_amount_auditor_ciphertext_hi);
    data[166] = @bitCast(equality_proof_instruction_offset);
    data[167] = @bitCast(ciphertext_validity_proof_instruction_offset);
    data[168] = @bitCast(range_proof_instruction_offset);
    return ixSlice(metas[0..offset], data);
}

pub fn transferConfidentialTransferWithFee(
    source: *const Pubkey,
    mint: *const Pubkey,
    destination: *const Pubkey,
    new_source_decryptable_available_balance: *const [36]u8,
    transfer_amount_auditor_ciphertext_lo: *const [64]u8,
    transfer_amount_auditor_ciphertext_hi: *const [64]u8,
    authority: *const Pubkey,
    signers: []const Pubkey,
    equality_proof_location: ConfidentialProofLocation,
    transfer_amount_ciphertext_validity_proof_location: ConfidentialProofLocation,
    fee_sigma_proof_location: ConfidentialProofLocation,
    fee_ciphertext_validity_proof_location: ConfidentialProofLocation,
    range_proof_location: ConfidentialProofLocation,
    metas: []AccountMeta,
    data: *[confidential_transfer_transfer_with_fee_data_len]u8,
) ExtensionInstructionError!Instruction {
    const proof_locations = [_]ConfidentialProofLocation{
        equality_proof_location,
        transfer_amount_ciphertext_validity_proof_location,
        fee_sigma_proof_location,
        fee_ciphertext_validity_proof_location,
        range_proof_location,
    };
    const accounts_len = confidentialTransferProofAccountsLen(signers, 3, &proof_locations) orelse return error.TooManyAccounts;
    if (metas.len < accounts_len) return error.OutputTooSmall;

    metas[0] = AccountMeta.writable(source);
    metas[1] = AccountMeta.readonly(mint);
    metas[2] = AccountMeta.writable(destination);
    var offset: usize = 3;
    if (proofLocationsUseInstructionOffset(&proof_locations)) {
        metas[offset] = AccountMeta.readonly(&sol.instructions_sysvar_id);
        offset += 1;
    }
    const equality_proof_instruction_offset = appendContextProofLocationMeta(metas, &offset, equality_proof_location);
    const transfer_amount_ciphertext_validity_proof_instruction_offset = appendContextProofLocationMeta(
        metas,
        &offset,
        transfer_amount_ciphertext_validity_proof_location,
    );
    const fee_sigma_proof_instruction_offset = appendContextProofLocationMeta(metas, &offset, fee_sigma_proof_location);
    const fee_ciphertext_validity_proof_instruction_offset = appendContextProofLocationMeta(metas, &offset, fee_ciphertext_validity_proof_location);
    const range_proof_instruction_offset = appendContextProofLocationMeta(metas, &offset, range_proof_location);
    offset = appendAuthorityAndSignerMetas(metas, offset, authority, signers);

    writeConfidentialTransferPrefix(data, .transfer_with_fee);
    @memcpy(data[2..38], new_source_decryptable_available_balance);
    @memcpy(data[38..102], transfer_amount_auditor_ciphertext_lo);
    @memcpy(data[102..166], transfer_amount_auditor_ciphertext_hi);
    data[166] = @bitCast(equality_proof_instruction_offset);
    data[167] = @bitCast(transfer_amount_ciphertext_validity_proof_instruction_offset);
    data[168] = @bitCast(fee_sigma_proof_instruction_offset);
    data[169] = @bitCast(fee_ciphertext_validity_proof_instruction_offset);
    data[170] = @bitCast(range_proof_instruction_offset);
    return ixSlice(metas[0..offset], data);
}

pub fn applyPendingConfidentialTransferBalance(
    account: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    expected_pending_balance_credit_counter: u64,
    new_decryptable_available_balance: *const [36]u8,
    metas: []AccountMeta,
    data: *[confidential_transfer_apply_pending_balance_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillExtensionAuthorityMetas(
        metas,
        2,
        authority,
        signers,
        .{AccountMeta.writable(account)},
    );
    writeConfidentialTransferPrefix(data, .apply_pending_balance);
    std.mem.writeInt(u64, data[2..10], expected_pending_balance_credit_counter, .little);
    @memcpy(data[10..46], new_decryptable_available_balance);
    return ixSlice(metas[0..accounts_len], data);
}

pub fn enableConfidentialTransferCredits(
    account: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    metas: []AccountMeta,
    data: *[confidential_transfer_toggle_credits_data_len]u8,
) ExtensionInstructionError!Instruction {
    return confidentialTransferCredits(account, authority, signers, .enable_confidential_credits, metas, data);
}

pub fn disableConfidentialTransferCredits(
    account: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    metas: []AccountMeta,
    data: *[confidential_transfer_toggle_credits_data_len]u8,
) ExtensionInstructionError!Instruction {
    return confidentialTransferCredits(account, authority, signers, .disable_confidential_credits, metas, data);
}

pub fn enableNonConfidentialTransferCredits(
    account: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    metas: []AccountMeta,
    data: *[confidential_transfer_toggle_credits_data_len]u8,
) ExtensionInstructionError!Instruction {
    return confidentialTransferCredits(account, authority, signers, .enable_non_confidential_credits, metas, data);
}

pub fn disableNonConfidentialTransferCredits(
    account: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    metas: []AccountMeta,
    data: *[confidential_transfer_toggle_credits_data_len]u8,
) ExtensionInstructionError!Instruction {
    return confidentialTransferCredits(account, authority, signers, .disable_non_confidential_credits, metas, data);
}

pub fn initializeConfidentialTransferFeeConfig(
    mint: *const Pubkey,
    authority: ?*const Pubkey,
    withdraw_withheld_authority_elgamal_pubkey: *const [32]u8,
    metas: *metasArray(get_account_data_size_spec),
    data: *[confidential_transfer_fee_initialize_config_data_len]u8,
) Instruction {
    writeConfidentialTransferFeePrefix(data, .initialize_confidential_transfer_fee_config);
    writeOptionalNonZeroPubkey(data[2..34], authority);
    @memcpy(data[34..66], withdraw_withheld_authority_elgamal_pubkey);
    metas[0] = AccountMeta.writable(mint);
    return ix(metas, data);
}

pub fn withdrawConfidentialTransferFeeWithheldTokensFromMint(
    mint: *const Pubkey,
    destination: *const Pubkey,
    new_decryptable_available_balance: *const [36]u8,
    authority: *const Pubkey,
    signers: []const Pubkey,
    proof_location: ConfidentialProofLocation,
    metas: []AccountMeta,
    data: *[confidential_transfer_fee_withdraw_withheld_tokens_from_mint_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = transferFeeAuthorityAccountsLen(signers, 4) orelse return error.TooManyAccounts;
    if (metas.len < accounts_len) return error.OutputTooSmall;
    metas[0] = AccountMeta.writable(mint);
    metas[1] = AccountMeta.writable(destination);
    const proof_instruction_offset = fillProofLocationMeta(metas, 2, proof_location);
    metas[3] = if (signers.len == 0)
        AccountMeta.signer(authority)
    else
        AccountMeta.readonly(authority);
    for (signers, 0..) |_, i| {
        metas[4 + i] = AccountMeta.signer(&signers[i]);
    }
    writeConfidentialTransferFeePrefix(data, .withdraw_withheld_tokens_from_mint);
    data[2] = @bitCast(proof_instruction_offset);
    @memcpy(data[3..39], new_decryptable_available_balance);
    return ixSlice(metas[0..accounts_len], data);
}

pub fn withdrawConfidentialTransferFeeWithheldTokensFromAccounts(
    mint: *const Pubkey,
    destination: *const Pubkey,
    new_decryptable_available_balance: *const [36]u8,
    authority: *const Pubkey,
    signers: []const Pubkey,
    sources: []const Pubkey,
    proof_location: ConfidentialProofLocation,
    metas: []AccountMeta,
    data: *[confidential_transfer_fee_withdraw_withheld_tokens_from_accounts_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = confidentialTransferFeeWithdrawFromAccountsLen(signers, sources) orelse return error.TooManyAccounts;
    if (metas.len < accounts_len) return error.OutputTooSmall;

    metas[0] = AccountMeta.readonly(mint);
    metas[1] = AccountMeta.writable(destination);
    const proof_instruction_offset = fillProofLocationMeta(metas, 2, proof_location);
    metas[3] = if (signers.len == 0)
        AccountMeta.signer(authority)
    else
        AccountMeta.readonly(authority);
    for (signers, 0..) |_, i| {
        metas[4 + i] = AccountMeta.signer(&signers[i]);
    }
    const source_offset = 4 + signers.len;
    for (sources, 0..) |_, i| {
        metas[source_offset + i] = AccountMeta.writable(&sources[i]);
    }

    writeConfidentialTransferFeePrefix(data, .withdraw_withheld_tokens_from_accounts);
    data[2] = @intCast(sources.len);
    data[3] = @bitCast(proof_instruction_offset);
    @memcpy(data[4..40], new_decryptable_available_balance);
    return ixSlice(metas[0..accounts_len], data);
}

pub fn harvestConfidentialTransferWithheldTokensToMint(
    mint: *const Pubkey,
    sources: []const Pubkey,
    metas: []AccountMeta,
    data: *[confidential_transfer_fee_harvest_withheld_tokens_to_mint_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = transferFeeHarvestAccountsLen(sources) orelse return error.TooManyAccounts;
    if (metas.len < accounts_len) return error.OutputTooSmall;
    metas[0] = AccountMeta.writable(mint);
    for (sources, 0..) |_, i| {
        metas[1 + i] = AccountMeta.writable(&sources[i]);
    }
    writeConfidentialTransferFeePrefix(data, .harvest_withheld_tokens_to_mint);
    return ixSlice(metas[0..accounts_len], data);
}

pub fn enableConfidentialTransferFeeHarvestToMint(
    mint: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    metas: []AccountMeta,
    data: *[confidential_transfer_fee_toggle_harvest_to_mint_data_len]u8,
) ExtensionInstructionError!Instruction {
    return confidentialTransferFeeHarvestToMint(mint, authority, signers, .enable_harvest_to_mint, metas, data);
}

pub fn disableConfidentialTransferFeeHarvestToMint(
    mint: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    metas: []AccountMeta,
    data: *[confidential_transfer_fee_toggle_harvest_to_mint_data_len]u8,
) ExtensionInstructionError!Instruction {
    return confidentialTransferFeeHarvestToMint(mint, authority, signers, .disable_harvest_to_mint, metas, data);
}

pub fn reallocate(
    account: *const Pubkey,
    payer: *const Pubkey,
    owner: *const Pubkey,
    signers: []const Pubkey,
    extension_types: []const ExtensionType,
    metas: []AccountMeta,
    data: []u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = reallocateAccountsLen(signers) orelse return error.TooManyAccounts;
    const data_len = reallocateDataLen(extension_types) orelse return error.TooManyAccounts;
    if (metas.len < accounts_len or data.len < data_len) return error.OutputTooSmall;

    metas[0] = AccountMeta.writable(account);
    metas[1] = AccountMeta.signerWritable(payer);
    metas[2] = AccountMeta.readonly(&sol.system_program_id);
    metas[3] = if (signers.len == 0)
        AccountMeta.signer(owner)
    else
        AccountMeta.readonly(owner);
    for (signers, 0..) |_, i| {
        metas[4 + i] = AccountMeta.signer(&signers[i]);
    }

    data[0] = @intFromEnum(Token2022Instruction.reallocate);
    for (extension_types, 0..) |extension_type, i| {
        const offset = 1 + i * 2;
        std.mem.writeInt(u16, data[offset..][0..2], @intFromEnum(extension_type), .little);
    }
    return ixSlice(metas[0..accounts_len], data[0..data_len]);
}

pub fn createNativeMint(
    payer: *const Pubkey,
    metas: *metasArray(create_native_mint_spec),
    data: *dataArray(create_native_mint_spec),
) Instruction {
    data[0] = @intFromEnum(Token2022Instruction.create_native_mint);
    metas[0] = AccountMeta.signerWritable(payer);
    metas[1] = AccountMeta.writable(&id.NATIVE_MINT);
    metas[2] = AccountMeta.readonly(&sol.system_program_id);
    return ix(metas, data);
}

pub fn withdrawExcessLamports(
    source: *const Pubkey,
    destination: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    metas: []AccountMeta,
    data: *[withdraw_excess_lamports_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillExtensionAuthorityMetas(
        metas,
        3,
        authority,
        signers,
        .{
            AccountMeta.writable(source),
            AccountMeta.writable(destination),
        },
    );
    data[0] = @intFromEnum(Token2022Instruction.withdraw_excess_lamports);
    return ixSlice(metas[0..accounts_len], data);
}

pub fn initializeDefaultAccountState(
    mint: *const Pubkey,
    account_state: AccountState,
    metas: *metasArray(get_account_data_size_spec),
    data: *[default_account_state_data_len]u8,
) Instruction {
    writeDefaultAccountStateData(data, .initialize, account_state);
    metas[0] = AccountMeta.writable(mint);
    return ix(metas, data);
}

pub fn initializeNonTransferableMint(
    mint: *const Pubkey,
    metas: *metasArray(initialize_non_transferable_mint_spec),
    data: *dataArray(initialize_non_transferable_mint_spec),
) Instruction {
    data[0] = @intFromEnum(Token2022Instruction.initialize_non_transferable_mint);
    metas[0] = AccountMeta.writable(mint);
    return ix(metas, data);
}

pub fn updateDefaultAccountState(
    mint: *const Pubkey,
    freeze_authority: *const Pubkey,
    signers: []const Pubkey,
    account_state: AccountState,
    metas: []AccountMeta,
    data: *[default_account_state_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillExtensionAuthorityMetas(
        metas,
        2,
        freeze_authority,
        signers,
        .{AccountMeta.writable(mint)},
    );
    writeDefaultAccountStateData(data, .update, account_state);
    return ixSlice(metas[0..accounts_len], data);
}

pub fn enableRequiredTransferMemos(
    account: *const Pubkey,
    owner: *const Pubkey,
    signers: []const Pubkey,
    metas: []AccountMeta,
    data: *[memo_transfer_data_len]u8,
) ExtensionInstructionError!Instruction {
    return requiredTransferMemos(account, owner, signers, .enable, metas, data);
}

pub fn disableRequiredTransferMemos(
    account: *const Pubkey,
    owner: *const Pubkey,
    signers: []const Pubkey,
    metas: []AccountMeta,
    data: *[memo_transfer_data_len]u8,
) ExtensionInstructionError!Instruction {
    return requiredTransferMemos(account, owner, signers, .disable, metas, data);
}

pub fn enableCpiGuard(
    account: *const Pubkey,
    owner: *const Pubkey,
    signers: []const Pubkey,
    metas: []AccountMeta,
    data: *[cpi_guard_data_len]u8,
) ExtensionInstructionError!Instruction {
    return cpiGuard(account, owner, signers, .enable, metas, data);
}

pub fn disableCpiGuard(
    account: *const Pubkey,
    owner: *const Pubkey,
    signers: []const Pubkey,
    metas: []AccountMeta,
    data: *[cpi_guard_data_len]u8,
) ExtensionInstructionError!Instruction {
    return cpiGuard(account, owner, signers, .disable, metas, data);
}

pub fn initializeInterestBearingMint(
    mint: *const Pubkey,
    rate_authority: ?*const Pubkey,
    rate: i16,
    metas: *metasArray(get_account_data_size_spec),
    data: *[interest_bearing_initialize_data_len]u8,
) Instruction {
    writeInterestBearingMintPrefix(data, .initialize);
    writeOptionalNonZeroPubkey(data[2..34], rate_authority);
    std.mem.writeInt(i16, data[34..36], rate, .little);
    metas[0] = AccountMeta.writable(mint);
    return ix(metas, data);
}

pub fn updateInterestBearingRate(
    mint: *const Pubkey,
    rate_authority: *const Pubkey,
    signers: []const Pubkey,
    rate: i16,
    metas: []AccountMeta,
    data: *[interest_bearing_update_rate_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillExtensionAuthorityMetas(
        metas,
        2,
        rate_authority,
        signers,
        .{AccountMeta.writable(mint)},
    );
    writeInterestBearingMintPrefix(data, .update_rate);
    std.mem.writeInt(i16, data[2..4], rate, .little);
    return ixSlice(metas[0..accounts_len], data);
}

pub fn initializePermanentDelegate(
    mint: *const Pubkey,
    delegate: *const Pubkey,
    metas: *metasArray(get_account_data_size_spec),
    data: *[initialize_permanent_delegate_data_len]u8,
) Instruction {
    data[0] = @intFromEnum(Token2022Instruction.initialize_permanent_delegate);
    @memcpy(data[1..33], delegate);
    metas[0] = AccountMeta.writable(mint);
    return ix(metas, data);
}

pub fn initializeMetadataPointer(
    mint: *const Pubkey,
    authority: ?*const Pubkey,
    metadata_address: ?*const Pubkey,
    metas: *metasArray(get_account_data_size_spec),
    data: *[pointer_initialize_data_len]u8,
) Instruction {
    writePointerInitializeData(data, .metadata_pointer_extension, authority, metadata_address);
    metas[0] = AccountMeta.writable(mint);
    return ix(metas, data);
}

pub fn updateMetadataPointer(
    mint: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    metadata_address: ?*const Pubkey,
    metas: []AccountMeta,
    data: *[pointer_update_data_len]u8,
) ExtensionInstructionError!Instruction {
    return updatePointer(.metadata_pointer_extension, mint, authority, signers, metadata_address, metas, data);
}

pub fn initializeGroupPointer(
    mint: *const Pubkey,
    authority: ?*const Pubkey,
    group_address: ?*const Pubkey,
    metas: *metasArray(get_account_data_size_spec),
    data: *[pointer_initialize_data_len]u8,
) Instruction {
    writePointerInitializeData(data, .group_pointer_extension, authority, group_address);
    metas[0] = AccountMeta.writable(mint);
    return ix(metas, data);
}

pub fn updateGroupPointer(
    mint: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    group_address: ?*const Pubkey,
    metas: []AccountMeta,
    data: *[pointer_update_data_len]u8,
) ExtensionInstructionError!Instruction {
    return updatePointer(.group_pointer_extension, mint, authority, signers, group_address, metas, data);
}

pub fn initializeGroupMemberPointer(
    mint: *const Pubkey,
    authority: ?*const Pubkey,
    member_address: ?*const Pubkey,
    metas: *metasArray(get_account_data_size_spec),
    data: *[pointer_initialize_data_len]u8,
) Instruction {
    writePointerInitializeData(data, .group_member_pointer_extension, authority, member_address);
    metas[0] = AccountMeta.writable(mint);
    return ix(metas, data);
}

pub fn updateGroupMemberPointer(
    mint: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    member_address: ?*const Pubkey,
    metas: []AccountMeta,
    data: *[pointer_update_data_len]u8,
) ExtensionInstructionError!Instruction {
    return updatePointer(.group_member_pointer_extension, mint, authority, signers, member_address, metas, data);
}

pub fn initializeTransferHook(
    mint: *const Pubkey,
    authority: ?*const Pubkey,
    transfer_hook_program_id: ?*const Pubkey,
    metas: *metasArray(get_account_data_size_spec),
    data: *[transfer_hook_initialize_data_len]u8,
) Instruction {
    writePointerInitializeData(data, .transfer_hook_extension, authority, transfer_hook_program_id);
    metas[0] = AccountMeta.writable(mint);
    return ix(metas, data);
}

pub fn updateTransferHook(
    mint: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    transfer_hook_program_id: ?*const Pubkey,
    metas: []AccountMeta,
    data: *[transfer_hook_update_data_len]u8,
) ExtensionInstructionError!Instruction {
    return updatePointer(.transfer_hook_extension, mint, authority, signers, transfer_hook_program_id, metas, data);
}

pub fn initializeScaledUiAmount(
    mint: *const Pubkey,
    authority: ?*const Pubkey,
    multiplier: f64,
    metas: *metasArray(get_account_data_size_spec),
    data: *[scaled_ui_amount_initialize_data_len]u8,
) Instruction {
    writeScaledUiAmountPrefix(data, .initialize);
    writeOptionalNonZeroPubkey(data[2..34], authority);
    writeF64Le(data[34..42], multiplier);
    metas[0] = AccountMeta.writable(mint);
    return ix(metas, data);
}

pub fn updateScaledUiAmountMultiplier(
    mint: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    multiplier: f64,
    effective_timestamp: i64,
    metas: []AccountMeta,
    data: *[scaled_ui_amount_update_multiplier_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillExtensionAuthorityMetas(
        metas,
        2,
        authority,
        signers,
        .{AccountMeta.writable(mint)},
    );
    writeScaledUiAmountPrefix(data, .update_multiplier);
    writeF64Le(data[2..10], multiplier);
    std.mem.writeInt(i64, data[10..18], effective_timestamp, .little);
    return ixSlice(metas[0..accounts_len], data);
}

pub fn initializePausable(
    mint: *const Pubkey,
    authority: *const Pubkey,
    metas: *metasArray(get_account_data_size_spec),
    data: *[pausable_initialize_data_len]u8,
) Instruction {
    writePausablePrefix(data, .initialize);
    @memcpy(data[2..34], authority);
    metas[0] = AccountMeta.writable(mint);
    return ix(metas, data);
}

pub fn pausePausable(
    mint: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    metas: []AccountMeta,
    data: *[pausable_toggle_data_len]u8,
) ExtensionInstructionError!Instruction {
    return pausableToggle(mint, authority, signers, .pause_pausable, metas, data);
}

pub fn resumePausable(
    mint: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    metas: []AccountMeta,
    data: *[pausable_toggle_data_len]u8,
) ExtensionInstructionError!Instruction {
    return pausableToggle(mint, authority, signers, .resume_pausable, metas, data);
}

fn ix(accounts: anytype, data: anytype) Instruction {
    return .{
        .program_id = &id.PROGRAM_ID,
        .accounts = accounts,
        .data = data,
    };
}

fn ixSlice(accounts: []const AccountMeta, data: []const u8) Instruction {
    return .{
        .program_id = &id.PROGRAM_ID,
        .accounts = accounts,
        .data = data,
    };
}

fn writeAmountData(data: []u8, disc: Token2022Instruction, amount: u64) void {
    data[0] = @intFromEnum(disc);
    std.mem.writeInt(u64, data[1..9], amount, .little);
}

fn writeAmountDecimalsData(data: []u8, disc: Token2022Instruction, amount: u64, decimals: u8) void {
    writeAmountData(data, disc, amount);
    data[9] = decimals;
}

fn writeTransferFeePrefix(data: []u8, disc: TransferFeeInstruction) void {
    data[0] = @intFromEnum(Token2022Instruction.transfer_fee_extension);
    data[1] = @intFromEnum(disc);
}

fn writeConfidentialTransferPrefix(data: []u8, disc: ConfidentialTransferInstruction) void {
    data[0] = @intFromEnum(Token2022Instruction.confidential_transfer_extension);
    data[1] = @intFromEnum(disc);
}

fn writeConfidentialTransferFeePrefix(data: []u8, disc: ConfidentialTransferFeeInstruction) void {
    data[0] = @intFromEnum(Token2022Instruction.confidential_transfer_fee_extension);
    data[1] = @intFromEnum(disc);
}

fn writeDefaultAccountStateData(
    data: *[default_account_state_data_len]u8,
    disc: DefaultAccountStateInstruction,
    account_state: AccountState,
) void {
    data[0] = @intFromEnum(Token2022Instruction.default_account_state_extension);
    data[1] = @intFromEnum(disc);
    data[2] = @intFromEnum(account_state);
}

fn writeRequiredTransferMemosData(
    data: *[memo_transfer_data_len]u8,
    disc: RequiredMemoTransfersInstruction,
) void {
    data[0] = @intFromEnum(Token2022Instruction.memo_transfer_extension);
    data[1] = @intFromEnum(disc);
}

fn writeCpiGuardData(
    data: *[cpi_guard_data_len]u8,
    disc: CpiGuardInstruction,
) void {
    data[0] = @intFromEnum(Token2022Instruction.cpi_guard_extension);
    data[1] = @intFromEnum(disc);
}

fn writeInterestBearingMintPrefix(
    data: []u8,
    disc: InterestBearingMintInstruction,
) void {
    data[0] = @intFromEnum(Token2022Instruction.interest_bearing_mint_extension);
    data[1] = @intFromEnum(disc);
}

fn writePausablePrefix(
    data: []u8,
    disc: PausableInstruction,
) void {
    data[0] = @intFromEnum(Token2022Instruction.pausable_extension);
    data[1] = @intFromEnum(disc);
}

fn writePointerPrefix(
    data: []u8,
    outer: Token2022Instruction,
    disc: PointerInstruction,
) void {
    data[0] = @intFromEnum(outer);
    data[1] = @intFromEnum(disc);
}

fn writePointerInitializeData(
    data: *[pointer_initialize_data_len]u8,
    outer: Token2022Instruction,
    authority: ?*const Pubkey,
    target: ?*const Pubkey,
) void {
    writePointerPrefix(data, outer, .initialize);
    writeOptionalNonZeroPubkey(data[2..34], authority);
    writeOptionalNonZeroPubkey(data[34..66], target);
}

fn writePointerUpdateData(
    data: *[pointer_update_data_len]u8,
    outer: Token2022Instruction,
    target: ?*const Pubkey,
) void {
    writePointerPrefix(data, outer, .update);
    writeOptionalNonZeroPubkey(data[2..34], target);
}

fn writeScaledUiAmountPrefix(
    data: []u8,
    disc: ScaledUiAmountInstruction,
) void {
    data[0] = @intFromEnum(Token2022Instruction.scaled_ui_amount_extension);
    data[1] = @intFromEnum(disc);
}

fn writeF64Le(out: []u8, value: f64) void {
    std.debug.assert(out.len >= 8);
    const bits: u64 = @bitCast(value);
    std.mem.writeInt(u64, out[0..8], bits, .little);
}

fn writeTransferFeeAmountDecimalsFeeData(
    data: *[transfer_fee_transfer_checked_with_fee_data_len]u8,
    disc: TransferFeeInstruction,
    amount: u64,
    decimals: u8,
    fee: u64,
) void {
    writeTransferFeePrefix(data, disc);
    std.mem.writeInt(u64, data[2..10], amount, .little);
    data[10] = decimals;
    std.mem.writeInt(u64, data[11..19], fee, .little);
}

fn writeOptionalPubkey(out: []u8, value: ?*const Pubkey) usize {
    std.debug.assert(out.len >= 33);
    if (value) |pubkey| {
        out[0] = 1;
        @memcpy(out[1..33], pubkey);
        return 33;
    } else {
        out[0] = 0;
        @memset(out[1..33], 0);
        return 1;
    }
}

fn writeOptionalNonZeroPubkey(out: []u8, value: ?*const Pubkey) void {
    std.debug.assert(out.len >= 32);
    if (value) |pubkey| {
        @memcpy(out[0..32], pubkey);
    } else {
        @memset(out[0..32], 0);
    }
}

fn writeOptionalBytes32(out: []u8, value: ?*const [32]u8) void {
    std.debug.assert(out.len >= 32);
    if (value) |bytes| {
        @memcpy(out[0..32], bytes);
    } else {
        @memset(out[0..32], 0);
    }
}

fn fillProofLocationMeta(
    metas: []AccountMeta,
    index: usize,
    proof_location: ConfidentialProofLocation,
) i8 {
    switch (proof_location) {
        .instruction_offset => |offset| {
            metas[index] = AccountMeta.readonly(&sol.instructions_sysvar_id);
            return offset;
        },
        .context_state_account => |account| {
            metas[index] = AccountMeta.readonly(account);
            return 0;
        },
    }
}

fn proofLocationUsesInstructionOffset(proof_location: ConfidentialProofLocation) bool {
    return switch (proof_location) {
        .instruction_offset => true,
        .context_state_account => false,
    };
}

fn proofLocationsUseInstructionOffset(proof_locations: []const ConfidentialProofLocation) bool {
    for (proof_locations) |proof_location| {
        if (proofLocationUsesInstructionOffset(proof_location)) return true;
    }
    return false;
}

fn appendContextProofLocationMeta(
    metas: []AccountMeta,
    offset: *usize,
    proof_location: ConfidentialProofLocation,
) i8 {
    switch (proof_location) {
        .instruction_offset => |proof_instruction_offset| return proof_instruction_offset,
        .context_state_account => |account| {
            metas[offset.*] = AccountMeta.readonly(account);
            offset.* += 1;
            return 0;
        },
    }
}

fn appendAuthorityAndSignerMetas(
    metas: []AccountMeta,
    offset: usize,
    authority: *const Pubkey,
    signers: []const Pubkey,
) usize {
    metas[offset] = if (signers.len == 0)
        AccountMeta.signer(authority)
    else
        AccountMeta.readonly(authority);
    const signer_offset = offset + 1;
    for (signers, 0..) |_, i| {
        metas[signer_offset + i] = AccountMeta.signer(&signers[i]);
    }
    return signer_offset + signers.len;
}

fn fillTransferFeeAuthorityMetas(
    metas: []AccountMeta,
    comptime base_accounts_len: usize,
    authority: *const Pubkey,
    signers: []const Pubkey,
    prefix: [base_accounts_len - 1]AccountMeta,
) TransferFeeInstructionError!usize {
    return fillExtensionAuthorityMetas(metas, base_accounts_len, authority, signers, prefix);
}

fn fillExtensionAuthorityMetas(
    metas: []AccountMeta,
    comptime base_accounts_len: usize,
    authority: *const Pubkey,
    signers: []const Pubkey,
    prefix: [base_accounts_len - 1]AccountMeta,
) ExtensionInstructionError!usize {
    const accounts_len = transferFeeAuthorityAccountsLen(signers, base_accounts_len) orelse return error.TooManyAccounts;
    if (metas.len < accounts_len) return error.OutputTooSmall;
    inline for (prefix, 0..) |meta, i| {
        metas[i] = meta;
    }
    metas[base_accounts_len - 1] = if (signers.len == 0)
        AccountMeta.signer(authority)
    else
        AccountMeta.readonly(authority);
    for (signers, 0..) |_, i| {
        metas[base_accounts_len + i] = AccountMeta.signer(&signers[i]);
    }
    return accounts_len;
}

fn validateMultisigThreshold(threshold: u8, signers: []const Pubkey) MultisigInstructionError!void {
    if (signers.len < MIN_SIGNERS or signers.len > MAX_SIGNERS) return error.InvalidMultisigSignerCount;
    if (threshold < MIN_SIGNERS or threshold > signers.len) return error.InvalidMultisigThreshold;
}

fn appendReadonlyMetas(
    metas: []AccountMeta,
    base_accounts_len: usize,
    signers: []const Pubkey,
) MultisigInstructionError![]const AccountMeta {
    const accounts_len = initializeMultisigAccountsLen(signers, base_accounts_len) orelse return error.TooManyAccounts;
    if (metas.len < accounts_len) return error.OutputTooSmall;
    for (signers, 0..) |_, i| {
        metas[base_accounts_len + i] = AccountMeta.readonly(&signers[i]);
    }
    return metas[0..accounts_len];
}

fn requiredTransferMemos(
    account: *const Pubkey,
    owner: *const Pubkey,
    signers: []const Pubkey,
    disc: RequiredMemoTransfersInstruction,
    metas: []AccountMeta,
    data: *[memo_transfer_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillExtensionAuthorityMetas(
        metas,
        2,
        owner,
        signers,
        .{AccountMeta.writable(account)},
    );
    writeRequiredTransferMemosData(data, disc);
    return ixSlice(metas[0..accounts_len], data);
}

fn cpiGuard(
    account: *const Pubkey,
    owner: *const Pubkey,
    signers: []const Pubkey,
    disc: CpiGuardInstruction,
    metas: []AccountMeta,
    data: *[cpi_guard_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillExtensionAuthorityMetas(
        metas,
        2,
        owner,
        signers,
        .{AccountMeta.writable(account)},
    );
    writeCpiGuardData(data, disc);
    return ixSlice(metas[0..accounts_len], data);
}

fn updatePointer(
    outer: Token2022Instruction,
    mint: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    target: ?*const Pubkey,
    metas: []AccountMeta,
    data: *[pointer_update_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillExtensionAuthorityMetas(
        metas,
        2,
        authority,
        signers,
        .{AccountMeta.writable(mint)},
    );
    writePointerUpdateData(data, outer, target);
    return ixSlice(metas[0..accounts_len], data);
}

fn pausableToggle(
    mint: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    disc: PausableInstruction,
    metas: []AccountMeta,
    data: *[pausable_toggle_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillExtensionAuthorityMetas(
        metas,
        2,
        authority,
        signers,
        .{AccountMeta.writable(mint)},
    );
    writePausablePrefix(data, disc);
    return ixSlice(metas[0..accounts_len], data);
}

fn confidentialTransferCredits(
    account: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    disc: ConfidentialTransferInstruction,
    metas: []AccountMeta,
    data: *[confidential_transfer_toggle_credits_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillExtensionAuthorityMetas(
        metas,
        2,
        authority,
        signers,
        .{AccountMeta.writable(account)},
    );
    writeConfidentialTransferPrefix(data, disc);
    return ixSlice(metas[0..accounts_len], data);
}

fn confidentialTransferFeeHarvestToMint(
    mint: *const Pubkey,
    authority: *const Pubkey,
    signers: []const Pubkey,
    disc: ConfidentialTransferFeeInstruction,
    metas: []AccountMeta,
    data: *[confidential_transfer_fee_toggle_harvest_to_mint_data_len]u8,
) ExtensionInstructionError!Instruction {
    const accounts_len = try fillExtensionAuthorityMetas(
        metas,
        2,
        authority,
        signers,
        .{AccountMeta.writable(mint)},
    );
    writeConfidentialTransferFeePrefix(data, disc);
    return ixSlice(metas[0..accounts_len], data);
}

fn expectMeta(actual: AccountMeta, key: *const Pubkey, writable: u8, signer: u8) !void {
    try std.testing.expectEqual(key, actual.pubkey);
    try std.testing.expectEqual(writable, actual.is_writable);
    try std.testing.expectEqual(signer, actual.is_signer);
}

test "checked transfer builder uses Token-2022 program id and canonical bytes" {
    const source: Pubkey = .{1} ** 32;
    const mint: Pubkey = .{2} ** 32;
    const destination: Pubkey = .{3} ** 32;
    const authority: Pubkey = .{4} ** 32;
    var metas: metasArray(transfer_checked_spec) = undefined;
    var data: dataArray(transfer_checked_spec) = undefined;

    const built = transferChecked(&source, &mint, &destination, &authority, 500, 6, &metas, &data);
    try std.testing.expectEqual(&id.PROGRAM_ID, built.program_id);
    try std.testing.expectEqual(@as(usize, 4), built.accounts.len);
    try std.testing.expectEqual(@as(usize, 10), built.data.len);
    try std.testing.expectEqual(@as(u8, 12), data[0]);
    try std.testing.expectEqual(@as(u64, 500), std.mem.readInt(u64, data[1..9], .little));
    try std.testing.expectEqual(@as(u8, 6), data[9]);
    try expectMeta(built.accounts[0], &source, 1, 0);
    try expectMeta(built.accounts[1], &mint, 0, 0);
    try expectMeta(built.accounts[2], &destination, 1, 0);
    try expectMeta(built.accounts[3], &authority, 0, 1);
}

test "initializeMint2 encodes optional freeze authority" {
    const mint: Pubkey = .{0x11} ** 32;
    const mint_authority: Pubkey = .{0x22} ** 32;
    const freeze_authority: Pubkey = .{0x33} ** 32;
    var metas: metasArray(initialize_mint2_spec) = undefined;
    var data: dataArray(initialize_mint2_spec) = undefined;

    _ = initializeMint2(&mint, 9, &mint_authority, &freeze_authority, &metas, &data);
    try std.testing.expectEqual(@as(usize, initialize_mint2_some_data_len), initializeMint2(&mint, 9, &mint_authority, &freeze_authority, &metas, &data).data.len);
    try std.testing.expectEqual(@as(u8, 20), data[0]);
    try std.testing.expectEqual(@as(u8, 9), data[1]);
    try std.testing.expectEqualSlices(u8, &mint_authority, data[2..34]);
    try std.testing.expectEqual(@as(u8, 1), data[34]);
    try std.testing.expectEqualSlices(u8, &freeze_authority, data[35..67]);
    try expectMeta(metas[0], &mint, 1, 0);

    const none_ix = initializeMint2(&mint, 0, &mint_authority, null, &metas, &data);
    try std.testing.expectEqual(@as(usize, initialize_mint2_none_data_len), none_ix.data.len);
    try std.testing.expectEqual(@as(u8, 0), data[34]);
    for (data[35..67]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
}

test "legacy and modern account/multisig initializers encode canonical bytes" {
    const mint: Pubkey = .{0x12} ** 32;
    const account: Pubkey = .{0x13} ** 32;
    const owner: Pubkey = .{0x14} ** 32;
    const freeze_authority: Pubkey = .{0x15} ** 32;
    const multisig: Pubkey = .{0x16} ** 32;
    const signers = [_]Pubkey{ .{0x17} ** 32, .{0x18} ** 32, .{0x19} ** 32 };

    var init_mint_metas: metasArray(initialize_mint_spec) = undefined;
    var init_mint_data: dataArray(initialize_mint_spec) = undefined;
    const init_mint = initializeMint(&mint, 6, &owner, &freeze_authority, &init_mint_metas, &init_mint_data);
    try std.testing.expectEqual(@as(usize, initialize_mint_some_data_len), init_mint.data.len);
    try std.testing.expectEqualSlices(u8, &.{ 0, 6 }, init_mint.data[0..2]);
    try std.testing.expectEqualSlices(u8, &owner, init_mint.data[2..34]);
    try std.testing.expectEqual(@as(u8, 1), init_mint.data[34]);
    try std.testing.expectEqualSlices(u8, &freeze_authority, init_mint.data[35..67]);
    try expectMeta(init_mint.accounts[0], &mint, 1, 0);
    try expectMeta(init_mint.accounts[1], &sol.rent_id, 0, 0);

    const init_mint_none = initializeMint(&mint, 0, &owner, null, &init_mint_metas, &init_mint_data);
    try std.testing.expectEqual(@as(usize, initialize_mint_none_data_len), init_mint_none.data.len);
    try std.testing.expectEqual(@as(u8, 0), init_mint_none.data[34]);

    var init_account_metas: metasArray(initialize_account_spec) = undefined;
    var init_account_data: dataArray(initialize_account_spec) = undefined;
    const init_account = initializeAccount(&account, &mint, &owner, &init_account_metas, &init_account_data);
    try std.testing.expectEqualSlices(u8, &.{1}, init_account.data);
    try expectMeta(init_account.accounts[0], &account, 1, 0);
    try expectMeta(init_account.accounts[1], &mint, 0, 0);
    try expectMeta(init_account.accounts[2], &owner, 0, 0);
    try expectMeta(init_account.accounts[3], &sol.rent_id, 0, 0);

    var init_account2_metas: metasArray(initialize_account2_spec) = undefined;
    var init_account2_data: dataArray(initialize_account2_spec) = undefined;
    const init_account2 = initializeAccount2(&account, &mint, &owner, &init_account2_metas, &init_account2_data);
    try std.testing.expectEqual(@as(u8, 16), init_account2.data[0]);
    try std.testing.expectEqualSlices(u8, &owner, init_account2.data[1..33]);
    try expectMeta(init_account2.accounts[2], &sol.rent_id, 0, 0);

    var init_multisig_metas: multisigMetasArray(initialize_multisig_spec.accounts_len) = undefined;
    var init_multisig_data: dataArray(initialize_multisig_spec) = undefined;
    const init_multisig = try initializeMultisig(&multisig, &signers, 2, &init_multisig_metas, &init_multisig_data);
    try std.testing.expectEqualSlices(u8, &.{ 2, 2 }, init_multisig.data);
    try std.testing.expectEqual(@as(usize, 5), init_multisig.accounts.len);
    try expectMeta(init_multisig.accounts[0], &multisig, 1, 0);
    try expectMeta(init_multisig.accounts[1], &sol.rent_id, 0, 0);
    try expectMeta(init_multisig.accounts[4], &signers[2], 0, 0);

    var init_multisig2_metas: multisigMetasArray(initialize_multisig2_spec.accounts_len) = undefined;
    var init_multisig2_data: dataArray(initialize_multisig2_spec) = undefined;
    const init_multisig2 = try initializeMultisig2(&multisig, &signers, 3, &init_multisig2_metas, &init_multisig2_data);
    try std.testing.expectEqualSlices(u8, &.{ 19, 3 }, init_multisig2.data);
    try std.testing.expectEqual(@as(usize, 4), init_multisig2.accounts.len);
    try expectMeta(init_multisig2.accounts[0], &multisig, 1, 0);
    try expectMeta(init_multisig2.accounts[3], &signers[2], 0, 0);
}

test "utility builders cover close syncless size owner and ui amount flows" {
    const a: Pubkey = .{0xA1} ** 32;
    const b: Pubkey = .{0xB2} ** 32;
    const c: Pubkey = .{0xC3} ** 32;

    var amount_metas: metasArray(mint_to_spec) = undefined;
    var amount_data: dataArray(mint_to_spec) = undefined;
    _ = mintTo(&a, &b, &c, 77, &amount_metas, &amount_data);
    try std.testing.expectEqual(@as(u8, 7), amount_data[0]);

    var close_metas: metasArray(close_account_spec) = undefined;
    var close_data: dataArray(close_account_spec) = undefined;
    _ = closeAccount(&a, &b, &c, &close_metas, &close_data);
    try std.testing.expectEqual(@as(u8, 9), close_data[0]);

    var owner_metas: metasArray(initialize_immutable_owner_spec) = undefined;
    var owner_data: dataArray(initialize_immutable_owner_spec) = undefined;
    _ = initializeImmutableOwner(&a, &owner_metas, &owner_data);
    try std.testing.expectEqual(@as(u8, 22), owner_data[0]);

    var size_metas: metasArray(get_account_data_size_spec) = undefined;
    var size_data: [5]u8 = undefined;
    const size_ix = try getAccountDataSizeForExtensions(&a, &.{ .immutable_owner, .transfer_hook }, &size_metas, &size_data);
    try std.testing.expectEqualSlices(u8, &.{ 21, 7, 0, 14, 0 }, size_ix.data);
    try expectMeta(size_ix.accounts[0], &a, 0, 0);

    var ui_metas: metasArray(get_account_data_size_spec) = undefined;
    var ui_data: [8]u8 = undefined;
    const ui_ix = try uiAmountToAmount(&a, "1.25", &ui_metas, &ui_data);
    try std.testing.expectEqual(@as(usize, 5), ui_ix.data.len);
    try std.testing.expectEqual(@as(u8, 24), ui_ix.data[0]);
    try std.testing.expectEqualStrings("1.25", ui_ix.data[1..]);
}

test "authority lifecycle builders encode canonical bytes and metas" {
    const account: Pubkey = .{0xD1} ** 32;
    const mint: Pubkey = .{0xD2} ** 32;
    const owner: Pubkey = .{0xD3} ** 32;
    const signer: Pubkey = .{0xD4} ** 32;
    const new_authority: Pubkey = .{0xD5} ** 32;
    const signers = [_]Pubkey{signer};
    var metas: [4]AccountMeta = undefined;

    var revoke_data: dataArray(revoke_spec) = undefined;
    const revoked = try revoke(&account, &owner, &signers, &metas, &revoke_data);
    try std.testing.expectEqualSlices(u8, &.{5}, revoked.data);
    try std.testing.expectEqual(@as(usize, 3), revoked.accounts.len);
    try expectMeta(revoked.accounts[0], &account, 1, 0);
    try expectMeta(revoked.accounts[1], &owner, 0, 0);
    try expectMeta(revoked.accounts[2], &signers[0], 0, 1);

    var set_authority_data: dataArray(set_authority_spec) = undefined;
    const set_some = try setAuthority(&mint, &owner, &.{}, .metadata_pointer, &new_authority, &metas, &set_authority_data);
    try std.testing.expectEqual(@as(usize, set_authority_some_data_len), set_some.data.len);
    try std.testing.expectEqualSlices(u8, &.{ 6, 12, 1 }, set_some.data[0..3]);
    try std.testing.expectEqualSlices(u8, &new_authority, set_some.data[3..35]);
    try expectMeta(set_some.accounts[1], &owner, 0, 1);

    const set_none = try setAuthority(&mint, &owner, &signers, .pause, null, &metas, &set_authority_data);
    try std.testing.expectEqualSlices(u8, &.{ 6, 16, 0 }, set_none.data);
    try std.testing.expectEqual(@as(usize, 3), set_none.accounts.len);
    try expectMeta(set_none.accounts[1], &owner, 0, 0);
    try expectMeta(set_none.accounts[2], &signers[0], 0, 1);

    var freeze_data: dataArray(freeze_account_spec) = undefined;
    const frozen = try freezeAccount(&account, &mint, &owner, &signers, &metas, &freeze_data);
    try std.testing.expectEqualSlices(u8, &.{10}, frozen.data);
    try expectMeta(frozen.accounts[0], &account, 1, 0);
    try expectMeta(frozen.accounts[1], &mint, 0, 0);
    try expectMeta(frozen.accounts[2], &owner, 0, 0);
    try expectMeta(frozen.accounts[3], &signers[0], 0, 1);

    var thaw_data: dataArray(thaw_account_spec) = undefined;
    const thawed = try thawAccount(&account, &mint, &owner, &.{}, &metas, &thaw_data);
    try std.testing.expectEqualSlices(u8, &.{11}, thawed.data);
    try std.testing.expectEqual(@as(usize, 3), thawed.accounts.len);
    try expectMeta(thawed.accounts[2], &owner, 0, 1);
}

test "sync native and withdraw excess lamports builders encode canonical bytes" {
    const source: Pubkey = .{0xE1} ** 32;
    const destination: Pubkey = .{0xE2} ** 32;
    const authority: Pubkey = .{0xE3} ** 32;
    const signer: Pubkey = .{0xE4} ** 32;
    const signers = [_]Pubkey{signer};
    var sync_metas: metasArray(sync_native_spec) = undefined;
    var sync_data: dataArray(sync_native_spec) = undefined;
    var withdraw_metas: [4]AccountMeta = undefined;
    var withdraw_data: [withdraw_excess_lamports_data_len]u8 = undefined;

    const synced = syncNative(&source, &sync_metas, &sync_data);
    try std.testing.expectEqualSlices(u8, &.{17}, synced.data);
    try expectMeta(synced.accounts[0], &source, 1, 0);

    const withdrawn = try withdrawExcessLamports(&source, &destination, &authority, &signers, &withdraw_metas, &withdraw_data);
    try std.testing.expectEqualSlices(u8, &.{38}, withdrawn.data);
    try std.testing.expectEqual(@as(usize, 4), withdrawn.accounts.len);
    try expectMeta(withdrawn.accounts[0], &source, 1, 0);
    try expectMeta(withdrawn.accounts[1], &destination, 1, 0);
    try expectMeta(withdrawn.accounts[2], &authority, 0, 0);
    try expectMeta(withdrawn.accounts[3], &signers[0], 0, 1);
}

test "mint close authority and non-transferable initializers encode canonical bytes" {
    const mint: Pubkey = .{0xB1} ** 32;
    const close_authority: Pubkey = .{0xB2} ** 32;
    var close_metas: metasArray(initialize_mint_close_authority_spec) = undefined;
    var close_data: dataArray(initialize_mint_close_authority_spec) = undefined;
    var non_transferable_metas: metasArray(initialize_non_transferable_mint_spec) = undefined;
    var non_transferable_data: dataArray(initialize_non_transferable_mint_spec) = undefined;

    const some_close = initializeMintCloseAuthority(&mint, &close_authority, &close_metas, &close_data);
    try std.testing.expectEqual(@as(usize, initialize_mint_close_authority_some_data_len), some_close.data.len);
    try std.testing.expectEqual(@as(u8, 25), some_close.data[0]);
    try std.testing.expectEqual(@as(u8, 1), some_close.data[1]);
    try std.testing.expectEqualSlices(u8, &close_authority, some_close.data[2..34]);
    try expectMeta(some_close.accounts[0], &mint, 1, 0);

    const none_close = initializeMintCloseAuthority(&mint, null, &close_metas, &close_data);
    try std.testing.expectEqual(@as(usize, initialize_mint_close_authority_none_data_len), none_close.data.len);
    try std.testing.expectEqualSlices(u8, &.{ 25, 0 }, none_close.data);

    const non_transferable = initializeNonTransferableMint(&mint, &non_transferable_metas, &non_transferable_data);
    try std.testing.expectEqualSlices(u8, &.{32}, non_transferable.data);
    try expectMeta(non_transferable.accounts[0], &mint, 1, 0);
}

test "create native mint builder encodes canonical account metas" {
    const payer: Pubkey = .{0xC1} ** 32;
    var metas: metasArray(create_native_mint_spec) = undefined;
    var data: dataArray(create_native_mint_spec) = undefined;

    const built = createNativeMint(&payer, &metas, &data);
    try std.testing.expectEqualSlices(u8, &.{31}, built.data);
    try std.testing.expectEqual(@as(usize, 3), built.accounts.len);
    try expectMeta(built.accounts[0], &payer, 1, 1);
    try expectMeta(built.accounts[1], &id.NATIVE_MINT, 1, 0);
    try expectMeta(built.accounts[2], &sol.system_program_id, 0, 0);
}

test "reallocate builder encodes extension type list and authority metas" {
    const account: Pubkey = .{0xBA} ** 32;
    const payer: Pubkey = .{0xBB} ** 32;
    const owner: Pubkey = .{0xBC} ** 32;
    const signers = [_]Pubkey{.{0xBD} ** 32};
    const extension_types = [_]ExtensionType{ .transfer_hook, .permanent_delegate };
    var metas: [5]AccountMeta = undefined;
    var data: [16]u8 = undefined;

    const built = try reallocate(&account, &payer, &owner, &signers, &extension_types, &metas, &data);
    try std.testing.expectEqual(@as(usize, 5), built.accounts.len);
    try expectMeta(built.accounts[0], &account, 1, 0);
    try expectMeta(built.accounts[1], &payer, 1, 1);
    try expectMeta(built.accounts[2], &sol.system_program_id, 0, 0);
    try expectMeta(built.accounts[3], &owner, 0, 0);
    try expectMeta(built.accounts[4], &signers[0], 0, 1);
    try std.testing.expectEqualSlices(u8, &.{ 29, 14, 0, 12, 0 }, built.data);
}

test "transfer fee config builder encodes compact optional authorities" {
    const mint: Pubkey = .{0x21} ** 32;
    const authority: Pubkey = .{0x22} ** 32;
    var metas: metasArray(get_account_data_size_spec) = undefined;
    var data: [transfer_fee_initialize_config_some_data_len]u8 = undefined;

    const built = try initializeTransferFeeConfig(&mint, &authority, null, 111, 999, &metas, &data);
    try std.testing.expectEqual(&id.PROGRAM_ID, built.program_id);
    try std.testing.expectEqual(@as(usize, 46), built.data.len);
    try std.testing.expectEqual(@as(u8, 26), built.data[0]);
    try std.testing.expectEqual(@as(u8, 0), built.data[1]);
    try std.testing.expectEqual(@as(u8, 1), built.data[2]);
    try std.testing.expectEqualSlices(u8, &authority, built.data[3..35]);
    try std.testing.expectEqual(@as(u8, 0), built.data[35]);
    try std.testing.expectEqual(@as(u16, 111), std.mem.readInt(u16, built.data[36..38], .little));
    try std.testing.expectEqual(@as(u64, 999), std.mem.readInt(u64, built.data[38..46], .little));
    try expectMeta(built.accounts[0], &mint, 1, 0);

    const none_built = try initializeTransferFeeConfig(&mint, null, null, 1, 2, &metas, &data);
    try std.testing.expectEqual(@as(usize, transfer_fee_initialize_config_none_data_len), none_built.data.len);
    try std.testing.expectEqual(@as(u8, 0), none_built.data[2]);
    try std.testing.expectEqual(@as(u8, 0), none_built.data[3]);
}

test "confidential transfer mint and account builders encode canonical bytes" {
    const mint: Pubkey = .{0x25} ** 32;
    const account: Pubkey = .{0x26} ** 32;
    const destination: Pubkey = .{0x24} ** 32;
    const authority: Pubkey = .{0x27} ** 32;
    const signer: Pubkey = .{0x28} ** 32;
    const auditor: [32]u8 = .{0x29} ** 32;
    const decryptable: [36]u8 = .{0x2a} ** 36;
    const context_state: Pubkey = .{0x2b} ** 32;
    const range_context_state: Pubkey = .{0x2c} ** 32;
    const validity_context_state: Pubkey = .{0x2d} ** 32;
    const elgamal_registry: Pubkey = .{0x30} ** 32;
    const payer: Pubkey = .{0x31} ** 32;
    const cipher_lo: [64]u8 = .{0x2e} ** 64;
    const cipher_hi: [64]u8 = .{0x2f} ** 64;
    const signers = [_]Pubkey{signer};

    var init_metas: metasArray(get_account_data_size_spec) = undefined;
    var init_data: [confidential_transfer_initialize_mint_data_len]u8 = undefined;
    const init = initializeConfidentialTransferMint(&mint, &authority, true, &auditor, &init_metas, &init_data);
    try std.testing.expectEqualSlices(u8, &.{ 27, 0 }, init.data[0..2]);
    try std.testing.expectEqualSlices(u8, &authority, init.data[2..34]);
    try std.testing.expectEqual(@as(u8, 1), init.data[34]);
    try std.testing.expectEqualSlices(u8, &auditor, init.data[35..67]);
    try expectMeta(init.accounts[0], &mint, 1, 0);

    var update_metas: [3]AccountMeta = undefined;
    var update_data: [confidential_transfer_update_mint_data_len]u8 = undefined;
    const updated = try updateConfidentialTransferMint(&mint, &authority, &signers, false, null, &update_metas, &update_data);
    try std.testing.expectEqualSlices(u8, &.{ 27, 1, 0 }, updated.data[0..3]);
    for (updated.data[3..35]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
    try std.testing.expectEqual(@as(usize, 3), updated.accounts.len);
    try expectMeta(updated.accounts[0], &mint, 1, 0);
    try expectMeta(updated.accounts[1], &authority, 0, 0);
    try expectMeta(updated.accounts[2], &signers[0], 0, 1);

    var configure_metas: [4]AccountMeta = undefined;
    var configure_data: [confidential_transfer_configure_account_data_len]u8 = undefined;
    const configured = try configureConfidentialTransferAccount(
        &account,
        &mint,
        &decryptable,
        9,
        &authority,
        &.{},
        .{ .context_state_account = &context_state },
        &configure_metas,
        &configure_data,
    );
    try std.testing.expectEqualSlices(u8, &.{ 27, 2 }, configured.data[0..2]);
    try std.testing.expectEqualSlices(u8, &decryptable, configured.data[2..38]);
    try std.testing.expectEqual(@as(u64, 9), std.mem.readInt(u64, configured.data[38..46], .little));
    try std.testing.expectEqual(@as(u8, 0), configured.data[46]);
    try expectMeta(configured.accounts[0], &account, 1, 0);
    try expectMeta(configured.accounts[1], &mint, 0, 0);
    try expectMeta(configured.accounts[2], &context_state, 0, 0);
    try expectMeta(configured.accounts[3], &authority, 0, 1);

    var registry_metas: [5]AccountMeta = undefined;
    var registry_data: [confidential_transfer_configure_account_with_registry_data_len]u8 = undefined;
    const configured_with_registry = try configureConfidentialTransferAccountWithRegistry(
        &account,
        &mint,
        &elgamal_registry,
        &payer,
        &registry_metas,
        &registry_data,
    );
    try std.testing.expectEqualSlices(u8, &.{ 27, 14 }, configured_with_registry.data);
    try std.testing.expectEqual(@as(usize, 5), configured_with_registry.accounts.len);
    try expectMeta(configured_with_registry.accounts[0], &account, 1, 0);
    try expectMeta(configured_with_registry.accounts[1], &mint, 0, 0);
    try expectMeta(configured_with_registry.accounts[2], &elgamal_registry, 0, 0);
    try expectMeta(configured_with_registry.accounts[3], &payer, 1, 1);
    try expectMeta(configured_with_registry.accounts[4], &sol.system_program_id, 0, 0);

    var approve_metas: [4]AccountMeta = undefined;
    var approve_data: [confidential_transfer_approve_account_data_len]u8 = undefined;
    const approved = try approveConfidentialTransferAccount(&account, &mint, &authority, &signers, &approve_metas, &approve_data);
    try std.testing.expectEqualSlices(u8, &.{ 27, 3 }, approved.data);
    try expectMeta(approved.accounts[0], &account, 1, 0);
    try expectMeta(approved.accounts[1], &mint, 0, 0);
    try expectMeta(approved.accounts[2], &authority, 0, 0);
    try expectMeta(approved.accounts[3], &signers[0], 0, 1);

    var empty_metas: [4]AccountMeta = undefined;
    var empty_data: [confidential_transfer_empty_account_data_len]u8 = undefined;
    const emptied = try emptyConfidentialTransferAccount(
        &account,
        &authority,
        &signers,
        .{ .instruction_offset = -1 },
        &empty_metas,
        &empty_data,
    );
    try std.testing.expectEqualSlices(u8, &.{ 27, 4, 0xff }, emptied.data);
    try expectMeta(emptied.accounts[0], &account, 1, 0);
    try expectMeta(emptied.accounts[1], &sol.instructions_sysvar_id, 0, 0);
    try expectMeta(emptied.accounts[2], &authority, 0, 0);
    try expectMeta(emptied.accounts[3], &signers[0], 0, 1);

    var deposit_metas: [4]AccountMeta = undefined;
    var deposit_data: [confidential_transfer_deposit_data_len]u8 = undefined;
    const deposited = try depositConfidentialTransfer(&account, &mint, &authority, &signers, 1234, 6, &deposit_metas, &deposit_data);
    try std.testing.expectEqualSlices(u8, &.{ 27, 5 }, deposited.data[0..2]);
    try std.testing.expectEqual(@as(u64, 1234), std.mem.readInt(u64, deposited.data[2..10], .little));
    try std.testing.expectEqual(@as(u8, 6), deposited.data[10]);

    var withdraw_metas: [6]AccountMeta = undefined;
    var withdraw_data: [confidential_transfer_withdraw_data_len]u8 = undefined;
    const withdrawn = try withdrawConfidentialTransfer(
        &account,
        &mint,
        4321,
        5,
        &decryptable,
        &authority,
        &signers,
        .{ .instruction_offset = 1 },
        .{ .context_state_account = &range_context_state },
        &withdraw_metas,
        &withdraw_data,
    );
    try std.testing.expectEqualSlices(u8, &.{ 27, 6 }, withdrawn.data[0..2]);
    try std.testing.expectEqual(@as(u64, 4321), std.mem.readInt(u64, withdrawn.data[2..10], .little));
    try std.testing.expectEqual(@as(u8, 5), withdrawn.data[10]);
    try std.testing.expectEqualSlices(u8, &decryptable, withdrawn.data[11..47]);
    try std.testing.expectEqual(@as(u8, 1), withdrawn.data[47]);
    try std.testing.expectEqual(@as(u8, 0), withdrawn.data[48]);
    try std.testing.expectEqual(@as(usize, 6), withdrawn.accounts.len);
    try expectMeta(withdrawn.accounts[0], &account, 1, 0);
    try expectMeta(withdrawn.accounts[1], &mint, 0, 0);
    try expectMeta(withdrawn.accounts[2], &sol.instructions_sysvar_id, 0, 0);
    try expectMeta(withdrawn.accounts[3], &range_context_state, 0, 0);
    try expectMeta(withdrawn.accounts[4], &authority, 0, 0);
    try expectMeta(withdrawn.accounts[5], &signers[0], 0, 1);

    var transfer_metas: [7]AccountMeta = undefined;
    var transfer_data: [confidential_transfer_transfer_data_len]u8 = undefined;
    const transferred = try transferConfidentialTransfer(
        &account,
        &mint,
        &destination,
        &decryptable,
        &cipher_lo,
        &cipher_hi,
        &authority,
        &.{},
        .{ .context_state_account = &context_state },
        .{ .context_state_account = &validity_context_state },
        .{ .context_state_account = &range_context_state },
        &transfer_metas,
        &transfer_data,
    );
    try std.testing.expectEqualSlices(u8, &.{ 27, 7 }, transferred.data[0..2]);
    try std.testing.expectEqualSlices(u8, &decryptable, transferred.data[2..38]);
    try std.testing.expectEqualSlices(u8, &cipher_lo, transferred.data[38..102]);
    try std.testing.expectEqualSlices(u8, &cipher_hi, transferred.data[102..166]);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0 }, transferred.data[166..169]);
    try std.testing.expectEqual(@as(usize, 7), transferred.accounts.len);
    try expectMeta(transferred.accounts[0], &account, 1, 0);
    try expectMeta(transferred.accounts[1], &mint, 0, 0);
    try expectMeta(transferred.accounts[2], &destination, 1, 0);
    try expectMeta(transferred.accounts[3], &context_state, 0, 0);
    try expectMeta(transferred.accounts[4], &validity_context_state, 0, 0);
    try expectMeta(transferred.accounts[5], &range_context_state, 0, 0);
    try expectMeta(transferred.accounts[6], &authority, 0, 1);

    var transfer_fee_metas: [6]AccountMeta = undefined;
    var transfer_fee_data: [confidential_transfer_transfer_with_fee_data_len]u8 = undefined;
    const transferred_with_fee = try transferConfidentialTransferWithFee(
        &account,
        &mint,
        &destination,
        &decryptable,
        &cipher_lo,
        &cipher_hi,
        &authority,
        &signers,
        .{ .instruction_offset = 1 },
        .{ .instruction_offset = 2 },
        .{ .instruction_offset = 3 },
        .{ .instruction_offset = 4 },
        .{ .instruction_offset = 5 },
        &transfer_fee_metas,
        &transfer_fee_data,
    );
    try std.testing.expectEqualSlices(u8, &.{ 27, 13 }, transferred_with_fee.data[0..2]);
    try std.testing.expectEqualSlices(u8, &decryptable, transferred_with_fee.data[2..38]);
    try std.testing.expectEqualSlices(u8, &cipher_lo, transferred_with_fee.data[38..102]);
    try std.testing.expectEqualSlices(u8, &cipher_hi, transferred_with_fee.data[102..166]);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4, 5 }, transferred_with_fee.data[166..171]);
    try std.testing.expectEqual(@as(usize, 6), transferred_with_fee.accounts.len);
    try expectMeta(transferred_with_fee.accounts[0], &account, 1, 0);
    try expectMeta(transferred_with_fee.accounts[1], &mint, 0, 0);
    try expectMeta(transferred_with_fee.accounts[2], &destination, 1, 0);
    try expectMeta(transferred_with_fee.accounts[3], &sol.instructions_sysvar_id, 0, 0);
    try expectMeta(transferred_with_fee.accounts[4], &authority, 0, 0);
    try expectMeta(transferred_with_fee.accounts[5], &signers[0], 0, 1);

    var apply_metas: [3]AccountMeta = undefined;
    var apply_data: [confidential_transfer_apply_pending_balance_data_len]u8 = undefined;
    const applied = try applyPendingConfidentialTransferBalance(&account, &authority, &signers, 7, &decryptable, &apply_metas, &apply_data);
    try std.testing.expectEqualSlices(u8, &.{ 27, 8 }, applied.data[0..2]);
    try std.testing.expectEqual(@as(u64, 7), std.mem.readInt(u64, applied.data[2..10], .little));
    try std.testing.expectEqualSlices(u8, &decryptable, applied.data[10..46]);

    var toggle_metas: [3]AccountMeta = undefined;
    var toggle_data: [confidential_transfer_toggle_credits_data_len]u8 = undefined;
    const enabled = try enableConfidentialTransferCredits(&account, &authority, &signers, &toggle_metas, &toggle_data);
    try std.testing.expectEqualSlices(u8, &.{ 27, 9 }, enabled.data);
    const disabled = try disableNonConfidentialTransferCredits(&account, &authority, &.{}, &toggle_metas, &toggle_data);
    try std.testing.expectEqualSlices(u8, &.{ 27, 12 }, disabled.data);
    try expectMeta(disabled.accounts[1], &authority, 0, 1);
}

test "confidential transfer fee builders encode canonical bytes" {
    const mint: Pubkey = .{0x2b} ** 32;
    const authority: Pubkey = .{0x2c} ** 32;
    const signer: Pubkey = .{0x2d} ** 32;
    const elgamal: [32]u8 = .{0x2e} ** 32;
    const destination: Pubkey = .{0x2a} ** 32;
    const context_state: Pubkey = .{0x24} ** 32;
    const decryptable: [36]u8 = .{0x23} ** 36;
    const sources = [_]Pubkey{ .{0x2f} ** 32, .{0x30} ** 32 };
    const signers = [_]Pubkey{signer};

    var init_metas: metasArray(get_account_data_size_spec) = undefined;
    var init_data: [confidential_transfer_fee_initialize_config_data_len]u8 = undefined;
    const init = initializeConfidentialTransferFeeConfig(&mint, &authority, &elgamal, &init_metas, &init_data);
    try std.testing.expectEqualSlices(u8, &.{ 37, 0 }, init.data[0..2]);
    try std.testing.expectEqualSlices(u8, &authority, init.data[2..34]);
    try std.testing.expectEqualSlices(u8, &elgamal, init.data[34..66]);
    try expectMeta(init.accounts[0], &mint, 1, 0);

    var withdraw_mint_metas: [5]AccountMeta = undefined;
    var withdraw_mint_data: [confidential_transfer_fee_withdraw_withheld_tokens_from_mint_data_len]u8 = undefined;
    const withdraw_mint = try withdrawConfidentialTransferFeeWithheldTokensFromMint(
        &mint,
        &destination,
        &decryptable,
        &authority,
        &signers,
        .{ .instruction_offset = 1 },
        &withdraw_mint_metas,
        &withdraw_mint_data,
    );
    try std.testing.expectEqualSlices(u8, &.{ 37, 1, 1 }, withdraw_mint.data[0..3]);
    try std.testing.expectEqualSlices(u8, &decryptable, withdraw_mint.data[3..39]);
    try std.testing.expectEqual(@as(usize, 5), withdraw_mint.accounts.len);
    try expectMeta(withdraw_mint.accounts[0], &mint, 1, 0);
    try expectMeta(withdraw_mint.accounts[1], &destination, 1, 0);
    try expectMeta(withdraw_mint.accounts[2], &sol.instructions_sysvar_id, 0, 0);
    try expectMeta(withdraw_mint.accounts[3], &authority, 0, 0);
    try expectMeta(withdraw_mint.accounts[4], &signers[0], 0, 1);

    var withdraw_accounts_metas: [6]AccountMeta = undefined;
    var withdraw_accounts_data: [confidential_transfer_fee_withdraw_withheld_tokens_from_accounts_data_len]u8 = undefined;
    const withdraw_accounts = try withdrawConfidentialTransferFeeWithheldTokensFromAccounts(
        &mint,
        &destination,
        &decryptable,
        &authority,
        &.{},
        &sources,
        .{ .context_state_account = &context_state },
        &withdraw_accounts_metas,
        &withdraw_accounts_data,
    );
    try std.testing.expectEqualSlices(u8, &.{ 37, 2, 2, 0 }, withdraw_accounts.data[0..4]);
    try std.testing.expectEqualSlices(u8, &decryptable, withdraw_accounts.data[4..40]);
    try std.testing.expectEqual(@as(usize, 6), withdraw_accounts.accounts.len);
    try expectMeta(withdraw_accounts.accounts[0], &mint, 0, 0);
    try expectMeta(withdraw_accounts.accounts[1], &destination, 1, 0);
    try expectMeta(withdraw_accounts.accounts[2], &context_state, 0, 0);
    try expectMeta(withdraw_accounts.accounts[3], &authority, 0, 1);
    try expectMeta(withdraw_accounts.accounts[4], &sources[0], 1, 0);
    try expectMeta(withdraw_accounts.accounts[5], &sources[1], 1, 0);

    var harvest_metas: [3]AccountMeta = undefined;
    var harvest_data: [confidential_transfer_fee_harvest_withheld_tokens_to_mint_data_len]u8 = undefined;
    const harvest = try harvestConfidentialTransferWithheldTokensToMint(&mint, &sources, &harvest_metas, &harvest_data);
    try std.testing.expectEqualSlices(u8, &.{ 37, 3 }, harvest.data);
    try std.testing.expectEqual(@as(usize, 3), harvest.accounts.len);
    try expectMeta(harvest.accounts[0], &mint, 1, 0);
    try expectMeta(harvest.accounts[1], &sources[0], 1, 0);
    try expectMeta(harvest.accounts[2], &sources[1], 1, 0);

    var toggle_metas: [3]AccountMeta = undefined;
    var toggle_data: [confidential_transfer_fee_toggle_harvest_to_mint_data_len]u8 = undefined;
    const enabled = try enableConfidentialTransferFeeHarvestToMint(&mint, &authority, &signers, &toggle_metas, &toggle_data);
    try std.testing.expectEqualSlices(u8, &.{ 37, 4 }, enabled.data);
    try std.testing.expectEqual(@as(usize, 3), enabled.accounts.len);
    try expectMeta(enabled.accounts[0], &mint, 1, 0);
    try expectMeta(enabled.accounts[1], &authority, 0, 0);
    try expectMeta(enabled.accounts[2], &signers[0], 0, 1);

    const disabled = try disableConfidentialTransferFeeHarvestToMint(&mint, &authority, &.{}, &toggle_metas, &toggle_data);
    try std.testing.expectEqualSlices(u8, &.{ 37, 5 }, disabled.data);
    try std.testing.expectEqual(@as(usize, 2), disabled.accounts.len);
    try expectMeta(disabled.accounts[1], &authority, 0, 1);
}

test "transfer fee authority builders support single and multisig account metas" {
    const source: Pubkey = .{0x31} ** 32;
    const mint: Pubkey = .{0x32} ** 32;
    const destination: Pubkey = .{0x33} ** 32;
    const authority: Pubkey = .{0x34} ** 32;
    const signers = [_]Pubkey{ .{0x35} ** 32, .{0x36} ** 32 };
    var metas: [6]AccountMeta = undefined;
    var data: [transfer_fee_transfer_checked_with_fee_data_len]u8 = undefined;

    const single = try transferCheckedWithFee(
        &source,
        &mint,
        &destination,
        &authority,
        &.{},
        500,
        6,
        7,
        &metas,
        &data,
    );
    try std.testing.expectEqual(@as(usize, 4), single.accounts.len);
    try std.testing.expectEqual(@as(u8, 26), single.data[0]);
    try std.testing.expectEqual(@as(u8, 1), single.data[1]);
    try std.testing.expectEqual(@as(u64, 500), std.mem.readInt(u64, single.data[2..10], .little));
    try std.testing.expectEqual(@as(u8, 6), single.data[10]);
    try std.testing.expectEqual(@as(u64, 7), std.mem.readInt(u64, single.data[11..19], .little));
    try expectMeta(single.accounts[3], &authority, 0, 1);

    const multi = try transferCheckedWithFee(
        &source,
        &mint,
        &destination,
        &authority,
        &signers,
        500,
        6,
        7,
        &metas,
        &data,
    );
    try std.testing.expectEqual(@as(usize, 6), multi.accounts.len);
    try expectMeta(multi.accounts[3], &authority, 0, 0);
    try expectMeta(multi.accounts[4], &signers[0], 0, 1);
    try expectMeta(multi.accounts[5], &signers[1], 0, 1);
}

test "transfer fee withdraw harvest and set builders encode canonical bytes" {
    const mint: Pubkey = .{0x41} ** 32;
    const destination: Pubkey = .{0x42} ** 32;
    const authority: Pubkey = .{0x43} ** 32;
    const signers = [_]Pubkey{.{0x44} ** 32};
    const sources = [_]Pubkey{ .{0x45} ** 32, .{0x46} ** 32 };
    var metas: [8]AccountMeta = undefined;

    var withdraw_mint_data: [transfer_fee_withdraw_withheld_tokens_from_mint_data_len]u8 = undefined;
    const withdraw_mint = try withdrawWithheldTokensFromMint(
        &mint,
        &destination,
        &authority,
        &signers,
        &metas,
        &withdraw_mint_data,
    );
    try std.testing.expectEqualSlices(u8, &.{ 26, 2 }, withdraw_mint.data);
    try std.testing.expectEqual(@as(usize, 4), withdraw_mint.accounts.len);
    try expectMeta(withdraw_mint.accounts[0], &mint, 1, 0);
    try expectMeta(withdraw_mint.accounts[2], &authority, 0, 0);
    try expectMeta(withdraw_mint.accounts[3], &signers[0], 0, 1);

    var withdraw_accounts_data: [transfer_fee_withdraw_withheld_tokens_from_accounts_data_len]u8 = undefined;
    const withdraw_accounts = try withdrawWithheldTokensFromAccounts(
        &mint,
        &destination,
        &authority,
        &signers,
        &sources,
        &metas,
        &withdraw_accounts_data,
    );
    try std.testing.expectEqualSlices(u8, &.{ 26, 3, 2 }, withdraw_accounts.data);
    try std.testing.expectEqual(@as(usize, 6), withdraw_accounts.accounts.len);
    try expectMeta(withdraw_accounts.accounts[0], &mint, 0, 0);
    try expectMeta(withdraw_accounts.accounts[4], &sources[0], 1, 0);
    try expectMeta(withdraw_accounts.accounts[5], &sources[1], 1, 0);

    var harvest_data: [transfer_fee_harvest_withheld_tokens_to_mint_data_len]u8 = undefined;
    const harvest = try harvestWithheldTokensToMint(&mint, &sources, &metas, &harvest_data);
    try std.testing.expectEqualSlices(u8, &.{ 26, 4 }, harvest.data);
    try std.testing.expectEqual(@as(usize, 3), harvest.accounts.len);
    try expectMeta(harvest.accounts[0], &mint, 1, 0);
    try expectMeta(harvest.accounts[2], &sources[1], 1, 0);

    var set_fee_data: [transfer_fee_set_transfer_fee_data_len]u8 = undefined;
    const set_fee = try setTransferFee(&mint, &authority, &signers, 250, 10_000, &metas, &set_fee_data);
    try std.testing.expectEqual(@as(u8, 26), set_fee.data[0]);
    try std.testing.expectEqual(@as(u8, 5), set_fee.data[1]);
    try std.testing.expectEqual(@as(u16, 250), std.mem.readInt(u16, set_fee.data[2..4], .little));
    try std.testing.expectEqual(@as(u64, 10_000), std.mem.readInt(u64, set_fee.data[4..12], .little));
    try std.testing.expectEqual(@as(usize, 3), set_fee.accounts.len);
    try expectMeta(set_fee.accounts[0], &mint, 1, 0);
    try expectMeta(set_fee.accounts[1], &authority, 0, 0);
    try expectMeta(set_fee.accounts[2], &signers[0], 0, 1);
}

test "default account state builders encode canonical bytes and authority metas" {
    const mint: Pubkey = .{0x51} ** 32;
    const authority: Pubkey = .{0x52} ** 32;
    const signers = [_]Pubkey{.{0x53} ** 32};
    var init_metas: metasArray(get_account_data_size_spec) = undefined;
    var metas: [3]AccountMeta = undefined;
    var data: [default_account_state_data_len]u8 = undefined;

    const init = initializeDefaultAccountState(&mint, .frozen, &init_metas, &data);
    try std.testing.expectEqualSlices(u8, &.{ 28, 0, 2 }, init.data);
    try std.testing.expectEqual(@as(usize, 1), init.accounts.len);
    try expectMeta(init.accounts[0], &mint, 1, 0);

    const single = try updateDefaultAccountState(&mint, &authority, &.{}, .initialized, &metas, &data);
    try std.testing.expectEqualSlices(u8, &.{ 28, 1, 1 }, single.data);
    try std.testing.expectEqual(@as(usize, 2), single.accounts.len);
    try expectMeta(single.accounts[0], &mint, 1, 0);
    try expectMeta(single.accounts[1], &authority, 0, 1);

    const multi = try updateDefaultAccountState(&mint, &authority, &signers, .frozen, &metas, &data);
    try std.testing.expectEqualSlices(u8, &.{ 28, 1, 2 }, multi.data);
    try std.testing.expectEqual(@as(usize, 3), multi.accounts.len);
    try expectMeta(multi.accounts[1], &authority, 0, 0);
    try expectMeta(multi.accounts[2], &signers[0], 0, 1);
}

test "memo transfer builders encode canonical bytes and authority metas" {
    const account: Pubkey = .{0x61} ** 32;
    const owner: Pubkey = .{0x62} ** 32;
    const signers = [_]Pubkey{ .{0x63} ** 32, .{0x64} ** 32 };
    var metas: [4]AccountMeta = undefined;
    var data: [memo_transfer_data_len]u8 = undefined;

    const enable = try enableRequiredTransferMemos(&account, &owner, &.{}, &metas, &data);
    try std.testing.expectEqualSlices(u8, &.{ 30, 0 }, enable.data);
    try std.testing.expectEqual(@as(usize, 2), enable.accounts.len);
    try expectMeta(enable.accounts[0], &account, 1, 0);
    try expectMeta(enable.accounts[1], &owner, 0, 1);

    const disable = try disableRequiredTransferMemos(&account, &owner, &signers, &metas, &data);
    try std.testing.expectEqualSlices(u8, &.{ 30, 1 }, disable.data);
    try std.testing.expectEqual(@as(usize, 4), disable.accounts.len);
    try expectMeta(disable.accounts[1], &owner, 0, 0);
    try expectMeta(disable.accounts[2], &signers[0], 0, 1);
    try expectMeta(disable.accounts[3], &signers[1], 0, 1);
}

test "cpi guard builders encode canonical bytes and authority metas" {
    const account: Pubkey = .{0x71} ** 32;
    const owner: Pubkey = .{0x72} ** 32;
    const signers = [_]Pubkey{.{0x73} ** 32};
    var metas: [3]AccountMeta = undefined;
    var data: [cpi_guard_data_len]u8 = undefined;

    const enable = try enableCpiGuard(&account, &owner, &.{}, &metas, &data);
    try std.testing.expectEqualSlices(u8, &.{ 34, 0 }, enable.data);
    try std.testing.expectEqual(@as(usize, 2), enable.accounts.len);
    try expectMeta(enable.accounts[0], &account, 1, 0);
    try expectMeta(enable.accounts[1], &owner, 0, 1);

    const disable = try disableCpiGuard(&account, &owner, &signers, &metas, &data);
    try std.testing.expectEqualSlices(u8, &.{ 34, 1 }, disable.data);
    try std.testing.expectEqual(@as(usize, 3), disable.accounts.len);
    try expectMeta(disable.accounts[1], &owner, 0, 0);
    try expectMeta(disable.accounts[2], &signers[0], 0, 1);
}

test "interest-bearing mint builders encode canonical bytes and authority metas" {
    const mint: Pubkey = .{0x75} ** 32;
    const authority: Pubkey = .{0x76} ** 32;
    const signer: Pubkey = .{0x77} ** 32;
    const signers = [_]Pubkey{signer};
    var init_metas: metasArray(get_account_data_size_spec) = undefined;
    var metas: [3]AccountMeta = undefined;
    var init_data: [interest_bearing_initialize_data_len]u8 = undefined;
    var update_data: [interest_bearing_update_rate_data_len]u8 = undefined;

    const init = initializeInterestBearingMint(&mint, &authority, -125, &init_metas, &init_data);
    try std.testing.expectEqualSlices(u8, &.{ 33, 0 }, init.data[0..2]);
    try std.testing.expectEqualSlices(u8, &authority, init.data[2..34]);
    try std.testing.expectEqual(@as(i16, -125), std.mem.readInt(i16, init.data[34..36], .little));
    try expectMeta(init.accounts[0], &mint, 1, 0);

    const none_init = initializeInterestBearingMint(&mint, null, 250, &init_metas, &init_data);
    for (none_init.data[2..34]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
    try std.testing.expectEqual(@as(i16, 250), std.mem.readInt(i16, none_init.data[34..36], .little));

    const update = try updateInterestBearingRate(&mint, &authority, &signers, 500, &metas, &update_data);
    try std.testing.expectEqualSlices(u8, &.{ 33, 1 }, update.data[0..2]);
    try std.testing.expectEqual(@as(i16, 500), std.mem.readInt(i16, update.data[2..4], .little));
    try std.testing.expectEqual(@as(usize, 3), update.accounts.len);
    try expectMeta(update.accounts[0], &mint, 1, 0);
    try expectMeta(update.accounts[1], &authority, 0, 0);
    try expectMeta(update.accounts[2], &signers[0], 0, 1);
}

test "permanent delegate builder encodes canonical bytes" {
    const mint: Pubkey = .{0x78} ** 32;
    const delegate: Pubkey = .{0x79} ** 32;
    var metas: metasArray(get_account_data_size_spec) = undefined;
    var data: [initialize_permanent_delegate_data_len]u8 = undefined;

    const init = initializePermanentDelegate(&mint, &delegate, &metas, &data);
    try std.testing.expectEqual(@as(u8, 35), init.data[0]);
    try std.testing.expectEqualSlices(u8, &delegate, init.data[1..33]);
    try std.testing.expectEqual(@as(usize, 1), init.accounts.len);
    try expectMeta(init.accounts[0], &mint, 1, 0);
}

test "pausable builders encode canonical bytes and authority metas" {
    const mint: Pubkey = .{0x81} ** 32;
    const authority: Pubkey = .{0x82} ** 32;
    const signers = [_]Pubkey{ .{0x83} ** 32, .{0x84} ** 32 };
    var init_metas: metasArray(get_account_data_size_spec) = undefined;
    var metas: [4]AccountMeta = undefined;
    var init_data: [pausable_initialize_data_len]u8 = undefined;
    var data: [pausable_toggle_data_len]u8 = undefined;

    const init = initializePausable(&mint, &authority, &init_metas, &init_data);
    try std.testing.expectEqual(@as(usize, pausable_initialize_data_len), init.data.len);
    try std.testing.expectEqualSlices(u8, &.{ 44, 0 }, init.data[0..2]);
    try std.testing.expectEqualSlices(u8, &authority, init.data[2..34]);
    try expectMeta(init.accounts[0], &mint, 1, 0);

    const paused = try pausePausable(&mint, &authority, &.{}, &metas, &data);
    try std.testing.expectEqualSlices(u8, &.{ 44, 1 }, paused.data);
    try std.testing.expectEqual(@as(usize, 2), paused.accounts.len);
    try expectMeta(paused.accounts[1], &authority, 0, 1);

    const resumed = try resumePausable(&mint, &authority, &signers, &metas, &data);
    try std.testing.expectEqualSlices(u8, &.{ 44, 2 }, resumed.data);
    try std.testing.expectEqual(@as(usize, 4), resumed.accounts.len);
    try expectMeta(resumed.accounts[1], &authority, 0, 0);
    try expectMeta(resumed.accounts[2], &signers[0], 0, 1);
    try expectMeta(resumed.accounts[3], &signers[1], 0, 1);
}

test "pointer extension builders encode canonical bytes and authority metas" {
    const mint: Pubkey = .{0x91} ** 32;
    const authority: Pubkey = .{0x92} ** 32;
    const target: Pubkey = .{0x93} ** 32;
    const signer: Pubkey = .{0x94} ** 32;
    const signers = [_]Pubkey{signer};
    var init_metas: metasArray(get_account_data_size_spec) = undefined;
    var metas: [3]AccountMeta = undefined;
    var init_data: [pointer_initialize_data_len]u8 = undefined;
    var update_data: [pointer_update_data_len]u8 = undefined;

    const metadata_init = initializeMetadataPointer(&mint, &authority, &target, &init_metas, &init_data);
    try std.testing.expectEqualSlices(u8, &.{ 39, 0 }, metadata_init.data[0..2]);
    try std.testing.expectEqualSlices(u8, &authority, metadata_init.data[2..34]);
    try std.testing.expectEqualSlices(u8, &target, metadata_init.data[34..66]);
    try expectMeta(metadata_init.accounts[0], &mint, 1, 0);

    const metadata_update = try updateMetadataPointer(&mint, &authority, &signers, null, &metas, &update_data);
    try std.testing.expectEqualSlices(u8, &.{ 39, 1 }, metadata_update.data[0..2]);
    for (metadata_update.data[2..34]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
    try std.testing.expectEqual(@as(usize, 3), metadata_update.accounts.len);
    try expectMeta(metadata_update.accounts[1], &authority, 0, 0);
    try expectMeta(metadata_update.accounts[2], &signers[0], 0, 1);

    const group_init = initializeGroupPointer(&mint, null, &target, &init_metas, &init_data);
    try std.testing.expectEqualSlices(u8, &.{ 40, 0 }, group_init.data[0..2]);
    for (group_init.data[2..34]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
    try std.testing.expectEqualSlices(u8, &target, group_init.data[34..66]);

    const group_update = try updateGroupPointer(&mint, &authority, &.{}, &target, &metas, &update_data);
    try std.testing.expectEqualSlices(u8, &.{ 40, 1 }, group_update.data[0..2]);
    try std.testing.expectEqualSlices(u8, &target, group_update.data[2..34]);
    try expectMeta(group_update.accounts[1], &authority, 0, 1);

    const member_init = initializeGroupMemberPointer(&mint, &authority, null, &init_metas, &init_data);
    try std.testing.expectEqualSlices(u8, &.{ 41, 0 }, member_init.data[0..2]);
    try std.testing.expectEqualSlices(u8, &authority, member_init.data[2..34]);
    for (member_init.data[34..66]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);

    const member_update = try updateGroupMemberPointer(&mint, &authority, &.{}, &target, &metas, &update_data);
    try std.testing.expectEqualSlices(u8, &.{ 41, 1 }, member_update.data[0..2]);
    try std.testing.expectEqualSlices(u8, &target, member_update.data[2..34]);
}

test "transfer hook builders encode canonical bytes and authority metas" {
    const mint: Pubkey = .{0x95} ** 32;
    const authority: Pubkey = .{0x96} ** 32;
    const program_id: Pubkey = .{0x97} ** 32;
    const signer: Pubkey = .{0x98} ** 32;
    const signers = [_]Pubkey{signer};
    var init_metas: metasArray(get_account_data_size_spec) = undefined;
    var metas: [3]AccountMeta = undefined;
    var init_data: [transfer_hook_initialize_data_len]u8 = undefined;
    var update_data: [transfer_hook_update_data_len]u8 = undefined;

    const init = initializeTransferHook(&mint, &authority, &program_id, &init_metas, &init_data);
    try std.testing.expectEqualSlices(u8, &.{ 36, 0 }, init.data[0..2]);
    try std.testing.expectEqualSlices(u8, &authority, init.data[2..34]);
    try std.testing.expectEqualSlices(u8, &program_id, init.data[34..66]);
    try expectMeta(init.accounts[0], &mint, 1, 0);

    const update = try updateTransferHook(&mint, &authority, &signers, null, &metas, &update_data);
    try std.testing.expectEqualSlices(u8, &.{ 36, 1 }, update.data[0..2]);
    for (update.data[2..34]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
    try std.testing.expectEqual(@as(usize, 3), update.accounts.len);
    try expectMeta(update.accounts[1], &authority, 0, 0);
    try expectMeta(update.accounts[2], &signers[0], 0, 1);
}

test "scaled ui amount builders encode canonical bytes and authority metas" {
    const mint: Pubkey = .{0xA5} ** 32;
    const authority: Pubkey = .{0xA6} ** 32;
    const signer: Pubkey = .{0xA7} ** 32;
    const signers = [_]Pubkey{signer};
    var init_metas: metasArray(get_account_data_size_spec) = undefined;
    var metas: [3]AccountMeta = undefined;
    var init_data: [scaled_ui_amount_initialize_data_len]u8 = undefined;
    var update_data: [scaled_ui_amount_update_multiplier_data_len]u8 = undefined;

    const init = initializeScaledUiAmount(&mint, &authority, 1.25, &init_metas, &init_data);
    try std.testing.expectEqualSlices(u8, &.{ 43, 0 }, init.data[0..2]);
    try std.testing.expectEqualSlices(u8, &authority, init.data[2..34]);
    try std.testing.expectEqual(@as(u64, @bitCast(@as(f64, 1.25))), std.mem.readInt(u64, init.data[34..42], .little));
    try expectMeta(init.accounts[0], &mint, 1, 0);

    const update = try updateScaledUiAmountMultiplier(&mint, &authority, &signers, 2.5, -42, &metas, &update_data);
    try std.testing.expectEqualSlices(u8, &.{ 43, 1 }, update.data[0..2]);
    try std.testing.expectEqual(@as(u64, @bitCast(@as(f64, 2.5))), std.mem.readInt(u64, update.data[2..10], .little));
    try std.testing.expectEqual(@as(i64, -42), std.mem.readInt(i64, update.data[10..18], .little));
    try std.testing.expectEqual(@as(usize, 3), update.accounts.len);
    try expectMeta(update.accounts[0], &mint, 1, 0);
    try expectMeta(update.accounts[1], &authority, 0, 0);
    try expectMeta(update.accounts[2], &signers[0], 0, 1);
}
