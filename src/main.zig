const std = @import("std");

pub fn main() !void {
    const dir = try std.fs.cwd().openDir("src/examples", .{ .iterate = true });
    var iterator = dir.iterate();
    while (try iterator.next()) |thing| {
        const name = thing.name;
        const ext = name[(name.len - 4)..(name.len)];
        const kind = thing.kind;
        if (std.mem.eql(u8, ext, ".zig") and kind == std.fs.File.Kind.file) {
            std.debug.print("{s} => {s}, {any}\n", .{ name, ext, kind });
        }
    }
}
