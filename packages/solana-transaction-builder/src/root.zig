//! `solana_transaction_builder` — host-side transaction assembly helpers.

const std = @import("std");
const tx = @import("solana_tx");
const keypair = @import("solana_keypair");
const system = @import("solana_system");
const alt = @import("solana_address_lookup_table");
const compute_budget = @import("solana_compute_budget");
const spl_token = @import("spl_token");
const spl_ata = @import("spl_ata");

pub const Pubkey = tx.Pubkey;
pub const Instruction = tx.Instruction;
pub const Keypair = keypair.Keypair;
pub const Signature = tx.Signature;
pub const LookupTableAccount = alt.LookupTableAccount;
pub const HASH_BYTES = tx.HASH_BYTES;
pub const SystemAccountMeta = system.AccountMeta;
pub const SystemCreateAccountData = system.CreateAccountData;
pub const SystemTransferData = system.TransferData;
pub const SystemNonceAuthorityData = system.NonceAuthorityData;
pub const ComputeBudgetRequestHeapFrameData = compute_budget.RequestHeapFrameData;
pub const ComputeBudgetSetComputeUnitLimitData = compute_budget.SetComputeUnitLimitData;
pub const ComputeBudgetSetComputeUnitPriceData = compute_budget.SetComputeUnitPriceData;
pub const ComputeBudgetSetLoadedAccountsDataSizeLimitData = compute_budget.SetLoadedAccountsDataSizeLimitData;
pub const TokenTransferMetas = spl_token.instruction.metasArray(spl_token.instruction.transfer_spec);
pub const TokenTransferData = spl_token.instruction.dataArray(spl_token.instruction.transfer_spec);
pub const TokenTransferCheckedMetas = spl_token.instruction.metasArray(spl_token.instruction.transfer_checked_spec);
pub const TokenTransferCheckedData = spl_token.instruction.dataArray(spl_token.instruction.transfer_checked_spec);
pub const AtaCreateIdempotentScratch = spl_ata.instruction.Scratch(spl_ata.instruction.create_idempotent_spec);

pub const ComputeBudgetOptions = struct {
    heap_frame_bytes: ?u32 = null,
    loaded_accounts_data_size_limit: ?u32 = null,
    compute_unit_limit: ?u32 = null,
    compute_unit_price_micro_lamports: ?u64 = null,
};

pub const ComputeBudgetInstructionBuffers = struct {
    request_heap_frame_data: *ComputeBudgetRequestHeapFrameData,
    set_compute_unit_limit_data: *ComputeBudgetSetComputeUnitLimitData,
    set_compute_unit_price_data: *ComputeBudgetSetComputeUnitPriceData,
    set_loaded_accounts_data_size_limit_data: *ComputeBudgetSetLoadedAccountsDataSizeLimitData,
};

pub const ComputeBudgetPrelude = struct {
    instructions: [4]Instruction,
    len: usize,

    pub fn slice(self: *const ComputeBudgetPrelude) []const Instruction {
        return self.instructions[0..self.len];
    }
};

pub const TransferWithComputeBudgetBuffers = struct {
    compute_budget: ComputeBudgetInstructionBuffers,
    transfer_metas: *[2]SystemAccountMeta,
    transfer_data: *SystemTransferData,
};

pub const TransferWithComputeBudgetInstructions = struct {
    instructions: [5]Instruction,
    len: usize,

    pub fn slice(self: *const TransferWithComputeBudgetInstructions) []const Instruction {
        return self.instructions[0..self.len];
    }

    pub fn transferInstruction(self: *const TransferWithComputeBudgetInstructions) *const Instruction {
        std.debug.assert(self.len > 0);
        return &self.instructions[self.len - 1];
    }
};

pub const TokenTransferWithComputeBudgetBuffers = struct {
    compute_budget: ComputeBudgetInstructionBuffers,
    transfer_metas: *TokenTransferMetas,
    transfer_data: *TokenTransferData,
};

pub const TokenTransferCheckedWithComputeBudgetBuffers = struct {
    compute_budget: ComputeBudgetInstructionBuffers,
    transfer_metas: *TokenTransferCheckedMetas,
    transfer_data: *TokenTransferCheckedData,
};

pub const AtaTokenTransferWithComputeBudgetBuffers = struct {
    compute_budget: ComputeBudgetInstructionBuffers,
    ata_scratch: *AtaCreateIdempotentScratch,
    transfer_metas: *TokenTransferMetas,
    transfer_data: *TokenTransferData,
};

pub const AtaTokenTransferCheckedWithComputeBudgetBuffers = struct {
    compute_budget: ComputeBudgetInstructionBuffers,
    ata_scratch: *AtaCreateIdempotentScratch,
    transfer_metas: *TokenTransferCheckedMetas,
    transfer_data: *TokenTransferCheckedData,
};

pub const TokenTransferWithComputeBudgetInstructions = struct {
    instructions: [5]Instruction,
    len: usize,

    pub fn slice(self: *const TokenTransferWithComputeBudgetInstructions) []const Instruction {
        return self.instructions[0..self.len];
    }

    pub fn tokenTransferInstruction(self: *const TokenTransferWithComputeBudgetInstructions) *const Instruction {
        std.debug.assert(self.len > 0);
        return &self.instructions[self.len - 1];
    }
};

pub const AtaTokenTransferWithComputeBudgetInstructions = struct {
    instructions: [6]Instruction,
    len: usize,

    pub fn slice(self: *const AtaTokenTransferWithComputeBudgetInstructions) []const Instruction {
        return self.instructions[0..self.len];
    }

    pub fn createAssociatedTokenAccountInstruction(self: *const AtaTokenTransferWithComputeBudgetInstructions) *const Instruction {
        std.debug.assert(self.len >= 2);
        return &self.instructions[self.len - 2];
    }

    pub fn tokenTransferInstruction(self: *const AtaTokenTransferWithComputeBudgetInstructions) *const Instruction {
        std.debug.assert(self.len > 0);
        return &self.instructions[self.len - 1];
    }
};

pub const SystemInstructionBuffers = struct {
    create_account_metas: *[2]SystemAccountMeta,
    create_account_data: *SystemCreateAccountData,
    initialize_nonce_metas: *[3]SystemAccountMeta,
    initialize_nonce_data: *SystemNonceAuthorityData,
};

pub fn computeBudgetPrelude(
    options: ComputeBudgetOptions,
    buffers: ComputeBudgetInstructionBuffers,
) ComputeBudgetPrelude {
    var result: ComputeBudgetPrelude = .{
        .instructions = undefined,
        .len = 0,
    };

    if (options.heap_frame_bytes) |bytes| {
        result.instructions[result.len] = compute_budget.requestHeapFrame(bytes, buffers.request_heap_frame_data);
        result.len += 1;
    }
    if (options.loaded_accounts_data_size_limit) |bytes| {
        result.instructions[result.len] = compute_budget.setLoadedAccountsDataSizeLimit(
            bytes,
            buffers.set_loaded_accounts_data_size_limit_data,
        );
        result.len += 1;
    }
    if (options.compute_unit_limit) |units| {
        result.instructions[result.len] = compute_budget.setComputeUnitLimit(units, buffers.set_compute_unit_limit_data);
        result.len += 1;
    }
    if (options.compute_unit_price_micro_lamports) |micro_lamports| {
        result.instructions[result.len] = compute_budget.setComputeUnitPrice(
            micro_lamports,
            buffers.set_compute_unit_price_data,
        );
        result.len += 1;
    }

    return result;
}

pub fn transferWithComputeBudget(
    from: *const Pubkey,
    to: *const Pubkey,
    lamports: u64,
    compute_options: ComputeBudgetOptions,
    buffers: TransferWithComputeBudgetBuffers,
) TransferWithComputeBudgetInstructions {
    const prelude = computeBudgetPrelude(compute_options, buffers.compute_budget);
    var result: TransferWithComputeBudgetInstructions = .{
        .instructions = undefined,
        .len = 0,
    };
    for (prelude.slice()) |ix| {
        result.instructions[result.len] = ix;
        result.len += 1;
    }
    result.instructions[result.len] = system.transfer(from, to, lamports, buffers.transfer_metas, buffers.transfer_data);
    result.len += 1;
    return result;
}

