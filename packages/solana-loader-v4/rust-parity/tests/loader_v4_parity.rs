use memoffset::offset_of;
use solana_instruction::AccountMeta;
use solana_loader_v4_interface::{
    instruction::{self, LoaderV4Instruction},
    state::{LoaderV4State, LoaderV4Status},
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
fn official_state_layout_matches_zig_constants() {
    assert_eq!(offset_of!(LoaderV4State, slot), 0x00);
    assert_eq!(
        offset_of!(LoaderV4State, authority_address_or_next_version),
        0x08
    );
    assert_eq!(offset_of!(LoaderV4State, status), 0x28);
    assert_eq!(LoaderV4State::program_data_offset(), 0x30);
    assert_eq!(LoaderV4Status::Retracted as u64, 0);
    assert_eq!(LoaderV4Status::Deployed as u64, 1);
    assert_eq!(LoaderV4Status::Finalized as u64, 2);
}

#[test]
fn official_instruction_data_layouts_match_zig_constants() {
    let write = bincode::serialize(&LoaderV4Instruction::Write {
        offset: 7,
        bytes: vec![1, 2, 3],
    })
    .unwrap();
    assert_eq!(&write[0..4], &[0, 0, 0, 0]);
    assert_eq!(u32::from_le_bytes(write[4..8].try_into().unwrap()), 7);
    assert_eq!(u64::from_le_bytes(write[8..16].try_into().unwrap()), 3);
    assert_eq!(&write[16..19], &[1, 2, 3]);

    let copy = bincode::serialize(&LoaderV4Instruction::Copy {
        destination_offset: 1,
        source_offset: 2,
        length: 3,
    })
    .unwrap();
    assert_eq!(&copy[0..4], &[1, 0, 0, 0]);
    assert_eq!(u32::from_le_bytes(copy[4..8].try_into().unwrap()), 1);
    assert_eq!(u32::from_le_bytes(copy[8..12].try_into().unwrap()), 2);
    assert_eq!(u32::from_le_bytes(copy[12..16].try_into().unwrap()), 3);

    let length =
        bincode::serialize(&LoaderV4Instruction::SetProgramLength { new_size: 1024 }).unwrap();
    assert_eq!(&length[0..4], &[2, 0, 0, 0]);
    assert_eq!(u32::from_le_bytes(length[4..8].try_into().unwrap()), 1024);

    assert_eq!(
        bincode::serialize(&LoaderV4Instruction::Deploy).unwrap(),
        vec![3, 0, 0, 0]
    );
    assert_eq!(
        bincode::serialize(&LoaderV4Instruction::Retract).unwrap(),
        vec![4, 0, 0, 0]
    );
    assert_eq!(
        bincode::serialize(&LoaderV4Instruction::TransferAuthority).unwrap(),
        vec![5, 0, 0, 0]
    );
    assert_eq!(
        bincode::serialize(&LoaderV4Instruction::Finalize).unwrap(),
        vec![6, 0, 0, 0]
    );
}

#[test]
fn official_builder_accounts_match_zig_shape() {
    let payer = key(1);
    let program = key(2);
    let authority = key(3);
    let recipient = key(4);
    let source = key(5);
    let new_authority = key(6);
    let next_version = key(7);

    let create = instruction::create_buffer(&payer, &program, 500, &authority, 123, &recipient);
    assert_eq!(create.len(), 2);
    assert_eq!(&create[0].data[0..4], &[0, 0, 0, 0]);
    assert_eq!(
        u64::from_le_bytes(create[0].data[12..20].try_into().unwrap()),
        0
    );
    assert_eq!(&create[1].data[0..4], &[2, 0, 0, 0]);
    assert_meta(&create[1].accounts[0], program, false, true);
    assert_meta(&create[1].accounts[1], authority, true, false);
    assert_meta(&create[1].accounts[2], recipient, false, true);

    let write = instruction::write(&program, &authority, 7, vec![1, 2, 3]);
    assert_eq!(&write.data[0..4], &[0, 0, 0, 0]);
    assert_meta(&write.accounts[0], program, false, true);
    assert_meta(&write.accounts[1], authority, true, false);

    let copy = instruction::copy(&program, &authority, &source, 1, 2, 3);
    assert_eq!(&copy.data[0..4], &[1, 0, 0, 0]);
    assert_meta(&copy.accounts[2], source, false, false);

    let deploy = instruction::deploy_from_source(&program, &authority, &source);
    assert_eq!(deploy.data, vec![3, 0, 0, 0]);
    assert_meta(&deploy.accounts[2], source, false, true);

    let retract = instruction::retract(&program, &authority);
    assert_eq!(retract.data, vec![4, 0, 0, 0]);

    let transfer = instruction::transfer_authority(&program, &authority, &new_authority);
    assert_eq!(transfer.data, vec![5, 0, 0, 0]);
    assert_meta(&transfer.accounts[2], new_authority, true, false);

    let finalize = instruction::finalize(&program, &authority, &next_version);
    assert_eq!(finalize.data, vec![6, 0, 0, 0]);
    assert_meta(&finalize.accounts[2], next_version, false, false);
}
