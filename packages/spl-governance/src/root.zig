//! `spl_governance` - SPL Governance PDA, state tag, and instruction helpers.

const std = @import("std");
const sol = @import("solana_program_sdk");
const codec = @import("solana_codec");

pub const Pubkey = sol.Pubkey;
pub const AccountMeta = sol.cpi.AccountMeta;
pub const Instruction = sol.cpi.Instruction;

pub const PROGRAM_ID: Pubkey = sol.pubkey.comptimeFromBase58("Governance111111111111111111111111111111111");
pub const SYSTEM_PROGRAM_ID: Pubkey = sol.system_program_id;
pub const TOKEN_PROGRAM_ID: Pubkey = sol.pubkey.comptimeFromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
pub const RENT_ID: Pubkey = sol.rent_id;
pub const PROGRAM_AUTHORITY_SEED = "governance";

pub const Error = codec.Error || sol.ProgramError || error{
    AccountDataTooSmall,
    AccountMetaBufferTooSmall,
    InvalidAccountType,
    TooManyProposalOptions,
    TooManyInstructionAccounts,
    TooManyInstructions,
    TooManyVoteChoices,
    InvalidOptionalAccounts,
    MissingNewRealmAuthority,
};

pub const GovernanceAccountType = enum(u8) {
    uninitialized = 0,
    realm_v1 = 1,
    token_owner_record_v1 = 2,
    governance_v1 = 3,
    program_governance_v1 = 4,
    proposal_v1 = 5,
    signatory_record_v1 = 6,
    vote_record_v1 = 7,
    proposal_instruction_v1 = 8,
    mint_governance_v1 = 9,
    token_governance_v1 = 10,
    realm_config = 11,
    vote_record_v2 = 12,
    proposal_transaction_v2 = 13,
    proposal_v2 = 14,
    program_metadata = 15,
    realm_v2 = 16,
    token_owner_record_v2 = 17,
    governance_v2 = 18,
    program_governance_v2 = 19,
    mint_governance_v2 = 20,
    token_governance_v2 = 21,
    signatory_record_v2 = 22,
    proposal_deposit = 23,
    required_signatory = 24,
};

pub const GovernanceInstruction = enum(u8) {
    create_realm = 0,
    deposit_governing_tokens = 1,
    withdraw_governing_tokens = 2,
    set_governance_delegate = 3,
    create_governance = 4,
    create_program_governance = 5,
    create_proposal = 6,
    add_signatory = 7,
    legacy1 = 8,
    insert_transaction = 9,
    remove_transaction = 10,
    cancel_proposal = 11,
    sign_off_proposal = 12,
    cast_vote = 13,
    finalize_vote = 14,
    relinquish_vote = 15,
    execute_transaction = 16,
    create_mint_governance = 17,
    create_token_governance = 18,
    set_governance_config = 19,
    flag_transaction_error = 20,
    set_realm_authority = 21,
    set_realm_config = 22,
    create_token_owner_record = 23,
    update_program_metadata = 24,
    create_native_treasury = 25,
    revoke_governing_tokens = 26,
    refund_proposal_deposit = 27,
    complete_proposal = 28,
    add_required_signatory = 29,
    remove_required_signatory = 30,
};

pub const MintMaxVoterWeightSource = union(enum) {
    supply_fraction: u64,
    absolute: u64,
};

pub const SUPPLY_FRACTION_BASE: u64 = 10_000_000_000;
pub const FULL_SUPPLY_FRACTION: MintMaxVoterWeightSource = .{ .supply_fraction = SUPPLY_FRACTION_BASE };

pub const GoverningTokenType = enum(u8) {
    liquid = 0,
    membership = 1,
    dormant = 2,
};

pub const GoverningTokenConfigArgs = struct {
    use_voter_weight_addin: bool = false,
    use_max_voter_weight_addin: bool = false,
    token_type: GoverningTokenType = .liquid,
};

pub const GoverningTokenConfigAccountArgs = struct {
    voter_weight_addin: ?*const Pubkey = null,
    max_voter_weight_addin: ?*const Pubkey = null,
    token_type: GoverningTokenType = .liquid,
};

pub const RealmConfigArgs = struct {
    use_council_mint: bool,
    min_community_weight_to_create_governance: u64,
    community_mint_max_voter_weight_source: MintMaxVoterWeightSource,
    community_token_config_args: GoverningTokenConfigArgs,
    council_token_config_args: GoverningTokenConfigArgs,
};

pub const VoteThreshold = union(enum) {
    yes_vote_percentage: u8,
    quorum_percentage: u8,
    disabled,
};

pub const VoteTipping = enum(u8) {
    strict = 0,
    early = 1,
    disabled = 2,
};

pub const GovernanceConfig = struct {
    community_vote_threshold: VoteThreshold,
    min_community_weight_to_create_proposal: u64,
    min_transaction_hold_up_time: u32,
    voting_base_time: u32,
    community_vote_tipping: VoteTipping,
    council_vote_threshold: VoteThreshold,
    council_veto_vote_threshold: VoteThreshold,
    min_council_weight_to_create_proposal: u64,
    council_vote_tipping: VoteTipping,
    community_veto_vote_threshold: VoteThreshold,
    voting_cool_off_time: u32,
    deposit_exempt_proposal_count: u8,
};

pub const SetRealmAuthorityAction = enum(u8) {
    set_unchecked = 0,
    set_checked = 1,
    remove = 2,
};

pub const MultiChoiceType = enum(u8) {
    full_weight = 0,
    weighted = 1,
};

pub const MultiChoice = struct {
    choice_type: MultiChoiceType,
    min_voter_options: u8,
    max_voter_options: u8,
    max_winning_options: u8,
};

pub const VoteType = union(enum) {
    single_choice,
    multi_choice: MultiChoice,
};

pub const VoteChoice = struct {
    rank: u8,
    weight_percentage: u8,
};

pub const Vote = union(enum) {
    approve: []const VoteChoice,
    deny,
    abstain,
    veto,
};

pub const InstructionAccountMetaData = struct {
    pubkey: *const Pubkey,
    is_signer: bool,
    is_writable: bool,
};

pub const ProposalInstructionData = struct {
    program_id: *const Pubkey,
    accounts: []const InstructionAccountMetaData,
    data: []const u8,
};

pub const TokenOwnerRecordHeader = struct {
    account_type: GovernanceAccountType,
    realm: Pubkey,
    governing_token_mint: Pubkey,
    governing_token_owner: Pubkey,
};

pub const GovernanceHeader = struct {
    account_type: GovernanceAccountType,
    realm: Pubkey,
    governed_account: Pubkey,
};

pub const ProposalDepositHeader = struct {
    account_type: GovernanceAccountType,
    proposal: Pubkey,
    deposit_payer: Pubkey,
};

pub const CreateRealmAccounts = struct {
    realm: *const Pubkey,
    realm_authority: *const Pubkey,
    community_token_mint: *const Pubkey,
    community_token_holding: *const Pubkey,
    payer: *const Pubkey,
    council_token_mint: ?*const Pubkey = null,
    council_token_holding: ?*const Pubkey = null,
    realm_config: *const Pubkey,
    community_token_config_accounts: GoverningTokenConfigAccountArgs = .{},
    council_token_config_accounts: GoverningTokenConfigAccountArgs = .{},
};

pub const DepositGoverningTokensAccounts = struct {
    realm: *const Pubkey,
    governing_token_holding: *const Pubkey,
    governing_token_source: *const Pubkey,
    governing_token_owner: *const Pubkey,
    governing_token_source_authority: *const Pubkey,
    token_owner_record: *const Pubkey,
    payer: *const Pubkey,
    realm_config: *const Pubkey,
};

pub const WithdrawGoverningTokensAccounts = struct {
    realm: *const Pubkey,
    governing_token_holding: *const Pubkey,
    governing_token_destination: *const Pubkey,
    governing_token_owner: *const Pubkey,
    token_owner_record: *const Pubkey,
    realm_config: *const Pubkey,
};

pub const SetGovernanceDelegateAccounts = struct {
    governance_authority: *const Pubkey,
    token_owner_record: *const Pubkey,
};

pub const CreateGovernanceAccounts = struct {
    realm: *const Pubkey,
    governance: *const Pubkey,
    governed_account: *const Pubkey,
    token_owner_record: *const Pubkey,
    payer: *const Pubkey,
    create_authority: *const Pubkey,
    realm_config: *const Pubkey,
    voter_weight_record: ?*const Pubkey = null,
};

pub const SetGovernanceConfigAccounts = struct {
    governance: *const Pubkey,
};

pub const CreateProposalAccounts = struct {
    realm: *const Pubkey,
    proposal: *const Pubkey,
    governance: *const Pubkey,
    proposal_owner_record: *const Pubkey,
    governing_token_mint: *const Pubkey,
    governance_authority: *const Pubkey,
    payer: *const Pubkey,
    realm_config: *const Pubkey,
    voter_weight_record: ?*const Pubkey = null,
    proposal_deposit: *const Pubkey,
};

pub const AddSignatoryByOwnerAccounts = struct {
    governance: *const Pubkey,
    proposal: *const Pubkey,
    signatory_record: *const Pubkey,
    payer: *const Pubkey,
    token_owner_record: *const Pubkey,
    governance_authority: *const Pubkey,
};

pub const AddRequiredSignatoryToProposalAccounts = struct {
    governance: *const Pubkey,
    proposal: *const Pubkey,
    signatory_record: *const Pubkey,
    payer: *const Pubkey,
    required_signatory: *const Pubkey,
};

pub const SignOffProposalOwnerAccounts = struct {
    realm: *const Pubkey,
    governance: *const Pubkey,
    proposal: *const Pubkey,
    proposal_owner: *const Pubkey,
    proposal_owner_record: *const Pubkey,
};

pub const SignOffProposalSignatoryAccounts = struct {
    realm: *const Pubkey,
    governance: *const Pubkey,
    proposal: *const Pubkey,
    signatory: *const Pubkey,
    signatory_record: *const Pubkey,
};