pub fn tokenTransferWithComputeBudget(
    source: *const Pubkey,
    destination: *const Pubkey,
    authority: *const Pubkey,
    amount: u64,
    compute_options: ComputeBudgetOptions,
    buffers: TokenTransferWithComputeBudgetBuffers,
) TokenTransferWithComputeBudgetInstructions {
    const prelude = computeBudgetPrelude(compute_options, buffers.compute_budget);
    var result: TokenTransferWithComputeBudgetInstructions = .{
        .instructions = undefined,
        .len = 0,
    };
    for (prelude.slice()) |ix| {
        result.instructions[result.len] = ix;
        result.len += 1;
    }
    result.instructions[result.len] = spl_token.instruction.transfer(
        source,
        destination,
        authority,
        amount,
        buffers.transfer_metas,
        buffers.transfer_data,
    );
    result.len += 1;
    return result;
}

pub fn tokenTransferCheckedWithComputeBudget(
    source: *const Pubkey,
    mint: *const Pubkey,
    destination: *const Pubkey,
    authority: *const Pubkey,
    amount: u64,
    decimals: u8,
    compute_options: ComputeBudgetOptions,
    buffers: TokenTransferCheckedWithComputeBudgetBuffers,
) TokenTransferWithComputeBudgetInstructions {
    const prelude = computeBudgetPrelude(compute_options, buffers.compute_budget);
    var result: TokenTransferWithComputeBudgetInstructions = .{
        .instructions = undefined,
        .len = 0,
    };
    for (prelude.slice()) |ix| {
        result.instructions[result.len] = ix;
        result.len += 1;
    }
    result.instructions[result.len] = spl_token.instruction.transferChecked(
        source,
        mint,
        destination,
        authority,
        amount,
        decimals,
        buffers.transfer_metas,
        buffers.transfer_data,
    );
    result.len += 1;
    return result;
}

pub fn createAtaAndTokenTransferWithComputeBudget(
    payer: *const Pubkey,
    wallet: *const Pubkey,
    source: *const Pubkey,
    mint: *const Pubkey,
    authority: *const Pubkey,
    amount: u64,
    compute_options: ComputeBudgetOptions,
    buffers: AtaTokenTransferWithComputeBudgetBuffers,
) AtaTokenTransferWithComputeBudgetInstructions {
    const prelude = computeBudgetPrelude(compute_options, buffers.compute_budget);
    var result: AtaTokenTransferWithComputeBudgetInstructions = .{
        .instructions = undefined,
        .len = 0,
    };
    for (prelude.slice()) |ix| {
        result.instructions[result.len] = ix;
        result.len += 1;
    }
    result.instructions[result.len] = spl_ata.instruction.createIdempotent(
        payer,
        wallet,
        mint,
        &system.PROGRAM_ID,
        &spl_token.PROGRAM_ID,
        buffers.ata_scratch,
    );
    result.len += 1;
    result.instructions[result.len] = spl_token.instruction.transfer(
        source,
        &buffers.ata_scratch.associated_token_account,
        authority,
        amount,
        buffers.transfer_metas,
        buffers.transfer_data,
    );
    result.len += 1;
    return result;
}

pub fn createAtaAndTokenTransferCheckedWithComputeBudget(
    payer: *const Pubkey,
    wallet: *const Pubkey,
    source: *const Pubkey,
    mint: *const Pubkey,
    authority: *const Pubkey,
    amount: u64,
    decimals: u8,
    compute_options: ComputeBudgetOptions,
    buffers: AtaTokenTransferCheckedWithComputeBudgetBuffers,
) AtaTokenTransferWithComputeBudgetInstructions {
    const prelude = computeBudgetPrelude(compute_options, buffers.compute_budget);
    var result: AtaTokenTransferWithComputeBudgetInstructions = .{
        .instructions = undefined,
        .len = 0,
    };
    for (prelude.slice()) |ix| {
        result.instructions[result.len] = ix;
        result.len += 1;
    }
    result.instructions[result.len] = spl_ata.instruction.createIdempotent(
        payer,
        wallet,
        mint,
        &system.PROGRAM_ID,
        &spl_token.PROGRAM_ID,
        buffers.ata_scratch,
    );
    result.len += 1;
    result.instructions[result.len] = spl_token.instruction.transferChecked(
        source,
        mint,
        &buffers.ata_scratch.associated_token_account,
        authority,
        amount,
        decimals,
        buffers.transfer_metas,
        buffers.transfer_data,
    );
    result.len += 1;
    return result;
}

pub const NonceAccountInstructions = struct {
    instructions: [2]Instruction,

    pub fn createAccount(self: *const NonceAccountInstructions) *const Instruction {
        return &self.instructions[0];
    }

    pub fn initializeNonceAccount(self: *const NonceAccountInstructions) *const Instruction {
        return &self.instructions[1];
    }

    pub fn slice(self: *const NonceAccountInstructions) []const Instruction {
        return self.instructions[0..];
    }
};

pub const Error = tx.Error || error{
    SignatureBufferTooSmall,
    MessageBufferTooSmall,
    MissingRequiredSigner,
    LookupTableBufferTooSmall,
    LookupIndexBufferTooSmall,
};

pub const LegacyBuffers = struct {
    account_keys: []Pubkey,
    compiled_instructions: []tx.CompiledInstruction,
    instruction_account_indices: []u8,
    message_bytes: []u8,
    signatures: []Signature,
    transaction_bytes: []u8,
};

pub const BuiltLegacyTransaction = struct {
    message: tx.LegacyMessage,
    message_bytes: []const u8,
    signatures: []const Signature,
    transaction_bytes: []const u8,
};

pub const V0Buffers = struct {
    message_bytes: []u8,
    signatures: []Signature,
    transaction_bytes: []u8,
};

pub const LookupTableCandidate = struct {
    account_key: *const Pubkey,
    table: LookupTableAccount,
};

pub const V0CompileBuffers = struct {
    static_account_keys: []Pubkey,
    compiled_instructions: []tx.CompiledInstruction,
    instruction_account_indices: []u8,
    address_table_lookups: []tx.MessageAddressTableLookup,
    writable_lookup_indexes: []u8,
    readonly_lookup_indexes: []u8,
};

pub const BuiltV0Transaction = struct {
    message: tx.V0Message,
    message_bytes: []const u8,
    signatures: []const Signature,
    transaction_bytes: []const u8,
};

pub fn createNonceAccountInstructions(
    payer: *const Pubkey,
    nonce_account: *const Pubkey,
    authority: *const Pubkey,
    lamports: u64,
    buffers: SystemInstructionBuffers,
) NonceAccountInstructions {
    return createNonceAccountInstructionsWithSysvars(
        payer,
        nonce_account,
        &system.RECENT_BLOCKHASHES_ID,
        &system.RENT_ID,
        authority,
        lamports,
        buffers,
    );
}

pub fn createNonceAccountInstructionsWithSysvars(
    payer: *const Pubkey,
    nonce_account: *const Pubkey,
    recent_blockhashes_sysvar: *const Pubkey,
    rent_sysvar: *const Pubkey,
    authority: *const Pubkey,
    lamports: u64,
    buffers: SystemInstructionBuffers,
) NonceAccountInstructions {
    return .{
        .instructions = .{
            system.createAccount(
                payer,
                nonce_account,
                lamports,
                system.NONCE_STATE_SIZE,
                &system.PROGRAM_ID,
                buffers.create_account_metas,
                buffers.create_account_data,
            ),
            system.initializeNonceAccount(
                nonce_account,
                recent_blockhashes_sysvar,
                rent_sysvar,
                authority,
                buffers.initialize_nonce_metas,
                buffers.initialize_nonce_data,
            ),
        },
    };
}

