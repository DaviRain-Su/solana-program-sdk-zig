use {solana_instruction::AccountMeta, solana_pubkey::Pubkey, spl_memo::build_memo};

fn key(byte: u8) -> Pubkey {
    Pubkey::from([byte; 32])
}

fn assert_meta(meta: &AccountMeta, pubkey: Pubkey, is_signer: bool, is_writable: bool) {
    assert_eq!(meta.pubkey, pubkey);
    assert_eq!(meta.is_signer, is_signer);
    assert_eq!(meta.is_writable, is_writable);
}

#[test]
fn official_memo_builder_matches_zig_shape() {
    let signer_a = key(1);
    let signer_b = key(2);
    let memo = b"audit:withdraw";
    let ix = build_memo(memo, &[&signer_a, &signer_b]);

    assert_eq!(ix.program_id, spl_memo::id());
    assert_eq!(ix.data, memo);
    assert_eq!(ix.accounts.len(), 2);
    assert_meta(&ix.accounts[0], signer_a, true, false);
    assert_meta(&ix.accounts[1], signer_b, true, false);
}

#[test]
fn official_no_signer_memo_matches_zig_shape() {
    let ix = build_memo(b"hello", &[]);

    assert_eq!(ix.program_id, spl_memo::id());
    assert_eq!(ix.data, b"hello");
    assert!(ix.accounts.is_empty());
}
