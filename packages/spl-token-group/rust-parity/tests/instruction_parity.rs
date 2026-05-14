use serde::Deserialize;
use solana_address::Address;
use solana_instruction::Instruction;
use spl_discriminator::SplDiscriminate;
use spl_token_group_interface::instruction::{
    initialize_group, initialize_member, update_group_authority, update_group_max_size,
    InitializeGroup, InitializeMember, TokenGroupInstruction, UpdateGroupAuthority,
    UpdateGroupMaxSize,
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
struct Discriminators {
    initialize_group: [u8; 8],
    update_group_max_size: [u8; 8],
    update_group_authority: [u8; 8],
    initialize_member: [u8; 8],
}

#[derive(Debug, Deserialize)]
struct InitializeGroupCase {
    update_authority: [u8; 32],
    max_size: u64,
    instruction: InstructionFixture,
}

#[derive(Debug, Deserialize)]
struct UpdateGroupMaxSizeCase {
    max_size: u64,
    instruction: InstructionFixture,
}

#[derive(Debug, Deserialize)]
struct UpdateGroupAuthorityCase {
    new_authority: [u8; 32],
    instruction: InstructionFixture,
}

#[derive(Debug, Deserialize)]
struct InitializeMemberCase {
    instruction: InstructionFixture,
}

#[derive(Debug, Deserialize)]
struct Fixture {
    discriminators: Discriminators,
    initialize_group: Vec<InitializeGroupCase>,
    update_group_max_size: Vec<UpdateGroupMaxSizeCase>,
    update_group_authority: Vec<UpdateGroupAuthorityCase>,
    initialize_member: Vec<InitializeMemberCase>,
}

fn address(bytes: [u8; 32]) -> Address {
    Address::new_from_array(bytes)
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

fn nullable_address(bytes: [u8; 32]) -> Option<Address> {
    if bytes == [0u8; 32] {
        None
    } else {
        Some(address(bytes))
    }
}

#[test]
fn fixture_matches_official_group_discriminators() {
    let fixture: Fixture = serde_json::from_str(FIXTURE_JSON).unwrap();

    assert_eq!(
        fixture.discriminators.initialize_group,
        InitializeGroup::SPL_DISCRIMINATOR_SLICE
    );
    assert_eq!(
        fixture.discriminators.update_group_max_size,
        UpdateGroupMaxSize::SPL_DISCRIMINATOR_SLICE
    );
    assert_eq!(
        fixture.discriminators.update_group_authority,
        UpdateGroupAuthority::SPL_DISCRIMINATOR_SLICE
    );
    assert_eq!(
        fixture.discriminators.initialize_member,
        InitializeMember::SPL_DISCRIMINATOR_SLICE
    );
}

#[test]
fn fixture_matches_official_group_instruction_builders_and_unpacking() {
    let fixture: Fixture = serde_json::from_str(FIXTURE_JSON).unwrap();

    for case in &fixture.initialize_group {
        let ix = initialize_group(
            &address(case.instruction.program_id),
            &address(case.instruction.accounts[0].pubkey),
            &address(case.instruction.accounts[1].pubkey),
            &address(case.instruction.accounts[2].pubkey),
            nullable_address(case.update_authority),
            case.max_size,
        );
        assert_instruction_matches(ix, &case.instruction);

        let unpacked = TokenGroupInstruction::unpack(&case.instruction.data).unwrap();
        assert_eq!(case.instruction.data, unpacked.pack());
    }

    for case in &fixture.update_group_max_size {
        let ix = update_group_max_size(
            &address(case.instruction.program_id),
            &address(case.instruction.accounts[0].pubkey),
            &address(case.instruction.accounts[1].pubkey),
            case.max_size,
        );
        assert_instruction_matches(ix, &case.instruction);

        let unpacked = TokenGroupInstruction::unpack(&case.instruction.data).unwrap();
        assert_eq!(case.instruction.data, unpacked.pack());
    }

    for case in &fixture.update_group_authority {
        let ix = update_group_authority(
            &address(case.instruction.program_id),
            &address(case.instruction.accounts[0].pubkey),
            &address(case.instruction.accounts[1].pubkey),
            nullable_address(case.new_authority),
        );
        assert_instruction_matches(ix, &case.instruction);

        let unpacked = TokenGroupInstruction::unpack(&case.instruction.data).unwrap();
        assert_eq!(case.instruction.data, unpacked.pack());
    }

    for case in &fixture.initialize_member {
        let ix = initialize_member(
            &address(case.instruction.program_id),
            &address(case.instruction.accounts[0].pubkey),
            &address(case.instruction.accounts[1].pubkey),
            &address(case.instruction.accounts[2].pubkey),
            &address(case.instruction.accounts[3].pubkey),
            &address(case.instruction.accounts[4].pubkey),
        );
        assert_instruction_matches(ix, &case.instruction);

        let unpacked = TokenGroupInstruction::unpack(&case.instruction.data).unwrap();
        assert_eq!(case.instruction.data, unpacked.pack());
    }
}
