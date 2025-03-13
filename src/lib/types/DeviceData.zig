const std = @import("std");
const DeviceDescriptor = @import("DeviceDescriptor.zig").DeviceDescriptor;
const Handle = @import("Handle.zig").Handle;
const UsbError = @import("error.zig").UsbError;
const Driver = @import("usb-driver").Driver;

pub const DeviceData = struct {
    file_handle: Handle,
    handle: Handle,
    open: bool,
    path: std.ArrayList(u8),
};
