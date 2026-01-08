//! Zig implementation of Solana SDK's BPF loader program IDs and instructions
//!
//! Rust sources:
//! - https://github.com/anza-xyz/solana-sdk/blob/master/sdk-ids/src/lib.rs
//! - https://github.com/anza-xyz/solana-sdk/blob/master/loader-v3-interface/src/instruction.rs
//!
//! This module provides the program IDs for Solana's BPF loaders and
//! instructions for the upgradeable BPF loader (loader-v3).

const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;
const AccountMeta = @import("instruction.zig").AccountMeta;
const sysvar_id = @import("sysvar_id.zig");
const system_program = @import("system_program.zig");

/// Built instruction for BPF loader operations
///
/// Owns the allocated data and accounts. Call `deinit` to free memory.
pub const BuiltInstruction = system_program.BuiltInstruction;

/// BPF Loader v1 (deprecated)
///
/// The original BPF loader, now deprecated in favor of v2 and upgradeable.
/// Programs deployed with this loader cannot be upgraded.
///
/// Rust equivalent: `solana_sdk::bpf_loader_deprecated::id()`
pub const bpf_loader_deprecated_id = PublicKey.comptimeFromBase58("BPFLoader1111111111111111111111111111111111");

/// BPF Loader v2
///
/// The standard BPF loader for non-upgradeable programs.
/// Programs deployed with this loader are immutable.
///
/// Rust equivalent: `solana_sdk::bpf_loader::id()`
pub const bpf_loader_id = PublicKey.comptimeFromBase58("BPFLoader2111111111111111111111111111111111");

/// BPF Loader Upgradeable
///
/// The upgradeable BPF loader that allows programs to be upgraded.
/// Most modern Solana programs use this loader.
///
/// Rust equivalent: `solana_sdk::bpf_loader_upgradeable::id()`
pub const bpf_loader_upgradeable_id = PublicKey.comptimeFromBase58("BPFLoaderUpgradeab1e11111111111111111111111");

/// Check if a program ID is one of the BPF loaders
pub fn isBpfLoader(program_id: PublicKey) bool {
    return program_id.equals(bpf_loader_deprecated_id) or
        program_id.equals(bpf_loader_id) or
        program_id.equals(bpf_loader_upgradeable_id);
}

/// Check if a program ID is the upgradeable loader
pub fn isUpgradeableLoader(program_id: PublicKey) bool {
    return program_id.equals(bpf_loader_upgradeable_id);
}

/// Upgradeable Loader State types
///
/// Rust equivalent: `solana_sdk::bpf_loader_upgradeable::UpgradeableLoaderState`
pub const UpgradeableLoaderState = union(enum) {
    /// Account is not initialized
    uninitialized,

    /// A Buffer account stores the program data while it's being deployed
    buffer: struct {
        /// Authority address that can write to the buffer
        authority_address: ?PublicKey,
    },

    /// An executable Program account
    program: struct {
        /// Address of the ProgramData account
        programdata_address: PublicKey,
    },

    /// A ProgramData account stores the program data and upgrade authority
    program_data: struct {
        /// Slot that the program was last modified
        slot: u64,
        /// Optional upgrade authority address. If None, the program is immutable.
        upgrade_authority_address: ?PublicKey,
    },
};

/// Size of UpgradeableLoaderState::Uninitialized
pub const UPGRADEABLE_LOADER_STATE_UNINITIALIZED_SIZE: usize = 4;

/// Size of UpgradeableLoaderState::Buffer (without program data)
pub const UPGRADEABLE_LOADER_STATE_BUFFER_SIZE: usize = 37;

/// Size of UpgradeableLoaderState::Program
pub const UPGRADEABLE_LOADER_STATE_PROGRAM_SIZE: usize = 36;

/// Size of UpgradeableLoaderState::ProgramData (without program data)
pub const UPGRADEABLE_LOADER_STATE_PROGRAMDATA_SIZE: usize = 45;

/// Derive the program address for an upgradeable program's data account
///
/// The ProgramData account address is derived from the program ID.
pub fn getProgramDataAddress(program_id: PublicKey) !struct { address: PublicKey, bump: u8 } {
    const seeds = [_][]const u8{&program_id.bytes};
    return try PublicKey.findProgramAddress(&seeds, bpf_loader_upgradeable_id);
}

// ============================================================================
// Upgradeable Loader Instructions
// ============================================================================

