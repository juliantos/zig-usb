const std = @import("std");
const windows = std.os.windows;
const setup_api = @cImport({
    @cInclude("windows.h");
    @cInclude("setupapi.h");
    @cInclude("guiddef.h");
});
const usb = @cImport({
    @cInclude("usbioctl.h");
});
const io = @cImport({
    @cInclude("ioapiset.h");
});
const iodef = @cImport({
    @cInclude("windows.h");
    @cInclude("usbiodef.h");
});
const WindowsError = @import("WindowsError.zig").WindowsError;
const DeviceDescriptor = @import("usb-types").DeviceDescriptor;

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

const GUID_DEVINTERFACE_USB_HUB: setup_api.GUID = .{
    .Data1 = 0xf18a0e88,
    .Data2 = 0xc30c,
    .Data3 = 0x11d0,
    .Data4 = .{
        0x88,
        0x15,
        0x00,
        0xa0,
        0xc9,
        0x06,
        0xbe,
        0xd8,
    },
};

fn CTL_CODE(device_type: u32, function: u32, method: u32, access: u32) u32 {
    return (device_type << 16) | (access << 14) | (function << 2) | method;
}

const IOCTL_USB_GET_DESCRIPTOR_FROM_NODE_CONNECTION = CTL_CODE(iodef.FILE_DEVICE_USB, iodef.USB_GET_DESCRIPTOR_FROM_NODE_CONNECTION, iodef.METHOD_BUFFERED, iodef.FILE_ANY_ACCESS);
const IOCTL_USB_GET_NODE_CONNECTION_INFORMATION = CTL_CODE(iodef.FILE_DEVICE_USB, iodef.USB_GET_NODE_CONNECTION_INFORMATION, iodef.METHOD_BUFFERED, iodef.FILE_ANY_ACCESS);
const IOCTL_USB_GET_ROOT_HUB_NAME = CTL_CODE(iodef.FILE_DEVICE_USB, iodef.HCD_GET_ROOT_HUB_NAME, iodef.METHOD_BUFFERED, iodef.FILE_ANY_ACCESS);

