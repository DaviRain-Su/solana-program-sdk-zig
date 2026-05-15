//! `spl_elgamal_registry` - SPL ElGamal Registry PDA, state layout,
//! and instruction builders.

const std = @import("std");
const sol = @import("solana_program_sdk");

pub const Pubkey = sol.Pubkey;
pub const AccountMeta = sol.cpi.AccountMeta;
pub const Instruction = sol.cpi.Instruction;
pub const ProgramDerivedAddress = sol.pda.ProgramDerivedAddress;

pub const PROGRAM_ID: Pubkey = sol.pubkey.comptimeFromBase58("regVYJW7tcT8zipN5YiBvHsvR5jXW1uLFxaHSbugABg");
pub const SYSTEM_PROGRAM_ID: Pubkey = sol.system_program_id;
pub const INSTRUCTIONS_SYSVAR_ID: Pubkey = sol.instructions_sysvar_id;
pub const REGISTRY_ADDRESS_SEED: []const u8 = "elgamal-registry";

pub const ELGAMAL_PUBKEY_BYTES: usize = 32;
pub const ELGAMAL_REGISTRY_ACCOUNT_LEN: usize = sol.PUBKEY_BYTES + ELGAMAL_PUBKEY_BYTES;

pub const RegistryAccount = extern struct {
    owner: Pubkey,
    elgamal_pubkey: [ELGAMAL_PUBKEY_BYTES]u8,
};

pub const RegistryInstruction = enum(u8) {
    create_registry = 0,
    update_registry = 1,
};

pub const DATA_LEN: usize = 2;
pub const CreateRegistryData = [DATA_LEN]u8;
pub const UpdateRegistryData = [DATA_LEN]u8;

pub const CreateContextMetas = [4]AccountMeta;
pub const UpdateContextMetas = [3]AccountMeta;
pub const CreateInstructionOffsetMetas = [4]AccountMeta;
pub const UpdateInstructionOffsetMetas = [3]AccountMeta;
pub const CreateRecordMetas = [5]AccountMeta;
pub const UpdateRecordMetas = [4]AccountMeta;

pub fn findRegistryAddress(wallet: *const Pubkey) ProgramDerivedAddress {
    return sol.pda.findProgramAddress(&.{ REGISTRY_ADDRESS_SEED, wallet }, &PROGRAM_ID) catch unreachable;
}

pub fn writeInstructionData(
    tag: RegistryInstruction,
    proof_instruction_offset: i8,
    out: *[DATA_LEN]u8,
) []const u8 {
    out[0] = @intFromEnum(tag);
    out[1] = @bitCast(proof_instruction_offset);
    return out;
}

pub fn createRegistryWithContext(
    owner: *const Pubkey,
    context_state_account: *const Pubkey,
    registry_out: *Pubkey,
    metas: *CreateContextMetas,
    data: *CreateRegistryData,
) Instruction {
    registry_out.* = findRegistryAddress(owner).address;
    return createRegistryWithContextForRegistry(owner, context_state_account, registry_out, metas, data);
}

pub fn createRegistryWithContextForRegistry(
    owner: *const Pubkey,
    context_state_account: *const Pubkey,
    registry: *const Pubkey,
    metas: *CreateContextMetas,
    data: *CreateRegistryData,
) Instruction {
    metas[0] = AccountMeta.writable(registry);
    metas[1] = AccountMeta.signer(owner);
    metas[2] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    metas[3] = AccountMeta.readonly(context_state_account);
    return .{
        .program_id = &PROGRAM_ID,
        .accounts = metas,
        .data = writeInstructionData(.create_registry, 0, data),
    };
}

pub fn updateRegistryWithContext(
    owner: *const Pubkey,
    context_state_account: *const Pubkey,
    registry_out: *Pubkey,
    metas: *UpdateContextMetas,
    data: *UpdateRegistryData,
) Instruction {
    registry_out.* = findRegistryAddress(owner).address;
    return updateRegistryWithContextForRegistry(owner, context_state_account, registry_out, metas, data);
}

pub fn updateRegistryWithContextForRegistry(
    owner: *const Pubkey,
    context_state_account: *const Pubkey,
    registry: *const Pubkey,
    metas: *UpdateContextMetas,
    data: *UpdateRegistryData,
) Instruction {
    metas[0] = AccountMeta.writable(registry);
    metas[1] = AccountMeta.readonly(context_state_account);
    metas[2] = AccountMeta.signer(owner);
    return .{
        .program_id = &PROGRAM_ID,
        .accounts = metas,
        .data = writeInstructionData(.update_registry, 0, data),
    };
}

