const std = @import("std");

pub fn build(b: *std.Build) void {
    // Use sbf target with freestanding OS
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .sbf,
        .os_tag = .freestanding,
    });
    
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });

    // Create the program
    const program = b.addSharedLibrary(.{
        .name = "hello_world",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add SDK dependency
    const sdk = b.dependency("solana_program_sdk_zig", .{
        .target = target,
        .optimize = optimize,
    });
    program.root_module.addImport("solana", sdk.module("solana_program_sdk_zig_lib"));

    // Link configuration
    linkSolanaProgram(b, program);

    // Install the program
    b.installArtifact(program);

    // Create deploy step
    const deploy_cmd = b.addSystemCommand(&.{
        "solana",
        "program",
        "deploy",
        "--program-id",
        "hello-world-keypair.json",
    });
    deploy_cmd.addArtifactArg(program);

    const deploy_step = b.step("deploy", "Deploy the program to Solana");
    deploy_step.dependOn(&deploy_cmd.step);
}

// Link Solana program with proper configuration
fn linkSolanaProgram(b: *std.Build, lib: *std.Build.Step.Compile) void {
    // Add linker script
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
    lib.setLinkerScript(linker_script);
    
    // Critical flags from joncinque's implementation
    lib.stack_size = 4096;
    lib.link_z_notext = true;
    lib.root_module.pic = true;
    lib.root_module.strip = true;
    lib.linker_allow_shlib_undefined = true;
    lib.entry = .{ .symbol_name = "entrypoint" };
    lib.rdynamic = true;
}