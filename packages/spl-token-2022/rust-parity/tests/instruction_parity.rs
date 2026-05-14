use {
    std::str::FromStr,
    solana_instruction::AccountMeta,
    solana_pubkey::Pubkey,
    spl_token_2022::{
        extension::{
            cpi_guard::instruction as cpi_guard_instruction,
            default_account_state::instruction as default_account_state_instruction,
            group_member_pointer::instruction as group_member_pointer_instruction,
            group_pointer::instruction as group_pointer_instruction,
            interest_bearing_mint::instruction as interest_bearing_mint_instruction,
            memo_transfer::instruction as memo_transfer_instruction,
            metadata_pointer::instruction as metadata_pointer_instruction,
            pausable::instruction as pausable_instruction,
            scaled_ui_amount::instruction as scaled_ui_amount_instruction,
            transfer_hook::instruction as transfer_hook_instruction,
            transfer_fee::instruction as transfer_fee_instruction, ExtensionType,
        },
        id, instruction,
        state::AccountState,
    },
};

fn key(byte: u8) -> Pubkey {
    Pubkey::from([byte; 32])
}

fn rent_id() -> Pubkey {
    Pubkey::from_str("SysvarRent111111111111111111111111111111111").unwrap()
}

fn native_mint() -> Pubkey {
    Pubkey::from_str("9pan9bMn5HatX4EJdBwg9VgCa7Uz5HL8N1m5D3NdXejP").unwrap()
}

fn assert_meta(meta: &AccountMeta, pubkey: Pubkey, is_signer: bool, is_writable: bool) {
    assert_eq!(meta.pubkey, pubkey);
    assert_eq!(meta.is_signer, is_signer);
    assert_eq!(meta.is_writable, is_writable);
}

fn assert_amount_ix(data: &[u8], disc: u8, amount: u64) {
    let mut expected = vec![disc];
    expected.extend_from_slice(&amount.to_le_bytes());
    assert_eq!(data, expected);
}

fn assert_amount_decimals_ix(data: &[u8], disc: u8, amount: u64, decimals: u8) {
    let mut expected = vec![disc];
    expected.extend_from_slice(&amount.to_le_bytes());
    expected.push(decimals);
    assert_eq!(data, expected);
}

fn assert_transfer_fee_amount_decimals_fee_ix(
    data: &[u8],
    inner: u8,
    amount: u64,
    decimals: u8,
    fee: u64,
) {
    let mut expected = vec![26, inner];
    expected.extend_from_slice(&amount.to_le_bytes());
    expected.push(decimals);
    expected.extend_from_slice(&fee.to_le_bytes());
    assert_eq!(data, expected);
}

#[allow(deprecated)]
#[test]
fn official_plain_amount_builders_match_zig_shape() {
    let source = key(1);
    let destination = key(2);
    let authority = key(3);
    let mint = key(4);
    let delegate = key(5);

    let transfer =
        instruction::transfer(&id(), &source, &destination, &authority, &[], 500).unwrap();
    assert_eq!(transfer.program_id, id());
    assert_amount_ix(&transfer.data, 3, 500);
    assert_eq!(transfer.accounts.len(), 3);
    assert_meta(&transfer.accounts[0], source, false, true);
    assert_meta(&transfer.accounts[1], destination, false, true);
    assert_meta(&transfer.accounts[2], authority, true, false);

    let approve = instruction::approve(&id(), &source, &delegate, &authority, &[], 501).unwrap();
    assert_eq!(approve.program_id, id());
    assert_amount_ix(&approve.data, 4, 501);
    assert_eq!(approve.accounts.len(), 3);
    assert_meta(&approve.accounts[0], source, false, true);
    assert_meta(&approve.accounts[1], delegate, false, false);
    assert_meta(&approve.accounts[2], authority, true, false);

    let mint_to = instruction::mint_to(&id(), &mint, &destination, &authority, &[], 502).unwrap();
    assert_eq!(mint_to.program_id, id());
    assert_amount_ix(&mint_to.data, 7, 502);
    assert_eq!(mint_to.accounts.len(), 3);
    assert_meta(&mint_to.accounts[0], mint, false, true);
    assert_meta(&mint_to.accounts[1], destination, false, true);
    assert_meta(&mint_to.accounts[2], authority, true, false);

    let burn = instruction::burn(&id(), &source, &mint, &authority, &[], 503).unwrap();
    assert_eq!(burn.program_id, id());
    assert_amount_ix(&burn.data, 8, 503);
    assert_eq!(burn.accounts.len(), 3);
    assert_meta(&burn.accounts[0], source, false, true);
    assert_meta(&burn.accounts[1], mint, false, true);
    assert_meta(&burn.accounts[2], authority, true, false);
}

