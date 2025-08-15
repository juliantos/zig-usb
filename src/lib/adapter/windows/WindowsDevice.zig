const std = @import("std");
const windows = std.os.windows;
const setup_api = @cImport({
    @cInclude("windows.h");
    @cInclude("setupapi.h");
    @cInclude("guiddef.h");
});
const WindowsError = @import("WindowsError.zig").WindowsError;

const GUID_DEVINTERFACE_USB_DEVICE: setup_api.GUID = .{
    .Data1 = 0xa5dcbf10,
    .Data2 = 0x6530,
    .Data3 = 0x11d2,
    .Data4 = .{
        0x90,
        0x1f,
        0x00,
        0xc0,
        0x4f,
        0xb9,
        0x51,
        0xed,
    },
};

pub const WindowsDevice = struct {
    const Self = @This();

    filepath: [windows.MAX_PATH:0]u8,

    pub fn init(allocator: std.mem.Allocator, handle: setup_api.HDEVINFO, index: u32) !WindowsDevice {
        var device = setup_api.SP_DEVINFO_DATA{};
        device.cbSize = @sizeOf(setup_api.SP_DEVINFO_DATA);
        var result = setup_api.SetupDiEnumDeviceInfo(handle, index, &device);
        if (result == windows.FALSE) {
            @branchHint(.unlikely);
            return WindowsError.NoEnumInfo;
        }

        // TODO: Maybe Iterate?
        var data = setup_api.SP_DEVICE_INTERFACE_DATA{};
        data.cbSize = @sizeOf(setup_api.SP_DEVICE_INTERFACE_DATA);
        result = setup_api.SetupDiEnumDeviceInterfaces(handle, &device, &GUID_DEVINTERFACE_USB_DEVICE, 0, &data);

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

        var win_device = WindowsDevice{
            .filepath = std.mem.zeroes([windows.MAX_PATH:0]u8),
        };
        for (0..length) |i| {
            win_device.filepath[i] = flex_c_str[i];
        }
        return win_device;
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }

    pub fn getPath(self: Self) ![:0]const u8 {
        return self.filepath[0..self.filepath.len];
    }

    pub fn enumerateDevices(allocator: std.mem.Allocator, handle: setup_api.HDEVINFO) ![]WindowsDevice {
        var devices = std.ArrayList(WindowsDevice).init(allocator);
        var index: u32 = 0;
        var winerr = windows.Win32Error.SUCCESS;

        while (winerr != windows.Win32Error.NO_MORE_ITEMS) {
            const device = WindowsDevice.init(allocator, handle, index) catch |err| switch (err) {
                else => {
                    winerr = windows.GetLastError();
                    std.debug.print("Error: {}\n", .{winerr});
                    index += 1;
                    continue;
                },
            };
            devices.append(device) catch {
                device.deinit();
                continue;
            };
            index += 1;
        }

        return devices.toOwnedSlice();
    }

    fn getDeviceProperty(allocator: std.mem.Allocator, handle: setup_api.HDEVINFO, device_info: setup_api.PSP_DEVINFO_DATA, property: windows.DWORD) ![]windows.WCHAR {
        var result: windows.BOOL = windows.TRUE;
        var length: windows.DWORD = 0;

        if (handle == windows.INVALID_HANDLE_VALUE) {
            return WindowsError.NoDevInfo;
        }

        result = setup_api.SetupDiGetDeviceRegistryPropertyW(
            handle,
            device_info,
            property,
            null,
            null,
            0,
            &length,
        );

        if (length == 0 or result != windows.FALSE) {
            return WindowsError.NoRegistryProperty;
        }

        const buffer = try allocator.alloc(windows.WCHAR, length / @sizeOf(windows.WCHAR));

        result = windows.TRUE;
        result = setup_api.SetupDiGetDeviceRegistryPropertyW(
            handle,
            device_info,
            property,
            null,
            @ptrCast(buffer),
            length,
            &length,
        );

        if (result == windows.FALSE) {
            allocator.free(buffer);
            return WindowsError.NoRegistryProperty;
        }

        return buffer;
    }
};

// pub const WindowsDevice = struct {
//     var Self = @This();

//     context: setup_api.HDEVINFO,
//     allocator: std.mem.Allocator,
//     interface_data: setup_api.SP_DEVICE_INTERFACE_DATA,
//     device_info_data: setup_api.SP_DEVINFO_DATA,
//     device_interface_detail_data: setup_api.PSP_DEVICE_INTERFACE_DETAIL_DATA_W,
//     device_interface_detail_length: win.ULONG,
//     device_description: std.ArrayList(win.WCHAR),
//     driver_key: std.ArrayList(win.WCHAR),

