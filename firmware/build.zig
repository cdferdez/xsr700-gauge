const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core = b.addModule("core", .{
        .root_source_file = b.path("src/core/core.zig"),
        .target = target,
        .optimize = optimize,
    });
    core.addAnonymousImport("kline_vectors", .{ .root_source_file = b.path("testdata/kline_vectors.json") });

    const sim = b.addExecutable(.{
        .name = "gauge-sim",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "core", .module = core }},
        }),
    });
    b.installArtifact(sim);

    const run = b.addRunArtifact(sim);
    run.step.dependOn(b.getInstallStep());
    run.addPassthruArgs();
    b.step("run", "Run the desktop gauge simulator").dependOn(&run.step);

    const test_step = b.step("test", "Run all tests");
    const core_tests = b.addTest(.{ .root_module = core });
    test_step.dependOn(&b.addRunArtifact(core_tests).step);
    const sim_tests = b.addTest(.{ .root_module = sim.root_module });
    test_step.dependOn(&b.addRunArtifact(sim_tests).step);

    const gen = b.addSystemCommand(&.{"python3"});
    gen.addFileArg(b.path("../tools/gen_vectors.py"));
    gen.addArg("testdata/kline_vectors.json");
    gen.setCwd(b.path("."));
    b.step("vectors", "Regenerate testdata/ from tools/gen_vectors.py").dependOn(&gen.step);
}
