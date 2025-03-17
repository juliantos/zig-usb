const std = @import("std");
const win = std.os.windows;
const setup_api = @cImport({
    @cInclude("windows.h");
    @cInclude("setupapi.h");
    @cInclude("guiddef.h");
});

pub const WinDevice = struct {
    const Self = @This();

    interface_data: setup_api.SP_DEVICE_INTERFACE_DATA,
    device_info_data: setup_api.SP_DEVINFO_DATA,
    device_interface_detail_data: setup_api.SP_DEVICE_INTERFACE_DETAIL_DATA_W,
    device_description: std.ArrayList(win.WCHAR),
    driver_key: std.ArrayList(win.WCHAR),

    pub fn init(allocator: std.mem.Allocator) Self {
        var dev: WinDevice = .{
            .interface_data = undefined,
            .device_info_data = undefined,
            .device_interface_detail_data = undefined,
            .device_description = std.ArrayList(win.WCHAR).init(allocator),
            .driver_key = std.ArrayList(win.WCHAR).init(allocator),
        };

        dev.interface_data.cbSize = @sizeOf(setup_api.SP_DEVICE_INTERFACE_DATA);
        dev.device_info_data.cbSize = @sizeOf(setup_api.SP_DEVINFO_DATA);
        dev.device_interface_detail_data.cbSize = @sizeOf(setup_api.SP_DEVICE_INTERFACE_DETAIL_DATA_W);

        return dev;
    }

    pub fn deinit(self: Self) void {
        self.device_description.deinit();
        self.driver_key.deinit();
    }
};
