const std = @import("std");
const win = std.os.windows;
const setup_api = @cImport({
    @cInclude("windows.h");
    @cInclude("setupapi.h");
    @cInclude("guiddef.h");
});
const win_usb = @cImport({
    @cInclude("winusb.h");
    @cInclude("usbspec.h");
});
const Context = @import("usb-types").Context;
const DeviceData = @import("usb-types").DeviceData;
const DeviceDescriptor = @import("usb-types").DeviceDescriptor;
const Handle = @import("usb-types").Handle;
const UsbError = @import("usb-types").UsbError;

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

pub const Driver = struct {
    const Self = @This();

    context: Context,

    pub fn init() Self {
        return Self{
            .context = setup_api.SetupDiGetClassDevsW(
                &GUID_DEVINTERFACE_USB_DEVICE,
                null,
                null,
                setup_api.DIGCF_PRESENT | setup_api.DIGCF_DEVICEINTERFACE,
            ),
        };
    }

    pub fn GetDevices(self: Self) !std.ArrayList(DeviceData) {
        var interface_data: setup_api.SP_DEVICE_INTERFACE_DATA = undefined;
        var result: win.BOOL = win.TRUE;
        var index: u32 = 0;
        var required_length: u32 = 0;
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();
        var devices = std.ArrayList(DeviceData).init(allocator);
        defer {
            _ = gpa.deinit();
        }

        if (self.context != setup_api.INVALID_HANDLE_VALUE) {
            interface_data.cbSize = @sizeOf(setup_api.SP_DEVICE_INTERFACE_DATA);

            result = setup_api.SetupDiEnumDeviceInterfaces(
                self.context,
                null,
                &GUID_DEVINTERFACE_USB_DEVICE,
                index,
                &interface_data,
            );

            while (result != win.FALSE) {
                result = setup_api.SetupDiGetDeviceInterfaceDetailW(self.context, &interface_data, null, 0, &required_length, null);

                if (result != win.TRUE) {
                    switch (win.kernel32.GetLastError()) {
                        win.Win32Error.INSUFFICIENT_BUFFER => {},
                        else => {
                            interface_data = undefined;
                            interface_data.cbSize = @sizeOf(setup_api.SP_DEVINFO_DATA);
                            index += 1;
                            result = setup_api.SetupDiEnumDeviceInterfaces(
                                self.context,
                                null,
                                &GUID_DEVINTERFACE_USB_DEVICE,
                                index,
                                &interface_data,
                            );
                            continue;
                        },
                    }
                }

                var buffer: [win.MAX_PATH * 2 + @sizeOf(win.WCHAR)]u8 align(16) = std.mem.zeroes([win.MAX_PATH * 2 + @sizeOf(win.WCHAR)]u8);
                var fba = std.heap.FixedBufferAllocator.init(&buffer);

                const detail_data = fba.allocator().create(setup_api.SP_DEVICE_INTERFACE_DETAIL_DATA_W) catch break;
                detail_data.*.cbSize = @sizeOf(setup_api.SP_DEVICE_INTERFACE_DETAIL_DATA_W);
                const length = required_length;

                result = setup_api.SetupDiGetDeviceInterfaceDetailW(
                    self.context,
                    &interface_data,
                    detail_data,
                    length,
                    &required_length,
                    null,
                );

                if (result != win.TRUE) {
                    defer {
                        allocator.destroy(detail_data);
                    }
                    interface_data = undefined;
                    interface_data.cbSize = @sizeOf(setup_api.SP_DEVINFO_DATA);
                    index += 1;
                    result = setup_api.SetupDiEnumDeviceInterfaces(
                        self.context,
                        null,
                        &GUID_DEVINTERFACE_USB_DEVICE,
                        index,
                        &interface_data,
                    );
                    continue;
                }

                var gpa_device = std.heap.GeneralPurposeAllocator(.{}){};
                var device: DeviceData = undefined;
                device.path = std.ArrayList(u8).init(gpa_device.allocator());
                var flexible_ptr: [*]win.WCHAR = &detail_data.DevicePath;
                const flexible_array: [:0]win.WCHAR = @ptrCast(flexible_ptr[0..length]);
                std.unicode.utf16LeToUtf8ArrayList(&device.path, flexible_array) catch {
                    defer {
                        _ = gpa_device.deinit();
                    }
                    break;
                };

                var gpa_path = std.heap.GeneralPurposeAllocator(.{}){};
                const path = std.unicode.utf8ToUtf16LeWithNull(gpa_path.allocator(), device.path.items) catch &[_:0]win.WCHAR{};
                defer {
                    gpa_path.allocator().free(path);
                    _ = gpa_path.deinit();
                }
                device.file_handle = win.kernel32.CreateFileW(
                    path,
                    win.GENERIC_READ | win.GENERIC_WRITE,
                    win.FILE_SHARE_READ | win.FILE_SHARE_WRITE,
                    null,
                    win.OPEN_EXISTING,
                    win.FILE_ATTRIBUTE_NORMAL | win.FILE_FLAG_OVERLAPPED,
                    null,
                );

                if (device.file_handle == win.INVALID_HANDLE_VALUE) {
                    _ = win.kernel32.CloseHandle(device.file_handle.?);
                    defer {
                        device.path.deinit();
                        _ = gpa_device.deinit();
                    }
                    index += 1;
                    result = setup_api.SetupDiEnumDeviceInterfaces(
                        self.context,
                        null,
                        &GUID_DEVINTERFACE_USB_DEVICE,
                        index,
                        &interface_data,
                    );
                    continue;
                }

                result = win_usb.WinUsb_Initialize(device.file_handle, &device.handle);
                std.debug.print("Last Error {any} {any}\n", .{ device.file_handle, win.kernel32.GetLastError() });
                if (result == win.FALSE) {
                    win.CloseHandle(device.file_handle.?);
                    defer {
                        device.path.deinit();
                        _ = gpa_device.deinit();
                    }
                    index += 1;
                    result = setup_api.SetupDiEnumDeviceInterfaces(
                        self.context,
                        null,
                        &GUID_DEVINTERFACE_USB_DEVICE,
                        index,
                        &interface_data,
                    );
                    continue;
                }

                device.open = true;
                std.debug.print("{any}\n", .{device});
                devices.append(device) catch {};

                index += 1;
                result = setup_api.SetupDiEnumDeviceInterfaces(
                    self.context,
                    null,
                    &GUID_DEVINTERFACE_USB_DEVICE,
                    index,
                    &interface_data,
                );
            }
        } else {
            return UsbError.InvalidContext;
        }

        return devices;
    }

    pub fn GetDeviceDescriptor(self: Self, device_data: DeviceData) !DeviceDescriptor {
        _ = self;
        if (device_data.handle != win.INVALID_HANDLE_VALUE or
            device_data.file_handle != win.INVALID_HANDLE_VALUE or
            device_data.open == false)
        {
            var descriptor: DeviceDescriptor = undefined;
            //var length_out = 0;
            const result = win_usb.WinUsb_GetDescriptor(
                device_data.handle,
                win_usb.USB_DEVICE_DESCRIPTOR_TYPE,
                0,
                0,
                std.mem.asBytes(&descriptor),
                18,
                null,
            );
            if (result == win.TRUE) {
                return descriptor;
            } else {
                return UsbError.DriverFailure;
            }
        }

        return UsbError.InvalidContext;
    }
};
