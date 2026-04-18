use {
    mollusk_svm::Mollusk, solana_instruction::Instruction, solana_sdk_ids::bpf_loader_upgradeable,
};

mod program {
    solana_pubkey::declare_id!("6dC4SnTEP9Gs8FbqDJZ6dM26npFeHgyPEYcWJaGnY9PT");
}

#[test]
fn test_run() {
    let mut mollusk = Mollusk::default();

    mollusk.add_program(
        &program::id(),
        "zig-out/lib/hello_world",
        &bpf_loader_upgradeable::id(),
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