pub fn buildAndSignLegacyTransaction(
    payer: *const Pubkey,
    recent_blockhash: *const [HASH_BYTES]u8,
    instructions: []const Instruction,
    signers: []const Keypair,
    buffers: LegacyBuffers,
) (Error || anyerror)!BuiltLegacyTransaction {
    const message = try tx.compileLegacyMessage(
        payer,
        recent_blockhash,
        instructions,
        buffers.account_keys,
        buffers.compiled_instructions,
        buffers.instruction_account_indices,
    );

    const message_len = try tx.serializedLegacyMessageLen(message);
    if (buffers.message_bytes.len < message_len) return error.MessageBufferTooSmall;
    const message_bytes = try tx.serializeLegacyMessage(message, buffers.message_bytes);

    const required_signatures = message.header.num_required_signatures;
    if (buffers.signatures.len < required_signatures) return error.SignatureBufferTooSmall;
    const signatures = buffers.signatures[0..required_signatures];

    for (message.account_keys[0..required_signatures], signatures) |*required_pubkey, *signature| {
        const signer = findSigner(signers, required_pubkey) orelse return error.MissingRequiredSigner;
        signature.* = try signer.sign(message_bytes);
    }

    const transaction_bytes = try tx.serializeLegacyTransaction(
        signatures,
        message,
        buffers.transaction_bytes,
    );

    return .{
        .message = message,
        .message_bytes = message_bytes,
        .signatures = signatures,
        .transaction_bytes = transaction_bytes,
    };
}

pub fn buildAndSignV0Transaction(
    message: tx.V0Message,
    signers: []const Keypair,
    buffers: V0Buffers,
) (Error || anyerror)!BuiltV0Transaction {
    const message_len = try tx.serializedV0MessageLen(message);
    if (buffers.message_bytes.len < message_len) return error.MessageBufferTooSmall;
    const message_bytes = try tx.serializeV0Message(message, buffers.message_bytes);

    const required_signatures = message.header.num_required_signatures;
    if (buffers.signatures.len < required_signatures) return error.SignatureBufferTooSmall;
    const signatures = buffers.signatures[0..required_signatures];

    for (message.account_keys[0..required_signatures], signatures) |*required_pubkey, *signature| {
        const signer = findSigner(signers, required_pubkey) orelse return error.MissingRequiredSigner;
        signature.* = try signer.sign(message_bytes);
    }

    const transaction_bytes = try tx.serializeV0Transaction(
        signatures,
        message,
        buffers.transaction_bytes,
    );

    return .{
        .message = message,
        .message_bytes = message_bytes,
        .signatures = signatures,
        .transaction_bytes = transaction_bytes,
    };
}

pub fn compileV0MessageWithLookupTables(
    payer: *const Pubkey,
    recent_blockhash: *const [HASH_BYTES]u8,
    instructions: []const Instruction,
    lookup_tables: []const LookupTableCandidate,
    buffers: V0CompileBuffers,
) Error!tx.V0Message {
    if (buffers.compiled_instructions.len < instructions.len) {
        return error.CompiledInstructionBufferTooSmall;
    }

    var keys: [tx.MAX_LEGACY_ACCOUNT_KEYS]V0KeyFlags = undefined;
    var key_count: usize = 0;
    try upsertV0Key(&keys, &key_count, payer, true, true, false);

    for (instructions) |ix| {
        for (ix.accounts) |meta| {
            try upsertV0Key(
                &keys,
                &key_count,
                meta.pubkey,
                meta.is_signer != 0,
                meta.is_writable != 0,
                false,
            );
        }
        try upsertV0Key(&keys, &key_count, ix.program_id, false, false, true);
    }

    var selected: [tx.MAX_LEGACY_ACCOUNT_KEYS]LookupSelection = undefined;
    var selected_count: usize = 0;
    const counts = try writeV0StaticKeysAndSelections(
        keys[0..key_count],
        lookup_tables,
        buffers.static_account_keys,
        &selected,
        &selected_count,
    );
    const static_keys = buffers.static_account_keys[0..counts.static_count];

    const lookups = try writeLookupRecords(
        lookup_tables,
        selected[0..selected_count],
        static_keys.len,
        buffers.address_table_lookups,
        buffers.writable_lookup_indexes,
        buffers.readonly_lookup_indexes,
    );

    var index_cursor: usize = 0;
    for (instructions, 0..) |ix, i| {
        if (ix.accounts.len > std.math.maxInt(u8)) return error.TooManyInstructionAccounts;
        if (index_cursor + ix.accounts.len > buffers.instruction_account_indices.len) {
            return error.InstructionAccountIndexBufferTooSmall;
        }

        const program_index = findV0MessageKeyIndex(static_keys, selected[0..selected_count], ix.program_id) orelse {
            return error.UnknownProgramId;
        };
        const start = index_cursor;
        for (ix.accounts) |meta| {
            buffers.instruction_account_indices[index_cursor] = findV0MessageKeyIndex(
                static_keys,
                selected[0..selected_count],
                meta.pubkey,
            ) orelse return error.UnknownProgramId;
            index_cursor += 1;
        }
        buffers.compiled_instructions[i] = .{
            .program_id_index = program_index,
            .accounts = buffers.instruction_account_indices[start..index_cursor],
            .data = ix.data,
        };
    }

    return .{
        .header = .{
            .num_required_signatures = @intCast(counts.signed_writable + counts.signed_readonly),
            .num_readonly_signed_accounts = @intCast(counts.signed_readonly),
            .num_readonly_unsigned_accounts = @intCast(counts.unsigned_readonly),
        },
        .account_keys = static_keys,
        .recent_blockhash = recent_blockhash,
        .instructions = buffers.compiled_instructions[0..instructions.len],
        .address_table_lookups = lookups,
    };
}

pub fn buildAndSignV0TransactionFromInstructions(
    payer: *const Pubkey,
    recent_blockhash: *const [HASH_BYTES]u8,
    instructions: []const Instruction,
    lookup_tables: []const LookupTableCandidate,
    signers: []const Keypair,
    compile_buffers: V0CompileBuffers,
    tx_buffers: V0Buffers,
) (Error || anyerror)!BuiltV0Transaction {
    const message = try compileV0MessageWithLookupTables(
        payer,
        recent_blockhash,
        instructions,
        lookup_tables,
        compile_buffers,
    );
    return buildAndSignV0Transaction(message, signers, tx_buffers);
}

fn findSigner(signers: []const Keypair, pubkey: *const Pubkey) ?Keypair {
    for (signers) |signer| {
        const signer_pubkey = signer.publicKey();
        if (std.mem.eql(u8, &signer_pubkey, pubkey)) return signer;
    }
    return null;
}

const V0KeyFlags = struct {
    key: Pubkey,
    is_signer: bool,
    is_writable: bool,
    is_program_id: bool,
};

const LookupSelection = struct {
    key: Pubkey,
    table_index: usize,
    address_index: u8,
    is_writable: bool,
    loaded_index: u8 = 0,
    readonly_order: usize = 0,
};

const V0Counts = struct {
    static_count: usize,
    signed_writable: usize,
    signed_readonly: usize,
    unsigned_readonly: usize,
};

fn upsertV0Key(
    keys: *[tx.MAX_LEGACY_ACCOUNT_KEYS]V0KeyFlags,
    key_count: *usize,
    key: *const Pubkey,
    is_signer: bool,
    is_writable: bool,
    is_program_id: bool,
) Error!void {
    for (keys[0..key_count.*]) |*entry| {
        if (std.mem.eql(u8, &entry.key, key)) {
            entry.is_signer = entry.is_signer or is_signer;
            entry.is_writable = entry.is_writable or is_writable;
            entry.is_program_id = entry.is_program_id or is_program_id;
            return;
        }
    }

    if (key_count.* >= tx.MAX_LEGACY_ACCOUNT_KEYS) return error.TooManyAccountKeys;
    keys[key_count.*] = .{
        .key = key.*,
        .is_signer = is_signer,
        .is_writable = is_writable,
        .is_program_id = is_program_id,
    };
    key_count.* += 1;
}