pub const CastVoteAccounts = struct {
    realm: *const Pubkey,
    governance: *const Pubkey,
    proposal: *const Pubkey,
    proposal_owner_record: *const Pubkey,
    voter_token_owner_record: *const Pubkey,
    governance_authority: *const Pubkey,
    vote_record: *const Pubkey,
    vote_governing_token_mint: *const Pubkey,
    payer: *const Pubkey,
    realm_config: *const Pubkey,
    voter_weight_record: ?*const Pubkey = null,
    max_voter_weight_record: ?*const Pubkey = null,
};

pub const FinalizeVoteAccounts = struct {
    realm: *const Pubkey,
    governance: *const Pubkey,
    proposal: *const Pubkey,
    proposal_owner_record: *const Pubkey,
    governing_token_mint: *const Pubkey,
    realm_config: *const Pubkey,
    max_voter_weight_record: ?*const Pubkey = null,
};

pub const RelinquishVoteAccounts = struct {
    realm: *const Pubkey,
    governance: *const Pubkey,
    proposal: *const Pubkey,
    token_owner_record: *const Pubkey,
    vote_record: *const Pubkey,
    vote_governing_token_mint: *const Pubkey,
    governance_authority: ?*const Pubkey = null,
    beneficiary: ?*const Pubkey = null,
};

pub const CancelProposalAccounts = struct {
    realm: *const Pubkey,
    governance: *const Pubkey,
    proposal: *const Pubkey,
    proposal_owner_record: *const Pubkey,
    governance_authority: *const Pubkey,
};

pub const InsertTransactionAccounts = struct {
    governance: *const Pubkey,
    proposal: *const Pubkey,
    token_owner_record: *const Pubkey,
    governance_authority: *const Pubkey,
    proposal_transaction: *const Pubkey,
    payer: *const Pubkey,
};

pub const RemoveTransactionAccounts = struct {
    proposal: *const Pubkey,
    token_owner_record: *const Pubkey,
    governance_authority: *const Pubkey,
    proposal_transaction: *const Pubkey,
    beneficiary: *const Pubkey,
};

pub const ExecuteTransactionAccounts = struct {
    governance: *const Pubkey,
    proposal: *const Pubkey,
    proposal_transaction: *const Pubkey,
    instruction_program_id: *const Pubkey,
};

pub const FlagTransactionErrorAccounts = struct {
    proposal: *const Pubkey,
    token_owner_record: *const Pubkey,
    governance_authority: *const Pubkey,
    proposal_transaction: *const Pubkey,
};

pub const SetRealmAuthorityAccounts = struct {
    realm: *const Pubkey,
    realm_authority: *const Pubkey,
    new_realm_authority: ?*const Pubkey = null,
};

pub const SetRealmConfigAccounts = struct {
    realm: *const Pubkey,
    realm_authority: *const Pubkey,
    council_token_mint: ?*const Pubkey = null,
    council_token_holding: ?*const Pubkey = null,
    realm_config: *const Pubkey,
    payer: *const Pubkey,
    community_token_config_accounts: GoverningTokenConfigAccountArgs = .{},
    council_token_config_accounts: GoverningTokenConfigAccountArgs = .{},
};

pub const CreateTokenOwnerRecordAccounts = struct {
    realm: *const Pubkey,
    governing_token_owner: *const Pubkey,
    token_owner_record: *const Pubkey,
    governing_token_mint: *const Pubkey,
    payer: *const Pubkey,
};

pub const UpdateProgramMetadataAccounts = struct {
    program_metadata: *const Pubkey,
    payer: *const Pubkey,
};

pub const CreateNativeTreasuryAccounts = struct {
    governance: *const Pubkey,
    native_treasury: *const Pubkey,
    payer: *const Pubkey,
};

pub const RevokeGoverningTokensAccounts = struct {
    realm: *const Pubkey,
    governing_token_holding: *const Pubkey,
    token_owner_record: *const Pubkey,
    governing_token_mint: *const Pubkey,
    revoke_authority: *const Pubkey,
    realm_config: *const Pubkey,
};

pub const AddRequiredSignatoryAccounts = struct {
    governance: *const Pubkey,
    required_signatory: *const Pubkey,
    payer: *const Pubkey,
};

pub const RemoveRequiredSignatoryAccounts = struct {
    governance: *const Pubkey,
    required_signatory: *const Pubkey,
    beneficiary: *const Pubkey,
};

pub const RefundProposalDepositAccounts = struct {
    proposal: *const Pubkey,
    proposal_deposit: *const Pubkey,
    proposal_deposit_payer: *const Pubkey,
};

pub const CompleteProposalAccounts = struct {
    proposal: *const Pubkey,
    token_owner_record: *const Pubkey,
    complete_proposal_authority: *const Pubkey,
};

pub fn findRealmAddress(name: []const u8) sol.pda.ProgramDerivedAddress {
    return sol.pda.findProgramAddress(&.{ PROGRAM_AUTHORITY_SEED, name }, &PROGRAM_ID) catch unreachable;
}

pub fn findGoverningTokenHoldingAddress(
    realm: *const Pubkey,
    governing_token_mint: *const Pubkey,
) sol.pda.ProgramDerivedAddress {
    return sol.pda.findProgramAddress(&.{ PROGRAM_AUTHORITY_SEED, realm, governing_token_mint }, &PROGRAM_ID) catch unreachable;
}

pub fn findTokenOwnerRecordAddress(
    realm: *const Pubkey,
    governing_token_mint: *const Pubkey,
    governing_token_owner: *const Pubkey,
) sol.pda.ProgramDerivedAddress {
    return sol.pda.findProgramAddress(&.{ PROGRAM_AUTHORITY_SEED, realm, governing_token_mint, governing_token_owner }, &PROGRAM_ID) catch unreachable;
}

pub fn findRealmConfigAddress(realm: *const Pubkey) sol.pda.ProgramDerivedAddress {
    return sol.pda.findProgramAddress(&.{ "realm-config", realm }, &PROGRAM_ID) catch unreachable;
}

pub fn findGovernanceAddress(realm: *const Pubkey, governed_account: *const Pubkey) sol.pda.ProgramDerivedAddress {
    return sol.pda.findProgramAddress(&.{ "account-governance", realm, governed_account }, &PROGRAM_ID) catch unreachable;
}

pub fn findProgramGovernanceAddress(realm: *const Pubkey, governed_program: *const Pubkey) sol.pda.ProgramDerivedAddress {
    return sol.pda.findProgramAddress(&.{ "program-governance", realm, governed_program }, &PROGRAM_ID) catch unreachable;
}

pub fn findMintGovernanceAddress(realm: *const Pubkey, governed_mint: *const Pubkey) sol.pda.ProgramDerivedAddress {
    return sol.pda.findProgramAddress(&.{ "mint-governance", realm, governed_mint }, &PROGRAM_ID) catch unreachable;
}

pub fn findTokenGovernanceAddress(realm: *const Pubkey, governed_token: *const Pubkey) sol.pda.ProgramDerivedAddress {
    return sol.pda.findProgramAddress(&.{ "token-governance", realm, governed_token }, &PROGRAM_ID) catch unreachable;
}

pub fn findProposalAddress(
    governance: *const Pubkey,
    governing_token_mint: *const Pubkey,
    proposal_seed: *const Pubkey,
) sol.pda.ProgramDerivedAddress {
    return sol.pda.findProgramAddress(&.{ PROGRAM_AUTHORITY_SEED, governance, governing_token_mint, proposal_seed }, &PROGRAM_ID) catch unreachable;
}

pub fn findVoteRecordAddress(proposal: *const Pubkey, token_owner_record: *const Pubkey) sol.pda.ProgramDerivedAddress {
    return sol.pda.findProgramAddress(&.{ PROGRAM_AUTHORITY_SEED, proposal, token_owner_record }, &PROGRAM_ID) catch unreachable;
}

pub fn findSignatoryRecordAddress(proposal: *const Pubkey, signatory: *const Pubkey) sol.pda.ProgramDerivedAddress {
    return sol.pda.findProgramAddress(&.{ PROGRAM_AUTHORITY_SEED, proposal, signatory }, &PROGRAM_ID) catch unreachable;
}

pub fn findProposalTransactionAddress(
    proposal: *const Pubkey,
    option_index: u8,
    instruction_index: u16,
) sol.pda.ProgramDerivedAddress {
    const option_index_bytes = [_]u8{option_index};
    const instruction_index_bytes = std.mem.toBytes(instruction_index);
    return sol.pda.findProgramAddress(&.{ PROGRAM_AUTHORITY_SEED, proposal, &option_index_bytes, &instruction_index_bytes }, &PROGRAM_ID) catch unreachable;
}

pub fn findNativeTreasuryAddress(governance: *const Pubkey) sol.pda.ProgramDerivedAddress {
    return sol.pda.findProgramAddress(&.{ "native-treasury", governance }, &PROGRAM_ID) catch unreachable;
}

pub fn findRequiredSignatoryAddress(governance: *const Pubkey, signatory: *const Pubkey) sol.pda.ProgramDerivedAddress {
    return sol.pda.findProgramAddress(&.{ "required-signatory", governance, signatory }, &PROGRAM_ID) catch unreachable;
}

pub fn findProposalDepositAddress(proposal: *const Pubkey, proposal_deposit_payer: *const Pubkey) sol.pda.ProgramDerivedAddress {
    return sol.pda.findProgramAddress(&.{ "proposal-deposit", proposal, proposal_deposit_payer }, &PROGRAM_ID) catch unreachable;
}

pub fn findProgramMetadataAddress() sol.pda.ProgramDerivedAddress {
    return sol.pda.findProgramAddress(&.{"metadata"}, &PROGRAM_ID) catch unreachable;
}

pub fn parseAccountType(byte: u8) Error!GovernanceAccountType {
    const max_tag = @intFromEnum(GovernanceAccountType.required_signatory);
    if (byte > max_tag) return error.InvalidAccountType;
    return @enumFromInt(byte);
}

