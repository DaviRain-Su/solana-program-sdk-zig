//! Real SBF coverage for the Token-2022 parsing demo.
//!
//! The tests load the exact built artifact path
//! `zig-out/lib/example_spl_token_2022_parse.so` through Mollusk and
//! verify the demo's documented ABI and stable failure mapping.

use {
    mollusk_svm::{file, result::ProgramResult, Mollusk},
    mollusk_svm_programs_token::{token as spl_token_program, token2022 as spl_token_2022_program},
    solana_account::Account,
    solana_instruction::{AccountMeta, Instruction},
    solana_program_error::ProgramError as SolanaProgramError,
    solana_pubkey::Pubkey,
    solana_sdk_ids::bpf_loader_upgradeable,
    std::path::{Path, PathBuf},
};

mod program {
    solana_pubkey::declare_id!("Zigc1Hc97L8Pebma74jDzYiyoUvdxxcj7Gxppg9VRxK");
}

const ROUTE_MINT: u8 = 0;
const ROUTE_ACCOUNT: u8 = 1;

const EXT_MINT_CLOSE_AUTHORITY: u16 = 3;
const EXT_DEFAULT_ACCOUNT_STATE: u16 = 6;
const EXT_IMMUTABLE_OWNER: u16 = 7;
const EXT_NON_TRANSFERABLE: u16 = 9;
const EXT_TOKEN_METADATA: u16 = 19;
const EXT_TRANSFER_FEE_AMOUNT: u16 = 2;
const EXT_UNKNOWN_BEFORE: u16 = 0x7FFE;
const EXT_UNKNOWN_BETWEEN: u16 = 0x7FFD;
const EXT_UNKNOWN_AFTER: u16 = 0x7FFC;

const MINT_BASE_LEN: usize = 82;
const ACCOUNT_TYPE_OFFSET: usize = 165;
const TLV_START_OFFSET: usize = 166;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u32)]
enum DemoFailure {
    InvalidInstructionData = 6100,
    InvalidAccountList = 6101,
    IncorrectProgramId = 6102,
    WrongAccountType = 6103,
    InvalidAccountData = 6104,
    ExtensionNotFound = 6105,
    UnsupportedExtension = 6106,
    InvalidExtensionLength = 6107,
}

fn token_2022_demo_artifact_path() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("zig-out")
        .join("lib")
        .join("example_spl_token_2022_parse.so")
}

fn fresh_mollusk() -> Mollusk {
    let artifact = token_2022_demo_artifact_path();
    assert!(
        artifact.is_file(),
        "expected Token-2022 demo artifact at {}; build it with `SOLANA_ZIG=\"${{SOLANA_ZIG:-$(scripts/ensure-solana-zig.sh)}}\" && \"$SOLANA_ZIG\" build --build-file program-test/build.zig --summary all`",
        artifact.display(),
    );

    let mut mollusk = Mollusk::default();
    let elf = file::read_file(&artifact);
    mollusk.add_program_with_elf_and_loader(&program::id(), &elf, &bpf_loader_upgradeable::id());
    mollusk
}

fn append_record(dst: &mut Vec<u8>, extension_type: u16, payload: &[u8]) {
    dst.extend_from_slice(&extension_type.to_le_bytes());
    dst.extend_from_slice(&(payload.len() as u16).to_le_bytes());
    dst.extend_from_slice(payload);
}

fn mint_with_extensions(records: &[(u16, Vec<u8>)]) -> Vec<u8> {
    let mut data = vec![0u8; TLV_START_OFFSET];
    data[ACCOUNT_TYPE_OFFSET] = 1;
    for (extension_type, payload) in records {
        append_record(&mut data, *extension_type, payload);
    }
    data
}

