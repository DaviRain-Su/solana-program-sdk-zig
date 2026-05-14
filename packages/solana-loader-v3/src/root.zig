//! `solana_loader_v3` — Upgradeable BPF Loader helpers.

const std = @import("std");
const sol = @import("solana_program_sdk");
const system = @import("solana_system");

pub const Pubkey = sol.Pubkey;
pub const AccountMeta = sol.cpi.AccountMeta;
pub const Instruction = sol.cpi.Instruction;

pub const PROGRAM_ID: Pubkey = sol.bpf.bpf_upgradeable_loader_program_id;
pub const LOADER_V4_ID: Pubkey = sol.pubkey.comptimeFromBase58("LoaderV411111111111111111111111111111111111");
pub const SYSTEM_PROGRAM_ID: Pubkey = system.PROGRAM_ID;
pub const RENT_ID: Pubkey = sol.rent_id;
pub const CLOCK_ID: Pubkey = sol.clock_id;

pub const MINIMUM_EXTEND_PROGRAM_BYTES: u32 = 10_240;

pub const UNINITIALIZED_STATE_SIZE: usize = 4;
pub const BUFFER_METADATA_SIZE: usize = 37;
pub const PROGRAM_STATE_SIZE: usize = 36;
pub const PROGRAMDATA_METADATA_SIZE: usize = 45;

pub const DISCRIMINANT_DATA_LEN: usize = 4;
pub const DEPLOY_WITH_MAX_DATA_LEN: usize = 12;
pub const EXTEND_PROGRAM_DATA_LEN: usize = 8;
pub const WRITE_DATA_OVERHEAD: usize = 16;

pub const DiscriminantData = [DISCRIMINANT_DATA_LEN]u8;
pub const DeployWithMaxData = [DEPLOY_WITH_MAX_DATA_LEN]u8;
pub const ExtendProgramData = [EXTEND_PROGRAM_DATA_LEN]u8;
pub const UninitializedStateData = [UNINITIALIZED_STATE_SIZE]u8;
pub const BufferStateData = [BUFFER_METADATA_SIZE]u8;
pub const ProgramStateData = [PROGRAM_STATE_SIZE]u8;
pub const ProgramDataStateData = [PROGRAMDATA_METADATA_SIZE]u8;

pub const Error = error{
    BufferTooSmall,
    InvalidAccountMetaCount,
    InvalidInstructionTag,
    InvalidStateTag,
    InvalidOptionTag,
    InputTooShort,
};

pub const StateTag = enum(u32) {
    uninitialized = 0,
    buffer = 1,
    program = 2,
    program_data = 3,
};

pub const InstructionTag = enum(u32) {
    initialize_buffer = 0,
    write = 1,
    deploy_with_max_data_len = 2,
    upgrade = 3,
    set_authority = 4,
    close = 5,
    extend_program = 6,
    set_authority_checked = 7,
    migrate = 8,
    extend_program_checked = 9,
};

pub const ProgramDataState = struct {
    slot: u64,
    upgrade_authority_address: ?Pubkey,
};

pub const CreateBufferBuffers = struct {
    create_metas: *[2]system.AccountMeta,
    create_data: *system.CreateAccountData,
    initialize_metas: *[2]AccountMeta,
    initialize_data: *DiscriminantData,
};

pub const CreateBufferInstructions = struct {
    instructions: [2]Instruction,

    pub fn createAccount(self: *const CreateBufferInstructions) *const Instruction {
        return &self.instructions[0];
    }

    pub fn initializeBuffer(self: *const CreateBufferInstructions) *const Instruction {
        return &self.instructions[1];
    }

    pub fn slice(self: *const CreateBufferInstructions) []const Instruction {
        return self.instructions[0..];
    }
};

pub const DeployBuffers = struct {
    create_metas: *[2]system.AccountMeta,
    create_data: *system.CreateAccountData,
    deploy_metas: *[8]AccountMeta,
    deploy_data: *DeployWithMaxData,
};

pub const DeployInstructions = struct {
    instructions: [2]Instruction,

    pub fn createProgram(self: *const DeployInstructions) *const Instruction {
        return &self.instructions[0];
    }

    pub fn deploy(self: *const DeployInstructions) *const Instruction {
        return &self.instructions[1];
    }

    pub fn slice(self: *const DeployInstructions) []const Instruction {
        return self.instructions[0..];
    }
};

