//! Typed account view — zero-copy `T`-shaped access to runtime account data.
//!
//! A `TypedAccount(T)` wraps an `AccountInfo` and lets you read/write
//! fields of the user-defined `T` (an `extern struct`) **in place** in
//! the runtime input buffer. There is no allocation, no serialization,
//! no `RefCell` — every field access is a single pointer deref.
//!
//! Conventions:
//!   - `T` must be an `extern struct` (so its layout is C ABI, stable,
//!     and packed-without-padding-surprises).
//!   - If `T` declares a comptime `pub const DISCRIMINATOR: [8]u8`
//!     (typically `sol.discriminator.forAccount("MyType")`), the
//!     bind/initialize helpers enforce that the first 8 bytes of the
//!     account's data equal that constant. This matches the Anchor
//!     convention and defends against type-confusion attacks. The
//!     user is expected to reserve the first 8 bytes of `T`'s layout
//!     for this purpose (e.g. `discriminator: [8]u8 = DISCRIMINATOR`
//!     as field 0).
//!   - Without `DISCRIMINATOR`, no type check is enforced — the caller
//!     takes responsibility for type safety some other way.
//!
//! Cost: equivalent to hand-written `@ptrCast(@alignCast(data.ptr))`
//! plus (when applicable) one 64-bit compare against an immediate for
//! the discriminator check. No allocation, no copy.

const std = @import("std");
const account_mod = @import("account/root.zig");
const discriminator = @import("discriminator.zig");
const program_error = @import("program_error.zig");

const AccountInfo = account_mod.AccountInfo;
const ProgramError = program_error.ProgramError;
const DISCRIMINATOR_LEN = discriminator.DISCRIMINATOR_LEN;

/// Pull the `DISCRIMINATOR` decl off `T` if it has one with the right shape.
fn declaredDiscriminator(comptime T: type) ?[DISCRIMINATOR_LEN]u8 {
    if (!@hasDecl(T, "DISCRIMINATOR")) return null;
    const d = @field(T, "DISCRIMINATOR");
    const D = @TypeOf(d);
    if (D == [DISCRIMINATOR_LEN]u8) return d;
    // Allow inferred-length arrays that coerce to [8]u8.
    const info = @typeInfo(D);
    if (info == .array and info.array.len == DISCRIMINATOR_LEN and info.array.child == u8) {
        return d;
    }
    return null;
}