#[test]
fn official_checked_builders_match_zig_shape() {
    let source = key(11);
    let mint = key(12);
    let destination = key(13);
    let authority = key(14);
    let delegate = key(15);

    let transfer = instruction::transfer_checked(
        &id(),
        &source,
        &mint,
        &destination,
        &authority,
        &[],
        1_000_000,
        6,
    )
    .unwrap();
    assert_eq!(transfer.program_id, id());
    assert_amount_decimals_ix(&transfer.data, 12, 1_000_000, 6);
    assert_eq!(transfer.accounts.len(), 4);
    assert_meta(&transfer.accounts[0], source, false, true);
    assert_meta(&transfer.accounts[1], mint, false, false);
    assert_meta(&transfer.accounts[2], destination, false, true);
    assert_meta(&transfer.accounts[3], authority, true, false);

    let approve = instruction::approve_checked(
        &id(),
        &source,
        &mint,
        &delegate,
        &authority,
        &[],
        2_000_000,
        7,
    )
    .unwrap();
    assert_eq!(approve.program_id, id());
    assert_amount_decimals_ix(&approve.data, 13, 2_000_000, 7);
    assert_eq!(approve.accounts.len(), 4);
    assert_meta(&approve.accounts[0], source, false, true);
    assert_meta(&approve.accounts[1], mint, false, false);
    assert_meta(&approve.accounts[2], delegate, false, false);
    assert_meta(&approve.accounts[3], authority, true, false);

    let mint_to =
        instruction::mint_to_checked(&id(), &mint, &destination, &authority, &[], 3_000_000, 8)
            .unwrap();
    assert_eq!(mint_to.program_id, id());
    assert_amount_decimals_ix(&mint_to.data, 14, 3_000_000, 8);
    assert_eq!(mint_to.accounts.len(), 3);
    assert_meta(&mint_to.accounts[0], mint, false, true);
    assert_meta(&mint_to.accounts[1], destination, false, true);
    assert_meta(&mint_to.accounts[2], authority, true, false);

    let burn =
        instruction::burn_checked(&id(), &source, &mint, &authority, &[], 4_000_000, 9).unwrap();
    assert_eq!(burn.program_id, id());
    assert_amount_decimals_ix(&burn.data, 15, 4_000_000, 9);
    assert_eq!(burn.accounts.len(), 3);
    assert_meta(&burn.accounts[0], source, false, true);
    assert_meta(&burn.accounts[1], mint, false, true);
    assert_meta(&burn.accounts[2], authority, true, false);
}

