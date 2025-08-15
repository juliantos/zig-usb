const std = @import("std");
const Adapter = @import("usb-adapter").Adapter;
const Device = @import("usb-adapter").Device;

pub const DeviceData = struct {
    const Self = @This();

    adapter: Adapter,
    handle: Device,
    open: bool,
    path: [*:0]const u8,

    pub fn deinit(self: Self) void {
        self.adapter.deinitDevice(self.handle);
    }
};
