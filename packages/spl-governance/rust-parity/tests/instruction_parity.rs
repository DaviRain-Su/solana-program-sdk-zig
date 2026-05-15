use {
    solana_program::{instruction::AccountMeta, pubkey::Pubkey, system_program, sysvar},
    spl_governance::{
        instruction::{
            add_required_signatory, add_signatory, cancel_proposal, cast_vote, complete_proposal,
            create_governance, create_native_treasury, create_proposal, create_realm,
            create_token_owner_record, deposit_governing_tokens, execute_transaction,
            finalize_vote, flag_transaction_error, insert_transaction, refund_proposal_deposit,
            relinquish_vote, remove_required_signatory, remove_transaction,
            revoke_governing_tokens, set_governance_config, set_governance_delegate,
            set_realm_authority, set_realm_config, sign_off_proposal, upgrade_program_metadata,
            withdraw_governing_tokens, AddSignatoryAuthority,
        },
        state::{
            enums::{GovernanceAccountType, MintMaxVoterWeightSource, VoteThreshold, VoteTipping},
            governance::{
                get_governance_address, get_mint_governance_address,
                get_program_governance_address, get_token_governance_address, GovernanceConfig,
            },
            native_treasury::get_native_treasury_address,
            program_metadata::get_program_metadata_address,
            proposal::{get_proposal_address, VoteType},
            proposal_deposit::get_proposal_deposit_address,
            proposal_transaction::{
                get_proposal_transaction_address, AccountMetaData, InstructionData,
            },
            realm::{get_governing_token_holding_address, get_realm_address},
            realm::{GoverningTokenConfigAccountArgs, SetRealmAuthorityAction},
            realm_config::get_realm_config_address,
            realm_config::GoverningTokenType,
            required_signatory::get_required_signatory_address,
            signatory_record::get_signatory_record_address,
            token_owner_record::get_token_owner_record_address,
            vote_record::{get_vote_record_address, Vote, VoteChoice},
        },
    },
    std::str::FromStr,
};

fn key(byte: u8) -> Pubkey {
    Pubkey::from([byte; 32])
}

fn governance_program_id() -> Pubkey {
    Pubkey::from_str("Governance111111111111111111111111111111111").unwrap()
}

fn assert_meta(meta: &AccountMeta, pubkey: Pubkey, is_signer: bool, is_writable: bool) {
    assert_eq!(meta.pubkey, pubkey);
    assert_eq!(meta.is_signer, is_signer);
    assert_eq!(meta.is_writable, is_writable);
}

fn sample_governance_config() -> GovernanceConfig {
    GovernanceConfig {
        community_vote_threshold: VoteThreshold::YesVotePercentage(60),
        min_community_weight_to_create_proposal: 10,
        min_transaction_hold_up_time: 30,
        voting_base_time: 3600,
        community_vote_tipping: VoteTipping::Strict,
        council_vote_threshold: VoteThreshold::Disabled,
        council_veto_vote_threshold: VoteThreshold::YesVotePercentage(51),
        min_council_weight_to_create_proposal: 1,
        council_vote_tipping: VoteTipping::Early,
        community_veto_vote_threshold: VoteThreshold::QuorumPercentage(40),
        voting_cool_off_time: 12,
        deposit_exempt_proposal_count: 3,
    }
}

