const std = @import("std");
const DeviceDescriptor = @import("DeviceDescriptor.zig").DeviceDescriptor;
const Handle = @import("Handle.zig").Handle;
const UsbError = @import("error.zig").UsbError;

pub const DeviceData = struct {
    file_handle: Handle,
    handle: Handle,
    open: bool,
    path: std.ArrayList(u8),

    pub fn initCapacity(allocator: std.mem.Allocator, capacity: usize) !DeviceData {
        return .{
            .file_handle = null,
            .handle = null,
            .open = false,
            .path = try .initCapacity(allocator, capacity),
        };
    }

    pub fn deinit(self: *DeviceData) void {
        self.path.deinit();
    }
};
