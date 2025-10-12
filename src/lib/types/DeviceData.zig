const std = @import("std");
const Adapter = @import("usb-adapter").Adapter;
const Device = @import("usb-adapter").Device;
const DeviceDescriptor = @import("descriptors.zig").DeviceDescriptor;

pub const DeviceData = struct {
    const Self = @This();

    adapter: Adapter,
    handle: Device,
    open: bool,
    path: [*:0]const u8,

    pub fn deinit(self: Self) void {
        self.adapter.deinitDevice(self.handle);
    }

    pub inline fn getPID(self: Self) !u16 {
        return self.handle.getPID();
    }

    pub inline fn getVID(self: Self) !u16 {
        return self.handle.getVID();
    }

    pub inline fn getDescriptors(self: Self) !DeviceDescriptor {
        return self.handle.getDescriptors();
    }
};