#[test]
fn official_initializer_and_utility_builders_match_zig_shape() {
    let account = key(21);
    let mint = key(22);
    let owner = key(23);
    let destination = key(24);
    let freeze_authority = key(25);
    let signer_a = key(26);
    let signer_b = key(27);
    let signer_c = key(28);
    let multisig = key(29);

    let init_mint =
        instruction::initialize_mint(&id(), &mint, &owner, Some(&freeze_authority), 6).unwrap();
    assert_eq!(init_mint.program_id, id());
    assert_eq!(init_mint.data[0], 0);
    assert_eq!(init_mint.data[1], 6);
    assert_eq!(&init_mint.data[2..34], owner.as_ref());
    assert_eq!(init_mint.data.len(), 67);
    assert_eq!(init_mint.data[34], 1);
    assert_eq!(&init_mint.data[35..67], freeze_authority.as_ref());
    assert_eq!(init_mint.accounts.len(), 2);
    assert_meta(&init_mint.accounts[0], mint, false, true);
    assert_meta(&init_mint.accounts[1], rent_id(), false, false);

    let init_mint_none = instruction::initialize_mint(&id(), &mint, &owner, None, 0).unwrap();
    assert_eq!(init_mint_none.data.len(), 35);
    assert_eq!(init_mint_none.data[34], 0);

    let init_account = instruction::initialize_account3(&id(), &account, &mint, &owner).unwrap();
    assert_eq!(init_account.program_id, id());
    assert_eq!(init_account.data[0], 18);
    assert_eq!(&init_account.data[1..33], owner.as_ref());
    assert_eq!(init_account.accounts.len(), 2);
    assert_meta(&init_account.accounts[0], account, false, true);
    assert_meta(&init_account.accounts[1], mint, false, false);

    let init_mint =
        instruction::initialize_mint2(&id(), &mint, &owner, Some(&freeze_authority), 6).unwrap();
    assert_eq!(init_mint.program_id, id());
    assert_eq!(init_mint.data[0], 20);
    assert_eq!(init_mint.data[1], 6);
    assert_eq!(&init_mint.data[2..34], owner.as_ref());
    assert_eq!(init_mint.data.len(), 67);
    assert_eq!(init_mint.data[34], 1);
    assert_eq!(&init_mint.data[35..67], freeze_authority.as_ref());
    assert_eq!(init_mint.accounts.len(), 1);
    assert_meta(&init_mint.accounts[0], mint, false, true);

    let init_mint_without_freeze =
        instruction::initialize_mint2(&id(), &mint, &owner, None, 0).unwrap();
    assert_eq!(init_mint_without_freeze.data.len(), 35);
    assert_eq!(init_mint_without_freeze.data[34], 0);

    let init_account_legacy = instruction::initialize_account(&id(), &account, &mint, &owner)
        .unwrap();
    assert_eq!(init_account_legacy.data, vec![1]);
    assert_eq!(init_account_legacy.accounts.len(), 4);
    assert_meta(&init_account_legacy.accounts[0], account, false, true);
    assert_meta(&init_account_legacy.accounts[1], mint, false, false);
    assert_meta(&init_account_legacy.accounts[2], owner, false, false);
    assert_meta(&init_account_legacy.accounts[3], rent_id(), false, false);

    let init_account2 = instruction::initialize_account2(&id(), &account, &mint, &owner).unwrap();
    assert_eq!(init_account2.data[0], 16);
    assert_eq!(&init_account2.data[1..33], owner.as_ref());
    assert_eq!(init_account2.accounts.len(), 3);
    assert_meta(&init_account2.accounts[0], account, false, true);
    assert_meta(&init_account2.accounts[1], mint, false, false);
    assert_meta(&init_account2.accounts[2], rent_id(), false, false);

    let init_multisig = instruction::initialize_multisig(
        &id(),
        &multisig,
        &[&signer_a, &signer_b, &signer_c],
        2,
    )
    .unwrap();
    assert_eq!(init_multisig.data, vec![2, 2]);
    assert_eq!(init_multisig.accounts.len(), 5);
    assert_meta(&init_multisig.accounts[0], multisig, false, true);
    assert_meta(&init_multisig.accounts[1], rent_id(), false, false);
    assert_meta(&init_multisig.accounts[4], signer_c, false, false);

    let init_multisig2 = instruction::initialize_multisig2(
        &id(),
        &multisig,
        &[&signer_a, &signer_b, &signer_c],
        3,
    )
    .unwrap();
    assert_eq!(init_multisig2.data, vec![19, 3]);
    assert_eq!(init_multisig2.accounts.len(), 4);
    assert_meta(&init_multisig2.accounts[0], multisig, false, true);
    assert_meta(&init_multisig2.accounts[3], signer_c, false, false);

    let close = instruction::close_account(&id(), &account, &destination, &owner, &[]).unwrap();
    assert_eq!(close.program_id, id());
    assert_eq!(close.data, vec![9]);
    assert_eq!(close.accounts.len(), 3);
    assert_meta(&close.accounts[0], account, false, true);
    assert_meta(&close.accounts[1], destination, false, true);
    assert_meta(&close.accounts[2], owner, true, false);

    let sync = instruction::sync_native(&id(), &account).unwrap();
    assert_eq!(sync.program_id, id());
    assert_eq!(sync.data, vec![17]);
    assert_eq!(sync.accounts.len(), 1);
    assert_meta(&sync.accounts[0], account, false, true);

    let get_size = instruction::get_account_data_size(&id(), &mint, &[]).unwrap();
    assert_eq!(get_size.program_id, id());
    assert_eq!(get_size.data, vec![21]);
    assert_eq!(get_size.accounts.len(), 1);
    assert_meta(&get_size.accounts[0], mint, false, false);

    let get_size_with_extension =
        instruction::get_account_data_size(&id(), &mint, &[ExtensionType::ImmutableOwner]).unwrap();
    assert_eq!(get_size_with_extension.data, vec![21, 7, 0]);

    let immutable = instruction::initialize_immutable_owner(&id(), &account).unwrap();
    assert_eq!(immutable.program_id, id());
    assert_eq!(immutable.data, vec![22]);
    assert_eq!(immutable.accounts.len(), 1);
    assert_meta(&immutable.accounts[0], account, false, true);

    let mint_close =
        instruction::initialize_mint_close_authority(&id(), &mint, Some(&owner)).unwrap();
    let mut expected_mint_close = vec![25, 1];
    expected_mint_close.extend_from_slice(owner.as_ref());
    assert_eq!(mint_close.program_id, id());
    assert_eq!(mint_close.data, expected_mint_close);
    assert_eq!(mint_close.accounts.len(), 1);
    assert_meta(&mint_close.accounts[0], mint, false, true);

    let mint_close_none =
        instruction::initialize_mint_close_authority(&id(), &mint, None).unwrap();
    assert_eq!(mint_close_none.data, vec![25, 0]);

    let non_transferable = instruction::initialize_non_transferable_mint(&id(), &mint).unwrap();
    assert_eq!(non_transferable.program_id, id());
    assert_eq!(non_transferable.data, vec![32]);
    assert_eq!(non_transferable.accounts.len(), 1);
    assert_meta(&non_transferable.accounts[0], mint, false, true);

    let native = instruction::create_native_mint(&id(), &owner).unwrap();
    assert_eq!(native.program_id, id());
    assert_eq!(native.data, vec![31]);
    assert_eq!(native.accounts.len(), 3);
    assert_meta(&native.accounts[0], owner, true, true);
    assert_meta(&native.accounts[1], native_mint(), false, true);
    assert_meta(&native.accounts[2], Pubkey::from([0u8; 32]), false, false);

    let amount_to_ui = instruction::amount_to_ui_amount(&id(), &mint, 42).unwrap();
    assert_eq!(amount_to_ui.program_id, id());
    assert_amount_ix(&amount_to_ui.data, 23, 42);
    assert_eq!(amount_to_ui.accounts.len(), 1);
    assert_meta(&amount_to_ui.accounts[0], mint, false, false);

    let ui_to_amount = instruction::ui_amount_to_amount(&id(), &mint, "1.25").unwrap();
    assert_eq!(ui_to_amount.program_id, id());
    assert_eq!(ui_to_amount.data, vec![24, b'1', b'.', b'2', b'5']);
    assert_eq!(ui_to_amount.accounts.len(), 1);
    assert_meta(&ui_to_amount.accounts[0], mint, false, false);
}

