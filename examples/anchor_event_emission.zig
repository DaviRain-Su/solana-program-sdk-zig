const anchor = @import("sol_anchor_zig");
const sol = anchor.sdk;

const TransferEvent = anchor.Event(struct {
    from: sol.PublicKey,
    to: sol.PublicKey,
    amount: u64,
});

const TransferAccounts = struct {
    from: anchor.Signer,
    to: anchor.Signer,
};

pub fn transfer(ctx: anchor.Context(TransferAccounts), amount: u64) !void {
    ctx.emit(TransferEvent, .{
        .from = ctx.accounts.from.key().*,
        .to = ctx.accounts.to.key().*,
        .amount = amount,
    });
}
