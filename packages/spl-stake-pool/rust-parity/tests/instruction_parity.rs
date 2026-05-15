use {
    solana_program::{instruction::AccountMeta, pubkey::Pubkey, sysvar},
    spl_stake_pool::{
        find_deposit_authority_program_address, find_ephemeral_stake_program_address,
        find_stake_program_address, find_transient_stake_program_address,
        find_withdraw_authority_program_address,
        instruction::{
            add_validator_to_pool, deposit_sol_with_authority_and_slippage,
            deposit_stake_with_authority, initialize, withdraw_sol_with_authority_and_slippage,
            withdraw_stake_with_slippage,
        },
        state::Fee,
    },
    std::{num::NonZeroU32, str::FromStr},
};

fn key(byte: u8) -> Pubkey {
    Pubkey::from([byte; 32])
}

fn id(value: &str) -> Pubkey {
    Pubkey::from_str(value).unwrap()
}

fn assert_meta(meta: &AccountMeta, pubkey: Pubkey, is_signer: bool, is_writable: bool) {
    assert_eq!(meta.pubkey, pubkey);
    assert_eq!(meta.is_signer, is_signer);
    assert_eq!(meta.is_writable, is_writable);
}

#[test]
fn official_pda_helpers_match_zig_seed_order() {
    let stake_pool = key(1);
    let vote = key(2);

    assert_eq!(
        find_deposit_authority_program_address(&spl_stake_pool::id(), &stake_pool),
        Pubkey::find_program_address(&[stake_pool.as_ref(), b"deposit"], &spl_stake_pool::id())
    );
    assert_eq!(
        find_withdraw_authority_program_address(&spl_stake_pool::id(), &stake_pool),
        Pubkey::find_program_address(&[stake_pool.as_ref(), b"withdraw"], &spl_stake_pool::id())
    );
    assert_eq!(
        find_stake_program_address(
            &spl_stake_pool::id(),
            &vote,
            &stake_pool,
            Some(NonZeroU32::new(7).unwrap())
        ),
        Pubkey::find_program_address(
            &[vote.as_ref(), stake_pool.as_ref(), &7u32.to_le_bytes()],
            &spl_stake_pool::id()
        )
    );
    assert_eq!(
        find_transient_stake_program_address(&spl_stake_pool::id(), &vote, &stake_pool, 8),
        Pubkey::find_program_address(
            &[
                b"transient",
                vote.as_ref(),
                stake_pool.as_ref(),
                &8u64.to_le_bytes()
            ],
            &spl_stake_pool::id()
        )
    );
    assert_eq!(
        find_ephemeral_stake_program_address(&spl_stake_pool::id(), &stake_pool, 9),
        Pubkey::find_program_address(
            &[b"ephemeral", stake_pool.as_ref(), &9u64.to_le_bytes()],
            &spl_stake_pool::id()
        )
    );
}

#[test]
fn official_initialize_and_add_validator_match_zig_layout() {
    let keys = [
        key(0),
        key(1),
        key(2),
        key(3),
        key(4),
        key(5),
        key(6),
        key(7),
        key(8),
        key(9),
    ];
    let ix = initialize(
        &spl_stake_pool::id(),
        &keys[0],
        &keys[1],
        &keys[2],
        &keys[3],
        &keys[4],
        &keys[5],
        &keys[6],
        &keys[7],
        &keys[8],
        Some(keys[9]),
        Fee {
            denominator: 100,
            numerator: 1,
        },
        Fee {
            denominator: 200,
            numerator: 2,
        },
        Fee {
            denominator: 300,
            numerator: 3,
        },
        4,
        5,
    );
    assert_eq!(ix.program_id, spl_stake_pool::id());
    assert_eq!(ix.accounts.len(), 10);
    assert_meta(&ix.accounts[0], keys[0], false, true);
    assert_meta(&ix.accounts[1], keys[1], true, false);
    assert_meta(&ix.accounts[9], keys[9], true, false);
    assert_eq!(ix.data[0], 0);
    assert_eq!(u64::from_le_bytes(ix.data[1..9].try_into().unwrap()), 100);
    assert_eq!(u64::from_le_bytes(ix.data[9..17].try_into().unwrap()), 1);

    let add_ix = add_validator_to_pool(
        &spl_stake_pool::id(),
        &keys[0],
        &keys[1],
        &keys[2],
        &keys[3],
        &keys[4],
        &keys[5],
        &keys[6],
        Some(NonZeroU32::new(7).unwrap()),
    );
    assert_eq!(add_ix.accounts.len(), 13);
    assert_meta(&add_ix.accounts[7], sysvar::rent::id(), false, false);
    assert_meta(
        &add_ix.accounts[10],
        id("StakeConfig11111111111111111111111111111111"),
        false,
        false,
    );
    assert_meta(
        &add_ix.accounts[12],
        id("Stake11111111111111111111111111111111111111"),
        false,
        false,
    );
    assert_eq!(add_ix.data, vec![1, 7, 0, 0, 0]);
}

