//! Hello World — the smallest possible Solana program in Zig.
//!
//! Demonstrates:
//!   - `lazyEntrypointRaw` — u64-returning entrypoint, zero error-union
//!     overhead. Cheapest possible shape (~5 CU lower than the
//!     ProgramResult version).
//!   - `sol.log.log` — write a string to the program log.
//!
//! Measured cost: ~106 CU end-to-end (program-test). Most of that is
//! the runtime's invoke / return overhead; the program body itself is
//! ~5 CU.
//!
//! Not suitable as a starting template for non-trivial programs —
//! `lazyEntrypoint` (ProgramResult shape) reads more naturally once
//! you need error handling.

const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

fn process(_: *sol.entrypoint.InstructionContext) u64 {
    sol.log.log("Hello, Solana!");
    return sol.SUCCESS;
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypointRaw(process)(input);
}
