//! Integration tests for the Hello World program
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
    /// Program ID - derived from zig-out/lib/hello_world-keypair.json
    pub fn id() -> Pubkey {
        Pubkey::from_str("6dC4SnTEP9Gs8FbqDJZ6dM26npFeHgyPEYcWJaGnY9PT").unwrap()
    }
}

#[test]
#[ignore = "Requires BPF program build - run with: cargo test -- --ignored"]
fn test_hello_world_no_accounts() {
    let mut mollusk = Mollusk::default();

    mollusk.add_program(
        &program::id(),
        "zig-out/lib/hello_world",
        &BPF_LOADER_UPGRADEABLE_ID,
    );

    let instruction = Instruction {
        program_id: program::id(),
        accounts: vec![],
        data: vec![],
    };

    let result = mollusk.process_instruction(&instruction, &[]);
    assert!(result.program_result.is_ok());
}

#[test]
#[ignore = "Requires BPF program build - run with: cargo test -- --ignored"]
fn test_hello_world_with_accounts() {
    let mut mollusk = Mollusk::default();

    mollusk.add_program(
        &program::id(),
        "zig-out/lib/hello_world",
        &BPF_LOADER_UPGRADEABLE_ID,
    );

    let user = Pubkey::new_unique();
    let user_account = Account::new(1_000_000_000, 0, &Pubkey::default());

    let instruction = Instruction {
        program_id: program::id(),
        accounts: vec![AccountMeta::new(user, true)],
        data: vec![],
    };

    let result = mollusk.process_instruction(&instruction, &[(user, user_account)]);
    assert!(result.program_result.is_ok());
}

#[test]
#[ignore = "Requires BPF program build - run with: cargo test -- --ignored"]
fn test_hello_world_with_data() {
    let mut mollusk = Mollusk::default();

    mollusk.add_program(
        &program::id(),
        "zig-out/lib/hello_world",
        &BPF_LOADER_UPGRADEABLE_ID,
    );

    let instruction = Instruction {
        program_id: program::id(),
        accounts: vec![],
        data: vec![1, 2, 3, 4, 5],
    };

    let result = mollusk.process_instruction(&instruction, &[]);
    assert!(result.program_result.is_ok());
}
