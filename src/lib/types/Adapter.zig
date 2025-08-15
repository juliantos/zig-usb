const std = @import("std");
const DeviceData = @import("DeviceData.zig").DeviceData;

pub const Adapter = struct {
    const Self = @This();

    getDevicesFn: fn (*Adapter, std.mem.Allocator) []DeviceData,

    pub fn getDevices(self: Self, allocator: std.mem.Allocator) []DeviceData {
        return self.getDevicesFn(allocator);
    }
};
