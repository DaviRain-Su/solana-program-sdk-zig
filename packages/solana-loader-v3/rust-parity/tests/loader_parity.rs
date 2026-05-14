use solana_instruction::AccountMeta;
use solana_loader_v3_interface::{
    instruction::{self, UpgradeableLoaderInstruction},
    state::UpgradeableLoaderState,
};
use solana_pubkey::Pubkey;

fn key(byte: u8) -> Pubkey {
    Pubkey::from([byte; 32])
}

fn assert_meta(meta: &AccountMeta, pubkey: Pubkey, is_signer: bool, is_writable: bool) {
    assert_eq!(meta.pubkey, pubkey);
    assert_eq!(meta.is_signer, is_signer);
    assert_eq!(meta.is_writable, is_writable);
}

#[test]
fn official_state_sizes_and_layouts_match_zig_constants() {
    assert_eq!(UpgradeableLoaderState::size_of_uninitialized(), 4);
    assert_eq!(UpgradeableLoaderState::size_of_buffer_metadata(), 37);
    assert_eq!(UpgradeableLoaderState::size_of_program(), 36);
    assert_eq!(UpgradeableLoaderState::size_of_programdata_metadata(), 45);

    let authority = key(9);
    let programdata = key(7);

    let uninitialized = bincode::serialize(&UpgradeableLoaderState::Uninitialized).unwrap();
    assert_eq!(uninitialized, vec![0, 0, 0, 0]);

    let buffer = bincode::serialize(&UpgradeableLoaderState::Buffer {
        authority_address: Some(authority),
    })
    .unwrap();
    assert_eq!(&buffer[0..5], &[1, 0, 0, 0, 1]);
    assert_eq!(&buffer[5..37], authority.as_ref());

    let program = bincode::serialize(&UpgradeableLoaderState::Program {
        programdata_address: programdata,
    })
    .unwrap();
    assert_eq!(&program[0..4], &[2, 0, 0, 0]);
    assert_eq!(&program[4..36], programdata.as_ref());

    let programdata_state = bincode::serialize(&UpgradeableLoaderState::ProgramData {
        slot: 42,
        upgrade_authority_address: Some(authority),
    })
    .unwrap();
    assert_eq!(&programdata_state[0..4], &[3, 0, 0, 0]);
    assert_eq!(
        u64::from_le_bytes(programdata_state[4..12].try_into().unwrap()),
        42
    );
    assert_eq!(programdata_state[12], 1);
    assert_eq!(&programdata_state[13..45], authority.as_ref());
}

#[test]
fn official_instruction_data_layouts_match_zig_constants() {
    let init = bincode::serialize(&UpgradeableLoaderInstruction::InitializeBuffer).unwrap();
    assert_eq!(init, vec![0, 0, 0, 0]);

    let write = bincode::serialize(&UpgradeableLoaderInstruction::Write {
        offset: 7,
        bytes: vec![1, 2, 3],
    })
    .unwrap();
    assert_eq!(&write[0..4], &[1, 0, 0, 0]);
    assert_eq!(u32::from_le_bytes(write[4..8].try_into().unwrap()), 7);
    assert_eq!(u64::from_le_bytes(write[8..16].try_into().unwrap()), 3);
    assert_eq!(&write[16..19], &[1, 2, 3]);

    let deploy = bincode::serialize(&UpgradeableLoaderInstruction::DeployWithMaxDataLen {
        max_data_len: 65536,
    })
    .unwrap();
    assert_eq!(&deploy[0..4], &[2, 0, 0, 0]);
    assert_eq!(u64::from_le_bytes(deploy[4..12].try_into().unwrap()), 65536);

    let extend = bincode::serialize(&UpgradeableLoaderInstruction::ExtendProgram {
        additional_bytes: 10_240,
    })
    .unwrap();
    assert_eq!(&extend[0..4], &[6, 0, 0, 0]);
    assert_eq!(u32::from_le_bytes(extend[4..8].try_into().unwrap()), 10_240);

    let checked = bincode::serialize(&UpgradeableLoaderInstruction::ExtendProgramChecked {
        additional_bytes: 10_241,
    })
    .unwrap();
    assert_eq!(&checked[0..4], &[9, 0, 0, 0]);
    assert_eq!(
        u32::from_le_bytes(checked[4..8].try_into().unwrap()),
        10_241
    );
}