/// Instructions for the upgradeable BPF loader.
///
/// Rust equivalent: `solana_loader_v3_interface::instruction::UpgradeableLoaderInstruction`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/loader-v3-interface/src/instruction.rs
pub const UpgradeableLoaderInstruction = union(enum) {
    /// Initialize a Buffer account.
    ///
    /// A Buffer account is an intermediary that once fully populated is used
    /// with the `DeployWithMaxDataLen` instruction to populate the program's
    /// ProgramData account.
    ///
    /// # Account references
    ///   0. `[writable]` source account to initialize.
    ///   1. `[]` Buffer authority, optional, if omitted then the buffer will be immutable.
    InitializeBuffer,

    /// Write program data into a Buffer account.
    ///
    /// # Account references
    ///   0. `[writable]` Buffer account to write program data to.
    ///   1. `[signer]` Buffer authority
    Write: struct {
        /// Offset at which to write the given bytes.
        offset: u32,
        /// Serialized program data
        bytes: []const u8,
    },

    /// Deploy an executable program.
    ///
    /// # Account references
    ///   0. `[writable, signer]` The payer account
    ///   1. `[writable]` The uninitialized ProgramData account.
    ///   2. `[writable]` The uninitialized Program account.
    ///   3. `[writable]` The Buffer account where the program data has been written.
    ///   4. `[]` Rent sysvar.
    ///   5. `[]` Clock sysvar.
    ///   6. `[]` System program.
    ///   7. `[signer]` The program's authority
    DeployWithMaxDataLen: struct {
        /// Maximum length that the program can be upgraded to.
        max_data_len: usize,
    },

    /// Upgrade a program.
    ///
    /// # Account references
    ///   0. `[writable]` The ProgramData account.
    ///   1. `[writable]` The Program account.
    ///   2. `[writable]` The Buffer account where the program data has been written.
    ///   3. `[writable]` The spill account.
    ///   4. `[]` Rent sysvar.
    ///   5. `[]` Clock sysvar.
    ///   6. `[signer]` The program's authority.
    Upgrade,

    /// Set a new authority that is allowed to write the buffer or upgrade the program.
    ///
    /// # Account references
    ///   0. `[writable]` The Buffer or ProgramData account to change the authority of.
    ///   1. `[signer]` The current authority.
    ///   2. `[]` The new authority, optional.
    SetAuthority,

    /// Closes an account owned by the upgradeable loader.
    ///
    /// # Account references
    ///   0. `[writable]` The account to close.
    ///   1. `[writable]` The account to deposit the closed account's lamports.
    ///   2. `[signer]` The account's authority, optional.
    ///   3. `[writable]` The associated Program account if closing ProgramData.
    Close,

    /// Extend a program's ProgramData account by the specified number of bytes.
    ///
    /// # Account references
    ///   0. `[writable]` The ProgramData account.
    ///   1. `[writable]` The ProgramData account's associated Program account.
    ///   2. `[]` System program, optional.
    ///   3. `[writable, signer]` The payer account, optional.
    ExtendProgram: struct {
        /// Number of bytes to extend the program data.
        additional_bytes: u32,
    },

    /// Set a new authority (requires new authority to sign).
    ///
    /// # Account references
    ///   0. `[writable]` The Buffer or ProgramData account.
    ///   1. `[signer]` The current authority.
    ///   2. `[signer]` The new authority.
    SetAuthorityChecked,

    /// Migrate the program to loader-v4.
    ///
    /// # Account references
    ///   0. `[writable]` The ProgramData account.
    ///   1. `[writable]` The Program account.
    ///   2. `[signer]` The current authority.
    Migrate,

    /// Extend a program (requires authority to sign).
    ///
    /// # Account references
    ///   0. `[writable]` The ProgramData account.
    ///   1. `[writable]` The Program account.
    ///   2. `[signer]` The authority.
    ///   3. `[]` System program, optional.
    ///   4. `[signer]` The payer account, optional.
    ExtendProgramChecked: struct {
        /// Number of bytes to extend the program data.
        additional_bytes: u32,
    },

    /// Get the instruction discriminant byte
    pub fn getDiscriminant(self: UpgradeableLoaderInstruction) u8 {
        return switch (self) {
            .InitializeBuffer => 0,
            .Write => 1,
            .DeployWithMaxDataLen => 2,
            .Upgrade => 3,
            .SetAuthority => 4,
            .Close => 5,
            .ExtendProgram => 6,
            .SetAuthorityChecked => 7,
            .Migrate => 8,
            .ExtendProgramChecked => 9,
        };
    }

    /// Serialize instruction to bytes using bincode
    pub fn serialize(self: UpgradeableLoaderInstruction, allocator: std.mem.Allocator) ![]u8 {
        return switch (self) {
            .InitializeBuffer => blk: {
                var result = try allocator.alloc(u8, 4);
                std.mem.writeInt(u32, result[0..4], 0, .little);
                break :blk result;
            },
            .Write => |data| blk: {
                // discriminant (4 bytes) + offset (4 bytes) + length (8 bytes) + bytes
                const total_len = 4 + 4 + 8 + data.bytes.len;
                var result = try allocator.alloc(u8, total_len);
                std.mem.writeInt(u32, result[0..4], 1, .little);
                std.mem.writeInt(u32, result[4..8], data.offset, .little);
                std.mem.writeInt(u64, result[8..16], data.bytes.len, .little);
                @memcpy(result[16..], data.bytes);
                break :blk result;
            },
            .DeployWithMaxDataLen => |data| blk: {
                var result = try allocator.alloc(u8, 4 + 8);
                std.mem.writeInt(u32, result[0..4], 2, .little);
                std.mem.writeInt(u64, result[4..12], @intCast(data.max_data_len), .little);
                break :blk result;
            },
            .Upgrade => blk: {
                var result = try allocator.alloc(u8, 4);
                std.mem.writeInt(u32, result[0..4], 3, .little);
                break :blk result;
            },
            .SetAuthority => blk: {
                var result = try allocator.alloc(u8, 4);
                std.mem.writeInt(u32, result[0..4], 4, .little);
                break :blk result;
            },
            .Close => blk: {
                var result = try allocator.alloc(u8, 4);
                std.mem.writeInt(u32, result[0..4], 5, .little);
                break :blk result;
            },
            .ExtendProgram => |data| blk: {
                var result = try allocator.alloc(u8, 4 + 4);
                std.mem.writeInt(u32, result[0..4], 6, .little);
                std.mem.writeInt(u32, result[4..8], data.additional_bytes, .little);
                break :blk result;
            },
            .SetAuthorityChecked => blk: {
                var result = try allocator.alloc(u8, 4);
                std.mem.writeInt(u32, result[0..4], 7, .little);
                break :blk result;
            },
            .Migrate => blk: {
                var result = try allocator.alloc(u8, 4);
                std.mem.writeInt(u32, result[0..4], 8, .little);
                break :blk result;
            },
            .ExtendProgramChecked => |data| blk: {
                var result = try allocator.alloc(u8, 4 + 4);
                std.mem.writeInt(u32, result[0..4], 9, .little);
                std.mem.writeInt(u32, result[4..8], data.additional_bytes, .little);
                break :blk result;
            },
        };
    }
};

// ============================================================================
// Instruction Builders
// ============================================================================

