//! Real SPL Token integration coverage for the Zig `spl_token` CPI demo.
//!
//! These tests load our Zig on-chain demo alongside the real SPL Token
//! program and validate the authority-heavy v0.2 flows end-to-end:
//! approve / approveChecked / revoke, SetAuthority variants, freeze /
//! thaw, PDA-signed wrappers, and route guard failures.

use {
    mollusk_svm::{result::ProgramResult, Mollusk},
    mollusk_svm_programs_token::token as spl_token_program,
    solana_account::Account,
    solana_instruction::{AccountMeta, Instruction},
    solana_program_error::ProgramError as SolanaProgramError,
    solana_program_option::COption,
    solana_program_pack::Pack,
    solana_pubkey::Pubkey,
    solana_sdk_ids::{bpf_loader_upgradeable, system_program},
    spl_token_interface::{
        instruction::AuthorityType,
        state::{
            Account as TokenAccount, AccountState as TokenState, Mint, Multisig as TokenMultisig,
        },
    },
};

mod program {
    solana_pubkey::declare_id!("Zigc1Hc97L8Pebma74jDzYiyoUvdxxcj7Gxppg9VRxK");
}

const DECIMALS: u8 = 6;
const MINT_AMOUNT: u64 = 1_000;
const TRANSFER_AMOUNT: u64 = 250;
const BURN_AMOUNT: u64 = 100;
const APPROVE_AMOUNT: u64 = 200;
const APPROVE_SPEND_AMOUNT: u64 = 75;
const APPROVE_CHECKED_AMOUNT: u64 = 90;
const APPROVE_CHECKED_SPEND_AMOUNT: u64 = 40;
const PDA_APPROVE_AMOUNT: u64 = 55;
const FROZEN_TRANSFER_AMOUNT: u64 = 25;

fn fresh_mollusk() -> Mollusk {
    let mut mollusk = Mollusk::default();
    mollusk.add_program(
        &program::id(),
        "zig-out/lib/example_spl_token_cpi",
        &bpf_loader_upgradeable::id(),
    );
    spl_token_program::add_program(&mut mollusk);
    mollusk
}

fn coption(pubkey: Option<Pubkey>) -> COption<Pubkey> {
    match pubkey {
        Some(pubkey) => COption::Some(pubkey),
        None => COption::None,
    }
}

fn plain_account(lamports: u64, owner: Pubkey) -> Account {
    Account {
        lamports,
        data: vec![],
        owner,
        executable: false,
        rent_epoch: 0,
    }
}

fn system_account(lamports: u64) -> Account {
    plain_account(lamports, system_program::id())
}

fn mint_account(mint_authority: Option<Pubkey>, freeze_authority: Option<Pubkey>) -> Account {
    spl_token_program::create_account_for_mint(Mint {
        mint_authority: coption(mint_authority),
        supply: 0,
        decimals: DECIMALS,
        is_initialized: true,
        freeze_authority: coption(freeze_authority),
    })
}

fn multisig_account() -> Account {
    Account {
        lamports: 10_000_000,
        data: vec![0; TokenMultisig::LEN],
        owner: spl_token_program::ID,
        executable: false,
        rent_epoch: 0,
    }
}

fn token_account(
    mint: &Pubkey,
    owner: &Pubkey,
    amount: u64,
    delegate: Option<Pubkey>,
    delegated_amount: u64,
    state: TokenState,
    close_authority: Option<Pubkey>,
) -> Account {
    spl_token_program::create_account_for_token_account(TokenAccount {
        mint: *mint,
        owner: *owner,
        amount,
        delegate: coption(delegate),
        state,
        is_native: COption::None,
        delegated_amount,
        close_authority: coption(close_authority),
    })
}

fn build_demo_ix(accounts: Vec<AccountMeta>, data: Vec<u8>) -> Instruction {
    Instruction {
        program_id: program::id(),
        accounts,
        data,
    }
}

fn build_legacy_ix(
    mint: &Pubkey,
    source: &Pubkey,
    destination: &Pubkey,
    authority: &Pubkey,
    authority_signer: bool,
    data: Vec<u8>,
) -> Instruction {
    build_demo_ix(
        vec![
            AccountMeta::new_readonly(spl_token_program::ID, false),
            AccountMeta::new(*mint, false),
            AccountMeta::new(*source, false),
            AccountMeta::new(*destination, false),
            AccountMeta::new_readonly(*authority, authority_signer),
        ],
        data,
    )
}

fn build_approve_ix(
    source: &Pubkey,
    delegate: &Pubkey,
    owner: &Pubkey,
    owner_signer: bool,
    data: Vec<u8>,
) -> Instruction {
    build_demo_ix(
        vec![
            AccountMeta::new_readonly(spl_token_program::ID, false),
            AccountMeta::new(*source, false),
            AccountMeta::new_readonly(*delegate, false),
            AccountMeta::new_readonly(*owner, owner_signer),
        ],
        data,
    )
}

fn build_approve_checked_ix(
    source: &Pubkey,
    mint: &Pubkey,
    delegate: &Pubkey,
    owner: &Pubkey,
    owner_signer: bool,
    data: Vec<u8>,
) -> Instruction {
    build_demo_ix(
        vec![
            AccountMeta::new_readonly(spl_token_program::ID, false),
            AccountMeta::new(*source, false),
            AccountMeta::new_readonly(*mint, false),
            AccountMeta::new_readonly(*delegate, false),
            AccountMeta::new_readonly(*owner, owner_signer),
        ],
        data,
    )
}

fn build_revoke_ix(
    source: &Pubkey,
    owner: &Pubkey,
    owner_signer: bool,
    data: Vec<u8>,
) -> Instruction {
    build_demo_ix(
        vec![
            AccountMeta::new_readonly(spl_token_program::ID, false),
            AccountMeta::new(*source, false),
            AccountMeta::new_readonly(*owner, owner_signer),
        ],
        data,
    )
}

