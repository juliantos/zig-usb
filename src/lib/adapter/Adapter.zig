const builtin = @import("builtin");

pub const Adapter = switch (builtin.os.tag) {
    .windows => @import("windows/WindowsAdapter.zig").WindowsAdapter,
    .linux => @import("linux/LinuxAdapter.zig").LinuxAdapter,
    else => @panic("Dont have a os adapter"),
};

pub const Device = switch (builtin.os.tag) {
    .windows => @import("windows/WindowsDevice.zig").WindowsDevice,
    .linux => @import("linux/LinuxDevice.zig").LinuxDevice,
    else => @panic("Don't have an os device"),
};