#[test]
fn official_pda_helpers_match_zig_seed_order() {
    let program_id = governance_program_id();
    let realm = key(1);
    let mint = key(2);
    let owner = key(3);
    let governed = key(4);
    let proposal_seed = key(5);
    let proposal = key(6);
    let signatory = key(7);
    let payer = key(8);

    assert_eq!(
        get_realm_address(&program_id, "core-dao"),
        Pubkey::find_program_address(&[b"governance", b"core-dao"], &program_id).0
    );
    assert_eq!(
        get_governing_token_holding_address(&program_id, &realm, &mint),
        Pubkey::find_program_address(&[b"governance", realm.as_ref(), mint.as_ref()], &program_id)
            .0
    );
    assert_eq!(
        get_token_owner_record_address(&program_id, &realm, &mint, &owner),
        Pubkey::find_program_address(
            &[b"governance", realm.as_ref(), mint.as_ref(), owner.as_ref()],
            &program_id
        )
        .0
    );
    assert_eq!(
        get_realm_config_address(&program_id, &realm),
        Pubkey::find_program_address(&[b"realm-config", realm.as_ref()], &program_id).0
    );
    assert_eq!(
        get_governance_address(&program_id, &realm, &governed),
        Pubkey::find_program_address(
            &[b"account-governance", realm.as_ref(), governed.as_ref()],
            &program_id
        )
        .0
    );
    assert_eq!(
        get_program_governance_address(&program_id, &realm, &governed),
        Pubkey::find_program_address(
            &[b"program-governance", realm.as_ref(), governed.as_ref()],
            &program_id
        )
        .0
    );
    assert_eq!(
        get_mint_governance_address(&program_id, &realm, &governed),
        Pubkey::find_program_address(
            &[b"mint-governance", realm.as_ref(), governed.as_ref()],
            &program_id
        )
        .0
    );
    assert_eq!(
        get_token_governance_address(&program_id, &realm, &governed),
        Pubkey::find_program_address(
            &[b"token-governance", realm.as_ref(), governed.as_ref()],
            &program_id
        )
        .0
    );
    assert_eq!(
        get_proposal_address(&program_id, &governed, &mint, &proposal_seed),
        Pubkey::find_program_address(
            &[
                b"governance",
                governed.as_ref(),
                mint.as_ref(),
                proposal_seed.as_ref(),
            ],
            &program_id
        )
        .0
    );
    assert_eq!(
        get_vote_record_address(&program_id, &proposal, &owner),
        Pubkey::find_program_address(
            &[b"governance", proposal.as_ref(), owner.as_ref()],
            &program_id
        )
        .0
    );
    assert_eq!(
        get_signatory_record_address(&program_id, &proposal, &signatory),
        Pubkey::find_program_address(
            &[b"governance", proposal.as_ref(), signatory.as_ref()],
            &program_id
        )
        .0
    );
    assert_eq!(
        get_proposal_transaction_address(&program_id, &proposal, &[2], &9u16.to_le_bytes()),
        Pubkey::find_program_address(
            &[b"governance", proposal.as_ref(), &[2], &9u16.to_le_bytes()],
            &program_id
        )
        .0
    );
    assert_eq!(
        get_native_treasury_address(&program_id, &governed),
        Pubkey::find_program_address(&[b"native-treasury", governed.as_ref()], &program_id).0
    );
    assert_eq!(
        get_required_signatory_address(&program_id, &governed, &signatory),
        Pubkey::find_program_address(
            &[b"required-signatory", governed.as_ref(), signatory.as_ref()],
            &program_id
        )
        .0
    );
    assert_eq!(
        get_proposal_deposit_address(&program_id, &proposal, &payer),
        Pubkey::find_program_address(
            &[b"proposal-deposit", proposal.as_ref(), payer.as_ref()],
            &program_id
        )
        .0
    );
    assert_eq!(
        get_program_metadata_address(&program_id),
        Pubkey::find_program_address(&[b"metadata"], &program_id).0
    );
}

