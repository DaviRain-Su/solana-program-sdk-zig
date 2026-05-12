//! Integration test for examples/escrow.zig.
//!
//! Covers the three escrow lifecycle paths plus two error cases:
//!   - Make → Take happy path
//!   - Make → Refund
//!   - Take with insufficient taker funds → Custom(6001)
//!   - Take with wrong maker → Custom(6000)
//!
//! All five scenarios run on the real BPF runtime via Mollusk; the
//! `Custom(N)` assertions in particular are load-bearing — they
//! protect the `ErrorCode` design from any future regression that
//! collapses custom codes to `Custom(0)` / `CUSTOM_ZERO`.

use {
    mollusk_svm::{program::keyed_account_for_system_program, Mollusk},
    solana_account::Account,
    solana_instruction::{AccountMeta, Instruction},
    solana_program_error::ProgramError,
    solana_pubkey::Pubkey,
    solana_sdk_ids::{bpf_loader_upgradeable, system_program},
};

// Must match the `PROGRAM_ID` constant in `examples/escrow.zig`.
mod program {
    solana_pubkey::declare_id!("Zigc1Hc97L8Pebma74jDzYiyoUvdxxcj7Gxppg9VRxK");
}

/// `EscrowState` layout from `examples/escrow.zig`:
///   discriminator: [8]u8 — sha256("account:Escrow")[..8]
///   maker:         [32]u8
///   offered:       u64
///   requested:     u64
///   bump:          u8
///   _pad:          [7]u8
const ESCROW_STATE_SIZE: usize = 8 + 32 + 8 + 8 + 1 + 7;

fn escrow_discriminator() -> [u8; 8] {
    use solana_sha256_hasher::hashv;
    let h = hashv(&[b"account:Escrow"]);
    let mut out = [0u8; 8];
    out.copy_from_slice(&h.to_bytes()[..8]);
    out
}

const MAKER_INITIAL: u64 = 10_000_000_000;
const TAKER_INITIAL: u64 = 10_000_000_000;
const OFFERED: u64 = 1_000_000_000;
const REQUESTED: u64 = 500_000_000;

fn fixed_maker() -> Pubkey {
    Pubkey::new_from_array([0x33; 32])
}
fn fixed_taker() -> Pubkey {
    Pubkey::new_from_array([0x44; 32])
}

fn setup_mollusk() -> Mollusk {
    let mut mollusk = Mollusk::default();
    mollusk.add_program(
        &program::id(),
        "zig-out/lib/example_escrow",
        &bpf_loader_upgradeable::id(),
    );
    mollusk
}

fn derive_escrow(maker: &Pubkey) -> (Pubkey, u8) {
    Pubkey::find_program_address(&[b"escrow", maker.as_ref()], &program::id())
}

fn build_make_ix(
    maker: Pubkey,
    escrow: Pubkey,
    bump: u8,
    offered: u64,
    requested: u64,
) -> Instruction {
    let (system_pid, _) = keyed_account_for_system_program();
    let mut data = Vec::with_capacity(1 + 1 + 8 + 8);
    data.push(0u8); // tag = make
    data.push(bump);
    data.extend_from_slice(&offered.to_le_bytes());
    data.extend_from_slice(&requested.to_le_bytes());
    Instruction {
        program_id: program::id(),
        accounts: vec![
            AccountMeta::new(maker, true),
            AccountMeta::new(escrow, false),
            AccountMeta::new_readonly(system_pid, false),
        ],
        data,
    }
}

fn build_take_ix(taker: Pubkey, maker: Pubkey, escrow: Pubkey) -> Instruction {
    Instruction {
        program_id: program::id(),
        accounts: vec![
            AccountMeta::new(taker, true),
            AccountMeta::new(maker, false),
            AccountMeta::new(escrow, false),
        ],
        data: vec![1u8], // tag = take
    }
}

fn build_refund_ix(maker: Pubkey, escrow: Pubkey, filler: Pubkey) -> Instruction {
    // The dispatcher unconditionally parses 3 accounts; for refund
    // we still need to pass a placeholder third slot. The filler
    // **must be a distinct pubkey** from the maker/escrow — Solana's
    // input format uses a dup-marker for repeated accounts, and
    // `parseAccountsUnchecked` skips the dup-aware switch.
    Instruction {
        program_id: program::id(),
        accounts: vec![
            AccountMeta::new(maker, true),
            AccountMeta::new(escrow, false),
            AccountMeta::new_readonly(filler, false),
        ],
        data: vec![2u8], // tag = refund
    }
}