pub fn parseTokenOwnerRecordHeader(data: []const u8) Error!TokenOwnerRecordHeader {
    if (data.len < 97) return error.AccountDataTooSmall;
    return .{
        .account_type = try parseAccountType(data[0]),
        .realm = data[1..33].*,
        .governing_token_mint = data[33..65].*,
        .governing_token_owner = data[65..97].*,
    };
}

pub fn parseGovernanceHeader(data: []const u8) Error!GovernanceHeader {
    if (data.len < 65) return error.AccountDataTooSmall;
    const account_type = try parseAccountType(data[0]);
    if (!isGovernanceAccountType(account_type)) return error.InvalidAccountType;
    return .{
        .account_type = account_type,
        .realm = data[1..33].*,
        .governed_account = data[33..65].*,
    };
}

pub fn parseProposalDepositHeader(data: []const u8) Error!ProposalDepositHeader {
    if (data.len < 65) return error.AccountDataTooSmall;
    const account_type = try parseAccountType(data[0]);
    if (account_type != .proposal_deposit) return error.InvalidAccountType;
    return .{
        .account_type = account_type,
        .proposal = data[1..33].*,
        .deposit_payer = data[33..65].*,
    };
}

pub fn isGovernanceAccountType(account_type: GovernanceAccountType) bool {
    return switch (account_type) {
        .governance_v1,
        .program_governance_v1,
        .mint_governance_v1,
        .token_governance_v1,
        .governance_v2,
        .program_governance_v2,
        .mint_governance_v2,
        .token_governance_v2,
        => true,
        else => false,
    };
}

pub fn writeDepositGoverningTokensData(amount: u64, out: []u8) Error![]const u8 {
    if (out.len < 9) return error.BufferTooSmall;
    out[0] = @intFromEnum(GovernanceInstruction.deposit_governing_tokens);
    std.mem.writeInt(u64, out[1..9], amount, .little);
    return out[0..9];
}

pub fn writeWithdrawGoverningTokensData(out: []u8) Error![]const u8 {
    if (out.len < 1) return error.BufferTooSmall;
    out[0] = @intFromEnum(GovernanceInstruction.withdraw_governing_tokens);
    return out[0..1];
}

pub fn writeSetGovernanceDelegateData(new_governance_delegate: ?*const Pubkey, out: []u8) Error![]const u8 {
    const len: usize = if (new_governance_delegate == null) 2 else 34;
    if (out.len < len) return error.BufferTooSmall;
    out[0] = @intFromEnum(GovernanceInstruction.set_governance_delegate);
    if (new_governance_delegate) |delegate| {
        out[1] = 1;
        @memcpy(out[2..34], delegate);
    } else {
        out[1] = 0;
    }
    return out[0..len];
}

pub fn realmConfigArgsDataLen() usize {
    return 1 + 8 + 9 + 3 + 3;
}

pub fn writeCreateRealmData(name: []const u8, args: RealmConfigArgs, out: []u8) Error![]const u8 {
    const needed = 1 + (try codec.borshStringLen(name)) + realmConfigArgsDataLen();
    if (out.len < needed) return error.BufferTooSmall;
    out[0] = @intFromEnum(GovernanceInstruction.create_realm);
    var cursor: usize = 1;
    cursor += try codec.writeBorshString(out[cursor..], name);
    cursor += try writeRealmConfigArgs(args, out[cursor..]);
    return out[0..cursor];
}

pub fn governanceConfigDataLen(config: GovernanceConfig) usize {
    return voteThresholdDataLen(config.community_vote_threshold) +
        8 +
        4 +
        4 +
        1 +
        voteThresholdDataLen(config.council_vote_threshold) +
        voteThresholdDataLen(config.council_veto_vote_threshold) +
        8 +
        1 +
        voteThresholdDataLen(config.community_veto_vote_threshold) +
        4 +
        1;
}

pub fn writeCreateGovernanceData(config: GovernanceConfig, out: []u8) Error![]const u8 {
    return writeGovernanceConfigInstruction(.create_governance, config, out);
}

pub fn writeSetGovernanceConfigData(config: GovernanceConfig, out: []u8) Error![]const u8 {
    return writeGovernanceConfigInstruction(.set_governance_config, config, out);
}

pub fn createProposalDataLen(name: []const u8, description_link: []const u8, vote_type: VoteType, options: []const []const u8) Error!usize {
    return 1 +
        (try codec.borshStringLen(name)) +
        (try codec.borshStringLen(description_link)) +
        voteTypeDataLen(vote_type) +
        (try borshStringVecLen(options)) +
        1 +
        sol.PUBKEY_BYTES;
}

pub fn writeCreateProposalData(
    name: []const u8,
    description_link: []const u8,
    vote_type: VoteType,
    options: []const []const u8,
    use_deny_option: bool,
    proposal_seed: *const Pubkey,
    out: []u8,
) Error![]const u8 {
    const needed = 1 +
        (try codec.borshStringLen(name)) +
        (try codec.borshStringLen(description_link)) +
        voteTypeDataLen(vote_type) +
        (try borshStringVecLen(options)) +
        1 +
        sol.PUBKEY_BYTES;
    if (out.len < needed) return error.BufferTooSmall;

    out[0] = @intFromEnum(GovernanceInstruction.create_proposal);
    var cursor: usize = 1;
    cursor += try codec.writeBorshString(out[cursor..], name);
    cursor += try codec.writeBorshString(out[cursor..], description_link);
    cursor += try writeVoteType(vote_type, out[cursor..]);
    cursor += try writeBorshStringVec(options, out[cursor..]);
    cursor += try codec.writeBorshBool(out[cursor..], use_deny_option);
    @memcpy(out[cursor..][0..sol.PUBKEY_BYTES], proposal_seed);
    cursor += sol.PUBKEY_BYTES;
    return out[0..cursor];
}

pub fn writeAddSignatoryData(signatory: *const Pubkey, out: []u8) Error![]const u8 {
    if (out.len < 1 + sol.PUBKEY_BYTES) return error.BufferTooSmall;
    out[0] = @intFromEnum(GovernanceInstruction.add_signatory);
    @memcpy(out[1..33], signatory);
    return out[0..33];
}

pub fn writeTag(tag: GovernanceInstruction, out: []u8) Error![]const u8 {
    if (out.len < 1) return error.BufferTooSmall;
    out[0] = @intFromEnum(tag);
    return out[0..1];
}

pub fn castVoteDataLen(vote: Vote) Error!usize {
    return 1 + try voteDataLen(vote);
}

pub fn writeCastVoteData(vote: Vote, out: []u8) Error![]const u8 {
    const needed = try castVoteDataLen(vote);
    if (out.len < needed) return error.BufferTooSmall;
    out[0] = @intFromEnum(GovernanceInstruction.cast_vote);
    const vote_len = try writeVote(vote, out[1..]);
    return out[0 .. 1 + vote_len];
}

pub fn insertTransactionDataLen(instructions: []const ProposalInstructionData) Error!usize {
    if (instructions.len > std.math.maxInt(u32)) return error.TooManyInstructions;
    var len: usize = 1 + 1 + 2 + 4 + 4;
    for (instructions) |instruction| len += try proposalInstructionDataLen(instruction);
    return len;
}

pub fn writeInsertTransactionData(
    option_index: u8,
    index: u16,
    hold_up_time: u32,
    instructions: []const ProposalInstructionData,
    out: []u8,
) Error![]const u8 {
    const needed = try insertTransactionDataLen(instructions);
    if (out.len < needed) return error.BufferTooSmall;

    out[0] = @intFromEnum(GovernanceInstruction.insert_transaction);
    var cursor: usize = 1;
    cursor += try codec.writeBorshU8(out[cursor..], option_index);
    cursor += try codec.writeBorshU16(out[cursor..], index);
    cursor += try codec.writeBorshU32(out[cursor..], hold_up_time);
    cursor += try codec.writeBorshU32(out[cursor..], @intCast(instructions.len));
    for (instructions) |instruction| cursor += try writeProposalInstructionData(instruction, out[cursor..]);
    return out[0..cursor];
}

pub fn writeSetRealmAuthorityData(action: SetRealmAuthorityAction, out: []u8) Error![]const u8 {
    if (out.len < 2) return error.BufferTooSmall;
    out[0] = @intFromEnum(GovernanceInstruction.set_realm_authority);
    out[1] = @intFromEnum(action);
    return out[0..2];
}

pub fn writeSetRealmConfigData(args: RealmConfigArgs, out: []u8) Error![]const u8 {
    const needed = 1 + realmConfigArgsDataLen();
    if (out.len < needed) return error.BufferTooSmall;
    out[0] = @intFromEnum(GovernanceInstruction.set_realm_config);
    const written = try writeRealmConfigArgs(args, out[1..]);
    return out[0 .. 1 + written];
}

pub fn writeRevokeGoverningTokensData(amount: u64, out: []u8) Error![]const u8 {
    if (out.len < 9) return error.BufferTooSmall;
    out[0] = @intFromEnum(GovernanceInstruction.revoke_governing_tokens);
    std.mem.writeInt(u64, out[1..9], amount, .little);
    return out[0..9];
}

pub fn writeAddRequiredSignatoryData(signatory: *const Pubkey, out: []u8) Error![]const u8 {
    if (out.len < 1 + sol.PUBKEY_BYTES) return error.BufferTooSmall;
    out[0] = @intFromEnum(GovernanceInstruction.add_required_signatory);
    @memcpy(out[1..33], signatory);
    return out[0..33];
}

fn writeGovernanceConfigInstruction(tag: GovernanceInstruction, config: GovernanceConfig, out: []u8) Error![]const u8 {
    const needed = 1 + governanceConfigDataLen(config);
    if (out.len < needed) return error.BufferTooSmall;
    out[0] = @intFromEnum(tag);
    const written = try writeGovernanceConfig(config, out[1..]);
    return out[0 .. 1 + written];
}

fn writeMintMaxVoterWeightSource(source: MintMaxVoterWeightSource, out: []u8) Error!usize {
    if (out.len < 9) return error.BufferTooSmall;
    switch (source) {
        .supply_fraction => |fraction| {
            out[0] = 0;
            std.mem.writeInt(u64, out[1..9], fraction, .little);
        },
        .absolute => |value| {
            out[0] = 1;
            std.mem.writeInt(u64, out[1..9], value, .little);
        },
    }
    return 9;
}

