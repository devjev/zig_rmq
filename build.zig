const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "zig_rmq",
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(b.path("libs/librabbitmq/include"));
    lib.addLibraryPath(b.path("libs/librabbitmq/lib"));
    lib.addObjectFile(b.path("libs/librabbitmq/lib/librabbitmq.a"));
    b.installArtifact(lib);

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/lib.zig"),
    });
    lib_mod.addIncludePath(b.path("libs/librabbitmq/include"));
    lib_mod.addLibraryPath(b.path("libs/librabbitmq/lib"));
    lib_mod.addObjectFile(b.path("libs/librabbitmq/lib/librabbitmq.a"));

    const consumer_exe = b.addExecutable(.{
        .name = "queue_consumer",
        .root_source_file = b.path("src/queue_consumer.zig"),
        .target = target,
        .optimize = optimize,
    });
    consumer_exe.root_module.addImport("zig_rmq", lib_mod);
    b.installArtifact(consumer_exe);
}
