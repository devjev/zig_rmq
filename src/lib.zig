const std = @import("std");
const c = @cImport({
    @cInclude("rabbitmq-c/amqp.h");
    @cInclude("rabbitmq-c/tcp_socket.h");
});

// Errors ====================================================================

pub const AppError = error{
    socket_err,
    channel_open_err,
};

pub const LibRabbitMqError = error{
    no_memory,
    bad_amqp_data,
    unknown_class,
    unknown_method,
    host_not_resolved,
    incompatible_amqp_version,
    conn_closed,
    bad_url,
    socket_err,
    invalid_param,
    table_too_big,
    wrong_method,
    timeout,
    timer_failure,
    heartbeat_timeout,
    unexpected_state,
    socket_closed,
    socket_in_use,
    broker_unsupported_sasl_method,
    unsupported,
    tcp_error,
    tcp_socketlib_init_err,
    ssl_err,
    ssl_host_verify_failed,
    ssl_peer_verify_err,
    ssl_conn_err,
    ssl_set_engine_err,
    ssl_unimplemented,
};

pub const ServerError = error{};

// Login params ==============================================================

pub const ParamMax = enum { auto, max };

pub const ChannelMax = union(ParamMax) { auto: void, max: i32 };
pub const FrameMax = union(ParamMax) { auto: void, max: i32 };

pub const HeartbeatTag = enum { off, seconds };
pub const Heartbeat = union(HeartbeatTag) { off: void, seconds: i32 };

pub const SaslMethodTag = enum { plain, external };
pub const SaslPlainParams = struct {
    username: []const u8,
    password: []const u8,
};
pub const SaslMethod = union(SaslMethodTag) {
    plain: SaslPlainParams,
    external: void, // TODO Implement this
};

pub const LoginParams = struct {
    vhost: []const u8,
    auth: SaslMethod,
    channel_max: ChannelMax = .auto,
    frame_max: FrameMax = .auto,
    heartbeat: Heartbeat = .off,

    pub fn get_channel_max(self: *const @This()) i32 {
        switch (self.channel_max) {
            .max => |m| return m,
            .auto => return 0,
        }
    }

    pub fn get_frame_max(self: *const @This()) i32 {
        switch (self.frame_max) {
            .max => |m| return m,
            .auto => return 0,
        }
    }

    pub fn get_heartbeat(self: *const @This()) i32 {
        switch (self.heartbeat) {
            .seconds => |s| return s,
            .off => return 0,
        }
    }
};

// Connection ================================================================

pub const Connection = struct {
    alloc: *const std.mem.Allocator,
    conn: c.amqp_connection_state_t,
    socket: ?*c.amqp_socket_t,
    hostname: [:0]const u8,
    port: c_int,
    vhost: [:0]const u8,
    channel_max: c_int,
    frame_max: c_int,

    pub fn init(
        alloc: *const std.mem.Allocator,
        hostname: []const u8,
        port: i32,
        login_params: LoginParams,
    ) !Connection {
        const hostname_cstr = try alloc.dupeZ(u8, hostname); // TODO handle the error?
        const vhost_cstr = try alloc.dupeZ(u8, login_params.vhost);
        const port_cint: c_int = @intCast(port);
        const channel_max_cint: c_int = @intCast(login_params.get_channel_max());
        const frame_max_cint: c_int = @intCast(login_params.get_frame_max());
        const heartbeat: c_int = @intCast(login_params.get_heartbeat());

        const conn = c.amqp_new_connection();

        const socket = c.amqp_tcp_socket_new(conn);
        const socket_open_status = c.amqp_socket_open(socket, hostname_cstr.ptr, port_cint);
        _ = switch (_handle_lib_status(socket_open_status)) {
            .err => |err| return err.err_val,
            .ok => void,
            .no_reply => unreachable,
        };

        switch (login_params.auth) {
            .plain => |auth_params| {
                const username_cstr = try alloc.dupeZ(u8, auth_params.username);
                defer alloc.free(username_cstr);
                const password_cstr = try alloc.dupeZ(u8, auth_params.password);
                defer alloc.free(password_cstr);

                _ = c.amqp_login(
                    conn,
                    vhost_cstr,
                    channel_max_cint,
                    frame_max_cint,
                    heartbeat,
                    c.AMQP_SASL_METHOD_PLAIN,
                    username_cstr.ptr,
                    password_cstr.ptr,
                );
            },
            else => {
                @panic("External authentication method not implemented yet");
            },
        }

        return Connection{
            .alloc = alloc,
            .conn = conn,
            .socket = socket,
            .hostname = hostname_cstr,
            .port = port_cint,
            .vhost = vhost_cstr,
            .channel_max = channel_max_cint,
            .frame_max = frame_max_cint,
        };
    }

    pub fn deinit(self: *const @This()) void {
        // TODO deal with possible failure here
        _ = c.amqp_connection_close(self.conn, c.AMQP_REPLY_SUCCESS);
        _ = c.amqp_destroy_connection(self.conn);
        self.alloc.free(self.hostname);
    }
};