fn writeGoverningTokenConfigArgs(args: GoverningTokenConfigArgs, out: []u8) Error!usize {
    if (out.len < 3) return error.BufferTooSmall;
    out[0] = @intFromBool(args.use_voter_weight_addin);
    out[1] = @intFromBool(args.use_max_voter_weight_addin);
    out[2] = @intFromEnum(args.token_type);
    return 3;
}

fn writeRealmConfigArgs(args: RealmConfigArgs, out: []u8) Error!usize {
    const needed = realmConfigArgsDataLen();
    if (out.len < needed) return error.BufferTooSmall;
    var cursor: usize = 0;
    cursor += try codec.writeBorshBool(out[cursor..], args.use_council_mint);
    cursor += try codec.writeBorshU64(out[cursor..], args.min_community_weight_to_create_governance);
    cursor += try writeMintMaxVoterWeightSource(args.community_mint_max_voter_weight_source, out[cursor..]);
    cursor += try writeGoverningTokenConfigArgs(args.community_token_config_args, out[cursor..]);
    cursor += try writeGoverningTokenConfigArgs(args.council_token_config_args, out[cursor..]);
    return cursor;
}

fn voteThresholdDataLen(threshold: VoteThreshold) usize {
    return switch (threshold) {
        .yes_vote_percentage, .quorum_percentage => 2,
        .disabled => 1,
    };
}

fn writeVoteThreshold(threshold: VoteThreshold, out: []u8) Error!usize {
    const needed = voteThresholdDataLen(threshold);
    if (out.len < needed) return error.BufferTooSmall;
    switch (threshold) {
        .yes_vote_percentage => |percentage| {
            out[0] = 0;
            out[1] = percentage;
        },
        .quorum_percentage => |percentage| {
            out[0] = 1;
            out[1] = percentage;
        },
        .disabled => out[0] = 2,
    }
    return needed;
}

fn writeGovernanceConfig(config: GovernanceConfig, out: []u8) Error!usize {
    const needed = governanceConfigDataLen(config);
    if (out.len < needed) return error.BufferTooSmall;
    var cursor: usize = 0;
    cursor += try writeVoteThreshold(config.community_vote_threshold, out[cursor..]);
    cursor += try codec.writeBorshU64(out[cursor..], config.min_community_weight_to_create_proposal);
    cursor += try codec.writeBorshU32(out[cursor..], config.min_transaction_hold_up_time);
    cursor += try codec.writeBorshU32(out[cursor..], config.voting_base_time);
    cursor += try codec.writeBorshU8(out[cursor..], @intFromEnum(config.community_vote_tipping));
    cursor += try writeVoteThreshold(config.council_vote_threshold, out[cursor..]);
    cursor += try writeVoteThreshold(config.council_veto_vote_threshold, out[cursor..]);
    cursor += try codec.writeBorshU64(out[cursor..], config.min_council_weight_to_create_proposal);
    cursor += try codec.writeBorshU8(out[cursor..], @intFromEnum(config.council_vote_tipping));
    cursor += try writeVoteThreshold(config.community_veto_vote_threshold, out[cursor..]);
    cursor += try codec.writeBorshU32(out[cursor..], config.voting_cool_off_time);
    cursor += try codec.writeBorshU8(out[cursor..], config.deposit_exempt_proposal_count);
    return cursor;
}

fn configArgsFromAccounts(accounts: GoverningTokenConfigAccountArgs) GoverningTokenConfigArgs {
    return .{
        .use_voter_weight_addin = accounts.voter_weight_addin != null,
        .use_max_voter_weight_addin = accounts.max_voter_weight_addin != null,
        .token_type = accounts.token_type,
    };
}

fn governingTokenConfigAccountCount(accounts: GoverningTokenConfigAccountArgs) usize {
    return (if (accounts.voter_weight_addin == null) @as(usize, 0) else 1) +
        (if (accounts.max_voter_weight_addin == null) @as(usize, 0) else 1);
}

fn appendGoverningTokenConfigAccounts(metas: []AccountMeta, start: usize, accounts: GoverningTokenConfigAccountArgs) usize {
    var cursor = start;
    if (accounts.voter_weight_addin) |addin| {
        metas[cursor] = AccountMeta.readonly(addin);
        cursor += 1;
    }
    if (accounts.max_voter_weight_addin) |addin| {
        metas[cursor] = AccountMeta.readonly(addin);
        cursor += 1;
    }
    return cursor;
}

fn voteTypeDataLen(vote_type: VoteType) usize {
    return switch (vote_type) {
        .single_choice => 1,
        .multi_choice => 5,
    };
}

fn writeVoteType(vote_type: VoteType, out: []u8) Error!usize {
    switch (vote_type) {
        .single_choice => {
            if (out.len < 1) return error.BufferTooSmall;
            out[0] = 0;
            return 1;
        },
        .multi_choice => |choice| {
            if (out.len < 5) return error.BufferTooSmall;
            out[0] = 1;
            out[1] = @intFromEnum(choice.choice_type);
            out[2] = choice.min_voter_options;
            out[3] = choice.max_voter_options;
            out[4] = choice.max_winning_options;
            return 5;
        },
    }
}

fn borshStringVecLen(values: []const []const u8) Error!usize {
    if (values.len > std.math.maxInt(u32)) return error.TooManyProposalOptions;
    var len: usize = 4;
    for (values) |value| len += try codec.borshStringLen(value);
    return len;
}

fn writeBorshStringVec(values: []const []const u8, out: []u8) Error!usize {
    const needed = try borshStringVecLen(values);
    if (out.len < needed) return error.BufferTooSmall;

    var cursor = try codec.writeBorshU32(out, @intCast(values.len));
    for (values) |value| cursor += try codec.writeBorshString(out[cursor..], value);
    return cursor;
}

fn voteDataLen(vote: Vote) Error!usize {
    return switch (vote) {
        .approve => |choices| blk: {
            if (choices.len > std.math.maxInt(u32)) return error.TooManyVoteChoices;
            break :blk 1 + 4 + choices.len * 2;
        },
        .deny, .abstain, .veto => 1,
    };
}

fn writeVote(vote: Vote, out: []u8) Error!usize {
    switch (vote) {
        .approve => |choices| {
            const needed = try voteDataLen(vote);
            if (out.len < needed) return error.BufferTooSmall;
            out[0] = 0;
            var cursor: usize = 1;
            cursor += try codec.writeBorshU32(out[cursor..], @intCast(choices.len));
            for (choices) |choice| {
                out[cursor] = choice.rank;
                out[cursor + 1] = choice.weight_percentage;
                cursor += 2;
            }
            return cursor;
        },
        .deny => {
            if (out.len < 1) return error.BufferTooSmall;
            out[0] = 1;
            return 1;
        },
        .abstain => {
            if (out.len < 1) return error.BufferTooSmall;
            out[0] = 2;
            return 1;
        },
        .veto => {
            if (out.len < 1) return error.BufferTooSmall;
            out[0] = 3;
            return 1;
        },
    }
}

fn proposalInstructionDataLen(instruction: ProposalInstructionData) Error!usize {
    if (instruction.accounts.len > std.math.maxInt(u32)) return error.TooManyInstructionAccounts;
    return sol.PUBKEY_BYTES +
        4 +
        instruction.accounts.len * (sol.PUBKEY_BYTES + 2) +
        (try codec.borshBytesLen(instruction.data));
}

fn writeProposalInstructionData(instruction: ProposalInstructionData, out: []u8) Error!usize {
    const needed = try proposalInstructionDataLen(instruction);
    if (out.len < needed) return error.BufferTooSmall;

    var cursor: usize = 0;
    @memcpy(out[cursor..][0..sol.PUBKEY_BYTES], instruction.program_id);
    cursor += sol.PUBKEY_BYTES;
    cursor += try codec.writeBorshU32(out[cursor..], @intCast(instruction.accounts.len));
    for (instruction.accounts) |account| {
        @memcpy(out[cursor..][0..sol.PUBKEY_BYTES], account.pubkey);
        cursor += sol.PUBKEY_BYTES;
        cursor += try codec.writeBorshBool(out[cursor..], account.is_signer);
        cursor += try codec.writeBorshBool(out[cursor..], account.is_writable);
    }
    cursor += try codec.writeBorshBytes(out[cursor..], instruction.data);
    return cursor;
}

pub fn createRealm(
    accounts: CreateRealmAccounts,
    name: []const u8,
    min_community_weight_to_create_governance: u64,
    community_mint_max_voter_weight_source: MintMaxVoterWeightSource,
    metas: []AccountMeta,
    data: []u8,
) Error!Instruction {
    const has_council_mint = accounts.council_token_mint != null;
    const has_council_holding = accounts.council_token_holding != null;
    if (has_council_mint != has_council_holding) return error.InvalidOptionalAccounts;

    const account_len: usize = 9 +
        (if (has_council_mint) @as(usize, 2) else 0) +
        governingTokenConfigAccountCount(accounts.community_token_config_accounts) +
        governingTokenConfigAccountCount(accounts.council_token_config_accounts);
    if (metas.len < account_len) return error.AccountMetaBufferTooSmall;

    const config_args: RealmConfigArgs = .{
        .use_council_mint = has_council_mint,
        .min_community_weight_to_create_governance = min_community_weight_to_create_governance,
        .community_mint_max_voter_weight_source = community_mint_max_voter_weight_source,
        .community_token_config_args = configArgsFromAccounts(accounts.community_token_config_accounts),
        .council_token_config_args = configArgsFromAccounts(accounts.council_token_config_accounts),
    };
    const written_data = try writeCreateRealmData(name, config_args, data);

    metas[0] = AccountMeta.writable(accounts.realm);
    metas[1] = AccountMeta.readonly(accounts.realm_authority);
    metas[2] = AccountMeta.readonly(accounts.community_token_mint);
    metas[3] = AccountMeta.writable(accounts.community_token_holding);
    metas[4] = AccountMeta.signerWritable(accounts.payer);
    metas[5] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    metas[6] = AccountMeta.readonly(&TOKEN_PROGRAM_ID);
    metas[7] = AccountMeta.readonly(&RENT_ID);
    var cursor: usize = 8;
    if (accounts.council_token_mint) |council_mint| {
        metas[cursor] = AccountMeta.readonly(council_mint);
        cursor += 1;
        metas[cursor] = AccountMeta.writable(accounts.council_token_holding.?);
        cursor += 1;
    }
    metas[cursor] = AccountMeta.writable(accounts.realm_config);
    cursor += 1;
    cursor = appendGoverningTokenConfigAccounts(metas, cursor, accounts.community_token_config_accounts);
    cursor = appendGoverningTokenConfigAccounts(metas, cursor, accounts.council_token_config_accounts);

    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..cursor], .data = written_data };
}