/// Create an InitializeBuffer instruction
///
/// # Account references
///   0. `[writable]` Source account to initialize as buffer
///   1. `[]` Buffer authority (optional, if omitted buffer is immutable)
///
/// Rust equivalent: `solana_loader_v3_interface::instruction::initialize_buffer`
pub fn initializeBuffer(
    allocator: std.mem.Allocator,
    buffer_account: PublicKey,
    buffer_authority: ?PublicKey,
) !BuiltInstruction {
    const num_accounts: usize = if (buffer_authority != null) 2 else 1;
    const accounts = try allocator.alloc(AccountMeta, num_accounts);
    errdefer allocator.free(accounts);

    accounts[0] = AccountMeta.init(buffer_account, false, true); // writable
    if (buffer_authority) |authority| {
        accounts[1] = AccountMeta.init(authority, false, false); // readonly
    }

    const data = try allocator.alloc(u8, 4);
    std.mem.writeInt(u32, data[0..4], 0, .little); // InitializeBuffer discriminant

    return BuiltInstruction{
        .program_id = bpf_loader_upgradeable_id,
        .accounts = accounts,
        .data = data,
    };
}

/// Create a Write instruction
///
/// # Account references
///   0. `[writable]` Buffer account to write to
///   1. `[signer]` Buffer authority
///
/// Rust equivalent: `solana_loader_v3_interface::instruction::write`
pub fn writeBuffer(
    allocator: std.mem.Allocator,
    buffer_account: PublicKey,
    buffer_authority: PublicKey,
    offset: u32,
    bytes: []const u8,
) !BuiltInstruction {
    const accounts = try allocator.alloc(AccountMeta, 2);
    errdefer allocator.free(accounts);

    accounts[0] = AccountMeta.init(buffer_account, false, true); // writable
    accounts[1] = AccountMeta.init(buffer_authority, true, false); // signer

    // discriminant (4) + offset (4) + length (8) + bytes
    const data_len = 4 + 4 + 8 + bytes.len;
    const data = try allocator.alloc(u8, data_len);
    errdefer allocator.free(data);

    std.mem.writeInt(u32, data[0..4], 1, .little); // Write discriminant
    std.mem.writeInt(u32, data[4..8], offset, .little);
    std.mem.writeInt(u64, data[8..16], bytes.len, .little);
    @memcpy(data[16..], bytes);

    return BuiltInstruction{
        .program_id = bpf_loader_upgradeable_id,
        .accounts = accounts,
        .data = data,
    };
}

/// Create a DeployWithMaxDataLen instruction
///
/// # Account references
///   0. `[writable, signer]` Payer account
///   1. `[writable]` ProgramData account
///   2. `[writable]` Program account
///   3. `[writable]` Buffer account
///   4. `[]` Rent sysvar
///   5. `[]` Clock sysvar
///   6. `[]` System program
///   7. `[signer]` Authority
///
/// Rust equivalent: `solana_loader_v3_interface::instruction::deploy_with_max_data_len`
pub fn deployWithMaxDataLen(
    allocator: std.mem.Allocator,
    payer: PublicKey,
    program_data: PublicKey,
    program: PublicKey,
    buffer: PublicKey,
    authority: PublicKey,
    max_data_len: usize,
) !BuiltInstruction {
    const accounts = try allocator.alloc(AccountMeta, 8);
    errdefer allocator.free(accounts);

    accounts[0] = AccountMeta.init(payer, true, true); // signer, writable
    accounts[1] = AccountMeta.init(program_data, false, true); // writable
    accounts[2] = AccountMeta.init(program, false, true); // writable
    accounts[3] = AccountMeta.init(buffer, false, true); // writable
    accounts[4] = AccountMeta.init(sysvar_id.RENT, false, false); // readonly
    accounts[5] = AccountMeta.init(sysvar_id.CLOCK, false, false); // readonly
    accounts[6] = AccountMeta.init(system_program.id, false, false); // readonly
    accounts[7] = AccountMeta.init(authority, true, false); // signer

    const data = try allocator.alloc(u8, 4 + 8);
    std.mem.writeInt(u32, data[0..4], 2, .little); // DeployWithMaxDataLen discriminant
    std.mem.writeInt(u64, data[4..12], @intCast(max_data_len), .little);

    return BuiltInstruction{
        .program_id = bpf_loader_upgradeable_id,
        .accounts = accounts,
        .data = data,
    };
}

/// Create an Upgrade instruction
///
/// # Account references
///   0. `[writable]` ProgramData account
///   1. `[writable]` Program account
///   2. `[writable]` Buffer account
///   3. `[writable]` Spill account (receives reclaimed lamports)
///   4. `[]` Rent sysvar
///   5. `[]` Clock sysvar
///   6. `[signer]` Authority
///
/// Rust equivalent: `solana_loader_v3_interface::instruction::upgrade`
pub fn upgradeProgram(
    allocator: std.mem.Allocator,
    program_data: PublicKey,
    program: PublicKey,
    buffer: PublicKey,
    spill: PublicKey,
    authority: PublicKey,
) !BuiltInstruction {
    const accounts = try allocator.alloc(AccountMeta, 7);
    errdefer allocator.free(accounts);

    accounts[0] = AccountMeta.init(program_data, false, true); // writable
    accounts[1] = AccountMeta.init(program, false, true); // writable
    accounts[2] = AccountMeta.init(buffer, false, true); // writable
    accounts[3] = AccountMeta.init(spill, false, true); // writable
    accounts[4] = AccountMeta.init(sysvar_id.RENT, false, false); // readonly
    accounts[5] = AccountMeta.init(sysvar_id.CLOCK, false, false); // readonly
    accounts[6] = AccountMeta.init(authority, true, false); // signer

    const data = try allocator.alloc(u8, 4);
    std.mem.writeInt(u32, data[0..4], 3, .little); // Upgrade discriminant

    return BuiltInstruction{
        .program_id = bpf_loader_upgradeable_id,
        .accounts = accounts,
        .data = data,
    };
}

