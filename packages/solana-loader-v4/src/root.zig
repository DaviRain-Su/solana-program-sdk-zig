//! `solana_loader_v4` — Loader v4 helpers.

const std = @import("std");
const sol = @import("solana_program_sdk");
const system = @import("solana_system");

pub const Pubkey = sol.Pubkey;
pub const AccountMeta = sol.cpi.AccountMeta;
pub const Instruction = sol.cpi.Instruction;

pub const PROGRAM_ID: Pubkey = sol.pubkey.comptimeFromBase58("LoaderV411111111111111111111111111111111111");
pub const SYSTEM_PROGRAM_ID: Pubkey = system.PROGRAM_ID;
pub const DEPLOYMENT_COOLDOWN_IN_SLOTS: u64 = 1;

pub const STATE_PROGRAM_DATA_OFFSET: usize = 0x30;
pub const DISCRIMINANT_DATA_LEN: usize = 4;
pub const SET_PROGRAM_LENGTH_DATA_LEN: usize = 8;
pub const COPY_DATA_LEN: usize = 16;
pub const WRITE_DATA_OVERHEAD: usize = 16;

pub const DiscriminantData = [DISCRIMINANT_DATA_LEN]u8;
pub const SetProgramLengthData = [SET_PROGRAM_LENGTH_DATA_LEN]u8;
pub const CopyData = [COPY_DATA_LEN]u8;

pub const Error = error{
    BufferTooSmall,
};

pub const LoaderV4Status = enum(u64) {
    retracted = 0,
    deployed = 1,
    finalized = 2,
};

pub const LoaderV4State = extern struct {
    slot: u64,
    authority_address_or_next_version: Pubkey,
    status: LoaderV4Status,
};

pub const InstructionTag = enum(u32) {
    write = 0,
    copy = 1,
    set_program_length = 2,
    deploy = 3,
    retract = 4,
    transfer_authority = 5,
    finalize = 6,
};

pub const CreateBufferBuffers = struct {
    create_metas: *[2]system.AccountMeta,
    create_data: *system.CreateAccountData,
    length_metas: *[3]AccountMeta,
    length_data: *SetProgramLengthData,
};

pub const CreateBufferInstructions = struct {
    instructions: [2]Instruction,

    pub fn createAccount(self: *const CreateBufferInstructions) *const Instruction {
        return &self.instructions[0];
    }

    pub fn setProgramLength(self: *const CreateBufferInstructions) *const Instruction {
        return &self.instructions[1];
    }

    pub fn slice(self: *const CreateBufferInstructions) []const Instruction {
        return self.instructions[0..];
    }
};

comptime {
    std.debug.assert(@sizeOf(LoaderV4State) == STATE_PROGRAM_DATA_OFFSET);
    std.debug.assert(@offsetOf(LoaderV4State, "slot") == 0x00);
    std.debug.assert(@offsetOf(LoaderV4State, "authority_address_or_next_version") == 0x08);
    std.debug.assert(@offsetOf(LoaderV4State, "status") == 0x28);
}

pub fn write(
    program_address: *const Pubkey,
    authority_address: *const Pubkey,
    offset: u32,
    bytes: []const u8,
    metas: *[2]AccountMeta,
    data: []u8,
) Error!Instruction {
    if (data.len < WRITE_DATA_OVERHEAD + bytes.len) return error.BufferTooSmall;
    writeInstructionTag(.write, data[0..4]);
    std.mem.writeInt(u32, data[4..8], offset, .little);
    std.mem.writeInt(u64, data[8..16], @intCast(bytes.len), .little);
    @memcpy(data[16 .. 16 + bytes.len], bytes);

    metas[0] = AccountMeta.writable(program_address);
    metas[1] = AccountMeta.signer(authority_address);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas, .data = data[0 .. WRITE_DATA_OVERHEAD + bytes.len] };
}