pub fn depositGoverningTokens(
    accounts: DepositGoverningTokensAccounts,
    amount: u64,
    metas: *[10]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written_data = try writeDepositGoverningTokensData(amount, data);

    metas[0] = AccountMeta.readonly(accounts.realm);
    metas[1] = AccountMeta.writable(accounts.governing_token_holding);
    metas[2] = AccountMeta.writable(accounts.governing_token_source);
    metas[3] = AccountMeta.signer(accounts.governing_token_owner);
    metas[4] = AccountMeta.signer(accounts.governing_token_source_authority);
    metas[5] = AccountMeta.writable(accounts.token_owner_record);
    metas[6] = AccountMeta.signerWritable(accounts.payer);
    metas[7] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    metas[8] = AccountMeta.readonly(&TOKEN_PROGRAM_ID);
    metas[9] = AccountMeta.readonly(accounts.realm_config);

    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn withdrawGoverningTokens(
    accounts: WithdrawGoverningTokensAccounts,
    metas: *[7]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written_data = try writeWithdrawGoverningTokensData(data);

    metas[0] = AccountMeta.readonly(accounts.realm);
    metas[1] = AccountMeta.writable(accounts.governing_token_holding);
    metas[2] = AccountMeta.writable(accounts.governing_token_destination);
    metas[3] = AccountMeta.signer(accounts.governing_token_owner);
    metas[4] = AccountMeta.writable(accounts.token_owner_record);
    metas[5] = AccountMeta.readonly(&TOKEN_PROGRAM_ID);
    metas[6] = AccountMeta.readonly(accounts.realm_config);

    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn setGovernanceDelegate(
    accounts: SetGovernanceDelegateAccounts,
    new_governance_delegate: ?*const Pubkey,
    metas: *[2]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written_data = try writeSetGovernanceDelegateData(new_governance_delegate, data);

    metas[0] = AccountMeta.signer(accounts.governance_authority);
    metas[1] = AccountMeta.writable(accounts.token_owner_record);

    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn createGovernance(
    accounts: CreateGovernanceAccounts,
    config: GovernanceConfig,
    metas: []AccountMeta,
    data: []u8,
) Error!Instruction {
    const account_len: usize = if (accounts.voter_weight_record == null) 8 else 9;
    if (metas.len < account_len) return error.AccountMetaBufferTooSmall;
    const written_data = try writeCreateGovernanceData(config, data);

    metas[0] = AccountMeta.readonly(accounts.realm);
    metas[1] = AccountMeta.writable(accounts.governance);
    metas[2] = AccountMeta.readonly(accounts.governed_account);
    metas[3] = AccountMeta.readonly(accounts.token_owner_record);
    metas[4] = AccountMeta.signerWritable(accounts.payer);
    metas[5] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    metas[6] = AccountMeta.signer(accounts.create_authority);
    metas[7] = AccountMeta.readonly(accounts.realm_config);
    if (accounts.voter_weight_record) |record| metas[8] = AccountMeta.readonly(record);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..account_len], .data = written_data };
}

pub fn setGovernanceConfig(
    accounts: SetGovernanceConfigAccounts,
    config: GovernanceConfig,
    metas: *[1]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written_data = try writeSetGovernanceConfigData(config, data);
    metas[0] = AccountMeta.signerWritable(accounts.governance);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn createProposal(
    accounts: CreateProposalAccounts,
    name: []const u8,
    description_link: []const u8,
    vote_type: VoteType,
    options: []const []const u8,
    use_deny_option: bool,
    proposal_seed: *const Pubkey,
    metas: []AccountMeta,
    data: []u8,
) Error!Instruction {
    const account_len: usize = if (accounts.voter_weight_record == null) 10 else 11;
    if (metas.len < account_len) return error.AccountMetaBufferTooSmall;
    const written_data = try writeCreateProposalData(name, description_link, vote_type, options, use_deny_option, proposal_seed, data);

    metas[0] = AccountMeta.readonly(accounts.realm);
    metas[1] = AccountMeta.writable(accounts.proposal);
    metas[2] = AccountMeta.writable(accounts.governance);
    metas[3] = AccountMeta.writable(accounts.proposal_owner_record);
    metas[4] = AccountMeta.readonly(accounts.governing_token_mint);
    metas[5] = AccountMeta.signer(accounts.governance_authority);
    metas[6] = AccountMeta.signerWritable(accounts.payer);
    metas[7] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    metas[8] = AccountMeta.readonly(accounts.realm_config);
    var cursor: usize = 9;
    if (accounts.voter_weight_record) |record| {
        metas[cursor] = AccountMeta.readonly(record);
        cursor += 1;
    }
    metas[cursor] = AccountMeta.writable(accounts.proposal_deposit);
    cursor += 1;

    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..cursor], .data = written_data };
}

pub fn addSignatoryByProposalOwner(
    accounts: AddSignatoryByOwnerAccounts,
    signatory: *const Pubkey,
    metas: *[7]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written_data = try writeAddSignatoryData(signatory, data);
    metas[0] = AccountMeta.readonly(accounts.governance);
    metas[1] = AccountMeta.writable(accounts.proposal);
    metas[2] = AccountMeta.writable(accounts.signatory_record);
    metas[3] = AccountMeta.signerWritable(accounts.payer);
    metas[4] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    metas[5] = AccountMeta.readonly(accounts.token_owner_record);
    metas[6] = AccountMeta.signer(accounts.governance_authority);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn addRequiredSignatoryToProposal(
    accounts: AddRequiredSignatoryToProposalAccounts,
    signatory: *const Pubkey,
    metas: *[6]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written_data = try writeAddSignatoryData(signatory, data);
    metas[0] = AccountMeta.readonly(accounts.governance);
    metas[1] = AccountMeta.writable(accounts.proposal);
    metas[2] = AccountMeta.writable(accounts.signatory_record);
    metas[3] = AccountMeta.signerWritable(accounts.payer);
    metas[4] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    metas[5] = AccountMeta.readonly(accounts.required_signatory);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn signOffProposalOwner(accounts: SignOffProposalOwnerAccounts, metas: *[5]AccountMeta, data: []u8) Error!Instruction {
    const written_data = try writeTag(.sign_off_proposal, data);
    metas[0] = AccountMeta.readonly(accounts.realm);
    metas[1] = AccountMeta.readonly(accounts.governance);
    metas[2] = AccountMeta.writable(accounts.proposal);
    metas[3] = AccountMeta.signer(accounts.proposal_owner);
    metas[4] = AccountMeta.readonly(accounts.proposal_owner_record);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn signOffProposalSignatory(accounts: SignOffProposalSignatoryAccounts, metas: *[5]AccountMeta, data: []u8) Error!Instruction {
    const written_data = try writeTag(.sign_off_proposal, data);
    metas[0] = AccountMeta.readonly(accounts.realm);
    metas[1] = AccountMeta.readonly(accounts.governance);
    metas[2] = AccountMeta.writable(accounts.proposal);
    metas[3] = AccountMeta.signer(accounts.signatory);
    metas[4] = AccountMeta.writable(accounts.signatory_record);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn castVote(accounts: CastVoteAccounts, vote: Vote, metas: []AccountMeta, data: []u8) Error!Instruction {
    const account_len: usize = 11 +
        (if (accounts.voter_weight_record == null) @as(usize, 0) else 1) +
        (if (accounts.max_voter_weight_record == null) @as(usize, 0) else 1);
    if (metas.len < account_len) return error.AccountMetaBufferTooSmall;
    const written_data = try writeCastVoteData(vote, data);

    metas[0] = AccountMeta.readonly(accounts.realm);
    metas[1] = AccountMeta.writable(accounts.governance);
    metas[2] = AccountMeta.writable(accounts.proposal);
    metas[3] = AccountMeta.writable(accounts.proposal_owner_record);
    metas[4] = AccountMeta.writable(accounts.voter_token_owner_record);
    metas[5] = AccountMeta.signer(accounts.governance_authority);
    metas[6] = AccountMeta.writable(accounts.vote_record);
    metas[7] = AccountMeta.readonly(accounts.vote_governing_token_mint);
    metas[8] = AccountMeta.signerWritable(accounts.payer);
    metas[9] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    metas[10] = AccountMeta.readonly(accounts.realm_config);
    var cursor: usize = 11;
    if (accounts.voter_weight_record) |record| {
        metas[cursor] = AccountMeta.readonly(record);
        cursor += 1;
    }
    if (accounts.max_voter_weight_record) |record| {
        metas[cursor] = AccountMeta.readonly(record);
        cursor += 1;
    }
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..cursor], .data = written_data };
}

pub fn finalizeVote(accounts: FinalizeVoteAccounts, metas: []AccountMeta, data: []u8) Error!Instruction {
    const account_len: usize = if (accounts.max_voter_weight_record == null) 6 else 7;
    if (metas.len < account_len) return error.AccountMetaBufferTooSmall;
    const written_data = try writeTag(.finalize_vote, data);
    metas[0] = AccountMeta.readonly(accounts.realm);
    metas[1] = AccountMeta.writable(accounts.governance);
    metas[2] = AccountMeta.writable(accounts.proposal);
    metas[3] = AccountMeta.writable(accounts.proposal_owner_record);
    metas[4] = AccountMeta.readonly(accounts.governing_token_mint);
    metas[5] = AccountMeta.readonly(accounts.realm_config);
    if (accounts.max_voter_weight_record) |record| metas[6] = AccountMeta.readonly(record);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..account_len], .data = written_data };
}

