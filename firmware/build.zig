// build.zig is a normal Zig program. `zig build <step>` compiles and runs it,
// and this `build` function describes a graph of steps (compile, run, test).
// Nothing is built until you ask for a step that depends on it.
const std = @import("std");

pub fn build(b: *std.Build) void {
    // `-Dtarget=...` picks the CPU/OS. The default is your Mac (aarch64-macos).
    // Later we'll add a microcontroller target here.
    const target = b.standardTargetOptions(.{});
    // `-Doptimize=Debug|ReleaseSafe|ReleaseFast|ReleaseSmall` (default: Debug)
    const optimize = b.standardOptimizeOption(.{});

    // ── core: the hardware-independent logic (decoding, gear calc, smoothing).
    // It's a module so that every program (simulator now, firmware later)
    // can `@import("core")`. Rule: core never imports LVGL or SDL.
    const core = b.addModule("core", .{
        .root_source_file = b.path("src/core/core.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ── gauge-sim: the desktop program you run on the Mac.
    const sim = b.addExecutable(.{
        .name = "gauge-sim",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "core", .module = core }},
        }),
    });
    // "install" = copy the built program into zig-out/bin/
    b.installArtifact(sim);

    // ── `zig build run`: build, install, then run gauge-sim.
    // Anything after `--` is passed through: `zig build run -- --source=sweep`
    const run = b.addRunArtifact(sim);
    run.step.dependOn(b.getInstallStep());
    run.addPassthruArgs();
    b.step("run", "Run the desktop gauge simulator").dependOn(&run.step);

    // ── `zig build test`: compile every `test "..." {}` block reachable from
    // each module's root file into a test program, then run it.
    const test_step = b.step("test", "Run all tests");
    const core_tests = b.addTest(.{ .root_module = core });
    test_step.dependOn(&b.addRunArtifact(core_tests).step);
    const sim_tests = b.addTest(.{ .root_module = sim.root_module });
    test_step.dependOn(&b.addRunArtifact(sim_tests).step);
}