/// Create a SetAuthority instruction
///
/// # Account references
///   0. `[writable]` Buffer or ProgramData account
///   1. `[signer]` Current authority
///   2. `[]` New authority (optional)
///
/// Rust equivalent: `solana_loader_v3_interface::instruction::set_authority`
pub fn setAuthority(
    allocator: std.mem.Allocator,
    account: PublicKey,
    current_authority: PublicKey,
    new_authority: ?PublicKey,
) !BuiltInstruction {
    const num_accounts: usize = if (new_authority != null) 3 else 2;
    const accounts = try allocator.alloc(AccountMeta, num_accounts);
    errdefer allocator.free(accounts);

    accounts[0] = AccountMeta.init(account, false, true); // writable
    accounts[1] = AccountMeta.init(current_authority, true, false); // signer
    if (new_authority) |new_auth| {
        accounts[2] = AccountMeta.init(new_auth, false, false); // readonly
    }

    const data = try allocator.alloc(u8, 4);
    std.mem.writeInt(u32, data[0..4], 4, .little); // SetAuthority discriminant

    return BuiltInstruction{
        .program_id = bpf_loader_upgradeable_id,
        .accounts = accounts,
        .data = data,
    };
}

/// Create a Close instruction
///
/// # Account references
///   0. `[writable]` Account to close
///   1. `[writable]` Recipient account
///   2. `[signer]` Authority (optional for uninitialized buffer)
///   3. `[writable]` Program account (required when closing ProgramData)
///
/// Rust equivalent: `solana_loader_v3_interface::instruction::close`
pub fn closeAccount(
    allocator: std.mem.Allocator,
    account_to_close: PublicKey,
    recipient: PublicKey,
    authority: ?PublicKey,
    program: ?PublicKey,
) !BuiltInstruction {
    var num_accounts: usize = 2;
    if (authority != null) num_accounts += 1;
    if (program != null) num_accounts += 1;

    const accounts = try allocator.alloc(AccountMeta, num_accounts);
    errdefer allocator.free(accounts);

    accounts[0] = AccountMeta.init(account_to_close, false, true); // writable
    accounts[1] = AccountMeta.init(recipient, false, true); // writable

    var idx: usize = 2;
    if (authority) |auth| {
        accounts[idx] = AccountMeta.init(auth, true, false); // signer
        idx += 1;
    }
    if (program) |prog| {
        accounts[idx] = AccountMeta.init(prog, false, true); // writable
    }

    const data = try allocator.alloc(u8, 4);
    std.mem.writeInt(u32, data[0..4], 5, .little); // Close discriminant

    return BuiltInstruction{
        .program_id = bpf_loader_upgradeable_id,
        .accounts = accounts,
        .data = data,
    };
}

/// Create an ExtendProgram instruction
///
/// # Account references
///   0. `[writable]` ProgramData account
///   1. `[writable]` Program account
///   2. `[]` System program (optional, required if payer provided)
///   3. `[writable, signer]` Payer (optional)
///
/// Rust equivalent: `solana_loader_v3_interface::instruction::extend_program`
pub fn extendProgram(
    allocator: std.mem.Allocator,
    program_data: PublicKey,
    program: PublicKey,
    additional_bytes: u32,
    payer: ?PublicKey,
) !BuiltInstruction {
    const num_accounts: usize = if (payer != null) 4 else 2;
    const accounts = try allocator.alloc(AccountMeta, num_accounts);
    errdefer allocator.free(accounts);

    accounts[0] = AccountMeta.init(program_data, false, true); // writable
    accounts[1] = AccountMeta.init(program, false, true); // writable
    if (payer) |p| {
        accounts[2] = AccountMeta.init(system_program.id, false, false); // readonly
        accounts[3] = AccountMeta.init(p, true, true); // signer, writable
    }

    const data = try allocator.alloc(u8, 4 + 4);
    std.mem.writeInt(u32, data[0..4], 6, .little); // ExtendProgram discriminant
    std.mem.writeInt(u32, data[4..8], additional_bytes, .little);

    return BuiltInstruction{
        .program_id = bpf_loader_upgradeable_id,
        .accounts = accounts,
        .data = data,
    };
}

/// Create a SetAuthorityChecked instruction
///
/// # Account references
///   0. `[writable]` Buffer or ProgramData account
///   1. `[signer]` Current authority
///   2. `[signer]` New authority
///
/// Rust equivalent: `solana_loader_v3_interface::instruction::set_authority_checked`
pub fn setAuthorityChecked(
    allocator: std.mem.Allocator,
    account: PublicKey,
    current_authority: PublicKey,
    new_authority: PublicKey,
) !BuiltInstruction {
    const accounts = try allocator.alloc(AccountMeta, 3);
    errdefer allocator.free(accounts);

    accounts[0] = AccountMeta.init(account, false, true); // writable
    accounts[1] = AccountMeta.init(current_authority, true, false); // signer
    accounts[2] = AccountMeta.init(new_authority, true, false); // signer

    const data = try allocator.alloc(u8, 4);
    std.mem.writeInt(u32, data[0..4], 7, .little); // SetAuthorityChecked discriminant

    return BuiltInstruction{
        .program_id = bpf_loader_upgradeable_id,
        .accounts = accounts,
        .data = data,
    };
}

/// Create a Migrate instruction
///
/// Migrates the program to loader-v4.
///
/// # Account references
///   0. `[writable]` ProgramData account
///   1. `[writable]` Program account
///   2. `[signer]` Authority
///
/// Rust equivalent: `solana_loader_v3_interface::instruction::migrate`
pub fn migrateProgram(
    allocator: std.mem.Allocator,
    program_data: PublicKey,
    program: PublicKey,
    authority: PublicKey,
) !BuiltInstruction {
    const accounts = try allocator.alloc(AccountMeta, 3);
    errdefer allocator.free(accounts);

    accounts[0] = AccountMeta.init(program_data, false, true); // writable
    accounts[1] = AccountMeta.init(program, false, true); // writable
    accounts[2] = AccountMeta.init(authority, true, false); // signer

    const data = try allocator.alloc(u8, 4);
    std.mem.writeInt(u32, data[0..4], 8, .little); // Migrate discriminant

    return BuiltInstruction{
        .program_id = bpf_loader_upgradeable_id,
        .accounts = accounts,
        .data = data,
    };
}