#[test]
fn official_realm_governance_and_admin_builders_match_zig_layout() {
    let program_id = governance_program_id();
    let realm_authority = key(1);
    let community_mint = key(2);
    let payer = key(3);
    let council_mint = key(4);
    let community_voter_weight_addin = key(5);
    let council_max_voter_weight_addin = key(6);

    let create_realm_ix = create_realm(
        &program_id,
        &realm_authority,
        &community_mint,
        &payer,
        Some(council_mint),
        Some(GoverningTokenConfigAccountArgs {
            voter_weight_addin: Some(community_voter_weight_addin),
            max_voter_weight_addin: None,
            token_type: GoverningTokenType::Membership,
        }),
        Some(GoverningTokenConfigAccountArgs {
            voter_weight_addin: None,
            max_voter_weight_addin: Some(council_max_voter_weight_addin),
            token_type: GoverningTokenType::Dormant,
        }),
        "dao".to_string(),
        42,
        MintMaxVoterWeightSource::Absolute(999),
    );
    let realm = get_realm_address(&program_id, "dao");
    let community_holding =
        get_governing_token_holding_address(&program_id, &realm, &community_mint);
    let council_holding = get_governing_token_holding_address(&program_id, &realm, &council_mint);
    let realm_config = get_realm_config_address(&program_id, &realm);
    assert_eq!(create_realm_ix.data[0], 0);
    assert_eq!(
        u32::from_le_bytes(create_realm_ix.data[1..5].try_into().unwrap()),
        3
    );
    assert_eq!(&create_realm_ix.data[5..8], b"dao");
    assert_eq!(create_realm_ix.data[8], 1);
    assert_eq!(
        u64::from_le_bytes(create_realm_ix.data[9..17].try_into().unwrap()),
        42
    );
    assert_eq!(create_realm_ix.data[17], 1);
    assert_eq!(
        u64::from_le_bytes(create_realm_ix.data[18..26].try_into().unwrap()),
        999
    );
    assert_eq!(&create_realm_ix.data[26..32], &[1, 0, 1, 0, 1, 2]);
    assert_eq!(create_realm_ix.accounts.len(), 13);
    assert_meta(&create_realm_ix.accounts[0], realm, false, true);
    assert_meta(&create_realm_ix.accounts[1], realm_authority, false, false);
    assert_meta(&create_realm_ix.accounts[2], community_mint, false, false);
    assert_meta(&create_realm_ix.accounts[3], community_holding, false, true);
    assert_meta(&create_realm_ix.accounts[4], payer, true, true);
    assert_meta(
        &create_realm_ix.accounts[5],
        system_program::id(),
        false,
        false,
    );
    assert_meta(&create_realm_ix.accounts[6], spl_token::id(), false, false);
    assert_meta(
        &create_realm_ix.accounts[7],
        sysvar::rent::id(),
        false,
        false,
    );
    assert_meta(&create_realm_ix.accounts[8], council_mint, false, false);
    assert_meta(&create_realm_ix.accounts[9], council_holding, false, true);
    assert_meta(&create_realm_ix.accounts[10], realm_config, false, true);
    assert_meta(
        &create_realm_ix.accounts[11],
        community_voter_weight_addin,
        false,
        false,
    );
    assert_meta(
        &create_realm_ix.accounts[12],
        council_max_voter_weight_addin,
        false,
        false,
    );

    let governed = key(7);
    let token_owner_record = key(8);
    let create_authority = key(9);
    let voter_weight_record = key(10);
    let governance = get_governance_address(&program_id, &realm, &governed);
    let config = sample_governance_config();
    let create_governance_ix = create_governance(
        &program_id,
        &realm,
        Some(&governed),
        &token_owner_record,
        &payer,
        &create_authority,
        Some(voter_weight_record),
        config.clone(),
    );
    assert_eq!(create_governance_ix.data[0], 4);
    assert_eq!(&create_governance_ix.data[1..3], &[0, 60]);
    assert_eq!(
        u64::from_le_bytes(create_governance_ix.data[3..11].try_into().unwrap()),
        10
    );
    assert_eq!(create_governance_ix.accounts.len(), 9);
    assert_meta(&create_governance_ix.accounts[0], realm, false, false);
    assert_meta(&create_governance_ix.accounts[1], governance, false, true);
    assert_meta(&create_governance_ix.accounts[2], governed, false, false);
    assert_meta(
        &create_governance_ix.accounts[6],
        create_authority,
        true,
        false,
    );
    assert_meta(
        &create_governance_ix.accounts[7],
        realm_config,
        false,
        false,
    );
    assert_meta(
        &create_governance_ix.accounts[8],
        voter_weight_record,
        false,
        false,
    );

    let set_config_ix = set_governance_config(&program_id, &governance, config);
    assert_eq!(set_config_ix.data[0], 19);
    assert_eq!(set_config_ix.accounts.len(), 1);
    assert_meta(&set_config_ix.accounts[0], governance, true, true);

    let new_authority = key(11);
    let set_authority_ix = set_realm_authority(
        &program_id,
        &realm,
        &realm_authority,
        Some(&new_authority),
        SetRealmAuthorityAction::SetChecked,
    );
    assert_eq!(set_authority_ix.data, vec![21, 1]);
    assert_eq!(set_authority_ix.accounts.len(), 3);
    assert_meta(&set_authority_ix.accounts[0], realm, false, true);
    assert_meta(&set_authority_ix.accounts[2], new_authority, false, false);

    let set_realm_config_ix = set_realm_config(
        &program_id,
        &realm,
        &realm_authority,
        None,
        &payer,
        Some(GoverningTokenConfigAccountArgs {
            voter_weight_addin: Some(community_voter_weight_addin),
            max_voter_weight_addin: None,
            token_type: GoverningTokenType::Liquid,
        }),
        None,
        5,
        MintMaxVoterWeightSource::SupplyFraction(10_000_000_000),
    );
    assert_eq!(set_realm_config_ix.data[0], 22);
    assert_eq!(set_realm_config_ix.accounts.len(), 6);
    assert_meta(&set_realm_config_ix.accounts[0], realm, false, true);
    assert_meta(
        &set_realm_config_ix.accounts[2],
        system_program::id(),
        false,
        false,
    );
    assert_meta(&set_realm_config_ix.accounts[3], realm_config, false, true);
    assert_meta(
        &set_realm_config_ix.accounts[4],
        community_voter_weight_addin,
        false,
        false,
    );
    assert_meta(&set_realm_config_ix.accounts[5], payer, true, true);

    let create_record_ix = create_token_owner_record(
        &program_id,
        &realm,
        &realm_authority,
        &community_mint,
        &payer,
    );
    assert_eq!(create_record_ix.data, vec![23]);
    assert_eq!(create_record_ix.accounts.len(), 6);
    assert_meta(&create_record_ix.accounts[0], realm, false, false);
    assert_meta(&create_record_ix.accounts[1], realm_authority, false, false);

    let metadata = get_program_metadata_address(&program_id);
    let update_metadata_ix = upgrade_program_metadata(&program_id, &payer);
    assert_eq!(update_metadata_ix.data, vec![24]);
    assert_meta(&update_metadata_ix.accounts[0], metadata, false, true);

    let native_treasury = get_native_treasury_address(&program_id, &governance);
    let treasury_ix = create_native_treasury(&program_id, &governance, &payer);
    assert_eq!(treasury_ix.data, vec![25]);
    assert_meta(&treasury_ix.accounts[1], native_treasury, false, true);

    let revoke_ix = revoke_governing_tokens(
        &program_id,
        &realm,
        &realm_authority,
        &community_mint,
        &realm_authority,
        9,
    );
    assert_eq!(revoke_ix.data, vec![26, 9, 0, 0, 0, 0, 0, 0, 0]);
    assert_eq!(revoke_ix.accounts.len(), 7);
    assert_meta(&revoke_ix.accounts[6], spl_token::id(), false, false);

    let signatory = key(12);
    let required_signatory = get_required_signatory_address(&program_id, &governance, &signatory);
    let add_required_ix = add_required_signatory(&program_id, &governance, &payer, &signatory);
    assert_eq!(add_required_ix.data[0], 29);
    assert_eq!(&add_required_ix.data[1..33], signatory.as_ref());
    assert_meta(&add_required_ix.accounts[0], governance, true, true);
    assert_meta(
        &add_required_ix.accounts[1],
        required_signatory,
        false,
        true,
    );

    let beneficiary = key(13);
    let remove_required_ix =
        remove_required_signatory(&program_id, &governance, &signatory, &beneficiary);
    assert_eq!(remove_required_ix.data, vec![30]);
    assert_meta(&remove_required_ix.accounts[2], beneficiary, false, true);

    let proposal = key(14);
    let proposal_deposit = get_proposal_deposit_address(&program_id, &proposal, &payer);
    let refund_ix = refund_proposal_deposit(&program_id, &proposal, &payer);
    assert_eq!(refund_ix.data, vec![27]);
    assert_meta(&refund_ix.accounts[1], proposal_deposit, false, true);

    let complete_ix = complete_proposal(
        &program_id,
        &proposal,
        &token_owner_record,
        &create_authority,
    );
    assert_eq!(complete_ix.data, vec![28]);
    assert_eq!(complete_ix.accounts.len(), 3);
    assert_meta(&complete_ix.accounts[2], create_authority, true, false);
}

