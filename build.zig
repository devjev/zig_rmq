const std = @import("std");

// OLD ATTEMPT, PAY NO ATTENTION.
//
// fn build_example(
//     b: *std.Build,
//     name: []const u8,
//     path: []const u8,
//     command: []const u8,
//     desc: []const u8,
//     target: std.Build.ResolvedTarget,
//     optimize: std.builtin.OptimizeMode,
// ) *std.Build.Step.Compile {
//     const exe = b.addExecutable(.{
//         .name = name,
//         .root_source_file = b.path(path),
//         .target = target,
//         .optimize = optimize,
//     });
//     exe.linkLibC();
//     exe.linkSystemLibrary("librabbitmq");
//     b.installArtifact(exe);
//     const run_exe = b.addRunArtifact(exe);
//     const run_step = b.step(command, desc);
//     run_step.dependOn(&run_exe.step);
// }
//
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Examples
    const lib = b.createModule(.{
        .root_source_file = b.path("src/lib.zig"),
    });
    const consumer_exe = b.addExecutable(.{
        .name = "queue_consumer",
        .root_source_file = b.path("src/examples/queue_consumer.zig"),
        .target = target,
        .optimize = optimize,
    });
    consumer_exe.linkLibC();
    consumer_exe.linkSystemLibrary("librabbitmq");
    consumer_exe.root_module.addImport("lib", lib);

    b.installArtifact(consumer_exe);

    const run_exe = b.addRunArtifact(consumer_exe);
    const run_step = b.step("run-consumer", "Run the queue consumer example");

    run_step.dependOn(&run_exe.step);
}