/// Create an ExtendProgramChecked instruction
///
/// # Account references
///   0. `[writable]` ProgramData account
///   1. `[writable]` Program account
///   2. `[signer]` Authority
///   3. `[]` System program (optional, required if payer provided)
///   4. `[signer]` Payer (optional)
///
/// Rust equivalent: `solana_loader_v3_interface::instruction::extend_program_checked`
pub fn extendProgramChecked(
    allocator: std.mem.Allocator,
    program_data: PublicKey,
    program: PublicKey,
    authority: PublicKey,
    additional_bytes: u32,
    payer: ?PublicKey,
) !BuiltInstruction {
    const num_accounts: usize = if (payer != null) 5 else 3;
    const accounts = try allocator.alloc(AccountMeta, num_accounts);
    errdefer allocator.free(accounts);

    accounts[0] = AccountMeta.init(program_data, false, true); // writable
    accounts[1] = AccountMeta.init(program, false, true); // writable
    accounts[2] = AccountMeta.init(authority, true, false); // signer
    if (payer) |p| {
        accounts[3] = AccountMeta.init(system_program.id, false, false); // readonly
        accounts[4] = AccountMeta.init(p, true, true); // signer, writable
    }

    const data = try allocator.alloc(u8, 4 + 4);
    std.mem.writeInt(u32, data[0..4], 9, .little); // ExtendProgramChecked discriminant
    std.mem.writeInt(u32, data[4..8], additional_bytes, .little);

    return BuiltInstruction{
        .program_id = bpf_loader_upgradeable_id,
        .accounts = accounts,
        .data = data,
    };
}

// ============================================================================
// Instruction Type Checking Functions
// ============================================================================

/// Check if the instruction data represents an Upgrade instruction
pub fn isUpgradeInstruction(instruction_data: []const u8) bool {
    return instruction_data.len > 0 and instruction_data[0] == 3;
}

/// Check if the instruction data represents a SetAuthority instruction
pub fn isSetAuthorityInstruction(instruction_data: []const u8) bool {
    return instruction_data.len > 0 and instruction_data[0] == 4;
}

/// Check if the instruction data represents a Close instruction
pub fn isCloseInstruction(instruction_data: []const u8) bool {
    return instruction_data.len > 0 and instruction_data[0] == 5;
}

/// Check if the instruction data represents a SetAuthorityChecked instruction
pub fn isSetAuthorityCheckedInstruction(instruction_data: []const u8) bool {
    return instruction_data.len > 0 and instruction_data[0] == 7;
}

/// Check if the instruction data represents a Migrate instruction
pub fn isMigrateInstruction(instruction_data: []const u8) bool {
    return instruction_data.len > 0 and instruction_data[0] == 8;
}

/// Check if the instruction data represents an ExtendProgramChecked instruction
pub fn isExtendProgramCheckedInstruction(instruction_data: []const u8) bool {
    return instruction_data.len > 0 and instruction_data[0] == 9;
}

/// Calculate the size of a Buffer account for a given program length
pub fn sizeOfBuffer(program_len: usize) usize {
    return UPGRADEABLE_LOADER_STATE_BUFFER_SIZE + program_len;
}

/// Calculate the size of a ProgramData account for a given program length
pub fn sizeOfProgramData(program_len: usize) usize {
    return UPGRADEABLE_LOADER_STATE_PROGRAMDATA_SIZE + program_len;
}

/// Size of the Program account
pub fn sizeOfProgram() usize {
    return UPGRADEABLE_LOADER_STATE_PROGRAM_SIZE;
}

// ============================================================================
// Tests
// ============================================================================

test "bpf_loader: program IDs are correct length" {
    try std.testing.expectEqual(@as(usize, 32), bpf_loader_deprecated_id.bytes.len);
    try std.testing.expectEqual(@as(usize, 32), bpf_loader_id.bytes.len);
    try std.testing.expectEqual(@as(usize, 32), bpf_loader_upgradeable_id.bytes.len);
}

test "bpf_loader: isBpfLoader check" {
    try std.testing.expect(isBpfLoader(bpf_loader_deprecated_id));
    try std.testing.expect(isBpfLoader(bpf_loader_id));
    try std.testing.expect(isBpfLoader(bpf_loader_upgradeable_id));

    // System program should not be a BPF loader
    const system_id = PublicKey.from([_]u8{0} ** 32);
    try std.testing.expect(!isBpfLoader(system_id));
}

test "bpf_loader: isUpgradeableLoader check" {
    try std.testing.expect(isUpgradeableLoader(bpf_loader_upgradeable_id));
    try std.testing.expect(!isUpgradeableLoader(bpf_loader_id));
    try std.testing.expect(!isUpgradeableLoader(bpf_loader_deprecated_id));
}

test "bpf_loader: state sizes are correct" {
    // These match the Rust SDK sizes
    try std.testing.expectEqual(@as(usize, 4), UPGRADEABLE_LOADER_STATE_UNINITIALIZED_SIZE);
    try std.testing.expectEqual(@as(usize, 37), UPGRADEABLE_LOADER_STATE_BUFFER_SIZE);
    try std.testing.expectEqual(@as(usize, 36), UPGRADEABLE_LOADER_STATE_PROGRAM_SIZE);
    try std.testing.expectEqual(@as(usize, 45), UPGRADEABLE_LOADER_STATE_PROGRAMDATA_SIZE);
}

test "bpf_loader: loader IDs are different" {
    try std.testing.expect(!bpf_loader_deprecated_id.equals(bpf_loader_id));
    try std.testing.expect(!bpf_loader_id.equals(bpf_loader_upgradeable_id));
    try std.testing.expect(!bpf_loader_deprecated_id.equals(bpf_loader_upgradeable_id));
}