/// Wrap an `AccountInfo` for typed access to data shaped like `T`.
///
/// `T` should be an `extern struct`. If `T` declares a comptime
/// `pub const DISCRIMINATOR: [8]u8` the bind/initialize helpers
/// enforce it.
pub fn TypedAccount(comptime T: type) type {
    comptime {
        if (@typeInfo(T) != .@"struct") {
            @compileError("TypedAccount(T): T must be a struct");
        }
        const layout = @typeInfo(T).@"struct".layout;
        if (layout != .@"extern" and layout != .@"packed") {
            @compileError("TypedAccount(T): T must be an `extern struct` or `packed struct`");
        }
    }

    const declared = comptime declaredDiscriminator(T);

    return struct {
        info: AccountInfo,

        const Self = @This();
        pub const Inner = T;
        pub const has_discriminator: bool = declared != null;
        pub const expected_discriminator: ?[DISCRIMINATOR_LEN]u8 = declared;
        pub const size: usize = @sizeOf(T);

        /// Wrap without checking the discriminator. Use when you've
        /// already validated the account type some other way (e.g. you
        /// just created the account in this same instruction).
        pub inline fn bindUnchecked(info: AccountInfo) Self {
            return .{ .info = info };
        }

        /// Wrap an `AccountInfo`, verifying:
        ///   1. `info.dataLen() >= @sizeOf(T)` → `AccountDataTooSmall`
        ///   2. (when `T` declares `DISCRIMINATOR`) the first 8 bytes
        ///      of the account's data equal that constant → otherwise
        ///      `InvalidAccountData`.
        pub fn bind(info: AccountInfo) ProgramError!Self {
            if (info.dataLen() < size) return error.AccountDataTooSmall;
            if (comptime declared) |want| {
                const got_ptr: *align(1) const [DISCRIMINATOR_LEN]u8 =
                    @ptrCast(@alignCast(info.dataPtr()));
                if (!discriminator.eq(got_ptr, &want)) {
                    return error.InvalidAccountData;
                }
            }
            return .{ .info = info };
        }

        /// Read-only pointer to the typed payload.
        pub inline fn read(self: Self) *align(1) const T {
            return @ptrCast(@alignCast(self.info.dataPtr()));
        }

        /// Mutable pointer to the typed payload.
        ///
        /// Caller is responsible for ensuring the account is writable
        /// — typically by going through `parseAccountsWith(.{
        /// .writable = true })` upstream.
        pub inline fn write(self: Self) *align(1) T {
            return @ptrCast(@alignCast(self.info.dataPtr()));
        }

        /// Initialize a freshly-created account: writes `value` into
        /// the account data, then (if `T` declares `DISCRIMINATOR`)
        /// overwrites the first 8 bytes with the canonical
        /// discriminator. This way callers can leave the
        /// `discriminator` field of `value` as `undefined` (or any
        /// value); the canonical bytes are always written.
        pub fn initialize(info: AccountInfo, value: T) ProgramError!Self {
            if (info.dataLen() < size) return error.AccountDataTooSmall;
            const ptr: *align(1) T = @ptrCast(@alignCast(info.dataPtr()));
            // If the type has a declared discriminator: rebuild the
            // value with the disc field stamped, then single-store.
            // Measured at −3 CU vs. "store value, then stamp disc over
            // first 8 bytes" because it eliminates the redundant
            // second 8-byte store. Disassembly shows the rebuild does
            // stage through stack, but the rebuild-and-single-store
            // is still cheaper than write-twice on our 56-byte payload.
            if (comptime declared) |want| {
                var v = value;
                const v_disc: *align(1) [DISCRIMINATOR_LEN]u8 =
                    @ptrCast(@alignCast(&v));
                v_disc.* = want;
                ptr.* = v;
            } else {
                ptr.* = value;
            }
            return .{ .info = info };
        }

        /// `has_one` constraint — Anchor's
        /// `#[account(has_one = authority)]` equivalent.
        ///
        /// Asserts that the `field_name` member of the typed state
        /// equals `expected.key().*`. Returns `error.IncorrectAuthority`
        /// on mismatch (or `error.IncorrectProgramId` if you want a
        /// different variant — see `requireHasOneWith`).
        ///
        /// The field type must be `Pubkey`. Field name is comptime,
        /// so the offset is folded into a single load + 32-byte compare
        /// in BPF code.
        ///
        /// ```zig
        /// const vault = try sol.TypedAccount(VaultState).bind(a.vault);
        /// try vault.requireHasOne("authority", a.authority_signer);
        /// ```
        pub inline fn requireHasOne(
            self: Self,
            comptime field_name: []const u8,
            expected: AccountInfo,
        ) ProgramError!void {
            return self.requireHasOneWith(field_name, expected, error.IncorrectAuthority);
        }

        /// Like `requireHasOne` but lets you pick the error variant.
        /// Useful when "authority mismatch" is not the right semantic
        /// for your domain (e.g. `error.InvalidArgument` for a
        /// `delegate` field).
        pub inline fn requireHasOneWith(
            self: Self,
            comptime field_name: []const u8,
            expected: AccountInfo,
            comptime err: anytype,
        ) @TypeOf(err)!void {
            comptime {
                if (!@hasField(T, field_name)) {
                    @compileError("requireHasOne: type " ++ @typeName(T) ++
                        " has no field named `" ++ field_name ++ "`");
                }
                const FieldT = @TypeOf(@field(@as(T, undefined), field_name));
                if (FieldT != @import("pubkey.zig").Pubkey) {
                    @compileError("requireHasOne: field `" ++ field_name ++
                        "` of " ++ @typeName(T) ++
                        " must be a Pubkey, got " ++ @typeName(FieldT));
                }
            }
            const stored = &@field(self.read().*, field_name);
            const pk = @import("pubkey.zig");
            if (!pk.pubkeyEq(stored, expected.key())) return err;
        }

        /// Close this typed account and refund rent to `destination`.
        ///
        /// Anchor's `#[account(close = destination)]` — drains
        /// lamports, zeroes data, shrinks `data_len` to 0, reassigns
        /// to the system program. After `close()` the wrapped
        /// `AccountInfo` is no longer a valid typed view; drop the
        /// `TypedAccount` value immediately.
        ///
        /// Caller MUST ensure this program owns the account (typically
        /// by checking ownership at bind time or relying on
        /// `expect(.{ .owner = ... })` upstream).
        pub inline fn close(
            self: Self,
            destination: AccountInfo,
        ) ProgramError!void {
            return self.info.close(destination);
        }
    };
}

// =============================================================================
// Tests
// =============================================================================

const pubkey_mod = @import("pubkey.zig");
const Pubkey = pubkey_mod.Pubkey;
const Account = account_mod.Account;
const NOT_BORROWED = account_mod.NOT_BORROWED;

// A test type WITHOUT discriminator
const Simple = extern struct {
    counter: u64,
    flag: u8,
    _pad: [7]u8 = .{0} ** 7,
};

// A test type WITH discriminator
const Stateful = extern struct {
    discriminator: [DISCRIMINATOR_LEN]u8,
    counter: u64,
    owner: Pubkey,

    pub const DISCRIMINATOR = discriminator.forAccount("Stateful");
};

fn makeAccount(buf: *[256]u8, key_byte: u8) AccountInfo {
    @memset(buf, 0);
    const acc: *Account = @ptrCast(@alignCast(buf));
    acc.* = .{
        .borrow_state = NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{key_byte} ** 32,
        .owner = .{0} ** 32,
        .lamports = 0,
        .data_len = 256 - @sizeOf(Account),
    };
    return .{ .raw = acc };
}

