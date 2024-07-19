// zig_rmq
// =======
//
// Example code showing how to:
// a) use system libraries written in C in a Zig project (in this case rabbitmq-c), and
// b) consume messages from RabbitMQ.
//

const std = @import("std");
const lib = @import("lib");

pub fn main() !void {
    const alloc = std.heap.c_allocator;
    var rmq_conn = try lib.RmqConnection.init(&alloc, "localhost", 5762);
    defer rmq_conn.deinit();

    std.debug.print("rmq_con = {any}", .{rmq_conn});
}