pub fn sizeOfBuffer(program_len: usize) usize {
    return BUFFER_METADATA_SIZE +| program_len;
}

pub fn sizeOfProgramData(program_len: usize) usize {
    return PROGRAMDATA_METADATA_SIZE +| program_len;
}

pub fn getProgramDataAddress(program_address: *const Pubkey) !Pubkey {
    return sol.bpf.getUpgradeableLoaderProgramDataId(program_address);
}

pub fn encodeUninitialized(out: *UninitializedStateData) []const u8 {
    writeStateTag(.uninitialized, out[0..]);
    return out[0..];
}

pub fn encodeBuffer(authority_address: ?*const Pubkey, out: *BufferStateData) []const u8 {
    @memset(out[0..], 0);
    writeStateTag(.buffer, out[0..4]);
    if (authority_address) |authority| {
        out[4] = 1;
        @memcpy(out[5..37], authority);
    }
    return out[0..];
}

pub fn encodeProgram(programdata_address: *const Pubkey, out: *ProgramStateData) []const u8 {
    writeStateTag(.program, out[0..4]);
    @memcpy(out[4..36], programdata_address);
    return out[0..];
}

pub fn encodeProgramData(state: ProgramDataState, out: *ProgramDataStateData) []const u8 {
    @memset(out[0..], 0);
    writeStateTag(.program_data, out[0..4]);
    std.mem.writeInt(u64, out[4..12], state.slot, .little);
    if (state.upgrade_authority_address) |authority| {
        out[12] = 1;
        @memcpy(out[13..45], &authority);
    }
    return out[0..];
}

pub fn decodeProgramData(input: []const u8) Error!ProgramDataState {
    if (input.len < PROGRAMDATA_METADATA_SIZE) return error.InputTooShort;
    if (readStateTag(input) != .program_data) return error.InvalidStateTag;
    return .{
        .slot = std.mem.readInt(u64, input[4..12], .little),
        .upgrade_authority_address = switch (input[12]) {
            0 => null,
            1 => input[13..45].*,
            else => return error.InvalidOptionTag,
        },
    };
}

pub fn initializeBuffer(
    buffer_address: *const Pubkey,
    authority_address: *const Pubkey,
    metas: *[2]AccountMeta,
    data: *DiscriminantData,
) Instruction {
    writeInstructionTag(.initialize_buffer, data[0..]);
    metas[0] = AccountMeta.writable(buffer_address);
    metas[1] = AccountMeta.readonly(authority_address);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas, .data = data };
}

pub fn initializeImmutableBuffer(
    buffer_address: *const Pubkey,
    metas: *[1]AccountMeta,
    data: *DiscriminantData,
) Instruction {
    writeInstructionTag(.initialize_buffer, data[0..]);
    metas[0] = AccountMeta.writable(buffer_address);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas, .data = data };
}

pub fn write(
    buffer_address: *const Pubkey,
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

    metas[0] = AccountMeta.writable(buffer_address);
    metas[1] = AccountMeta.signer(authority_address);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas, .data = data[0 .. WRITE_DATA_OVERHEAD + bytes.len] };
}

pub fn deployWithMaxDataLen(
    payer_address: *const Pubkey,
    programdata_address: *const Pubkey,
    program_address: *const Pubkey,
    buffer_address: *const Pubkey,
    upgrade_authority_address: *const Pubkey,
    max_data_len: usize,
    metas: *[8]AccountMeta,
    data: *DeployWithMaxData,
) Instruction {
    writeInstructionTag(.deploy_with_max_data_len, data[0..4]);
    std.mem.writeInt(u64, data[4..12], @intCast(max_data_len), .little);

    metas[0] = AccountMeta.signerWritable(payer_address);
    metas[1] = AccountMeta.writable(programdata_address);
    metas[2] = AccountMeta.writable(program_address);
    metas[3] = AccountMeta.writable(buffer_address);
    metas[4] = AccountMeta.readonly(&RENT_ID);
    metas[5] = AccountMeta.readonly(&CLOCK_ID);
    metas[6] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    metas[7] = AccountMeta.signer(upgrade_authority_address);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas, .data = data };
}