#[test]
fn official_token_deposit_withdraw_and_delegate_match_zig_layout() {
    let program_id = governance_program_id();
    let realm = key(1);
    let mint = key(2);
    let source = key(3);
    let owner = key(4);
    let source_authority = key(5);
    let payer = key(6);
    let destination = key(7);
    let delegate = key(8);

    let token_holding = get_governing_token_holding_address(&program_id, &realm, &mint);
    let token_owner_record = get_token_owner_record_address(&program_id, &realm, &mint, &owner);
    let realm_config = get_realm_config_address(&program_id, &realm);

    let deposit_ix = deposit_governing_tokens(
        &program_id,
        &realm,
        &source,
        &owner,
        &source_authority,
        &payer,
        500,
        &mint,
    );
    assert_eq!(deposit_ix.program_id, program_id);
    assert_eq!(deposit_ix.data, vec![1, 0xf4, 0x01, 0, 0, 0, 0, 0, 0]);
    assert_eq!(deposit_ix.accounts.len(), 10);
    assert_meta(&deposit_ix.accounts[0], realm, false, false);
    assert_meta(&deposit_ix.accounts[1], token_holding, false, true);
    assert_meta(&deposit_ix.accounts[2], source, false, true);
    assert_meta(&deposit_ix.accounts[3], owner, true, false);
    assert_meta(&deposit_ix.accounts[4], source_authority, true, false);
    assert_meta(&deposit_ix.accounts[5], token_owner_record, false, true);
    assert_meta(&deposit_ix.accounts[6], payer, true, true);
    assert_meta(&deposit_ix.accounts[7], system_program::id(), false, false);
    assert_meta(&deposit_ix.accounts[8], spl_token::id(), false, false);
    assert_meta(&deposit_ix.accounts[9], realm_config, false, false);

    let withdraw_ix = withdraw_governing_tokens(&program_id, &realm, &destination, &owner, &mint);
    assert_eq!(withdraw_ix.data, vec![2]);
    assert_eq!(withdraw_ix.accounts.len(), 7);
    assert_meta(&withdraw_ix.accounts[0], realm, false, false);
    assert_meta(&withdraw_ix.accounts[1], token_holding, false, true);
    assert_meta(&withdraw_ix.accounts[2], destination, false, true);
    assert_meta(&withdraw_ix.accounts[3], owner, true, false);
    assert_meta(&withdraw_ix.accounts[4], token_owner_record, false, true);
    assert_meta(&withdraw_ix.accounts[5], spl_token::id(), false, false);
    assert_meta(&withdraw_ix.accounts[6], realm_config, false, false);

    let set_delegate_ix =
        set_governance_delegate(&program_id, &owner, &realm, &mint, &owner, &Some(delegate));
    assert_eq!(set_delegate_ix.data[0], 3);
    assert_eq!(set_delegate_ix.data[1], 1);
    assert_eq!(&set_delegate_ix.data[2..34], delegate.as_ref());
    assert_eq!(set_delegate_ix.accounts.len(), 2);
    assert_meta(&set_delegate_ix.accounts[0], owner, true, false);
    assert_meta(
        &set_delegate_ix.accounts[1],
        token_owner_record,
        false,
        true,
    );

    let clear_delegate_ix =
        set_governance_delegate(&program_id, &owner, &realm, &mint, &owner, &None);
    assert_eq!(clear_delegate_ix.data, vec![3, 0]);
}

