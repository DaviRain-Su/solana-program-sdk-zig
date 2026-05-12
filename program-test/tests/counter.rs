//! Integration test for examples/counter.zig.
//!
//! Verifies that the program's custom error codes actually survive
//! to the wire on the real BPF runtime — the previous slot-stash
//! design passed host tests but failed to deploy on-chain, so these
//! tests are the load-bearing safety net for `ErrorCode`.
//!
//! Covers:
//!   - happy path: Initialize → Increment → state reflects the delta
//!   - Overflow:   delta that overflows u64 → `Custom(6001)`
//!   - NotOwner:   wrong signer → `Custom(6000)`
//!   - Reset:      counter goes back to 0

use {
    mollusk_svm::{program::keyed_account_for_system_program, Mollusk},
    solana_account::Account,
    solana_instruction::{AccountMeta, Instruction},
    solana_program_error::ProgramError,
    solana_pubkey::Pubkey,
    solana_sdk_ids::{bpf_loader_upgradeable, system_program},
};

// Must match `examples/counter.zig`'s `PROGRAM_ID` constant —
// the program uses this when verifying PDA signers via
// `createRentExemptComptimeRaw` → `invokeSignedRaw`.
mod program {
    solana_pubkey::declare_id!("Cou1terZigExamp1eProgram111111111111111111X");
}

/// Account layout from `examples/counter.zig::CounterState`.
///   - discriminator: [8]u8
///   - owner:         [32]u8
///   - count:         u64
///   - bump:          u8
///   - _pad:          [7]u8
const COUNTER_STATE_SIZE: usize = 8 + 32 + 8 + 1 + 7;
const DISCRIMINATOR_OFFSET: usize = 0;
const COUNT_OFFSET: usize = 8 + 32;

/// `sha256("account:Counter")[..8]` — must match
/// `sol.discriminatorFor("Counter")` in the program.
fn counter_discriminator() -> [u8; 8] {
    use solana_sha256_hasher::hashv;
    let h = hashv(&[b"account:Counter"]);
    let mut out = [0u8; 8];
    out.copy_from_slice(&h.to_bytes()[..8]);
    out
}

fn setup() -> (Mollusk, Pubkey, u8) {
    let mut mollusk = Mollusk::default();
    mollusk.add_program(
        &program::id(),
        "zig-out/lib/example_counter",
        &bpf_loader_upgradeable::id(),
    );
    // PDA derived from `["counter", owner.key()]` against the
    // program's own ID. We use a fixed `owner` so the test is
    // deterministic.
    let owner = fixed_owner();
    let (pda, bump) = Pubkey::find_program_address(
        &[b"counter", owner.as_ref()],
        &program::id(),
    );
    (mollusk, pda, bump)
}

/// Stable, well-funded owner so independent tests can re-derive the
/// same PDA without coordinating.
fn fixed_owner() -> Pubkey {
    Pubkey::new_from_array([0x11; 32])
}

fn build_initialize_ix(owner: Pubkey, counter: Pubkey, bump: u8) -> Instruction {
    let (system_pid, _) = keyed_account_for_system_program();
    let mut data = vec![0u8, bump]; // tag=0, bump
    let _ = &mut data; // silence rustfmt cleanup
    Instruction {
        program_id: program::id(),
        accounts: vec![
            AccountMeta::new(owner, true),
            AccountMeta::new(counter, false),
            AccountMeta::new_readonly(system_pid, false),
        ],
        data,
    }
}

fn build_increment_ix(owner: Pubkey, counter: Pubkey, delta: u64) -> Instruction {
    let (system_pid, _) = keyed_account_for_system_program();
    let mut data = vec![1u8]; // tag=1
    data.extend_from_slice(&delta.to_le_bytes());
    Instruction {
        program_id: program::id(),
        accounts: vec![
            AccountMeta::new_readonly(owner, true),
            AccountMeta::new(counter, false),
            AccountMeta::new_readonly(system_pid, false),
        ],
        data,
    }
}

fn build_reset_ix(owner: Pubkey, counter: Pubkey) -> Instruction {
    let (system_pid, _) = keyed_account_for_system_program();
    Instruction {
        program_id: program::id(),
        accounts: vec![
            AccountMeta::new_readonly(owner, true),
            AccountMeta::new(counter, false),
            AccountMeta::new_readonly(system_pid, false),
        ],
        data: vec![2u8],
    }
}

/// Build an empty (uninitialized) counter account — System Program owned,
/// zero data, zero lamports. The program's `createRentExemptComptimeRaw`
/// CPI will populate / re-assign it.
fn empty_owner_account() -> Account {
    Account {
        lamports: 100_000_000,
        data: vec![],
        owner: system_program::id(),
        executable: false,
        rent_epoch: 0,
    }
}

fn empty_counter_account() -> Account {
    Account {
        lamports: 0,
        data: vec![],
        owner: system_program::id(),
        executable: false,
        rent_epoch: 0,
    }
}

/// Pre-initialized counter PDA account holding `count` (no CPI needed).
/// Useful for tests that want to start from a non-zero counter without
/// running `initialize` (which requires a `system_program` CPI that's
/// only available in compose-style test setups).
fn preinitialized_counter_account(owner: Pubkey, count: u64, bump: u8) -> Account {
    let mut data = vec![0u8; COUNTER_STATE_SIZE];
    data[..8].copy_from_slice(&counter_discriminator());
    data[8..40].copy_from_slice(owner.as_ref());
    data[COUNT_OFFSET..COUNT_OFFSET + 8].copy_from_slice(&count.to_le_bytes());
    data[40 + 8] = bump;
    Account {
        lamports: 2_000_000, // arbitrary, rent-exempt for 56 bytes
        data,
        owner: program::id(),
        executable: false,
        rent_epoch: 0,
    }
}

