use {
    solana_instruction::AccountMeta,
    solana_pubkey::Pubkey,
    spl_associated_token_account_interface::{
        address::get_associated_token_address_with_program_id,
        instruction::{
            create_associated_token_account, create_associated_token_account_idempotent,
            recover_nested,
        },
        program,
    },
};

fn key(byte: u8) -> Pubkey {
    Pubkey::from([byte; 32])
}

fn token_program_id() -> Pubkey {
    Pubkey::from_str_const("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA")
}

fn assert_meta(meta: &AccountMeta, pubkey: Pubkey, is_signer: bool, is_writable: bool) {
    assert_eq!(meta.pubkey, pubkey);
    assert_eq!(meta.is_signer, is_signer);
    assert_eq!(meta.is_writable, is_writable);
}

#[test]
fn official_create_builders_match_zig_shape() {
    let payer = key(1);
    let wallet = key(2);
    let mint = key(3);
    let token_program = token_program_id();
    let ata = get_associated_token_address_with_program_id(&wallet, &mint, &token_program);

    let create = create_associated_token_account(&payer, &wallet, &mint, &token_program);
    assert_eq!(create.program_id, program::id());
    assert_eq!(create.data, vec![0]);
    assert_eq!(create.accounts.len(), 6);
    assert_meta(&create.accounts[0], payer, true, true);
    assert_meta(&create.accounts[1], ata, false, true);
    assert_meta(&create.accounts[2], wallet, false, false);
    assert_meta(&create.accounts[3], mint, false, false);
    assert_meta(
        &create.accounts[4],
        solana_sdk_ids::system_program::id(),
        false,
        false,
    );
    assert_meta(&create.accounts[5], token_program, false, false);

    let idempotent =
        create_associated_token_account_idempotent(&payer, &wallet, &mint, &token_program);
    assert_eq!(idempotent.program_id, program::id());
    assert_eq!(idempotent.data, vec![1]);
    assert_eq!(idempotent.accounts, create.accounts);
}

#[test]
fn official_recover_nested_builder_matches_zig_shape() {
    let wallet = key(4);
    let owner_mint = key(5);
    let nested_mint = key(6);
    let token_program = token_program_id();
    let owner_ata =
        get_associated_token_address_with_program_id(&wallet, &owner_mint, &token_program);
    let destination_ata =
        get_associated_token_address_with_program_id(&wallet, &nested_mint, &token_program);
    let nested_ata =
        get_associated_token_address_with_program_id(&owner_ata, &nested_mint, &token_program);

    let ix = recover_nested(&wallet, &owner_mint, &nested_mint, &token_program);
    assert_eq!(ix.program_id, program::id());
    assert_eq!(ix.data, vec![2]);
    assert_eq!(ix.accounts.len(), 7);
    assert_meta(&ix.accounts[0], nested_ata, false, true);
    assert_meta(&ix.accounts[1], nested_mint, false, false);
    assert_meta(&ix.accounts[2], destination_ata, false, true);
    assert_meta(&ix.accounts[3], owner_ata, false, false);
    assert_meta(&ix.accounts[4], owner_mint, false, false);
    assert_meta(&ix.accounts[5], wallet, true, true);
    assert_meta(&ix.accounts[6], token_program, false, false);
}