// Channel ===================================================================

pub const Channel = struct {
    conn: *const Connection,
    channel: u16,

    pub fn init(conn: *const Connection, channel: u16) !Channel {
        if (0 != c.amqp_channel_open(conn.conn, channel)) {
            return AppError.channel_open_err;
        }

        switch (get_rpc_reply(conn)) {
            .ok => {},
            .err => |err| {
                std.debug.print("{any}\n", .{err});
                return err.err_val;
            },
            else => {},
        }

        return Channel{
            .conn = conn,
            .channel = channel,
        };
    }

    pub fn deinit(self: *const @This()) void {
        _ = c.amqp_channel_close(
            self.conn.conn,
            self.channel,
            c.AMQP_REPLY_SUCCESS,
        );
    }
};

// Exchange ==================================================================

pub const ExchangeType = enum {
    direct,
    fanout,
    topic,
    headers,
};

pub const Exchange = struct {
    alloc: *const std.mem.Allocator,
    conn: *const Connection,
    chan: *const Channel,
    exchange_name: AmqpBytes,
    exchange_type: AmqpBytes,

    pub fn declare(
        alloc: *const std.mem.Allocator,
        conn: *const Connection,
        chan: *const Channel,
        exchange_name: []const u8,
        exchange_type: ExchangeType,
        passive: bool,
        durable: bool,
        auto_delete: bool,
        internal: bool,
    ) !Exchange {
        const exchange_name_amqpb = try AmqpBytes.init(alloc, exchange_name);
        const exchange_type_amqpb = switch (exchange_type) {
            .direct => try AmqpBytes.init(alloc, "direct"),
            .fanout => try AmqpBytes.init(alloc, "fanout"),
            .topic => try AmqpBytes.init(alloc, "topic"),
            .headers => try AmqpBytes.init(alloc, "headers"),
        };

        _ = c.amqp_exchange_declare(
            conn.conn,
            chan.channel,
            exchange_name_amqpb.amqp_bytes,
            exchange_type_amqpb.amqp_bytes,
            if (passive) 1 else 0,
            if (durable) 1 else 0,
            if (auto_delete) 1 else 0,
            if (internal) 1 else 0,
            .{},
        );

        return Exchange{
            .alloc = alloc,
            .conn = conn,
            .chan = chan,
            .exchange_name = exchange_name_amqpb,
            .exchange_type = exchange_type_amqpb,
        };
    }

    pub fn init(
        alloc: *const std.mem.Allocator,
        conn: *const Connection,
        chan: *const Channel,
        exchange_name: []const u8,
        exchange_type: ExchangeType,
        passive: bool,
        durable: bool,
        auto_delete: bool,
        internal: bool,
    ) !void {
        try Exchange.declare(
            alloc,
            conn,
            chan,
            exchange_name,
            exchange_type,
            passive,
            durable,
            auto_delete,
            internal,
        );
    }

    pub fn deinit(self: *const @This()) void {
        self.exchange_name.deinit();
        self.exchange_type.deinit();
    }
};

// Integration ===============================================================

// rabbitmq-c uses their own struct for handling binary data of arbitrary
// length
pub const AmqpBytes = struct {
    alloc: *const std.mem.Allocator,
    amqp_bytes: c.amqp_bytes_t,
    payload: []const u8,

    pub fn init(alloc: *const std.mem.Allocator, payload: []const u8) !AmqpBytes {
        const copied_payload = try alloc.dupe(u8, payload);
        const amqp_bytes = c.amqp_bytes_t{
            .bytes = @ptrCast(copied_payload),
            .len = copied_payload.len,
        };

        return AmqpBytes{
            .alloc = alloc,
            .amqp_bytes = amqp_bytes,
            .payload = copied_payload,
        };
    }

    pub fn deinit(self: *const @This()) void {
        self.alloc.free(self.payload);
    }
};

// Handling RPC calls and server responses ===================================

pub const ReplyType = enum {
    ok,
    err,
    no_reply,
};

pub const ErrorLocation = enum {
    server,
    application,
    librabbitmq,
};