pub fn copy(
    program_address: *const Pubkey,
    authority_address: *const Pubkey,
    source_address: *const Pubkey,
    destination_offset: u32,
    source_offset: u32,
    length: u32,
    metas: *[3]AccountMeta,
    data: *CopyData,
) Instruction {
    writeInstructionTag(.copy, data[0..4]);
    std.mem.writeInt(u32, data[4..8], destination_offset, .little);
    std.mem.writeInt(u32, data[8..12], source_offset, .little);
    std.mem.writeInt(u32, data[12..16], length, .little);

    metas[0] = AccountMeta.writable(program_address);
    metas[1] = AccountMeta.signer(authority_address);
    metas[2] = AccountMeta.readonly(source_address);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas, .data = data };
}

pub fn setProgramLength(
    program_address: *const Pubkey,
    authority_address: *const Pubkey,
    new_size: u32,
    recipient_address: *const Pubkey,
    metas: *[3]AccountMeta,
    data: *SetProgramLengthData,
) Instruction {
    writeInstructionTag(.set_program_length, data[0..4]);
    std.mem.writeInt(u32, data[4..8], new_size, .little);

    metas[0] = AccountMeta.writable(program_address);
    metas[1] = AccountMeta.signer(authority_address);
    metas[2] = AccountMeta.writable(recipient_address);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas, .data = data };
}

pub fn deploy(
    program_address: *const Pubkey,
    authority_address: *const Pubkey,
    metas: *[2]AccountMeta,
    data: *DiscriminantData,
) Instruction {
    writeInstructionTag(.deploy, data[0..]);
    metas[0] = AccountMeta.writable(program_address);
    metas[1] = AccountMeta.signer(authority_address);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas, .data = data };
}

pub fn deployFromSource(
    program_address: *const Pubkey,
    authority_address: *const Pubkey,
    source_address: *const Pubkey,
    metas: *[3]AccountMeta,
    data: *DiscriminantData,
) Instruction {
    writeInstructionTag(.deploy, data[0..]);
    metas[0] = AccountMeta.writable(program_address);
    metas[1] = AccountMeta.signer(authority_address);
    metas[2] = AccountMeta.writable(source_address);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas, .data = data };
}

pub fn retract(
    program_address: *const Pubkey,
    authority_address: *const Pubkey,
    metas: *[2]AccountMeta,
    data: *DiscriminantData,
) Instruction {
    writeInstructionTag(.retract, data[0..]);
    metas[0] = AccountMeta.writable(program_address);
    metas[1] = AccountMeta.signer(authority_address);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas, .data = data };
}

pub fn transferAuthority(
    program_address: *const Pubkey,
    authority_address: *const Pubkey,
    new_authority_address: *const Pubkey,
    metas: *[3]AccountMeta,
    data: *DiscriminantData,
) Instruction {
    writeInstructionTag(.transfer_authority, data[0..]);
    metas[0] = AccountMeta.writable(program_address);
    metas[1] = AccountMeta.signer(authority_address);
    metas[2] = AccountMeta.signer(new_authority_address);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas, .data = data };
}

pub fn finalize(
    program_address: *const Pubkey,
    authority_address: *const Pubkey,
    next_version_program_address: *const Pubkey,
    metas: *[3]AccountMeta,
    data: *DiscriminantData,
) Instruction {
    writeInstructionTag(.finalize, data[0..]);
    metas[0] = AccountMeta.writable(program_address);
    metas[1] = AccountMeta.signer(authority_address);
    metas[2] = AccountMeta.readonly(next_version_program_address);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas, .data = data };
}

pub fn createBuffer(
    payer_address: *const Pubkey,
    buffer_address: *const Pubkey,
    lamports: u64,
    authority_address: *const Pubkey,
    new_size: u32,
    recipient_address: *const Pubkey,
    buffers: CreateBufferBuffers,
) CreateBufferInstructions {
    return .{
        .instructions = .{
            system.createAccount(
                payer_address,
                buffer_address,
                lamports,
                0,
                &PROGRAM_ID,
                buffers.create_metas,
                buffers.create_data,
            ),
            setProgramLength(
                buffer_address,
                authority_address,
                new_size,
                recipient_address,
                buffers.length_metas,
                buffers.length_data,
            ),
        },
    };
}

