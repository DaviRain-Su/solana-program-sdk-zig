//! Integration test for examples/pubkey.zig.
//!
//! Exercises the SDK's pubkey + PDA API end-to-end on the BPF
//! runtime:
//!   - `DerivePda`:  syscall path returns the canonical PDA + bump
//!   - `VerifyPda`:  correct bump succeeds, wrong bump returns
//!                   InvalidSeeds
//!   - `CheckOwner`: pubkeyEqAny whitelist accepts/rejects correctly

use {
    mollusk_svm::Mollusk,
    solana_account::Account,
    solana_instruction::{AccountMeta, Instruction},
    solana_program_error::ProgramError,
    solana_pubkey::Pubkey,
    solana_sdk_ids::{bpf_loader_upgradeable, system_program},
};

mod program {
    solana_pubkey::declare_id!("Zigc1Hc97L8Pebma74jDzYiyoUvdxxcj7Gxppg9VRxK");
}

const SEED_PREFIX: &[u8] = b"pubkey-example";

fn setup() -> Mollusk {
    let mut mollusk = Mollusk::default();
    mollusk.add_program(
        &program::id(),
        "zig-out/lib/pubkey",
        &bpf_loader_upgradeable::id(),
    );
    mollusk
}

fn empty_account(owner: Pubkey) -> Account {
    Account {
        lamports: 1_000_000,
        data: vec![],
        owner,
        executable: false,
        rent_epoch: 0,
    }
}

fn caller() -> Pubkey {
    Pubkey::new_from_array([0x55; 32])
}

fn build_ix(tag: u8, extra: Option<u8>, accounts: Vec<AccountMeta>) -> Instruction {
    let mut data = vec![tag];
    if let Some(b) = extra {
        data.push(b);
    }
    Instruction {
        program_id: program::id(),
        accounts,
        data,
    }
}

// =========================================================================
// ix=0  DerivePda
// =========================================================================

#[test]
fn test_derive_pda_returns_address_and_bump() {
    let mollusk = setup();
    let caller = caller();
    // Use a dummy second account — the program parses 2 accounts
    // unconditionally but DerivePda ignores `target`.
    let dummy = Pubkey::new_from_array([0xaa; 32]);

    let ix = build_ix(
        0,
        None,
        vec![
            AccountMeta::new_readonly(caller, true),
            AccountMeta::new_readonly(dummy, false),
        ],
    );
    let accounts = vec![
        (caller, empty_account(system_program::id())),
        (dummy, empty_account(system_program::id())),
    ];

    let result = mollusk.process_instruction(&ix, &accounts);
    assert!(
        result.program_result.is_ok(),
        "derive_pda failed: {:?}",
        result.program_result
    );
    assert_eq!(result.return_data.len(), 33, "expected 32+1 return bytes");

    // The first 32 bytes are the address, the last byte is the bump.
    let mut on_chain_addr = [0u8; 32];
    on_chain_addr.copy_from_slice(&result.return_data[..32]);
    let on_chain_bump = result.return_data[32];

    // Off-chain derivation must agree with the on-chain syscall.
    let (off_chain_addr, off_chain_bump) =
        Pubkey::find_program_address(&[SEED_PREFIX, caller.as_ref()], &program::id());

    assert_eq!(on_chain_addr, off_chain_addr.to_bytes());
    assert_eq!(on_chain_bump, off_chain_bump);
}

// =========================================================================
// ix=1  VerifyPda
// =========================================================================

#[test]
fn test_verify_pda_accepts_canonical_bump() {
    let mollusk = setup();
    let caller = caller();
    let (pda, bump) = Pubkey::find_program_address(
        &[SEED_PREFIX, caller.as_ref()],
        &program::id(),
    );

    let ix = build_ix(
        1,
        Some(bump),
        vec![
            AccountMeta::new_readonly(caller, true),
            AccountMeta::new_readonly(pda, false),
        ],
    );
    let accounts = vec![
        (caller, empty_account(system_program::id())),
        (pda, empty_account(system_program::id())),
    ];

    let result = mollusk.process_instruction(&ix, &accounts);
    assert!(
        result.program_result.is_ok(),
        "verify_pda with correct bump failed: {:?}",
        result.program_result
    );
}