pub fn upgrade(
    programdata_address: *const Pubkey,
    program_address: *const Pubkey,
    buffer_address: *const Pubkey,
    spill_address: *const Pubkey,
    authority_address: *const Pubkey,
    metas: *[7]AccountMeta,
    data: *DiscriminantData,
) Instruction {
    writeInstructionTag(.upgrade, data[0..]);
    metas[0] = AccountMeta.writable(programdata_address);
    metas[1] = AccountMeta.writable(program_address);
    metas[2] = AccountMeta.writable(buffer_address);
    metas[3] = AccountMeta.writable(spill_address);
    metas[4] = AccountMeta.readonly(&RENT_ID);
    metas[5] = AccountMeta.readonly(&CLOCK_ID);
    metas[6] = AccountMeta.signer(authority_address);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas, .data = data };
}

pub fn setAuthority(
    account_address: *const Pubkey,
    current_authority_address: *const Pubkey,
    new_authority_address: ?*const Pubkey,
    metas: []AccountMeta,
    data: *DiscriminantData,
) Error!Instruction {
    const needed: usize = if (new_authority_address == null) 2 else 3;
    if (metas.len < needed) return error.InvalidAccountMetaCount;
    writeInstructionTag(.set_authority, data[0..]);
    metas[0] = AccountMeta.writable(account_address);
    metas[1] = AccountMeta.signer(current_authority_address);
    if (new_authority_address) |new_authority| {
        metas[2] = AccountMeta.readonly(new_authority);
    }
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..needed], .data = data };
}

pub fn setAuthorityChecked(
    account_address: *const Pubkey,
    current_authority_address: *const Pubkey,
    new_authority_address: *const Pubkey,
    metas: *[3]AccountMeta,
    data: *DiscriminantData,
) Instruction {
    writeInstructionTag(.set_authority_checked, data[0..]);
    metas[0] = AccountMeta.writable(account_address);
    metas[1] = AccountMeta.signer(current_authority_address);
    metas[2] = AccountMeta.signer(new_authority_address);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas, .data = data };
}

pub fn closeAny(
    close_address: *const Pubkey,
    recipient_address: *const Pubkey,
    authority_address: ?*const Pubkey,
    program_address: ?*const Pubkey,
    metas: []AccountMeta,
    data: *DiscriminantData,
) Error!Instruction {
    const needed: usize = 2 + @as(usize, if (authority_address == null) 0 else 1) + @as(usize, if (program_address == null) 0 else 1);
    if (metas.len < needed) return error.InvalidAccountMetaCount;
    writeInstructionTag(.close, data[0..]);
    metas[0] = AccountMeta.writable(close_address);
    metas[1] = AccountMeta.writable(recipient_address);
    var idx: usize = 2;
    if (authority_address) |authority| {
        metas[idx] = AccountMeta.signer(authority);
        idx += 1;
    }
    if (program_address) |program| {
        metas[idx] = AccountMeta.writable(program);
    }
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..needed], .data = data };
}

pub fn extendProgram(
    programdata_address: *const Pubkey,
    program_address: *const Pubkey,
    payer_address: ?*const Pubkey,
    additional_bytes: u32,
    metas: []AccountMeta,
    data: *ExtendProgramData,
) Error!Instruction {
    const needed: usize = if (payer_address == null) 2 else 4;
    if (metas.len < needed) return error.InvalidAccountMetaCount;
    writeInstructionTag(.extend_program, data[0..4]);
    std.mem.writeInt(u32, data[4..8], additional_bytes, .little);
    metas[0] = AccountMeta.writable(programdata_address);
    metas[1] = AccountMeta.writable(program_address);
    if (payer_address) |payer| {
        metas[2] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
        metas[3] = AccountMeta.signerWritable(payer);
    }
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..needed], .data = data };
}

pub fn migrateProgram(
    programdata_address: *const Pubkey,
    program_address: *const Pubkey,
    authority_address: *const Pubkey,
    metas: *[4]AccountMeta,
    data: *DiscriminantData,
) Instruction {
    writeInstructionTag(.migrate, data[0..]);
    metas[0] = AccountMeta.writable(programdata_address);
    metas[1] = AccountMeta.writable(program_address);
    metas[2] = AccountMeta.signer(authority_address);
    metas[3] = AccountMeta.readonly(&LOADER_V4_ID);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas, .data = data };
}

