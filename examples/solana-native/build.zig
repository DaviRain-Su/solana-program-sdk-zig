const std = @import("std");

pub fn build(b: *std.Build) void {
    // Solana SBF 目标
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .sbf,
        .os_tag = .freestanding,
        .abi = .none,
    });
    
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });
    
    // 创建 Solana 程序
    const program = b.addSharedLibrary(.{
        .name = "solana_native",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    // 添加 SDK 依赖
    const sdk = b.dependency("solana_program_sdk_zig", .{
        .target = target,
        .optimize = optimize,
    });
    program.root_module.addImport("solana", sdk.module("solana_program_sdk_zig"));
    
    // 设置程序特定的选项
    program.entry = .{ .symbol_name = "entrypoint" };
    program.rdynamic = true;
    
    // 安装
    b.installArtifact(program);
    
    // 创建部署步骤
    const deploy_cmd = b.addSystemCommand(&.{
        "solana",
        "program",
        "deploy",
        "--program-id",
        "program-keypair.json",
    });
    deploy_cmd.addArtifactArg(program);
    
    const deploy_step = b.step("deploy", "Deploy the program to Solana");
    deploy_step.dependOn(&deploy_cmd.step);
}