test "bpf_loader: instruction discriminants" {
    const init_buffer_instr: UpgradeableLoaderInstruction = .InitializeBuffer;
    try std.testing.expectEqual(@as(u8, 0), init_buffer_instr.getDiscriminant());

    const write_instr: UpgradeableLoaderInstruction = .{ .Write = .{ .offset = 0, .bytes = &[_]u8{} } };
    try std.testing.expectEqual(@as(u8, 1), write_instr.getDiscriminant());

    const deploy_instr: UpgradeableLoaderInstruction = .{ .DeployWithMaxDataLen = .{ .max_data_len = 1000 } };
    try std.testing.expectEqual(@as(u8, 2), deploy_instr.getDiscriminant());

    const upgrade_instr: UpgradeableLoaderInstruction = .Upgrade;
    try std.testing.expectEqual(@as(u8, 3), upgrade_instr.getDiscriminant());

    const set_auth_instr: UpgradeableLoaderInstruction = .SetAuthority;
    try std.testing.expectEqual(@as(u8, 4), set_auth_instr.getDiscriminant());

    const close_instr: UpgradeableLoaderInstruction = .Close;
    try std.testing.expectEqual(@as(u8, 5), close_instr.getDiscriminant());

    const extend_instr: UpgradeableLoaderInstruction = .{ .ExtendProgram = .{ .additional_bytes = 100 } };
    try std.testing.expectEqual(@as(u8, 6), extend_instr.getDiscriminant());

    const set_auth_checked_instr: UpgradeableLoaderInstruction = .SetAuthorityChecked;
    try std.testing.expectEqual(@as(u8, 7), set_auth_checked_instr.getDiscriminant());

    const migrate_instr: UpgradeableLoaderInstruction = .Migrate;
    try std.testing.expectEqual(@as(u8, 8), migrate_instr.getDiscriminant());

    const extend_checked_instr: UpgradeableLoaderInstruction = .{ .ExtendProgramChecked = .{ .additional_bytes = 200 } };
    try std.testing.expectEqual(@as(u8, 9), extend_checked_instr.getDiscriminant());
}

test "bpf_loader: isUpgradeInstruction" {
    try std.testing.expect(!isUpgradeInstruction(&[_]u8{}));
    try std.testing.expect(!isUpgradeInstruction(&[_]u8{0}));
    try std.testing.expect(!isUpgradeInstruction(&[_]u8{1}));
    try std.testing.expect(!isUpgradeInstruction(&[_]u8{2}));
    try std.testing.expect(isUpgradeInstruction(&[_]u8{3}));
    try std.testing.expect(!isUpgradeInstruction(&[_]u8{4}));
}

test "bpf_loader: isSetAuthorityInstruction" {
    try std.testing.expect(!isSetAuthorityInstruction(&[_]u8{}));
    try std.testing.expect(!isSetAuthorityInstruction(&[_]u8{3}));
    try std.testing.expect(isSetAuthorityInstruction(&[_]u8{4}));
    try std.testing.expect(!isSetAuthorityInstruction(&[_]u8{5}));
}

test "bpf_loader: isCloseInstruction" {
    try std.testing.expect(!isCloseInstruction(&[_]u8{}));
    try std.testing.expect(!isCloseInstruction(&[_]u8{4}));
    try std.testing.expect(isCloseInstruction(&[_]u8{5}));
    try std.testing.expect(!isCloseInstruction(&[_]u8{6}));
}

test "bpf_loader: isSetAuthorityCheckedInstruction" {
    try std.testing.expect(!isSetAuthorityCheckedInstruction(&[_]u8{}));
    try std.testing.expect(!isSetAuthorityCheckedInstruction(&[_]u8{6}));
    try std.testing.expect(isSetAuthorityCheckedInstruction(&[_]u8{7}));
    try std.testing.expect(!isSetAuthorityCheckedInstruction(&[_]u8{8}));
}

test "bpf_loader: isMigrateInstruction" {
    try std.testing.expect(!isMigrateInstruction(&[_]u8{}));
    try std.testing.expect(!isMigrateInstruction(&[_]u8{7}));
    try std.testing.expect(isMigrateInstruction(&[_]u8{8}));
    try std.testing.expect(!isMigrateInstruction(&[_]u8{9}));
}

test "bpf_loader: isExtendProgramCheckedInstruction" {
    try std.testing.expect(!isExtendProgramCheckedInstruction(&[_]u8{}));
    try std.testing.expect(!isExtendProgramCheckedInstruction(&[_]u8{8}));
    try std.testing.expect(isExtendProgramCheckedInstruction(&[_]u8{9}));
    try std.testing.expect(!isExtendProgramCheckedInstruction(&[_]u8{10}));
}

test "bpf_loader: sizeOfBuffer" {
    // Buffer: 37 bytes header + program data
    try std.testing.expectEqual(@as(usize, 37 + 1000), sizeOfBuffer(1000));
    try std.testing.expectEqual(@as(usize, 37 + 0), sizeOfBuffer(0));
}

test "bpf_loader: sizeOfProgramData" {
    // ProgramData: 45 bytes header + program data
    try std.testing.expectEqual(@as(usize, 45 + 1000), sizeOfProgramData(1000));
    try std.testing.expectEqual(@as(usize, 45 + 0), sizeOfProgramData(0));
}

test "bpf_loader: sizeOfProgram" {
    try std.testing.expectEqual(@as(usize, 36), sizeOfProgram());
}

test "bpf_loader: serialize InitializeBuffer" {
    const allocator = std.testing.allocator;
    const instr: UpgradeableLoaderInstruction = .InitializeBuffer;
    const data = try instr.serialize(allocator);
    defer allocator.free(data);

    try std.testing.expectEqual(@as(usize, 4), data.len);
    try std.testing.expectEqual(@as(u32, 0), std.mem.readInt(u32, data[0..4], .little));
}

test "bpf_loader: serialize Upgrade" {
    const allocator = std.testing.allocator;
    const instr: UpgradeableLoaderInstruction = .Upgrade;
    const data = try instr.serialize(allocator);
    defer allocator.free(data);

    try std.testing.expectEqual(@as(usize, 4), data.len);
    try std.testing.expectEqual(@as(u32, 3), std.mem.readInt(u32, data[0..4], .little));
}

