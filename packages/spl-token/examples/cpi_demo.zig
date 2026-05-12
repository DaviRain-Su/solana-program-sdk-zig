//! `spl-token` reference on-chain example.
//!
//! Exercises the package's CPI surface against the **real** SPL
//! Token program loaded by Mollusk in
//! `program-test/tests/spl_token.rs`. A single dispatcher routes to
//! one of four operations:
//!
//!   tag = 0  mintTo            data: tag(1) + amount(8)
//!   tag = 1  transferChecked   data: tag(1) + amount(8) + decimals(1)
//!   tag = 2  burn              data: tag(1) + amount(8)
//!   tag = 3  closeAccount      data: tag(1)
//!
//! Accounts (in order):
//!   0. token_program  — readonly, executable
//!   1. mint           — writable (for mintTo / burn / transferChecked)
//!   2. source/account — writable
//!   3. destination    — writable (mintTo / transferChecked / closeAccount)
//!   4. authority      — signer
//!
//! For `mintTo`, "source/account" is unused but still parsed so the
//! account layout is uniform across operations — keeps the test
//! harness simpler.

const sol = @import("solana_program_sdk");
const spl_token = @import("spl_token");

pub const panic = sol.panic.Panic;

const Op = enum(u8) {
    mint_to = 0,
    transfer_checked = 1,
    burn = 2,
    close_account = 3,
    _,
};

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    if (sol.entrypoint.unlikely(ctx.remainingAccounts() < 5)) {
        return error.NotEnoughAccountKeys;
    }

    const token_program = ctx.nextAccountUnchecked();
    const mint = ctx.nextAccountUnchecked();
    const source = ctx.nextAccountUnchecked();
    const destination = ctx.nextAccountUnchecked();
    const authority = ctx.nextAccountUnchecked();

    const op: Op = @enumFromInt(ctx.readIx(u8, 0));

    switch (op) {
        .mint_to => {
            const amount = ctx.readIx(u64, 1);
            try spl_token.cpi.mintTo(
                token_program.toCpiInfo(),
                mint.toCpiInfo(),
                destination.toCpiInfo(),
                authority.toCpiInfo(),
                amount,
            );
        },
        .transfer_checked => {
            const amount = ctx.readIx(u64, 1);
            const decimals = ctx.readIx(u8, 9);
            try spl_token.cpi.transferChecked(
                token_program.toCpiInfo(),
                source.toCpiInfo(),
                mint.toCpiInfo(),
                destination.toCpiInfo(),
                authority.toCpiInfo(),
                amount,
                decimals,
            );
        },
        .burn => {
            const amount = ctx.readIx(u64, 1);
            try spl_token.cpi.burn(
                token_program.toCpiInfo(),
                source.toCpiInfo(),
                mint.toCpiInfo(),
                authority.toCpiInfo(),
                amount,
            );
        },
        .close_account => {
            try spl_token.cpi.closeAccount(
                token_program.toCpiInfo(),
                source.toCpiInfo(),
                destination.toCpiInfo(),
                authority.toCpiInfo(),
            );
        },
        else => return error.InvalidInstructionData,
    }
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
