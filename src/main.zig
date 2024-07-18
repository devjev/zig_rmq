const std = @import("std");

// rabbitmq-c declarations (minimal) =========================================
pub const amqp_connection_state_struct = opaque {};
pub const amqp_connection_state_t = ?*amqp_connection_state_struct;
pub const amqp_socket_t = opaque {};

extern fn amqp_tcp_socket_new(state: amqp_connection_state_t) ?*amqp_socket_t;
extern fn amqp_new_connection() amqp_connection_state_t;
extern fn amqp_socket_open(self: ?*amqp_socket_t, host: [*c]const u8, port: c_int) c_int;

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
}
