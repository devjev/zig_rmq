const std = @import("std");
const c = @cImport({
    @cInclude("rabbitmq-c/amqp.h");
    @cInclude("rabbitmq-c/tcp_socket.h");
});

const RmqError = error{
    SocketError,
};

const RmqConnection = struct {
    conn: c.amqp_connection_state_t,
    socket: ?*c.amqp_socket_t,
};

fn new_rmq_connection(hostname: []const u8, port: i32) RmqConnection {
    const conn = c.amqp_new_connection();
    const socket = c.amqp_tcp_socket_new(conn);

    const port_c: c_int = @intCast(port);

    return RmqConnection{
        .conn = conn,
        .socket = socket,
    };
}

fn close_rmq_connection(rmq_conn: *const RmqConnection) void {
    const conn = rmq_conn.conn;
    _ = c.amqp_destroy_connection(conn);
}

pub fn main() !void {
    const conn = new_rmq_connection();
    defer close_rmq_connection(&conn);
}
