const shared = @import("shared.zig");
const cpi = shared.cpi;
const Pubkey = shared.Pubkey;
const CpiAccountInfo = shared.CpiAccountInfo;
const ProgramResult = shared.ProgramResult;
const NONCE_STATE_SIZE = shared.NONCE_STATE_SIZE;
const SystemInstruction = shared.SystemInstruction;
const TransferPayload = shared.TransferPayload;
const NonceAuthorityPayload = shared.NonceAuthorityPayload;
const fixedIxData = shared.fixedIxData;
const discriminantOnlyData = shared.discriminantOnlyData;
const create = @import("create.zig");
const seeded = @import("seeded.zig");

/// Initialize a nonce account after creation.
pub fn initializeNonceAccount(
    nonce_account: CpiAccountInfo,
    recent_blockhashes_sysvar: CpiAccountInfo,
    rent_sysvar: CpiAccountInfo,
    system_program: CpiAccountInfo,
    authority: *const Pubkey,
) ProgramResult {
    const ix_data = fixedIxData(SystemInstruction.InitializeNonceAccount, NonceAuthorityPayload, .{ .authority = authority.* });

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.writable(nonce_account.key()),
        cpi.AccountMeta.readonly(recent_blockhashes_sysvar.key()),
        cpi.AccountMeta.readonly(rent_sysvar.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(system_program, &account_metas, &ix_data);

    try cpi.invokeRaw(&ix, &[_]CpiAccountInfo{
        nonce_account,
        recent_blockhashes_sysvar,
        rent_sysvar,
        system_program,
    });
}

/// Create and initialize a nonce account.
pub fn createNonceAccount(
    from: CpiAccountInfo,
    nonce_account: CpiAccountInfo,
    recent_blockhashes_sysvar: CpiAccountInfo,
    rent_sysvar: CpiAccountInfo,
    system_program: CpiAccountInfo,
    authority: *const Pubkey,
    lamports: u64,
) ProgramResult {
    try create.createAccount(
        from,
        nonce_account,
        system_program,
        lamports,
        NONCE_STATE_SIZE,
        system_program.key(),
    );

    try initializeNonceAccount(
        nonce_account,
        recent_blockhashes_sysvar,
        rent_sysvar,
        system_program,
        authority,
    );
}

/// Create and initialize a nonce account at a seeded address.
pub fn createNonceAccountWithSeed(
    from: CpiAccountInfo,
    nonce_account: CpiAccountInfo,
    recent_blockhashes_sysvar: CpiAccountInfo,
    rent_sysvar: CpiAccountInfo,
    system_program: CpiAccountInfo,
    base: *const Pubkey,
    seed: []const u8,
    authority: *const Pubkey,
    lamports: u64,
) ProgramResult {
    try seeded.createAccountWithSeed(
        from,
        nonce_account,
        system_program,
        base,
        seed,
        lamports,
        NONCE_STATE_SIZE,
        system_program.key(),
    );

    try initializeNonceAccount(
        nonce_account,
        recent_blockhashes_sysvar,
        rent_sysvar,
        system_program,
        authority,
    );
}

/// Advance a durable transaction nonce.
pub fn advanceNonceAccount(
    nonce_account: CpiAccountInfo,
    recent_blockhashes_sysvar: CpiAccountInfo,
    authorized: CpiAccountInfo,
    system_program: CpiAccountInfo,
) ProgramResult {
    const ix_data = discriminantOnlyData(SystemInstruction.AdvanceNonceAccount);

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.writable(nonce_account.key()),
        cpi.AccountMeta.readonly(recent_blockhashes_sysvar.key()),
        cpi.AccountMeta.signer(authorized.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(system_program, &account_metas, &ix_data);

    try cpi.invokeRaw(&ix, &[_]CpiAccountInfo{
        nonce_account,
        recent_blockhashes_sysvar,
        authorized,
        system_program,
    });
}

/// Withdraw lamports from a nonce account.
pub fn withdrawNonceAccount(
    nonce_account: CpiAccountInfo,
    to: CpiAccountInfo,
    recent_blockhashes_sysvar: CpiAccountInfo,
    rent_sysvar: CpiAccountInfo,
    authorized: CpiAccountInfo,
    system_program: CpiAccountInfo,
    lamports: u64,
) ProgramResult {
    const ix_data = fixedIxData(SystemInstruction.WithdrawNonceAccount, TransferPayload, .{ .lamports = lamports });

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.writable(nonce_account.key()),
        cpi.AccountMeta.writable(to.key()),
        cpi.AccountMeta.readonly(recent_blockhashes_sysvar.key()),
        cpi.AccountMeta.readonly(rent_sysvar.key()),
        cpi.AccountMeta.signer(authorized.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(system_program, &account_metas, &ix_data);

    try cpi.invokeRaw(&ix, &[_]CpiAccountInfo{
        nonce_account,
        to,
        recent_blockhashes_sysvar,
        rent_sysvar,
        authorized,
        system_program,
    });
}

/// Change the authority of a nonce account.
pub fn authorizeNonceAccount(
    nonce_account: CpiAccountInfo,
    authorized: CpiAccountInfo,
    system_program: CpiAccountInfo,
    new_authority: *const Pubkey,
) ProgramResult {
    const ix_data = fixedIxData(SystemInstruction.AuthorizeNonceAccount, NonceAuthorityPayload, .{ .authority = new_authority.* });

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.writable(nonce_account.key()),
        cpi.AccountMeta.signer(authorized.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(system_program, &account_metas, &ix_data);

    try cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ nonce_account, authorized, system_program });
}

/// One-time idempotent upgrade of a legacy nonce account.
pub fn upgradeNonceAccount(
    nonce_account: CpiAccountInfo,
    system_program: CpiAccountInfo,
) ProgramResult {
    const ix_data = discriminantOnlyData(SystemInstruction.UpgradeNonceAccount);

    const account_metas = [_]cpi.AccountMeta{
        cpi.AccountMeta.writable(nonce_account.key()),
    };

    const ix = cpi.Instruction.fromCpiAccount(system_program, &account_metas, &ix_data);

    try cpi.invokeRaw(&ix, &[_]CpiAccountInfo{ nonce_account, system_program });
}