pub const WindowsDevice = struct {
    const Self = @This();

    filepath: std.array_list.AlignedManaged(u8, std.mem.Alignment.@"1"),
    handle: setup_api.HDEVINFO,
    info: setup_api.SP_DEVINFO_DATA,

    parent_hub: ?*WindowsDevice,
    sub_devices: std.array_list.Managed(WindowsDevice),

    pid: u16,
    vid: u16,
    mi: u8,
    depth: u8,
    serial: []const u8,
    interface_num: u16,
    interface_guid: setup_api.GUID,

    pub fn init(allocator: std.mem.Allocator, handle: setup_api.HDEVINFO, guid: setup_api.GUID, hub: ?*WindowsDevice, index: u32) !WindowsDevice {
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

        const device_desc = try WindowsDevice.getDeviceProperty(allocator, handle, &device, setup_api.SPDRP_DEVICEDESC);
        const device_desc_utf8 = try std.unicode.utf16LeToUtf8Alloc(allocator, device_desc);
        defer {
            allocator.free(device_desc);
            allocator.free(device_desc_utf8);
        }
        std.debug.print("Desc {s}\n", .{device_desc_utf8});

        // const fp = windows.kernel32.CreateFileW(flex_array, windows.GENERIC_READ | windows.GENERIC_WRITE, windows.FILE_SHARE_READ | windows.FILE_SHARE_WRITE, null, windows.OPEN_EXISTING, windows.FILE_ATTRIBUTE_NORMAL | windows.FILE_FLAG_OVERLAPPED, null);
        // if (fp == windows.INVALID_HANDLE_VALUE) {
        //     std.debug.print("Failed to open device {}\n", .{windows.GetLastError()});
        //     return WindowsError.NoDevice;
        // }
        // std.debug.print("File Pointer {any}\n", .{fp});

        var win_device = WindowsDevice{
            .filepath = std.array_list.Managed(u8).init(allocator),
            .handle = handle,
            .info = device,

            .parent_hub = hub,
            .sub_devices = std.array_list.Managed(WindowsDevice).init(allocator),

            .pid = 0,
            .vid = 0,
            .mi = 0,
            .depth = 0,
            .serial = "",
            .interface_num = 0,
            .interface_guid = setup_api.GUID{},
        };
        try win_device.filepath.appendSlice(flex_c_str[0..]);

        // Fill out device details
        win_device.getDeviceProperties();

        return win_device;
    }

    pub fn deinit(self: Self) void {
        self.filepath.deinit();
    }

    pub inline fn getPath(self: Self) ![:0]const u8 {
        return self.filepath.items[0 .. self.filepath.items.len - 1 :0];
    }

    pub inline fn getPID(self: Self) !u16 {
        return self.pid;
    }

    pub inline fn getVID(self: Self) !u16 {
        return self.vid;
    }

    pub fn getDescriptors(self: Self) !DeviceDescriptor {
        _ = self;
        return WindowsError.NoDescriptors;
    }

    pub fn enumerateDevices(allocator: std.mem.Allocator, handle: setup_api.HDEVINFO) ![]WindowsDevice {
        var devices = std.array_list.Managed(WindowsDevice).init(allocator);
        var index: u32 = 0;
        var winerr = windows.Win32Error.SUCCESS;

        while (winerr != windows.Win32Error.NO_MORE_ITEMS) {
            const device = WindowsDevice.init(allocator, handle, GUID_DEVINTERFACE_USB_DEVICE, null, index) catch |err| switch (err) {
                else => {
                    winerr = windows.GetLastError();
                    index += 1;
                    continue;
                },
            };
            devices.append(device) catch {
                device.deinit(); // MAYBE: need to increment index; seeing this while developing linux
                continue;
            };
            index += 1;
        }

        return devices.toOwnedSlice();
    }

    pub fn enumerateHubs(allocator: std.mem.Allocator, handle: setup_api.HDEVINFO) ![]WindowsDevice {
        var hubs = std.array_list.Managed(WindowsDevice).init(allocator);
        var index: u32 = 0;
        var winerr = windows.Win32Error.SUCCESS;

        while (winerr != windows.Win32Error.NO_MORE_ITEMS) {
            const hub = WindowsDevice.init(allocator, handle, GUID_DEVINTERFACE_USB_HUB, null, index) catch |err| switch (err) {
                else => {
                    winerr = windows.GetLastError();
                    index += 1;
                    continue;
                },
            };
            hubs.append(hub) catch {
                hub.deinit();
                continue;
            };
            index += 1;
        }

        return hubs.toOwnedSlice();
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

    fn getDeviceProperties(self: *Self) void {
        self.scanDevicePathString();
    }

    fn scanDevicePathString(self: *Self) void {
        if (self.filepath.items.len > 0) {
            var device_tokens = std.mem.tokenizeAny(u8, self.filepath.items, "#");

            // Decode \\?\usb
            const path_type = device_tokens.next();
            if (path_type) |path| {
                if (!std.mem.eql(u8, path, "\\\\?\\usb")) {
                    return;
                }
            } else {
                return;
            }

            //vid_xxxx&pid_yyyy
            const ids = device_tokens.next();
            if (ids) |id| {
                var id_tokens = std.mem.tokenizeAny(u8, id, "&");

                // vid_xxxx
                const vid = id_tokens.next();

                // pid_yyyy
                const pid = id_tokens.next();

                // mi_zz
                const mi = id_tokens.next();

                if (vid) |v| {
                    if (v.len == 8) {
                        self.vid = std.fmt.parseInt(u16, v[4..], 16) catch 0;
                    }
                }

                if (pid) |p| {
                    if (p.len == 8) {
                        self.pid = std.fmt.parseInt(u16, p[4..], 16) catch 0;
                    }
                }

                if (mi) |m| {
                    if (m.len == 5) {
                        self.mi = std.fmt.parseInt(u8, m[3..], 16) catch 0;
                    }
                }
            }

            // Extract Serial and Other Device ID
            const serial = device_tokens.next();
            if (serial) |s| {
                var serial_tokens = std.mem.tokenizeAny(u8, s, "&");

                // This can either be the depth or the serial
                const first = serial_tokens.next();
                if (first) |f| {
                    if (f.len == 1) {
                        self.depth = std.fmt.parseUnsigned(u8, f, 10) catch 0;
                    } else {
                        self.serial = f;
                    }
                }

                if (self.serial.len == 0) {
                    const ser = serial_tokens.next();

                    // If the serial hasn't been updated that means a depth was found
                    if (ser) |token| {
                        self.serial = token;
                    }

                    // Skip over &0&
                    _ = serial_tokens.next();

                    // Interface Number
                    const iface = serial_tokens.next();
                    if (iface) |token| {
                        self.interface_num = std.fmt.parseUnsigned(u8, token, 16) catch 0;
                    }
                }
            }

            const guid = device_tokens.next();
            if (guid) |g| {
                const end = std.mem.indexOf(u8, g, &[_]u8{0}) orelse g.len;
                var guid_tokens = std.mem.tokenizeAny(u8, g[1 .. end - 1], "-");

                const data1 = guid_tokens.next();
                if (data1) |d| {
                    self.interface_guid.Data1 = std.fmt.parseUnsigned(c_ulong, d, 16) catch 0;
                }

                const data2 = guid_tokens.next();
                if (data2) |d| {
                    self.interface_guid.Data2 = std.fmt.parseUnsigned(c_ushort, d, 16) catch 0;
                }

                const data3 = guid_tokens.next();
                if (data3) |d| {
                    self.interface_guid.Data3 = std.fmt.parseUnsigned(c_ushort, d, 16) catch 0;
                }

                const data4a = guid_tokens.next();
                if (data4a) |d| {
                    if (d.len == 4) {
                        for (0..2) |i| {
                            self.interface_guid.Data4[i] = std.fmt.parseUnsigned(u8, d[i * 2 .. i * 2 + 1], 16) catch 0;
                        }
                    }
                }

                const data4b = guid_tokens.next();
                if (data4b) |d| {
                    if (d.len == 12) {
                        for (0..6) |i| {
                            self.interface_guid.Data4[i + 2] = std.fmt.parseUnsigned(u8, d[i * 2 .. i * 2 + 1], 16) catch 0;
                        }
                    }
                }
            }
        }
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
