const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //=======EXE========
    const exe = b.addExecutable(.{
        .name = "gears",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    //=======UNIT TEST EXE========
    const exe_test = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    //================ADD RATIOS====================
    const options = b.addOptions();
    const ratios_single = @import("src/gear.zig").processAllGears();
    options.addOption([]const u8, "ratios", &std.mem.toBytes(ratios_single));
    exe.root_module.addImport("options", options.createModule());

    //================ADD DVUI======================
    const dvui = b.dependency("dvui", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("dvui", dvui.module("dvui_raylib"));
    exe_test.root_module.addImport("dvui", dvui.module("dvui_raylib"));

    //================ADD RAYLIBBACKEND======================
    exe.root_module.addImport("RaylibBackend", dvui.module("RaylibBackend"));
    exe_test.root_module.addImport("RaylibBackend", dvui.module("RaylibBackend"));

    //=======RUN STEPS========
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const run_exe_test = b.addRunArtifact(exe_test);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_test.step);
}
