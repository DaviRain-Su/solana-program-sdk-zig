use solana_hash::Hash;
use solana_instruction::AccountMeta;
use solana_pubkey::Pubkey;
use solana_vote_interface::{
    instruction as vote_instruction,
    state::{Lockout, TowerSync, Vote, VoteAuthorize, VoteInit, VoteStateUpdate},
};
use std::collections::VecDeque;

fn key(byte: u8) -> Pubkey {
    Pubkey::from([byte; 32])
}

fn hash(byte: u8) -> Hash {
    Hash::new_from_array([byte; 32])
}

fn assert_meta(meta: &AccountMeta, pubkey: Pubkey, is_signer: bool, is_writable: bool) {
    assert_eq!(meta.pubkey, pubkey);
    assert_eq!(meta.is_signer, is_signer);
    assert_eq!(meta.is_writable, is_writable);
}

#[test]
fn official_initialize_matches_zig_layout() {
    let vote_account = key(1);
    let vote_init = VoteInit {
        node_pubkey: key(2),
        authorized_voter: key(3),
        authorized_withdrawer: key(4),
        commission: 7,
    };
    let instructions = vote_instruction::create_account_with_config(
        &key(9),
        &vote_account,
        &vote_init,
        1_000,
        Default::default(),
    );
    let ix = &instructions[1];

    assert_eq!(ix.program_id, solana_vote_interface::program::ID);
    assert_meta(&ix.accounts[0], vote_account, false, true);
    assert_meta(&ix.accounts[3], vote_init.node_pubkey, true, false);
    assert_eq!(&ix.data[0..4], &[0, 0, 0, 0]);
    assert_eq!(&ix.data[4..36], &vote_init.node_pubkey.to_bytes());
    assert_eq!(&ix.data[36..68], &vote_init.authorized_voter.to_bytes());
    assert_eq!(
        &ix.data[68..100],
        &vote_init.authorized_withdrawer.to_bytes()
    );
    assert_eq!(ix.data[100], 7);
}

#[test]
fn official_authorize_builders_match_zig_layout() {
    let vote_account = key(1);
    let current = key(2);
    let next = key(3);

    let authorize =
        vote_instruction::authorize(&vote_account, &current, &next, VoteAuthorize::Withdrawer);
    assert_eq!(&authorize.data[0..4], &[1, 0, 0, 0]);
    assert_eq!(&authorize.data[4..36], &next.to_bytes());
    assert_eq!(&authorize.data[36..40], &[1, 0, 0, 0]);
    assert_meta(&authorize.accounts[2], current, true, false);

    let checked =
        vote_instruction::authorize_checked(&vote_account, &current, &next, VoteAuthorize::Voter);
    assert_eq!(checked.data, [7, 0, 0, 0, 0, 0, 0, 0]);
    assert_meta(&checked.accounts[3], next, true, false);
}

#[test]
fn official_seeded_authorize_builders_match_zig_layout() {
    let vote_account = key(1);
    let base = key(2);
    let owner = key(3);
    let next = key(4);

    let seeded = vote_instruction::authorize_with_seed(
        &vote_account,
        &base,
        &owner,
        "seed",
        &next,
        VoteAuthorize::Withdrawer,
    );
    assert_eq!(&seeded.data[0..4], &[10, 0, 0, 0]);
    assert_eq!(&seeded.data[4..8], &[1, 0, 0, 0]);
    assert_eq!(&seeded.data[8..40], &owner.to_bytes());
    assert_eq!(
        u64::from_le_bytes(seeded.data[40..48].try_into().unwrap()),
        4
    );
    assert_eq!(&seeded.data[48..52], b"seed");
    assert_eq!(&seeded.data[52..84], &next.to_bytes());
    assert_meta(&seeded.accounts[2], base, true, false);

    let checked = vote_instruction::authorize_checked_with_seed(
        &vote_account,
        &base,
        &owner,
        "seed",
        &next,
        VoteAuthorize::Voter,
    );
    assert_eq!(&checked.data[0..4], &[11, 0, 0, 0]);
    assert_eq!(&checked.data[4..8], &[0, 0, 0, 0]);
    assert_eq!(&checked.data[8..40], &owner.to_bytes());
    assert_eq!(
        u64::from_le_bytes(checked.data[40..48].try_into().unwrap()),
        4
    );
    assert_eq!(&checked.data[48..52], b"seed");
    assert_eq!(checked.accounts.len(), 4);
    assert_meta(&checked.accounts[2], base, true, false);
    assert_meta(&checked.accounts[3], next, true, false);
}

#[test]
fn official_account_management_builders_match_zig_layout() {
    let vote_account = key(1);
    let withdrawer = key(2);
    let node = key(3);
    let to = key(4);

    let identity = vote_instruction::update_validator_identity(&vote_account, &withdrawer, &node);
    assert_eq!(identity.data, [4, 0, 0, 0]);
    assert_meta(&identity.accounts[1], node, true, false);
    assert_meta(&identity.accounts[2], withdrawer, true, false);

    let commission = vote_instruction::update_commission(&vote_account, &withdrawer, 9);
    assert_eq!(commission.data, [5, 0, 0, 0, 9]);
    assert_meta(&commission.accounts[1], withdrawer, true, false);

    let withdraw = vote_instruction::withdraw(&vote_account, &withdrawer, 500, &to);
    assert_eq!(&withdraw.data[0..4], &[3, 0, 0, 0]);
    assert_eq!(
        u64::from_le_bytes(withdraw.data[4..12].try_into().unwrap()),
        500
    );
    assert_meta(&withdraw.accounts[1], to, false, true);
    assert_meta(&withdraw.accounts[2], withdrawer, true, false);
}

