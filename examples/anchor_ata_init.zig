//! Example: ATA init with payer semantics.

const anchor = @import("sol_anchor_zig");
const sol = anchor.sdk;

const Accounts = anchor.typed.Accounts(.{
    .payer = anchor.typed.SignerMut,
    .authority = anchor.typed.Signer,
    .mint = anchor.typed.Mint(.{ .authority = .authority }),
    .ata = anchor.typed.ATA(.{
        .mint = .mint,
        .authority = .authority,
        .payer = .payer,
        .if_needed = true,
    }),
    .system_program = anchor.typed.SystemProgram,
    .token_program = anchor.typed.TokenProgram,
    .associated_token_program = anchor.typed.AssociatedTokenProgram,
});

pub fn initAta(ctx: anchor.Context(Accounts)) !void {
    _ = ctx;
}
