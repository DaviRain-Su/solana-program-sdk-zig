const anchor = @import("sol_anchor_zig");
const sol = anchor.sdk;

const UserData = struct {
    authority: sol.PublicKey,
    bump: u8,
};

const UserAccount = anchor.Account(UserData, .{
    .discriminator = anchor.accountDiscriminator("UserData"),
    .seeds = &.{
        anchor.seed("user"),
        anchor.seedAccount("authority"),
        anchor.seedField("authority"),
        anchor.seedBump("user"),
    },
});

const InitializeAccounts = struct {
    authority: anchor.Signer,
    user: UserAccount,
};

pub fn processInstruction(
    program_id: *const sol.PublicKey,
    accounts: []const sol.account.Account.Info,
) !void {
    const result = try anchor.loadAccountsWithDependencies(InitializeAccounts, program_id, accounts);
    const ctx = anchor.Context(InitializeAccounts).new(
        result.accounts,
        program_id,
        &[_]sol.account.Account.Info{},
        result.bumps,
    );
    _ = ctx;
}