#[test]
fn official_authority_lifecycle_builders_match_zig_shape() {
    let account = key(26);
    let mint = key(27);
    let owner = key(28);
    let signer = key(29);
    let new_authority = key(30);
    let destination = key(31);

    let revoke = instruction::revoke(&id(), &account, &owner, &[&signer]).unwrap();
    assert_eq!(revoke.program_id, id());
    assert_eq!(revoke.data, vec![5]);
    assert_eq!(revoke.accounts.len(), 3);
    assert_meta(&revoke.accounts[0], account, false, true);
    assert_meta(&revoke.accounts[1], owner, false, false);
    assert_meta(&revoke.accounts[2], signer, true, false);

    let set_some = instruction::set_authority(
        &id(),
        &mint,
        Some(&new_authority),
        instruction::AuthorityType::MetadataPointer,
        &owner,
        &[],
    )
    .unwrap();
    let mut expected_set_some = vec![6, 12, 1];
    expected_set_some.extend_from_slice(new_authority.as_ref());
    assert_eq!(set_some.data, expected_set_some);
    assert_eq!(set_some.accounts.len(), 2);
    assert_meta(&set_some.accounts[0], mint, false, true);
    assert_meta(&set_some.accounts[1], owner, true, false);

    let set_none = instruction::set_authority(
        &id(),
        &mint,
        None,
        instruction::AuthorityType::Pause,
        &owner,
        &[&signer],
    )
    .unwrap();
    assert_eq!(set_none.data, vec![6, 16, 0]);
    assert_eq!(set_none.accounts.len(), 3);
    assert_meta(&set_none.accounts[1], owner, false, false);
    assert_meta(&set_none.accounts[2], signer, true, false);

    let freeze = instruction::freeze_account(&id(), &account, &mint, &owner, &[&signer]).unwrap();
    assert_eq!(freeze.data, vec![10]);
    assert_eq!(freeze.accounts.len(), 4);
    assert_meta(&freeze.accounts[0], account, false, true);
    assert_meta(&freeze.accounts[1], mint, false, false);
    assert_meta(&freeze.accounts[2], owner, false, false);
    assert_meta(&freeze.accounts[3], signer, true, false);

    let thaw = instruction::thaw_account(&id(), &account, &mint, &owner, &[]).unwrap();
    assert_eq!(thaw.data, vec![11]);
    assert_eq!(thaw.accounts.len(), 3);
    assert_meta(&thaw.accounts[2], owner, true, false);

    let withdraw =
        instruction::withdraw_excess_lamports(&id(), &account, &destination, &owner, &[&signer])
            .unwrap();
    assert_eq!(withdraw.data, vec![38]);
    assert_eq!(withdraw.accounts.len(), 4);
    assert_meta(&withdraw.accounts[0], account, false, true);
    assert_meta(&withdraw.accounts[1], destination, false, true);
    assert_meta(&withdraw.accounts[2], owner, false, false);
    assert_meta(&withdraw.accounts[3], signer, true, false);
}

