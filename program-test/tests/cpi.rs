//! Integration test for the CPI program (program-test/cpi/main.zig).
//!
//! The program transfers `amount` lamports from `from` (signer) to `to`
//! via a System Program CPI.

use {
    mollusk_svm::{program::keyed_account_for_system_program, Mollusk},
    solana_account::Account,
    solana_instruction::{AccountMeta, Instruction},
    solana_pubkey::Pubkey,
    solana_sdk_ids::{bpf_loader_upgradeable, system_program},
};

mod program {
    solana_pubkey::declare_id!("Zigc1Hc97L8Pebma74jDzYiyoUvdxxcj7Gxppg9VRxK");
}

const FROM_LAMPORTS: u64 = 10_000_000;
const TO_LAMPORTS: u64 = 1_000_000;
const TRANSFER_AMOUNT: u64 = 250_000;

#[test]
fn test_cpi_transfer() {
    let mut mollusk = Mollusk::default();
    mollusk.add_program(
        &program::id(),
        "zig-out/lib/cpi",
        &bpf_loader_upgradeable::id(),
    );

    let from = Pubkey::new_unique();
    let to = Pubkey::new_unique();
    let (system_pid, system_account) = keyed_account_for_system_program();

    // `from` must be owned by the System Program in order for the
    // System Program transfer CPI to debit it.
    let from_account = Account {
        lamports: FROM_LAMPORTS,
        data: vec![],
        owner: system_program::id(),
        executable: false,
        rent_epoch: 0,
    };
    let to_account = Account {
        lamports: TO_LAMPORTS,
        data: vec![],
        owner: system_program::id(),
        executable: false,
        rent_epoch: 0,
    };

    let instruction = Instruction {
        program_id: program::id(),
        accounts: vec![
            AccountMeta::new(from, true),
            AccountMeta::new(to, false),
            AccountMeta::new_readonly(system_pid, false),
        ],
        data: TRANSFER_AMOUNT.to_le_bytes().to_vec(),
    };

    let accounts = vec![
        (from, from_account),
        (to, to_account),
        (system_pid, system_account),
    ];

    let result = mollusk.process_instruction(&instruction, &accounts);

    assert!(
        result.program_result.is_ok(),
        "cpi program failed: {:?}",
        result.program_result
    );

    let resulting_from = result
        .resulting_accounts
        .iter()
        .find(|(k, _)| *k == from)
        .expect("from account missing")
        .1
        .lamports;
    let resulting_to = result
        .resulting_accounts
        .iter()
        .find(|(k, _)| *k == to)
        .expect("to account missing")
        .1
        .lamports;

    assert_eq!(resulting_from, FROM_LAMPORTS - TRANSFER_AMOUNT);
    assert_eq!(resulting_to, TO_LAMPORTS + TRANSFER_AMOUNT);

    println!("CPI transfer consumed {} CU", result.compute_units_consumed);
}

#[test]
fn test_cpi_insufficient_accounts_fails() {
    let mut mollusk = Mollusk::default();
    mollusk.add_program(
        &program::id(),
        "zig-out/lib/cpi",
        &bpf_loader_upgradeable::id(),
    );

    let from = Pubkey::new_unique();
    let (system_pid, system_account) = keyed_account_for_system_program();

    let from_account = Account {
        lamports: FROM_LAMPORTS,
        data: vec![],
        owner: system_program::id(),
        executable: false,
        rent_epoch: 0,
    };

    // Only 2 accounts supplied; program requires 3.
    let instruction = Instruction {
        program_id: program::id(),
        accounts: vec![
            AccountMeta::new(from, true),
            AccountMeta::new_readonly(system_pid, false),
        ],
        data: TRANSFER_AMOUNT.to_le_bytes().to_vec(),
    };

    let accounts = vec![(from, from_account), (system_pid, system_account)];

    let result = mollusk.process_instruction(&instruction, &accounts);
    assert!(
        result.program_result.is_err(),
        "expected program to fail on missing account"
    );
}