fn build_set_authority_ix(
    target: &Pubkey,
    current_authority: &Pubkey,
    authority_signer: bool,
    data: Vec<u8>,
) -> Instruction {
    build_demo_ix(
        vec![
            AccountMeta::new_readonly(spl_token_program::ID, false),
            AccountMeta::new(*target, false),
            AccountMeta::new_readonly(*current_authority, authority_signer),
        ],
        data,
    )
}

fn build_freeze_thaw_ix(
    account: &Pubkey,
    mint: &Pubkey,
    authority: &Pubkey,
    authority_signer: bool,
    data: Vec<u8>,
) -> Instruction {
    build_demo_ix(
        vec![
            AccountMeta::new_readonly(spl_token_program::ID, false),
            AccountMeta::new(*account, false),
            AccountMeta::new_readonly(*mint, false),
            AccountMeta::new_readonly(*authority, authority_signer),
        ],
        data,
    )
}

fn build_initialize_multisig2_ix(
    multisig: &Pubkey,
    signer_pubkeys: &[Pubkey],
    threshold: u8,
) -> Instruction {
    let mut accounts = vec![
        AccountMeta::new_readonly(spl_token_program::ID, false),
        AccountMeta::new(*multisig, false),
    ];
    accounts.extend(
        signer_pubkeys
            .iter()
            .map(|pubkey| AccountMeta::new_readonly(*pubkey, false)),
    );
    build_demo_ix(accounts, vec![16u8, threshold])
}

fn build_approve_multisig_ix(
    source: &Pubkey,
    delegate: &Pubkey,
    multisig_authority: &Pubkey,
    signer_pubkeys: &[Pubkey],
    data: Vec<u8>,
) -> Instruction {
    let mut accounts = vec![
        AccountMeta::new_readonly(spl_token_program::ID, false),
        AccountMeta::new(*source, false),
        AccountMeta::new_readonly(*delegate, false),
        AccountMeta::new_readonly(*multisig_authority, false),
    ];
    accounts.extend(
        signer_pubkeys
            .iter()
            .map(|pubkey| AccountMeta::new_readonly(*pubkey, true)),
    );
    build_demo_ix(accounts, data)
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
        .find(|(k, _)| k == key)
        .unwrap_or_else(|| panic!("account {key} not in result"))
        .1
}

fn unpack_token(accounts: &[(Pubkey, Account)], key: &Pubkey) -> TokenAccount {
    TokenAccount::unpack(&account(accounts, key).data).unwrap()
}

fn unpack_mint(accounts: &[(Pubkey, Account)], key: &Pubkey) -> Mint {
    Mint::unpack(&account(accounts, key).data).unwrap()
}

fn unpack_multisig(accounts: &[(Pubkey, Account)], key: &Pubkey) -> TokenMultisig {
    TokenMultisig::unpack(&account(accounts, key).data).unwrap()
}

fn assert_success(label: &str, result: &mollusk_svm::result::InstructionResult) {
    assert!(
        result.program_result.is_ok(),
        "{label} failed: {:?}",
        result.program_result,
    );
}

fn assert_failure(label: &str, result: &mollusk_svm::result::InstructionResult) {
    assert!(
        result.program_result.is_err(),
        "{label} unexpectedly succeeded",
    );
}

fn assert_account_unchanged(
    before: &[(Pubkey, Account)],
    after: &[(Pubkey, Account)],
    key: &Pubkey,
    label: &str,
) {
    let before_account = account(before, key);
    let after_account = account(after, key);
    assert_eq!(
        after_account.lamports, before_account.lamports,
        "{label}: lamports changed for {key}",
    );
    assert_eq!(
        after_account.data, before_account.data,
        "{label}: data changed for {key}",
    );
    assert_eq!(
        after_account.owner, before_account.owner,
        "{label}: owner changed for {key}",
    );
    assert_eq!(
        after_account.executable, before_account.executable,
        "{label}: executable flag changed for {key}",
    );
    assert_eq!(
        after_account.rent_epoch, before_account.rent_epoch,
        "{label}: rent_epoch changed for {key}",
    );
}

fn assert_accounts_unchanged(
    before: &[(Pubkey, Account)],
    after: &[(Pubkey, Account)],
    keys: &[Pubkey],
    label: &str,
) {
    for key in keys {
        assert_account_unchanged(before, after, key, label);
    }
}

fn authority_type_u8(authority_type: AuthorityType) -> u8 {
    match authority_type {
        AuthorityType::MintTokens => 0,
        AuthorityType::FreezeAccount => 1,
        AuthorityType::AccountOwner => 2,
        AuthorityType::CloseAccount => 3,
    }
}

fn set_authority_data(
    route_tag: u8,
    authority_type: AuthorityType,
    new_authority: Option<&Pubkey>,
    trailing_bump: Option<u8>,
) -> Vec<u8> {
    let mut data = vec![route_tag, authority_type_u8(authority_type)];
    match new_authority {
        Some(pubkey) => {
            data.push(1);
            data.extend_from_slice(pubkey.as_ref());
        }
        None => data.push(0),
    }
    if let Some(bump) = trailing_bump {
        data.push(bump);
    }
    data
}