// =========================================================================
// Tests
// =========================================================================

#[test]
fn test_initialize_then_increment_updates_count() {
    let (mollusk, counter, bump) = setup();
    let owner = fixed_owner();
    let (system_pid, system_account) = keyed_account_for_system_program();

    // Step 1: initialize the counter PDA.
    let init_ix = build_initialize_ix(owner, counter, bump);
    let accounts = vec![
        (owner, empty_owner_account()),
        (counter, empty_counter_account()),
        (system_pid, system_account.clone()),
    ];
    let init_result = mollusk.process_instruction(&init_ix, &accounts);
    assert!(
        init_result.program_result.is_ok(),
        "initialize failed: {:?}",
        init_result.program_result
    );

    // Pull out the new counter state.
    let counter_account = init_result
        .resulting_accounts
        .iter()
        .find(|(k, _)| *k == counter)
        .map(|(_, a)| a.clone())
        .expect("counter not in resulting accounts");
    assert_eq!(counter_account.data.len(), COUNTER_STATE_SIZE);
    assert_eq!(
        &counter_account.data[DISCRIMINATOR_OFFSET..8],
        &counter_discriminator(),
        "discriminator mismatch — TypedAccount didn't write it",
    );
    assert_eq!(
        &counter_account.data[COUNT_OFFSET..COUNT_OFFSET + 8],
        &0u64.to_le_bytes(),
        "fresh counter should have count = 0",
    );

    // Step 2: increment by 42.
    let owner_account_post_init = init_result
        .resulting_accounts
        .iter()
        .find(|(k, _)| *k == owner)
        .map(|(_, a)| a.clone())
        .expect("owner not in resulting accounts");
    let inc_ix = build_increment_ix(owner, counter, 42);
    let result = mollusk.process_instruction(
        &inc_ix,
        &[
            (owner, owner_account_post_init),
            (counter, counter_account),
            (system_pid, system_account),
        ],
    );
    assert!(
        result.program_result.is_ok(),
        "increment failed: {:?}",
        result.program_result
    );

    let counter_final = &result
        .resulting_accounts
        .iter()
        .find(|(k, _)| *k == counter)
        .expect("counter not in result")
        .1
        .data;
    assert_eq!(
        &counter_final[COUNT_OFFSET..COUNT_OFFSET + 8],
        &42u64.to_le_bytes(),
        "expected count=42 after increment(42)",
    );

    println!(
        "counter init+inc consumed {} CU",
        init_result.compute_units_consumed + result.compute_units_consumed
    );
}

#[test]
fn test_increment_overflow_returns_custom_6001() {
    // Pre-load the counter with count = u64::MAX - 1, then ask for +5
    // → checked add must overflow → `CounterErr.toError(.Overflow)`
    // → wire `Custom(6001)`.
    let (mollusk, counter, bump) = setup();
    let owner = fixed_owner();
    let (system_pid, system_account) = keyed_account_for_system_program();

    let ix = build_increment_ix(owner, counter, 5);
    let accounts = vec![
        (owner, empty_owner_account()),
        (
            counter,
            preinitialized_counter_account(owner, u64::MAX - 1, bump),
        ),
        (system_pid, system_account),
    ];
    let result = mollusk.process_instruction(&ix, &accounts);

    match result.program_result {
        mollusk_svm::result::ProgramResult::Failure(ref err) => {
            assert_eq!(
                err,
                &ProgramError::Custom(6001),
                "expected Custom(6001) (Overflow), got {err:?}",
            );
        }
        other => panic!("expected program to fail with Overflow, got {other:?}"),
    }
}

#[test]
fn test_increment_wrong_owner_returns_custom_6000() {
    // Run `increment` with a signer that doesn't match the PDA's
    // stored `owner` → `requireHasOneWith` must return
    // `CounterErr.toError(.NotOwner)` → wire `Custom(6000)`.
    let (mollusk, counter, bump) = setup();
    let real_owner = fixed_owner();
    let imposter = Pubkey::new_from_array([0x22; 32]);
    let (system_pid, system_account) = keyed_account_for_system_program();

    let ix = build_increment_ix(imposter, counter, 1);
    let accounts = vec![
        (imposter, empty_owner_account()),
        (
            counter,
            preinitialized_counter_account(real_owner, 0, bump),
        ),
        (system_pid, system_account),
    ];
    let result = mollusk.process_instruction(&ix, &accounts);

    match result.program_result {
        mollusk_svm::result::ProgramResult::Failure(ref err) => {
            assert_eq!(
                err,
                &ProgramError::Custom(6000),
                "expected Custom(6000) (NotOwner), got {err:?}",
            );
        }
        other => panic!("expected program to fail with NotOwner, got {other:?}"),
    }
}

#[test]
fn test_reset_zeroes_count() {
    let (mollusk, counter, bump) = setup();
    let owner = fixed_owner();
    let (system_pid, system_account) = keyed_account_for_system_program();

    let ix = build_reset_ix(owner, counter);
    let accounts = vec![
        (owner, empty_owner_account()),
        (
            counter,
            preinitialized_counter_account(owner, 999_999, bump),
        ),
        (system_pid, system_account),
    ];
    let result = mollusk.process_instruction(&ix, &accounts);
    assert!(
        result.program_result.is_ok(),
        "reset failed: {:?}",
        result.program_result
    );

    let final_count = &result
        .resulting_accounts
        .iter()
        .find(|(k, _)| *k == counter)
        .expect("counter missing")
        .1
        .data[COUNT_OFFSET..COUNT_OFFSET + 8];
    assert_eq!(final_count, &0u64.to_le_bytes());
}