#[test]
fn official_reallocate_builder_matches_zig_shape() {
    let account = key(26);
    let payer = key(27);
    let owner = key(28);
    let signer = key(29);

    let reallocate = instruction::reallocate(
        &id(),
        &account,
        &payer,
        &owner,
        &[&signer],
        &[ExtensionType::TransferHook, ExtensionType::PermanentDelegate],
    )
    .unwrap();
    assert_eq!(reallocate.program_id, id());
    assert_eq!(reallocate.data, vec![29, 14, 0, 12, 0]);
    assert_eq!(reallocate.accounts.len(), 5);
    assert_meta(&reallocate.accounts[0], account, false, true);
    assert_meta(&reallocate.accounts[1], payer, true, true);
    assert_meta(&reallocate.accounts[2], Pubkey::from([0u8; 32]), false, false);
    assert_meta(&reallocate.accounts[3], owner, false, false);
    assert_meta(&reallocate.accounts[4], signer, true, false);
}

#[test]
fn official_transfer_fee_initialize_and_transfer_builders_match_zig_shape() {
    let source = key(31);
    let mint = key(32);
    let destination = key(33);
    let authority = key(34);
    let signer_a = key(35);
    let signer_b = key(36);

    let init = transfer_fee_instruction::initialize_transfer_fee_config(
        &id(),
        &mint,
        Some(&authority),
        None,
        111,
        999,
    )
    .unwrap();
    let mut expected_init = vec![26, 0, 1];
    expected_init.extend_from_slice(authority.as_ref());
    expected_init.push(0);
    expected_init.extend_from_slice(&111u16.to_le_bytes());
    expected_init.extend_from_slice(&999u64.to_le_bytes());
    assert_eq!(init.program_id, id());
    assert_eq!(init.data, expected_init);
    assert_eq!(init.accounts.len(), 1);
    assert_meta(&init.accounts[0], mint, false, true);

    let init_none =
        transfer_fee_instruction::initialize_transfer_fee_config(&id(), &mint, None, None, 1, 2)
            .unwrap();
    assert_eq!(
        init_none.data,
        vec![26, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0, 0, 0, 0]
    );

    let single = transfer_fee_instruction::transfer_checked_with_fee(
        &id(),
        &source,
        &mint,
        &destination,
        &authority,
        &[],
        500,
        6,
        7,
    )
    .unwrap();
    assert_eq!(single.program_id, id());
    assert_transfer_fee_amount_decimals_fee_ix(&single.data, 1, 500, 6, 7);
    assert_eq!(single.accounts.len(), 4);
    assert_meta(&single.accounts[0], source, false, true);
    assert_meta(&single.accounts[1], mint, false, false);
    assert_meta(&single.accounts[2], destination, false, true);
    assert_meta(&single.accounts[3], authority, true, false);

    let multi = transfer_fee_instruction::transfer_checked_with_fee(
        &id(),
        &source,
        &mint,
        &destination,
        &authority,
        &[&signer_a, &signer_b],
        500,
        6,
        7,
    )
    .unwrap();
    assert_eq!(multi.accounts.len(), 6);
    assert_meta(&multi.accounts[3], authority, false, false);
    assert_meta(&multi.accounts[4], signer_a, true, false);
    assert_meta(&multi.accounts[5], signer_b, true, false);
}

