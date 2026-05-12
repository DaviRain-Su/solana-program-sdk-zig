//! `spl-ata` reference on-chain example.
//!
//! Exercises the package's CPI wrappers against the real Associated
//! Token Account program loaded by program-test. Instruction data is a
//! one-byte opcode:
//!
//!   tag = 0  create
//!   tag = 1  createIdempotent
//!
//! Accounts (in order):
//!   0. payer                    — signer, writable
//!   1. associated_token_account — writable
//!   2. wallet                   — readonly
//!   3. mint                     — readonly
//!   4. system_program           — readonly, executable
//!   5. token_program            — readonly, executable
//!   6. associated_token_program — readonly, executable

const sol = @import("solana_program_sdk");
const spl_ata = @import("spl_ata");

pub const panic = sol.panic.Panic;

const Op = enum(u8) {
    create = 0,
    create_idempotent = 1,
    _,
};

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    if (sol.entrypoint.unlikely(ctx.remainingAccounts() < 7)) {
        return error.NotEnoughAccountKeys;
    }

    const payer = ctx.nextAccountUnchecked();
    const associated_token_account = ctx.nextAccountUnchecked();
    const wallet = ctx.nextAccountUnchecked();
    const mint = ctx.nextAccountUnchecked();
    const system_program = ctx.nextAccountUnchecked();
    const token_program = ctx.nextAccountUnchecked();
    const associated_token_program = ctx.nextAccountUnchecked();

    const op: Op = @enumFromInt(ctx.readIx(u8, 0));

    switch (op) {
        .create => try spl_ata.cpi.create(
            payer.toCpiInfo(),
            associated_token_account.toCpiInfo(),
            wallet.toCpiInfo(),
            mint.toCpiInfo(),
            system_program.toCpiInfo(),
            token_program.toCpiInfo(),
            associated_token_program.toCpiInfo(),
        ),
        .create_idempotent => try spl_ata.cpi.createIdempotent(
            payer.toCpiInfo(),
            associated_token_account.toCpiInfo(),
            wallet.toCpiInfo(),
            mint.toCpiInfo(),
            system_program.toCpiInfo(),
            token_program.toCpiInfo(),
            associated_token_program.toCpiInfo(),
        ),
        else => return error.InvalidInstructionData,
    }
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