fn writeV0StaticKeysAndSelections(
    keys: []const V0KeyFlags,
    lookup_tables: []const LookupTableCandidate,
    static_out: []Pubkey,
    selected_out: *[tx.MAX_LEGACY_ACCOUNT_KEYS]LookupSelection,
    selected_count: *usize,
) Error!V0Counts {
    var static_flags: [tx.MAX_LEGACY_ACCOUNT_KEYS]V0KeyFlags = undefined;
    var static_count: usize = 0;

    for (keys) |entry| {
        if (!entry.is_signer and !entry.is_program_id) {
            if (findLookupAddress(lookup_tables, &entry.key)) |found| {
                selected_out[selected_count.*] = .{
                    .key = entry.key,
                    .table_index = found.table_index,
                    .address_index = found.address_index,
                    .is_writable = entry.is_writable,
                };
                selected_count.* += 1;
                continue;
            }
        }
        static_flags[static_count] = entry;
        static_count += 1;
    }

    if (static_out.len < static_count) return error.AccountKeyBufferTooSmall;
    var cursor: usize = 0;
    var signed_writable: usize = 0;
    var signed_readonly: usize = 0;
    var unsigned_readonly: usize = 0;

    for (static_flags[0..static_count]) |entry| {
        if (entry.is_signer and entry.is_writable) {
            static_out[cursor] = entry.key;
            cursor += 1;
            signed_writable += 1;
        }
    }
    for (static_flags[0..static_count]) |entry| {
        if (entry.is_signer and !entry.is_writable) {
            static_out[cursor] = entry.key;
            cursor += 1;
            signed_readonly += 1;
        }
    }
    for (static_flags[0..static_count]) |entry| {
        if (!entry.is_signer and entry.is_writable) {
            static_out[cursor] = entry.key;
            cursor += 1;
        }
    }
    for (static_flags[0..static_count]) |entry| {
        if (!entry.is_signer and !entry.is_writable) {
            static_out[cursor] = entry.key;
            cursor += 1;
            unsigned_readonly += 1;
        }
    }

    return .{
        .static_count = static_count,
        .signed_writable = signed_writable,
        .signed_readonly = signed_readonly,
        .unsigned_readonly = unsigned_readonly,
    };
}

fn writeLookupRecords(
    lookup_tables: []const LookupTableCandidate,
    selections: []LookupSelection,
    static_count: usize,
    lookups_out: []tx.MessageAddressTableLookup,
    writable_indexes_out: []u8,
    readonly_indexes_out: []u8,
) Error![]const tx.MessageAddressTableLookup {
    var lookup_count: usize = 0;
    var writable_cursor: usize = 0;
    var readonly_cursor: usize = 0;

    for (lookup_tables, 0..) |candidate, table_index| {
        const writable_start = writable_cursor;
        const readonly_start = readonly_cursor;

        for (selections) |*selection| {
            if (selection.table_index == table_index and selection.is_writable) {
                if (writable_cursor >= writable_indexes_out.len) return error.LookupIndexBufferTooSmall;
                writable_indexes_out[writable_cursor] = selection.address_index;
                selection.loaded_index = @intCast(static_count + writable_cursor);
                writable_cursor += 1;
            }
        }

        for (selections) |*selection| {
            if (selection.table_index == table_index and !selection.is_writable) {
                if (readonly_cursor >= readonly_indexes_out.len) return error.LookupIndexBufferTooSmall;
                readonly_indexes_out[readonly_cursor] = selection.address_index;
                selection.readonly_order = readonly_cursor;
                readonly_cursor += 1;
            }
        }

        if (writable_cursor != writable_start or readonly_cursor != readonly_start) {
            if (lookup_count >= lookups_out.len) return error.LookupTableBufferTooSmall;
            lookups_out[lookup_count] = .{
                .account_key = candidate.account_key,
                .writable_indexes = writable_indexes_out[writable_start..writable_cursor],
                .readonly_indexes = readonly_indexes_out[readonly_start..readonly_cursor],
            };
            lookup_count += 1;
        }
    }

    for (selections) |*selection| {
        if (!selection.is_writable) {
            selection.loaded_index = @intCast(static_count + writable_cursor + selection.readonly_order);
        }
    }

    return lookups_out[0..lookup_count];
}

fn findLookupAddress(lookup_tables: []const LookupTableCandidate, target: *const Pubkey) ?struct {
    table_index: usize,
    address_index: u8,
} {
    for (lookup_tables, 0..) |candidate, table_index| {
        for (candidate.table.addresses, 0..) |*address, address_index| {
            if (std.mem.eql(u8, address, target)) {
                return .{
                    .table_index = table_index,
                    .address_index = @intCast(address_index),
                };
            }
        }
    }
    return null;
}

fn findV0MessageKeyIndex(
    static_keys: []const Pubkey,
    selections: []const LookupSelection,
    target: *const Pubkey,
) ?u8 {
    for (static_keys, 0..) |*key, i| {
        if (std.mem.eql(u8, key, target)) return @intCast(i);
    }
    for (selections) |selection| {
        if (std.mem.eql(u8, &selection.key, target)) return selection.loaded_index;
    }
    return null;
}

test "buildAndSignV0Transaction signs and serializes a versioned transaction" {
    const payer = try Keypair.fromSeed(.{1} ** keypair.SEED_BYTES);
    const program: Pubkey = .{9} ** 32;
    const table: Pubkey = .{8} ** 32;
    const recent_blockhash: [HASH_BYTES]u8 = .{7} ** HASH_BYTES;
    const ix = Instruction.init(&program, &.{}, "hi");

    var account_keys: [4]Pubkey = undefined;
    var compiled: [1]tx.CompiledInstruction = undefined;
    var indices: [1]u8 = undefined;
    const payer_pubkey = payer.publicKey();
    const legacy = try tx.compileLegacyMessage(
        &payer_pubkey,
        &recent_blockhash,
        &.{ix},
        &account_keys,
        &compiled,
        &indices,
    );
    const lookup: tx.MessageAddressTableLookup = .{
        .account_key = &table,
        .writable_indexes = &.{1},
        .readonly_indexes = &.{2},
    };
    const message: tx.V0Message = .{
        .header = legacy.header,
        .account_keys = legacy.account_keys,
        .recent_blockhash = legacy.recent_blockhash,
        .instructions = legacy.instructions,
        .address_table_lookups = &.{lookup},
    };

    var message_bytes: [192]u8 = undefined;
    var signatures: [2]Signature = undefined;
    var transaction_bytes: [320]u8 = undefined;
    const built = try buildAndSignV0Transaction(message, &.{payer}, .{
        .message_bytes = &message_bytes,
        .signatures = &signatures,
        .transaction_bytes = &transaction_bytes,
    });

    try std.testing.expectEqual(@as(u8, 1), built.message.header.num_required_signatures);
    try std.testing.expectEqual(@as(u8, tx.VERSIONED_MESSAGE_PREFIX | tx.V0_MESSAGE_VERSION), built.message_bytes[0]);
    try keypair.verify(built.signatures[0], built.message_bytes, &payer_pubkey);
    try std.testing.expectEqual(@as(u8, 1), built.transaction_bytes[0]);
    try std.testing.expectEqualSlices(u8, &built.signatures[0], built.transaction_bytes[1..65]);
    try std.testing.expectEqualSlices(u8, built.message_bytes, built.transaction_bytes[65..]);
}