#[test]
fn official_transfer_fee_withdraw_harvest_and_set_builders_match_zig_shape() {
    let mint = key(41);
    let destination = key(42);
    let authority = key(43);
    let signer = key(44);
    let source_a = key(45);
    let source_b = key(46);

    let withdraw_mint = transfer_fee_instruction::withdraw_withheld_tokens_from_mint(
        &id(),
        &mint,
        &destination,
        &authority,
        &[&signer],
    )
    .unwrap();
    assert_eq!(withdraw_mint.program_id, id());
    assert_eq!(withdraw_mint.data, vec![26, 2]);
    assert_eq!(withdraw_mint.accounts.len(), 4);
    assert_meta(&withdraw_mint.accounts[0], mint, false, true);
    assert_meta(&withdraw_mint.accounts[1], destination, false, true);
    assert_meta(&withdraw_mint.accounts[2], authority, false, false);
    assert_meta(&withdraw_mint.accounts[3], signer, true, false);

    let withdraw_accounts = transfer_fee_instruction::withdraw_withheld_tokens_from_accounts(
        &id(),
        &mint,
        &destination,
        &authority,
        &[&signer],
        &[&source_a, &source_b],
    )
    .unwrap();
    assert_eq!(withdraw_accounts.data, vec![26, 3, 2]);
    assert_eq!(withdraw_accounts.accounts.len(), 6);
    assert_meta(&withdraw_accounts.accounts[0], mint, false, false);
    assert_meta(&withdraw_accounts.accounts[1], destination, false, true);
    assert_meta(&withdraw_accounts.accounts[2], authority, false, false);
    assert_meta(&withdraw_accounts.accounts[3], signer, true, false);
    assert_meta(&withdraw_accounts.accounts[4], source_a, false, true);
    assert_meta(&withdraw_accounts.accounts[5], source_b, false, true);

    let harvest = transfer_fee_instruction::harvest_withheld_tokens_to_mint(
        &id(),
        &mint,
        &[&source_a, &source_b],
    )
    .unwrap();
    assert_eq!(harvest.data, vec![26, 4]);
    assert_eq!(harvest.accounts.len(), 3);
    assert_meta(&harvest.accounts[0], mint, false, true);
    assert_meta(&harvest.accounts[1], source_a, false, true);
    assert_meta(&harvest.accounts[2], source_b, false, true);

    let set_fee = transfer_fee_instruction::set_transfer_fee(
        &id(),
        &mint,
        &authority,
        &[&signer],
        250,
        10_000,
    )
    .unwrap();
    let mut expected_set_fee = vec![26, 5];
    expected_set_fee.extend_from_slice(&250u16.to_le_bytes());
    expected_set_fee.extend_from_slice(&10_000u64.to_le_bytes());
    assert_eq!(set_fee.data, expected_set_fee);
    assert_eq!(set_fee.accounts.len(), 3);
    assert_meta(&set_fee.accounts[0], mint, false, true);
    assert_meta(&set_fee.accounts[1], authority, false, false);
    assert_meta(&set_fee.accounts[2], signer, true, false);
}

#[test]
fn official_default_account_state_builders_match_zig_shape() {
    let mint = key(51);
    let authority = key(52);
    let signer = key(53);

    let init = default_account_state_instruction::initialize_default_account_state(
        &id(),
        &mint,
        &AccountState::Frozen,
    )
    .unwrap();
    assert_eq!(init.program_id, id());
    assert_eq!(init.data, vec![28, 0, 2]);
    assert_eq!(init.accounts.len(), 1);
    assert_meta(&init.accounts[0], mint, false, true);

    let single = default_account_state_instruction::update_default_account_state(
        &id(),
        &mint,
        &authority,
        &[],
        &AccountState::Initialized,
    )
    .unwrap();
    assert_eq!(single.data, vec![28, 1, 1]);
    assert_eq!(single.accounts.len(), 2);
    assert_meta(&single.accounts[0], mint, false, true);
    assert_meta(&single.accounts[1], authority, true, false);

    let multi = default_account_state_instruction::update_default_account_state(
        &id(),
        &mint,
        &authority,
        &[&signer],
        &AccountState::Frozen,
    )
    .unwrap();
    assert_eq!(multi.data, vec![28, 1, 2]);
    assert_eq!(multi.accounts.len(), 3);
    assert_meta(&multi.accounts[1], authority, false, false);
    assert_meta(&multi.accounts[2], signer, true, false);
}

#[test]
fn official_memo_transfer_builders_match_zig_shape() {
    let account = key(61);
    let owner = key(62);
    let signer_a = key(63);
    let signer_b = key(64);

    let enable =
        memo_transfer_instruction::enable_required_transfer_memos(&id(), &account, &owner, &[])
            .unwrap();
    assert_eq!(enable.program_id, id());
    assert_eq!(enable.data, vec![30, 0]);
    assert_eq!(enable.accounts.len(), 2);
    assert_meta(&enable.accounts[0], account, false, true);
    assert_meta(&enable.accounts[1], owner, true, false);

    let disable = memo_transfer_instruction::disable_required_transfer_memos(
        &id(),
        &account,
        &owner,
        &[&signer_a, &signer_b],
    )
    .unwrap();
    assert_eq!(disable.data, vec![30, 1]);
    assert_eq!(disable.accounts.len(), 4);
    assert_meta(&disable.accounts[0], account, false, true);
    assert_meta(&disable.accounts[1], owner, false, false);
    assert_meta(&disable.accounts[2], signer_a, true, false);
    assert_meta(&disable.accounts[3], signer_b, true, false);
}

#[test]
fn official_cpi_guard_builders_match_zig_shape() {
    let account = key(71);
    let owner = key(72);
    let signer = key(73);

    let enable = cpi_guard_instruction::enable_cpi_guard(&id(), &account, &owner, &[]).unwrap();
    assert_eq!(enable.program_id, id());
    assert_eq!(enable.data, vec![34, 0]);
    assert_eq!(enable.accounts.len(), 2);
    assert_meta(&enable.accounts[0], account, false, true);
    assert_meta(&enable.accounts[1], owner, true, false);

    let disable =
        cpi_guard_instruction::disable_cpi_guard(&id(), &account, &owner, &[&signer]).unwrap();
    assert_eq!(disable.data, vec![34, 1]);
    assert_eq!(disable.accounts.len(), 3);
    assert_meta(&disable.accounts[0], account, false, true);
    assert_meta(&disable.accounts[1], owner, false, false);
    assert_meta(&disable.accounts[2], signer, true, false);
}