pub fn relinquishVote(accounts: RelinquishVoteAccounts, metas: []AccountMeta, data: []u8) Error!Instruction {
    const account_len: usize = if (accounts.governance_authority == null) 6 else 8;
    if (metas.len < account_len) return error.AccountMetaBufferTooSmall;
    const written_data = try writeTag(.relinquish_vote, data);
    metas[0] = AccountMeta.readonly(accounts.realm);
    metas[1] = AccountMeta.readonly(accounts.governance);
    metas[2] = AccountMeta.writable(accounts.proposal);
    metas[3] = AccountMeta.writable(accounts.token_owner_record);
    metas[4] = AccountMeta.writable(accounts.vote_record);
    metas[5] = AccountMeta.readonly(accounts.vote_governing_token_mint);
    if (accounts.governance_authority) |authority| {
        metas[6] = AccountMeta.signer(authority);
        metas[7] = AccountMeta.writable(accounts.beneficiary.?);
    }
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..account_len], .data = written_data };
}

pub fn cancelProposal(accounts: CancelProposalAccounts, metas: *[5]AccountMeta, data: []u8) Error!Instruction {
    const written_data = try writeTag(.cancel_proposal, data);
    metas[0] = AccountMeta.readonly(accounts.realm);
    metas[1] = AccountMeta.writable(accounts.governance);
    metas[2] = AccountMeta.writable(accounts.proposal);
    metas[3] = AccountMeta.writable(accounts.proposal_owner_record);
    metas[4] = AccountMeta.signer(accounts.governance_authority);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn insertTransaction(
    accounts: InsertTransactionAccounts,
    option_index: u8,
    index: u16,
    hold_up_time: u32,
    instructions: []const ProposalInstructionData,
    metas: *[8]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written_data = try writeInsertTransactionData(option_index, index, hold_up_time, instructions, data);
    metas[0] = AccountMeta.readonly(accounts.governance);
    metas[1] = AccountMeta.writable(accounts.proposal);
    metas[2] = AccountMeta.readonly(accounts.token_owner_record);
    metas[3] = AccountMeta.signer(accounts.governance_authority);
    metas[4] = AccountMeta.writable(accounts.proposal_transaction);
    metas[5] = AccountMeta.signerWritable(accounts.payer);
    metas[6] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    metas[7] = AccountMeta.readonly(&RENT_ID);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn removeTransaction(accounts: RemoveTransactionAccounts, metas: *[5]AccountMeta, data: []u8) Error!Instruction {
    const written_data = try writeTag(.remove_transaction, data);
    metas[0] = AccountMeta.writable(accounts.proposal);
    metas[1] = AccountMeta.readonly(accounts.token_owner_record);
    metas[2] = AccountMeta.signer(accounts.governance_authority);
    metas[3] = AccountMeta.writable(accounts.proposal_transaction);
    metas[4] = AccountMeta.writable(accounts.beneficiary);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn executeTransaction(
    accounts: ExecuteTransactionAccounts,
    instruction_accounts: []const AccountMeta,
    metas: []AccountMeta,
    data: []u8,
) Error!Instruction {
    const account_len = 4 + instruction_accounts.len;
    if (metas.len < account_len) return error.AccountMetaBufferTooSmall;
    const written_data = try writeTag(.execute_transaction, data);
    metas[0] = AccountMeta.readonly(accounts.governance);
    metas[1] = AccountMeta.writable(accounts.proposal);
    metas[2] = AccountMeta.writable(accounts.proposal_transaction);
    metas[3] = AccountMeta.readonly(accounts.instruction_program_id);
    @memcpy(metas[4..][0..instruction_accounts.len], instruction_accounts);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..account_len], .data = written_data };
}

pub fn flagTransactionError(accounts: FlagTransactionErrorAccounts, metas: *[4]AccountMeta, data: []u8) Error!Instruction {
    const written_data = try writeTag(.flag_transaction_error, data);
    metas[0] = AccountMeta.writable(accounts.proposal);
    metas[1] = AccountMeta.readonly(accounts.token_owner_record);
    metas[2] = AccountMeta.signer(accounts.governance_authority);
    metas[3] = AccountMeta.writable(accounts.proposal_transaction);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn setRealmAuthority(
    accounts: SetRealmAuthorityAccounts,
    action: SetRealmAuthorityAction,
    metas: []AccountMeta,
    data: []u8,
) Error!Instruction {
    const account_len: usize = switch (action) {
        .set_unchecked, .set_checked => 3,
        .remove => 2,
    };
    if (metas.len < account_len) return error.AccountMetaBufferTooSmall;
    if (account_len == 3 and accounts.new_realm_authority == null) return error.MissingNewRealmAuthority;
    const written_data = try writeSetRealmAuthorityData(action, data);

    metas[0] = AccountMeta.writable(accounts.realm);
    metas[1] = AccountMeta.signer(accounts.realm_authority);
    if (account_len == 3) metas[2] = AccountMeta.readonly(accounts.new_realm_authority.?);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..account_len], .data = written_data };
}

pub fn setRealmConfig(
    accounts: SetRealmConfigAccounts,
    min_community_weight_to_create_governance: u64,
    community_mint_max_voter_weight_source: MintMaxVoterWeightSource,
    metas: []AccountMeta,
    data: []u8,
) Error!Instruction {
    const has_council_mint = accounts.council_token_mint != null;
    const has_council_holding = accounts.council_token_holding != null;
    if (has_council_mint != has_council_holding) return error.InvalidOptionalAccounts;

    const account_len: usize = 5 +
        (if (has_council_mint) @as(usize, 2) else 0) +
        governingTokenConfigAccountCount(accounts.community_token_config_accounts) +
        governingTokenConfigAccountCount(accounts.council_token_config_accounts);
    if (metas.len < account_len) return error.AccountMetaBufferTooSmall;

    const config_args: RealmConfigArgs = .{
        .use_council_mint = has_council_mint,
        .min_community_weight_to_create_governance = min_community_weight_to_create_governance,
        .community_mint_max_voter_weight_source = community_mint_max_voter_weight_source,
        .community_token_config_args = configArgsFromAccounts(accounts.community_token_config_accounts),
        .council_token_config_args = configArgsFromAccounts(accounts.council_token_config_accounts),
    };
    const written_data = try writeSetRealmConfigData(config_args, data);

    metas[0] = AccountMeta.writable(accounts.realm);
    metas[1] = AccountMeta.signer(accounts.realm_authority);
    var cursor: usize = 2;
    if (accounts.council_token_mint) |council_mint| {
        metas[cursor] = AccountMeta.readonly(council_mint);
        cursor += 1;
        metas[cursor] = AccountMeta.writable(accounts.council_token_holding.?);
        cursor += 1;
    }
    metas[cursor] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    cursor += 1;
    metas[cursor] = AccountMeta.writable(accounts.realm_config);
    cursor += 1;
    cursor = appendGoverningTokenConfigAccounts(metas, cursor, accounts.community_token_config_accounts);
    cursor = appendGoverningTokenConfigAccounts(metas, cursor, accounts.council_token_config_accounts);
    metas[cursor] = AccountMeta.signerWritable(accounts.payer);
    cursor += 1;

    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..cursor], .data = written_data };
}

