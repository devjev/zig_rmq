// zig_rmq
// =======
//
// Example code showing how to:
// a) use system libraries written in C in a Zig project
//    (in this case rabbitmq-c), and
// b) consume messages from RabbitMQ.
//

const std = @import("std");
const rmq = @import("zig_rmq");

pub fn main() !void {
    const alloc = std.heap.c_allocator;

    // Connection
    const conn = try rmq.Connection.init(&alloc, "127.0.0.1", 5672, .{
        .vhost = "/",
        .auth = .{
            .plain = .{
                .username = "demo",
                .password = "demo",
            },
        },
    });
    defer conn.deinit();

    // Channel
    const channel = try rmq.Channel.init(&conn, 1);
    defer channel.deinit();

    // Exchange
    const exchange = try rmq.Exchange.declare(
        &alloc,
        &conn,
        &channel,
        "demo_exchange",
        .direct,
        true,
        true,
        false,
        false,
    );
    defer exchange.deinit();

    std.debug.print("rmq_con = {any}\n", .{conn});
    std.debug.print("Channel open, press any key to close connection\n", .{});
    var buf: [1]u8 = undefined;
    const stdin = std.io.getStdIn().reader();
    _ = try stdin.read(buf[0..]);
}
