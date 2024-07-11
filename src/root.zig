const std = @import("std");

pub const dbus = @import("dbussignal");

const DBUS_PATH = "/zig/timekeeper/signal";
const DBUS_INTERFACE = "zig.timekeeper.signal";
const DBUS_MEMBER = "msg";

test {
    std.testing.refAllDecls(@This());
}

test "test send to dbus" {
    var bus = try dbus.DBus.init("/testpath", "test.object");

    var buf: [20:0]u8 = undefined;
    const data_len = (try std.fmt.bufPrint(&buf, "{s}", .{"test"})).len;
    buf[data_len] = 0;
    try bus.send_message("test", &buf);
}

test "receive message" {
    var gp = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    const allocator = gp.allocator();

    defer _ = gp.deinit();

    var bus = try dbus.DBus.init(DBUS_PATH, DBUS_INTERFACE);
    var count: u32 = 0;
    while (true) {
        const value = try bus.get_message_blocking(200, DBUS_MEMBER, allocator);
        count += 1;
        if (value) |val| {
            allocator.free(val);
        }

        if (count > 5) {
            break;
        }
    }
}