fn account_with_extensions(records: &[(u16, Vec<u8>)]) -> Vec<u8> {
    let mut data = vec![0xA5u8; TLV_START_OFFSET];
    data[ACCOUNT_TYPE_OFFSET] = 2;
    for (extension_type, payload) in records {
        append_record(&mut data, *extension_type, payload);
    }
    data
}

fn readonly_data_account(owner: Pubkey, data: Vec<u8>) -> Account {
    Account {
        lamports: 1,
        data,
        owner,
        executable: false,
        rent_epoch: 0,
    }
}

fn demo_ix(
    route: u8,
    extension_type: u16,
    expected_bytes: &[u8],
    account: Option<(Pubkey, bool, bool)>,
) -> Instruction {
    let mut data = Vec::with_capacity(5 + expected_bytes.len());
    data.push(route);
    data.extend_from_slice(&extension_type.to_le_bytes());
    data.extend_from_slice(&(expected_bytes.len() as u16).to_le_bytes());
    data.extend_from_slice(expected_bytes);

    let accounts = account
        .into_iter()
        .map(|(pubkey, is_signer, is_writable)| {
            if is_writable {
                AccountMeta::new(pubkey, is_signer)
            } else {
                AccountMeta::new_readonly(pubkey, is_signer)
            }
        })
        .collect();

    Instruction {
        program_id: program::id(),
        accounts,
        data,
    }
}

fn run(
    mollusk: &Mollusk,
    instruction: &Instruction,
    accounts: &[(Pubkey, Account)],
) -> mollusk_svm::result::InstructionResult {
    mollusk.process_instruction(instruction, accounts)
}

fn assert_custom_failure(
    result: &mollusk_svm::result::InstructionResult,
    expected: DemoFailure,
) {
    assert_eq!(
        result.program_result,
        ProgramResult::Failure(SolanaProgramError::Custom(expected as u32)),
        "expected {expected:?}, got {:?}",
        result.program_result,
    );
}

fn assert_success(result: &mollusk_svm::result::InstructionResult) {
    assert!(
        matches!(result.program_result, ProgramResult::Success),
        "expected success, got {:?}",
        result.program_result,
    );
}

fn assert_account_unchanged(
    before: &[(Pubkey, Account)],
    after: &[(Pubkey, Account)],
    key: &Pubkey,
) {
    let before_account = before
        .iter()
        .find(|(candidate, _)| candidate == key)
        .expect("missing pre-account")
        .1
        .clone();
    let after_account = after
        .iter()
        .find(|(candidate, _)| candidate == key)
        .expect("missing post-account")
        .1
        .clone();

    assert_eq!(after_account.lamports, before_account.lamports);
    assert_eq!(after_account.data, before_account.data);
    assert_eq!(after_account.owner, before_account.owner);
    assert_eq!(after_account.executable, before_account.executable);
    assert_eq!(after_account.rent_epoch, before_account.rent_epoch);
}

#[test]
fn token_2022_demo_helper_uses_exact_built_artifact_path() {
    let expected = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("zig-out")
        .join("lib")
        .join("example_spl_token_2022_parse.so");
    assert_eq!(token_2022_demo_artifact_path(), expected);
    assert!(token_2022_demo_artifact_path().is_file());
}

#[test]
fn token_2022_demo_verifies_exact_mint_extension_bytes() {
    let mollusk = fresh_mollusk();
    let account_key = Pubkey::new_unique();
    let expected = vec![2u8];
    let account_data = mint_with_extensions(&[(EXT_DEFAULT_ACCOUNT_STATE, expected.clone())]);
    let accounts = vec![(
        account_key,
        readonly_data_account(spl_token_2022_program::ID, account_data),
    )];

    let result = run(
        &mollusk,
        &demo_ix(
            ROUTE_MINT,
            EXT_DEFAULT_ACCOUNT_STATE,
            &expected,
            Some((account_key, false, false)),
        ),
        &accounts,
    );
    assert_success(&result);
    assert_account_unchanged(&accounts, &result.resulting_accounts, &account_key);
}

