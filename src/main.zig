const std = @import("std");
const usb = @import("zig-usb");
const Device = usb.Device;

pub fn main() !void {
    const device: Device = Device.init(0, 0);
    try device.open();
    std.debug.print("{any}\n", .{device});
    //_ = usb.device.OpenDevice(context, 0, 0) catch |err| {
    ////std.debug.print("Error {}\n", err);
    //std.debug.print("{any}", .{err});
    //};
}