pub fn createTokenOwnerRecord(accounts: CreateTokenOwnerRecordAccounts, metas: *[6]AccountMeta, data: []u8) Error!Instruction {
    const written_data = try writeTag(.create_token_owner_record, data);
    metas[0] = AccountMeta.readonly(accounts.realm);
    metas[1] = AccountMeta.readonly(accounts.governing_token_owner);
    metas[2] = AccountMeta.writable(accounts.token_owner_record);
    metas[3] = AccountMeta.readonly(accounts.governing_token_mint);
    metas[4] = AccountMeta.signerWritable(accounts.payer);
    metas[5] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn updateProgramMetadata(accounts: UpdateProgramMetadataAccounts, metas: *[3]AccountMeta, data: []u8) Error!Instruction {
    const written_data = try writeTag(.update_program_metadata, data);
    metas[0] = AccountMeta.writable(accounts.program_metadata);
    metas[1] = AccountMeta.signerWritable(accounts.payer);
    metas[2] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn createNativeTreasury(accounts: CreateNativeTreasuryAccounts, metas: *[4]AccountMeta, data: []u8) Error!Instruction {
    const written_data = try writeTag(.create_native_treasury, data);
    metas[0] = AccountMeta.readonly(accounts.governance);
    metas[1] = AccountMeta.writable(accounts.native_treasury);
    metas[2] = AccountMeta.signerWritable(accounts.payer);
    metas[3] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn revokeGoverningTokens(accounts: RevokeGoverningTokensAccounts, amount: u64, metas: *[7]AccountMeta, data: []u8) Error!Instruction {
    const written_data = try writeRevokeGoverningTokensData(amount, data);
    metas[0] = AccountMeta.readonly(accounts.realm);
    metas[1] = AccountMeta.writable(accounts.governing_token_holding);
    metas[2] = AccountMeta.writable(accounts.token_owner_record);
    metas[3] = AccountMeta.writable(accounts.governing_token_mint);
    metas[4] = AccountMeta.signer(accounts.revoke_authority);
    metas[5] = AccountMeta.readonly(accounts.realm_config);
    metas[6] = AccountMeta.readonly(&TOKEN_PROGRAM_ID);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn addRequiredSignatory(accounts: AddRequiredSignatoryAccounts, signatory: *const Pubkey, metas: *[4]AccountMeta, data: []u8) Error!Instruction {
    const written_data = try writeAddRequiredSignatoryData(signatory, data);
    metas[0] = AccountMeta.signerWritable(accounts.governance);
    metas[1] = AccountMeta.writable(accounts.required_signatory);
    metas[2] = AccountMeta.signerWritable(accounts.payer);
    metas[3] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn removeRequiredSignatory(accounts: RemoveRequiredSignatoryAccounts, metas: *[3]AccountMeta, data: []u8) Error!Instruction {
    const written_data = try writeTag(.remove_required_signatory, data);
    metas[0] = AccountMeta.signerWritable(accounts.governance);
    metas[1] = AccountMeta.writable(accounts.required_signatory);
    metas[2] = AccountMeta.writable(accounts.beneficiary);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn refundProposalDeposit(accounts: RefundProposalDepositAccounts, metas: *[3]AccountMeta, data: []u8) Error!Instruction {
    const written_data = try writeTag(.refund_proposal_deposit, data);
    metas[0] = AccountMeta.readonly(accounts.proposal);
    metas[1] = AccountMeta.writable(accounts.proposal_deposit);
    metas[2] = AccountMeta.writable(accounts.proposal_deposit_payer);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn completeProposal(accounts: CompleteProposalAccounts, metas: *[3]AccountMeta, data: []u8) Error!Instruction {
    const written_data = try writeTag(.complete_proposal, data);
    metas[0] = AccountMeta.writable(accounts.proposal);
    metas[1] = AccountMeta.readonly(accounts.token_owner_record);
    metas[2] = AccountMeta.signer(accounts.complete_proposal_authority);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

test "instruction data encodes governance borsh enum variants" {
    var buf: [40]u8 = undefined;
    const deposit = try writeDepositGoverningTokensData(500, &buf);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0xf4, 0x01, 0, 0, 0, 0, 0, 0 }, deposit);

    const withdraw = try writeWithdrawGoverningTokensData(&buf);
    try std.testing.expectEqualSlices(u8, &.{2}, withdraw);

    const delegate: Pubkey = .{7} ** 32;
    const set_delegate = try writeSetGovernanceDelegateData(&delegate, &buf);
    try std.testing.expectEqual(@as(usize, 34), set_delegate.len);
    try std.testing.expectEqual(@as(u8, 3), set_delegate[0]);
    try std.testing.expectEqual(@as(u8, 1), set_delegate[1]);
    try std.testing.expectEqualSlices(u8, &delegate, set_delegate[2..34]);

    const clear_delegate = try writeSetGovernanceDelegateData(null, &buf);
    try std.testing.expectEqualSlices(u8, &.{ 3, 0 }, clear_delegate);
}

test "realm and governance config data encode official borsh layout" {
    var buf: [128]u8 = undefined;
    const realm_args: RealmConfigArgs = .{
        .use_council_mint = true,
        .min_community_weight_to_create_governance = 42,
        .community_mint_max_voter_weight_source = .{ .absolute = 999 },
        .community_token_config_args = .{ .use_voter_weight_addin = true, .token_type = .membership },
        .council_token_config_args = .{ .use_max_voter_weight_addin = true, .token_type = .dormant },
    };
    const create_realm = try writeCreateRealmData("dao", realm_args, &buf);
    try std.testing.expectEqual(@as(u8, 0), create_realm[0]);
    try std.testing.expectEqual(@as(u32, 3), std.mem.readInt(u32, create_realm[1..5], .little));
    try std.testing.expectEqualSlices(u8, "dao", create_realm[5..8]);
    try std.testing.expectEqual(@as(u8, 1), create_realm[8]);
    try std.testing.expectEqual(@as(u64, 42), std.mem.readInt(u64, create_realm[9..17], .little));
    try std.testing.expectEqual(@as(u8, 1), create_realm[17]);
    try std.testing.expectEqual(@as(u64, 999), std.mem.readInt(u64, create_realm[18..26], .little));
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 1, 0, 1, 2 }, create_realm[26..32]);

    const config: GovernanceConfig = .{
        .community_vote_threshold = .{ .yes_vote_percentage = 60 },
        .min_community_weight_to_create_proposal = 10,
        .min_transaction_hold_up_time = 30,
        .voting_base_time = 3600,
        .community_vote_tipping = .strict,
        .council_vote_threshold = .disabled,
        .council_veto_vote_threshold = .{ .yes_vote_percentage = 51 },
        .min_council_weight_to_create_proposal = 1,
        .council_vote_tipping = .early,
        .community_veto_vote_threshold = .{ .quorum_percentage = 40 },
        .voting_cool_off_time = 12,
        .deposit_exempt_proposal_count = 3,
    };
    const create_governance = try writeCreateGovernanceData(config, &buf);
    try std.testing.expectEqual(@as(u8, 4), create_governance[0]);
    try std.testing.expectEqualSlices(u8, &.{ 0, 60 }, create_governance[1..3]);
    try std.testing.expectEqual(@as(u64, 10), std.mem.readInt(u64, create_governance[3..11], .little));
    try std.testing.expectEqual(@as(u8, 2), create_governance[20]);
    try std.testing.expectEqualSlices(u8, &.{ 0, 51 }, create_governance[21..23]);
    try std.testing.expectEqual(@as(u8, 1), create_governance[31]);
    try std.testing.expectEqualSlices(u8, &.{ 1, 40 }, create_governance[32..34]);

    const set_realm_authority = try writeSetRealmAuthorityData(.set_checked, &buf);
    try std.testing.expectEqualSlices(u8, &.{ 21, 1 }, set_realm_authority);

    const signatory: Pubkey = .{7} ** 32;
    const add_required_signatory = try writeAddRequiredSignatoryData(&signatory, &buf);
    try std.testing.expectEqual(@as(u8, 29), add_required_signatory[0]);
}

test "proposal and vote data encode governance borsh variants" {
    var buf: [160]u8 = undefined;
    const seed: Pubkey = .{9} ** 32;
    const options = [_][]const u8{ "yes", "abstain" };

    const create = try writeCreateProposalData(
        "ship",
        "https://example.invalid",
        .single_choice,
        &options,
        true,
        &seed,
        &buf,
    );
    try std.testing.expectEqual(@as(u8, 6), create[0]);
    var cursor: usize = 1;
    try std.testing.expectEqual(@as(u32, 4), std.mem.readInt(u32, create[cursor..][0..4], .little));
    cursor += 4;
    try std.testing.expectEqualSlices(u8, "ship", create[cursor..][0..4]);
    cursor += 4;
    const desc_len = std.mem.readInt(u32, create[cursor..][0..4], .little);
    cursor += 4 + @as(usize, desc_len);
    try std.testing.expectEqual(@as(u8, 0), create[cursor]);
    cursor += 1;
    try std.testing.expectEqual(@as(u32, 2), std.mem.readInt(u32, create[cursor..][0..4], .little));

    const choices = [_]VoteChoice{.{ .rank = 0, .weight_percentage = 100 }};
    const cast = try writeCastVoteData(.{ .approve = &choices }, &buf);
    try std.testing.expectEqualSlices(u8, &.{ 13, 0, 1, 0, 0, 0, 0, 100 }, cast);

    const deny = try writeCastVoteData(.deny, &buf);
    try std.testing.expectEqualSlices(u8, &.{ 13, 1 }, deny);

    const signatory: Pubkey = .{8} ** 32;
    const add = try writeAddSignatoryData(&signatory, &buf);
    try std.testing.expectEqual(@as(u8, 7), add[0]);
    try std.testing.expectEqualSlices(u8, &signatory, add[1..33]);
}

test "proposal transaction data encodes nested instruction data" {
    const program_id: Pubkey = .{1} ** 32;
    const account: Pubkey = .{2} ** 32;
    const instruction_accounts = [_]InstructionAccountMetaData{
        .{ .pubkey = &account, .is_signer = true, .is_writable = false },
    };
    const instruction_payload = [_]u8{ 0xaa, 0xbb };
    const instructions = [_]ProposalInstructionData{
        .{ .program_id = &program_id, .accounts = &instruction_accounts, .data = &instruction_payload },
    };
    var buf: [128]u8 = undefined;
    const data = try writeInsertTransactionData(2, 9, 30, &instructions, &buf);

    try std.testing.expectEqual(@as(u8, 9), data[0]);
    try std.testing.expectEqual(@as(u8, 2), data[1]);
    try std.testing.expectEqual(@as(u16, 9), std.mem.readInt(u16, data[2..4], .little));
    try std.testing.expectEqual(@as(u32, 30), std.mem.readInt(u32, data[4..8], .little));
    try std.testing.expectEqual(@as(u32, 1), std.mem.readInt(u32, data[8..12], .little));
    try std.testing.expectEqualSlices(u8, &program_id, data[12..44]);
    try std.testing.expectEqual(@as(u32, 1), std.mem.readInt(u32, data[44..48], .little));
    try std.testing.expectEqualSlices(u8, &account, data[48..80]);
    try std.testing.expectEqual(@as(u8, 1), data[80]);
    try std.testing.expectEqual(@as(u8, 0), data[81]);
    try std.testing.expectEqual(@as(u32, 2), std.mem.readInt(u32, data[82..86], .little));
    try std.testing.expectEqualSlices(u8, &instruction_payload, data[86..88]);
}

test "proposal vote builders use caller-owned account addresses" {
    const keys = [_]Pubkey{
        .{0} ** 32,
        .{1} ** 32,
        .{2} ** 32,
        .{3} ** 32,
        .{4} ** 32,
        .{5} ** 32,
        .{6} ** 32,
        .{7} ** 32,
        .{8} ** 32,
        .{9} ** 32,
        .{10} ** 32,
        .{11} ** 32,
    };
    var metas: [12]AccountMeta = undefined;
    var data: [128]u8 = undefined;

    const create = try createProposal(
        .{
            .realm = &keys[0],
            .proposal = &keys[1],
            .governance = &keys[2],
            .proposal_owner_record = &keys[3],
            .governing_token_mint = &keys[4],
            .governance_authority = &keys[5],
            .payer = &keys[6],
            .realm_config = &keys[7],
            .proposal_deposit = &keys[8],
        },
        "p",
        "d",
        .single_choice,
        &[_][]const u8{"yes"},
        true,
        &keys[9],
        &metas,
        &data,
    );
    try std.testing.expectEqual(@as(usize, 10), create.accounts.len);
    try std.testing.expectEqualSlices(u8, &keys[1], create.accounts[1].pubkey);
    try std.testing.expectEqual(@as(u8, 1), create.accounts[1].is_writable);
    try std.testing.expectEqualSlices(u8, &keys[8], create.accounts[9].pubkey);

    const vote = try castVote(
        .{
            .realm = &keys[0],
            .governance = &keys[2],
            .proposal = &keys[1],
            .proposal_owner_record = &keys[3],
            .voter_token_owner_record = &keys[4],
            .governance_authority = &keys[5],
            .vote_record = &keys[10],
            .vote_governing_token_mint = &keys[9],
            .payer = &keys[6],
            .realm_config = &keys[7],
            .voter_weight_record = &keys[11],
        },
        .deny,
        &metas,
        &data,
    );
    try std.testing.expectEqual(@as(usize, 12), vote.accounts.len);
    try std.testing.expectEqualSlices(u8, &keys[10], vote.accounts[6].pubkey);
    try std.testing.expectEqualSlices(u8, &keys[11], vote.accounts[11].pubkey);
    try std.testing.expectEqualSlices(u8, &.{ 13, 1 }, vote.data);
}

test "realm governance and admin builders use canonical account order" {
    const keys = [_]Pubkey{
        .{0} ** 32,
        .{1} ** 32,
        .{2} ** 32,
        .{3} ** 32,
        .{4} ** 32,
        .{5} ** 32,
        .{6} ** 32,
        .{7} ** 32,
        .{8} ** 32,
        .{9} ** 32,
        .{10} ** 32,
        .{11} ** 32,
        .{12} ** 32,
        .{13} ** 32,
    };
    var metas: [16]AccountMeta = undefined;
    var fixed_metas: [7]AccountMeta = undefined;
    var data: [160]u8 = undefined;

    const create_realm = try createRealm(
        .{
            .realm = &keys[0],
            .realm_authority = &keys[1],
            .community_token_mint = &keys[2],
            .community_token_holding = &keys[3],
            .payer = &keys[4],
            .council_token_mint = &keys[5],
            .council_token_holding = &keys[6],
            .realm_config = &keys[7],
            .community_token_config_accounts = .{ .voter_weight_addin = &keys[8], .token_type = .membership },
            .council_token_config_accounts = .{ .max_voter_weight_addin = &keys[9], .token_type = .dormant },
        },
        "dao",
        42,
        .{ .absolute = 999 },
        &metas,
        &data,
    );
    try std.testing.expectEqual(@as(usize, 13), create_realm.accounts.len);
    try std.testing.expectEqualSlices(u8, &keys[0], create_realm.accounts[0].pubkey);
    try std.testing.expectEqual(@as(u8, 1), create_realm.accounts[0].is_writable);
    try std.testing.expectEqualSlices(u8, &keys[5], create_realm.accounts[8].pubkey);
    try std.testing.expectEqualSlices(u8, &keys[7], create_realm.accounts[10].pubkey);
    try std.testing.expectEqualSlices(u8, &keys[8], create_realm.accounts[11].pubkey);
    try std.testing.expectEqualSlices(u8, &keys[9], create_realm.accounts[12].pubkey);

    const config: GovernanceConfig = .{
        .community_vote_threshold = .{ .yes_vote_percentage = 60 },
        .min_community_weight_to_create_proposal = 10,
        .min_transaction_hold_up_time = 30,
        .voting_base_time = 3600,
        .community_vote_tipping = .strict,
        .council_vote_threshold = .disabled,
        .council_veto_vote_threshold = .{ .yes_vote_percentage = 51 },
        .min_council_weight_to_create_proposal = 1,
        .council_vote_tipping = .early,
        .community_veto_vote_threshold = .{ .quorum_percentage = 40 },
        .voting_cool_off_time = 12,
        .deposit_exempt_proposal_count = 3,
    };
    const create_governance = try createGovernance(
        .{
            .realm = &keys[0],
            .governance = &keys[1],
            .governed_account = &keys[2],
            .token_owner_record = &keys[3],
            .payer = &keys[4],
            .create_authority = &keys[5],
            .realm_config = &keys[6],
            .voter_weight_record = &keys[7],
        },
        config,
        &metas,
        &data,
    );
    try std.testing.expectEqual(@as(usize, 9), create_governance.accounts.len);
    try std.testing.expectEqualSlices(u8, &keys[1], create_governance.accounts[1].pubkey);
    try std.testing.expectEqualSlices(u8, &keys[6], create_governance.accounts[7].pubkey);
    try std.testing.expectEqualSlices(u8, &keys[7], create_governance.accounts[8].pubkey);

    const set_realm_config = try setRealmConfig(
        .{
            .realm = &keys[0],
            .realm_authority = &keys[1],
            .realm_config = &keys[2],
            .payer = &keys[3],
            .community_token_config_accounts = .{ .voter_weight_addin = &keys[4] },
        },
        5,
        FULL_SUPPLY_FRACTION,
        &metas,
        &data,
    );
    try std.testing.expectEqual(@as(usize, 6), set_realm_config.accounts.len);
    try std.testing.expectEqualSlices(u8, &SYSTEM_PROGRAM_ID, set_realm_config.accounts[2].pubkey);
    try std.testing.expectEqualSlices(u8, &keys[2], set_realm_config.accounts[3].pubkey);
    try std.testing.expectEqualSlices(u8, &keys[4], set_realm_config.accounts[4].pubkey);
    try std.testing.expectEqualSlices(u8, &keys[3], set_realm_config.accounts[5].pubkey);

    const revoke = try revokeGoverningTokens(
        .{
            .realm = &keys[0],
            .governing_token_holding = &keys[1],
            .token_owner_record = &keys[2],
            .governing_token_mint = &keys[3],
            .revoke_authority = &keys[4],
            .realm_config = &keys[5],
        },
        9,
        &fixed_metas,
        &data,
    );
    try std.testing.expectEqualSlices(u8, &.{ 26, 9, 0, 0, 0, 0, 0, 0, 0 }, revoke.data);
    try std.testing.expectEqualSlices(u8, &TOKEN_PROGRAM_ID, revoke.accounts[6].pubkey);

    var required_metas: [4]AccountMeta = undefined;
    const add_required = try addRequiredSignatory(
        .{ .governance = &keys[0], .required_signatory = &keys[1], .payer = &keys[2] },
        &keys[3],
        &required_metas,
        &data,
    );
    try std.testing.expectEqual(@as(u8, 29), add_required.data[0]);
    try std.testing.expectEqual(@as(u8, 1), add_required.accounts[0].is_signer);

    var three_metas: [3]AccountMeta = undefined;
    const complete = try completeProposal(
        .{ .proposal = &keys[0], .token_owner_record = &keys[1], .complete_proposal_authority = &keys[2] },
        &three_metas,
        &data,
    );
    try std.testing.expectEqualSlices(u8, &.{28}, complete.data);
    try std.testing.expectEqualSlices(u8, &keys[2], complete.accounts[2].pubkey);
}

test "proposal transaction builders use canonical account order" {
    const keys = [_]Pubkey{
        .{0} ** 32,
        .{1} ** 32,
        .{2} ** 32,
        .{3} ** 32,
        .{4} ** 32,
        .{5} ** 32,
        .{6} ** 32,
        .{7} ** 32,
    };
    const instruction_metas = [_]AccountMeta{
        AccountMeta.signer(&keys[6]),
        AccountMeta.writable(&keys[7]),
    };
    const nested_accounts = [_]InstructionAccountMetaData{
        .{ .pubkey = &keys[6], .is_signer = true, .is_writable = false },
    };
    const nested = [_]ProposalInstructionData{
        .{ .program_id = &keys[5], .accounts = &nested_accounts, .data = &.{0xaa} },
    };
    var metas: [10]AccountMeta = undefined;
    var insert_metas: [8]AccountMeta = undefined;
    var data: [128]u8 = undefined;

    const insert = try insertTransaction(
        .{
            .governance = &keys[0],
            .proposal = &keys[1],
            .token_owner_record = &keys[2],
            .governance_authority = &keys[3],
            .proposal_transaction = &keys[4],
            .payer = &keys[5],
        },
        1,
        2,
        3,
        &nested,
        &insert_metas,
        &data,
    );
    try std.testing.expectEqualSlices(u8, &.{ 9, 1, 2, 0, 3, 0, 0, 0 }, insert.data[0..8]);
    try std.testing.expectEqualSlices(u8, &keys[4], insert.accounts[4].pubkey);
    try std.testing.expectEqualSlices(u8, &RENT_ID, insert.accounts[7].pubkey);

    const execute = try executeTransaction(
        .{ .governance = &keys[0], .proposal = &keys[1], .proposal_transaction = &keys[4], .instruction_program_id = &keys[5] },
        &instruction_metas,
        &metas,
        &data,
    );
    try std.testing.expectEqual(@as(usize, 6), execute.accounts.len);
    try std.testing.expectEqualSlices(u8, &keys[6], execute.accounts[4].pubkey);
    try std.testing.expectEqualSlices(u8, &.{16}, execute.data);
}

test "parse governance account headers" {
    const realm: Pubkey = .{1} ** 32;
    const governed: Pubkey = .{2} ** 32;
    var governance_data = [_]u8{0} ** 65;
    governance_data[0] = @intFromEnum(GovernanceAccountType.program_governance_v2);
    @memcpy(governance_data[1..33], &realm);
    @memcpy(governance_data[33..65], &governed);

    const governance = try parseGovernanceHeader(&governance_data);
    try std.testing.expectEqual(GovernanceAccountType.program_governance_v2, governance.account_type);
    try std.testing.expectEqualSlices(u8, &realm, &governance.realm);
    try std.testing.expectEqualSlices(u8, &governed, &governance.governed_account);

    governance_data[0] = @intFromEnum(GovernanceAccountType.realm_v2);
    try std.testing.expectError(error.InvalidAccountType, parseGovernanceHeader(&governance_data));
}
