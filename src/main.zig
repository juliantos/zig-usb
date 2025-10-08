const std = @import("std");
const usb = @import("zig-usb");
const Device = usb.Device;

pub fn main() !void {
    std.debug.print("Searching for Devices\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }
    var allocator = gpa.allocator();
    const devices = try Device.getIDs(allocator);
    defer {
        allocator.free(devices);
    }

    for (devices) |dev| {
        std.debug.print("Device: 0x{x:0>4} 0x{x:0>4}\n", .{ dev.pid, dev.vid });

        var device = Device.init(allocator, dev.vid, dev.pid);
        defer {
            device.deinit();
        }
        if (device.open()) {
            std.debug.print("Descriptor: {any}\n", .{device.device_descriptor});
        } else |_| {}
    }

    //_ = usb.device.OpenDevice(context, 0, 0) catch |err| {
    ////std.debug.print("Error {}\n", err);
    //std.debug.print("{any}", .{err});
    //};
}