pub fn extendProgramChecked(
    programdata_address: *const Pubkey,
    program_address: *const Pubkey,
    authority_address: *const Pubkey,
    payer_address: ?*const Pubkey,
    additional_bytes: u32,
    metas: []AccountMeta,
    data: *ExtendProgramData,
) Error!Instruction {
    const needed: usize = if (payer_address == null) 3 else 5;
    if (metas.len < needed) return error.InvalidAccountMetaCount;
    writeInstructionTag(.extend_program_checked, data[0..4]);
    std.mem.writeInt(u32, data[4..8], additional_bytes, .little);
    metas[0] = AccountMeta.writable(programdata_address);
    metas[1] = AccountMeta.writable(program_address);
    metas[2] = AccountMeta.signerWritable(authority_address);
    if (payer_address) |payer| {
        metas[3] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
        metas[4] = AccountMeta.signer(payer);
    }
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..needed], .data = data };
}

pub fn createBuffer(
    payer_address: *const Pubkey,
    buffer_address: *const Pubkey,
    authority_address: *const Pubkey,
    lamports: u64,
    program_len: usize,
    buffers: CreateBufferBuffers,
) CreateBufferInstructions {
    return .{
        .instructions = .{
            system.createAccount(
                payer_address,
                buffer_address,
                lamports,
                @intCast(sizeOfBuffer(program_len)),
                &PROGRAM_ID,
                buffers.create_metas,
                buffers.create_data,
            ),
            initializeBuffer(
                buffer_address,
                authority_address,
                buffers.initialize_metas,
                buffers.initialize_data,
            ),
        },
    };
}

pub fn deployWithMaxProgramLen(
    payer_address: *const Pubkey,
    program_address: *const Pubkey,
    buffer_address: *const Pubkey,
    upgrade_authority_address: *const Pubkey,
    program_lamports: u64,
    max_data_len: usize,
    buffers: DeployBuffers,
) !DeployInstructions {
    const programdata_address = try getProgramDataAddress(program_address);
    return .{
        .instructions = .{
            system.createAccount(
                payer_address,
                program_address,
                program_lamports,
                PROGRAM_STATE_SIZE,
                &PROGRAM_ID,
                buffers.create_metas,
                buffers.create_data,
            ),
            deployWithMaxDataLen(
                payer_address,
                &programdata_address,
                program_address,
                buffer_address,
                upgrade_authority_address,
                max_data_len,
                buffers.deploy_metas,
                buffers.deploy_data,
            ),
        },
    };
}

pub fn isUpgradeInstruction(instruction_data: []const u8) bool {
    return hasInstructionTag(instruction_data, .upgrade);
}

pub fn isSetAuthorityInstruction(instruction_data: []const u8) bool {
    return hasInstructionTag(instruction_data, .set_authority);
}

pub fn isCloseInstruction(instruction_data: []const u8) bool {
    return hasInstructionTag(instruction_data, .close);
}

pub fn isSetAuthorityCheckedInstruction(instruction_data: []const u8) bool {
    return hasInstructionTag(instruction_data, .set_authority_checked);
}

pub fn isMigrateInstruction(instruction_data: []const u8) bool {
    return hasInstructionTag(instruction_data, .migrate);
}

pub fn isExtendProgramCheckedInstruction(instruction_data: []const u8) bool {
    return hasInstructionTag(instruction_data, .extend_program_checked);
}

fn hasInstructionTag(instruction_data: []const u8, tag: InstructionTag) bool {
    return instruction_data.len >= 4 and std.mem.readInt(u32, instruction_data[0..4], .little) == @intFromEnum(tag);
}

fn writeStateTag(tag: StateTag, out: []u8) void {
    std.mem.writeInt(u32, out[0..4], @intFromEnum(tag), .little);
}

fn readStateTag(input: []const u8) StateTag {
    return @enumFromInt(std.mem.readInt(u32, input[0..4], .little));
}

fn writeInstructionTag(tag: InstructionTag, out: []u8) void {
    std.mem.writeInt(u32, out[0..4], @intFromEnum(tag), .little);
}

