const std = @import("std");
const Pubkey = @import("pubkey.zig").Pubkey;
const AccountInfo = @import("account.zig").AccountInfo;

/// Context contains all the information available to a Solana program
pub const Context = struct {
    program_id: *const Pubkey,
    accounts: []const AccountInfo,
    instruction_data: []const u8,

    /// Load context from the entrypoint input
    pub fn load(input: [*]u8) !Context {
        var offset: usize = 0;
        
        // Read number of accounts
        const num_accounts = std.mem.readInt(u64, input[offset..][0..8], .little);
        offset += 8;
        
        // Allocate accounts array (using a fixed buffer for BPF)
        var accounts_buf: [64]AccountInfo = undefined;
        if (num_accounts > accounts_buf.len) {
            return error.TooManyAccounts;
        }
        
        // Read each account
        for (0..num_accounts) |i| {
            // Read duplicate indicator
            const is_dup = input[offset];
            offset += 1;
            
            if (is_dup != 0) {
                // This is a duplicate of a previous account
                const dup_index = input[offset];
                offset += 1;
                accounts_buf[i] = accounts_buf[dup_index];
            } else {
                // Read full account info
                var account = &accounts_buf[i];
                
                // is_signer
                account.is_signer = input[offset] != 0;
                offset += 1;
                
                // is_writable
                account.is_writable = input[offset] != 0;
                offset += 1;
                
                // key (pubkey)
                account.key = @ptrCast(@alignCast(input[offset..][0..32]));
                offset += 32;
                
                // lamports
                account.lamports = @ptrCast(@alignCast(input[offset..][0..8]));
                offset += 8;
                
                // data length
                const data_len = std.mem.readInt(u64, input[offset..][0..8], .little);
                offset += 8;
                
                // data
                account.data = input[offset..][0..data_len];
                offset += data_len;
                
                // owner
                account.owner = @ptrCast(@alignCast(input[offset..][0..32]));
                offset += 32;
                
                // executable
                account.executable = input[offset] != 0;
                offset += 1;
                
                // rent_epoch
                account.rent_epoch = std.mem.readInt(u64, input[offset..][0..8], .little);
                offset += 8;
            }
        }
        
        // Read instruction data length
        const instruction_data_len = std.mem.readInt(u64, input[offset..][0..8], .little);
        offset += 8;
        
        // Read instruction data
        const instruction_data = input[offset..][0..instruction_data_len];
        offset += instruction_data_len;
        
        // Read program id
        const program_id: *const Pubkey = @ptrCast(@alignCast(input[offset..][0..32]));
        
        return Context{
            .program_id = program_id,
            .accounts = accounts_buf[0..num_accounts],
            .instruction_data = instruction_data,
        };
    }
};