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

    const base58_dep = b.dependency("base58", .{
        .target = target,
        .optimize = optimize,
    });
    const base58_mod = base58_dep.module("base58");
    solana_mod.addImport("base58", base58_mod);

    const lib_unit_tests = b.addTest(.{
        .root_module = solana_mod,
    });

    lib_unit_tests.root_module.addImport("base58", base58_mod);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

pub const LinkedProgram = struct {
    name: []const u8,
    module: *std.Build.Module,
    so: std.Build.LazyPath,
    step: *std.Build.Step,
};

// ---------------------------------------------------------------------
// Target query: sbf-solana-none with SBPF v2 features (fork Zig path).
//
// Requires the `solana-zig-bootstrap` Zig fork (`solana-1.52-zig0.16`
// branch or later) because stock Zig 0.16 does not know the `.sbf`
// CPU arch. If you are on stock Zig 0.16, use `bpf_target` +
// `buildProgramElf2sbpf` instead.
// ---------------------------------------------------------------------

pub const sbf_target: std.Target.Query = .{
    .cpu_arch = .sbf,
    .os_tag = .solana,
    .cpu_model = .{ .explicit = &std.Target.sbf.cpu.v2 },
};

pub const bpf_target: std.Target.Query = .{
    .cpu_arch = .bpfel,
    .cpu_model = .{ .explicit = &std.Target.bpf.cpu.v2 },
    .os_tag = .freestanding,
};

// ---------------------------------------------------------------------
// buildProgram — primary (fork Zig) path.
//
// One call produces a deployable `.so` directly. Expects the running
// Zig compiler to be the solana-zig fork (known to `std.Target.sbf`).
// If you need the elf2sbpf fallback path for stock Zig, use
// `buildProgramElf2sbpf` below instead.
// ---------------------------------------------------------------------

pub const BuildProgramOptions = struct {
    name: []const u8,
    root_source_file: std.Build.LazyPath,
    optimize: std.builtin.OptimizeMode = .ReleaseFast,
};

pub fn buildProgram(b: *std.Build, options: BuildProgramOptions) LinkedProgram {
    const target = b.resolveTargetQuery(sbf_target);
    const optimize = options.optimize;

    const solana_dep = b.dependency("solana_program_sdk", .{
        .target = target,
        .optimize = optimize,
    });
    const solana_mod = solana_dep.module("solana_program_sdk");

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

// ---------------------------------------------------------------------
// buildProgramElf2sbpf — fallback (stock Zig) path.
//
// For users running stock Zig 0.16 without the solana-zig fork. Emits
// LLVM bitcode, then uses `zig cc -target bpfel` to produce a BPF
// object file, then invokes `elf2sbpf` to convert it to a Solana .so.
// CU numbers are worse than `buildProgram` — stock `bpfel` codegen
// expands unaligned u64 loads/stores to byte-wise chains that the
// solana-zig fork avoids. For CU-critical workloads, use the fork
// path via `buildProgram` above.
// ---------------------------------------------------------------------

fn fileExists(path: []const u8) bool {
    std.Io.Dir.accessAbsolute(std.Options.debug_io, path, .{}) catch return false;
    return true;
}

pub fn resolveElf2sbpfBin(b: *std.Build, cli_override: ?[]const u8) []const u8 {
    if (cli_override) |path| return path;

    if (b.graph.environ_map.get("ELF2SBPF_BIN")) |path| return path;

    const local_candidates = [_][]const u8{
        ".tools/bin/elf2sbpf",
        ".tools/elf2sbpf/bin/elf2sbpf",
        ".tools/elf2sbpf/zig-out/bin/elf2sbpf",
    };
    inline for (local_candidates) |candidate| {
        const abs = b.pathFromRoot(candidate);
        if (fileExists(abs)) return abs;
    }

    return b.findProgram(&.{"elf2sbpf"}, &.{}) catch @panic(
        "elf2sbpf not found. Run ./scripts/bootstrap.sh, set ELF2SBPF_BIN, or pass -Delf2sbpf-bin=/absolute/path/to/elf2sbpf.",
    );
}

pub const BuildProgramElf2SbpfOptions = struct {
    name: []const u8,
    root_source_file: std.Build.LazyPath,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    elf2sbpf_bin: ?[]const u8 = null,
};

pub fn buildProgramElf2sbpf(b: *std.Build, options: BuildProgramElf2SbpfOptions) LinkedProgram {
    const solana_dep = b.dependency("solana_program_sdk", .{
        .target = options.target,
        .optimize = options.optimize,
    });
    const solana_mod = solana_dep.module("solana_program_sdk");

    const program_mod = b.createModule(.{
        .root_source_file = options.root_source_file,
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "solana_program_sdk", .module = solana_mod },
        },
    });
    program_mod.pic = true;
    program_mod.strip = true;

    const bitcode_obj = b.addObject(.{
        .name = b.fmt("{s}-bitcode", .{options.name}),
        .root_module = program_mod,
    });
    const bitcode = bitcode_obj.getEmittedLlvmBc();

    const zig_cc = b.addSystemCommand(&.{
        b.graph.zig_exe,
        "cc",
        "-target",
        "bpfel-freestanding",
        "-mcpu=v2",
        "-O2",
        "-mllvm",
        "-bpf-stack-size=4096",
        "-c",
    });
    zig_cc.addFileArg(bitcode);
    zig_cc.addArg("-o");
    const obj = zig_cc.addOutputFileArg(b.fmt("{s}.o", .{options.name}));

    const elf2sbpf_bin = resolveElf2sbpfBin(b, options.elf2sbpf_bin);
    const link_program = b.addSystemCommand(&.{elf2sbpf_bin});
    link_program.addFileArg(obj);
    const so = link_program.addOutputFileArg(b.fmt("{s}.so", .{options.name}));

    b.getInstallStep().dependOn(&b.addInstallLibFile(so, b.fmt("{s}.so", .{options.name})).step);

    return .{
        .name = options.name,
        .module = solana_mod,
        .so = so,
        .step = &link_program.step,
    };
}