#[test]
fn official_interest_bearing_mint_builders_match_zig_shape() {
    let mint = key(75);
    let authority = key(76);
    let signer = key(77);

    let init =
        interest_bearing_mint_instruction::initialize(&id(), &mint, Some(authority), -125)
            .unwrap();
    let mut expected_init = vec![33, 0];
    expected_init.extend_from_slice(authority.as_ref());
    expected_init.extend_from_slice(&(-125i16).to_le_bytes());
    assert_eq!(init.program_id, id());
    assert_eq!(init.data, expected_init);
    assert_eq!(init.accounts.len(), 1);
    assert_meta(&init.accounts[0], mint, false, true);

    let none_init =
        interest_bearing_mint_instruction::initialize(&id(), &mint, None, 250).unwrap();
    let mut expected_none = vec![33, 0];
    expected_none.extend_from_slice(&[0u8; 32]);
    expected_none.extend_from_slice(&250i16.to_le_bytes());
    assert_eq!(none_init.data, expected_none);

    let update = interest_bearing_mint_instruction::update_rate(
        &id(),
        &mint,
        &authority,
        &[&signer],
        500,
    )
    .unwrap();
    assert_eq!(update.data, {
        let mut expected = vec![33, 1];
        expected.extend_from_slice(&500i16.to_le_bytes());
        expected
    });
    assert_eq!(update.accounts.len(), 3);
    assert_meta(&update.accounts[0], mint, false, true);
    assert_meta(&update.accounts[1], authority, false, false);
    assert_meta(&update.accounts[2], signer, true, false);
}

#[test]
fn official_permanent_delegate_builder_matches_zig_shape() {
    let mint = key(78);
    let delegate = key(79);

    let init = instruction::initialize_permanent_delegate(&id(), &mint, &delegate).unwrap();
    let mut expected = vec![35];
    expected.extend_from_slice(delegate.as_ref());
    assert_eq!(init.program_id, id());
    assert_eq!(init.data, expected);
    assert_eq!(init.accounts.len(), 1);
    assert_meta(&init.accounts[0], mint, false, true);
}

#[test]
fn official_pausable_builders_match_zig_shape() {
    let mint = key(81);
    let authority = key(82);
    let signer_a = key(83);
    let signer_b = key(84);

    let init = pausable_instruction::initialize(&id(), &mint, &authority).unwrap();
    let mut expected_init = vec![44, 0];
    expected_init.extend_from_slice(authority.as_ref());
    assert_eq!(init.program_id, id());
    assert_eq!(init.data, expected_init);
    assert_eq!(init.accounts.len(), 1);
    assert_meta(&init.accounts[0], mint, false, true);

    let pause = pausable_instruction::pause(&id(), &mint, &authority, &[]).unwrap();
    assert_eq!(pause.data, vec![44, 1]);
    assert_eq!(pause.accounts.len(), 2);
    assert_meta(&pause.accounts[0], mint, false, true);
    assert_meta(&pause.accounts[1], authority, true, false);

    let resume =
        pausable_instruction::resume(&id(), &mint, &authority, &[&signer_a, &signer_b]).unwrap();
    assert_eq!(resume.data, vec![44, 2]);
    assert_eq!(resume.accounts.len(), 4);
    assert_meta(&resume.accounts[0], mint, false, true);
    assert_meta(&resume.accounts[1], authority, false, false);
    assert_meta(&resume.accounts[2], signer_a, true, false);
    assert_meta(&resume.accounts[3], signer_b, true, false);
}

