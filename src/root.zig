/// Solana Program SDK for Zig
/// 
/// This SDK provides a Zig interface for developing Solana programs.
pub const solana = @import("solana/lib.zig");

test {
    _ = @import("solana/lib.zig");
}
