//! Pinocchio reference vault — same semantics as `examples/vault.zig`.
//!
//! Three instructions, dispatched on `data[0]`:
//!   0 = initialize  accounts: authority (sig+w), vault PDA (w), system_program
//!                   data: [tag:1][bump:1]
//!   1 = deposit     accounts: payer (sig+w), vault PDA (w), system_program
//!                   data: [tag:1][amount:u64 LE]
//!   2 = withdraw    accounts: authority (sig), vault PDA (w), recipient (w)
//!                   data: [tag:1][amount:u64 LE]
//!
//! PDA seeds: `["vault", authority.address().as_ref()]`.
//! Client supplies the canonical bump in `initialize` ix data (same as the
//! Zig vault), so we only do one `create_program_address` worth of work
//! via the system program's signer-seed proof.
//!
//! Notes vs Zig vault:
//!   - Matches Zig vault's 56-byte account size exactly: 8-byte
//!     discriminator (unused here, zeroed) + 32 authority + 8 balance +
//!     1 bump + 7 pad. Keeps rent-exempt min balance identical so
//!     CreateAccount lamports/byte costs match.
//!   - `sol_log_data` event emission mirrors the Zig vault: 24-byte
//!     payload = [8-byte event disc][u64 amount][u64 new_balance].
//!     We use zero-filled discriminators here as placeholders — exact
//!     byte parity with `sha256("event:Deposit")[..8]` isn't required
//!     for the CU comparison.

#![no_std]
#![allow(unexpected_cfgs)]

use pinocchio::{
    cpi::{Seed, Signer},
    error::ProgramError,
    no_allocator, nostd_panic_handler, program_entrypoint,
    AccountView, Address, ProgramResult,
};
use pinocchio_system::instructions::{CreateAccount, Transfer as SystemTransfer};

// =========================================================================
// Program ID
// =========================================================================

// Base58 "PinoVau1tBench11111111111111111111111111111" decoded at compile
// time via the const-decoder from five8_const.
// Address has #[repr(transparent)] over [u8; 32], so transmuting via
// const initializer is safe here.
pub const ID: Address = unsafe {
    core::mem::transmute::<[u8; 32], Address>(five8_const::decode_32_const(
        "PinoVau1tBench11111111111111111111111111111",
    ))
};

program_entrypoint!(process_instruction);
no_allocator!();
nostd_panic_handler!();

// =========================================================================
// State
// =========================================================================

// 8 (disc) + 32 (authority) + 8 (balance) + 1 (bump) + 7 (pad) = 56 bytes.
// Exact byte parity with the Zig vault, so CreateAccount lamports and
// data-load CU match precisely.
const VAULT_SIZE: usize = 56;

#[repr(C)]
struct VaultState {
    /// 8-byte discriminator (unused by this minimal reference impl,
    /// but kept for byte-parity with the Zig `VaultState`).
    _disc: [u8; 8],
    authority: Address,
    balance: u64,
    bump: u8,
    _pad: [u8; 7],
}

// =========================================================================
// Events — 24-byte sol_log_data payload, same shape as Zig vault.
// =========================================================================

const DEPOSIT_EVENT_DISC: [u8; 8] = [0u8; 8];
const WITHDRAW_EVENT_DISC: [u8; 8] = [0u8; 8];

#[inline(always)]
unsafe fn emit_event(disc: &[u8; 8], amount: u64, new_balance: u64) {
    let mut payload = [0u8; 24];
    payload[0..8].copy_from_slice(disc);
    payload[8..16].copy_from_slice(&amount.to_le_bytes());
    payload[16..24].copy_from_slice(&new_balance.to_le_bytes());

    // sol_log_data takes (data: *const SolBytes, n: u64) where SolBytes is
    // a (ptr, len) pair. We emit a single slice to keep base-fee overhead
    // minimal (same trade-off as the Zig vault's single-slice emit).
    #[repr(C)]
    struct SolBytes {
        addr: u64,
        len: u64,
    }
    let one = [SolBytes {
        addr: payload.as_ptr() as u64,
        len: payload.len() as u64,
    }];

    #[cfg(any(target_os = "solana", target_arch = "bpf"))]
    pinocchio::syscalls::sol_log_data(one.as_ptr() as *const u8, 1);

    // Silence unused-variable warnings on host builds.
    #[cfg(not(any(target_os = "solana", target_arch = "bpf")))]
    let _ = one;
}

// =========================================================================
// Instruction dispatch
// =========================================================================

#[inline(always)]
fn process_instruction(
    _program_id: &Address,
    accounts: &mut [AccountView],
    data: &[u8],
) -> ProgramResult {
    if accounts.len() < 3 || data.is_empty() {
        return Err(ProgramError::InvalidInstructionData);
    }
    let (first, rest) = accounts.split_first_mut().unwrap();
    let (second, rest) = rest.split_first_mut().unwrap();
    let third = &mut rest[0];
    match data[0] {
        0 => process_initialize(first, second, third, data),
        1 => process_deposit(first, second, third, data),
        2 => process_withdraw(first, second, third, data),
        _ => Err(ProgramError::InvalidInstructionData),
    }
}

// -------------------------------------------------------------------------
// initialize
// -------------------------------------------------------------------------

