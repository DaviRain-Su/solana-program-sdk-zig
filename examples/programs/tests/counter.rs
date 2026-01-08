//! Integration tests for the Counter program
//!
//! To run these tests:
//! 1. Build the program: ../../solana-zig/zig build
//! 2. Run tests: cargo test -- --ignored

use {
    mollusk_svm::Mollusk,
    solana_sdk::{
        account::Account,
        instruction::{AccountMeta, Instruction},
        pubkey::Pubkey,
    },
    std::str::FromStr,
};

const BPF_LOADER_UPGRADEABLE_ID: Pubkey =
    solana_sdk::pubkey!("BPFLoaderUpgradeab1e11111111111111111111111");

mod program {
    use super::*;
    /// Program ID - derived from zig-out/lib/counter-keypair.json
    pub fn id() -> Pubkey {
        Pubkey::from_str("HsLRmdn9WRVhjBhbCL1AC6BdsKn2cJBKR6CoFkSERGPd").unwrap()
    }
}

/// Counter instruction discriminators
mod instruction {
    pub const INITIALIZE: u8 = 0;
    pub const INCREMENT: u8 = 1;
    pub const DECREMENT: u8 = 2;
}

/// Counter account data size (u64 = 8 bytes)
const COUNTER_SIZE: usize = 8;

fn create_counter_account(program_id: &Pubkey) -> Account {
    Account::new(1_000_000_000, COUNTER_SIZE, program_id)
}

#[test]
#[ignore = "Requires BPF program build - run with: cargo test -- --ignored"]
fn test_counter_initialize() {
    let mut mollusk = Mollusk::default();

    mollusk.add_program(
        &program::id(),
        "zig-out/lib/counter",
        &BPF_LOADER_UPGRADEABLE_ID,
    );

    let counter_pubkey = Pubkey::new_unique();
    let authority = Pubkey::new_unique();

    let counter_account = create_counter_account(&program::id());
    let authority_account = Account::new(1_000_000_000, 0, &Pubkey::default());

    let instruction = Instruction {
        program_id: program::id(),
        accounts: vec![
            AccountMeta::new(counter_pubkey, false),
            AccountMeta::new_readonly(authority, true),
        ],
        data: vec![instruction::INITIALIZE],
    };

    let result = mollusk.process_instruction(
        &instruction,
        &[
            (counter_pubkey, counter_account),
            (authority, authority_account),
        ],
    );

    assert!(result.program_result.is_ok(), "Initialize should succeed");
}

#[test]
#[ignore = "Requires BPF program build - run with: cargo test -- --ignored"]
fn test_counter_increment() {
    let mut mollusk = Mollusk::default();

    mollusk.add_program(
        &program::id(),
        "zig-out/lib/counter",
        &BPF_LOADER_UPGRADEABLE_ID,
    );

    let counter_pubkey = Pubkey::new_unique();

    // Create counter account with initial value 0, owned by program
    let mut counter_account = create_counter_account(&program::id());
    counter_account.data[..8].copy_from_slice(&0u64.to_le_bytes());

    let instruction = Instruction {
        program_id: program::id(),
        accounts: vec![AccountMeta::new(counter_pubkey, false)],
        data: vec![instruction::INCREMENT],
    };

    let result = mollusk.process_instruction(&instruction, &[(counter_pubkey, counter_account)]);

    assert!(result.program_result.is_ok(), "Increment should succeed");
}

#[test]
#[ignore = "Requires BPF program build - run with: cargo test -- --ignored"]
fn test_counter_decrement() {
    let mut mollusk = Mollusk::default();

    mollusk.add_program(
        &program::id(),
        "zig-out/lib/counter",
        &BPF_LOADER_UPGRADEABLE_ID,
    );

    let counter_pubkey = Pubkey::new_unique();

    // Create counter account with initial value 5
    let mut counter_account = create_counter_account(&program::id());
    counter_account.data[..8].copy_from_slice(&5u64.to_le_bytes());

    let instruction = Instruction {
        program_id: program::id(),
        accounts: vec![AccountMeta::new(counter_pubkey, false)],
        data: vec![instruction::DECREMENT],
    };

    let result = mollusk.process_instruction(&instruction, &[(counter_pubkey, counter_account)]);

    assert!(result.program_result.is_ok(), "Decrement should succeed");
}

#[test]
#[ignore = "Requires BPF program build - run with: cargo test -- --ignored"]
fn test_counter_decrement_underflow() {
    let mut mollusk = Mollusk::default();

    mollusk.add_program(
        &program::id(),
        "zig-out/lib/counter",
        &BPF_LOADER_UPGRADEABLE_ID,
    );

    let counter_pubkey = Pubkey::new_unique();

    // Create counter account with value 0
    let mut counter_account = create_counter_account(&program::id());
    counter_account.data[..8].copy_from_slice(&0u64.to_le_bytes());

    let instruction = Instruction {
        program_id: program::id(),
        accounts: vec![AccountMeta::new(counter_pubkey, false)],
        data: vec![instruction::DECREMENT],
    };

    let result = mollusk.process_instruction(&instruction, &[(counter_pubkey, counter_account)]);

    assert!(
        result.program_result.is_err(),
        "Decrement from 0 should fail"
    );
}

#[test]
#[ignore = "Requires BPF program build - run with: cargo test -- --ignored"]
fn test_counter_invalid_instruction() {
    let mut mollusk = Mollusk::default();

    mollusk.add_program(
        &program::id(),
        "zig-out/lib/counter",
        &BPF_LOADER_UPGRADEABLE_ID,
    );

    let counter_pubkey = Pubkey::new_unique();
    let counter_account = create_counter_account(&program::id());

    let instruction = Instruction {
        program_id: program::id(),
        accounts: vec![AccountMeta::new(counter_pubkey, false)],
        data: vec![], // Empty data = invalid
    };

    let result = mollusk.process_instruction(&instruction, &[(counter_pubkey, counter_account)]);

    assert!(
        result.program_result.is_err(),
        "Empty instruction data should fail"
    );
}
