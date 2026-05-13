//! SPL Transfer Hook validation PDA derivation and future account
//! resolution helpers.

const std = @import("std");
const sol = @import("solana_program_sdk");

const Pubkey = sol.Pubkey;

pub const ProgramDerivedAddress = sol.pda.ProgramDerivedAddress;
pub const EXTRA_ACCOUNT_METAS_SEED = "extra-account-metas";

pub fn findValidationAddress(
    mint: *const Pubkey,
    hook_program_id: *const Pubkey,
) ProgramDerivedAddress {
    return sol.pda.findProgramAddress(
        &.{ EXTRA_ACCOUNT_METAS_SEED, mint },
        hook_program_id,
    ) catch unreachable;
}

fn expectValidationVector(
    mint: *const Pubkey,
    hook_program_id: *const Pubkey,
    expected_bump_seed: u8,
    expected_address: *const Pubkey,
) !void {
    const Self = @This();
    try std.testing.expect(@hasDecl(Self, "findValidationAddress"));
    if (!@hasDecl(Self, "findValidationAddress")) return;

    const find_validation_address = @field(Self, "findValidationAddress");
    const actual = find_validation_address(mint, hook_program_id);
    try std.testing.expectEqual(expected_bump_seed, actual.bump_seed);
    try std.testing.expectEqualSlices(u8, expected_address, &actual.address);
}

test "resolve exposes canonical extra-account-metas seed bytes" {
    const Self = @This();
    try std.testing.expect(@hasDecl(Self, "EXTRA_ACCOUNT_METAS_SEED"));
    if (!@hasDecl(Self, "EXTRA_ACCOUNT_METAS_SEED")) return;

    const extra_account_metas_seed = @field(Self, "EXTRA_ACCOUNT_METAS_SEED");
    try std.testing.expectEqualStrings("extra-account-metas", extra_account_metas_seed);
}

test "findValidationAddress matches canonical seed and program-specific golden vectors" {
    const mint_a: Pubkey = .{0x11} ** 32;
    const mint_b: Pubkey = .{0x22} ** 32;
    const hook_program_a: Pubkey = .{0xa1} ** 32;
    const hook_program_b: Pubkey = .{0xb2} ** 32;

    const expected_a_a: Pubkey = .{ 55, 49, 232, 125, 247, 117, 73, 26, 57, 218, 226, 59, 26, 145, 183, 14, 234, 21, 131, 15, 67, 179, 215, 205, 253, 81, 22, 155, 105, 89, 189, 71 };
    const expected_a_b: Pubkey = .{ 11, 167, 177, 207, 201, 85, 227, 141, 97, 112, 150, 42, 115, 216, 51, 246, 5, 182, 248, 28, 41, 165, 184, 178, 152, 91, 129, 202, 108, 94, 180, 202 };
    const expected_b_a: Pubkey = .{ 91, 253, 165, 84, 93, 156, 222, 200, 255, 60, 244, 92, 91, 60, 160, 54, 124, 235, 60, 194, 27, 247, 253, 207, 187, 237, 56, 91, 24, 116, 254, 177 };
    const expected_b_b: Pubkey = .{ 150, 147, 209, 64, 248, 20, 55, 68, 31, 177, 76, 58, 240, 58, 15, 189, 85, 115, 239, 27, 111, 53, 86, 121, 173, 153, 25, 194, 14, 74, 240, 58 };

    try expectValidationVector(&mint_a, &hook_program_a, 253, &expected_a_a);
    try expectValidationVector(&mint_a, &hook_program_b, 253, &expected_a_b);
    try expectValidationVector(&mint_b, &hook_program_a, 255, &expected_b_a);
    try expectValidationVector(&mint_b, &hook_program_b, 253, &expected_b_b);
}