#[test]
fn official_proposal_signatory_and_vote_builders_match_zig_layout() {
    let program_id = governance_program_id();
    let realm = key(1);
    let governance = key(2);
    let owner_record = key(3);
    let governing_mint = key(4);
    let authority = key(5);
    let payer = key(6);
    let proposal_seed = key(7);
    let proposal = get_proposal_address(&program_id, &governance, &governing_mint, &proposal_seed);
    let proposal_deposit = get_proposal_deposit_address(&program_id, &proposal, &payer);
    let realm_config = get_realm_config_address(&program_id, &realm);
    let signatory = key(8);
    let signatory_record = get_signatory_record_address(&program_id, &proposal, &signatory);
    let voter_record = key(9);
    let vote_record = get_vote_record_address(&program_id, &proposal, &voter_record);
    let voter_weight_record = key(10);
    let max_voter_weight_record = key(11);
    let beneficiary = key(12);

    let create_ix = create_proposal(
        &program_id,
        &governance,
        &owner_record,
        &authority,
        &payer,
        None,
        &realm,
        "ship".to_string(),
        "https://example.invalid".to_string(),
        &governing_mint,
        VoteType::SingleChoice,
        vec!["yes".to_string()],
        true,
        &proposal_seed,
    );
    assert_eq!(create_ix.data[0], 6);
    assert_eq!(create_ix.accounts.len(), 10);
    assert_meta(&create_ix.accounts[0], realm, false, false);
    assert_meta(&create_ix.accounts[1], proposal, false, true);
    assert_meta(&create_ix.accounts[2], governance, false, true);
    assert_meta(&create_ix.accounts[3], owner_record, false, true);
    assert_meta(&create_ix.accounts[4], governing_mint, false, false);
    assert_meta(&create_ix.accounts[5], authority, true, false);
    assert_meta(&create_ix.accounts[6], payer, true, true);
    assert_meta(&create_ix.accounts[7], system_program::id(), false, false);
    assert_meta(&create_ix.accounts[8], realm_config, false, false);
    assert_meta(&create_ix.accounts[9], proposal_deposit, false, true);

    let add_ix = add_signatory(
        &program_id,
        &governance,
        &proposal,
        &AddSignatoryAuthority::ProposalOwner {
            governance_authority: authority,
            token_owner_record: owner_record,
        },
        &payer,
        &signatory,
    );
    assert_eq!(add_ix.data[0], 7);
    assert_eq!(&add_ix.data[1..33], signatory.as_ref());
    assert_eq!(add_ix.accounts.len(), 7);
    assert_meta(&add_ix.accounts[0], governance, false, false);
    assert_meta(&add_ix.accounts[1], proposal, false, true);
    assert_meta(&add_ix.accounts[2], signatory_record, false, true);
    assert_meta(&add_ix.accounts[3], payer, true, true);
    assert_meta(&add_ix.accounts[4], system_program::id(), false, false);
    assert_meta(&add_ix.accounts[5], owner_record, false, false);
    assert_meta(&add_ix.accounts[6], authority, true, false);

    let sign_off_owner_ix = sign_off_proposal(
        &program_id,
        &realm,
        &governance,
        &proposal,
        &authority,
        Some(&owner_record),
    );
    assert_eq!(sign_off_owner_ix.data, vec![12]);
    assert_eq!(sign_off_owner_ix.accounts.len(), 5);
    assert_meta(&sign_off_owner_ix.accounts[2], proposal, false, true);
    assert_meta(&sign_off_owner_ix.accounts[3], authority, true, false);
    assert_meta(&sign_off_owner_ix.accounts[4], owner_record, false, false);

    let sign_off_signatory_ix = sign_off_proposal(
        &program_id,
        &realm,
        &governance,
        &proposal,
        &signatory,
        None,
    );
    assert_eq!(sign_off_signatory_ix.data, vec![12]);
    assert_meta(
        &sign_off_signatory_ix.accounts[4],
        signatory_record,
        false,
        true,
    );

    let cast_ix = cast_vote(
        &program_id,
        &realm,
        &governance,
        &proposal,
        &owner_record,
        &voter_record,
        &authority,
        &governing_mint,
        &payer,
        Some(voter_weight_record),
        Some(max_voter_weight_record),
        Vote::Approve(vec![VoteChoice {
            rank: 0,
            weight_percentage: 100,
        }]),
    );
    assert_eq!(cast_ix.data, vec![13, 0, 1, 0, 0, 0, 0, 100]);
    assert_eq!(cast_ix.accounts.len(), 13);
    assert_meta(&cast_ix.accounts[0], realm, false, false);
    assert_meta(&cast_ix.accounts[1], governance, false, true);
    assert_meta(&cast_ix.accounts[2], proposal, false, true);
    assert_meta(&cast_ix.accounts[3], owner_record, false, true);
    assert_meta(&cast_ix.accounts[4], voter_record, false, true);
    assert_meta(&cast_ix.accounts[5], authority, true, false);
    assert_meta(&cast_ix.accounts[6], vote_record, false, true);
    assert_meta(&cast_ix.accounts[7], governing_mint, false, false);
    assert_meta(&cast_ix.accounts[8], payer, true, true);
    assert_meta(&cast_ix.accounts[9], system_program::id(), false, false);
    assert_meta(&cast_ix.accounts[10], realm_config, false, false);
    assert_meta(&cast_ix.accounts[11], voter_weight_record, false, false);
    assert_meta(&cast_ix.accounts[12], max_voter_weight_record, false, false);

    let finalize_ix = finalize_vote(
        &program_id,
        &realm,
        &governance,
        &proposal,
        &owner_record,
        &governing_mint,
        Some(max_voter_weight_record),
    );
    assert_eq!(finalize_ix.data, vec![14]);
    assert_eq!(finalize_ix.accounts.len(), 7);
    assert_meta(&finalize_ix.accounts[5], realm_config, false, false);
    assert_meta(
        &finalize_ix.accounts[6],
        max_voter_weight_record,
        false,
        false,
    );

    let cancel_ix = cancel_proposal(
        &program_id,
        &realm,
        &governance,
        &proposal,
        &owner_record,
        &authority,
    );
    assert_eq!(cancel_ix.data, vec![11]);
    assert_eq!(cancel_ix.accounts.len(), 5);
    assert_meta(&cancel_ix.accounts[4], authority, true, false);

    let relinquish_ix = relinquish_vote(
        &program_id,
        &realm,
        &governance,
        &proposal,
        &voter_record,
        &governing_mint,
        Some(authority),
        Some(beneficiary),
    );
    assert_eq!(relinquish_ix.data, vec![15]);
    assert_eq!(relinquish_ix.accounts.len(), 8);
    assert_meta(&relinquish_ix.accounts[4], vote_record, false, true);
    assert_meta(&relinquish_ix.accounts[6], authority, true, false);
    assert_meta(&relinquish_ix.accounts[7], beneficiary, false, true);
}

