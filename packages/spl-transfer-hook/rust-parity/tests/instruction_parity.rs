use serde::Deserialize;
use spl_tlv_account_resolution::{
    account::ExtraAccountMeta,
    solana_instruction::{AccountMeta, Instruction},
    solana_pubkey::Pubkey,
};
use spl_transfer_hook_interface::instruction::{
    execute, initialize_extra_account_meta_list, update_extra_account_meta_list,
};

const FIXTURE_JSON: &str = include_str!("../../src/official_instruction_parity.json");

#[derive(Debug, Deserialize)]
struct AccountFixture {
    pubkey: [u8; 32],
    is_signer: u8,
    is_writable: u8,
}

#[derive(Debug, Deserialize)]
struct InstructionFixture {
    program_id: [u8; 32],
    accounts: Vec<AccountFixture>,
    data: Vec<u8>,
}

#[derive(Debug, Deserialize)]
struct Inputs {
    program_id: [u8; 32],
    source: [u8; 32],
    mint: [u8; 32],
    destination: [u8; 32],
    authority: [u8; 32],
    validation: [u8; 32],
    amount: u64,
    extra_account_metas: Vec<AccountFixture>,
}

#[derive(Debug, Deserialize)]
struct Fixture {
    inputs: Inputs,
    execute: InstructionFixture,
    initialize: InstructionFixture,
    update: InstructionFixture,
}

fn pubkey(bytes: [u8; 32]) -> Pubkey {
    Pubkey::new_from_array(bytes)
}

fn account_meta(fixture: &AccountFixture) -> AccountMeta {
    AccountMeta {
        pubkey: pubkey(fixture.pubkey),
        is_signer: fixture.is_signer != 0,
        is_writable: fixture.is_writable != 0,
    }
}

fn snapshot(ix: Instruction) -> InstructionFixture {
    InstructionFixture {
        program_id: ix.program_id.to_bytes(),
        accounts: ix
            .accounts
            .into_iter()
            .map(|meta| AccountFixture {
                pubkey: meta.pubkey.to_bytes(),
                is_signer: u8::from(meta.is_signer),
                is_writable: u8::from(meta.is_writable),
            })
            .collect(),
        data: ix.data,
    }
}

fn assert_instruction_matches(actual: Instruction, expected: &InstructionFixture) {
    let actual = snapshot(actual);
    assert_eq!(expected.program_id, actual.program_id);
    assert_eq!(expected.data, actual.data);
    assert_eq!(expected.accounts.len(), actual.accounts.len());

    for (expected_meta, actual_meta) in expected.accounts.iter().zip(actual.accounts.iter()) {
        assert_eq!(expected_meta.pubkey, actual_meta.pubkey);
        assert_eq!(expected_meta.is_signer, actual_meta.is_signer);
        assert_eq!(expected_meta.is_writable, actual_meta.is_writable);
    }
}

#[test]
fn fixture_matches_official_spl_transfer_hook_interface_builders() {
    let fixture: Fixture = serde_json::from_str(FIXTURE_JSON).unwrap();

    let extra_account_metas: Vec<ExtraAccountMeta> = fixture
        .inputs
        .extra_account_metas
        .iter()
        .map(account_meta)
        .map(ExtraAccountMeta::from)
        .collect();

    let execute_ix = execute(
        &pubkey(fixture.inputs.program_id),
        &pubkey(fixture.inputs.source),
        &pubkey(fixture.inputs.mint),
        &pubkey(fixture.inputs.destination),
        &pubkey(fixture.inputs.authority),
        fixture.inputs.amount,
    );
    assert_instruction_matches(execute_ix, &fixture.execute);

    let initialize_ix = initialize_extra_account_meta_list(
        &pubkey(fixture.inputs.program_id),
        &pubkey(fixture.inputs.validation),
        &pubkey(fixture.inputs.mint),
        &pubkey(fixture.inputs.authority),
        &extra_account_metas,
    );
    assert_instruction_matches(initialize_ix, &fixture.initialize);

    let update_ix = update_extra_account_meta_list(
        &pubkey(fixture.inputs.program_id),
        &pubkey(fixture.inputs.validation),
        &pubkey(fixture.inputs.mint),
        &pubkey(fixture.inputs.authority),
        &extra_account_metas,
    );
    assert_instruction_matches(update_ix, &fixture.update);
}
