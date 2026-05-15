use {
    solana_address_lookup_table_interface::instruction::{
        close_lookup_table, create_lookup_table, deactivate_lookup_table,
        derive_lookup_table_address, extend_lookup_table, freeze_lookup_table, ProgramInstruction,
    },
    solana_instruction::AccountMeta,
    solana_pubkey::Pubkey,
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
fn official_create_builder_matches_zig_layout() {
    let authority = key(1);
    let payer = key(2);
    let recent_slot = 12345;
    let (table, bump) = derive_lookup_table_address(&authority, recent_slot);
    let (ix, returned_table) = create_lookup_table(authority, payer, recent_slot);

    assert_eq!(returned_table, table);
    assert_eq!(&ix.data[0..4], &[0, 0, 0, 0]);
    assert_eq!(
        u64::from_le_bytes(ix.data[4..12].try_into().unwrap()),
        recent_slot
    );
    assert_eq!(ix.data[12], bump);
    assert_eq!(ix.accounts.len(), 4);
    assert_meta(&ix.accounts[0], table, false, true);
    assert_meta(&ix.accounts[1], authority, false, false);
    assert_meta(&ix.accounts[2], payer, true, true);
    assert_meta(
        &ix.accounts[3],
        solana_sdk_ids::system_program::id(),
        false,
        false,
    );
}

#[test]
fn official_management_builders_match_zig_layout() {
    let table = key(3);
    let authority = key(4);
    let payer = key(5);
    let recipient = key(6);
    let addresses = vec![key(7), key(8)];

    let freeze = freeze_lookup_table(table, authority);
    assert_eq!(
        freeze.data,
        bincode::serialize(&ProgramInstruction::FreezeLookupTable).unwrap()
    );
    assert_meta(&freeze.accounts[0], table, false, true);
    assert_meta(&freeze.accounts[1], authority, true, false);

    let extend = extend_lookup_table(table, authority, Some(payer), addresses.clone());
    assert_eq!(&extend.data[0..4], &[2, 0, 0, 0]);
    assert_eq!(
        u64::from_le_bytes(extend.data[4..12].try_into().unwrap()),
        2
    );
    assert_eq!(&extend.data[12..44], addresses[0].as_ref());
    assert_meta(&extend.accounts[0], table, false, true);
    assert_meta(&extend.accounts[1], authority, true, false);
    assert_meta(&extend.accounts[2], payer, true, true);
    assert_meta(
        &extend.accounts[3],
        solana_sdk_ids::system_program::id(),
        false,
        false,
    );

    let extend_unfunded = extend_lookup_table(table, authority, None, addresses);
    assert_eq!(extend_unfunded.accounts.len(), 2);

    let deactivate = deactivate_lookup_table(table, authority);
    assert_eq!(
        deactivate.data,
        bincode::serialize(&ProgramInstruction::DeactivateLookupTable).unwrap()
    );

    let close = close_lookup_table(table, authority, recipient);
    assert_eq!(
        close.data,
        bincode::serialize(&ProgramInstruction::CloseLookupTable).unwrap()
    );
    assert_meta(&close.accounts[2], recipient, false, true);
}