#[test]
fn official_proposal_transaction_builders_match_zig_layout() {
    let program_id = governance_program_id();
    let governance = key(1);
    let proposal = key(2);
    let owner_record = key(3);
    let authority = key(4);
    let payer = key(5);
    let proposal_transaction =
        get_proposal_transaction_address(&program_id, &proposal, &[2], &9u16.to_le_bytes());
    let beneficiary = key(6);
    let nested_program = key(7);
    let nested_account = key(8);

    let insert_ix = insert_transaction(
        &program_id,
        &governance,
        &proposal,
        &owner_record,
        &authority,
        &payer,
        2,
        9,
        30,
        vec![InstructionData {
            program_id: nested_program,
            accounts: vec![AccountMetaData {
                pubkey: nested_account,
                is_signer: true,
                is_writable: false,
            }],
            data: vec![0xaa, 0xbb],
        }],
    );
    assert_eq!(insert_ix.data[0..8], [9, 2, 9, 0, 30, 0, 0, 0]);
    assert_eq!(
        u32::from_le_bytes(insert_ix.data[8..12].try_into().unwrap()),
        1
    );
    assert_eq!(&insert_ix.data[12..44], nested_program.as_ref());
    assert_eq!(
        u32::from_le_bytes(insert_ix.data[44..48].try_into().unwrap()),
        1
    );
    assert_eq!(&insert_ix.data[48..80], nested_account.as_ref());
    assert_eq!(insert_ix.data[80], 1);
    assert_eq!(insert_ix.data[81], 0);
    assert_eq!(
        u32::from_le_bytes(insert_ix.data[82..86].try_into().unwrap()),
        2
    );
    assert_eq!(&insert_ix.data[86..88], &[0xaa, 0xbb]);
    assert_eq!(insert_ix.accounts.len(), 8);
    assert_meta(&insert_ix.accounts[0], governance, false, false);
    assert_meta(&insert_ix.accounts[1], proposal, false, true);
    assert_meta(&insert_ix.accounts[2], owner_record, false, false);
    assert_meta(&insert_ix.accounts[3], authority, true, false);
    assert_meta(&insert_ix.accounts[4], proposal_transaction, false, true);
    assert_meta(&insert_ix.accounts[5], payer, true, true);
    assert_meta(&insert_ix.accounts[6], system_program::id(), false, false);

    let remove_ix = remove_transaction(
        &program_id,
        &proposal,
        &owner_record,
        &authority,
        &proposal_transaction,
        &beneficiary,
    );
    assert_eq!(remove_ix.data, vec![10]);
    assert_eq!(remove_ix.accounts.len(), 5);
    assert_meta(&remove_ix.accounts[0], proposal, false, true);
    assert_meta(&remove_ix.accounts[4], beneficiary, false, true);

    let execute_ix = execute_transaction(
        &program_id,
        &governance,
        &proposal,
        &proposal_transaction,
        &nested_program,
        &[AccountMeta::new_readonly(nested_account, true)],
    );
    assert_eq!(execute_ix.data, vec![16]);
    assert_eq!(execute_ix.accounts.len(), 5);
    assert_meta(&execute_ix.accounts[0], governance, false, false);
    assert_meta(&execute_ix.accounts[2], proposal_transaction, false, true);
    assert_meta(&execute_ix.accounts[3], nested_program, false, false);
    assert_meta(&execute_ix.accounts[4], nested_account, true, false);

    let flag_ix = flag_transaction_error(
        &program_id,
        &proposal,
        &owner_record,
        &authority,
        &proposal_transaction,
    );
    assert_eq!(flag_ix.data, vec![20]);
    assert_eq!(flag_ix.accounts.len(), 4);
    assert_meta(&flag_ix.accounts[0], proposal, false, true);
    assert_meta(&flag_ix.accounts[3], proposal_transaction, false, true);
}

#[test]
fn governance_account_type_discriminants_match_zig_enum() {
    assert_eq!(GovernanceAccountType::Uninitialized as u8, 0);
    assert_eq!(GovernanceAccountType::RealmV2 as u8, 16);
    assert_eq!(GovernanceAccountType::TokenOwnerRecordV2 as u8, 17);
    assert_eq!(GovernanceAccountType::ProgramGovernanceV2 as u8, 19);
    assert_eq!(GovernanceAccountType::ProposalDeposit as u8, 23);
    assert_eq!(GovernanceAccountType::RequiredSignatory as u8, 24);
}
