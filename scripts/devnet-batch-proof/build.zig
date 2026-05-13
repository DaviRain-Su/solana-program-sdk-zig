const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseFast;
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .sbf,
        .os_tag = .solana,
        .cpu_model = .{ .explicit = &std.Target.sbf.cpu.v2 },
    });

    const sol_mod = b.createModule(.{
        .root_source_file = b.path("../../src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const spl_token_mod = b.createModule(.{
        .root_source_file = b.path("../../packages/spl-token/src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "solana_program_sdk", .module = sol_mod },
        },
    });
    const program_mod = b.createModule(.{
        .root_source_file = b.path("../../examples/batch_proof.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "solana_program_sdk", .module = sol_mod },
            .{ .name = "spl_token", .module = spl_token_mod },
        },
    });
    program_mod.pic = true;
    program_mod.strip = true;

    const program = b.addLibrary(.{
        .name = "batch_proof",
        .linkage = .dynamic,
        .root_module = program_mod,
    });
    program.entry = .{ .symbol_name = "entrypoint" };
    program.stack_size = 4096;
    program.link_z_notext = true;
    linkSolanaProgram(b, program);

    const so = program.getEmittedBin();
    const install = b.addInstallLibFile(so, "batch_proof.so");
    b.getInstallStep().dependOn(&install.step);
}

fn linkSolanaProgram(b: *std.Build, lib: *std.Build.Step.Compile) void {
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