#[test]
fn token_2022_demo_verifies_exact_account_extension_bytes() {
    let mollusk = fresh_mollusk();
    let account_key = Pubkey::new_unique();
    let expected = 0x8877_6655_4433_2211u64.to_le_bytes().to_vec();
    let account_data = account_with_extensions(&[(EXT_TRANSFER_FEE_AMOUNT, expected.clone())]);
    let accounts = vec![(
        account_key,
        readonly_data_account(spl_token_2022_program::ID, account_data),
    )];

    let result = run(
        &mollusk,
        &demo_ix(
            ROUTE_ACCOUNT,
            EXT_TRANSFER_FEE_AMOUNT,
            &expected,
            Some((account_key, false, false)),
        ),
        &accounts,
    );
    assert_success(&result);
    assert_account_unchanged(&accounts, &result.resulting_accounts, &account_key);
}

#[test]
fn token_2022_demo_covers_representative_positive_extension_matrix() {
    let mollusk = fresh_mollusk();

    let mint_key = Pubkey::new_unique();
    let mint_optional_pubkey = (0..32)
        .map(|i| 0x80u8.wrapping_add(i as u8))
        .collect::<Vec<_>>();
    let mint_records = vec![
        (EXT_UNKNOWN_BEFORE, vec![0xAA, 0xBB]),
        (EXT_DEFAULT_ACCOUNT_STATE, vec![2u8]),
        (EXT_UNKNOWN_BETWEEN, vec![0xCC]),
        (EXT_MINT_CLOSE_AUTHORITY, mint_optional_pubkey.clone()),
        (EXT_NON_TRANSFERABLE, vec![]),
        (EXT_UNKNOWN_AFTER, vec![0xDD, 0xEE, 0xFF]),
    ];
    let mint_accounts = vec![(
        mint_key,
        readonly_data_account(spl_token_2022_program::ID, mint_with_extensions(&mint_records)),
    )];

    let mint_optional = run(
        &mollusk,
        &demo_ix(
            ROUTE_MINT,
            EXT_MINT_CLOSE_AUTHORITY,
            &mint_optional_pubkey,
            Some((mint_key, false, false)),
        ),
        &mint_accounts,
    );
    assert_success(&mint_optional);
    assert_account_unchanged(&mint_accounts, &mint_optional.resulting_accounts, &mint_key);

    let mint_marker = run(
        &mollusk,
        &demo_ix(
            ROUTE_MINT,
            EXT_NON_TRANSFERABLE,
            &[],
            Some((mint_key, false, false)),
        ),
        &mint_accounts,
    );
    assert_success(&mint_marker);
    assert_account_unchanged(&mint_accounts, &mint_marker.resulting_accounts, &mint_key);

    let account_key = Pubkey::new_unique();
    let account_numeric = 0x0123_4567_89AB_CDEFu64.to_le_bytes().to_vec();
    let account_records = vec![
        (EXT_UNKNOWN_BEFORE, vec![0x10]),
        (EXT_IMMUTABLE_OWNER, vec![]),
        (EXT_UNKNOWN_BETWEEN, vec![0x20, 0x21]),
        (EXT_TRANSFER_FEE_AMOUNT, account_numeric.clone()),
        (EXT_UNKNOWN_AFTER, vec![0x30]),
    ];
    let account_accounts = vec![(
        account_key,
        readonly_data_account(
            spl_token_2022_program::ID,
            account_with_extensions(&account_records),
        ),
    )];

    let account_numeric_result = run(
        &mollusk,
        &demo_ix(
            ROUTE_ACCOUNT,
            EXT_TRANSFER_FEE_AMOUNT,
            &account_numeric,
            Some((account_key, false, false)),
        ),
        &account_accounts,
    );
    assert_success(&account_numeric_result);
    assert_account_unchanged(
        &account_accounts,
        &account_numeric_result.resulting_accounts,
        &account_key,
    );
}