test "compileV0MessageWithLookupTables selects ALT accounts and compiles combined indexes" {
    const payer = try Keypair.fromSeed(.{1} ** keypair.SEED_BYTES);
    const owner = try Keypair.fromSeed(.{2} ** keypair.SEED_BYTES);
    const payer_pubkey = payer.publicKey();
    const owner_pubkey = owner.publicKey();
    const program: Pubkey = .{3} ** 32;
    const static_account: Pubkey = .{4} ** 32;
    const alt_writable: Pubkey = .{5} ** 32;
    const alt_readonly: Pubkey = .{6} ** 32;
    const table_key: Pubkey = .{7} ** 32;
    const recent_blockhash: [HASH_BYTES]u8 = .{8} ** HASH_BYTES;
    const table_addresses = [_]Pubkey{
        .{9} ** 32,
        alt_readonly,
        alt_writable,
    };
    const table: LookupTableAccount = .{
        .meta = .{
            .deactivation_slot = std.math.maxInt(u64),
            .last_extended_slot = 1,
            .last_extended_slot_start_index = 0,
            .authority = null,
        },
        .addresses = &table_addresses,
    };
    var metas = [_]tx.AccountMeta{
        tx.AccountMeta.writable(&alt_writable),
        tx.AccountMeta.readonly(&alt_readonly),
        tx.AccountMeta.signer(&owner_pubkey),
        tx.AccountMeta.writable(&static_account),
    };
    const ix = Instruction.init(&program, &metas, &.{0xaa});

    var static_keys: [8]Pubkey = undefined;
    var compiled: [1]tx.CompiledInstruction = undefined;
    var ix_indices: [4]u8 = undefined;
    var lookups: [1]tx.MessageAddressTableLookup = undefined;
    var writable_indexes: [2]u8 = undefined;
    var readonly_indexes: [2]u8 = undefined;
    const message = try compileV0MessageWithLookupTables(
        &payer_pubkey,
        &recent_blockhash,
        &.{ix},
        &.{.{ .account_key = &table_key, .table = table }},
        .{
            .static_account_keys = &static_keys,
            .compiled_instructions = &compiled,
            .instruction_account_indices = &ix_indices,
            .address_table_lookups = &lookups,
            .writable_lookup_indexes = &writable_indexes,
            .readonly_lookup_indexes = &readonly_indexes,
        },
    );

    try std.testing.expectEqual(@as(u8, 2), message.header.num_required_signatures);
    try std.testing.expectEqual(@as(u8, 1), message.header.num_readonly_signed_accounts);
    try std.testing.expectEqual(@as(u8, 1), message.header.num_readonly_unsigned_accounts);
    try std.testing.expectEqual(@as(usize, 4), message.account_keys.len);
    try std.testing.expectEqualSlices(u8, &payer_pubkey, &message.account_keys[0]);
    try std.testing.expectEqualSlices(u8, &owner_pubkey, &message.account_keys[1]);
    try std.testing.expectEqualSlices(u8, &static_account, &message.account_keys[2]);
    try std.testing.expectEqualSlices(u8, &program, &message.account_keys[3]);
    try std.testing.expectEqual(@as(usize, 1), message.address_table_lookups.len);
    try std.testing.expectEqualSlices(u8, &table_key, message.address_table_lookups[0].account_key);
    try std.testing.expectEqualSlices(u8, &.{2}, message.address_table_lookups[0].writable_indexes);
    try std.testing.expectEqualSlices(u8, &.{1}, message.address_table_lookups[0].readonly_indexes);
    try std.testing.expectEqual(@as(u8, 3), message.instructions[0].program_id_index);
    try std.testing.expectEqualSlices(u8, &.{ 4, 5, 1, 2 }, message.instructions[0].accounts);
}

test "buildAndSignV0TransactionFromInstructions compiles ALT lookups signs and serializes" {
    const payer = try Keypair.fromSeed(.{1} ** keypair.SEED_BYTES);
    const payer_pubkey = payer.publicKey();
    const program: Pubkey = .{3} ** 32;
    const alt_readonly: Pubkey = .{6} ** 32;
    const table_key: Pubkey = .{7} ** 32;
    const recent_blockhash: [HASH_BYTES]u8 = .{8} ** HASH_BYTES;
    const table_addresses = [_]Pubkey{alt_readonly};
    const table: LookupTableAccount = .{
        .meta = .{
            .deactivation_slot = std.math.maxInt(u64),
            .last_extended_slot = 1,
            .last_extended_slot_start_index = 0,
            .authority = null,
        },
        .addresses = &table_addresses,
    };
    var metas = [_]tx.AccountMeta{tx.AccountMeta.readonly(&alt_readonly)};
    const ix = Instruction.init(&program, &metas, &.{0xaa});

    var static_keys: [4]Pubkey = undefined;
    var compiled: [1]tx.CompiledInstruction = undefined;
    var ix_indices: [1]u8 = undefined;
    var lookups: [1]tx.MessageAddressTableLookup = undefined;
    var writable_indexes: [1]u8 = undefined;
    var readonly_indexes: [1]u8 = undefined;
    var message_bytes: [192]u8 = undefined;
    var signatures: [1]Signature = undefined;
    var transaction_bytes: [320]u8 = undefined;

    const built = try buildAndSignV0TransactionFromInstructions(
        &payer_pubkey,
        &recent_blockhash,
        &.{ix},
        &.{.{ .account_key = &table_key, .table = table }},
        &.{payer},
        .{
            .static_account_keys = &static_keys,
            .compiled_instructions = &compiled,
            .instruction_account_indices = &ix_indices,
            .address_table_lookups = &lookups,
            .writable_lookup_indexes = &writable_indexes,
            .readonly_lookup_indexes = &readonly_indexes,
        },
        .{
            .message_bytes = &message_bytes,
            .signatures = &signatures,
            .transaction_bytes = &transaction_bytes,
        },
    );

    try std.testing.expectEqual(@as(usize, 1), built.message.address_table_lookups.len);
    try std.testing.expectEqualSlices(u8, &.{0}, built.message.address_table_lookups[0].readonly_indexes);
    try std.testing.expectEqual(@as(u8, tx.VERSIONED_MESSAGE_PREFIX | tx.V0_MESSAGE_VERSION), built.message_bytes[0]);
    try keypair.verify(built.signatures[0], built.message_bytes, &payer_pubkey);
    try std.testing.expectEqualSlices(u8, built.message_bytes, built.transaction_bytes[65..]);
}

test "createNonceAccountInstructions composes create and initialize nonce account" {
    const payer: Pubkey = .{1} ** 32;
    const nonce: Pubkey = .{2} ** 32;
    const authority: Pubkey = .{3} ** 32;

    var create_metas: [2]system.AccountMeta = undefined;
    var create_data: system.CreateAccountData = undefined;
    var init_metas: [3]system.AccountMeta = undefined;
    var init_data: system.NonceAuthorityData = undefined;

    const instructions = createNonceAccountInstructions(&payer, &nonce, &authority, 1_000, .{
        .create_account_metas = &create_metas,
        .create_account_data = &create_data,
        .initialize_nonce_metas = &init_metas,
        .initialize_nonce_data = &init_data,
    });

    try std.testing.expectEqual(@as(usize, 2), instructions.slice().len);
    const create_ix = instructions.createAccount();
    try std.testing.expectEqualSlices(u8, &system.PROGRAM_ID, create_ix.program_id);
    try std.testing.expectEqual(@as(u32, 0), std.mem.readInt(u32, create_ix.data[0..4], .little));
    try std.testing.expectEqual(@as(u64, 1_000), std.mem.readInt(u64, create_ix.data[4..12], .little));
    try std.testing.expectEqual(@as(u64, system.NONCE_STATE_SIZE), std.mem.readInt(u64, create_ix.data[12..20], .little));
    try std.testing.expectEqualSlices(u8, &system.PROGRAM_ID, create_ix.data[20..52]);
    try std.testing.expectEqual(@as(u8, 1), create_ix.accounts[0].is_signer);
    try std.testing.expectEqual(@as(u8, 1), create_ix.accounts[1].is_signer);

    const init_ix = instructions.initializeNonceAccount();
    try std.testing.expectEqualSlices(u8, &system.PROGRAM_ID, init_ix.program_id);
    try std.testing.expectEqual(@as(u32, 6), std.mem.readInt(u32, init_ix.data[0..4], .little));
    try std.testing.expectEqualSlices(u8, &authority, init_ix.data[4..36]);
    try std.testing.expectEqual(@as(usize, 3), init_ix.accounts.len);
    try std.testing.expectEqualSlices(u8, &nonce, init_ix.accounts[0].pubkey);
    try std.testing.expectEqual(@as(u8, 1), init_ix.accounts[0].is_writable);
    try std.testing.expectEqual(@as(u8, 0), init_ix.accounts[1].is_writable);
    try std.testing.expectEqual(@as(u8, 0), init_ix.accounts[2].is_signer);
}

test "createNonceAccountInstructionsWithSysvars keeps caller supplied sysvars" {
    const payer: Pubkey = .{1} ** 32;
    const nonce: Pubkey = .{2} ** 32;
    const authority: Pubkey = .{3} ** 32;
    const recent: Pubkey = .{4} ** 32;
    const rent: Pubkey = .{5} ** 32;

    var create_metas: [2]system.AccountMeta = undefined;
    var create_data: system.CreateAccountData = undefined;
    var init_metas: [3]system.AccountMeta = undefined;
    var init_data: system.NonceAuthorityData = undefined;

    const instructions = createNonceAccountInstructionsWithSysvars(
        &payer,
        &nonce,
        &recent,
        &rent,
        &authority,
        1_000,
        .{
            .create_account_metas = &create_metas,
            .create_account_data = &create_data,
            .initialize_nonce_metas = &init_metas,
            .initialize_nonce_data = &init_data,
        },
    );

    try std.testing.expectEqualSlices(u8, &recent, instructions.initializeNonceAccount().accounts[1].pubkey);
    try std.testing.expectEqualSlices(u8, &rent, instructions.initializeNonceAccount().accounts[2].pubkey);
}

