use solana_instruction::AccountMeta;
use solana_pubkey::Pubkey;
use solana_stake_interface::{
    instruction as stake_instruction,
    state::{Authorized, Lockup, StakeAuthorize},
};

fn key(byte: u8) -> Pubkey {
    Pubkey::from([byte; 32])
}

fn assert_meta(meta: &AccountMeta, pubkey: Pubkey, is_signer: bool, is_writable: bool) {
    assert_eq!(meta.pubkey, pubkey);
    assert_eq!(meta.is_signer, is_signer);
    assert_eq!(meta.is_writable, is_writable);
}

#[test]
fn official_initialize_matches_zig_layout() {
    let stake = key(1);
    let authorized = Authorized {
        staker: key(2),
        withdrawer: key(3),
    };
    let lockup = Lockup {
        unix_timestamp: -5,
        epoch: 9,
        custodian: key(4),
    };
    let ix = stake_instruction::initialize(&stake, &authorized, &lockup);

    assert_eq!(ix.program_id, solana_stake_interface::program::ID);
    assert_meta(&ix.accounts[0], stake, false, true);
    assert_eq!(ix.data[0..4], [0, 0, 0, 0]);
    assert_eq!(ix.data[4..36], authorized.staker.to_bytes());
    assert_eq!(ix.data[36..68], authorized.withdrawer.to_bytes());
    assert_eq!(i64::from_le_bytes(ix.data[68..76].try_into().unwrap()), -5);
    assert_eq!(u64::from_le_bytes(ix.data[76..84].try_into().unwrap()), 9);
    assert_eq!(ix.data[84..116], lockup.custodian.to_bytes());
}

#[test]
fn official_checked_and_authorize_builders_match_zig_layout() {
    let stake = key(1);
    let authorized = Authorized {
        staker: key(2),
        withdrawer: key(3),
    };
    let custodian = key(4);
    let checked = stake_instruction::initialize_checked(&stake, &authorized);
    assert_eq!(checked.data, [9, 0, 0, 0]);
    assert_meta(&checked.accounts[2], authorized.staker, false, false);
    assert_meta(&checked.accounts[3], authorized.withdrawer, true, false);

    let authorize = stake_instruction::authorize(
        &stake,
        &authorized.withdrawer,
        &key(5),
        StakeAuthorize::Withdrawer,
        Some(&custodian),
    );
    assert_eq!(&authorize.data[0..4], &[1, 0, 0, 0]);
    assert_eq!(&authorize.data[4..36], &key(5).to_bytes());
    assert_eq!(&authorize.data[36..40], &[1, 0, 0, 0]);
    assert_meta(&authorize.accounts[3], custodian, true, false);

    let authorize_checked = stake_instruction::authorize_checked(
        &stake,
        &authorized.staker,
        &key(6),
        StakeAuthorize::Staker,
        None,
    );
    assert_eq!(authorize_checked.data, [10, 0, 0, 0, 0, 0, 0, 0]);
    assert_eq!(authorize_checked.accounts.len(), 4);
    assert_meta(&authorize_checked.accounts[3], key(6), true, false);
}

#[test]
fn official_seeded_authorize_and_lockup_builders_match_zig_layout() {
    let stake = key(1);
    let authority_base = key(2);
    let authority_owner = key(3);
    let next = key(4);
    let custodian = key(5);
    let new_custodian = key(6);

    let seeded = stake_instruction::authorize_with_seed(
        &stake,
        &authority_base,
        "seed".to_string(),
        &authority_owner,
        &next,
        StakeAuthorize::Withdrawer,
        Some(&custodian),
    );
    assert_eq!(&seeded.data[0..4], &[8, 0, 0, 0]);
    assert_eq!(&seeded.data[4..36], &next.to_bytes());
    assert_eq!(&seeded.data[36..40], &[1, 0, 0, 0]);
    assert_eq!(
        u64::from_le_bytes(seeded.data[40..48].try_into().unwrap()),
        4
    );
    assert_eq!(&seeded.data[48..52], b"seed");
    assert_eq!(&seeded.data[52..84], &authority_owner.to_bytes());
    assert_meta(&seeded.accounts[1], authority_base, true, false);
    assert_meta(&seeded.accounts[3], custodian, true, false);

    let checked_seeded = stake_instruction::authorize_checked_with_seed(
        &stake,
        &authority_base,
        "seed".to_string(),
        &authority_owner,
        &next,
        StakeAuthorize::Staker,
        None,
    );
    assert_eq!(&checked_seeded.data[0..4], &[11, 0, 0, 0]);
    assert_eq!(&checked_seeded.data[4..8], &[0, 0, 0, 0]);
    assert_eq!(
        u64::from_le_bytes(checked_seeded.data[8..16].try_into().unwrap()),
        4
    );
    assert_eq!(&checked_seeded.data[16..20], b"seed");
    assert_eq!(&checked_seeded.data[20..52], &authority_owner.to_bytes());
    assert_eq!(checked_seeded.accounts.len(), 4);
    assert_meta(&checked_seeded.accounts[3], next, true, false);

    let lockup = stake_instruction::LockupArgs {
        unix_timestamp: Some(-5),
        epoch: Some(9),
        custodian: Some(new_custodian),
    };
    let set_lockup = stake_instruction::set_lockup(&stake, &lockup, &custodian);
    assert_eq!(&set_lockup.data[0..4], &[6, 0, 0, 0]);
    assert_eq!(set_lockup.data[4], 1);
    assert_eq!(
        i64::from_le_bytes(set_lockup.data[5..13].try_into().unwrap()),
        -5
    );
    assert_eq!(set_lockup.data[13], 1);
    assert_eq!(
        u64::from_le_bytes(set_lockup.data[14..22].try_into().unwrap()),
        9
    );
    assert_eq!(set_lockup.data[22], 1);
    assert_eq!(&set_lockup.data[23..55], &new_custodian.to_bytes());
    assert_meta(&set_lockup.accounts[1], custodian, true, false);

    let checked_lockup = stake_instruction::set_lockup_checked(&stake, &lockup, &custodian);
    assert_eq!(&checked_lockup.data[0..4], &[12, 0, 0, 0]);
    assert_eq!(checked_lockup.data[4], 1);
    assert_eq!(
        i64::from_le_bytes(checked_lockup.data[5..13].try_into().unwrap()),
        -5
    );
    assert_eq!(checked_lockup.data[13], 1);
    assert_eq!(
        u64::from_le_bytes(checked_lockup.data[14..22].try_into().unwrap()),
        9
    );
    assert_eq!(checked_lockup.accounts.len(), 3);
    assert_meta(&checked_lockup.accounts[2], new_custodian, true, false);
}

