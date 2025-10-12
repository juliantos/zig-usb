const std = @import("std");
const linux = std.os.linux;
const posix = std.posix;
// const udev = @cImport({
//     @cInclude("libudev.h");
// });
const LinuxDevice = @import("LinuxDevice.zig").LinuxDevice;
const DeviceData = @import("usb-types").DeviceData;

pub const LinuxAdapter = struct {
    const Self = @This();

    // context: ?*udev.struct_udev,

    pub fn init() Self {
        return Self{
            // .context = udev.udev_new(),
        };
    }

    pub fn deinit(self: Self) void {
        _ = self;
        // if (self.context) |c| {
        //     var ref: ?*udev.struct_udev = c;
        //     while (ref) |r| {
        //         ref = udev.udev_unref(r);
        //     }
        // }
        return;
    }

    pub fn deinitDevice(self: Self, device: LinuxDevice) void {
        _ = self;
        device.deinit();
    }

    pub fn getDevices(self: Self, allocator: std.mem.Allocator) ![]DeviceData {
        _ = self;
        var devices = std.array_list.Managed(DeviceData).init(allocator);

        const linux_devices = try LinuxDevice.enumerateDevice(allocator);
        defer {
            for (linux_devices) |d| {
                d.deinit();
            }
            allocator.free(linux_devices);
        }

        return devices.toOwnedSlice();
    }
};
