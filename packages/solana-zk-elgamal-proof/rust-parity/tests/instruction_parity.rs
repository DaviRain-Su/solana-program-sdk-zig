use {
    bytemuck::Zeroable,
    solana_instruction::AccountMeta,
    solana_pubkey::Pubkey,
    solana_zk_sdk::zk_elgamal_proof_program::{
        id,
        instruction::{close_context_state, ContextStateInfo, ProofInstruction},
        proof_data::PubkeyValidityProofData,
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
fn official_close_context_state_matches_zig_shape() {
    let context_state = key(1);
    let destination = key(2);
    let authority = key(3);
    let ix = close_context_state(
        ContextStateInfo {
            context_state_account: &context_state,
            context_state_authority: &authority,
        },
        &destination,
    );

    assert_eq!(ix.program_id, id());
    assert_eq!(ix.data, vec![0]);
    assert_eq!(ix.accounts.len(), 3);
    assert_meta(&ix.accounts[0], context_state, false, true);
    assert_meta(&ix.accounts[1], destination, false, true);
    assert_meta(&ix.accounts[2], authority, true, false);
}

#[test]
fn official_verify_proof_builders_match_raw_shape() {
    let context_state = key(4);
    let authority = key(5);
    let proof_account = key(6);

    let proof_data = PubkeyValidityProofData::zeroed();
    let inline = ProofInstruction::VerifyPubkeyValidity.encode_verify_proof(
        Some(ContextStateInfo {
            context_state_account: &context_state,
            context_state_authority: &authority,
        }),
        &proof_data,
    );
    assert_eq!(inline.program_id, id());
    assert_eq!(inline.data[0], 4);
    assert_eq!(inline.accounts.len(), 2);
    assert_meta(&inline.accounts[0], context_state, false, true);
    assert_meta(&inline.accounts[1], authority, false, false);

    let from_account = ProofInstruction::VerifyPubkeyValidity.encode_verify_proof_from_account(
        Some(ContextStateInfo {
            context_state_account: &context_state,
            context_state_authority: &authority,
        }),
        &proof_account,
        42,
    );
    assert_eq!(from_account.program_id, id());
    assert_eq!(from_account.data, vec![4, 42, 0, 0, 0]);
    assert_eq!(from_account.accounts.len(), 3);
    assert_meta(&from_account.accounts[0], proof_account, false, true);
    assert_meta(&from_account.accounts[1], context_state, false, true);
    assert_meta(&from_account.accounts[2], authority, false, false);
}
