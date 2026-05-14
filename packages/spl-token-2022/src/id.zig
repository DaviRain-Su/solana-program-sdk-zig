//! SPL Token-2022 program id.

const std = @import("std");
const sol = @import("solana_program_sdk");

pub const Pubkey = sol.Pubkey;

/// Canonical SPL Token-2022 program id.
///
/// `TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb`
pub const PROGRAM_ID: Pubkey = sol.spl_token_2022_program_id;

/// Canonical Token-2022 native mint address.
///
/// `9pan9bMn5HatX4EJdBwg9VgCa7Uz5HL8N1m5D3NdXejP`
pub const NATIVE_MINT: Pubkey = sol.pubkey.comptimeFromBase58(
    "9pan9bMn5HatX4EJdBwg9VgCa7Uz5HL8N1m5D3NdXejP",
);

test "PROGRAM_ID is canonical Token-2022 id" {
    var out: [44]u8 = undefined;
    const len = sol.pubkey.encodeBase58(&PROGRAM_ID, &out);

    try std.testing.expectEqualStrings(
        "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb",
        out[0..len],
    );
}

test "NATIVE_MINT is canonical Token-2022 native mint" {
    var out: [44]u8 = undefined;
    const len = sol.pubkey.encodeBase58(&NATIVE_MINT, &out);

    try std.testing.expectEqualStrings(
        "9pan9bMn5HatX4EJdBwg9VgCa7Uz5HL8N1m5D3NdXejP",
        out[0..len],
    );
}

test "PROGRAM_ID matches root SDK Token-2022 id and stays distinct from classic ids" {
    try std.testing.expectEqualSlices(u8, &sol.spl_token_2022_program_id, &PROGRAM_ID);
    try std.testing.expect(!sol.pubkey.pubkeyEq(&PROGRAM_ID, &sol.spl_token_program_id));
    try std.testing.expect(!sol.pubkey.pubkeyEq(&PROGRAM_ID, &sol.spl_associated_token_account_id));
}
