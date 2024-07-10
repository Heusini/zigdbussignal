const std = @import("std");

pub const dbus = @import("dbus.zig");

test {
    std.testing.refAllDecls(@This());
}
