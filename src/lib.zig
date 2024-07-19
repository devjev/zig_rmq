const std = @import("std");

// @cImport is just like translate-c, but works transparently in your source code,
// including if you link in a system library (like I am doing here), as it
// automatically adds include and lib paths!
const c = @cImport({
    @cInclude("rabbitmq-c/amqp.h");
    @cInclude("rabbitmq-c/tcp_socket.h");
});

pub const RmqError = error{
    SocketError,
};

// I am going to wrap all the details necessary for a connecting and logging in
// with RabbitMQ in a single struct.
pub const RmqConnection = struct {
    alloc: *const std.mem.Allocator,
    conn: c.amqp_connection_state_t,
    socket: ?*c.amqp_socket_t,
    hostname: [:0]const u8,
    port: c_int,

    pub fn init(
        alloc: *const std.mem.Allocator,
        hostname: []const u8,
        port: i32,
    ) !RmqConnection {
        const hostname_cstr = try alloc.dupeZ(u8, hostname); // TODO handle the error?
        const port_cint: c_int = @intCast(port);

        const conn = c.amqp_new_connection();
        const socket = c.amqp_tcp_socket_new(conn);

        if (0 != c.amqp_socket_open(socket, hostname_cstr.ptr, port_cint)) {
            return RmqError.SocketError;
        }

        return RmqConnection{
            .alloc = alloc,
            .conn = conn,
            .socket = socket,
            .hostname = hostname_cstr,
            .port = port_cint,
        };
    }

    pub fn deinit(self: *@This()) void {
        // TODO deal with possible failure here
        _ = c.amqp_connection_close(self.conn, c.AMQP_REPLY_SUCCESS);
        _ = c.amqp_destroy_connection(self.conn);
        self.alloc.free(self.hostname);
    }
};