fn system_owned(lamports: u64) -> Account {
    Account {
        lamports,
        data: vec![],
        owner: system_program::id(),
        executable: false,
        rent_epoch: 0,
    }
}

fn empty_pda() -> Account {
    Account {
        lamports: 0,
        data: vec![],
        owner: system_program::id(),
        executable: false,
        rent_epoch: 0,
    }
}

fn preinitialized_escrow(
    maker: Pubkey,
    offered: u64,
    requested: u64,
    bump: u8,
    extra_lamports: u64,
) -> Account {
    let mut data = vec![0u8; ESCROW_STATE_SIZE];
    data[..8].copy_from_slice(&escrow_discriminator());
    data[8..40].copy_from_slice(maker.as_ref());
    data[40..48].copy_from_slice(&offered.to_le_bytes());
    data[48..56].copy_from_slice(&requested.to_le_bytes());
    data[56] = bump;
    Account {
        // Rent-exempt minimum for 56 bytes + the actual offered lamports.
        lamports: 2_000_000 + extra_lamports,
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
fn test_make_then_take_happy_path() {
    let mollusk = setup_mollusk();
    let maker = fixed_maker();
    let taker = fixed_taker();
    let (escrow, bump) = derive_escrow(&maker);
    let (system_pid, system_account) = keyed_account_for_system_program();

    // === Make ===
    let make_ix = build_make_ix(maker, escrow, bump, OFFERED, REQUESTED);
    let accounts = vec![
        (maker, system_owned(MAKER_INITIAL)),
        (escrow, empty_pda()),
        (system_pid, system_account.clone()),
    ];
    let make_result = mollusk.process_instruction(&make_ix, &accounts);
    assert!(
        make_result.program_result.is_ok(),
        "make failed: {:?}",
        make_result.program_result
    );

    let maker_after_make = make_result
        .resulting_accounts
        .iter()
        .find(|(k, _)| *k == maker)
        .map(|(_, a)| a.clone())
        .unwrap();
    let escrow_after_make = make_result
        .resulting_accounts
        .iter()
        .find(|(k, _)| *k == escrow)
        .map(|(_, a)| a.clone())
        .unwrap();

    assert!(
        maker_after_make.lamports < MAKER_INITIAL - OFFERED,
        "maker should have lost OFFERED + rent + fees",
    );
    assert!(
        escrow_after_make.lamports >= OFFERED,
        "escrow should hold at least OFFERED lamports",
    );

    // === Take ===
    let take_ix = build_take_ix(taker, maker, escrow);
    let take_accounts = vec![
        (taker, system_owned(TAKER_INITIAL)),
        (maker, maker_after_make.clone()),
        (escrow, escrow_after_make.clone()),
    ];
    let take_result = mollusk.process_instruction(&take_ix, &take_accounts);
    assert!(
        take_result.program_result.is_ok(),
        "take failed: {:?}",
        take_result.program_result
    );

    let taker_final = take_result
        .resulting_accounts
        .iter()
        .find(|(k, _)| *k == taker)
        .unwrap()
        .1
        .lamports;
    let maker_final = take_result
        .resulting_accounts
        .iter()
        .find(|(k, _)| *k == maker)
        .unwrap()
        .1
        .lamports;
    let escrow_final = take_result
        .resulting_accounts
        .iter()
        .find(|(k, _)| *k == escrow)
        .unwrap()
        .1
        .lamports;

    // Taker: -REQUESTED + escrow_balance (≈ OFFERED + rent)
    let escrow_drain = escrow_after_make.lamports;
    assert_eq!(
        taker_final,
        TAKER_INITIAL - REQUESTED + escrow_drain,
        "taker lamports off",
    );
    assert_eq!(
        maker_final,
        maker_after_make.lamports + REQUESTED,
        "maker lamports off",
    );
    assert_eq!(escrow_final, 0, "escrow PDA should be drained");
}

#[test]
fn test_make_then_refund() {
    let mollusk = setup_mollusk();
    let maker = fixed_maker();
    let (escrow, bump) = derive_escrow(&maker);
    let (system_pid, system_account) = keyed_account_for_system_program();

    // === Make ===
    let make_ix = build_make_ix(maker, escrow, bump, OFFERED, REQUESTED);
    let accounts = vec![
        (maker, system_owned(MAKER_INITIAL)),
        (escrow, empty_pda()),
        (system_pid, system_account),
    ];
    let make_result = mollusk.process_instruction(&make_ix, &accounts);
    assert!(make_result.program_result.is_ok());

    let maker_after_make = make_result
        .resulting_accounts
        .iter()
        .find(|(k, _)| *k == maker)
        .map(|(_, a)| a.clone())
        .unwrap();
    let escrow_after_make = make_result
        .resulting_accounts
        .iter()
        .find(|(k, _)| *k == escrow)
        .map(|(_, a)| a.clone())
        .unwrap();
    let escrow_balance = escrow_after_make.lamports;

    // === Refund ===
    // Pass a distinct filler pubkey for the unused third slot;
    // see `build_refund_ix` for why we can't reuse maker/escrow.
    let filler = Pubkey::new_from_array([0xab; 32]);
    let refund_ix = build_refund_ix(maker, escrow, filler);
    let refund_accounts = vec![
        (maker, maker_after_make.clone()),
        (escrow, escrow_after_make.clone()),
        (filler, system_owned(0)),
    ];
    let refund_result = mollusk.process_instruction(&refund_ix, &refund_accounts);
    assert!(
        refund_result.program_result.is_ok(),
        "refund failed: {:?}",
        refund_result.program_result
    );

    let maker_final = refund_result
        .resulting_accounts
        .iter()
        .find(|(k, _)| *k == maker)
        .unwrap()
        .1
        .lamports;
    let escrow_final = refund_result
        .resulting_accounts
        .iter()
        .find(|(k, _)| *k == escrow)
        .unwrap()
        .1
        .lamports;

    assert_eq!(
        maker_final,
        maker_after_make.lamports + escrow_balance,
        "maker should reclaim entire escrow balance",
    );
    assert_eq!(escrow_final, 0, "escrow should be drained on refund");
}

#[test]
fn test_take_insufficient_funds_returns_custom_6001() {
    let mollusk = setup_mollusk();
    let maker = fixed_maker();
    let taker = fixed_taker();
    let (escrow, bump) = derive_escrow(&maker);

    // Taker has fewer lamports than `requested` → direct-lamport
    // `if (taker.lamports() < state.requested) return InsufficientFunds`
    // → wire Custom(6001).
    let take_ix = build_take_ix(taker, maker, escrow);
    let accounts = vec![
        (taker, system_owned(REQUESTED - 1)),
        (maker, system_owned(MAKER_INITIAL)),
        (
            escrow,
            preinitialized_escrow(maker, OFFERED, REQUESTED, bump, OFFERED),
        ),
    ];
    let result = mollusk.process_instruction(&take_ix, &accounts);

    match result.program_result {
        mollusk_svm::result::ProgramResult::Failure(ref err) => {
            assert_eq!(
                err,
                &ProgramError::Custom(6001),
                "expected Custom(6001) (InsufficientFunds), got {err:?}",
            );
        }
        other => panic!("expected failure with InsufficientFunds, got {other:?}"),
    }
}

#[test]
fn test_take_wrong_maker_returns_custom_6000() {
    let mollusk = setup_mollusk();
    let real_maker = fixed_maker();
    let imposter_maker = Pubkey::new_from_array([0x77; 32]);
    let taker = fixed_taker();
    let (escrow, bump) = derive_escrow(&real_maker);

    // Take with the wrong maker pubkey. `requireHasOneWith("maker", ...)`
    // compares stored.maker (real_maker) to passed maker (imposter)
    // → Custom(6000).
    let take_ix = build_take_ix(taker, imposter_maker, escrow);
    let accounts = vec![
        (taker, system_owned(TAKER_INITIAL)),
        (imposter_maker, system_owned(MAKER_INITIAL)),
        (
            escrow,
            preinitialized_escrow(real_maker, OFFERED, REQUESTED, bump, OFFERED),
        ),
    ];
    let result = mollusk.process_instruction(&take_ix, &accounts);

    match result.program_result {
        mollusk_svm::result::ProgramResult::Failure(ref err) => {
            assert_eq!(
                err,
                &ProgramError::Custom(6000),
                "expected Custom(6000) (NotMaker), got {err:?}",
            );
        }
        other => panic!("expected failure with NotMaker, got {other:?}"),
    }
}
