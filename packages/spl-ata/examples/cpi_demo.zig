//! `spl-ata` reference on-chain example.
//!
//! Exercises the package's CPI wrappers against the real Associated
//! Token Account program loaded by program-test. Instruction data is a
//! one-byte opcode:
//!
//!   tag = 0  create
//!   tag = 1  createIdempotent
//!   tag = 2  recoverNested
//!
//! Accounts (create / createIdempotent):
//!   0. payer                    — signer, writable
//!   1. associated_token_account — writable
//!   2. wallet                   — readonly
//!   3. mint                     — readonly
//!   4. system_program           — readonly, executable
//!   5. token_program            — readonly, executable
//!   6. associated_token_program — readonly, executable
//!
//! Accounts (recoverNested):
//!   0. nested_associated_token_account       — writable
//!   1. nested_token_mint                     — readonly
//!   2. destination_associated_token_account  — writable
//!   3. owner_associated_token_account        — readonly
//!   4. owner_token_mint                      — readonly
//!   5. wallet                                — signer, writable
//!   6. token_program                         — readonly, executable
//!   7. associated_token_program              — readonly, executable

const sol = @import("solana_program_sdk");
const spl_ata = @import("spl_ata");

pub const panic = sol.panic.Panic;

const Op = enum(u8) {
    create = 0,
    create_idempotent = 1,
    recover_nested = 2,
    _,
};

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    const op: Op = @enumFromInt(ctx.readIx(u8, 0));

    switch (op) {
        .create, .create_idempotent => {
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
                else => unreachable,
            }
        },
        .recover_nested => {
            if (sol.entrypoint.unlikely(ctx.remainingAccounts() < 8)) {
                return error.NotEnoughAccountKeys;
            }

            const nested_associated_token_account = ctx.nextAccountUnchecked();
            const nested_token_mint = ctx.nextAccountUnchecked();
            const destination_associated_token_account = ctx.nextAccountUnchecked();
            const owner_associated_token_account = ctx.nextAccountUnchecked();
            const owner_token_mint = ctx.nextAccountUnchecked();
            const wallet = ctx.nextAccountUnchecked();
            const token_program = ctx.nextAccountUnchecked();
            const associated_token_program = ctx.nextAccountUnchecked();

            try spl_ata.cpi.recoverNested(
                nested_associated_token_account.toCpiInfo(),
                nested_token_mint.toCpiInfo(),
                destination_associated_token_account.toCpiInfo(),
                owner_associated_token_account.toCpiInfo(),
                owner_token_mint.toCpiInfo(),
                wallet.toCpiInfo(),
                token_program.toCpiInfo(),
                associated_token_program.toCpiInfo(),
            );
        },
        else => return error.InvalidInstructionData,
    }
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