#[test]
fn test_initialize_multisig2_canonical_and_invalid_thresholds() {
    let mollusk = fresh_mollusk();

    let multisig = Pubkey::new_unique();
    let signer_a = Pubkey::new_unique();
    let signer_b = Pubkey::new_unique();
    let signer_c = Pubkey::new_unique();
    let signer_pubkeys = [signer_a, signer_b, signer_c];

    let initial_accounts = vec![
        (
            spl_token_program::keyed_account().0,
            spl_token_program::keyed_account().1,
        ),
        (multisig, multisig_account()),
        (signer_a, system_account(1_000_000)),
        (signer_b, system_account(1_000_000)),
        (signer_c, system_account(1_000_000)),
    ];

    let zero_threshold_accounts = initial_accounts.clone();
    let zero_threshold_ix = build_initialize_multisig2_ix(&multisig, &signer_pubkeys, 0);
    let zero_threshold_result = run(&mollusk, &zero_threshold_accounts, &zero_threshold_ix);
    assert_failure("initializeMultisig2 threshold zero", &zero_threshold_result);
    assert_accounts_unchanged(
        &zero_threshold_accounts,
        &zero_threshold_result.resulting_accounts,
        &[multisig],
        "initializeMultisig2 threshold zero",
    );

    let too_high_threshold_accounts = initial_accounts.clone();
    let too_high_threshold_ix = build_initialize_multisig2_ix(&multisig, &signer_pubkeys, 4);
    let too_high_threshold_result = run(
        &mollusk,
        &too_high_threshold_accounts,
        &too_high_threshold_ix,
    );
    assert_failure(
        "initializeMultisig2 threshold exceeds signer count",
        &too_high_threshold_result,
    );
    assert_accounts_unchanged(
        &too_high_threshold_accounts,
        &too_high_threshold_result.resulting_accounts,
        &[multisig],
        "initializeMultisig2 threshold exceeds signer count",
    );

    let init_ix = build_initialize_multisig2_ix(&multisig, &signer_pubkeys, 2);
    let init_result = run(&mollusk, &initial_accounts, &init_ix);
    assert_success("initializeMultisig2", &init_result);
    let after_init = init_result.resulting_accounts;
    let multisig_state = unpack_multisig(&after_init, &multisig);
    assert_eq!(multisig_state.m, 2);
    assert_eq!(multisig_state.n, signer_pubkeys.len() as u8);
    assert!(multisig_state.is_initialized);
    assert_eq!(
        &multisig_state.signers[..signer_pubkeys.len()],
        &signer_pubkeys
    );
}

#[test]
fn test_approve_multisig_threshold_signers_and_failures() {
    let mollusk = fresh_mollusk();

    let multisig = Pubkey::new_unique();
    let signer_a = Pubkey::new_unique();
    let signer_b = Pubkey::new_unique();
    let signer_c = Pubkey::new_unique();
    let outsider = Pubkey::new_unique();
    let delegate = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let source = Pubkey::new_unique();
    let signer_pubkeys = [signer_a, signer_b, signer_c];

    let initial_accounts = vec![
        (
            spl_token_program::keyed_account().0,
            spl_token_program::keyed_account().1,
        ),
        (multisig, multisig_account()),
        (mint, mint_account(Some(multisig), None)),
        (
            source,
            token_account(
                &mint,
                &multisig,
                500,
                None,
                0,
                TokenState::Initialized,
                None,
            ),
        ),
        (signer_a, system_account(1_000_000)),
        (signer_b, system_account(1_000_000)),
        (signer_c, system_account(1_000_000)),
        (outsider, system_account(1_000_000)),
        (delegate, system_account(1_000_000)),
    ];

    let init_ix = build_initialize_multisig2_ix(&multisig, &signer_pubkeys, 2);
    let init_result = run(&mollusk, &initial_accounts, &init_ix);
    assert_success("initializeMultisig2 for approveMultisig", &init_result);
    let after_init = init_result.resulting_accounts;

    let mut approve_data = vec![19u8];
    approve_data.extend_from_slice(&APPROVE_AMOUNT.to_le_bytes());

    let insufficient_accounts = after_init.clone();
    let insufficient_ix = build_approve_multisig_ix(
        &source,
        &delegate,
        &multisig,
        &[signer_a],
        approve_data.clone(),
    );
    let insufficient_result = run(&mollusk, &insufficient_accounts, &insufficient_ix);
    assert_failure("approveMultisig with one signer", &insufficient_result);
    assert_accounts_unchanged(
        &insufficient_accounts,
        &insufficient_result.resulting_accounts,
        &[source, multisig],
        "approveMultisig with one signer",
    );

    let substituted_accounts = after_init.clone();
    let substituted_ix = build_approve_multisig_ix(
        &source,
        &delegate,
        &multisig,
        &[signer_a, outsider],
        approve_data.clone(),
    );
    let substituted_result = run(&mollusk, &substituted_accounts, &substituted_ix);
    assert_failure(
        "approveMultisig with substituted signer",
        &substituted_result,
    );
    assert_accounts_unchanged(
        &substituted_accounts,
        &substituted_result.resulting_accounts,
        &[source, multisig],
        "approveMultisig with substituted signer",
    );

    let approve_ix = build_approve_multisig_ix(
        &source,
        &delegate,
        &multisig,
        &[signer_a, signer_b],
        approve_data,
    );
    let approve_result = run(&mollusk, &after_init, &approve_ix);
    assert_success("approveMultisig threshold signers", &approve_result);
    let after_approve = approve_result.resulting_accounts;
    let approved_source = unpack_token(&after_approve, &source);
    assert_eq!(approved_source.amount, 500);
    assert_eq!(approved_source.delegate, COption::Some(delegate));
    assert_eq!(approved_source.delegated_amount, APPROVE_AMOUNT);
}

