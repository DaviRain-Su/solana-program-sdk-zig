use solana_feature_gate_interface as feature_gate;
use solana_instruction::AccountMeta;
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
fn official_feature_account_layout_matches_zig_layout() {
    assert_eq!(feature_gate::Feature::size_of(), 9);

    let inactive = bincode::serialize(&feature_gate::Feature { activated_at: None }).unwrap();
    assert_eq!(inactive, vec![0]);

    let active = bincode::serialize(&feature_gate::Feature {
        activated_at: Some(0x0102_0304_0506_0708),
    })
    .unwrap();
    assert_eq!(
        active,
        vec![1, 8, 7, 6, 5, 4, 3, 2, 1]
    );
}

#[test]
fn official_activation_instructions_match_zig_sequence() {
    let feature = key(1);
    let funder = key(2);
    let instructions = feature_gate::activate_with_lamports(&feature, &funder, 500);

    assert_eq!(instructions.len(), 3);

    let transfer = &instructions[0];
    assert_eq!(&transfer.data[0..4], &[2, 0, 0, 0]);
    assert_eq!(
        u64::from_le_bytes(transfer.data[4..12].try_into().unwrap()),
        500
    );
    assert_meta(&transfer.accounts[0], funder, true, true);
    assert_meta(&transfer.accounts[1], feature, false, true);

    let allocate = &instructions[1];
    assert_eq!(&allocate.data[0..4], &[8, 0, 0, 0]);
    assert_eq!(
        u64::from_le_bytes(allocate.data[4..12].try_into().unwrap()),
        feature_gate::Feature::size_of() as u64
    );
    assert_meta(&allocate.accounts[0], feature, true, true);

    let assign = &instructions[2];
    assert_eq!(&assign.data[0..4], &[1, 0, 0, 0]);
    assert_eq!(&assign.data[4..36], &feature_gate::ID.to_bytes());
    assert_meta(&assign.accounts[0], feature, true, true);
}
