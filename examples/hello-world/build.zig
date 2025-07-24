const std = @import("std");

pub fn build(b: *std.Build) void {
    // BPF 目标配置
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .sbf,
        .os_tag = .freestanding,
    });
    
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSmall,
    });
    
    // 创建 BPF 程序
    const program = b.addSharedLibrary(.{
        .name = "hello_world",
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    // 添加 SDK 依赖
    const sdk = b.dependency("solana_program_sdk_zig", .{
        .target = target,
        .optimize = optimize,
    });
    program.root_module.addImport("solana_program_sdk_zig_lib", sdk.module("solana_program_sdk_zig"));
    
    // 设置 BPF 特定的编译选项
    program.entry = .{ .symbol_name = "entrypoint" };
    program.rdynamic = true;
    
    // 安装编译产物
    b.installArtifact(program);
    
    // 创建部署步骤
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
    
    // 创建测试步骤（本地测试）
    const test_exe = b.addExecutable(.{
        .name = "test_hello_world",
        .root_source_file = b.path("test.zig"),
        .target = b.host,
        .optimize = optimize,
    });
    
    const sdk_host = b.dependency("solana_program_sdk_zig", .{
        .target = b.host,
        .optimize = optimize,
    });
    test_exe.root_module.addImport("solana_program_sdk_zig_lib", sdk_host.module("solana_program_sdk_zig"));
    
    const run_test = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run local tests");
    test_step.dependOn(&run_test.step);
}