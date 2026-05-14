use {
    solana_instruction::AccountMeta,
    solana_pubkey::Pubkey,
    solana_zk_sdk::zk_elgamal_proof_program::proof_data::PubkeyValidityProofData,
    spl_elgamal_registry::{
        get_elgamal_registry_address, id,
        instruction::{create_registry, update_registry, RegistryInstruction},
        state::{ElGamalRegistry, ELGAMAL_REGISTRY_ACCOUNT_LEN},
        REGISTRY_ADDRESS_SEED,
    },
    spl_token_confidential_transfer_proof_extraction::instruction::ProofLocation,
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
fn official_state_and_constants_match_zig_surface() {
    assert_eq!(
        id().to_string(),
        "regVYJW7tcT8zipN5YiBvHsvR5jXW1uLFxaHSbugABg"
    );
    assert_eq!(REGISTRY_ADDRESS_SEED, b"elgamal-registry");
    assert_eq!(ELGAMAL_REGISTRY_ACCOUNT_LEN, 64);
    assert_eq!(std::mem::size_of::<ElGamalRegistry>(), 64);
}

#[test]
fn official_instruction_pack_matches_zig_wire_tags() {
    assert_eq!(
        RegistryInstruction::CreateRegistry {
            proof_instruction_offset: 0
        }
        .pack(),
        vec![0, 0]
    );
    assert_eq!(
        RegistryInstruction::UpdateRegistry {
            proof_instruction_offset: -1
        }
        .pack(),
        vec![1, 255]
    );
}

#[test]
fn official_context_state_builders_match_zig_shape() {
    let owner = key(1);
    let context_state = key(2);
    let registry = get_elgamal_registry_address(&owner, &id());

    let create = create_registry(
        &owner,
        ProofLocation::<PubkeyValidityProofData>::ContextStateAccount(&context_state),
    )
    .unwrap();
    assert_eq!(create.len(), 1);
    let create_ix = &create[0];
    assert_eq!(create_ix.program_id, id());
    assert_eq!(create_ix.data, vec![0, 0]);
    assert_eq!(create_ix.accounts.len(), 4);
    assert_meta(&create_ix.accounts[0], registry, false, true);
    assert_meta(&create_ix.accounts[1], owner, true, false);
    assert_meta(
        &create_ix.accounts[2],
        solana_sdk_ids::system_program::id(),
        false,
        false,
    );
    assert_meta(&create_ix.accounts[3], context_state, false, false);

    let update = update_registry(
        &owner,
        ProofLocation::<PubkeyValidityProofData>::ContextStateAccount(&context_state),
    )
    .unwrap();
    assert_eq!(update.len(), 1);
    let update_ix = &update[0];
    assert_eq!(update_ix.program_id, id());
    assert_eq!(update_ix.data, vec![1, 0]);
    assert_eq!(update_ix.accounts.len(), 3);
    assert_meta(&update_ix.accounts[0], registry, false, true);
    assert_meta(&update_ix.accounts[1], context_state, false, false);
    assert_meta(&update_ix.accounts[2], owner, true, false);
}