test "computeBudgetPrelude builds ordered compute budget prelude" {
    var heap_data: ComputeBudgetRequestHeapFrameData = undefined;
    var limit_data: ComputeBudgetSetComputeUnitLimitData = undefined;
    var price_data: ComputeBudgetSetComputeUnitPriceData = undefined;
    var loaded_data: ComputeBudgetSetLoadedAccountsDataSizeLimitData = undefined;

    const prelude = computeBudgetPrelude(.{
        .heap_frame_bytes = 32 * 1024,
        .loaded_accounts_data_size_limit = 64 * 1024,
        .compute_unit_limit = 200_000,
        .compute_unit_price_micro_lamports = 5_000,
    }, .{
        .request_heap_frame_data = &heap_data,
        .set_compute_unit_limit_data = &limit_data,
        .set_compute_unit_price_data = &price_data,
        .set_loaded_accounts_data_size_limit_data = &loaded_data,
    });

    try std.testing.expectEqual(@as(usize, 4), prelude.slice().len);
    for (prelude.slice()) |ix| {
        try std.testing.expectEqualSlices(u8, &compute_budget.PROGRAM_ID, ix.program_id);
        try std.testing.expectEqual(@as(usize, 0), ix.accounts.len);
    }
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 0x80, 0, 0 }, prelude.instructions[0].data);
    try std.testing.expectEqualSlices(u8, &.{ 4, 0, 0, 1, 0 }, prelude.instructions[1].data);
    try std.testing.expectEqualSlices(u8, &.{ 2, 0x40, 0x0d, 0x03, 0 }, prelude.instructions[2].data);
    try std.testing.expectEqualSlices(u8, &.{ 3, 0x88, 0x13, 0, 0, 0, 0, 0, 0 }, prelude.instructions[3].data);
}

test "transferWithComputeBudget composes prelude and system transfer" {
    const payer = try Keypair.fromSeed(.{1} ** keypair.SEED_BYTES);
    const recipient = try Keypair.fromSeed(.{2} ** keypair.SEED_BYTES);
    const payer_pubkey = payer.publicKey();
    const recipient_pubkey = recipient.publicKey();
    const recent_blockhash: [HASH_BYTES]u8 = .{9} ** HASH_BYTES;

    var heap_data: ComputeBudgetRequestHeapFrameData = undefined;
    var limit_data: ComputeBudgetSetComputeUnitLimitData = undefined;
    var price_data: ComputeBudgetSetComputeUnitPriceData = undefined;
    var loaded_data: ComputeBudgetSetLoadedAccountsDataSizeLimitData = undefined;
    var transfer_metas: [2]SystemAccountMeta = undefined;
    var transfer_data: SystemTransferData = undefined;

    const instructions = transferWithComputeBudget(
        &payer_pubkey,
        &recipient_pubkey,
        123,
        .{
            .compute_unit_limit = 100_000,
            .compute_unit_price_micro_lamports = 7,
        },
        .{
            .compute_budget = .{
                .request_heap_frame_data = &heap_data,
                .set_compute_unit_limit_data = &limit_data,
                .set_compute_unit_price_data = &price_data,
                .set_loaded_accounts_data_size_limit_data = &loaded_data,
            },
            .transfer_metas = &transfer_metas,
            .transfer_data = &transfer_data,
        },
    );

    try std.testing.expectEqual(@as(usize, 3), instructions.slice().len);
    try std.testing.expectEqualSlices(u8, &compute_budget.PROGRAM_ID, instructions.instructions[0].program_id);
    try std.testing.expectEqualSlices(u8, &compute_budget.PROGRAM_ID, instructions.instructions[1].program_id);
    const transfer_ix = instructions.transferInstruction();
    try std.testing.expectEqualSlices(u8, &system.PROGRAM_ID, transfer_ix.program_id);
    try std.testing.expectEqual(@as(u32, 2), std.mem.readInt(u32, transfer_ix.data[0..4], .little));
    try std.testing.expectEqual(@as(u64, 123), std.mem.readInt(u64, transfer_ix.data[4..12], .little));

    var account_keys: [8]Pubkey = undefined;
    var compiled: [3]tx.CompiledInstruction = undefined;
    var indices: [2]u8 = undefined;
    var message_bytes: [256]u8 = undefined;
    var signatures: [1]Signature = undefined;
    var transaction_bytes: [384]u8 = undefined;
    const built = try buildAndSignLegacyTransaction(
        &payer_pubkey,
        &recent_blockhash,
        instructions.slice(),
        &.{payer},
        .{
            .account_keys = &account_keys,
            .compiled_instructions = &compiled,
            .instruction_account_indices = &indices,
            .message_bytes = &message_bytes,
            .signatures = &signatures,
            .transaction_bytes = &transaction_bytes,
        },
    );

    try std.testing.expectEqual(@as(usize, 3), built.message.instructions.len);
    try std.testing.expectEqual(@as(u8, 1), built.message.header.num_required_signatures);
    try keypair.verify(built.signatures[0], built.message_bytes, &payer_pubkey);
}

test "token transfer helpers compose compute budget prelude and SPL Token instructions" {
    const source: Pubkey = .{1} ** 32;
    const destination: Pubkey = .{2} ** 32;
    const authority: Pubkey = .{3} ** 32;
    const mint: Pubkey = .{4} ** 32;

    var heap_data: ComputeBudgetRequestHeapFrameData = undefined;
    var limit_data: ComputeBudgetSetComputeUnitLimitData = undefined;
    var price_data: ComputeBudgetSetComputeUnitPriceData = undefined;
    var loaded_data: ComputeBudgetSetLoadedAccountsDataSizeLimitData = undefined;
    var transfer_metas: TokenTransferMetas = undefined;
    var transfer_data: TokenTransferData = undefined;

    const transfer_instructions = tokenTransferWithComputeBudget(
        &source,
        &destination,
        &authority,
        55,
        .{
            .compute_unit_limit = 45_000,
            .compute_unit_price_micro_lamports = 9,
        },
        .{
            .compute_budget = .{
                .request_heap_frame_data = &heap_data,
                .set_compute_unit_limit_data = &limit_data,
                .set_compute_unit_price_data = &price_data,
                .set_loaded_accounts_data_size_limit_data = &loaded_data,
            },
            .transfer_metas = &transfer_metas,
            .transfer_data = &transfer_data,
        },
    );
    try std.testing.expectEqual(@as(usize, 3), transfer_instructions.slice().len);
    try std.testing.expectEqualSlices(u8, &compute_budget.PROGRAM_ID, transfer_instructions.instructions[0].program_id);
    try std.testing.expectEqualSlices(u8, &compute_budget.PROGRAM_ID, transfer_instructions.instructions[1].program_id);
    const token_ix = transfer_instructions.tokenTransferInstruction();
    try std.testing.expectEqualSlices(u8, &spl_token.PROGRAM_ID, token_ix.program_id);
    try std.testing.expectEqual(@as(usize, 3), token_ix.accounts.len);
    try std.testing.expectEqualSlices(u8, &source, token_ix.accounts[0].pubkey);
    try std.testing.expectEqualSlices(u8, &destination, token_ix.accounts[1].pubkey);
    try std.testing.expectEqualSlices(u8, &authority, token_ix.accounts[2].pubkey);
    try std.testing.expectEqualSlices(u8, &.{ 3, 55, 0, 0, 0, 0, 0, 0, 0 }, token_ix.data);

    var checked_metas: TokenTransferCheckedMetas = undefined;
    var checked_data: TokenTransferCheckedData = undefined;
    const checked_instructions = tokenTransferCheckedWithComputeBudget(
        &source,
        &mint,
        &destination,
        &authority,
        77,
        6,
        .{ .loaded_accounts_data_size_limit = 512 },
        .{
            .compute_budget = .{
                .request_heap_frame_data = &heap_data,
                .set_compute_unit_limit_data = &limit_data,
                .set_compute_unit_price_data = &price_data,
                .set_loaded_accounts_data_size_limit_data = &loaded_data,
            },
            .transfer_metas = &checked_metas,
            .transfer_data = &checked_data,
        },
    );
    try std.testing.expectEqual(@as(usize, 2), checked_instructions.slice().len);
    try std.testing.expectEqualSlices(u8, &compute_budget.PROGRAM_ID, checked_instructions.instructions[0].program_id);
    const checked_ix = checked_instructions.tokenTransferInstruction();
    try std.testing.expectEqualSlices(u8, &spl_token.PROGRAM_ID, checked_ix.program_id);
    try std.testing.expectEqual(@as(usize, 4), checked_ix.accounts.len);
    try std.testing.expectEqualSlices(u8, &source, checked_ix.accounts[0].pubkey);
    try std.testing.expectEqualSlices(u8, &mint, checked_ix.accounts[1].pubkey);
    try std.testing.expectEqualSlices(u8, &destination, checked_ix.accounts[2].pubkey);
    try std.testing.expectEqualSlices(u8, &authority, checked_ix.accounts[3].pubkey);
    try std.testing.expectEqualSlices(u8, &.{ 12, 77, 0, 0, 0, 0, 0, 0, 0, 6 }, checked_ix.data);
}

