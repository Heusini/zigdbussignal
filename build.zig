const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });
    const lib = b.addLibrary(.{
        .name = "zigdbussignal",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/dbus.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    lib.linkLibC();
    lib.linkSystemLibrary("dbus-1");
    b.installArtifact(lib);
    const module = b.addModule("dbussignal", .{
        .root_source_file = b.path("src/dbus.zig"),
        .target = target,
        .optimize = optimize,
    });

    module.linkSystemLibrary("c", .{});
    module.linkSystemLibrary("dbus-1", .{});

    const my_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    my_tests.root_module.addImport("dbussignal", module);

    const run_exe_unit_tests = b.addRunArtifact(my_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
