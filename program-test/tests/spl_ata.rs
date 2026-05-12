//! Integration tests for the `spl-ata` sub-package.
//!
//! These tests exercise the Zig CPI demo against the real
//! Associated Token Account program plus the real classic SPL Token
//! and Token-2022 programs shipped by
//! `mollusk-svm-programs-token`.

use {
    mollusk_svm::{
        program::keyed_account_for_system_program, result::ProgramResult, Mollusk,
    },
    mollusk_svm_programs_token::{
        associated_token as spl_associated_token_program,
        token as spl_token_program, token2022 as spl_token_2022_program,
    },
    solana_account::Account,
    solana_instruction::{AccountMeta, Instruction},
    solana_program_option::COption,
    solana_program_pack::Pack,
    solana_pubkey::Pubkey,
    solana_sdk_ids::{bpf_loader_upgradeable, system_program},
    spl_token_interface::state::{
        Account as TokenAccount, AccountState as TokenState, Mint,
    },
};

mod program {
    solana_pubkey::declare_id!("Zigc1Hc97L8Pebma74jDzYiyoUvdxxcj7Gxppg9VRxK");
}

const TAG_CREATE: u8 = 0;
const TAG_CREATE_IDEMPOTENT: u8 = 1;
const PAYER_LAMPORTS: u64 = 10_000_000;
const DECIMALS: u8 = 6;

#[derive(Clone, Copy)]
enum TokenFlavor {
    Classic,
    Token2022,
}

struct Scenario {
    payer: Pubkey,
    wallet: Pubkey,
    mint: Pubkey,
    associated_token: Pubkey,
    classic_associated_token: Pubkey,
    token_2022_associated_token: Pubkey,
    system_program: Pubkey,
    token_program: Pubkey,
    associated_token_program: Pubkey,
}

fn fresh_mollusk() -> Mollusk {
    let mut mollusk = Mollusk::default();
    mollusk.add_program(
        &program::id(),
        "zig-out/lib/example_spl_ata_cpi",
        &bpf_loader_upgradeable::id(),
    );
    spl_associated_token_program::add_program(&mut mollusk);
    spl_token_program::add_program(&mut mollusk);
    spl_token_2022_program::add_program(&mut mollusk);
    mollusk
}

fn empty_system_account(lamports: u64) -> Account {
    Account {
        lamports,
        data: vec![],
        owner: system_program::id(),
        executable: false,
        rent_epoch: 0,
    }
}

fn mint_data(authority: Pubkey) -> Mint {
    Mint {
        mint_authority: COption::Some(authority),
        supply: 0,
        decimals: DECIMALS,
        is_initialized: true,
        freeze_authority: COption::None,
    }
}

fn associated_token_address(
    wallet: &Pubkey,
    mint: &Pubkey,
    token_program: &Pubkey,
) -> Pubkey {
    Pubkey::find_program_address(
        &[
            &wallet.to_bytes(),
            &token_program.to_bytes(),
            &mint.to_bytes(),
        ],
        &spl_associated_token_program::ID,
    )
    .0
}

fn classic_associated_token_address(wallet: &Pubkey, mint: &Pubkey) -> Pubkey {
    associated_token_address(wallet, mint, &spl_token_program::ID)
}

fn token_2022_associated_token_address(wallet: &Pubkey, mint: &Pubkey) -> Pubkey {
    associated_token_address(wallet, mint, &spl_token_2022_program::ID)
}

fn scenario(flavor: TokenFlavor) -> (Scenario, Vec<(Pubkey, Account)>) {
    let payer = Pubkey::new_unique();
    let wallet = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let classic_associated_token = classic_associated_token_address(&wallet, &mint);
    let token_2022_associated_token =
        token_2022_associated_token_address(&wallet, &mint);
    let associated_token = match flavor {
        TokenFlavor::Classic => classic_associated_token,
        TokenFlavor::Token2022 => token_2022_associated_token,
    };

    let (system_program_pid, system_program_account) =
        keyed_account_for_system_program();
    let (associated_token_program_pid, associated_token_program_account) =
        spl_associated_token_program::keyed_account();
    let (token_program_pid, token_program_account) = match flavor {
        TokenFlavor::Classic => spl_token_program::keyed_account(),
        TokenFlavor::Token2022 => spl_token_2022_program::keyed_account(),
    };

    let mint_account = match flavor {
        TokenFlavor::Classic => {
            spl_token_program::create_account_for_mint(mint_data(Pubkey::new_unique()))
        }
        TokenFlavor::Token2022 => spl_token_2022_program::create_account_for_mint(
            mint_data(Pubkey::new_unique()),
        ),
    };

    let accounts = vec![
        (payer, empty_system_account(PAYER_LAMPORTS)),
        (associated_token, empty_system_account(0)),
        (wallet, empty_system_account(0)),
        (mint, mint_account),
        (system_program_pid, system_program_account),
        (token_program_pid, token_program_account),
        (
            associated_token_program_pid,
            associated_token_program_account,
        ),
    ];

    (
        Scenario {
            payer,
            wallet,
            mint,
            associated_token,
            classic_associated_token,
            token_2022_associated_token,
            system_program: system_program_pid,
            token_program: token_program_pid,
            associated_token_program: associated_token_program_pid,
        },
        accounts,
    )
}