#[test]
fn test_mint_transfer_burn_close_end_to_end() {
    let mollusk = fresh_mollusk();

    let authority = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let alice = Pubkey::new_unique(); // source token account
    let bob = Pubkey::new_unique(); // destination token account

    // -------------------------------------------------------------
    // Initial on-chain state: an initialised mint, two empty token
    // accounts both owned by `authority`. We could reach those via
    // initializeMint2 / initializeAccount3 CPIs, but the goal here
    // is to test our transfer/mint/burn/close — the init path is
    // covered by host unit tests and the byte-layout assertions
    // inside `state.zig`.
    // -------------------------------------------------------------
    let initial_accounts = vec![
        (
            spl_token_program::keyed_account().0,
            spl_token_program::keyed_account().1,
        ),
        (mint, mint_account(Some(authority), None)),
        (
            alice,
            token_account(&mint, &authority, 0, None, 0, TokenState::Initialized, None),
        ),
        (
            bob,
            token_account(&mint, &authority, 0, None, 0, TokenState::Initialized, None),
        ),
        (authority, system_account(1_000_000)),
    ];

    // ───────────────────────── 1. mintTo ─────────────────────────
    // mintTo uses `mint`, `destination`, and `authority` — `source`
    // is ignored by the demo dispatcher but the runtime still has
    // to serialize it. Pass `bob` (a real, distinct account) in the
    // source slot to avoid a duplicate-account slot that the SDK's
    // `nextAccountUnchecked` doesn't handle.
    let mut data = vec![0u8]; // tag = mintTo
    data.extend_from_slice(&MINT_AMOUNT.to_le_bytes());
    let ix = build_legacy_ix(&mint, &bob, &alice, &authority, true, data);
    let r1 = run(&mollusk, &initial_accounts, &ix);
    assert_success("mintTo", &r1);
    println!("mintTo CU: {}", r1.compute_units_consumed);

    // alice now holds MINT_AMOUNT — pull the post-state forward.
    let after_mint = r1.resulting_accounts;
    let alice_balance = unpack_token(&after_mint, &alice).amount;
    assert_eq!(alice_balance, MINT_AMOUNT);

    // ─────────────────── 2. transferChecked ──────────────────────
    let mut data = vec![1u8]; // tag = transferChecked
    data.extend_from_slice(&TRANSFER_AMOUNT.to_le_bytes());
    data.push(DECIMALS);
    let ix = build_legacy_ix(&mint, &alice, &bob, &authority, true, data);
    let r2 = run(&mollusk, &after_mint, &ix);
    assert_success("transferChecked", &r2);
    println!("transferChecked CU: {}", r2.compute_units_consumed);

    let after_transfer = r2.resulting_accounts;
    let alice_balance = unpack_token(&after_transfer, &alice).amount;
    let bob_balance = unpack_token(&after_transfer, &bob).amount;
    assert_eq!(alice_balance, MINT_AMOUNT - TRANSFER_AMOUNT);
    assert_eq!(bob_balance, TRANSFER_AMOUNT);

    // ───────────────────────── 3. burn ───────────────────────────
    let mut data = vec![2u8]; // tag = burn
    data.extend_from_slice(&BURN_AMOUNT.to_le_bytes());
    let ix = build_legacy_ix(&mint, &alice, &bob, &authority, true, data);
    let r3 = run(&mollusk, &after_transfer, &ix);
    assert_success("burn", &r3);
    println!("burn CU: {}", r3.compute_units_consumed);

    let after_burn = r3.resulting_accounts;
    let alice_balance = unpack_token(&after_burn, &alice).amount;
    assert_eq!(
        alice_balance,
        MINT_AMOUNT - TRANSFER_AMOUNT - BURN_AMOUNT,
        "post-burn balance mismatch — builder bytes disagree with on-chain semantics",
    );

    // ────────────────────── 4. closeAccount ──────────────────────
    // Close alice → send rent lamports to `bob_owner_wallet`. Alice
    // must be empty for the token program to allow the close, so
    // first burn the remaining balance.
    let remaining = alice_balance;
    let mut data = vec![2u8]; // burn the rest
    data.extend_from_slice(&remaining.to_le_bytes());
    let ix = build_legacy_ix(&mint, &alice, &bob, &authority, true, data);
    let r4 = run(&mollusk, &after_burn, &ix);
    assert_success("drain before close", &r4);
    let after_drain = r4.resulting_accounts;

    let data = vec![3u8]; // tag = closeAccount; destination receives lamports
    let lamports_dest = Pubkey::new_unique();
    let mut accts_for_close = after_drain.clone();
    accts_for_close.push((
        lamports_dest,
        Account {
            lamports: 0,
            data: vec![],
            owner: solana_sdk_ids::system_program::id(),
            executable: false,
            rent_epoch: 0,
        },
    ));
    let ix = Instruction {
        program_id: program::id(),
        accounts: vec![
            AccountMeta::new_readonly(spl_token_program::ID, false),
            AccountMeta::new(mint, false),  // unused but kept in layout
            AccountMeta::new(alice, false), // the account being closed
            AccountMeta::new(lamports_dest, false), // lamports go here
            AccountMeta::new_readonly(authority, true),
        ],
        data,
    };
    let r5 = run(&mollusk, &accts_for_close, &ix);
    assert_success("closeAccount", &r5);
    println!("closeAccount CU: {}", r5.compute_units_consumed);

    // After close: alice's data is zeroed by the token program and
    // lamports are forwarded to lamports_dest.
    let after_close = r5.resulting_accounts;
    let dest_lamports = after_close
        .iter()
        .find(|(k, _)| *k == lamports_dest)
        .unwrap()
        .1
        .lamports;
    assert!(
        dest_lamports > 0,
        "expected lamports forwarded to close-destination",
    );
}

