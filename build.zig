const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Examples
    const consumer_exe = b.addExecutable(.{
        .name = "queue_consumer",
        .root_source_file = b.path("src/queue_consumer.zig"),
        .target = target,
        .optimize = optimize,
    });
    consumer_exe.linkLibC();
    consumer_exe.linkSystemLibrary("librabbitmq");
    b.installArtifact(consumer_exe);
    const run_exe = b.addRunArtifact(consumer_exe);
    const run_step = b.step(
        "run-consumer",
        "Run the queue consumer example",
    );
    run_step.dependOn(&run_exe.step);
}