pub fn isWriteInstruction(instruction_data: []const u8) bool {
    return hasInstructionTag(instruction_data, .write);
}

pub fn isCopyInstruction(instruction_data: []const u8) bool {
    return hasInstructionTag(instruction_data, .copy);
}

pub fn isSetProgramLengthInstruction(instruction_data: []const u8) bool {
    return hasInstructionTag(instruction_data, .set_program_length);
}

pub fn isDeployInstruction(instruction_data: []const u8) bool {
    return hasInstructionTag(instruction_data, .deploy);
}

pub fn isRetractInstruction(instruction_data: []const u8) bool {
    return hasInstructionTag(instruction_data, .retract);
}

pub fn isTransferAuthorityInstruction(instruction_data: []const u8) bool {
    return hasInstructionTag(instruction_data, .transfer_authority);
}

pub fn isFinalizeInstruction(instruction_data: []const u8) bool {
    return hasInstructionTag(instruction_data, .finalize);
}

fn hasInstructionTag(instruction_data: []const u8, tag: InstructionTag) bool {
    return instruction_data.len >= 4 and std.mem.readInt(u32, instruction_data[0..4], .little) == @intFromEnum(tag);
}

fn writeInstructionTag(tag: InstructionTag, out: []u8) void {
    std.mem.writeInt(u32, out[0..4], @intFromEnum(tag), .little);
}

test "state layout matches official loader-v4 offsets" {
    try std.testing.expectEqual(@as(usize, 0x30), STATE_PROGRAM_DATA_OFFSET);
    try std.testing.expectEqual(@as(usize, 0x00), @offsetOf(LoaderV4State, "slot"));
    try std.testing.expectEqual(@as(usize, 0x08), @offsetOf(LoaderV4State, "authority_address_or_next_version"));
    try std.testing.expectEqual(@as(usize, 0x28), @offsetOf(LoaderV4State, "status"));
    try std.testing.expectEqual(@as(usize, 0x30), @sizeOf(LoaderV4State));
    try std.testing.expectEqual(@as(u64, 0), @intFromEnum(LoaderV4Status.retracted));
    try std.testing.expectEqual(@as(u64, 1), @intFromEnum(LoaderV4Status.deployed));
    try std.testing.expectEqual(@as(u64, 2), @intFromEnum(LoaderV4Status.finalized));
}

test "instruction data layouts match official bincode tags" {
    const program: Pubkey = .{1} ** 32;
    const authority: Pubkey = .{2} ** 32;
    const source: Pubkey = .{3} ** 32;
    const recipient: Pubkey = .{4} ** 32;

    var write_metas: [2]AccountMeta = undefined;
    var write_data: [32]u8 = undefined;
    const write_ix = try write(&program, &authority, 7, &.{ 1, 2, 3 }, &write_metas, &write_data);
    try std.testing.expect(isWriteInstruction(write_ix.data));
    try std.testing.expectEqual(@as(u32, 7), std.mem.readInt(u32, write_ix.data[4..8], .little));
    try std.testing.expectEqual(@as(u64, 3), std.mem.readInt(u64, write_ix.data[8..16], .little));
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, write_ix.data[16..19]);

    var copy_metas: [3]AccountMeta = undefined;
    var copy_data: CopyData = undefined;
    const copy_ix = copy(&program, &authority, &source, 1, 2, 3, &copy_metas, &copy_data);
    try std.testing.expect(isCopyInstruction(copy_ix.data));
    try std.testing.expectEqual(@as(u32, 1), std.mem.readInt(u32, copy_ix.data[4..8], .little));
    try std.testing.expectEqual(@as(u32, 2), std.mem.readInt(u32, copy_ix.data[8..12], .little));
    try std.testing.expectEqual(@as(u32, 3), std.mem.readInt(u32, copy_ix.data[12..16], .little));

    var length_metas: [3]AccountMeta = undefined;
    var length_data: SetProgramLengthData = undefined;
    const length_ix = setProgramLength(&program, &authority, 1024, &recipient, &length_metas, &length_data);
    try std.testing.expect(isSetProgramLengthInstruction(length_ix.data));
    try std.testing.expectEqual(@as(u32, 1024), std.mem.readInt(u32, length_ix.data[4..8], .little));
}