#[test]
fn test_verify_pda_rejects_wrong_bump() {
    let mollusk = setup();
    let caller = caller();
    let (pda, bump) = Pubkey::find_program_address(
        &[SEED_PREFIX, caller.as_ref()],
        &program::id(),
    );

    // Lie about the bump. With overwhelming probability `bump - 1`
    // gives a different derived address (or no valid one), so
    // `verifyPda` must return InvalidSeeds.
    let wrong_bump = bump.wrapping_sub(1);
    let ix = build_ix(
        1,
        Some(wrong_bump),
        vec![
            AccountMeta::new_readonly(caller, true),
            AccountMeta::new_readonly(pda, false),
        ],
    );
    let accounts = vec![
        (caller, empty_account(system_program::id())),
        (pda, empty_account(system_program::id())),
    ];

    let result = mollusk.process_instruction(&ix, &accounts);
    match result.program_result {
        mollusk_svm::result::ProgramResult::Failure(ref err) => {
            assert_eq!(
                err,
                &ProgramError::InvalidSeeds,
                "expected InvalidSeeds, got {err:?}",
            );
        }
        other => panic!("expected InvalidSeeds failure, got {other:?}"),
    }
}

// =========================================================================
// ix=2  CheckOwner
// =========================================================================

#[test]
fn test_check_owner_accepts_whitelisted() {
    let mollusk = setup();
    let caller = caller();
    let target = Pubkey::new_from_array([0xbb; 32]);

    // Target owned by System Program → whitelisted.
    let ix = build_ix(
        2,
        None,
        vec![
            AccountMeta::new_readonly(caller, true),
            AccountMeta::new_readonly(target, false),
        ],
    );
    let accounts = vec![
        (caller, empty_account(system_program::id())),
        (target, empty_account(system_program::id())),
    ];

    let result = mollusk.process_instruction(&ix, &accounts);
    assert!(
        result.program_result.is_ok(),
        "check_owner (system) failed: {:?}",
        result.program_result
    );

    // BPF Loader Upgradeable is also in the whitelist.
    let target2 = Pubkey::new_from_array([0xcc; 32]);
    let ix2 = build_ix(
        2,
        None,
        vec![
            AccountMeta::new_readonly(caller, true),
            AccountMeta::new_readonly(target2, false),
        ],
    );
    let accounts2 = vec![
        (caller, empty_account(system_program::id())),
        (target2, empty_account(bpf_loader_upgradeable::id())),
    ];
    let r2 = mollusk.process_instruction(&ix2, &accounts2);
    assert!(
        r2.program_result.is_ok(),
        "check_owner (loader) failed: {:?}",
        r2.program_result
    );
}

#[test]
fn test_check_owner_rejects_unknown() {
    let mollusk = setup();
    let caller = caller();
    let target = Pubkey::new_from_array([0xdd; 32]);
    let imposter_owner = Pubkey::new_from_array([0xee; 32]);

    let ix = build_ix(
        2,
        None,
        vec![
            AccountMeta::new_readonly(caller, true),
            AccountMeta::new_readonly(target, false),
        ],
    );
    let accounts = vec![
        (caller, empty_account(system_program::id())),
        (target, empty_account(imposter_owner)),
    ];

    let result = mollusk.process_instruction(&ix, &accounts);
    match result.program_result {
        mollusk_svm::result::ProgramResult::Failure(ref err) => {
            assert_eq!(
                err,
                &ProgramError::IncorrectProgramId,
                "expected IncorrectProgramId, got {err:?}",
            );
        }
        other => panic!("expected IncorrectProgramId failure, got {other:?}"),
    }
}