#[test]
fn token_2022_demo_maps_representative_failures_to_documented_categories() {
    let mollusk = fresh_mollusk();
    let account_key = Pubkey::new_unique();
    let mint_payload = vec![2u8];
    let mint_account = readonly_data_account(
        spl_token_2022_program::ID,
        mint_with_extensions(&[(EXT_DEFAULT_ACCOUNT_STATE, mint_payload.clone())]),
    );

    let base_accounts = vec![(account_key, mint_account.clone())];

    let mismatch = run(
        &mollusk,
        &demo_ix(
            ROUTE_MINT,
            EXT_DEFAULT_ACCOUNT_STATE,
            &[0xFF],
            Some((account_key, false, false)),
        ),
        &base_accounts,
    );
    assert_custom_failure(&mismatch, DemoFailure::InvalidInstructionData);
    assert_account_unchanged(&base_accounts, &mismatch.resulting_accounts, &account_key);

    let wrong_owner_accounts = vec![(
        account_key,
        readonly_data_account(spl_token_program::ID, mint_with_extensions(&[(EXT_DEFAULT_ACCOUNT_STATE, mint_payload.clone())])),
    )];
    let wrong_owner = run(
        &mollusk,
        &demo_ix(
            ROUTE_MINT,
            EXT_DEFAULT_ACCOUNT_STATE,
            &mint_payload,
            Some((account_key, false, false)),
        ),
        &wrong_owner_accounts,
    );
    assert_custom_failure(&wrong_owner, DemoFailure::IncorrectProgramId);

    let wrong_kind_payload = 0x0102_0304_0506_0708u64.to_le_bytes().to_vec();
    let wrong_kind_accounts = vec![(
        account_key,
        readonly_data_account(
            spl_token_2022_program::ID,
            account_with_extensions(&[(EXT_TRANSFER_FEE_AMOUNT, wrong_kind_payload.clone())]),
        ),
    )];
    let wrong_kind = run(
        &mollusk,
        &demo_ix(
            ROUTE_MINT,
            EXT_TRANSFER_FEE_AMOUNT,
            &wrong_kind_payload,
            Some((account_key, false, false)),
        ),
        &wrong_kind_accounts,
    );
    assert_custom_failure(&wrong_kind, DemoFailure::WrongAccountType);

    let invalid_length_accounts = vec![(
        account_key,
        readonly_data_account(
            spl_token_2022_program::ID,
            mint_with_extensions(&[(EXT_DEFAULT_ACCOUNT_STATE, vec![7u8; 2])]),
        ),
    )];
    let invalid_length = run(
        &mollusk,
        &demo_ix(
            ROUTE_MINT,
            EXT_DEFAULT_ACCOUNT_STATE,
            &[7u8; 2],
            Some((account_key, false, false)),
        ),
        &invalid_length_accounts,
    );
    assert_custom_failure(&invalid_length, DemoFailure::InvalidExtensionLength);

    let mut malformed_data = vec![0u8; MINT_BASE_LEN];
    malformed_data.resize(TLV_START_OFFSET, 0);
    malformed_data[ACCOUNT_TYPE_OFFSET] = 1;
    malformed_data.extend_from_slice(&EXT_DEFAULT_ACCOUNT_STATE.to_le_bytes());
    malformed_data.extend_from_slice(&(1u16).to_le_bytes());
    malformed_data.extend_from_slice(&[1u8; 4]);
    let malformed_accounts = vec![(
        account_key,
        readonly_data_account(spl_token_2022_program::ID, malformed_data),
    )];
    let malformed = run(
        &mollusk,
        &demo_ix(
            ROUTE_MINT,
            EXT_DEFAULT_ACCOUNT_STATE,
            &[1u8],
            Some((account_key, false, false)),
        ),
        &malformed_accounts,
    );
    assert_custom_failure(&malformed, DemoFailure::InvalidAccountData);

    let unsupported_accounts = vec![(
        account_key,
        readonly_data_account(
            spl_token_2022_program::ID,
            mint_with_extensions(&[(EXT_TOKEN_METADATA, vec![9u8; 3]), (EXT_DEFAULT_ACCOUNT_STATE, mint_payload.clone())]),
        ),
    )];
    let unsupported = run(
        &mollusk,
        &demo_ix(
            ROUTE_MINT,
            EXT_TOKEN_METADATA,
            &[9u8; 3],
            Some((account_key, false, false)),
        ),
        &unsupported_accounts,
    );
    assert_custom_failure(&unsupported, DemoFailure::UnsupportedExtension);

    let missing_account = run(
        &mollusk,
        &demo_ix(ROUTE_MINT, EXT_DEFAULT_ACCOUNT_STATE, &mint_payload, None),
        &[],
    );
    assert_custom_failure(&missing_account, DemoFailure::InvalidAccountList);

    let writable_account = run(
        &mollusk,
        &demo_ix(
            ROUTE_MINT,
            EXT_DEFAULT_ACCOUNT_STATE,
            &mint_payload,
            Some((account_key, false, true)),
        ),
        &base_accounts,
    );
    assert_custom_failure(&writable_account, DemoFailure::InvalidAccountList);

    let unknown_route = run(
        &mollusk,
        &demo_ix(
            9,
            EXT_DEFAULT_ACCOUNT_STATE,
            &mint_payload,
            Some((account_key, false, false)),
        ),
        &base_accounts,
    );
    assert_custom_failure(&unknown_route, DemoFailure::InvalidInstructionData);
}

