use {
    solana_program::{instruction::AccountMeta, pubkey::Pubkey, system_program},
    spl_name_service::{
        instruction::{create, delete, realloc, transfer, update, NameRegistryInstruction},
        state::{get_seeds_and_key, NameRecordHeader, HASH_PREFIX},
    },
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
fn official_header_and_seed_helpers_match_zig_surface() {
    assert_eq!(
        spl_name_service::id().to_string(),
        "namesLPneVptA9Z5rqUDD9tMTWEJwofgaYwp8cawRkX"
    );
    assert_eq!(HASH_PREFIX, "SPL Name Service");

    let header = NameRecordHeader {
        parent_name: key(1),
        owner: key(2),
        class: key(3),
    };
    let packed = borsh::to_vec(&header).unwrap();
    assert_eq!(packed.len(), 96);
    assert_eq!(&packed[0..32], &key(1).to_bytes());
    assert_eq!(&packed[32..64], &key(2).to_bytes());
    assert_eq!(&packed[64..96], &key(3).to_bytes());

    let hashed_name = vec![7u8; 32];
    let (derived, seeds) = get_seeds_and_key(
        &spl_name_service::id(),
        hashed_name.clone(),
        Some(&key(3)),
        Some(&key(4)),
    );
    let (expected, bump) = Pubkey::find_program_address(
        &[&hashed_name, &key(3).to_bytes(), &key(4).to_bytes()],
        &spl_name_service::id(),
    );
    assert_eq!(derived, expected);
    assert_eq!(seeds.len(), 97);
    assert_eq!(seeds[96], bump);
}

#[test]
fn official_create_builder_matches_zig_account_and_data_layout() {
    let name_account = key(9);
    let payer = key(1);
    let owner = key(2);
    let class = key(3);
    let parent = key(4);
    let parent_owner = key(5);
    let hashed_name = vec![1, 2, 3];

    let ix = create(
        spl_name_service::id(),
        NameRegistryInstruction::Create {
            hashed_name: hashed_name.clone(),
            lamports: 50,
            space: 10,
        },
        name_account,
        payer,
        owner,
        Some(class),
        Some(parent),
        Some(parent_owner),
    )
    .unwrap();

    assert_eq!(ix.program_id, spl_name_service::id());
    assert_eq!(ix.accounts.len(), 7);
    assert_meta(&ix.accounts[0], system_program::id(), false, false);
    assert_meta(&ix.accounts[1], payer, true, true);
    assert_meta(&ix.accounts[2], name_account, false, true);
    assert_meta(&ix.accounts[3], owner, false, false);
    assert_meta(&ix.accounts[4], class, true, false);
    assert_meta(&ix.accounts[5], parent, false, false);
    assert_meta(&ix.accounts[6], parent_owner, true, false);
    assert_eq!(
        ix.data,
        vec![0, 3, 0, 0, 0, 1, 2, 3, 50, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0]
    );
}

#[test]
fn official_update_transfer_delete_realloc_builders_match_zig_layout() {
    let name_account = key(9);
    let owner = key(1);
    let new_owner = key(2);
    let class = key(3);
    let parent = key(4);
    let refund = key(5);

    let update_ix = update(
        spl_name_service::id(),
        7,
        b"abc".to_vec(),
        name_account,
        owner,
        Some(parent),
    )
    .unwrap();
    assert_eq!(update_ix.accounts.len(), 3);
    assert_meta(&update_ix.accounts[0], name_account, false, true);
    assert_meta(&update_ix.accounts[1], owner, true, false);
    assert_meta(&update_ix.accounts[2], parent, false, true);
    assert_eq!(
        update_ix.data,
        vec![1, 7, 0, 0, 0, 3, 0, 0, 0, b'a', b'b', b'c']
    );

    let transfer_ix = transfer(
        spl_name_service::id(),
        new_owner,
        name_account,
        owner,
        Some(class),
    )
    .unwrap();
    assert_eq!(transfer_ix.accounts.len(), 3);
    assert_meta(&transfer_ix.accounts[0], name_account, false, true);
    assert_meta(&transfer_ix.accounts[1], owner, true, false);
    assert_meta(&transfer_ix.accounts[2], class, true, false);
    assert_eq!(transfer_ix.data[0], 2);
    assert_eq!(&transfer_ix.data[1..33], &new_owner.to_bytes());

    let delete_ix = delete(spl_name_service::id(), name_account, owner, refund).unwrap();
    assert_eq!(delete_ix.data, vec![3]);
    assert_meta(&delete_ix.accounts[2], refund, false, true);

    let realloc_ix = realloc(spl_name_service::id(), refund, name_account, owner, 99).unwrap();
    assert_eq!(realloc_ix.data, vec![4, 99, 0, 0, 0]);
    assert_meta(&realloc_ix.accounts[0], system_program::id(), false, false);
    assert_meta(&realloc_ix.accounts[1], refund, true, true);
    assert_meta(&realloc_ix.accounts[2], name_account, false, true);
    assert_meta(&realloc_ix.accounts[3], owner, true, false);
}