pub fn createRegistryWithInstructionOffset(
    owner: *const Pubkey,
    proof_instruction_offset: i8,
    registry_out: *Pubkey,
    metas: *CreateInstructionOffsetMetas,
    data: *CreateRegistryData,
) Instruction {
    registry_out.* = findRegistryAddress(owner).address;
    return createRegistryWithInstructionOffsetForRegistry(owner, proof_instruction_offset, registry_out, metas, data);
}

pub fn createRegistryWithInstructionOffsetForRegistry(
    owner: *const Pubkey,
    proof_instruction_offset: i8,
    registry: *const Pubkey,
    metas: *CreateInstructionOffsetMetas,
    data: *CreateRegistryData,
) Instruction {
    metas[0] = AccountMeta.writable(registry);
    metas[1] = AccountMeta.signer(owner);
    metas[2] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    metas[3] = AccountMeta.readonly(&INSTRUCTIONS_SYSVAR_ID);
    return .{
        .program_id = &PROGRAM_ID,
        .accounts = metas,
        .data = writeInstructionData(.create_registry, proof_instruction_offset, data),
    };
}

pub fn updateRegistryWithInstructionOffset(
    owner: *const Pubkey,
    proof_instruction_offset: i8,
    registry_out: *Pubkey,
    metas: *UpdateInstructionOffsetMetas,
    data: *UpdateRegistryData,
) Instruction {
    registry_out.* = findRegistryAddress(owner).address;
    return updateRegistryWithInstructionOffsetForRegistry(owner, proof_instruction_offset, registry_out, metas, data);
}

pub fn updateRegistryWithInstructionOffsetForRegistry(
    owner: *const Pubkey,
    proof_instruction_offset: i8,
    registry: *const Pubkey,
    metas: *UpdateInstructionOffsetMetas,
    data: *UpdateRegistryData,
) Instruction {
    metas[0] = AccountMeta.writable(registry);
    metas[1] = AccountMeta.readonly(&INSTRUCTIONS_SYSVAR_ID);
    metas[2] = AccountMeta.signer(owner);
    return .{
        .program_id = &PROGRAM_ID,
        .accounts = metas,
        .data = writeInstructionData(.update_registry, proof_instruction_offset, data),
    };
}

pub fn createRegistryWithRecordAccount(
    owner: *const Pubkey,
    proof_instruction_offset: i8,
    record_account: *const Pubkey,
    registry_out: *Pubkey,
    metas: *CreateRecordMetas,
    data: *CreateRegistryData,
) Instruction {
    registry_out.* = findRegistryAddress(owner).address;
    return createRegistryWithRecordAccountForRegistry(owner, proof_instruction_offset, record_account, registry_out, metas, data);
}

pub fn createRegistryWithRecordAccountForRegistry(
    owner: *const Pubkey,
    proof_instruction_offset: i8,
    record_account: *const Pubkey,
    registry: *const Pubkey,
    metas: *CreateRecordMetas,
    data: *CreateRegistryData,
) Instruction {
    metas[0] = AccountMeta.writable(registry);
    metas[1] = AccountMeta.signer(owner);
    metas[2] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    metas[3] = AccountMeta.readonly(&INSTRUCTIONS_SYSVAR_ID);
    metas[4] = AccountMeta.readonly(record_account);
    return .{
        .program_id = &PROGRAM_ID,
        .accounts = metas,
        .data = writeInstructionData(.create_registry, proof_instruction_offset, data),
    };
}

pub fn updateRegistryWithRecordAccount(
    owner: *const Pubkey,
    proof_instruction_offset: i8,
    record_account: *const Pubkey,
    registry_out: *Pubkey,
    metas: *UpdateRecordMetas,
    data: *UpdateRegistryData,
) Instruction {
    registry_out.* = findRegistryAddress(owner).address;
    return updateRegistryWithRecordAccountForRegistry(owner, proof_instruction_offset, record_account, registry_out, metas, data);
}

pub fn updateRegistryWithRecordAccountForRegistry(
    owner: *const Pubkey,
    proof_instruction_offset: i8,
    record_account: *const Pubkey,
    registry: *const Pubkey,
    metas: *UpdateRecordMetas,
    data: *UpdateRegistryData,
) Instruction {
    metas[0] = AccountMeta.writable(registry);
    metas[1] = AccountMeta.readonly(&INSTRUCTIONS_SYSVAR_ID);
    metas[2] = AccountMeta.readonly(record_account);
    metas[3] = AccountMeta.signer(owner);
    return .{
        .program_id = &PROGRAM_ID,
        .accounts = metas,
        .data = writeInstructionData(.update_registry, proof_instruction_offset, data),
    };
}

fn expectMeta(
    actual: AccountMeta,
    expected_key: *const Pubkey,
    expected_writable: u8,
    expected_signer: u8,
) !void {
    try std.testing.expectEqualSlices(u8, expected_key, actual.pubkey);
    try std.testing.expectEqual(expected_writable, actual.is_writable);
    try std.testing.expectEqual(expected_signer, actual.is_signer);
}

