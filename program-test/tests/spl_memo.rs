//! Integration test for the `spl-memo` sub-package.
//!
//! This is the test that proves the sub-package isn't lying: it
//! deploys a tiny Zig program built against `spl_memo.cpi.memo(...)`
//! into a real Mollusk VM **alongside the official SPL Memo `.so`**
//! shipped by `mollusk-svm-programs-memo`, then exercises both the
//! no-signer and signer code paths via CPI.
//!
//! If the bytes our `instruction.memo` builder produces don't match
//! what the real SPL Memo program expects, this test fails — host
//! unit tests in the package alone can't catch that class of bug.

use {
    mollusk_svm::{result::ProgramResult, Mollusk},
    mollusk_svm_programs_memo::memo as memo_program,
    solana_account::Account,
    solana_instruction::{AccountMeta, Instruction},
    solana_pubkey::Pubkey,
    solana_sdk_ids::bpf_loader_upgradeable,
};

mod program {
    solana_pubkey::declare_id!("Zigc1Hc97L8Pebma74jDzYiyoUvdxxcj7Gxppg9VRxK");
}

fn fresh_mollusk() -> Mollusk {
    let mut mollusk = Mollusk::default();
    // Our Zig program — emits a memo via CPI.
    mollusk.add_program(
        &program::id(),
        "zig-out/lib/example_spl_memo_cpi",
        &bpf_loader_upgradeable::id(),
    );
    // Real on-chain SPL Memo program (v2). Loaded from the
    // pre-built `.so` shipped inside the `mollusk-svm-programs-memo`
    // crate — no manual `solana program dump` needed.
    memo_program::add_program(&mut mollusk);
    mollusk
}

fn run(
    mollusk: &Mollusk,
    message: &[u8],
    signers: &[Pubkey],
) -> mollusk_svm::result::InstructionResult {
    let (memo_pid, memo_account) = memo_program::keyed_account();

    let mut metas = vec![AccountMeta::new_readonly(memo_pid, false)];
    for s in signers {
        metas.push(AccountMeta::new_readonly(*s, true));
    }

    let instruction = Instruction {
        program_id: program::id(),
        accounts: metas,
        data: message.to_vec(),
    };

    let mut accounts = vec![(memo_pid, memo_account.clone())];
    for s in signers {
        // Signers carry no balance / data — they only need to exist
        // for the runtime to satisfy the signer constraint.
        accounts.push((
            *s,
            Account {
                lamports: 0,
                data: vec![],
                owner: solana_sdk_ids::system_program::id(),
                executable: false,
                rent_epoch: 0,
            },
        ));
    }

    mollusk.process_instruction(&instruction, &accounts)
}

#[test]
fn test_memo_no_signers() {
    let mollusk = fresh_mollusk();
    let result = run(&mollusk, b"hello from zig", &[]);
    assert!(
        matches!(result.program_result, ProgramResult::Success),
        "memo CPI failed: {:?}",
        result.program_result,
    );
    println!(
        "spl-memo no-signer CPI consumed {} CU",
        result.compute_units_consumed,
    );
}

#[test]
fn test_memo_with_signers() {
    let mollusk = fresh_mollusk();
    let signer_a = Pubkey::new_unique();
    let signer_b = Pubkey::new_unique();
    let result = run(&mollusk, b"signed memo", &[signer_a, signer_b]);
    assert!(
        matches!(result.program_result, ProgramResult::Success),
        "signed memo CPI failed: {:?}",
        result.program_result,
    );
    println!(
        "spl-memo 2-signer CPI consumed {} CU",
        result.compute_units_consumed,
    );
}
