//! On-chain CPI wrappers around the SPL Memo program.
//!
//! Thin syntactic sugar over `instruction.zig` + `sol.cpi.invoke`.
//! Use these helpers when you're writing on-chain code that wants to
//! emit a memo via CPI; off-chain code (transaction construction)
//! should call `instruction.memo(...)` directly.

const sol = @import("solana_program_sdk");
const instruction = @import("instruction.zig");

const CpiAccountInfo = sol.CpiAccountInfo;
const ProgramResult = sol.ProgramResult;

/// Invoke the SPL Memo program with `message`. Pass the memo program
/// account itself in `memo_program` (the runtime requires the program
/// account to be present in the accounts list passed to `invoke`).
///
/// `signers` are the runtime account views whose pubkeys must
/// co-sign. They will both populate the instruction's `AccountMeta`
/// list (via `instruction.memo`) **and** be forwarded to `invoke` so
/// the runtime can satisfy the cross-program account graph.
///
/// Allocation-free: `signers.len + 1` worth of stack scratch for the
/// `AccountMeta` array and the `[CpiAccountInfo]` invoke buffer. With
/// no signers (the most common case), only one `CpiAccountInfo` slot
/// is used.
///
/// CU cost: dominated by the runtime-imposed CPI overhead (~1200 CU)
/// plus the memo program's own log + signer-check costs (~400 CU per
/// the v2 program's measured cost).
///
/// Caps `signers.len` at 11 so the on-stack scratch buffers stay
/// bounded — that's well above any realistic memo's needs (memos with
/// more than 2-3 co-signers are vanishingly rare in practice).
pub fn memo(
    message: []const u8,
    memo_program: CpiAccountInfo,
    signers: []const CpiAccountInfo,
) ProgramResult {
    const max_signers = 11;
    if (signers.len > max_signers) return error.InvalidArgument;

    var meta_buf: [max_signers]sol.cpi.AccountMeta = undefined;
    var pubkey_buf: [max_signers]*const sol.Pubkey = undefined;
    for (signers, 0..) |s, i| pubkey_buf[i] = s.key();

    const ix = instruction.memo(message, pubkey_buf[0..signers.len], meta_buf[0..signers.len]);

    var infos: [max_signers + 1]CpiAccountInfo = undefined;
    for (signers, 0..) |s, i| infos[i] = s;
    infos[signers.len] = memo_program;

    return sol.cpi.invoke(&ix, infos[0 .. signers.len + 1]);
}

/// No-signer convenience — emit a memo without enforcing any
/// signatures. Common for "audit log" style usage.
pub fn memoNoSigners(message: []const u8, memo_program: CpiAccountInfo) ProgramResult {
    const ix = instruction.memoNoSigners(message);
    var infos = [_]CpiAccountInfo{memo_program};
    return sol.cpi.invoke(&ix, &infos);
}
