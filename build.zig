const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const types = b.createModule(.{
        .root_source_file = b.path("src/lib/types/root.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
    });

    const adapter = b.createModule(.{
        .root_source_file = b.path("src/lib/adapter/Adapter.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
        .link_libc = true,
    });

    types.addImport("usb-adapter", adapter);

    switch (target.result.os.tag) {
        .windows => {
            adapter.addImport("usb-types", types);
            adapter.linkSystemLibrary("SetupApi", .{});
            adapter.linkSystemLibrary("WinUsb", .{});
        },
        .linux => {
            adapter.addImport("usb-types", types);
            adapter.linkSystemLibrary("libsystemd", .{});
        },
        else => @panic("link system/kernel libraries for adapter"),
    }

    const module = b.createModule(.{
        .root_source_file = b.path("src/lib/root.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
    });
    module.addImport("usb-types", types);
    module.addImport("usb-adapter", adapter);

    const example_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
    });
    example_module.addImport("zig-usb", module);

    const exe = b.addExecutable(.{
        .name = "zig-usb-example",
        .root_module = example_module,
    });
    exe.root_module.addImport("zig-usb", module);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