#[test]
fn test_approve_revoke_checked_and_signed_routes() {
    let mollusk = fresh_mollusk();

    let owner = Pubkey::new_unique();
    let delegate = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let source = Pubkey::new_unique();
    let destination = Pubkey::new_unique();
    let destination_owner = Pubkey::new_unique();
    let pda_source = Pubkey::new_unique();
    let (pda_authority, pda_bump) = Pubkey::find_program_address(&[b"authority"], &program::id());

    let initial_accounts = vec![
        (
            spl_token_program::keyed_account().0,
            spl_token_program::keyed_account().1,
        ),
        (mint, mint_account(Some(owner), None)),
        (
            source,
            token_account(&mint, &owner, 500, None, 0, TokenState::Initialized, None),
        ),
        (
            destination,
            token_account(
                &mint,
                &destination_owner,
                0,
                None,
                0,
                TokenState::Initialized,
                None,
            ),
        ),
        (
            pda_source,
            token_account(
                &mint,
                &pda_authority,
                80,
                None,
                0,
                TokenState::Initialized,
                None,
            ),
        ),
        (owner, system_account(1_000_000)),
        (delegate, system_account(1_000_000)),
        (pda_authority, plain_account(1_000_000, program::id())),
    ];

    let mut approve_data = vec![4u8];
    approve_data.extend_from_slice(&APPROVE_AMOUNT.to_le_bytes());
    let approve_ix = build_approve_ix(&source, &delegate, &owner, true, approve_data);
    let approve_result = run(&mollusk, &initial_accounts, &approve_ix);
    assert_success("approve", &approve_result);
    let after_approve = approve_result.resulting_accounts;
    let approved_source = unpack_token(&after_approve, &source);
    assert_eq!(approved_source.amount, 500);
    assert_eq!(approved_source.delegate, COption::Some(delegate));
    assert_eq!(approved_source.delegated_amount, APPROVE_AMOUNT);

    let mut spend_data = vec![1u8];
    spend_data.extend_from_slice(&APPROVE_SPEND_AMOUNT.to_le_bytes());
    spend_data.push(DECIMALS);
    let spend_ix = build_legacy_ix(&mint, &source, &destination, &delegate, true, spend_data);
    let spend_result = run(&mollusk, &after_approve, &spend_ix);
    assert_success("delegate transfer within allowance", &spend_result);
    let after_delegate_spend = spend_result.resulting_accounts;
    let spent_source = unpack_token(&after_delegate_spend, &source);
    let spent_destination = unpack_token(&after_delegate_spend, &destination);
    assert_eq!(spent_source.amount, 500 - APPROVE_SPEND_AMOUNT);
    assert_eq!(spent_destination.amount, APPROVE_SPEND_AMOUNT);
    assert_eq!(spent_source.delegate, COption::Some(delegate));
    assert_eq!(
        spent_source.delegated_amount,
        APPROVE_AMOUNT - APPROVE_SPEND_AMOUNT,
    );

    let overspend_accounts = after_delegate_spend.clone();
    let mut overspend_data = vec![1u8];
    overspend_data.extend_from_slice(&(APPROVE_AMOUNT - APPROVE_SPEND_AMOUNT + 1).to_le_bytes());
    overspend_data.push(DECIMALS);
    let overspend_ix = build_legacy_ix(
        &mint,
        &source,
        &destination,
        &delegate,
        true,
        overspend_data,
    );
    let overspend_result = run(&mollusk, &overspend_accounts, &overspend_ix);
    assert_failure("delegate overspend", &overspend_result);
    assert_accounts_unchanged(
        &overspend_accounts,
        &overspend_result.resulting_accounts,
        &[source, destination],
        "delegate overspend",
    );

    let revoke_ix = build_revoke_ix(&source, &owner, true, vec![8u8]);
    let revoke_result = run(&mollusk, &after_delegate_spend, &revoke_ix);
    assert_success("revoke", &revoke_result);
    let after_revoke = revoke_result.resulting_accounts;
    let revoked_source = unpack_token(&after_revoke, &source);
    assert_eq!(revoked_source.delegate, COption::None);
    assert_eq!(revoked_source.delegated_amount, 0);

    let revoked_accounts = after_revoke.clone();
    let mut revoked_spend_data = vec![1u8];
    revoked_spend_data.extend_from_slice(&1u64.to_le_bytes());
    revoked_spend_data.push(DECIMALS);
    let revoked_spend_ix = build_legacy_ix(
        &mint,
        &source,
        &destination,
        &delegate,
        true,
        revoked_spend_data,
    );
    let revoked_spend_result = run(&mollusk, &revoked_accounts, &revoked_spend_ix);
    assert_failure("revoked delegate transfer", &revoked_spend_result);
    assert_accounts_unchanged(
        &revoked_accounts,
        &revoked_spend_result.resulting_accounts,
        &[source, destination],
        "revoked delegate transfer",
    );

    let mut approve_checked_data = vec![6u8];
    approve_checked_data.extend_from_slice(&APPROVE_CHECKED_AMOUNT.to_le_bytes());
    approve_checked_data.push(DECIMALS);
    let approve_checked_ix = build_approve_checked_ix(
        &source,
        &mint,
        &delegate,
        &owner,
        true,
        approve_checked_data,
    );
    let approve_checked_result = run(&mollusk, &after_revoke, &approve_checked_ix);
    assert_success("approveChecked", &approve_checked_result);
    let after_approve_checked = approve_checked_result.resulting_accounts;
    let checked_source = unpack_token(&after_approve_checked, &source);
    assert_eq!(checked_source.delegate, COption::Some(delegate));
    assert_eq!(checked_source.delegated_amount, APPROVE_CHECKED_AMOUNT);

    let wrong_decimals_accounts = after_approve_checked.clone();
    let mut wrong_decimals_data = vec![6u8];
    wrong_decimals_data.extend_from_slice(&33u64.to_le_bytes());
    wrong_decimals_data.push(DECIMALS + 1);
    let wrong_decimals_ix =
        build_approve_checked_ix(&source, &mint, &delegate, &owner, true, wrong_decimals_data);
    let wrong_decimals_result = run(&mollusk, &wrong_decimals_accounts, &wrong_decimals_ix);
    assert_failure("approveChecked wrong decimals", &wrong_decimals_result);
    assert_accounts_unchanged(
        &wrong_decimals_accounts,
        &wrong_decimals_result.resulting_accounts,
        &[source, mint],
        "approveChecked wrong decimals",
    );

    let mut checked_spend_data = vec![1u8];
    checked_spend_data.extend_from_slice(&APPROVE_CHECKED_SPEND_AMOUNT.to_le_bytes());
    checked_spend_data.push(DECIMALS);
    let checked_spend_ix = build_legacy_ix(
        &mint,
        &source,
        &destination,
        &delegate,
        true,
        checked_spend_data,
    );
    let checked_spend_result = run(&mollusk, &after_approve_checked, &checked_spend_ix);
    assert_success(
        "delegate transfer after approveChecked",
        &checked_spend_result,
    );
    let after_checked_spend = checked_spend_result.resulting_accounts;
    let checked_spent_source = unpack_token(&after_checked_spend, &source);
    let checked_spent_destination = unpack_token(&after_checked_spend, &destination);
    assert_eq!(
        checked_spent_source.amount,
        500 - APPROVE_SPEND_AMOUNT - APPROVE_CHECKED_SPEND_AMOUNT,
    );
    assert_eq!(
        checked_spent_destination.amount,
        APPROVE_SPEND_AMOUNT + APPROVE_CHECKED_SPEND_AMOUNT,
    );
    assert_eq!(
        checked_spent_source.delegated_amount,
        APPROVE_CHECKED_AMOUNT - APPROVE_CHECKED_SPEND_AMOUNT,
    );

    let mut approve_signed_data = vec![5u8];
    approve_signed_data.extend_from_slice(&PDA_APPROVE_AMOUNT.to_le_bytes());
    approve_signed_data.push(pda_bump);
    let approve_signed_ix = build_approve_ix(
        &pda_source,
        &delegate,
        &pda_authority,
        false,
        approve_signed_data,
    );
    let approve_signed_result = run(&mollusk, &after_checked_spend, &approve_signed_ix);
    assert_success("approveSigned PDA path", &approve_signed_result);
    let after_approve_signed = approve_signed_result.resulting_accounts;
    let pda_source_state = unpack_token(&after_approve_signed, &pda_source);
    assert_eq!(pda_source_state.delegate, COption::Some(delegate));
    assert_eq!(pda_source_state.delegated_amount, PDA_APPROVE_AMOUNT);
    assert_eq!(pda_source_state.amount, 80);
}