#[inline(never)]
fn process_initialize(
    authority: &mut AccountView,
    vault: &mut AccountView,
    _system_program: &mut AccountView,
    data: &[u8],
) -> ProgramResult {
    if !authority.is_signer() {
        return Err(ProgramError::MissingRequiredSignature);
    }
    if data.len() < 2 {
        return Err(ProgramError::InvalidInstructionData);
    }
    let bump = data[1];
    let bump_seed = [bump];

    let auth_key: Address = *authority.address();

    let seeds = [
        Seed::from(b"vault".as_ref()),
        Seed::from(auth_key.as_ref()),
        Seed::from(bump_seed.as_ref()),
    ];
    let signer = Signer::from(&seeds);

    // NOTE: We bypass `Rent::get()` here because pinocchio 0.11's
    // sysvar struct reads only `lamports_per_byte_year` from the
    // rent sysvar without multiplying by `exemption_threshold` (2.0).
    // On solana-program-test 2.1 that returns *half* the actual
    // rent-exempt minimum and the transaction fails with
    // `InsufficientFundsForRent`. We compute the rent ourselves with
    // the canonical formula. Both sides of the bench use this same
    // formula, so the comparison stays fair.
    //
    //   minimum_balance = (storage_overhead + data_len) * lamports_per_byte_year * 2.0
    //                   = (128 + 56) * 3480 * 2 = 1_280_640 lamports
    const ACCOUNT_STORAGE_OVERHEAD: u64 = 128;
    const LAMPORTS_PER_BYTE_YEAR: u64 = 3480;
    const EXEMPTION_MULT: u64 = 2;
    let needed_lamports =
        (ACCOUNT_STORAGE_OVERHEAD + VAULT_SIZE as u64) * LAMPORTS_PER_BYTE_YEAR * EXEMPTION_MULT;

    CreateAccount {
        from: authority,
        to: vault,
        lamports: needed_lamports,
        space: VAULT_SIZE as u64,
        owner: &ID,
    }
    .invoke_signed(&[signer])?;

    unsafe {
        let data_ptr = vault.borrow_unchecked_mut().as_mut_ptr();
        let state = &mut *(data_ptr as *mut VaultState);
        state._disc = [0u8; 8];
        state.authority = auth_key;
        state.balance = 0;
        state.bump = bump;
        state._pad = [0u8; 7];
    }

    Ok(())
}

// -------------------------------------------------------------------------
// deposit
// -------------------------------------------------------------------------

#[inline(never)]
fn process_deposit(
    payer: &mut AccountView,
    vault: &mut AccountView,
    _system_program: &mut AccountView,
    data: &[u8],
) -> ProgramResult {
    if !payer.is_signer() {
        return Err(ProgramError::MissingRequiredSignature);
    }
    if vault.owner() != &ID {
        return Err(ProgramError::InvalidAccountOwner);
    }
    if data.len() < 9 {
        return Err(ProgramError::InvalidInstructionData);
    }
    let amount = u64::from_le_bytes(data[1..9].try_into().unwrap());

    SystemTransfer {
        from: payer,
        to: vault,
        lamports: amount,
    }
    .invoke()?;

    let new_balance = unsafe {
        let data_ptr = vault.borrow_unchecked_mut().as_mut_ptr();
        let state = &mut *(data_ptr as *mut VaultState);
        let nb = state
            .balance
            .checked_add(amount)
            .ok_or(ProgramError::ArithmeticOverflow)?;
        state.balance = nb;
        nb
    };

    unsafe { emit_event(&DEPOSIT_EVENT_DISC, amount, new_balance) };
    Ok(())
}

// -------------------------------------------------------------------------
// withdraw
// -------------------------------------------------------------------------

#[inline(never)]
fn process_withdraw(
    authority: &mut AccountView,
    vault: &mut AccountView,
    recipient: &mut AccountView,
    data: &[u8],
) -> ProgramResult {
    if !authority.is_signer() {
        return Err(ProgramError::MissingRequiredSignature);
    }
    if vault.owner() != &ID {
        return Err(ProgramError::InvalidAccountOwner);
    }
    if data.len() < 9 {
        return Err(ProgramError::InvalidInstructionData);
    }
    let amount = u64::from_le_bytes(data[1..9].try_into().unwrap());

    let auth_key: Address = *authority.address();

    // Read stored state.
    let (stored_bump, current_balance, stored_authority) = unsafe {
        let data_ptr = vault.borrow_unchecked().as_ptr();
        let s = &*(data_ptr as *const VaultState);
        (s.bump, s.balance, s.authority)
    };

    // has_one
    if stored_authority != auth_key {
        return Err(ProgramError::IllegalOwner);
    }

    // verify PDA
    let bump_seed = [stored_bump];
    let derived = Address::create_program_address(
        &[b"vault", auth_key.as_ref(), &bump_seed],
        &ID,
    )
    .map_err(|_| ProgramError::InvalidSeeds)?;
    if &derived != vault.address() {
        return Err(ProgramError::InvalidSeeds);
    }

    if current_balance < amount {
        return Err(ProgramError::InsufficientFunds);
    }

    // Direct lamport mutation.
    let new_vault_lamports = vault
        .lamports()
        .checked_sub(amount)
        .ok_or(ProgramError::InsufficientFunds)?;
    let new_recipient_lamports = recipient
        .lamports()
        .checked_add(amount)
        .ok_or(ProgramError::ArithmeticOverflow)?;

    vault.set_lamports(new_vault_lamports);
    recipient.set_lamports(new_recipient_lamports);

    let new_balance = current_balance - amount;
    unsafe {
        let data_ptr = vault.borrow_unchecked_mut().as_mut_ptr();
        let s = &mut *(data_ptr as *mut VaultState);
        s.balance = new_balance;
    }

    unsafe { emit_event(&WITHDRAW_EVENT_DISC, amount, new_balance) };
    Ok(())
}
