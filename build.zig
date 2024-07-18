const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zig_rmq",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Include rabbitmq-c system library
    exe.linkLibC();
    exe.linkSystemLibrary("librabbitmq");

    b.installArtifact(exe);
}
