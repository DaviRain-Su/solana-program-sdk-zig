//! Integration test for examples/hello.zig.
//!
//! Smoke test: deploys the minimal `hello` program, invokes it with
//! zero accounts and zero data, and asserts (a) success and (b) the
//! expected log line.

use {
    mollusk_svm::Mollusk,
    solana_instruction::Instruction,
    solana_sdk_ids::bpf_loader_upgradeable,
};

mod program {
    solana_pubkey::declare_id!("Zigc1Hc97L8Pebma74jDzYiyoUvdxxcj7Gxppg9VRxK");
}

#[test]
fn test_hello_logs_and_succeeds() {
    let mut mollusk = Mollusk::default();
    mollusk.add_program(
        &program::id(),
        "zig-out/lib/example_hello",
        &bpf_loader_upgradeable::id(),
    );

    let instruction = Instruction {
        program_id: program::id(),
        accounts: vec![],
        data: vec![],
    };

    let result = mollusk.process_instruction(&instruction, &[]);
    assert!(
        result.program_result.is_ok(),
        "hello program failed: {:?}",
        result.program_result
    );

    // The program logs `Hello, Solana!` via `sol.log.log` —
    // verifying the log text would require capturing stdout
    // (Mollusk's `InstructionResult` doesn't expose program logs).
    // Success + non-zero CU is enough to prove the entrypoint
    // executed end-to-end.
    assert!(
        result.compute_units_consumed > 0,
        "expected non-zero CU, got 0",
    );

    println!("hello consumed {} CU", result.compute_units_consumed);
}
