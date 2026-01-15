//! Example: Memo CPI helper usage.

const anchor = @import("sol_anchor_zig");
const sol = anchor.sdk;

const Accounts = struct {
    memo_program: anchor.Program(anchor.memo.MEMO_PROGRAM_ID),
    authority: anchor.Signer,
};

pub fn addMemo(ctx: anchor.Context(Accounts)) !void {
    try anchor.memo.memo(
        1,
        ctx.accounts.memo_program.toAccountInfo(),
        &[_]*const sol.account.Account.Info{ ctx.accounts.authority.toAccountInfo() },
        "hello from zig",
        null,
    );
}
