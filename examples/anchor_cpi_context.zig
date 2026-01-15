//! Example: CPI context builder.

const anchor = @import("sol_anchor_zig");
const sol = anchor.sdk;

const TargetProgram = struct {
    pub const instructions = struct {
        pub const ping = anchor.Instruction(.{
            .Accounts = struct {
                authority: anchor.Signer,
            },
            .Args = void,
        });
    };
};

const Accounts = struct {
    target_program: anchor.Program(sol.PublicKey.default()),
    authority: anchor.Signer,
};

pub fn ping(ctx: anchor.Context(Accounts)) !void {
    const cpi = anchor.CpiContext(TargetProgram, TargetProgram.instructions.ping.Accounts).init(
        sol.allocator.bpf_allocator,
        ctx.accounts.target_program.toAccountInfo(),
        .{ .authority = ctx.accounts.authority },
    );
    _ = try cpi.invokeNoArgs("ping");
}