test "ATA token transfer helpers compose idempotent ATA create and SPL Token transfer" {
    const payer: Pubkey = .{1} ** 32;
    const wallet: Pubkey = .{2} ** 32;
    const source: Pubkey = .{3} ** 32;
    const mint: Pubkey = .{4} ** 32;
    const authority: Pubkey = .{5} ** 32;
    const expected_ata = spl_ata.findAddress(&wallet, &mint, &spl_token.PROGRAM_ID).address;

    var heap_data: ComputeBudgetRequestHeapFrameData = undefined;
    var limit_data: ComputeBudgetSetComputeUnitLimitData = undefined;
    var price_data: ComputeBudgetSetComputeUnitPriceData = undefined;
    var loaded_data: ComputeBudgetSetLoadedAccountsDataSizeLimitData = undefined;
    var ata_scratch: AtaCreateIdempotentScratch = undefined;
    var transfer_metas: TokenTransferMetas = undefined;
    var transfer_data: TokenTransferData = undefined;

    const instructions = createAtaAndTokenTransferWithComputeBudget(
        &payer,
        &wallet,
        &source,
        &mint,
        &authority,
        88,
        .{ .compute_unit_limit = 60_000 },
        .{
            .compute_budget = .{
                .request_heap_frame_data = &heap_data,
                .set_compute_unit_limit_data = &limit_data,
                .set_compute_unit_price_data = &price_data,
                .set_loaded_accounts_data_size_limit_data = &loaded_data,
            },
            .ata_scratch = &ata_scratch,
            .transfer_metas = &transfer_metas,
            .transfer_data = &transfer_data,
        },
    );
    try std.testing.expectEqual(@as(usize, 3), instructions.slice().len);
    try std.testing.expectEqualSlices(u8, &compute_budget.PROGRAM_ID, instructions.instructions[0].program_id);
    try std.testing.expectEqualSlices(u8, &expected_ata, &ata_scratch.associated_token_account);

    const ata_ix = instructions.createAssociatedTokenAccountInstruction();
    try std.testing.expectEqualSlices(u8, &spl_ata.PROGRAM_ID, ata_ix.program_id);
    try std.testing.expectEqualSlices(u8, &.{1}, ata_ix.data);
    try std.testing.expectEqualSlices(u8, &payer, ata_ix.accounts[0].pubkey);
    try std.testing.expectEqualSlices(u8, &expected_ata, ata_ix.accounts[1].pubkey);
    try std.testing.expectEqualSlices(u8, &wallet, ata_ix.accounts[2].pubkey);
    try std.testing.expectEqualSlices(u8, &mint, ata_ix.accounts[3].pubkey);
    try std.testing.expectEqualSlices(u8, &system.PROGRAM_ID, ata_ix.accounts[4].pubkey);
    try std.testing.expectEqualSlices(u8, &spl_token.PROGRAM_ID, ata_ix.accounts[5].pubkey);

    const token_ix = instructions.tokenTransferInstruction();
    try std.testing.expectEqualSlices(u8, &spl_token.PROGRAM_ID, token_ix.program_id);
    try std.testing.expectEqualSlices(u8, &source, token_ix.accounts[0].pubkey);
    try std.testing.expectEqualSlices(u8, &expected_ata, token_ix.accounts[1].pubkey);
    try std.testing.expectEqualSlices(u8, &authority, token_ix.accounts[2].pubkey);
    try std.testing.expectEqualSlices(u8, &.{ 3, 88, 0, 0, 0, 0, 0, 0, 0 }, token_ix.data);

    var checked_ata_scratch: AtaCreateIdempotentScratch = undefined;
    var checked_metas: TokenTransferCheckedMetas = undefined;
    var checked_data: TokenTransferCheckedData = undefined;
    const checked_instructions = createAtaAndTokenTransferCheckedWithComputeBudget(
        &payer,
        &wallet,
        &source,
        &mint,
        &authority,
        99,
        6,
        .{},
        .{
            .compute_budget = .{
                .request_heap_frame_data = &heap_data,
                .set_compute_unit_limit_data = &limit_data,
                .set_compute_unit_price_data = &price_data,
                .set_loaded_accounts_data_size_limit_data = &loaded_data,
            },
            .ata_scratch = &checked_ata_scratch,
            .transfer_metas = &checked_metas,
            .transfer_data = &checked_data,
        },
    );
    try std.testing.expectEqual(@as(usize, 2), checked_instructions.slice().len);
    try std.testing.expectEqualSlices(u8, &expected_ata, &checked_ata_scratch.associated_token_account);
    const checked_ix = checked_instructions.tokenTransferInstruction();
    try std.testing.expectEqualSlices(u8, &source, checked_ix.accounts[0].pubkey);
    try std.testing.expectEqualSlices(u8, &mint, checked_ix.accounts[1].pubkey);
    try std.testing.expectEqualSlices(u8, &expected_ata, checked_ix.accounts[2].pubkey);
    try std.testing.expectEqualSlices(u8, &authority, checked_ix.accounts[3].pubkey);
    try std.testing.expectEqualSlices(u8, &.{ 12, 99, 0, 0, 0, 0, 0, 0, 0, 6 }, checked_ix.data);
}

test "nonce account instruction pair can be signed as one legacy transaction" {
    const payer = try Keypair.fromSeed(.{1} ** keypair.SEED_BYTES);
    const nonce_account = try Keypair.fromSeed(.{2} ** keypair.SEED_BYTES);
    const authority = try Keypair.fromSeed(.{3} ** keypair.SEED_BYTES);
    const payer_pubkey = payer.publicKey();
    const nonce_pubkey = nonce_account.publicKey();
    const authority_pubkey = authority.publicKey();
    const recent_blockhash: [HASH_BYTES]u8 = .{7} ** HASH_BYTES;

    var create_metas: [2]system.AccountMeta = undefined;
    var create_data: system.CreateAccountData = undefined;
    var init_metas: [3]system.AccountMeta = undefined;
    var init_data: system.NonceAuthorityData = undefined;
    const instructions = createNonceAccountInstructions(
        &payer_pubkey,
        &nonce_pubkey,
        &authority_pubkey,
        1_000,
        .{
            .create_account_metas = &create_metas,
            .create_account_data = &create_data,
            .initialize_nonce_metas = &init_metas,
            .initialize_nonce_data = &init_data,
        },
    );

    var account_keys: [8]Pubkey = undefined;
    var compiled: [2]tx.CompiledInstruction = undefined;
    var indices: [5]u8 = undefined;
    var message_bytes: [384]u8 = undefined;
    var signatures: [2]Signature = undefined;
    var transaction_bytes: [640]u8 = undefined;
    const built = try buildAndSignLegacyTransaction(
        &payer_pubkey,
        &recent_blockhash,
        instructions.slice(),
        &.{ payer, nonce_account },
        .{
            .account_keys = &account_keys,
            .compiled_instructions = &compiled,
            .instruction_account_indices = &indices,
            .message_bytes = &message_bytes,
            .signatures = &signatures,
            .transaction_bytes = &transaction_bytes,
        },
    );

    try std.testing.expectEqual(@as(u8, 2), built.message.header.num_required_signatures);
    try std.testing.expectEqual(@as(usize, 2), built.message.instructions.len);
    try keypair.verify(built.signatures[0], built.message_bytes, &payer_pubkey);
    try keypair.verify(built.signatures[1], built.message_bytes, &nonce_pubkey);
}