fn build_ix(s: &Scenario, tag: u8) -> Instruction {
    Instruction {
        program_id: program::id(),
        accounts: vec![
            AccountMeta::new(s.payer, true),
            AccountMeta::new(s.associated_token, false),
            AccountMeta::new_readonly(s.wallet, false),
            AccountMeta::new_readonly(s.mint, false),
            AccountMeta::new_readonly(s.system_program, false),
            AccountMeta::new_readonly(s.token_program, false),
            AccountMeta::new_readonly(s.associated_token_program, false),
        ],
        data: vec![tag],
    }
}

fn run(
    mollusk: &Mollusk,
    accounts: &[(Pubkey, Account)],
    ix: &Instruction,
) -> mollusk_svm::result::InstructionResult {
    mollusk.process_instruction(ix, accounts)
}

fn account<'a>(accounts: &'a [(Pubkey, Account)], key: &Pubkey) -> &'a Account {
    &accounts
        .iter()
        .find(|(candidate, _)| candidate == key)
        .unwrap_or_else(|| panic!("account {key} missing"))
        .1
}

fn assert_account_eq(actual: &Account, expected: &Account, context: &str) {
    assert_eq!(actual.lamports, expected.lamports, "{context}: lamports");
    assert_eq!(actual.data, expected.data, "{context}: data");
    assert_eq!(actual.owner, expected.owner, "{context}: owner");
    assert_eq!(
        actual.executable, expected.executable,
        "{context}: executable"
    );
    assert_eq!(
        actual.rent_epoch, expected.rent_epoch,
        "{context}: rent epoch"
    );
}

fn assert_initialized_token_account(
    account: &Account,
    owner_program: &Pubkey,
    wallet: &Pubkey,
    mint: &Pubkey,
) {
    assert_eq!(account.owner, *owner_program);
    assert!(account.lamports > 0, "created ATA should be rent-funded");
    assert_eq!(account.data.len(), TokenAccount::LEN);

    let unpacked = TokenAccount::unpack(&account.data).unwrap();
    assert_eq!(unpacked.state, TokenState::Initialized);
    assert_eq!(unpacked.mint, *mint);
    assert_eq!(unpacked.owner, *wallet);
    assert_eq!(unpacked.amount, 0);
}

#[test]
fn test_classic_create_initializes_real_spl_token_account() {
    let mollusk = fresh_mollusk();
    let (scenario, initial_accounts) = scenario(TokenFlavor::Classic);

    let result = run(&mollusk, &initial_accounts, &build_ix(&scenario, TAG_CREATE));
    assert!(
        matches!(result.program_result, ProgramResult::Success),
        "classic ATA create failed: {:?}",
        result.program_result,
    );
    println!("classic ATA create CU: {}", result.compute_units_consumed);

    let ata_account = account(&result.resulting_accounts, &scenario.associated_token);
    assert_initialized_token_account(
        ata_account,
        &spl_token_program::ID,
        &scenario.wallet,
        &scenario.mint,
    );
}