#[test]
fn test_set_authority_freeze_thaw_and_failure_preservation() {
    let mollusk = fresh_mollusk();

    let mint = Pubkey::new_unique();
    let old_owner = Pubkey::new_unique();
    let new_owner = Pubkey::new_unique();
    let delegate = Pubkey::new_unique();
    let wrong_authority = Pubkey::new_unique();
    let mint_authority = Pubkey::new_unique();
    let old_freeze_authority = Pubkey::new_unique();
    let new_freeze_authority = Pubkey::new_unique();
    let new_close_authority = Pubkey::new_unique();
    let source = Pubkey::new_unique();
    let recipient = Pubkey::new_unique();
    let recipient_owner = Pubkey::new_unique();
    let closable = Pubkey::new_unique();
    let lamports_destination = Pubkey::new_unique();

    let initial_accounts = vec![
        (
            spl_token_program::keyed_account().0,
            spl_token_program::keyed_account().1,
        ),
        (
            mint,
            mint_account(Some(mint_authority), Some(old_freeze_authority)),
        ),
        (
            source,
            token_account(
                &mint,
                &old_owner,
                120,
                None,
                0,
                TokenState::Initialized,
                None,
            ),
        ),
        (
            recipient,
            token_account(
                &mint,
                &recipient_owner,
                0,
                None,
                0,
                TokenState::Initialized,
                None,
            ),
        ),
        (
            closable,
            token_account(&mint, &old_owner, 0, None, 0, TokenState::Initialized, None),
        ),
        (old_owner, system_account(1_000_000)),
        (new_owner, system_account(1_000_000)),
        (delegate, system_account(1_000_000)),
        (wrong_authority, system_account(1_000_000)),
        (mint_authority, system_account(1_000_000)),
        (old_freeze_authority, system_account(1_000_000)),
        (new_freeze_authority, system_account(1_000_000)),
        (new_close_authority, system_account(1_000_000)),
        (lamports_destination, system_account(0)),
    ];

    let owner_change_ix = build_set_authority_ix(
        &source,
        &old_owner,
        true,
        set_authority_data(10, AuthorityType::AccountOwner, Some(&new_owner), None),
    );
    let owner_change_result = run(&mollusk, &initial_accounts, &owner_change_ix);
    assert_success("setAuthority account owner", &owner_change_result);
    let after_owner_change = owner_change_result.resulting_accounts;
    let owner_changed_source = unpack_token(&after_owner_change, &source);
    assert_eq!(owner_changed_source.owner, new_owner);

    let old_owner_fail_accounts = after_owner_change.clone();
    let mut old_owner_approve_data = vec![4u8];
    old_owner_approve_data.extend_from_slice(&1u64.to_le_bytes());
    let old_owner_approve_ix =
        build_approve_ix(&source, &delegate, &old_owner, true, old_owner_approve_data);
    let old_owner_approve_result = run(&mollusk, &old_owner_fail_accounts, &old_owner_approve_ix);
    assert_failure(
        "old owner approve after ownership transfer",
        &old_owner_approve_result,
    );
    assert_accounts_unchanged(
        &old_owner_fail_accounts,
        &old_owner_approve_result.resulting_accounts,
        &[source],
        "old owner approve after ownership transfer",
    );

    let mut new_owner_approve_data = vec![4u8];
    new_owner_approve_data.extend_from_slice(&1u64.to_le_bytes());
    let new_owner_approve_ix =
        build_approve_ix(&source, &delegate, &new_owner, true, new_owner_approve_data);
    let new_owner_approve_result = run(&mollusk, &after_owner_change, &new_owner_approve_ix);
    assert_success(
        "new owner approve after ownership transfer",
        &new_owner_approve_result,
    );
    let after_new_owner_approve = new_owner_approve_result.resulting_accounts;
    let new_owner_approved_source = unpack_token(&after_new_owner_approve, &source);
    assert_eq!(new_owner_approved_source.delegate, COption::Some(delegate));

    let new_owner_revoke_ix = build_revoke_ix(&source, &new_owner, true, vec![8u8]);
    let new_owner_revoke_result = run(&mollusk, &after_new_owner_approve, &new_owner_revoke_ix);
    assert_success("new owner revoke", &new_owner_revoke_result);
    let after_new_owner_revoke = new_owner_revoke_result.resulting_accounts;
    let new_owner_revoked_source = unpack_token(&after_new_owner_revoke, &source);
    assert_eq!(new_owner_revoked_source.delegate, COption::None);
    assert_eq!(new_owner_revoked_source.delegated_amount, 0);

    let unauthorized_close_accounts = after_new_owner_revoke.clone();
    let unauthorized_close_ix = build_set_authority_ix(
        &closable,
        &wrong_authority,
        true,
        set_authority_data(
            10,
            AuthorityType::CloseAccount,
            Some(&new_close_authority),
            None,
        ),
    );
    let unauthorized_close_result = run(
        &mollusk,
        &unauthorized_close_accounts,
        &unauthorized_close_ix,
    );
    assert_failure(
        "unauthorized setAuthority close authority",
        &unauthorized_close_result,
    );
    assert_accounts_unchanged(
        &unauthorized_close_accounts,
        &unauthorized_close_result.resulting_accounts,
        &[closable],
        "unauthorized setAuthority close authority",
    );

    let close_authority_ix = build_set_authority_ix(
        &closable,
        &old_owner,
        true,
        set_authority_data(
            10,
            AuthorityType::CloseAccount,
            Some(&new_close_authority),
            None,
        ),
    );
    let close_authority_result = run(&mollusk, &after_new_owner_revoke, &close_authority_ix);
    assert_success("setAuthority close authority", &close_authority_result);
    let after_close_authority = close_authority_result.resulting_accounts;
    let closable_state = unpack_token(&after_close_authority, &closable);
    assert_eq!(closable_state.owner, old_owner);
    assert_eq!(
        closable_state.close_authority,
        COption::Some(new_close_authority),
    );

    let close_ix = build_legacy_ix(
        &mint,
        &closable,
        &lamports_destination,
        &new_close_authority,
        true,
        vec![3u8],
    );
    let close_result = run(&mollusk, &after_close_authority, &close_ix);
    assert_success(
        "closeAccount with reassigned close authority",
        &close_result,
    );
    let after_close = close_result.resulting_accounts;
    assert!(
        account(&after_close, &lamports_destination).lamports > 0,
        "close authority should receive drained lamports",
    );

    let freeze_authority_change_ix = build_set_authority_ix(
        &mint,
        &old_freeze_authority,
        true,
        set_authority_data(
            10,
            AuthorityType::FreezeAccount,
            Some(&new_freeze_authority),
            None,
        ),
    );
    let freeze_authority_change_result = run(&mollusk, &after_close, &freeze_authority_change_ix);
    assert_success(
        "setAuthority freeze authority",
        &freeze_authority_change_result,
    );
    let after_freeze_authority_change = freeze_authority_change_result.resulting_accounts;
    let changed_mint = unpack_mint(&after_freeze_authority_change, &mint);
    assert_eq!(
        changed_mint.freeze_authority,
        COption::Some(new_freeze_authority),
    );

    let old_freeze_fail_accounts = after_freeze_authority_change.clone();
    let old_freeze_ix =
        build_freeze_thaw_ix(&source, &mint, &old_freeze_authority, true, vec![12u8]);
    let old_freeze_result = run(&mollusk, &old_freeze_fail_accounts, &old_freeze_ix);
    assert_failure(
        "old freeze authority after reassignment",
        &old_freeze_result,
    );
    assert_accounts_unchanged(
        &old_freeze_fail_accounts,
        &old_freeze_result.resulting_accounts,
        &[source, mint],
        "old freeze authority after reassignment",
    );

    let freeze_ix = build_freeze_thaw_ix(&source, &mint, &new_freeze_authority, true, vec![12u8]);
    let freeze_result = run(&mollusk, &after_freeze_authority_change, &freeze_ix);
    assert_success("freezeAccount", &freeze_result);
    let after_freeze = freeze_result.resulting_accounts;
    let frozen_source = unpack_token(&after_freeze, &source);
    assert_eq!(frozen_source.state, TokenState::Frozen);

    let frozen_transfer_accounts = after_freeze.clone();
    let mut frozen_transfer_data = vec![1u8];
    frozen_transfer_data.extend_from_slice(&1u64.to_le_bytes());
    frozen_transfer_data.push(DECIMALS);
    let frozen_transfer_ix = build_legacy_ix(
        &mint,
        &source,
        &recipient,
        &new_owner,
        true,
        frozen_transfer_data,
    );
    let frozen_transfer_result = run(&mollusk, &frozen_transfer_accounts, &frozen_transfer_ix);
    assert_failure("transfer from frozen account", &frozen_transfer_result);
    assert_accounts_unchanged(
        &frozen_transfer_accounts,
        &frozen_transfer_result.resulting_accounts,
        &[source, recipient],
        "transfer from frozen account",
    );

    let frozen_burn_accounts = after_freeze.clone();
    let mut frozen_burn_data = vec![2u8];
    frozen_burn_data.extend_from_slice(&1u64.to_le_bytes());
    let frozen_burn_ix = build_legacy_ix(
        &mint,
        &source,
        &recipient,
        &new_owner,
        true,
        frozen_burn_data,
    );
    let frozen_burn_result = run(&mollusk, &frozen_burn_accounts, &frozen_burn_ix);
    assert_failure("burn from frozen account", &frozen_burn_result);
    assert_accounts_unchanged(
        &frozen_burn_accounts,
        &frozen_burn_result.resulting_accounts,
        &[source, recipient, mint],
        "burn from frozen account",
    );

    let wrong_thaw_accounts = after_freeze.clone();
    let wrong_thaw_ix = build_freeze_thaw_ix(&source, &mint, &wrong_authority, true, vec![14u8]);
    let wrong_thaw_result = run(&mollusk, &wrong_thaw_accounts, &wrong_thaw_ix);
    assert_failure("wrong freeze authority thaw", &wrong_thaw_result);
    assert_accounts_unchanged(
        &wrong_thaw_accounts,
        &wrong_thaw_result.resulting_accounts,
        &[source, mint],
        "wrong freeze authority thaw",
    );

    let thaw_ix = build_freeze_thaw_ix(&source, &mint, &new_freeze_authority, true, vec![14u8]);
    let thaw_result = run(&mollusk, &after_freeze, &thaw_ix);
    assert_success("thawAccount", &thaw_result);
    let after_thaw = thaw_result.resulting_accounts;
    let thawed_source = unpack_token(&after_thaw, &source);
    assert_eq!(thawed_source.state, TokenState::Initialized);

    let mut thaw_transfer_data = vec![1u8];
    thaw_transfer_data.extend_from_slice(&FROZEN_TRANSFER_AMOUNT.to_le_bytes());
    thaw_transfer_data.push(DECIMALS);
    let thaw_transfer_ix = build_legacy_ix(
        &mint,
        &source,
        &recipient,
        &new_owner,
        true,
        thaw_transfer_data,
    );
    let thaw_transfer_result = run(&mollusk, &after_thaw, &thaw_transfer_ix);
    assert_success("transfer after thaw", &thaw_transfer_result);
    let after_thaw_transfer = thaw_transfer_result.resulting_accounts;
    let post_thaw_source = unpack_token(&after_thaw_transfer, &source);
    let post_thaw_recipient = unpack_token(&after_thaw_transfer, &recipient);
    assert_eq!(post_thaw_source.amount, 120 - FROZEN_TRANSFER_AMOUNT);
    assert_eq!(post_thaw_recipient.amount, FROZEN_TRANSFER_AMOUNT);

    let clear_mint_authority_ix = build_set_authority_ix(
        &mint,
        &mint_authority,
        true,
        set_authority_data(10, AuthorityType::MintTokens, None, None),
    );
    let clear_mint_authority_result = run(&mollusk, &after_thaw_transfer, &clear_mint_authority_ix);
    assert_success("clear mint authority", &clear_mint_authority_result);
    let after_clear_mint_authority = clear_mint_authority_result.resulting_accounts;
    let mint_without_authority = unpack_mint(&after_clear_mint_authority, &mint);
    assert_eq!(mint_without_authority.mint_authority, COption::None);

    let cleared_mint_accounts = after_clear_mint_authority.clone();
    let mut mint_to_data = vec![0u8];
    mint_to_data.extend_from_slice(&1u64.to_le_bytes());
    let mint_to_ix = build_legacy_ix(
        &mint,
        &recipient,
        &source,
        &mint_authority,
        true,
        mint_to_data,
    );
    let mint_to_result = run(&mollusk, &cleared_mint_accounts, &mint_to_ix);
    assert_failure("mintTo after clearing mint authority", &mint_to_result);
    assert_accounts_unchanged(
        &cleared_mint_accounts,
        &mint_to_result.resulting_accounts,
        &[mint, source, recipient],
        "mintTo after clearing mint authority",
    );
}