test "buildAndSignV0Transaction reports missing signer and small buffers" {
    const payer = try Keypair.fromSeed(.{1} ** keypair.SEED_BYTES);
    const recent_blockhash: [HASH_BYTES]u8 = .{7} ** HASH_BYTES;
    const payer_pubkey = payer.publicKey();
    const message: tx.V0Message = .{
        .header = .{
            .num_required_signatures = 1,
            .num_readonly_signed_accounts = 0,
            .num_readonly_unsigned_accounts = 0,
        },
        .account_keys = &.{payer_pubkey},
        .recent_blockhash = &recent_blockhash,
        .instructions = &.{},
        .address_table_lookups = &.{},
    };

    var message_bytes: [96]u8 = undefined;
    var signatures: [1]Signature = undefined;
    var transaction_bytes: [160]u8 = undefined;
    try std.testing.expectError(
        error.MissingRequiredSigner,
        buildAndSignV0Transaction(message, &.{}, .{
            .message_bytes = &message_bytes,
            .signatures = &signatures,
            .transaction_bytes = &transaction_bytes,
        }),
    );

    var short_message: [1]u8 = undefined;
    try std.testing.expectError(
        error.MessageBufferTooSmall,
        buildAndSignV0Transaction(message, &.{payer}, .{
            .message_bytes = &short_message,
            .signatures = &signatures,
            .transaction_bytes = &transaction_bytes,
        }),
    );
}

test "buildAndSignLegacyTransaction compiles signs and serializes a legacy transaction" {
    const payer = try Keypair.fromSeed(.{1} ** keypair.SEED_BYTES);
    const program: Pubkey = .{9} ** 32;
    const recent_blockhash: [HASH_BYTES]u8 = .{7} ** HASH_BYTES;
    const ix = Instruction.init(&program, &.{}, "hi");

    var account_keys: [4]Pubkey = undefined;
    var compiled: [1]tx.CompiledInstruction = undefined;
    var indices: [1]u8 = undefined;
    var message_bytes: [128]u8 = undefined;
    var signatures: [2]Signature = undefined;
    var transaction_bytes: [256]u8 = undefined;

    const payer_pubkey = payer.publicKey();
    const built = try buildAndSignLegacyTransaction(
        &payer_pubkey,
        &recent_blockhash,
        &.{ix},
        &.{payer},
        .{
            .account_keys = &account_keys,
            .compiled_instructions = &compiled,
            .instruction_account_indices = &indices,
            .message_bytes = &message_bytes,
            .signatures = &signatures,
            .transaction_bytes = &transaction_bytes,
        },
    );

    try std.testing.expectEqual(@as(u8, 1), built.message.header.num_required_signatures);
    try std.testing.expectEqualSlices(u8, &payer_pubkey, &built.message.account_keys[0]);
    try keypair.verify(built.signatures[0], built.message_bytes, &payer_pubkey);
    try std.testing.expectEqual(@as(u8, 1), built.transaction_bytes[0]);
    try std.testing.expectEqualSlices(u8, &built.signatures[0], built.transaction_bytes[1..65]);
    try std.testing.expectEqualSlices(u8, built.message_bytes, built.transaction_bytes[65..]);
}

test "buildAndSignLegacyTransaction signs required signers in canonical key order" {
    const payer = try Keypair.fromSeed(.{1} ** keypair.SEED_BYTES);
    const owner = try Keypair.fromSeed(.{2} ** keypair.SEED_BYTES);
    const account: Pubkey = .{3} ** 32;
    const program: Pubkey = .{4} ** 32;
    const recent_blockhash: [HASH_BYTES]u8 = .{5} ** HASH_BYTES;

    const owner_pubkey = owner.publicKey();
    var metas = [_]tx.AccountMeta{
        tx.AccountMeta.signer(&owner_pubkey),
        tx.AccountMeta.writable(&account),
    };
    const ix = Instruction.init(&program, &metas, &.{});

    var account_keys: [8]Pubkey = undefined;
    var compiled: [1]tx.CompiledInstruction = undefined;
    var indices: [2]u8 = undefined;
    var message_bytes: [192]u8 = undefined;
    var signatures: [2]Signature = undefined;
    var transaction_bytes: [384]u8 = undefined;

    const payer_pubkey = payer.publicKey();
    const built = try buildAndSignLegacyTransaction(
        &payer_pubkey,
        &recent_blockhash,
        &.{ix},
        &.{ owner, payer },
        .{
            .account_keys = &account_keys,
            .compiled_instructions = &compiled,
            .instruction_account_indices = &indices,
            .message_bytes = &message_bytes,
            .signatures = &signatures,
            .transaction_bytes = &transaction_bytes,
        },
    );

    try std.testing.expectEqual(@as(u8, 2), built.message.header.num_required_signatures);
    try std.testing.expectEqualSlices(u8, &payer_pubkey, &built.message.account_keys[0]);
    try std.testing.expectEqualSlices(u8, &owner_pubkey, &built.message.account_keys[1]);
    try keypair.verify(built.signatures[0], built.message_bytes, &payer_pubkey);
    try keypair.verify(built.signatures[1], built.message_bytes, &owner_pubkey);
}

test "buildAndSignLegacyTransaction reports missing signer and small buffers" {
    const payer = try Keypair.fromSeed(.{1} ** keypair.SEED_BYTES);
    const program: Pubkey = .{9} ** 32;
    const recent_blockhash: [HASH_BYTES]u8 = .{7} ** HASH_BYTES;
    const ix = Instruction.init(&program, &.{}, &.{});

    var account_keys: [4]Pubkey = undefined;
    var compiled: [1]tx.CompiledInstruction = undefined;
    var indices: [1]u8 = undefined;
    var message_bytes: [128]u8 = undefined;
    var signatures: [1]Signature = undefined;
    var transaction_bytes: [256]u8 = undefined;

    const payer_pubkey = payer.publicKey();
    try std.testing.expectError(
        error.MissingRequiredSigner,
        buildAndSignLegacyTransaction(
            &payer_pubkey,
            &recent_blockhash,
            &.{ix},
            &.{},
            .{
                .account_keys = &account_keys,
                .compiled_instructions = &compiled,
                .instruction_account_indices = &indices,
                .message_bytes = &message_bytes,
                .signatures = &signatures,
                .transaction_bytes = &transaction_bytes,
            },
        ),
    );

    var short_message: [1]u8 = undefined;
    try std.testing.expectError(
        error.MessageBufferTooSmall,
        buildAndSignLegacyTransaction(
            &payer_pubkey,
            &recent_blockhash,
            &.{ix},
            &.{payer},
            .{
                .account_keys = &account_keys,
                .compiled_instructions = &compiled,
                .instruction_account_indices = &indices,
                .message_bytes = &short_message,
                .signatures = &signatures,
                .transaction_bytes = &transaction_bytes,
            },
        ),
    );
}

test "public surface guards" {
    try std.testing.expect(@hasDecl(@This(), "buildAndSignLegacyTransaction"));
    try std.testing.expect(@hasDecl(@This(), "buildAndSignV0Transaction"));
    try std.testing.expect(@hasDecl(@This(), "compileV0MessageWithLookupTables"));
    try std.testing.expect(@hasDecl(@This(), "buildAndSignV0TransactionFromInstructions"));
    try std.testing.expect(@hasDecl(@This(), "createNonceAccountInstructions"));
    try std.testing.expect(@hasDecl(@This(), "computeBudgetPrelude"));
    try std.testing.expect(@hasDecl(@This(), "transferWithComputeBudget"));
    try std.testing.expect(@hasDecl(@This(), "tokenTransferWithComputeBudget"));
    try std.testing.expect(@hasDecl(@This(), "tokenTransferCheckedWithComputeBudget"));
    try std.testing.expect(@hasDecl(@This(), "createAtaAndTokenTransferWithComputeBudget"));
    try std.testing.expect(@hasDecl(@This(), "createAtaAndTokenTransferCheckedWithComputeBudget"));
    try std.testing.expect(@hasDecl(@This(), "LegacyBuffers"));
    try std.testing.expect(@hasDecl(@This(), "V0Buffers"));
    try std.testing.expect(@hasDecl(@This(), "V0CompileBuffers"));
    try std.testing.expect(!@hasDecl(@This(), "rpc"));
    try std.testing.expect(!@hasDecl(@This(), "wallet"));
}
