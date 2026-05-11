const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Export self as a module
    const solana_mod = b.addModule("solana_program_sdk", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib_unit_tests = b.addTest(.{
        .root_module = solana_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Examples step (only works with solana-zig fork)
    if (has_sbf_target) {
        const examples_step = b.step("examples", "Build example programs");

        const token_dispatch = buildProgram(b, .{
            .name = "token_dispatch",
            .root_source_file = b.path("examples/token_dispatch.zig"),
        });
        examples_step.dependOn(token_dispatch.step);
    }
}

pub const LinkedProgram = struct {
    name: []const u8,
    module: *std.Build.Module,
    so: std.Build.LazyPath,
    step: *std.Build.Step,
};

// ---------------------------------------------------------------------
// Target query: sbf-solana-none with SBPF v2 features.
//
// Requires the solana-zig-bootstrap fork (solana-v1.53.0 or later)
// because stock Zig 0.16 does not know the `.sbf` CPU arch.
//
// Download: https://github.com/joncinque/solana-zig-bootstrap/releases
// ---------------------------------------------------------------------

pub const has_sbf_target = @hasField(std.Target.Cpu.Arch, "sbf");

pub fn sbfTarget() std.Target.Query {
    return .{
        .cpu_arch = .sbf,
        .os_tag = .solana,
        .cpu_model = .{ .explicit = &std.Target.sbf.cpu.v2 },
    };
}

// ---------------------------------------------------------------------
// buildProgram — primary path.
//
// One call produces a deployable `.so` directly. Expects the running
// Zig compiler to be the solana-zig fork (known to `std.Target.sbf`).
// ---------------------------------------------------------------------

pub const BuildProgramOptions = struct {
    name: []const u8,
    root_source_file: std.Build.LazyPath,
    optimize: std.builtin.OptimizeMode = .ReleaseFast,
};

pub fn buildProgram(b: *std.Build, options: BuildProgramOptions) LinkedProgram {
    if (!has_sbf_target) {
        std.log.err("buildProgram requires the solana-zig fork. Download from https://github.com/joncinque/solana-zig-bootstrap/releases", .{});
        std.process.exit(1);
    }
    const target = b.resolveTargetQuery(sbfTarget());
    const optimize = options.optimize;

    // Use self as module (not a dependency — this IS the SDK)
    const solana_mod = b.addModule("solana_program_sdk", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const program_mod = b.createModule(.{
        .root_source_file = options.root_source_file,
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "solana_program_sdk", .module = solana_mod },
        },
    });
    program_mod.pic = true;
    program_mod.strip = true;

    const program = b.addLibrary(.{
        .name = options.name,
        .linkage = .dynamic,
        .root_module = program_mod,
    });
    program.entry = .{ .symbol_name = "entrypoint" };
    program.stack_size = 4096;
    program.link_z_notext = true;
    linkSolanaProgram(b, program);

    const so = program.getEmittedBin();
    const install = b.addInstallLibFile(so, b.fmt("{s}.so", .{options.name}));
    b.getInstallStep().dependOn(&install.step);

    return .{
        .name = options.name,
        .module = solana_mod,
        .so = so,
        .step = &install.step,
    };
}

pub fn linkSolanaProgram(b: *std.Build, lib: *std.Build.Step.Compile) void {
    const write_file_step = b.addWriteFiles();
    const linker_script = write_file_step.add("bpf.ld",
        \\PHDRS
        \\{
        \\text PT_LOAD  ;
        \\rodata PT_LOAD ;
        \\data PT_LOAD ;
        \\dynamic PT_DYNAMIC ;
        \\}
        \\
        \\SECTIONS
        \\{
        \\. = SIZEOF_HEADERS;
        \\.text : { *(.text*) } :text
        \\.rodata : { *(.rodata*) } :rodata
        \\.data.rel.ro : { *(.data.rel.ro*) } :rodata
        \\.dynamic : { *(.dynamic) } :dynamic
        \\.dynsym : { *(.dynsym) } :data
        \\.dynstr : { *(.dynstr) } :data
        \\.rel.dyn : { *(.rel.dyn) } :data
        \\/DISCARD/ : {
        \\*(.eh_frame*)
        \\*(.gnu.hash*)
        \\*(.hash*)
        \\}
        \\}
    );
    lib.step.dependOn(&write_file_step.step);
    lib.setLinkerScript(linker_script);
}
