//! Integration tests for the mock transfer-hook demo artifact.

use {
    mollusk_svm::Mollusk,
    solana_account::Account,
    solana_instruction::{error::InstructionError, AccountMeta, Instruction},
    solana_program_error::ProgramError,
    solana_pubkey::Pubkey,
    solana_sdk_ids::{bpf_loader_upgradeable, system_program},
    std::path::{Path, PathBuf},
};

mod hook_program {
    solana_pubkey::declare_id!("5WT5Q8fv8A2dXPmiqP4rBVd3AujJFMadG7eP4c3RVK11");
}

const EXECUTE_DISCRIMINATOR: [u8; 8] = [105, 37, 101, 197, 75, 251, 102, 26];
const EXTRA_ACCOUNT_META_LEN: usize = 35;

fn program_test_dir() -> &'static Path {
    Path::new(env!("CARGO_MANIFEST_DIR"))
}

fn artifact_load_path(name: &str) -> String {
    program_test_dir()
        .join("zig-out")
        .join("lib")
        .join(name)
        .display()
        .to_string()
}

fn artifact_file_path(name: &str) -> PathBuf {
    program_test_dir()
        .join("zig-out")
        .join("lib")
        .join(format!("{name}.so"))
}

fn regular_account() -> Account {
    Account {
        lamports: 1_000_000,
        data: vec![],
        owner: system_program::id(),
        executable: false,
        rent_epoch: 0,
    }
}

fn owned_account(owner: Pubkey, data: Vec<u8>) -> Account {
    Account {
        lamports: 1_000_000,
        data,
        owner,
        executable: false,
        rent_epoch: 0,
    }
}

fn setup() -> Mollusk {
    let artifact_file = artifact_file_path("example_mock_transfer_hook");
    assert!(
        artifact_file.exists(),
        "transfer-hook artifact missing at {}",
        artifact_file.display(),
    );

    let mut mollusk = Mollusk::default();
    mollusk.add_program(
        &hook_program::id(),
        &artifact_load_path("example_mock_transfer_hook"),
        &bpf_loader_upgradeable::id(),
    );
    mollusk
}

fn execute_data(amount: u64) -> Vec<u8> {
    let mut data = Vec::with_capacity(16);
    data.extend_from_slice(&EXECUTE_DISCRIMINATOR);
    data.extend_from_slice(&amount.to_le_bytes());
    data
}

fn fixed_extra_meta(pubkey: &Pubkey, is_signer: bool, is_writable: bool) -> [u8; EXTRA_ACCOUNT_META_LEN] {
    let mut record = [0u8; EXTRA_ACCOUNT_META_LEN];
    record[0] = 0;
    record[1..33].copy_from_slice(pubkey.as_ref());
    record[33] = u8::from(is_signer);
    record[34] = u8::from(is_writable);
    record
}

fn validation_state_data(records: &[[u8; EXTRA_ACCOUNT_META_LEN]]) -> Vec<u8> {
    let records_len = records.len() * EXTRA_ACCOUNT_META_LEN;
    let value_len = 4 + records_len;
    let mut data = Vec::with_capacity(8 + 4 + value_len);
    data.extend_from_slice(&EXECUTE_DISCRIMINATOR);
    data.extend_from_slice(&(value_len as u32).to_le_bytes());
    data.extend_from_slice(&(records.len() as u32).to_le_bytes());
    for record in records {
        data.extend_from_slice(record);
    }
    data
}

#[derive(Clone)]
struct ExecuteFixture {
    source: Pubkey,
    mint: Pubkey,
    destination: Pubkey,
    authority: Pubkey,
    validation: Pubkey,
    signer_extra: Pubkey,
    writable_extra: Pubkey,
    validation_data: Vec<u8>,
}

impl ExecuteFixture {
    fn new() -> Self {
        let source = Pubkey::new_from_array([0x10; 32]);
        let mint = Pubkey::new_from_array([0x20; 32]);
        let destination = Pubkey::new_from_array([0x30; 32]);
        let authority = Pubkey::new_from_array([0x40; 32]);
        let signer_extra = Pubkey::new_from_array([0x50; 32]);
        let writable_extra = Pubkey::new_from_array([0x60; 32]);
        let validation = Pubkey::find_program_address(
            &[b"extra-account-metas", mint.as_ref()],
            &hook_program::id(),
        )
        .0;
        let validation_data = validation_state_data(&[
            fixed_extra_meta(&signer_extra, true, false),
            fixed_extra_meta(&writable_extra, false, true),
        ]);
        Self {
            source,
            mint,
            destination,
            authority,
            validation,
            signer_extra,
            writable_extra,
            validation_data,
        }
    }