#[test]
fn test_route_guards_reject_short_accounts_and_data() {
    let mollusk = fresh_mollusk();

    let owner = Pubkey::new_unique();
    let delegate = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let source = Pubkey::new_unique();

    let accounts = vec![
        (
            spl_token_program::keyed_account().0,
            spl_token_program::keyed_account().1,
        ),
        (mint, mint_account(Some(owner), None)),
        (
            source,
            token_account(&mint, &owner, 10, None, 0, TokenState::Initialized, None),
        ),
        (owner, system_account(1_000_000)),
        (delegate, system_account(1_000_000)),
    ];

    let short_accounts_ix = build_demo_ix(
        vec![
            AccountMeta::new_readonly(spl_token_program::ID, false),
            AccountMeta::new(source, false),
            AccountMeta::new_readonly(mint, false),
        ],
        vec![12u8],
    );
    let short_accounts_result = run(&mollusk, &accounts, &short_accounts_ix);
    assert!(matches!(
        short_accounts_result.program_result,
        ProgramResult::Failure(SolanaProgramError::NotEnoughAccountKeys)
    ));
    assert_accounts_unchanged(
        &accounts,
        &short_accounts_result.resulting_accounts,
        &[source, mint],
        "short account list",
    );

    let short_data_ix =
        build_approve_checked_ix(&source, &mint, &delegate, &owner, true, vec![6u8]);
    let short_data_result = run(&mollusk, &accounts, &short_data_ix);
    assert!(matches!(
        short_data_result.program_result,
        ProgramResult::Failure(SolanaProgramError::InvalidInstructionData)
    ));
    assert_accounts_unchanged(
        &accounts,
        &short_data_result.resulting_accounts,
        &[source, mint],
        "short instruction data",
    );
}