#[test]
fn test_classic_idempotent_create_succeeds_when_missing_and_when_present() {
    let mollusk = fresh_mollusk();
    let (scenario, initial_accounts) = scenario(TokenFlavor::Classic);
    let ix = build_ix(&scenario, TAG_CREATE_IDEMPOTENT);

    let first = run(&mollusk, &initial_accounts, &ix);
    assert!(
        matches!(first.program_result, ProgramResult::Success),
        "initial idempotent ATA create failed: {:?}",
        first.program_result,
    );
    println!(
        "classic ATA idempotent create (missing) CU: {}",
        first.compute_units_consumed,
    );

    let before_repeat =
        account(&first.resulting_accounts, &scenario.associated_token).clone();

    let second = run(&mollusk, &first.resulting_accounts, &ix);
    assert!(
        matches!(second.program_result, ProgramResult::Success),
        "repeat idempotent ATA create failed: {:?}",
        second.program_result,
    );
    println!(
        "classic ATA idempotent create (present) CU: {}",
        second.compute_units_consumed,
    );

    let after_repeat = account(&second.resulting_accounts, &scenario.associated_token);
    assert_initialized_token_account(
        after_repeat,
        &spl_token_program::ID,
        &scenario.wallet,
        &scenario.mint,
    );
    assert_account_eq(
        after_repeat,
        &before_repeat,
        "idempotent repeat should preserve ATA state",
    );
}

#[test]
fn test_classic_non_idempotent_create_fails_when_ata_already_exists() {
    let mollusk = fresh_mollusk();
    let (scenario, initial_accounts) = scenario(TokenFlavor::Classic);
    let create_ix = build_ix(&scenario, TAG_CREATE);

    let first = run(&mollusk, &initial_accounts, &create_ix);
    assert!(
        matches!(first.program_result, ProgramResult::Success),
        "initial ATA create failed: {:?}",
        first.program_result,
    );

    let before_retry =
        account(&first.resulting_accounts, &scenario.associated_token).clone();
    let second = run(&mollusk, &first.resulting_accounts, &create_ix);
    assert!(
        !matches!(second.program_result, ProgramResult::Success),
        "expected repeat non-idempotent ATA create to fail",
    );

    let after_retry = account(&second.resulting_accounts, &scenario.associated_token);
    assert_account_eq(
        after_retry,
        &before_retry,
        "non-idempotent retry should leave ATA unchanged",
    );
}

#[test]
fn test_token_2022_idempotent_create_uses_token_2022_address_and_owner() {
    let mollusk = fresh_mollusk();
    let (scenario, initial_accounts) = scenario(TokenFlavor::Token2022);
    let result = run(
        &mollusk,
        &initial_accounts,
        &build_ix(&scenario, TAG_CREATE_IDEMPOTENT),
    );

    assert!(
        matches!(result.program_result, ProgramResult::Success),
        "token-2022 ATA create failed: {:?}",
        result.program_result,
    );
    println!("token-2022 ATA create CU: {}", result.compute_units_consumed);

    assert_ne!(
        scenario.classic_associated_token, scenario.token_2022_associated_token,
        "classic and token-2022 ATA addresses must differ",
    );
    assert_eq!(scenario.associated_token, scenario.token_2022_associated_token);

    let ata_account = account(&result.resulting_accounts, &scenario.associated_token);
    assert_eq!(ata_account.owner, spl_token_2022_program::ID);
    assert!(
        ata_account.data.len() > TokenAccount::LEN,
        "token-2022 ATA should include extension bytes",
    );

    let unpacked =
        TokenAccount::unpack(&ata_account.data[..TokenAccount::LEN]).unwrap();
    assert_eq!(unpacked.state, TokenState::Initialized);
    assert_eq!(unpacked.mint, scenario.mint);
    assert_eq!(unpacked.owner, scenario.wallet);
    assert_eq!(unpacked.amount, 0);
}

#[test]
fn test_real_program_rejects_token_program_and_ata_address_mismatch() {
    let mollusk = fresh_mollusk();

    for token_flavor in [TokenFlavor::Classic, TokenFlavor::Token2022] {
        let (mut scenario, mut initial_accounts) = scenario(token_flavor);
        let wrong_key = match token_flavor {
            TokenFlavor::Classic => scenario.token_2022_associated_token,
            TokenFlavor::Token2022 => scenario.classic_associated_token,
        };
        scenario.associated_token = wrong_key;
        initial_accounts[1] = (wrong_key, empty_system_account(0));

        let before = account(&initial_accounts, &scenario.associated_token).clone();
        let result =
            run(&mollusk, &initial_accounts, &build_ix(&scenario, TAG_CREATE));

        assert!(
            !matches!(result.program_result, ProgramResult::Success),
            "expected mismatch for {:?} token program to fail",
            match token_flavor {
                TokenFlavor::Classic => "classic",
                TokenFlavor::Token2022 => "token-2022",
            },
        );

        let after = account(&result.resulting_accounts, &scenario.associated_token);
        assert_account_eq(
            after,
            &before,
            "mismatched ATA address should remain unchanged",
        );
    }
}
