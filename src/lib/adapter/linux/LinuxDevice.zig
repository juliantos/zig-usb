const std = @import("std");
const DeviceDescriptor = @import("usb-types").DeviceDescriptor;
const LinuxError = @import("LinuxError.zig").LinuxError;
// const udev = @cImport({
//     @cInclude("libudev.h");
// });
const device = @cImport({
    @cInclude("systemd/sd-device.h");
});

pub const LinuxDevice = struct {
    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }

    pub fn getPID(self: Self) u16 {
        _ = self;
        return 0;
    }

    pub fn getVID(self: Self) u16 {
        _ = self;
        return 0;
    }

    pub fn getDescriptors(self: Self) !DeviceDescriptor {
        _ = self;
        return LinuxError.NoDescriptors;
    }

    pub fn enumerateDevice(allocator: std.mem.Allocator) ![]LinuxDevice {
        var devices = std.array_list.Managed(LinuxDevice).init(allocator);

        var enumerator: ?*device.sd_device_enumerator = null;
        const r = device.sd_device_enumerator_new(&enumerator);
        _ = r;

        if (device.sd_device_enumerator_unref(enumerator) != null) {
            return LinuxError.NoDeviceEnumUnref;
        }

        return devices.toOwnedSlice();
    }
};