#[test]
fn official_runtime_vote_builders_match_zig_typed_payload_layout() {
    let vote_account = key(1);
    let voter = key(2);
    let vote = Vote {
        slots: vec![10, 11],
        hash: hash(9),
        timestamp: Some(-5),
    };
    let proof_hash = hash(7);

    let ix = vote_instruction::vote(&vote_account, &voter, vote.clone());
    assert_eq!(ix.data.len(), 69);
    assert_eq!(&ix.data[0..4], &[2, 0, 0, 0]);
    assert_eq!(u64::from_le_bytes(ix.data[4..12].try_into().unwrap()), 2);
    assert_eq!(u64::from_le_bytes(ix.data[12..20].try_into().unwrap()), 10);
    assert_eq!(u64::from_le_bytes(ix.data[20..28].try_into().unwrap()), 11);
    assert_eq!(&ix.data[28..60], &[9; 32]);
    assert_eq!(ix.data[60], 1);
    assert_eq!(i64::from_le_bytes(ix.data[61..69].try_into().unwrap()), -5);
    assert!(!ix.accounts[1].is_signer);
    assert!(!ix.accounts[2].is_signer);

    let switch = vote_instruction::vote_switch(&vote_account, &voter, vote, proof_hash);
    assert_eq!(&switch.data[0..4], &[6, 0, 0, 0]);
    assert_eq!(&switch.data[69..101], &[7; 32]);
}

#[test]
fn official_vote_state_and_tower_builders_match_zig_typed_payload_layout() {
    let vote_account = key(1);
    let voter = key(2);
    let proof_hash = hash(7);
    let lockouts = VecDeque::from(vec![
        Lockout::new_with_confirmation_count(100, 3),
        Lockout::new_with_confirmation_count(105, 4),
    ]);
    let update = VoteStateUpdate::new(lockouts.clone(), Some(90), hash(8));

    let ix = vote_instruction::update_vote_state(&vote_account, &voter, update.clone());
    assert_eq!(ix.data.len(), 78);
    assert_eq!(&ix.data[0..4], &[8, 0, 0, 0]);
    assert_eq!(u64::from_le_bytes(ix.data[4..12].try_into().unwrap()), 2);
    assert_eq!(u64::from_le_bytes(ix.data[12..20].try_into().unwrap()), 100);
    assert_eq!(u32::from_le_bytes(ix.data[20..24].try_into().unwrap()), 3);
    assert_eq!(u64::from_le_bytes(ix.data[24..32].try_into().unwrap()), 105);
    assert_eq!(u32::from_le_bytes(ix.data[32..36].try_into().unwrap()), 4);
    assert_eq!(ix.data[36], 1);
    assert_eq!(u64::from_le_bytes(ix.data[37..45].try_into().unwrap()), 90);
    assert_eq!(&ix.data[45..77], &[8; 32]);
    assert_eq!(ix.data[77], 0);

    let switch = vote_instruction::update_vote_state_switch(
        &vote_account,
        &voter,
        update.clone(),
        proof_hash,
    );
    assert_eq!(&switch.data[0..4], &[9, 0, 0, 0]);
    assert_eq!(&switch.data[78..110], &[7; 32]);

    let compact = vote_instruction::compact_update_vote_state(&vote_account, &voter, update);
    assert_eq!(compact.data.len(), 50);
    assert_eq!(&compact.data[0..4], &[12, 0, 0, 0]);
    assert_eq!(
        u64::from_le_bytes(compact.data[4..12].try_into().unwrap()),
        90
    );
    assert_eq!(&compact.data[12..17], &[2, 10, 3, 5, 4]);
    assert_eq!(&compact.data[17..49], &[8; 32]);
    assert_eq!(compact.data[49], 0);

    let tower = TowerSync::new(lockouts, None, hash(8), hash(6));
    let tower_ix = vote_instruction::tower_sync(&vote_account, &voter, tower.clone());
    assert_eq!(tower_ix.data.len(), 82);
    assert_eq!(&tower_ix.data[0..4], &[14, 0, 0, 0]);
    assert_eq!(
        u64::from_le_bytes(tower_ix.data[4..12].try_into().unwrap()),
        u64::MAX
    );
    assert_eq!(&tower_ix.data[12..17], &[2, 100, 3, 5, 4]);
    assert_eq!(&tower_ix.data[17..49], &[8; 32]);
    assert_eq!(tower_ix.data[49], 0);
    assert_eq!(&tower_ix.data[50..82], &[6; 32]);

    let tower_switch =
        vote_instruction::tower_sync_switch(&vote_account, &voter, tower, proof_hash);
    assert_eq!(&tower_switch.data[0..4], &[15, 0, 0, 0]);
    assert_eq!(&tower_switch.data[82..114], &[7; 32]);
}
