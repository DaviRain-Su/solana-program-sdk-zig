use borsh::to_vec;
use serde::Deserialize;
use solana_address::Address;
use spl_token_metadata_interface::{
    instruction::{emit, initialize, remove_key, update_authority, update_field},
    solana_instruction::Instruction,
    state::Field,
};

const FIXTURE_JSON: &str = include_str!("../../src/official_parity_fixture.json");

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
struct FieldInput {
    tag: u8,
    key: String,
}

#[derive(Debug, Deserialize)]
struct FieldCase {
    input: FieldInput,
    data: Vec<u8>,
}

#[derive(Debug, Deserialize)]
struct InitializeCase {
    name: String,
    symbol: String,
    uri: String,
    instruction: InstructionFixture,
}

#[derive(Debug, Deserialize)]
struct UpdateFieldCase {
    field: FieldInput,
    value: String,
    instruction: InstructionFixture,
}

#[derive(Debug, Deserialize)]
struct RemoveKeyCase {
    idempotent: u8,
    key: String,
    instruction: InstructionFixture,
}

#[derive(Debug, Deserialize)]
struct UpdateAuthorityCase {
    new_authority: [u8; 32],
    instruction: InstructionFixture,
}

#[derive(Debug, Deserialize)]
struct EmitCase {
    start_is_some: u8,
    start: u64,
    end_is_some: u8,
    end: u64,
    instruction: InstructionFixture,
}

#[derive(Debug, Deserialize)]
struct Fixture {
    fields: Vec<FieldCase>,
    initialize: Vec<InitializeCase>,
    update_field: Vec<UpdateFieldCase>,
    remove_key: Vec<RemoveKeyCase>,
    update_authority: Vec<UpdateAuthorityCase>,
    emit: Vec<EmitCase>,
}

fn address(bytes: [u8; 32]) -> Address {
    Address::new_from_array(bytes)
}

fn field(input: &FieldInput) -> Field {
    match input.tag {
        0 => Field::Name,
        1 => Field::Symbol,
        2 => Field::Uri,
        3 => Field::Key(input.key.clone()),
        _ => panic!("unexpected field tag {}", input.tag),
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
fn fixture_matches_official_field_borsh_encodings() {
    let fixture: Fixture = serde_json::from_str(FIXTURE_JSON).unwrap();

    for case in &fixture.fields {
        assert_eq!(case.data, to_vec(&field(&case.input)).unwrap());
    }
}

#[test]
fn fixture_matches_official_instruction_builders() {
    let fixture: Fixture = serde_json::from_str(FIXTURE_JSON).unwrap();

    for case in &fixture.initialize {
        let ix = initialize(
            &address(case.instruction.program_id),
            &address(case.instruction.accounts[0].pubkey),
            &address(case.instruction.accounts[1].pubkey),
            &address(case.instruction.accounts[2].pubkey),
            &address(case.instruction.accounts[3].pubkey),
            case.name.clone(),
            case.symbol.clone(),
            case.uri.clone(),
        );
        assert_instruction_matches(ix, &case.instruction);
    }

    for case in &fixture.update_field {
        let ix = update_field(
            &address(case.instruction.program_id),
            &address(case.instruction.accounts[0].pubkey),
            &address(case.instruction.accounts[1].pubkey),
            field(&case.field),
            case.value.clone(),
        );
        assert_instruction_matches(ix, &case.instruction);
    }

    for case in &fixture.remove_key {
        let ix = remove_key(
            &address(case.instruction.program_id),
            &address(case.instruction.accounts[0].pubkey),
            &address(case.instruction.accounts[1].pubkey),
            case.key.clone(),
            case.idempotent != 0,
        );
        assert_instruction_matches(ix, &case.instruction);
    }

    for case in &fixture.update_authority {
        let new_authority = if case.new_authority == [0u8; 32] {
            Default::default()
        } else {
            address(case.new_authority).into()
        };
        let ix = update_authority(
            &address(case.instruction.program_id),
            &address(case.instruction.accounts[0].pubkey),
            &address(case.instruction.accounts[1].pubkey),
            new_authority,
        );
        assert_instruction_matches(ix, &case.instruction);
    }

    for case in &fixture.emit {
        let ix = emit(
            &address(case.instruction.program_id),
            &address(case.instruction.accounts[0].pubkey),
            (case.start_is_some != 0).then_some(case.start),
            (case.end_is_some != 0).then_some(case.end),
        );
        assert_instruction_matches(ix, &case.instruction);
    }
}
