const std = @import("std");
const dbus = @cImport(@cInclude("dbus/dbus.h"));

const DBusError = extern struct {
    name: [*c]const u8,
    message: [*c]const u8,
    dummy: isize,
    padding: *opaque {},
};

pub const DBus = struct {
    conn: *dbus.DBusConnection,
    interface: [:0]const u8,
    path: [:0]const u8,

    const Self = @This();

    pub fn init(comptime path: [:0]const u8, comptime interface: [:0]const u8) !Self {
        const filter = "type='signal',interface='" ++ interface ++ "'";

        var buf: DBusError = undefined;
        const err: *dbus.DBusError = @ptrCast(&buf);
        defer dbus.dbus_error_free(err);

        dbus.dbus_error_init(err);
        const conn = dbus.dbus_bus_get(dbus.DBUS_BUS_SESSION, err);

        if (dbus.dbus_error_is_set(err) != 0) {
            std.debug.print("{s}\n", .{std.mem.span(buf.message)});
            return error.CouldNotConnectToDBus;
        }

        dbus.dbus_bus_add_match(conn, filter, err);
        dbus.dbus_connection_flush(conn);
        if (dbus.dbus_error_is_set(err) != 0) {
            std.debug.print("Could not apply filter error: {s}\n", .{buf.message});
            return error.FilterNotAppliedError;
        }

        return Self{ .conn = conn.?, .interface = interface, .path = path };
    }

    pub fn get_message_blocking(self: *Self, block_ms: isize, msg_type: []const u8, allocator: std.mem.Allocator) !?[]const u8 {
        var sigval: [*c]u8 = undefined;
        const sigval_ptr: *anyopaque = @ptrCast(&sigval);
        var args: dbus.DBusMessageIter = undefined;

        // maybe handle error
        _ = dbus.dbus_connection_read_write(self.conn, @intCast(block_ms));
        const msg_raw = dbus.dbus_connection_pop_message(self.conn);

        if (msg_raw) |msg| {
            if (dbus.dbus_message_is_signal(msg, @ptrCast(self.interface), @ptrCast(msg_type)) == 1) {
                if (dbus.dbus_message_iter_init(msg, &args) == 0) {
                    std.debug.print("Message does not have payload\n", .{});
                    return error.NoMessagePayload;
                } else {
                    dbus.dbus_message_iter_get_basic(&args, sigval_ptr);
                    // std.debug.print("Message from dbus: {s}\n", .{sigval});
                    const sigval_len = std.mem.len(sigval);
                    const value = try allocator.alloc(u8, sigval_len);
                    std.mem.copyForwards(u8, value, sigval[0..sigval_len]);
                    dbus.dbus_message_unref(msg);
                    return value;
                }
            }
        }

        return null;
    }

    pub fn send_message(self: *Self, msg_type: [:0]const u8, msg: [:0]u8) !void {
        var args: dbus.DBusMessageIter = undefined;
        var serial: u32 = 0;

        const message: ?*dbus.DBusMessage = dbus.dbus_message_new_signal(self.path, self.interface, msg_type);

        if (message) |_| {} else {
            std.debug.print("Error could not create message {?}\n", .{message});
            return error.CreateDBusMessageError;
        }

        var msg_tmp = msg;
        const items: ?*anyopaque = @ptrCast(&msg_tmp);

        dbus.dbus_message_iter_init_append(message, &args);
        if (dbus.dbus_message_iter_append_basic(&args, dbus.DBUS_TYPE_STRING, items) == 0) {
            std.debug.print("Error cannot append data to message\n", .{});
            return error.AppendDataMessage;
        }
        if (dbus.dbus_connection_send(self.conn, message, &serial) == 0) {
            std.debug.print("Error sending message to dbus\n", .{});
            return error.SendingMessage;
        }

        dbus.dbus_connection_flush(self.conn);
        dbus.dbus_message_unref(message);
    }
};