    fn instruction(&self, data: Vec<u8>, extras: Vec<AccountMeta>) -> Instruction {
        let mut accounts = vec![
            AccountMeta::new_readonly(self.source, false),
            AccountMeta::new_readonly(self.mint, false),
            AccountMeta::new_readonly(self.destination, false),
            AccountMeta::new_readonly(self.authority, false),
            AccountMeta::new_readonly(self.validation, false),
        ];
        accounts.extend(extras);
        Instruction {
            program_id: hook_program::id(),
            accounts,
            data,
        }
    }

    fn success_instruction(&self, amount: u64) -> Instruction {
        self.instruction(
            execute_data(amount),
            vec![
                AccountMeta::new_readonly(self.signer_extra, true),
                AccountMeta::new(self.writable_extra, false),
            ],
        )
    }

    fn baseline_accounts(&self) -> Vec<(Pubkey, Account)> {
        vec![
            (self.source, regular_account()),
            (self.mint, regular_account()),
            (self.destination, regular_account()),
            (self.authority, regular_account()),
            (
                self.validation,
                owned_account(hook_program::id(), self.validation_data.clone()),
            ),
            (self.signer_extra, regular_account()),
            (self.writable_extra, regular_account()),
        ]
    }
}

fn assert_program_error(
    result: &mollusk_svm::result::InstructionResult,
    expected: ProgramError,
    label: &str,
) {
    match result.program_result {
        mollusk_svm::result::ProgramResult::Failure(ref err) => {
            assert_eq!(err, &expected, "{label}: expected {expected:?}, got {err:?}");
        }
        ref other => panic!("{label}: expected ProgramError failure, got {other:?}"),
    }
    assert!(
        result.return_data.is_empty(),
        "{label}: failure must not return data",
    );
}

fn assert_malformed_execute_failure(
    result: &mollusk_svm::result::InstructionResult,
    label: &str,
) {
    match result.program_result {
        mollusk_svm::result::ProgramResult::Failure(ref err) => {
            assert_eq!(
                err,
                &ProgramError::InvalidInstructionData,
                "{label}: expected InvalidInstructionData, got {err:?}",
            );
        }
        mollusk_svm::result::ProgramResult::UnknownError(ref err) => {
            assert_eq!(
                err,
                &InstructionError::UnsupportedProgramId,
                "{label}: malformed execute should use the documented stable Mollusk translation",
            );
        }
        ref other => panic!("{label}: malformed execute should fail, got {other:?}"),
    }
    assert!(
        result.return_data.is_empty(),
        "{label}: malformed execute failure must not return data",
    );
}

#[test]
fn mock_transfer_hook_accepts_canonical_execute() {
    let mollusk = setup();
    let fixture = ExecuteFixture::new();

    let result = mollusk.process_instruction(
        &fixture.success_instruction(111_111_111),
        &fixture.baseline_accounts(),
    );

    assert!(
        result.program_result.is_ok(),
        "canonical execute failed: {:?}",
        result.program_result,
    );
    assert!(
        result.compute_units_consumed > 0,
        "canonical execute should consume non-zero CU",
    );
    assert!(
        result.return_data.is_empty(),
        "mock transfer-hook success should not emit return data",
    );
}

#[test]
fn mock_transfer_hook_rejects_bad_discriminator() {
    let mollusk = setup();
    let fixture = ExecuteFixture::new();
    let mut data = execute_data(7);
    data[0] ^= 0xff;

    let result = mollusk.process_instruction(
        &fixture.instruction(
            data,
            vec![
                AccountMeta::new_readonly(fixture.signer_extra, true),
                AccountMeta::new(fixture.writable_extra, false),
            ],
        ),
        &fixture.baseline_accounts(),
    );
    assert_malformed_execute_failure(&result, "bad discriminator");
}

#[test]
fn mock_transfer_hook_rejects_short_execute_data() {
    let mollusk = setup();
    let fixture = ExecuteFixture::new();

    let result = mollusk.process_instruction(
        &fixture.instruction(EXECUTE_DISCRIMINATOR[..7].to_vec(), vec![]),
        &fixture.baseline_accounts(),
    );
    assert_malformed_execute_failure(&result, "short execute data");
}