#[test]
fn official_stake_flow_builders_match_zig_layout() {
    let stake = key(1);
    let other = key(2);
    let authority = key(3);
    let vote = key(4);
    let to = key(5);

    let delegate = stake_instruction::delegate_stake(&stake, &authority, &vote);
    assert_eq!(delegate.data, [2, 0, 0, 0]);
    assert_eq!(delegate.accounts.len(), 6);
    assert_meta(&delegate.accounts[0], stake, false, true);
    assert_meta(&delegate.accounts[1], vote, false, false);
    assert_meta(&delegate.accounts[5], authority, true, false);

    let split_instructions = stake_instruction::split(&stake, &authority, 500, &other);
    let split = &split_instructions[2];
    assert_eq!(&split.data[0..4], &[3, 0, 0, 0]);
    assert_eq!(
        u64::from_le_bytes(split.data[4..12].try_into().unwrap()),
        500
    );
    assert_meta(&split.accounts[1], other, false, true);

    let withdraw = stake_instruction::withdraw(&stake, &authority, &to, 600, None);
    assert_eq!(&withdraw.data[0..4], &[4, 0, 0, 0]);
    assert_eq!(
        u64::from_le_bytes(withdraw.data[4..12].try_into().unwrap()),
        600
    );
    assert_eq!(withdraw.accounts.len(), 5);
    assert_meta(&withdraw.accounts[1], to, false, true);

    let deactivate = stake_instruction::deactivate_stake(&stake, &authority);
    assert_eq!(deactivate.data, [5, 0, 0, 0]);
    assert_meta(&deactivate.accounts[2], authority, true, false);

    let merge = stake_instruction::merge(&stake, &other, &authority);
    assert_eq!(merge[0].data, [7, 0, 0, 0]);
    assert_meta(&merge[0].accounts[1], other, false, true);
}

#[test]
fn official_recent_builders_match_zig_layout() {
    let stake = key(1);
    let other = key(2);
    let authority = key(3);
    let vote_a = key(4);
    let vote_b = key(5);

    let minimum = stake_instruction::get_minimum_delegation();
    assert_eq!(minimum.accounts.len(), 0);
    assert_eq!(minimum.data, [13, 0, 0, 0]);

    let delinquent = stake_instruction::deactivate_delinquent_stake(&stake, &vote_a, &vote_b);
    assert_eq!(delinquent.data, [14, 0, 0, 0]);
    assert_meta(&delinquent.accounts[0], stake, false, true);
    assert_meta(&delinquent.accounts[1], vote_a, false, false);

    let move_stake = stake_instruction::move_stake(&stake, &other, &authority, 700);
    assert_eq!(&move_stake.data[0..4], &[16, 0, 0, 0]);
    assert_eq!(
        u64::from_le_bytes(move_stake.data[4..12].try_into().unwrap()),
        700
    );
    assert_meta(&move_stake.accounts[2], authority, true, false);

    let move_lamports = stake_instruction::move_lamports(&stake, &other, &authority, 800);
    assert_eq!(&move_lamports.data[0..4], &[17, 0, 0, 0]);
    assert_eq!(
        u64::from_le_bytes(move_lamports.data[4..12].try_into().unwrap()),
        800
    );
    assert_meta(&move_lamports.accounts[1], other, false, true);
}
