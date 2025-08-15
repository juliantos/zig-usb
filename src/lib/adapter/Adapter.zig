const builtin = @import("builtin");

pub const Adapter = switch (builtin.os.tag) {
    .windows => @import("windows/WindowsAdapter.zig").WindowsAdapter,
    else => @panic("Dont have a os adapter"),
};

pub const Device = switch (builtin.os.tag) {
    .windows => @import("windows/WindowsDevice.zig").WindowsDevice,
    else => @panic("Don't have an os device"),
};
