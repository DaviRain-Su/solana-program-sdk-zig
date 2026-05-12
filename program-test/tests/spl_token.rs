//! Integration test for the `spl-token` sub-package.
//!
//! Same recipe as the spl-memo test, scaled up: deploys our Zig
//! program built against `spl_token.cpi.*` into Mollusk **alongside
//! the real on-chain SPL Token `.so`** shipped by
//! `mollusk-svm-programs-token`, then walks through the four
//! highest-value operations in sequence:
//!
//!   1. mintTo            → mint 1_000 raw units to a fresh ATA
//!   2. transferChecked   → move 250 raw units to a second account
//!   3. burn              → destroy 100 raw units from the source
//!   4. closeAccount      → close the empty destination
//!
//! Each step is its own `process_instruction` call so failures
//! point at exactly one CPI. After step 3 we read back the source
//! token account's bytes and verify the on-chain `amount` matches
//! `1_000 - 250 - 100 = 650` — that's the byte-level
//! cross-validation the user asked for: "your builder wrote bytes,
//! but does the real on-chain program agree with what they mean?"

use {
    mollusk_svm::{result::ProgramResult, Mollusk},
    mollusk_svm_programs_token::token as spl_token_program,
    solana_account::Account,
    solana_instruction::{AccountMeta, Instruction},
    solana_program_option::COption,
    solana_program_pack::Pack,
    solana_pubkey::Pubkey,
    solana_sdk_ids::bpf_loader_upgradeable,
    spl_token_interface::state::{
        Account as TokenAccount, AccountState as TokenState, Mint,
    },
};

mod program {
    solana_pubkey::declare_id!("Zigc1Hc97L8Pebma74jDzYiyoUvdxxcj7Gxppg9VRxK");
}

const DECIMALS: u8 = 6;
const MINT_AMOUNT: u64 = 1_000;
const TRANSFER_AMOUNT: u64 = 250;
const BURN_AMOUNT: u64 = 100;

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

/// Pack a `Mint` into a fresh on-chain account with the canonical
/// SPL Token layout. `mint_authority` is the signer that will be
/// allowed to MintTo / Burn / etc.
fn mint_account(mint_authority: &Pubkey) -> Account {
    spl_token_program::create_account_for_mint(Mint {
        mint_authority: COption::Some(*mint_authority),
        supply: 0,
        decimals: DECIMALS,
        is_initialized: true,
        freeze_authority: COption::None,
    })
}

fn token_account(mint: &Pubkey, owner: &Pubkey, amount: u64) -> Account {
    spl_token_program::create_account_for_token_account(TokenAccount {
        mint: *mint,
        owner: *owner,
        amount,
        delegate: COption::None,
        state: TokenState::Initialized,
        is_native: COption::None,
        delegated_amount: 0,
        close_authority: COption::None,
    })
}

fn build_ix(
    mint: &Pubkey,
    source: &Pubkey,
    destination: &Pubkey,
    authority: &Pubkey,
    data: Vec<u8>,
) -> Instruction {
    Instruction {
        program_id: program::id(),
        accounts: vec![
            AccountMeta::new_readonly(spl_token_program::ID, false),
            AccountMeta::new(*mint, false),
            AccountMeta::new(*source, false),
            AccountMeta::new(*destination, false),
            AccountMeta::new_readonly(*authority, true),
        ],
        data,
    }
}

fn run(
    mollusk: &Mollusk,
    accounts: &[(Pubkey, Account)],
    ix: &Instruction,
) -> mollusk_svm::result::InstructionResult {
    mollusk.process_instruction(ix, accounts)
}