test "TypedAccount: bind + read on non-discriminator type" {
    var buf: [256]u8 align(8) = undefined;
    const info = makeAccount(&buf, 1);

    // Write a Simple manually into account data
    const writer: *align(1) Simple = @ptrCast(@alignCast(info.dataPtr()));
    writer.* = .{ .counter = 42, .flag = 1 };

    const TA = TypedAccount(Simple);
    const ta = try TA.bind(info);
    try std.testing.expectEqual(@as(u64, 42), ta.read().counter);
    try std.testing.expectEqual(@as(u8, 1), ta.read().flag);

    ta.write().counter += 8;
    try std.testing.expectEqual(@as(u64, 50), ta.read().counter);
}

test "TypedAccount: initialize writes discriminator" {
    var buf: [256]u8 align(8) = undefined;
    const info = makeAccount(&buf, 2);

    const TA = TypedAccount(Stateful);
    const ta = try TA.initialize(info, .{
        .discriminator = undefined,
        .counter = 100,
        .owner = .{7} ** 32,
    });
    try std.testing.expectEqual(@as(u64, 100), ta.read().counter);

    // Discriminator was written
    const want = discriminator.forAccount("Stateful");
    const got_ptr: *align(1) const [DISCRIMINATOR_LEN]u8 =
        @ptrCast(@alignCast(info.dataPtr()));
    try std.testing.expectEqualSlices(u8, &want, got_ptr);
}

test "TypedAccount: bind rejects mismatching discriminator" {
    var buf: [256]u8 align(8) = undefined;
    const info = makeAccount(&buf, 3);

    // Write a wrong discriminator
    const dp = info.dataPtr();
    @memset(dp[0..DISCRIMINATOR_LEN], 0xAB);

    const TA = TypedAccount(Stateful);
    try std.testing.expectError(error.InvalidAccountData, TA.bind(info));
}

test "TypedAccount: bind accepts matching discriminator" {
    var buf: [256]u8 align(8) = undefined;
    const info = makeAccount(&buf, 4);

    // Initialize the account
    const TA = TypedAccount(Stateful);
    _ = try TA.initialize(info, .{
        .discriminator = undefined,
        .counter = 7,
        .owner = .{1} ** 32,
    });

    // Re-bind succeeds
    const ta = try TA.bind(info);
    try std.testing.expectEqual(@as(u64, 7), ta.read().counter);
}

test "TypedAccount: bind enforces minimum size" {
    // The Account header is 88 bytes; allocate a generous buffer
    // but declare a tiny `data_len` to trigger the size check.
    var small_buf: [128]u8 align(8) = undefined;
    @memset(&small_buf, 0);
    const acc: *Account = @ptrCast(@alignCast(&small_buf));
    acc.* = .{
        .borrow_state = NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{4} ** 32,
        .owner = .{0} ** 32,
        .lamports = 0,
        .data_len = 1, // too small for Stateful (sizeof ~= 48)
    };
    const info = AccountInfo{ .raw = acc };

    const TA = TypedAccount(Stateful);
    try std.testing.expectError(error.AccountDataTooSmall, TA.bind(info));
}

test "TypedAccount: has_discriminator metadata" {
    try std.testing.expect(!TypedAccount(Simple).has_discriminator);
    try std.testing.expect(TypedAccount(Stateful).has_discriminator);
}

test "TypedAccount: requireHasOne accepts matching key" {
    var vault_buf: [256]u8 align(8) = undefined;
    var auth_buf: [256]u8 align(8) = undefined;

    const auth_key: Pubkey = .{0xA1} ** 32;
    const auth_info = makeAccount(&auth_buf, 0xA1);

    const vault_info = makeAccount(&vault_buf, 1);

    const TA = TypedAccount(Stateful);
    _ = try TA.initialize(vault_info, .{
        .discriminator = undefined,
        .counter = 0,
        .owner = auth_key,
    });

    const vault = try TA.bind(vault_info);
    try vault.requireHasOne("owner", auth_info);
}

test "TypedAccount: requireHasOne rejects mismatching key" {
    var vault_buf: [256]u8 align(8) = undefined;
    var auth_buf: [256]u8 align(8) = undefined;

    const auth_info = makeAccount(&auth_buf, 0xA1); // key = 0xA1...
    const vault_info = makeAccount(&vault_buf, 1);

    const TA = TypedAccount(Stateful);
    _ = try TA.initialize(vault_info, .{
        .discriminator = undefined,
        .counter = 0,
        .owner = .{0xB2} ** 32, // different from auth.key()
    });

    const vault = try TA.bind(vault_info);
    try std.testing.expectError(
        error.IncorrectAuthority,
        vault.requireHasOne("owner", auth_info),
    );
}