test "management builders match official account shape" {
    const program: Pubkey = .{1} ** 32;
    const authority: Pubkey = .{2} ** 32;
    const source: Pubkey = .{3} ** 32;
    const new_authority: Pubkey = .{4} ** 32;
    const next_version: Pubkey = .{5} ** 32;

    var deploy_metas: [2]AccountMeta = undefined;
    var deploy_data: DiscriminantData = undefined;
    const deploy_ix = deploy(&program, &authority, &deploy_metas, &deploy_data);
    try std.testing.expect(isDeployInstruction(deploy_ix.data));
    try std.testing.expectEqual(@as(usize, 2), deploy_ix.accounts.len);
    try std.testing.expectEqual(@as(u8, 1), deploy_ix.accounts[0].is_writable);
    try std.testing.expectEqual(@as(u8, 1), deploy_ix.accounts[1].is_signer);

    var source_metas: [3]AccountMeta = undefined;
    var source_data: DiscriminantData = undefined;
    const source_ix = deployFromSource(&program, &authority, &source, &source_metas, &source_data);
    try std.testing.expect(isDeployInstruction(source_ix.data));
    try std.testing.expectEqual(@as(u8, 1), source_ix.accounts[2].is_writable);

    var retract_metas: [2]AccountMeta = undefined;
    var retract_data: DiscriminantData = undefined;
    const retract_ix = retract(&program, &authority, &retract_metas, &retract_data);
    try std.testing.expect(isRetractInstruction(retract_ix.data));

    var transfer_metas: [3]AccountMeta = undefined;
    var transfer_data: DiscriminantData = undefined;
    const transfer_ix = transferAuthority(&program, &authority, &new_authority, &transfer_metas, &transfer_data);
    try std.testing.expect(isTransferAuthorityInstruction(transfer_ix.data));
    try std.testing.expectEqual(@as(u8, 1), transfer_ix.accounts[2].is_signer);

    var finalize_metas: [3]AccountMeta = undefined;
    var finalize_data: DiscriminantData = undefined;
    const finalize_ix = finalize(&program, &authority, &next_version, &finalize_metas, &finalize_data);
    try std.testing.expect(isFinalizeInstruction(finalize_ix.data));
    try std.testing.expectEqual(@as(u8, 0), finalize_ix.accounts[2].is_signer);
}

test "createBuffer pairs system create account with initial length instruction" {
    const payer: Pubkey = .{1} ** 32;
    const buffer: Pubkey = .{2} ** 32;
    const authority: Pubkey = .{3} ** 32;
    const recipient: Pubkey = .{4} ** 32;

    var create_metas: [2]system.AccountMeta = undefined;
    var create_data: system.CreateAccountData = undefined;
    var length_metas: [3]AccountMeta = undefined;
    var length_data: SetProgramLengthData = undefined;

    const instructions = createBuffer(&payer, &buffer, 500, &authority, 123, &recipient, .{
        .create_metas = &create_metas,
        .create_data = &create_data,
        .length_metas = &length_metas,
        .length_data = &length_data,
    });

    try std.testing.expectEqual(@as(usize, 2), instructions.slice().len);
    try std.testing.expectEqual(@as(u64, 0), std.mem.readInt(u64, instructions.createAccount().data[12..20], .little));
    try std.testing.expect(isSetProgramLengthInstruction(instructions.setProgramLength().data));
    try std.testing.expectEqual(@as(u32, 123), std.mem.readInt(u32, instructions.setProgramLength().data[4..8], .little));
}