#[test]
fn token_2022_demo_rejects_representative_wrong_kind_and_length_cases() {
    let mollusk = fresh_mollusk();

    let wrong_kind_account_key = Pubkey::new_unique();
    let wrong_kind_account_payload = 0x0102_0304_0506_0708u64.to_le_bytes().to_vec();
    let wrong_kind_account_accounts = vec![(
        wrong_kind_account_key,
        readonly_data_account(
            spl_token_2022_program::ID,
            account_with_extensions(&[(EXT_TRANSFER_FEE_AMOUNT, wrong_kind_account_payload.clone())]),
        ),
    )];
    let wrong_kind_account = run(
        &mollusk,
        &demo_ix(
            ROUTE_MINT,
            EXT_TRANSFER_FEE_AMOUNT,
            &wrong_kind_account_payload,
            Some((wrong_kind_account_key, false, false)),
        ),
        &wrong_kind_account_accounts,
    );
    assert_custom_failure(&wrong_kind_account, DemoFailure::WrongAccountType);
    assert_account_unchanged(
        &wrong_kind_account_accounts,
        &wrong_kind_account.resulting_accounts,
        &wrong_kind_account_key,
    );

    let wrong_kind_mint_key = Pubkey::new_unique();
    let wrong_kind_mint_payload = (0..32)
        .map(|i| 0x40u8.wrapping_add(i as u8))
        .collect::<Vec<_>>();
    let wrong_kind_mint_accounts = vec![(
        wrong_kind_mint_key,
        readonly_data_account(
            spl_token_2022_program::ID,
            mint_with_extensions(&[(EXT_MINT_CLOSE_AUTHORITY, wrong_kind_mint_payload.clone())]),
        ),
    )];
    let wrong_kind_mint = run(
        &mollusk,
        &demo_ix(
            ROUTE_ACCOUNT,
            EXT_MINT_CLOSE_AUTHORITY,
            &wrong_kind_mint_payload,
            Some((wrong_kind_mint_key, false, false)),
        ),
        &wrong_kind_mint_accounts,
    );
    assert_custom_failure(&wrong_kind_mint, DemoFailure::WrongAccountType);
    assert_account_unchanged(
        &wrong_kind_mint_accounts,
        &wrong_kind_mint.resulting_accounts,
        &wrong_kind_mint_key,
    );

    let wrong_len_optional_key = Pubkey::new_unique();
    let wrong_len_optional_payload = vec![0x55; 31];
    let wrong_len_optional_accounts = vec![(
        wrong_len_optional_key,
        readonly_data_account(
            spl_token_2022_program::ID,
            mint_with_extensions(&[(EXT_MINT_CLOSE_AUTHORITY, wrong_len_optional_payload.clone())]),
        ),
    )];
    let wrong_len_optional = run(
        &mollusk,
        &demo_ix(
            ROUTE_MINT,
            EXT_MINT_CLOSE_AUTHORITY,
            &wrong_len_optional_payload,
            Some((wrong_len_optional_key, false, false)),
        ),
        &wrong_len_optional_accounts,
    );
    assert_custom_failure(&wrong_len_optional, DemoFailure::InvalidExtensionLength);
    assert_account_unchanged(
        &wrong_len_optional_accounts,
        &wrong_len_optional.resulting_accounts,
        &wrong_len_optional_key,
    );

    let wrong_len_marker_key = Pubkey::new_unique();
    let wrong_len_marker_payload = vec![1u8];
    let wrong_len_marker_accounts = vec![(
        wrong_len_marker_key,
        readonly_data_account(
            spl_token_2022_program::ID,
            mint_with_extensions(&[(EXT_NON_TRANSFERABLE, wrong_len_marker_payload.clone())]),
        ),
    )];
    let wrong_len_marker = run(
        &mollusk,
        &demo_ix(
            ROUTE_MINT,
            EXT_NON_TRANSFERABLE,
            &wrong_len_marker_payload,
            Some((wrong_len_marker_key, false, false)),
        ),
        &wrong_len_marker_accounts,
    );
    assert_custom_failure(&wrong_len_marker, DemoFailure::InvalidExtensionLength);
    assert_account_unchanged(
        &wrong_len_marker_accounts,
        &wrong_len_marker.resulting_accounts,
        &wrong_len_marker_key,
    );

    let wrong_len_numeric_key = Pubkey::new_unique();
    let wrong_len_numeric_payload = vec![0x77; 7];
    let wrong_len_numeric_accounts = vec![(
        wrong_len_numeric_key,
        readonly_data_account(
            spl_token_2022_program::ID,
            account_with_extensions(&[(EXT_TRANSFER_FEE_AMOUNT, wrong_len_numeric_payload.clone())]),
        ),
    )];
    let wrong_len_numeric = run(
        &mollusk,
        &demo_ix(
            ROUTE_ACCOUNT,
            EXT_TRANSFER_FEE_AMOUNT,
            &wrong_len_numeric_payload,
            Some((wrong_len_numeric_key, false, false)),
        ),
        &wrong_len_numeric_accounts,
    );
    assert_custom_failure(&wrong_len_numeric, DemoFailure::InvalidExtensionLength);
    assert_account_unchanged(
        &wrong_len_numeric_accounts,
        &wrong_len_numeric.resulting_accounts,
        &wrong_len_numeric_key,
    );
}

#[test]
fn token_2022_demo_reports_extension_not_found_separately() {
    let mollusk = fresh_mollusk();
    let account_key = Pubkey::new_unique();
    let account_data = mint_with_extensions(&[]);
    let accounts = vec![(
        account_key,
        readonly_data_account(spl_token_2022_program::ID, account_data),
    )];

    let result = run(
        &mollusk,
        &demo_ix(
            ROUTE_MINT,
            EXT_DEFAULT_ACCOUNT_STATE,
            &[0u8; 1],
            Some((account_key, false, false)),
        ),
        &accounts,
    );
    assert_custom_failure(&result, DemoFailure::ExtensionNotFound);
    assert_account_unchanged(&accounts, &result.resulting_accounts, &account_key);
}