#[test]
fn official_create_buffer_and_deploy_sequences_match_zig_shape() {
    let payer = key(1);
    let buffer = key(2);
    let authority = key(3);
    let program = key(4);

    let create_buffer = instruction::create_buffer(&payer, &buffer, &authority, 500, 123).unwrap();
    assert_eq!(create_buffer.len(), 2);
    assert_eq!(create_buffer[0].data[0..4], [0, 0, 0, 0]);
    assert_eq!(
        u64::from_le_bytes(create_buffer[0].data[12..20].try_into().unwrap()),
        UpgradeableLoaderState::size_of_buffer(123) as u64
    );
    assert_eq!(create_buffer[1].data, vec![0, 0, 0, 0]);
    assert_meta(&create_buffer[1].accounts[0], buffer, false, true);
    assert_meta(&create_buffer[1].accounts[1], authority, false, false);

    let deploy =
        instruction::deploy_with_max_program_len(&payer, &program, &buffer, &authority, 700, 4096)
            .unwrap();
    assert_eq!(deploy.len(), 2);
    assert_eq!(deploy[0].data[0..4], [0, 0, 0, 0]);
    assert_eq!(
        u64::from_le_bytes(deploy[0].data[12..20].try_into().unwrap()),
        UpgradeableLoaderState::size_of_program() as u64
    );
    assert_eq!(&deploy[1].data[0..4], &[2, 0, 0, 0]);
    assert_eq!(
        u64::from_le_bytes(deploy[1].data[4..12].try_into().unwrap()),
        4096
    );
    assert_meta(&deploy[1].accounts[0], payer, true, true);
    assert_meta(&deploy[1].accounts[2], program, false, true);
    assert_meta(&deploy[1].accounts[3], buffer, false, true);
}

#[test]
fn official_management_instruction_accounts_match_zig_shape() {
    let program = key(1);
    let programdata = solana_loader_v3_interface::get_program_data_address(&program);
    let buffer = key(2);
    let authority = key(3);
    let spill = key(4);
    let recipient = key(5);
    let payer = key(6);

    let upgrade = instruction::upgrade(&program, &buffer, &authority, &spill);
    assert_eq!(upgrade.data, vec![3, 0, 0, 0]);
    assert_meta(&upgrade.accounts[0], programdata, false, true);
    assert_meta(&upgrade.accounts[1], program, false, true);
    assert_meta(&upgrade.accounts[6], authority, true, false);

    let set = instruction::set_upgrade_authority(&program, &authority, Some(&payer));
    assert_eq!(set.data, vec![4, 0, 0, 0]);
    assert_meta(&set.accounts[0], programdata, false, true);
    assert_meta(&set.accounts[1], authority, true, false);
    assert_meta(&set.accounts[2], payer, false, false);

    let close = instruction::close_any(&programdata, &recipient, Some(&authority), Some(&program));
    assert_eq!(close.data, vec![5, 0, 0, 0]);
    assert_meta(&close.accounts[0], programdata, false, true);
    assert_meta(&close.accounts[1], recipient, false, true);
    assert_meta(&close.accounts[2], authority, true, false);
    assert_meta(&close.accounts[3], program, false, true);

    let extend = instruction::extend_program(&program, Some(&payer), 10_240);
    assert_eq!(&extend.data[0..4], &[6, 0, 0, 0]);
    assert_meta(&extend.accounts[0], programdata, false, true);
    assert_meta(&extend.accounts[1], program, false, true);
    assert_meta(&extend.accounts[3], payer, true, true);

    let migrate = instruction::migrate_program(&programdata, &program, &authority);
    assert_eq!(migrate.data, vec![8, 0, 0, 0]);
    assert_meta(&migrate.accounts[0], programdata, false, true);
    assert_meta(&migrate.accounts[2], authority, true, false);
}
