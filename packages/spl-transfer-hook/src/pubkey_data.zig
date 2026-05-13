const std = @import("std");
const sol = @import("solana_program_sdk");

const ProgramError = sol.ProgramError;

pub const PubkeyData = union(enum) {
    instruction_data: InstructionData,
    account_data: AccountData,

    pub const InstructionData = struct {
        index: u8,
    };

    pub const AccountData = struct {
        account_index: u8,
        data_index: u8,
    };

    pub fn tlvSize(self: PubkeyData) usize {
        return switch (self) {
            .instruction_data => 2,
            .account_data => 3,
        };
    }

    pub fn pack(self: PubkeyData, dst: []u8) ProgramError!void {
        if (dst.len != self.tlvSize()) return ProgramError.InvalidAccountData;

        switch (self) {
            .instruction_data => |source| {
                dst[0] = 1;
                dst[1] = source.index;
            },
            .account_data => |source| {
                dst[0] = 2;
                dst[1] = source.account_index;
                dst[2] = source.data_index;
            },
        }
    }
};

pub fn packIntoAddressConfig(config: PubkeyData) ProgramError![32]u8 {
    var buffer: [32]u8 = .{0} ** 32;
    try config.pack(buffer[0..config.tlvSize()]);
    return buffer;
}

pub fn unpackAddressConfig(address_config: *const [32]u8) ProgramError!PubkeyData {
    return switch (address_config[0]) {
        1 => .{ .instruction_data = .{ .index = address_config[1] } },
        2 => .{ .account_data = .{
            .account_index = address_config[1],
            .data_index = address_config[2],
        } },
        else => ProgramError.InvalidAccountData,
    };
}

test "pubkey-data configs pack and unpack canonically" {
    const instruction = PubkeyData{ .instruction_data = .{ .index = 9 } };
    const encoded_instruction = try packIntoAddressConfig(instruction);
    try std.testing.expectEqualDeep(instruction, try unpackAddressConfig(&encoded_instruction));

    const account = PubkeyData{ .account_data = .{ .account_index = 3, .data_index = 12 } };
    const encoded_account = try packIntoAddressConfig(account);
    try std.testing.expectEqualDeep(account, try unpackAddressConfig(&encoded_account));
}

test "pubkey-data config parsing rejects uninitialized and unsupported discriminators" {
    const zero = [_]u8{0} ** 32;
    try std.testing.expectError(ProgramError.InvalidAccountData, unpackAddressConfig(&zero));

    var invalid = zero;
    invalid[0] = 3;
    try std.testing.expectError(ProgramError.InvalidAccountData, unpackAddressConfig(&invalid));
}