//     pub fn init(allocator: std.mem.Allocator, context: setup_api.HDEVINFO) Self {
//         var dev: WinDevice = .{
//             .context = context,
//             .allocator = allocator,
//             .interface_data = undefined,
//             .device_info_data = undefined,
//             .device_interface_detail_data = null,
//             .device_interface_detail_length = 0,
//             .device_description = std.ArrayList(win.WCHAR).init(allocator),
//             .driver_key = std.ArrayList(win.WCHAR).init(allocator),
//         };

//         dev.interface_data.cbSize = @sizeOf(setup_api.SP_DEVICE_INTERFACE_DATA);
//         dev.device_info_data.cbSize = @sizeOf(setup_api.SP_DEVINFO_DATA);

//         return dev;
//     }

//     pub fn deinit(self: Self) void {
//         if (self.device_interface_detail_data == null) {
//             self.allocator.destroy(self.device_interface_detail_data);
//             self.device_interface_detail_length = 0;
//         }
//         self.device_description.deinit();
//         self.driver_key.deinit();
//     }

//     pub fn GetProperty(self: Self, allocator: std.mem.Allocator, property: win.DWORD) ![]u8 {
//         return GetDeviceProperty(allocator, self.context, self.device_info_data, property);
//     }
// };

// pub fn EnumerateDevices(allocator: std.mem.Allocator, context: setup_api.HDEVINFO, guid: setup_api.GUID) ![]WinDevice {
//     var index: u32 = 0;
//     var devices = std.ArrayList(WinDevice).init(allocator);
//     var err: win.Win32Error = .SUCCESS;

//     if (context == win.INVALID_HANDLE_VALUE) {
//         devices.deinit();
//         return UsbError.DriverFailure;
//     }

//     while (err != win.Win32Error.NO_MORE_ITEMS) {
//         var win_device: WinDevice = .init(allocator, context);
//         var length: win.ULONG = 0;

//         var result = setup_api.SetupDiEnumDeviceInfo(
//             context,
//             index,
//             &win_device.device_info_data,
//         );

//         if (result == win.FALSE) {
//             @branchHint(.unlikely);
//             err = win.kernel32.GetLastError();
//             index += 1;
//             continue;
//         }

//         const description_name = GetDeviceProperty(
//             allocator,
//             context,
//             &win_device.device_info_data,
//             setup_api.SPDRP_DEVICEDESC,
//         ) catch |get_err| {
//             win_device.deinit();
//             return get_err;
//         };
//         win_device.device_description = std.ArrayList(win.WCHAR).fromOwnedSlice(allocator, description_name);

//         const driver_name = GetDeviceProperty(
//             allocator,
//             context,
//             &win_device.device_info_data,
//             setup_api.SPDRP_DRIVER,
//         ) catch |get_err| {
//             win_device.deinit();
//             return get_err;
//         };
//         win_device.driver_key = std.ArrayList(win.WCHAR).fromOwnedSlice(allocator, driver_name);

//         result = setup_api.SetupDiEnumDeviceInterfaces(
//             context,
//             0,
//             &guid,
//             index,
//             &win_device.interface_data,
//         );

//         if (result == win.FALSE) {
//             @branchHint(.unlikely);
//             win_device.deinit();
//             err = win.kernel32.GetLastError();
//             index += 1;
//             continue;
//         }

//         result = setup_api.SetupDiGetDeviceInterfaceDetailW(
//             context,
//             &win_device.interface_data,
//             null,
//             0,
//             &length,
//             null,
//         );

//         if (result != win.FALSE) {
//             @branchHint(.unlikely);
//             win_device.deinit();
//             err = win.kernel32.GetLastError();
//             index += 1;
//             continue;
//         }

//         win_device.device_interface_detail_data = try allocator.create(setup_api.SP_DEVICE_INTERFACE_DETAIL_DATA_W);
//         win_device.device_interface_detail_data.*.cbSize = @sizeOf(setup_api.SP_DEVICE_INTERFACE_DETAIL_DATA_W);
//         result = setup_api.SetupDiGetDeviceInterfaceDetailW(
//             context,
//             &win_device.interface_data,
//             win_device.device_interface_detail_data,
//             length,
//             &length,
//             null,
//         );
//         win_device.device_interface_detail_length = length;

//         if (result == win.FALSE) {
//             @branchHint(.unlikely);
//             win_device.deinit();
//             err = win.kernel32.GetLastError();
//             index += 1;
//             continue;
//         }

//         try devices.append(win_device);

//         index += 1;
//     }

//     return devices.toOwnedSlice();
// }
