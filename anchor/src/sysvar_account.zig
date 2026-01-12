//! Sysvar account wrappers for Anchor-style account validation.
//!
//! Rust source: https://github.com/coral-xyz/anchor/blob/master/lang/src/accounts/sysvar.rs

const sol = @import("solana_program_sdk");

const AccountInfo = sol.account.Account.Info;
const PublicKey = sol.PublicKey;

/// Sysvar marker for ID-only sysvars without a data type.
pub fn SysvarId(comptime sysvar_id: PublicKey) type {
    return struct {
        pub const id = sysvar_id;
    };
}

pub const Instructions = SysvarId(sol.INSTRUCTIONS_ID);
pub const StakeHistory = SysvarId(sol.STAKE_HISTORY_ID);

/// Sysvar account wrapper with address validation.
pub fn Sysvar(comptime SysvarType: type) type {
    if (!@hasDecl(SysvarType, "id")) {
        @compileError("Sysvar type must define an id");
    }

    return struct {
        const Self = @This();

        pub const SYSVAR_TYPE = SysvarType;
        pub const ID = SysvarType.id;

        info: *const AccountInfo,

        pub fn load(info: *const AccountInfo) !Self {
            if (!info.id.equals(SysvarType.id)) {
                return error.ConstraintAddress;
            }
            return .{ .info = info };
        }

        pub fn key(self: Self) *const PublicKey {
            return self.info.id;
        }

        pub fn toAccountInfo(self: Self) *const AccountInfo {
            return self.info;
        }
    };
}
