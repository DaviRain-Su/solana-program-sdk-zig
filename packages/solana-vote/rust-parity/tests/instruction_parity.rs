use solana_instruction::AccountMeta;
use solana_pubkey::Pubkey;
use solana_vote_interface::{
    instruction as vote_instruction,
    state::{VoteAuthorize, VoteInit},
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