test "bpf_loader: serialize DeployWithMaxDataLen" {
    const allocator = std.testing.allocator;
    const instr: UpgradeableLoaderInstruction = .{ .DeployWithMaxDataLen = .{ .max_data_len = 50000 } };
    const data = try instr.serialize(allocator);
    defer allocator.free(data);

    try std.testing.expectEqual(@as(usize, 12), data.len);
    try std.testing.expectEqual(@as(u32, 2), std.mem.readInt(u32, data[0..4], .little));
    try std.testing.expectEqual(@as(u64, 50000), std.mem.readInt(u64, data[4..12], .little));
}

test "bpf_loader: serialize ExtendProgram" {
    const allocator = std.testing.allocator;
    const instr: UpgradeableLoaderInstruction = .{ .ExtendProgram = .{ .additional_bytes = 1024 } };
    const data = try instr.serialize(allocator);
    defer allocator.free(data);

    try std.testing.expectEqual(@as(usize, 8), data.len);
    try std.testing.expectEqual(@as(u32, 6), std.mem.readInt(u32, data[0..4], .little));
    try std.testing.expectEqual(@as(u32, 1024), std.mem.readInt(u32, data[4..8], .little));
}

test "bpf_loader: serialize Write" {
    const allocator = std.testing.allocator;
    const bytes = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
    const instr: UpgradeableLoaderInstruction = .{ .Write = .{ .offset = 100, .bytes = &bytes } };
    const data = try instr.serialize(allocator);
    defer allocator.free(data);

    // 4 (discriminant) + 4 (offset) + 8 (length) + 4 (bytes) = 20
    try std.testing.expectEqual(@as(usize, 20), data.len);
    try std.testing.expectEqual(@as(u32, 1), std.mem.readInt(u32, data[0..4], .little));
    try std.testing.expectEqual(@as(u32, 100), std.mem.readInt(u32, data[4..8], .little));
    try std.testing.expectEqual(@as(u64, 4), std.mem.readInt(u64, data[8..16], .little));
    try std.testing.expectEqualSlices(u8, &bytes, data[16..20]);
}

// ============================================================================
// Instruction Builder Tests
// ============================================================================

test "bpf_loader: initializeBuffer builder" {
    const allocator = std.testing.allocator;
    const buffer = PublicKey.from([_]u8{1} ** 32);
    const authority = PublicKey.from([_]u8{2} ** 32);

    // With authority
    var ix = try initializeBuffer(allocator, buffer, authority);
    defer ix.deinit(allocator);

    try std.testing.expectEqualSlices(u8, &bpf_loader_upgradeable_id.bytes, &ix.program_id.bytes);
    try std.testing.expectEqual(@as(usize, 2), ix.accounts.len);
    try std.testing.expect(ix.accounts[0].is_writable);
    try std.testing.expect(!ix.accounts[0].is_signer);
    try std.testing.expect(!ix.accounts[1].is_writable);
    try std.testing.expectEqual(@as(usize, 4), ix.data.len);
    try std.testing.expectEqual(@as(u32, 0), std.mem.readInt(u32, ix.data[0..4], .little));
}

test "bpf_loader: initializeBuffer without authority" {
    const allocator = std.testing.allocator;
    const buffer = PublicKey.from([_]u8{1} ** 32);

    var ix = try initializeBuffer(allocator, buffer, null);
    defer ix.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), ix.accounts.len);
}

test "bpf_loader: writeBuffer builder" {
    const allocator = std.testing.allocator;
    const buffer = PublicKey.from([_]u8{1} ** 32);
    const authority = PublicKey.from([_]u8{2} ** 32);
    const bytes = [_]u8{ 0xAB, 0xCD, 0xEF };

    var ix = try writeBuffer(allocator, buffer, authority, 100, &bytes);
    defer ix.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), ix.accounts.len);
    try std.testing.expect(ix.accounts[0].is_writable);
    try std.testing.expect(ix.accounts[1].is_signer);

    // Check data: discriminant (4) + offset (4) + length (8) + bytes (3)
    try std.testing.expectEqual(@as(usize, 19), ix.data.len);
    try std.testing.expectEqual(@as(u32, 1), std.mem.readInt(u32, ix.data[0..4], .little));
    try std.testing.expectEqual(@as(u32, 100), std.mem.readInt(u32, ix.data[4..8], .little));
    try std.testing.expectEqual(@as(u64, 3), std.mem.readInt(u64, ix.data[8..16], .little));
    try std.testing.expectEqualSlices(u8, &bytes, ix.data[16..19]);
}

test "bpf_loader: deployWithMaxDataLen builder" {
    const allocator = std.testing.allocator;
    const payer = PublicKey.from([_]u8{1} ** 32);
    const program_data = PublicKey.from([_]u8{2} ** 32);
    const program = PublicKey.from([_]u8{3} ** 32);
    const buffer = PublicKey.from([_]u8{4} ** 32);
    const authority = PublicKey.from([_]u8{5} ** 32);

    var ix = try deployWithMaxDataLen(allocator, payer, program_data, program, buffer, authority, 50000);
    defer ix.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 8), ix.accounts.len);
    try std.testing.expect(ix.accounts[0].is_writable and ix.accounts[0].is_signer); // payer
    try std.testing.expect(ix.accounts[7].is_signer); // authority

    // Check sysvars
    try std.testing.expectEqualSlices(u8, &sysvar_id.RENT.bytes, &ix.accounts[4].pubkey.bytes);
    try std.testing.expectEqualSlices(u8, &sysvar_id.CLOCK.bytes, &ix.accounts[5].pubkey.bytes);
    try std.testing.expectEqualSlices(u8, &system_program.id.bytes, &ix.accounts[6].pubkey.bytes);

    try std.testing.expectEqual(@as(usize, 12), ix.data.len);
    try std.testing.expectEqual(@as(u32, 2), std.mem.readInt(u32, ix.data[0..4], .little));
    try std.testing.expectEqual(@as(u64, 50000), std.mem.readInt(u64, ix.data[4..12], .little));
}

