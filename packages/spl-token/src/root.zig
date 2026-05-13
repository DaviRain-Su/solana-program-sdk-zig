//! `spl-token` — Zig client for the SPL Token program.
//!
//! Dual-target: on-chain CPI helpers + off-chain byte builders.
//! Works against both classic SPL Token and Token-2022 — pass the
//! appropriate `token_program` account to the CPI wrappers, or use
//! the `PROGRAM_ID` / `PROGRAM_ID_2022` constants when building
//! transactions off-chain.
//!
//! ## On-chain
//!
//! ```zig
//! const spl_token = @import("spl_token");
//!
//! fn transfer_handler(ctx: *sol.InstructionContext) sol.ProgramResult {
//!     const a = try ctx.parseAccountsWith(.{
//!         .{ "token_program", .{} },
//!         .{ "source",        .{} },
//!         .{ "destination",   .{} },
//!         .{ "authority",     .{ .is_signer = true } },
//!     });
//!     const amount = ctx.readIx(u64, 0);
//!     try spl_token.cpi.transfer(
//!         a.token_program.toCpiInfo(),
//!         a.source.toCpiInfo(),
//!         a.destination.toCpiInfo(),
//!         a.authority.toCpiInfo(),
//!         amount,
//!     );
//! }
//! ```
//!
//! ## Off-chain
//!
//! ```zig
//! var metas: [3]sol.cpi.AccountMeta = undefined;
//! var data: [9]u8 = undefined;
//! const ix = spl_token.instruction.transfer(
//!     &source_pubkey, &dest_pubkey, &authority_pubkey, 100,
//!     &metas, &data,
//! );
//! ```

const sol = @import("solana_program_sdk");

pub const id = @import("id.zig");
pub const state = @import("state.zig");
pub const instruction = @import("instruction.zig");
pub const cpi = @import("cpi.zig");

/// Classic SPL Token program ID.
pub const PROGRAM_ID = id.PROGRAM_ID;
/// Token-2022 program ID.
pub const PROGRAM_ID_2022 = id.PROGRAM_ID_2022;
/// Canonical wrapped-SOL / native mint address.
pub const NATIVE_MINT = id.NATIVE_MINT;

pub const Mint = state.Mint;
pub const Account = state.Account;
pub const Multisig = state.Multisig;
pub const AccountState = state.AccountState;
pub const MINT_LEN = state.MINT_LEN;
pub const ACCOUNT_LEN = state.ACCOUNT_LEN;
pub const MULTISIG_LEN = state.MULTISIG_LEN;
pub const MULTISIG_SIGNER_MAX = state.MULTISIG_SIGNER_MAX;

pub const TokenInstruction = instruction.TokenInstruction;

pub inline fn isNativeMint(mint: *const sol.Pubkey) bool {
    return sol.pubkey.pubkeyEq(mint, &NATIVE_MINT);
}

test {
    @import("std").testing.refAllDecls(@This());
}