test "state layout matches official pod account shape" {
    try std.testing.expectEqual(@as(usize, 64), @sizeOf(RegistryAccount));
    try std.testing.expectEqual(@as(usize, 64), ELGAMAL_REGISTRY_ACCOUNT_LEN);
    try std.testing.expectEqual(@as(usize, 0), @offsetOf(RegistryAccount, "owner"));
    try std.testing.expectEqual(@as(usize, 32), @offsetOf(RegistryAccount, "elgamal_pubkey"));
}

test "instruction data packs tag plus signed proof offset byte" {
    var create_data: CreateRegistryData = undefined;
    var update_data: UpdateRegistryData = undefined;

    try std.testing.expectEqualSlices(u8, &.{ 0, 0 }, writeInstructionData(.create_registry, 0, &create_data));
    try std.testing.expectEqualSlices(u8, &.{ 1, 255 }, writeInstructionData(.update_registry, -1, &update_data));
}

test "context-state create and update builders match official account shape" {
    const owner: Pubkey = .{1} ** 32;
    const context: Pubkey = .{2} ** 32;
    const registry = findRegistryAddress(&owner);
    var create_registry: Pubkey = undefined;
    var create_metas: CreateContextMetas = undefined;
    var create_data: CreateRegistryData = undefined;
    var update_registry: Pubkey = undefined;
    var update_metas: UpdateContextMetas = undefined;
    var update_data: UpdateRegistryData = undefined;

    const create_ix = createRegistryWithContext(&owner, &context, &create_registry, &create_metas, &create_data);
    try std.testing.expectEqualSlices(u8, &PROGRAM_ID, create_ix.program_id);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0 }, create_ix.data);
    try std.testing.expectEqual(@as(usize, 4), create_ix.accounts.len);
    try expectMeta(create_ix.accounts[0], &registry.address, 1, 0);
    try expectMeta(create_ix.accounts[1], &owner, 0, 1);
    try expectMeta(create_ix.accounts[2], &SYSTEM_PROGRAM_ID, 0, 0);
    try expectMeta(create_ix.accounts[3], &context, 0, 0);

    const update_ix = updateRegistryWithContext(&owner, &context, &update_registry, &update_metas, &update_data);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0 }, update_ix.data);
    try std.testing.expectEqual(@as(usize, 3), update_ix.accounts.len);
    try expectMeta(update_ix.accounts[0], &registry.address, 1, 0);
    try expectMeta(update_ix.accounts[1], &context, 0, 0);
    try expectMeta(update_ix.accounts[2], &owner, 0, 1);
}

test "instruction-offset and record-account builders expose proof accounts" {
    const owner: Pubkey = .{3} ** 32;
    const record: Pubkey = .{4} ** 32;
    var create_registry: Pubkey = undefined;
    var create_metas: CreateInstructionOffsetMetas = undefined;
    var create_data: CreateRegistryData = undefined;
    var update_registry: Pubkey = undefined;
    var update_metas: UpdateRecordMetas = undefined;
    var update_data: UpdateRegistryData = undefined;

    const create_ix = createRegistryWithInstructionOffset(&owner, 1, &create_registry, &create_metas, &create_data);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1 }, create_ix.data);
    try std.testing.expectEqual(@as(usize, 4), create_ix.accounts.len);
    try expectMeta(create_ix.accounts[3], &INSTRUCTIONS_SYSVAR_ID, 0, 0);

    const update_ix = updateRegistryWithRecordAccount(&owner, 1, &record, &update_registry, &update_metas, &update_data);
    try std.testing.expectEqualSlices(u8, &.{ 1, 1 }, update_ix.data);
    try std.testing.expectEqual(@as(usize, 4), update_ix.accounts.len);
    try expectMeta(update_ix.accounts[1], &INSTRUCTIONS_SYSVAR_ID, 0, 0);
    try expectMeta(update_ix.accounts[2], &record, 0, 0);
    try expectMeta(update_ix.accounts[3], &owner, 0, 1);
}

test "public surface guards" {
    try std.testing.expect(@hasDecl(@This(), "findRegistryAddress"));
    try std.testing.expect(@hasDecl(@This(), "createRegistryWithContext"));
    try std.testing.expect(@hasDecl(@This(), "createRegistryWithContextForRegistry"));
    try std.testing.expect(@hasDecl(@This(), "updateRegistryWithContext"));
    try std.testing.expect(@hasDecl(@This(), "createRegistryWithInstructionOffset"));
    try std.testing.expect(@hasDecl(@This(), "updateRegistryWithRecordAccount"));
}