test "bpf_loader: upgradeProgram builder" {
    const allocator = std.testing.allocator;
    const program_data = PublicKey.from([_]u8{1} ** 32);
    const program = PublicKey.from([_]u8{2} ** 32);
    const buffer = PublicKey.from([_]u8{3} ** 32);
    const spill = PublicKey.from([_]u8{4} ** 32);
    const authority = PublicKey.from([_]u8{5} ** 32);

    var ix = try upgradeProgram(allocator, program_data, program, buffer, spill, authority);
    defer ix.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 7), ix.accounts.len);
    try std.testing.expect(ix.accounts[6].is_signer); // authority

    try std.testing.expectEqual(@as(usize, 4), ix.data.len);
    try std.testing.expectEqual(@as(u32, 3), std.mem.readInt(u32, ix.data[0..4], .little));
}

test "bpf_loader: setAuthority builder" {
    const allocator = std.testing.allocator;
    const account = PublicKey.from([_]u8{1} ** 32);
    const current_auth = PublicKey.from([_]u8{2} ** 32);
    const new_auth = PublicKey.from([_]u8{3} ** 32);

    // With new authority
    var ix = try setAuthority(allocator, account, current_auth, new_auth);
    defer ix.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 3), ix.accounts.len);
    try std.testing.expect(ix.accounts[1].is_signer);
    try std.testing.expectEqual(@as(u32, 4), std.mem.readInt(u32, ix.data[0..4], .little));
}

test "bpf_loader: setAuthority without new authority" {
    const allocator = std.testing.allocator;
    const account = PublicKey.from([_]u8{1} ** 32);
    const current_auth = PublicKey.from([_]u8{2} ** 32);

    var ix = try setAuthority(allocator, account, current_auth, null);
    defer ix.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), ix.accounts.len);
}

test "bpf_loader: closeAccount builder" {
    const allocator = std.testing.allocator;
    const account = PublicKey.from([_]u8{1} ** 32);
    const recipient = PublicKey.from([_]u8{2} ** 32);
    const authority = PublicKey.from([_]u8{3} ** 32);
    const program = PublicKey.from([_]u8{4} ** 32);

    var ix = try closeAccount(allocator, account, recipient, authority, program);
    defer ix.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 4), ix.accounts.len);
    try std.testing.expect(ix.accounts[2].is_signer); // authority
    try std.testing.expectEqual(@as(u32, 5), std.mem.readInt(u32, ix.data[0..4], .little));
}

test "bpf_loader: extendProgram builder" {
    const allocator = std.testing.allocator;
    const program_data = PublicKey.from([_]u8{1} ** 32);
    const program = PublicKey.from([_]u8{2} ** 32);
    const payer = PublicKey.from([_]u8{3} ** 32);

    var ix = try extendProgram(allocator, program_data, program, 1024, payer);
    defer ix.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 4), ix.accounts.len);
    try std.testing.expectEqualSlices(u8, &system_program.id.bytes, &ix.accounts[2].pubkey.bytes);
    try std.testing.expect(ix.accounts[3].is_signer); // payer

    try std.testing.expectEqual(@as(usize, 8), ix.data.len);
    try std.testing.expectEqual(@as(u32, 6), std.mem.readInt(u32, ix.data[0..4], .little));
    try std.testing.expectEqual(@as(u32, 1024), std.mem.readInt(u32, ix.data[4..8], .little));
}

test "bpf_loader: extendProgram without payer" {
    const allocator = std.testing.allocator;
    const program_data = PublicKey.from([_]u8{1} ** 32);
    const program = PublicKey.from([_]u8{2} ** 32);

    var ix = try extendProgram(allocator, program_data, program, 512, null);
    defer ix.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), ix.accounts.len);
}

test "bpf_loader: setAuthorityChecked builder" {
    const allocator = std.testing.allocator;
    const account = PublicKey.from([_]u8{1} ** 32);
    const current_auth = PublicKey.from([_]u8{2} ** 32);
    const new_auth = PublicKey.from([_]u8{3} ** 32);

    var ix = try setAuthorityChecked(allocator, account, current_auth, new_auth);
    defer ix.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 3), ix.accounts.len);
    try std.testing.expect(ix.accounts[1].is_signer); // current authority
    try std.testing.expect(ix.accounts[2].is_signer); // new authority (checked)
    try std.testing.expectEqual(@as(u32, 7), std.mem.readInt(u32, ix.data[0..4], .little));
}

test "bpf_loader: migrateProgram builder" {
    const allocator = std.testing.allocator;
    const program_data = PublicKey.from([_]u8{1} ** 32);
    const program = PublicKey.from([_]u8{2} ** 32);
    const authority = PublicKey.from([_]u8{3} ** 32);

    var ix = try migrateProgram(allocator, program_data, program, authority);
    defer ix.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 3), ix.accounts.len);
    try std.testing.expect(ix.accounts[2].is_signer);
    try std.testing.expectEqual(@as(u32, 8), std.mem.readInt(u32, ix.data[0..4], .little));
}

test "bpf_loader: extendProgramChecked builder" {
    const allocator = std.testing.allocator;
    const program_data = PublicKey.from([_]u8{1} ** 32);
    const program = PublicKey.from([_]u8{2} ** 32);
    const authority = PublicKey.from([_]u8{3} ** 32);
    const payer = PublicKey.from([_]u8{4} ** 32);

    var ix = try extendProgramChecked(allocator, program_data, program, authority, 2048, payer);
    defer ix.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 5), ix.accounts.len);
    try std.testing.expect(ix.accounts[2].is_signer); // authority
    try std.testing.expect(ix.accounts[4].is_signer); // payer

    try std.testing.expectEqual(@as(usize, 8), ix.data.len);
    try std.testing.expectEqual(@as(u32, 9), std.mem.readInt(u32, ix.data[0..4], .little));
    try std.testing.expectEqual(@as(u32, 2048), std.mem.readInt(u32, ix.data[4..8], .little));
}