#[test]
fn test_mint_transfer_burn_close_end_to_end() {
    let mollusk = fresh_mollusk();

    let authority = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let alice = Pubkey::new_unique(); // source token account
    let bob = Pubkey::new_unique();   // destination token account

    // -------------------------------------------------------------
    // Initial on-chain state: an initialised mint, two empty token
    // accounts both owned by `authority`. We could reach those via
    // initializeMint2 / initializeAccount3 CPIs, but the goal here
    // is to test our transfer/mint/burn/close — the init path is
    // covered by host unit tests and the byte-layout assertions
    // inside `state.zig`.
    // -------------------------------------------------------------
    let initial_accounts = vec![
        (spl_token_program::keyed_account().0, spl_token_program::keyed_account().1),
        (mint, mint_account(&authority)),
        (alice, token_account(&mint, &authority, 0)),
        (bob, token_account(&mint, &authority, 0)),
        (
            authority,
            Account {
                lamports: 1_000_000,
                data: vec![],
                owner: solana_sdk_ids::system_program::id(),
                executable: false,
                rent_epoch: 0,
            },
        ),
    ];

    // ───────────────────────── 1. mintTo ─────────────────────────
    // mintTo uses `mint`, `destination`, and `authority` — `source`
    // is ignored by the demo dispatcher but the runtime still has
    // to serialize it. Pass `bob` (a real, distinct account) in the
    // source slot to avoid a duplicate-account slot that the SDK's
    // `nextAccountUnchecked` doesn't handle.
    let mut data = vec![0u8]; // tag = mintTo
    data.extend_from_slice(&MINT_AMOUNT.to_le_bytes());
    let ix = build_ix(&mint, &bob, &alice, &authority, data);
    let r1 = run(&mollusk, &initial_accounts, &ix);
    assert!(
        matches!(r1.program_result, ProgramResult::Success),
        "mintTo failed: {:?}",
        r1.program_result,
    );
    println!("mintTo CU: {}", r1.compute_units_consumed);

    // alice now holds MINT_AMOUNT — pull the post-state forward.
    let after_mint = r1.resulting_accounts;
    let alice_balance = TokenAccount::unpack(&account_data(&after_mint, &alice))
        .unwrap()
        .amount;
    assert_eq!(alice_balance, MINT_AMOUNT);

    // ─────────────────── 2. transferChecked ──────────────────────
    let mut data = vec![1u8]; // tag = transferChecked
    data.extend_from_slice(&TRANSFER_AMOUNT.to_le_bytes());
    data.push(DECIMALS);
    let ix = build_ix(&mint, &alice, &bob, &authority, data);
    let r2 = run(&mollusk, &after_mint, &ix);
    assert!(
        matches!(r2.program_result, ProgramResult::Success),
        "transferChecked failed: {:?}",
        r2.program_result,
    );
    println!("transferChecked CU: {}", r2.compute_units_consumed);

    let after_transfer = r2.resulting_accounts;
    let alice_balance = TokenAccount::unpack(&account_data(&after_transfer, &alice))
        .unwrap()
        .amount;
    let bob_balance = TokenAccount::unpack(&account_data(&after_transfer, &bob))
        .unwrap()
        .amount;
    assert_eq!(alice_balance, MINT_AMOUNT - TRANSFER_AMOUNT);
    assert_eq!(bob_balance, TRANSFER_AMOUNT);

    // ───────────────────────── 3. burn ───────────────────────────
    let mut data = vec![2u8]; // tag = burn
    data.extend_from_slice(&BURN_AMOUNT.to_le_bytes());
    let ix = build_ix(&mint, &alice, &bob, &authority, data);
    let r3 = run(&mollusk, &after_transfer, &ix);
    assert!(
        matches!(r3.program_result, ProgramResult::Success),
        "burn failed: {:?}",
        r3.program_result,
    );
    println!("burn CU: {}", r3.compute_units_consumed);

    let after_burn = r3.resulting_accounts;
    let alice_balance = TokenAccount::unpack(&account_data(&after_burn, &alice))
        .unwrap()
        .amount;
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
    let ix = build_ix(&mint, &alice, &bob, &authority, data);
    let r4 = run(&mollusk, &after_burn, &ix);
    assert!(matches!(r4.program_result, ProgramResult::Success));
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
            AccountMeta::new(mint, false),       // unused but kept in layout
            AccountMeta::new(alice, false),      // the account being closed
            AccountMeta::new(lamports_dest, false), // lamports go here
            AccountMeta::new_readonly(authority, true),
        ],
        data,
    };
    let r5 = run(&mollusk, &accts_for_close, &ix);
    assert!(
        matches!(r5.program_result, ProgramResult::Success),
        "closeAccount failed: {:?}",
        r5.program_result,
    );
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

fn account_data(accounts: &[(Pubkey, Account)], key: &Pubkey) -> Vec<u8> {
    accounts
        .iter()
        .find(|(k, _)| k == key)
        .unwrap_or_else(|| panic!("account {key} not in result"))
        .1
        .data
        .clone()
}