#[test]
fn official_deposit_and_withdraw_builders_match_zig_layout() {
    let keys = [
        key(0),
        key(1),
        key(2),
        key(3),
        key(4),
        key(5),
        key(6),
        key(7),
        key(8),
        key(9),
        key(10),
        key(11),
        key(12),
    ];

    let deposit_sol = deposit_sol_with_authority_and_slippage(
        &spl_stake_pool::id(),
        &keys[0],
        &keys[9],
        &keys[1],
        &keys[2],
        &keys[3],
        &keys[4],
        &keys[5],
        &keys[6],
        &keys[7],
        &keys[8],
        123,
        100,
    );
    assert_eq!(deposit_sol.accounts.len(), 11);
    assert_meta(&deposit_sol.accounts[3], keys[3], true, true);
    assert_meta(
        &deposit_sol.accounts[8],
        solana_program::system_program::id(),
        false,
        false,
    );
    assert_meta(&deposit_sol.accounts[10], keys[9], true, false);
    assert_eq!(
        deposit_sol.data,
        vec![25, 123, 0, 0, 0, 0, 0, 0, 0, 100, 0, 0, 0, 0, 0, 0, 0]
    );

    let deposit_stake = deposit_stake_with_authority(
        &spl_stake_pool::id(),
        &keys[0],
        &keys[1],
        &keys[2],
        &keys[3],
        &keys[4],
        &keys[5],
        &keys[6],
        &keys[7],
        &keys[8],
        &keys[9],
        &keys[10],
        &keys[11],
        &keys[12],
    );
    let final_deposit = deposit_stake.last().unwrap();
    assert_eq!(final_deposit.accounts.len(), 15);
    assert_meta(&final_deposit.accounts[2], keys[2], true, false);
    assert_eq!(final_deposit.data, vec![9]);

    let withdraw_stake = withdraw_stake_with_slippage(
        &spl_stake_pool::id(),
        &keys[0],
        &keys[1],
        &keys[2],
        &keys[3],
        &keys[4],
        &keys[5],
        &keys[6],
        &keys[7],
        &keys[8],
        &keys[9],
        &keys[10],
        55,
        44,
    );
    assert_eq!(withdraw_stake.accounts.len(), 13);
    assert_meta(
        &withdraw_stake.accounts[10],
        sysvar::clock::id(),
        false,
        false,
    );
    assert_eq!(
        withdraw_stake.data,
        vec![24, 55, 0, 0, 0, 0, 0, 0, 0, 44, 0, 0, 0, 0, 0, 0, 0]
    );

    let withdraw_sol = withdraw_sol_with_authority_and_slippage(
        &spl_stake_pool::id(),
        &keys[0],
        &keys[12],
        &keys[1],
        &keys[2],
        &keys[3],
        &keys[4],
        &keys[5],
        &keys[6],
        &keys[7],
        &keys[8],
        66,
        33,
    );
    assert_eq!(withdraw_sol.accounts.len(), 13);
    assert_meta(&withdraw_sol.accounts[12], keys[12], true, false);
    assert_eq!(
        withdraw_sol.data,
        vec![26, 66, 0, 0, 0, 0, 0, 0, 0, 33, 0, 0, 0, 0, 0, 0, 0]
    );
}
