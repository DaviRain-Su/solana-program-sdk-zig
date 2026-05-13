use serde::{Deserialize, Serialize};
use spl_tlv_account_resolution::{
    account::ExtraAccountMeta,
    pubkey_data::PubkeyData,
    seeds::Seed,
    solana_instruction::AccountMeta,
    solana_pubkey::Pubkey,
};

const FIXTURE_JSON: &str = include_str!("../../src/official_account_resolution_parity.json");

#[derive(Debug, Deserialize, PartialEq, Serialize)]
struct AccountKeyDataFixture {
    key: [u8; 32],
    data: Option<Vec<u8>>,
}

#[derive(Debug, Deserialize, PartialEq, Serialize)]
struct MetaFixture {
    discriminator: u8,
    address_config: [u8; 32],
    is_signer: u8,
    is_writable: u8,
}

#[derive(Debug, Deserialize, PartialEq, Serialize)]
struct ResolvedFixture {
    pubkey: [u8; 32],
    is_signer: u8,
    is_writable: u8,
}

#[derive(Debug, Deserialize, PartialEq, Serialize)]
struct CaseFixture {
    name: String,
    meta: MetaFixture,
    resolved: ResolvedFixture,
}

#[derive(Debug, Deserialize, PartialEq, Serialize)]
struct Fixture {
    hook_program_id: [u8; 32],
    instruction_data: Vec<u8>,
    base_accounts: Vec<AccountKeyDataFixture>,
    cases: Vec<CaseFixture>,
}

fn snapshot(meta: &ExtraAccountMeta) -> MetaFixture {
    MetaFixture {
        discriminator: meta.discriminator,
        address_config: meta.address_config,
        is_signer: u8::from(bool::from(meta.is_signer)),
        is_writable: u8::from(bool::from(meta.is_writable)),
    }
}

fn snapshot_resolved(meta: AccountMeta) -> ResolvedFixture {
    ResolvedFixture {
        pubkey: meta.pubkey.to_bytes(),
        is_signer: u8::from(meta.is_signer),
        is_writable: u8::from(meta.is_writable),
    }
}

fn build_fixture() -> Fixture {
    let hook_program_id = Pubkey::new_from_array([0x91; 32]);
    let external_program_id = Pubkey::new_from_array([0x72; 32]);
    let fixed_pubkey = Pubkey::new_from_array([0x44; 32]);
    let account_key = Pubkey::new_from_array([0x33; 32]);
    let account_data = vec![
        0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, 0x10, 0x20,
        0x30, 0x40, 0x50, 0x60, 0x70, 0x80, 0x90, 0xa0,
        0xb0, 0xc0, 0xd0, 0xe0, 0xf0, 0x01, 0x12, 0x23,
        0x34, 0x45, 0x56, 0x67, 0x78, 0x89, 0x9a, 0xab,
    ];
    let instruction_key = Pubkey::new_from_array([0xa1; 32]);

    let mut instruction_data = vec![0u8; 40];
    instruction_data[0] = 0x99;
    instruction_data[1] = 0x10;
    instruction_data[2] = 0x20;
    instruction_data[3] = 0x30;
    instruction_data[4] = 0x40;
    instruction_data[5] = 0x55;
    instruction_data[8..40].copy_from_slice(instruction_key.as_ref());

    let seeds = vec![
        Seed::Literal {
            bytes: b"vault".to_vec(),
        },
        Seed::InstructionData {
            index: 1,
            length: 4,
        },
        Seed::AccountKey { index: 0 },
        Seed::AccountData {
            account_index: 0,
            data_index: 1,
            length: 3,
        },
    ];

    let base_account_keys = vec![account_key, external_program_id];
    let base_account_data = vec![Some(account_data.clone()), None];

    let fixed_meta = ExtraAccountMeta::new_with_pubkey(&fixed_pubkey, false, true).unwrap();
    let internal_meta = ExtraAccountMeta::new_with_seeds(&seeds, false, true).unwrap();
    let external_meta =
        ExtraAccountMeta::new_external_pda_with_seeds(1, &seeds, true, false).unwrap();
    let instruction_pubkey_meta = ExtraAccountMeta::new_with_pubkey_data(
        &PubkeyData::InstructionData { index: 8 },
        false,
        true,
    )
    .unwrap();
    let account_pubkey_meta = ExtraAccountMeta::new_with_pubkey_data(
        &PubkeyData::AccountData {
            account_index: 0,
            data_index: 0,
        },
        true,
        false,
    )
    .unwrap();

    let resolve = |meta: &ExtraAccountMeta| -> AccountMeta {
        meta.resolve(&instruction_data, &hook_program_id, |index| {
            base_account_keys
                .get(index)
                .map(|pubkey| (pubkey, base_account_data[index].as_deref()))
        })
        .unwrap()
    };

    Fixture {
        hook_program_id: hook_program_id.to_bytes(),
        instruction_data: instruction_data.clone(),
        base_accounts: vec![
            AccountKeyDataFixture {
                key: base_account_keys[0].to_bytes(),
                data: base_account_data[0].clone(),
            },
            AccountKeyDataFixture {
                key: base_account_keys[1].to_bytes(),
                data: base_account_data[1].clone(),
            },
        ],
        cases: vec![
            CaseFixture {
                name: "fixed_pubkey".to_string(),
                meta: snapshot(&fixed_meta),
                resolved: snapshot_resolved(resolve(&fixed_meta)),
            },
            CaseFixture {
                name: "internal_pda".to_string(),
                meta: snapshot(&internal_meta),
                resolved: snapshot_resolved(resolve(&internal_meta)),
            },
            CaseFixture {
                name: "external_pda".to_string(),
                meta: snapshot(&external_meta),
                resolved: snapshot_resolved(resolve(&external_meta)),
            },
            CaseFixture {
                name: "instruction_pubkey_data".to_string(),
                meta: snapshot(&instruction_pubkey_meta),
                resolved: snapshot_resolved(resolve(&instruction_pubkey_meta)),
            },
            CaseFixture {
                name: "account_pubkey_data".to_string(),
                meta: snapshot(&account_pubkey_meta),
                resolved: snapshot_resolved(resolve(&account_pubkey_meta)),
            },
        ],
    }
}

#[test]
fn fixture_matches_official_tlv_account_resolution_behavior() {
    let expected: Fixture = serde_json::from_str(FIXTURE_JSON).unwrap();
    let actual = build_fixture();
    assert_eq!(expected, actual);
}
