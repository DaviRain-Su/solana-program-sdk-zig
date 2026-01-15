const anchor = @import("sol_anchor_zig");
const sol = anchor.sdk;

const TransferAccounts = struct {
    token_program: anchor.Program(sol.spl.TOKEN_PROGRAM_ID),
    source: anchor.TokenAccount(.{}),
    destination: anchor.TokenAccount(.{}),
    authority: anchor.Signer,
};

pub fn transfer(ctx: anchor.Context(TransferAccounts), amount: u64) !void {
    try anchor.token.transfer(
        ctx.accounts.token_program.toAccountInfo(),
        ctx.accounts.source.toAccountInfo(),
        ctx.accounts.destination.toAccountInfo(),
        ctx.accounts.authority.toAccountInfo(),
        amount,
    );
}
