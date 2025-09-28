const std = @import("std");
const windows = std.os.windows;
const setup_api = @cImport({
    @cInclude("windows.h");
    @cInclude("setupapi.h");
    @cInclude("guiddef.h");
});
const io = @cImport({
    @cInclude("ioapiset.h");
});
const usb = @cImport({
    @cInclude("usbioctl.h");
});
const WindowsHub = @import("WindowsHub.zig").WindowsHub;
const WindowsError = @import("WindowsError.zig").WindowsError;
const windows_helpers = @import("windows_helpers.zig");

const GUID_DEVINTERFACE_USB_HOST_CONTROLLER: setup_api.GUID = .{
    .Data1 = 0x3abf6f2d,
    .Data2 = 0x71c4,
    .Data3 = 0x462a,
    .Data4 = .{
        0x8a,
        0x92,
        0x1e,
        0x68,
        0x61,
        0xe6,
        0xaf,
        0x27,
    },
};

pub const WindowsHostController = struct {
    const Self = @This();

    name: std.array_list.AlignedManaged(u8, std.mem.Alignment.@"1"),
    path: std.array_list.AlignedManaged(u8, std.mem.Alignment.@"1"),

    fp: *anyopaque,

    pub fn init(allocator: std.mem.Allocator, handle: setup_api.HDEVINFO, guid: setup_api.GUID, index: u32) !Self {
        var device = setup_api.SP_DEVINFO_DATA{};
        device.cbSize = @sizeOf(setup_api.SP_DEVINFO_DATA);
        var result = setup_api.SetupDiEnumDeviceInfo(handle, index, &device);
        if (result == windows.FALSE) {
            @branchHint(.unlikely);
            return WindowsError.NoEnumInfo;
        }

        var data = setup_api.SP_DEVICE_INTERFACE_DATA{};
        data.cbSize = @sizeOf(setup_api.SP_DEVICE_INTERFACE_DATA);
        result = setup_api.SetupDiEnumDeviceInterfaces(handle, &device, &guid, 0, &data);

        const detail = try allocator.create(setup_api.SP_DEVICE_INTERFACE_DETAIL_DATA_W);
        defer allocator.destroy(detail);
        var length: windows.DWORD = 0;
        detail.cbSize = @sizeOf(setup_api.SP_DEVICE_INTERFACE_DETAIL_DATA_W);
        result = setup_api.SetupDiGetDeviceInterfaceDetailW(handle, &data, null, 0, &length, null);
        if (result == windows.FALSE) {
            @branchHint(.likely);
            if (windows.GetLastError() != windows.Win32Error.INSUFFICIENT_BUFFER) {
                @branchHint(.unlikely);
                return WindowsError.NoInstanceInfo;
            }
        }
        result = setup_api.SetupDiGetDeviceInterfaceDetailW(handle, &data, detail, length, &length, null);
        var flex_ptr: [*]u16 = &detail.DevicePath;
        const flex_array: [:0]u16 = @ptrCast(flex_ptr[0..length]);

        const flex_c_str = try std.unicode.utf16LeToUtf8Alloc(allocator, flex_array);
        defer allocator.free(flex_c_str);

        const device_desc = try windows_helpers.getDeviceProperty(allocator, handle, @ptrCast(&device), setup_api.SPDRP_DEVICEDESC);
        const device_desc_utf8 = try std.unicode.utf16LeToUtf8Alloc(allocator, device_desc);
        defer {
            allocator.free(device_desc);
            allocator.free(device_desc_utf8);
        }

        // Open Device to reveal interesting information
        const fp = windows.kernel32.CreateFileW(
            flex_array,
            windows.GENERIC_WRITE,
            windows.FILE_SHARE_WRITE,
            null,
            windows.OPEN_EXISTING,
            0,
            null,
        );
        if (fp == windows.INVALID_HANDLE_VALUE) {
            return WindowsError.NoDevice;
        }

        var controller = Self{
            .name = std.array_list.AlignedManaged(u8, std.mem.Alignment.@"1").init(allocator),
            .path = std.array_list.AlignedManaged(u8, std.mem.Alignment.@"1").init(allocator),

            .fp = fp,
        };
        try controller.name.appendSlice(device_desc_utf8[0..]);
        try controller.path.appendSlice(flex_c_str[0..]);

        controller.enumerate(allocator) catch |err| {
            controller.deinit();
            return err;
        };

        return controller;
    }

    pub fn deinit(self: Self) void {
        self.name.deinit();
        self.path.deinit();

        windows.CloseHandle(self.fp);
    }

    pub fn getName(self: Self) ![:0]const u8 {
        return self.name.items[0 .. self.name.items.len - 1 :0];
    }

    pub fn getPath(self: Self) ![:0]const u8 {
        return self.path.items[0 .. self.path.items.len - 1 :0];
    }

    fn enumerate(self: *Self, allocator: std.mem.Allocator) !void {

        // TODO:
        //   Get HCD Driver Key Name
        //   Get Device Properties from Driver Key Name
        //     vendor ID
        //     device ID
        //     sub sys ID
        //     revision
        //     Device Properies (USB Device PNP Strings)
        //     Power Map
        //     Bus Number
        //     Device and Function
        //     DIOCTL USB_USER_REQUEST -> USB_CONTROLLER_INFO

        // [x]  Get Device Root Hub
        //   [x]  DIOCTL USB_GET_ROOT_HUB_NAME
        //   [x]  Enumerate Hub
        const root_hub_name = try self.getRootHubName(allocator);
        defer {
            allocator.free(root_hub_name);
        }

        if (root_hub_name.len > 256) {
            return WindowsError.BadRootHub;
        } else if (root_hub_name.len > 0) {
            @branchHint(.likely);
            const hub = try WindowsHub.initName(allocator, root_hub_name);
            defer {
                hub.deinit();
            }

            std.debug.print("Hub Name: {s}\n", .{try hub.getName()});
        } else {
            return WindowsError.NoRootHub;
        }
    }

    fn getRootHubName(self: Self, allocator: std.mem.Allocator) ![:0]const u8 {
        var root_hub_name: usb.USB_ROOT_HUB_NAME = undefined;
        var num_bytes: u32 = 0;

        var result = io.DeviceIoControl(
            self.fp,
            windows_helpers.IOCTL_USB_GET_ROOT_HUB_NAME,
            null,
            0,
            &root_hub_name,
            @sizeOf(usb.USB_ROOT_HUB_NAME),
            &num_bytes,
            null,
        );

        if (result == 0) {
            @branchHint(.unlikely);
            return WindowsError.NoRootHub;
        }

        const root_hub_name_wide = try allocator.create(usb.USB_ROOT_HUB_NAME);
        defer {
            allocator.destroy(root_hub_name_wide);
        }
        result = io.DeviceIoControl(
            self.fp,
            windows_helpers.IOCTL_USB_GET_ROOT_HUB_NAME,
            null,
            0,
            root_hub_name_wide,
            root_hub_name.ActualLength,
            &num_bytes,
            null,
        );

        var name_ptr: [*]u16 = &root_hub_name_wide.RootHubName;
        const name_array: [:0]u16 = @ptrCast(name_ptr[0..num_bytes]);
        const name_c_str = try std.unicode.utf16LeToUtf8AllocZ(allocator, name_array);
        return name_c_str;
    }

    pub fn enumerateControllers(allocator: std.mem.Allocator, handle: setup_api.HDEVINFO) ![]WindowsHostController {
        var controllers = std.array_list.Managed(WindowsHostController).init(allocator);
        var index: u32 = 0;
        var winerr = windows.Win32Error.SUCCESS;

        while (winerr != windows.Win32Error.NO_MORE_ITEMS) {
            const controller = WindowsHostController.init(allocator, handle, GUID_DEVINTERFACE_USB_HOST_CONTROLLER, index) catch |err| switch (err) {
                else => {
                    winerr = windows.GetLastError();
                    index += 1;
                    continue;
                },
            };
            controllers.append(controller) catch {
                controller.deinit();
                continue;
            };
            index += 1;
        }

        return controllers.toOwnedSlice();
    }
};
