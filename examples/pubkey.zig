//! Pubkey — trivial no-account program used as a baseline.
//!
//! Logs a single line and returns success. The companion test
//! (`program-test/tests/pubkey.rs`) uses it to validate the
//! end-to-end build → load → invoke pipeline with the smallest
//! possible payload.
//!
//! For a more idiomatic minimal example, see `examples/hello.zig`,
//! which uses the cheaper `lazyEntrypointRaw` shape.

const sol = @import("solana_program_sdk");

pub const panic = sol.panic.Panic;

fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
    _ = ctx;
    sol.log.log("Hello zig program");
}

export fn entrypoint(input: [*]u8) u64 {
    return sol.entrypoint.lazyEntrypoint(process)(input);
}
