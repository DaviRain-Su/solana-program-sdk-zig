// This test requires a BPF program to be built first.
// BPF builds are disabled in CI due to stack overflow issues with base58 big integer operations.
// To run this test locally:
//   1. cd .. && ./solana-zig/zig build -Dtarget=sbf-solana
//   2. cargo test -- --ignored

use {
    mollusk_svm::Mollusk,
    solana_sdk::{instruction::Instruction, pubkey::Pubkey},
    std::str::FromStr,
};

const BPF_LOADER_UPGRADEABLE_ID: Pubkey =
    solana_sdk::pubkey!("BPFLoaderUpgradeab1e11111111111111111111111");

mod program {
    use super::*;
    pub fn id() -> Pubkey {
        Pubkey::from_str("Zigc1Hc97L8Pebma74jDzYiyoUvdxxcj7Gxppg9VRxK").unwrap()
    }
}

#[test]
#[ignore = "Requires BPF program build which is disabled in CI"]
fn test_run() {
    let mut mollusk = Mollusk::default();

    mollusk.add_program(
        &program::id(),
        "zig-out/lib/pubkey",
        &BPF_LOADER_UPGRADEABLE_ID,
    );

    let instruction = Instruction {
        program_id: program::id(),
        accounts: vec![],
        data: vec![],
    };

    let accounts = vec![];
    let result = mollusk.process_instruction(&instruction, &accounts);

    assert!(result.program_result.is_ok());
}