test "state size helpers and encoders match bincode layout" {
    try std.testing.expectEqual(@as(usize, 4), UNINITIALIZED_STATE_SIZE);
    try std.testing.expectEqual(@as(usize, 37), BUFFER_METADATA_SIZE);
    try std.testing.expectEqual(@as(usize, 36), PROGRAM_STATE_SIZE);
    try std.testing.expectEqual(@as(usize, 45), PROGRAMDATA_METADATA_SIZE);
    try std.testing.expectEqual(@as(usize, BUFFER_METADATA_SIZE + 99), sizeOfBuffer(99));
    try std.testing.expectEqual(@as(usize, PROGRAMDATA_METADATA_SIZE + 99), sizeOfProgramData(99));

    const authority: Pubkey = .{9} ** 32;
    const programdata: Pubkey = .{7} ** 32;

    var uninitialized: UninitializedStateData = undefined;
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0 }, encodeUninitialized(&uninitialized));

    var buffer: BufferStateData = undefined;
    const buffer_data = encodeBuffer(&authority, &buffer);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 0, 0, 1 }, buffer_data[0..5]);
    try std.testing.expectEqualSlices(u8, &authority, buffer_data[5..37]);

    var immutable_buffer: BufferStateData = undefined;
    const immutable = encodeBuffer(null, &immutable_buffer);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 0, 0, 0 }, immutable[0..5]);

    var program: ProgramStateData = undefined;
    const program_data = encodeProgram(&programdata, &program);
    try std.testing.expectEqualSlices(u8, &.{ 2, 0, 0, 0 }, program_data[0..4]);
    try std.testing.expectEqualSlices(u8, &programdata, program_data[4..36]);

    var data: ProgramDataStateData = undefined;
    const programdata_data = encodeProgramData(.{ .slot = 42, .upgrade_authority_address = authority }, &data);
    try std.testing.expectEqualSlices(u8, &.{ 3, 0, 0, 0 }, programdata_data[0..4]);
    try std.testing.expectEqual(@as(u64, 42), std.mem.readInt(u64, programdata_data[4..12], .little));
    try std.testing.expectEqual(@as(u8, 1), programdata_data[12]);
    try std.testing.expectEqualSlices(u8, &authority, programdata_data[13..45]);
    try std.testing.expectEqual(@as(?u64, 42), (try decodeProgramData(programdata_data)).slot);
}

test "instruction data layouts match official bincode tags" {
    const buffer: Pubkey = .{1} ** 32;
    const authority: Pubkey = .{2} ** 32;

    var init_metas: [2]AccountMeta = undefined;
    var init_data: DiscriminantData = undefined;
    const init = initializeBuffer(&buffer, &authority, &init_metas, &init_data);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0 }, init.data);
    try std.testing.expectEqual(@as(u8, 1), init.accounts[0].is_writable);
    try std.testing.expectEqual(@as(u8, 0), init.accounts[1].is_signer);

    var write_metas: [2]AccountMeta = undefined;
    var write_data: [32]u8 = undefined;
    const write_ix = try write(&buffer, &authority, 7, &.{ 1, 2, 3 }, &write_metas, &write_data);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 0, 0 }, write_ix.data[0..4]);
    try std.testing.expectEqual(@as(u32, 7), std.mem.readInt(u32, write_ix.data[4..8], .little));
    try std.testing.expectEqual(@as(u64, 3), std.mem.readInt(u64, write_ix.data[8..16], .little));
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, write_ix.data[16..19]);
}

