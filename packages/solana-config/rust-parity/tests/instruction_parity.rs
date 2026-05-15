use serde::Serialize;
use solana_config_program::{config_instruction, ConfigState};
use solana_sdk::{instruction::AccountMeta, pubkey::Pubkey};

#[derive(Default, Serialize)]
struct TestState {
    value: u32,
    enabled: bool,
}

impl ConfigState for TestState {
    fn max_space() -> u64 {
        5
    }
}

fn key(byte: u8) -> Pubkey {
    Pubkey::from([byte; 32])
}

fn assert_meta(meta: &AccountMeta, pubkey: Pubkey, is_signer: bool, is_writable: bool) {
    assert_eq!(meta.pubkey, pubkey);
    assert_eq!(meta.is_signer, is_signer);
    assert_eq!(meta.is_writable, is_writable);
}

#[test]
fn official_store_matches_zig_raw_config_layout() {
    let config = key(9);
    let signer = key(1);
    let readonly = key(2);
    let state = TestState {
        value: 0x5566_7788,
        enabled: true,
    };
    let ix = config_instruction::store(
        &config,
        false,
        vec![(signer, true), (readonly, false)],
        &state,
    );

    assert_eq!(ix.program_id, solana_config_program::id());
    assert_eq!(ix.accounts.len(), 2);
    assert_meta(&ix.accounts[0], config, false, true);
    assert_meta(&ix.accounts[1], signer, true, true);
    assert_eq!(ix.data.len(), 72);
    assert_eq!(ix.data[0], 2);
    assert_eq!(&ix.data[1..33], &signer.to_bytes());
    assert_eq!(ix.data[33], 1);
    assert_eq!(&ix.data[34..66], &readonly.to_bytes());
    assert_eq!(ix.data[66], 0);
    assert_eq!(&ix.data[67..72], &[0x88, 0x77, 0x66, 0x55, 1]);
}

#[test]
fn official_initialize_shape_matches_zig_initialize_raw() {
    let config = key(9);
    let ix = config_instruction::store(&config, true, Vec::new(), &TestState::default());

    assert_eq!(ix.accounts.len(), 1);
    assert_meta(&ix.accounts[0], config, true, true);
    assert_eq!(&ix.data, &[0, 0, 0, 0, 0, 0]);
}
