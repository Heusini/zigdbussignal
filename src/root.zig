const std = @import("std");

pub const dbus = @import("dbussignal");

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