test "deploy and management builders match official account shape" {
    const payer: Pubkey = .{1} ** 32;
    const programdata: Pubkey = .{2} ** 32;
    const program: Pubkey = .{3} ** 32;
    const buffer: Pubkey = .{4} ** 32;
    const authority: Pubkey = .{5} ** 32;
    const spill: Pubkey = .{6} ** 32;
    const recipient: Pubkey = .{7} ** 32;

    var deploy_metas: [8]AccountMeta = undefined;
    var deploy_data: DeployWithMaxData = undefined;
    const deploy = deployWithMaxDataLen(&payer, &programdata, &program, &buffer, &authority, 4096, &deploy_metas, &deploy_data);
    try std.testing.expectEqualSlices(u8, &.{ 2, 0, 0, 0 }, deploy.data[0..4]);
    try std.testing.expectEqual(@as(u64, 4096), std.mem.readInt(u64, deploy.data[4..12], .little));
    try std.testing.expectEqual(@as(u8, 1), deploy.accounts[0].is_signer);
    try std.testing.expectEqual(@as(u8, 1), deploy.accounts[0].is_writable);
    try std.testing.expectEqual(@as(u8, 1), deploy.accounts[2].is_writable);
    try std.testing.expectEqual(@as(u8, 1), deploy.accounts[7].is_signer);

    var upgrade_metas: [7]AccountMeta = undefined;
    var upgrade_data: DiscriminantData = undefined;
    const upgrade_ix = upgrade(&programdata, &program, &buffer, &spill, &authority, &upgrade_metas, &upgrade_data);
    try std.testing.expect(isUpgradeInstruction(upgrade_ix.data));
    try std.testing.expectEqual(@as(u8, 1), upgrade_ix.accounts[0].is_writable);
    try std.testing.expectEqual(@as(u8, 1), upgrade_ix.accounts[6].is_signer);

    var set_metas: [3]AccountMeta = undefined;
    var set_data: DiscriminantData = undefined;
    const set_ix = try setAuthority(&programdata, &authority, &payer, &set_metas, &set_data);
    try std.testing.expect(isSetAuthorityInstruction(set_ix.data));
    try std.testing.expectEqual(@as(usize, 3), set_ix.accounts.len);
    try std.testing.expectEqual(@as(u8, 0), set_ix.accounts[2].is_signer);

    var close_metas: [4]AccountMeta = undefined;
    var close_data: DiscriminantData = undefined;
    const close_ix = try closeAny(&programdata, &recipient, &authority, &program, &close_metas, &close_data);
    try std.testing.expect(isCloseInstruction(close_ix.data));
    try std.testing.expectEqual(@as(usize, 4), close_ix.accounts.len);

    var extend_metas: [4]AccountMeta = undefined;
    var extend_data: ExtendProgramData = undefined;
    const extend_ix = try extendProgram(&programdata, &program, &payer, MINIMUM_EXTEND_PROGRAM_BYTES, &extend_metas, &extend_data);
    try std.testing.expectEqualSlices(u8, &.{ 6, 0, 0, 0 }, extend_ix.data[0..4]);
    try std.testing.expectEqual(@as(u32, MINIMUM_EXTEND_PROGRAM_BYTES), std.mem.readInt(u32, extend_ix.data[4..8], .little));

    var migrate_metas: [4]AccountMeta = undefined;
    var migrate_data: DiscriminantData = undefined;
    const migrate = migrateProgram(&programdata, &program, &authority, &migrate_metas, &migrate_data);
    try std.testing.expect(isMigrateInstruction(migrate.data));
    try std.testing.expectEqual(@as(u8, 0), migrate.accounts[3].is_signer);
}

test "composite helpers pair system and loader instructions" {
    const payer: Pubkey = .{1} ** 32;
    const buffer: Pubkey = .{2} ** 32;
    const authority: Pubkey = .{3} ** 32;
    const program: Pubkey = .{4} ** 32;

    var create_buffer_metas: [2]system.AccountMeta = undefined;
    var create_buffer_data: system.CreateAccountData = undefined;
    var init_metas: [2]AccountMeta = undefined;
    var init_data: DiscriminantData = undefined;
    const create_buffer = createBuffer(&payer, &buffer, &authority, 500, 123, .{
        .create_metas = &create_buffer_metas,
        .create_data = &create_buffer_data,
        .initialize_metas = &init_metas,
        .initialize_data = &init_data,
    });
    try std.testing.expectEqual(@as(usize, 2), create_buffer.slice().len);
    try std.testing.expectEqual(@as(u64, sizeOfBuffer(123)), std.mem.readInt(u64, create_buffer.createAccount().data[12..20], .little));
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0 }, create_buffer.initializeBuffer().data);

    var create_program_metas: [2]system.AccountMeta = undefined;
    var create_program_data: system.CreateAccountData = undefined;
    var deploy_metas: [8]AccountMeta = undefined;
    var deploy_data: DeployWithMaxData = undefined;
    const deploy = try deployWithMaxProgramLen(&payer, &program, &buffer, &authority, 700, 4096, .{
        .create_metas = &create_program_metas,
        .create_data = &create_program_data,
        .deploy_metas = &deploy_metas,
        .deploy_data = &deploy_data,
    });
    try std.testing.expectEqual(@as(usize, 2), deploy.slice().len);
    try std.testing.expectEqual(@as(u64, PROGRAM_STATE_SIZE), std.mem.readInt(u64, deploy.createProgram().data[12..20], .little));
    try std.testing.expectEqualSlices(u8, &.{ 2, 0, 0, 0 }, deploy.deploy().data[0..4]);
}