pub const ErrorInfo = struct {
    err_val: (LibRabbitMqError || ServerError),
    err_loc: ErrorLocation,
};

pub const Reply = union(ReplyType) {
    ok: void,
    err: ErrorInfo,
    no_reply: void,
};

fn _handle_lib_status(status_code: c.amqp_status_enum) Reply {
    return switch (status_code) {
        c.AMQP_STATUS_OK => return .ok,
        c.AMQP_STATUS_NO_MEMORY => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.no_memory,
            },
        },
        c.AMQP_STATUS_BAD_AMQP_DATA => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.bad_amqp_data,
            },
        },
        c.AMQP_STATUS_UNKNOWN_CLASS => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.unknown_class,
            },
        },
        c.AMQP_STATUS_UNKNOWN_METHOD => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.unknown_method,
            },
        },
        c.AMQP_STATUS_HOSTNAME_RESOLUTION_FAILED => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.host_not_resolved,
            },
        },
        c.AMQP_STATUS_INCOMPATIBLE_AMQP_VERSION => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.incompatible_amqp_version,
            },
        },
        c.AMQP_STATUS_CONNECTION_CLOSED => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.conn_closed,
            },
        },
        c.AMQP_STATUS_BAD_URL => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.bad_url,
            },
        },
        c.AMQP_STATUS_SOCKET_ERROR => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.socket_err,
            },
        },
        c.AMQP_STATUS_INVALID_PARAMETER => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.invalid_param,
            },
        },
        c.AMQP_STATUS_TABLE_TOO_BIG => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.table_too_big,
            },
        },
        c.AMQP_STATUS_WRONG_METHOD => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.wrong_method,
            },
        },
        c.AMQP_STATUS_TIMEOUT => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.timeout,
            },
        },
        c.AMQP_STATUS_TIMER_FAILURE => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.timer_failure,
            },
        },
        c.AMQP_STATUS_HEARTBEAT_TIMEOUT => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.heartbeat_timeout,
            },
        },
        c.AMQP_STATUS_UNEXPECTED_STATE => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.unexpected_state,
            },
        },
        c.AMQP_STATUS_SOCKET_CLOSED => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.socket_closed,
            },
        },
        c.AMQP_STATUS_SOCKET_INUSE => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.socket_in_use,
            },
        },
        c.AMQP_STATUS_BROKER_UNSUPPORTED_SASL_METHOD => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.broker_unsupported_sasl_method,
            },
        },
        c.AMQP_STATUS_UNSUPPORTED => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.unsupported,
            },
        },
        c.AMQP_STATUS_TCP_ERROR => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.tcp_error,
            },
        },
        c.AMQP_STATUS_TCP_SOCKETLIB_INIT_ERROR => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.tcp_socketlib_init_err,
            },
        },
        c.AMQP_STATUS_SSL_ERROR => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.ssl_err,
            },
        },
        c.AMQP_STATUS_SSL_HOSTNAME_VERIFY_FAILED => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.ssl_host_verify_failed,
            },
        },
        c.AMQP_STATUS_SSL_PEER_VERIFY_FAILED => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.ssl_peer_verify_err,
            },
        },
        c.AMQP_STATUS_SSL_CONNECTION_FAILED => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.ssl_conn_err,
            },
        },
        c.AMQP_STATUS_SSL_SET_ENGINE_FAILED => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.ssl_set_engine_err,
            },
        },
        c.AMQP_STATUS_SSL_UNIMPLEMENTED => .{
            .err = .{
                .err_loc = .librabbitmq,
                .err_val = LibRabbitMqError.ssl_unimplemented,
            },
        },
        else => unreachable,
    };
}

fn _handle_rpc_reply(reply: *const c.amqp_rpc_reply_t) Reply {
    if (reply.reply_type == c.AMQP_RESPONSE_NORMAL) {
        return .ok;
    }

    if (reply.reply_type == c.AMQP_RESPONSE_LIBRARY_EXCEPTION) {
        switch (_handle_lib_status(reply.library_error)) {
            .ok => unreachable,
            else => |val| return val,
        }
    }

    if (reply.reply_type == c.AMQP_RESPONSE_SERVER_EXCEPTION) {
        return .ok;
    }

    if (reply.reply_type == c.AMQP_RESPONSE_NONE) {
        return .no_reply;
    }

    unreachable;
}

pub fn get_rpc_reply(conn: *const Connection) Reply {
    const reply: c.amqp_rpc_reply_t = c.amqp_get_rpc_reply(conn.conn);
    return _handle_rpc_reply(&reply);
}
