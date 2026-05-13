//! SPL Token-2022 program id.

const std = @import("std");
const sol = @import("solana_program_sdk");

pub const Pubkey = sol.Pubkey;

/// Canonical SPL Token-2022 program id.
///
/// `TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb`
pub const PROGRAM_ID: Pubkey = sol.spl_token_2022_program_id;

test "PROGRAM_ID is canonical Token-2022 id" {
    var out: [44]u8 = undefined;
    const len = sol.pubkey.encodeBase58(&PROGRAM_ID, &out);

    try std.testing.expectEqualStrings(
        "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb",
        out[0..len],
    );
}