#[test]
fn mock_transfer_hook_rejects_overlong_execute_data() {
    let mollusk = setup();
    let fixture = ExecuteFixture::new();
    let mut data = execute_data(9);
    data.push(0xff);

    let result = mollusk.process_instruction(
        &fixture.instruction(
            data,
            vec![
                AccountMeta::new_readonly(fixture.signer_extra, true),
                AccountMeta::new(fixture.writable_extra, false),
            ],
        ),
        &fixture.baseline_accounts(),
    );
    assert_malformed_execute_failure(&result, "overlong execute data");
}

#[test]
fn mock_transfer_hook_rejects_missing_accounts() {
    let mollusk = setup();
    let fixture = ExecuteFixture::new();
    let mut accounts = fixture.baseline_accounts();
    accounts.truncate(4);

    let instruction = Instruction {
        program_id: hook_program::id(),
        accounts: vec![
            AccountMeta::new_readonly(fixture.source, false),
            AccountMeta::new_readonly(fixture.mint, false),
            AccountMeta::new_readonly(fixture.destination, false),
            AccountMeta::new_readonly(fixture.authority, false),
        ],
        data: execute_data(5),
    };

    let result = mollusk.process_instruction(&instruction, &accounts);
    assert_program_error(&result, ProgramError::NotEnoughAccountKeys, "missing accounts");
}

#[test]
fn mock_transfer_hook_rejects_spoofed_validation_pda() {
    let mollusk = setup();
    let fixture = ExecuteFixture::new();
    let spoofed_validation = Pubkey::new_from_array([0x77; 32]);
    let mut accounts = fixture.baseline_accounts();
    accounts[4] = (
        spoofed_validation,
        owned_account(hook_program::id(), fixture.validation_data.clone()),
    );

    let instruction = Instruction {
        program_id: hook_program::id(),
        accounts: vec![
            AccountMeta::new_readonly(fixture.source, false),
            AccountMeta::new_readonly(fixture.mint, false),
            AccountMeta::new_readonly(fixture.destination, false),
            AccountMeta::new_readonly(fixture.authority, false),
            AccountMeta::new_readonly(spoofed_validation, false),
            AccountMeta::new_readonly(fixture.signer_extra, true),
            AccountMeta::new(fixture.writable_extra, false),
        ],
        data: execute_data(12),
    };

    let result = mollusk.process_instruction(&instruction, &accounts);
    assert_program_error(&result, ProgramError::InvalidArgument, "spoofed validation pda");
}

#[test]
fn mock_transfer_hook_rejects_duplicate_disallowed_extra_accounts() {
    let mollusk = setup();
    let fixture = ExecuteFixture::new();

    let instruction = fixture.instruction(
        execute_data(13),
        vec![
            AccountMeta::new_readonly(fixture.signer_extra, true),
            AccountMeta::new_readonly(fixture.signer_extra, true),
        ],
    );

    let result = mollusk.process_instruction(&instruction, &fixture.baseline_accounts());
    assert_program_error(
        &result,
        ProgramError::InvalidArgument,
        "duplicate disallowed extra accounts",
    );
}

#[test]
fn mock_transfer_hook_rejects_signer_escalation() {
    let mollusk = setup();
    let fixture = ExecuteFixture::new();

    let instruction = fixture.instruction(
        execute_data(14),
        vec![
            AccountMeta::new_readonly(fixture.signer_extra, false),
            AccountMeta::new(fixture.writable_extra, false),
        ],
    );

    let result = mollusk.process_instruction(&instruction, &fixture.baseline_accounts());
    assert_program_error(
        &result,
        ProgramError::MissingRequiredSignature,
        "signer escalation",
    );
}

#[test]
fn mock_transfer_hook_rejects_writable_escalation() {
    let mollusk = setup();
    let fixture = ExecuteFixture::new();

    let instruction = fixture.instruction(
        execute_data(15),
        vec![
            AccountMeta::new_readonly(fixture.signer_extra, true),
            AccountMeta::new_readonly(fixture.writable_extra, false),
        ],
    );

    let result = mollusk.process_instruction(&instruction, &fixture.baseline_accounts());
    assert_program_error(&result, ProgramError::Immutable, "writable escalation");
}