#[test]
fn official_pointer_builders_match_zig_shape() {
    let mint = key(91);
    let authority = key(92);
    let target = key(93);
    let signer = key(94);

    let metadata_init =
        metadata_pointer_instruction::initialize(&id(), &mint, Some(authority), Some(target))
            .unwrap();
    let mut expected_metadata_init = vec![39, 0];
    expected_metadata_init.extend_from_slice(authority.as_ref());
    expected_metadata_init.extend_from_slice(target.as_ref());
    assert_eq!(metadata_init.program_id, id());
    assert_eq!(metadata_init.data, expected_metadata_init);
    assert_eq!(metadata_init.accounts.len(), 1);
    assert_meta(&metadata_init.accounts[0], mint, false, true);

    let metadata_update =
        metadata_pointer_instruction::update(&id(), &mint, &authority, &[&signer], None).unwrap();
    assert_eq!(metadata_update.data, {
        let mut expected = vec![39, 1];
        expected.extend_from_slice(&[0u8; 32]);
        expected
    });
    assert_eq!(metadata_update.accounts.len(), 3);
    assert_meta(&metadata_update.accounts[0], mint, false, true);
    assert_meta(&metadata_update.accounts[1], authority, false, false);
    assert_meta(&metadata_update.accounts[2], signer, true, false);

    let group_init =
        group_pointer_instruction::initialize(&id(), &mint, None, Some(target)).unwrap();
    assert_eq!(group_init.data, {
        let mut expected = vec![40, 0];
        expected.extend_from_slice(&[0u8; 32]);
        expected.extend_from_slice(target.as_ref());
        expected
    });
    assert_eq!(group_init.accounts.len(), 1);
    assert_meta(&group_init.accounts[0], mint, false, true);

    let group_update =
        group_pointer_instruction::update(&id(), &mint, &authority, &[], Some(target)).unwrap();
    let mut expected_group_update = vec![40, 1];
    expected_group_update.extend_from_slice(target.as_ref());
    assert_eq!(group_update.data, expected_group_update);
    assert_eq!(group_update.accounts.len(), 2);
    assert_meta(&group_update.accounts[1], authority, true, false);

    let member_init =
        group_member_pointer_instruction::initialize(&id(), &mint, Some(authority), None).unwrap();
    assert_eq!(member_init.data, {
        let mut expected = vec![41, 0];
        expected.extend_from_slice(authority.as_ref());
        expected.extend_from_slice(&[0u8; 32]);
        expected
    });
    assert_eq!(member_init.accounts.len(), 1);
    assert_meta(&member_init.accounts[0], mint, false, true);

    let member_update =
        group_member_pointer_instruction::update(&id(), &mint, &authority, &[], Some(target))
            .unwrap();
    let mut expected_member_update = vec![41, 1];
    expected_member_update.extend_from_slice(target.as_ref());
    assert_eq!(member_update.data, expected_member_update);
    assert_eq!(member_update.accounts.len(), 2);
    assert_meta(&member_update.accounts[1], authority, true, false);
}

#[test]
fn official_transfer_hook_builders_match_zig_shape() {
    let mint = key(95);
    let authority = key(96);
    let program_id = key(97);
    let signer = key(98);

    let init =
        transfer_hook_instruction::initialize(&id(), &mint, Some(authority), Some(program_id))
            .unwrap();
    let mut expected_init = vec![36, 0];
    expected_init.extend_from_slice(authority.as_ref());
    expected_init.extend_from_slice(program_id.as_ref());
    assert_eq!(init.program_id, id());
    assert_eq!(init.data, expected_init);
    assert_eq!(init.accounts.len(), 1);
    assert_meta(&init.accounts[0], mint, false, true);

    let update =
        transfer_hook_instruction::update(&id(), &mint, &authority, &[&signer], None).unwrap();
    assert_eq!(update.data, {
        let mut expected = vec![36, 1];
        expected.extend_from_slice(&[0u8; 32]);
        expected
    });
    assert_eq!(update.accounts.len(), 3);
    assert_meta(&update.accounts[0], mint, false, true);
    assert_meta(&update.accounts[1], authority, false, false);
    assert_meta(&update.accounts[2], signer, true, false);
}

#[test]
fn official_scaled_ui_amount_builders_match_zig_shape() {
    let mint = key(105);
    let authority = key(106);
    let signer = key(107);

    let init =
        scaled_ui_amount_instruction::initialize(&id(), &mint, Some(authority), 1.25).unwrap();
    let mut expected_init = vec![43, 0];
    expected_init.extend_from_slice(authority.as_ref());
    expected_init.extend_from_slice(&1.25f64.to_le_bytes());
    assert_eq!(init.program_id, id());
    assert_eq!(init.data, expected_init);
    assert_eq!(init.accounts.len(), 1);
    assert_meta(&init.accounts[0], mint, false, true);

    let update = scaled_ui_amount_instruction::update_multiplier(
        &id(),
        &mint,
        &authority,
        &[&signer],
        2.5,
        -42,
    )
    .unwrap();
    let mut expected_update = vec![43, 1];
    expected_update.extend_from_slice(&2.5f64.to_le_bytes());
    expected_update.extend_from_slice(&(-42i64).to_le_bytes());
    assert_eq!(update.data, expected_update);
    assert_eq!(update.accounts.len(), 3);
    assert_meta(&update.accounts[0], mint, false, true);
    assert_meta(&update.accounts[1], authority, false, false);
    assert_meta(&update.accounts[2], signer, true, false);
}
