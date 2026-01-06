const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // MCL option: -Dwith-mcl enables MCL for off-chain BN254 operations
    // - If vendor/mcl/lib/libmcl.a exists, uses it directly
    // - If not, automatically builds MCL (requires clang)
    const with_mcl = b.option(bool, "with-mcl", "Enable MCL library for off-chain BN254 operations") orelse false;

    // Determine if MCL is enabled
    const mcl_enabled = with_mcl;

    // Create build options module to pass MCL availability to source code
    const build_options = b.addOptions();
    build_options.addOption(bool, "mcl_linked", mcl_enabled);

    // Export self as a module
    const solana_mod = b.addModule("solana_program_sdk", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add build options to module
    solana_mod.addOptions("build_options", build_options);

    const base58_dep = b.dependency("base58", .{
        .target = target,
        .optimize = optimize,
    });
    const base58_mod = base58_dep.module("base58");
    solana_mod.addImport("base58", base58_mod);

    // Also export the shared SDK module (no syscall dependencies)
    // This allows consumers to use just the core types without program-specific code
    const solana_sdk_dep = b.dependency("solana_sdk", .{
        .target = target,
        .optimize = optimize,
    });
    _ = b.addModule("solana_sdk", .{
        .root_source_file = solana_sdk_dep.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "base58", .module = base58_mod },
        },
    });

    const lib_unit_tests = b.addTest(.{
        .root_module = solana_mod,
    });

    lib_unit_tests.root_module.addImport("base58", base58_mod);
    lib_unit_tests.root_module.addOptions("build_options", build_options);

    // Handle MCL linking
    if (with_mcl) {
        // Check if libmcl.a already exists
        const mcl_lib_exists = blk: {
            std.fs.cwd().access("vendor/mcl/lib/libmcl.a", .{}) catch break :blk false;
            break :blk true;
        };

        // Only build if libmcl.a doesn't exist
        if (!mcl_lib_exists) {
            const mcl_build = buildMcl(b);
            lib_unit_tests.step.dependOn(&mcl_build.step);
        }

        lib_unit_tests.addObjectFile(b.path("vendor/mcl/lib/libmcl.a"));
        lib_unit_tests.root_module.addIncludePath(b.path("vendor/mcl/include"));
        lib_unit_tests.linkLibCpp();
    }

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Add a separate step to just build MCL
    const mcl_step = b.step("mcl", "Build MCL library");
    mcl_step.dependOn(&buildMcl(b).step);
}

/// Build MCL library using make with Clang + libc++
/// Note: Requires clang-20 or clang to be installed
fn buildMcl(b: *std.Build) *std.Build.Step.Run {
    // Detect clang version - try clang-20 first, fall back to clang
    const cc = detectClang("clang-20", "clang");
    const cxx = detectClangPP("clang++-20", "clang++");

    // Build MCL with Clang + libc++ for Zig compatibility
    // make will skip already-built targets automatically
    const build_cmd = b.addSystemCommand(&.{
        "make",
        "-C",
        "vendor/mcl",
        b.fmt("CXX={s} -stdlib=libc++", .{cxx}),
        b.fmt("CC={s}", .{cc}),
        "MCL_FP_BIT=256",
        "MCL_FR_BIT=256",
        "lib/libmcl.a",
        "-j4",
    });

    return build_cmd;
}

fn detectClang(preferred: []const u8, fallback: []const u8) []const u8 {
    // Check if preferred clang exists
    const result = std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &.{ "which", preferred },
    }) catch return fallback;
    defer std.heap.page_allocator.free(result.stdout);
    defer std.heap.page_allocator.free(result.stderr);
    return if (result.term.Exited == 0) preferred else fallback;
}

fn detectClangPP(preferred: []const u8, fallback: []const u8) []const u8 {
    const result = std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &.{ "which", preferred },
    }) catch return fallback;
    defer std.heap.page_allocator.free(result.stdout);
    defer std.heap.page_allocator.free(result.stderr);
    return if (result.term.Exited == 0) preferred else fallback;
}

// General helper function to do all the tricky build steps, by adding the
// solana-sdk module, adding the BPF link script
pub fn buildProgram(b: *std.Build, program: *std.Build.Step.Compile, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const solana_dep = b.dependency("solana_program_sdk", .{
        .target = target,
        .optimize = optimize,
    });
    const solana_mod = solana_dep.module("solana_program_sdk");
    program.root_module.addImport("solana_program_sdk", solana_mod);
    linkSolanaProgram(b, program);
    return solana_mod;
}

pub const sbf_target: std.Target.Query = .{
    .cpu_arch = .sbf,
    .os_tag = .solana,
};

pub const sbfv2_target: std.Target.Query = .{
    .cpu_arch = .sbf,
    .cpu_model = .{
        .explicit = &std.Target.sbf.cpu.sbfv2,
    },
    .os_tag = .solana,
    .cpu_features_add = std.Target.sbf.cpu.sbfv2.features,
};

pub const bpf_target: std.Target.Query = .{
    .cpu_arch = .bpfel,
    .os_tag = .freestanding,
    .cpu_features_add = std.Target.bpf.featureSet(&.{.solana}),
};

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
    lib.stack_size = 4096;
    lib.link_z_notext = true;
    lib.root_module.pic = true;
    lib.root_module.strip = true;
    lib.entry = .{ .symbol_name = "entrypoint" };
}
