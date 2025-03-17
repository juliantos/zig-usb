const std = @import("std");
const win = std.os.windows;
const setup_api = @cImport({
    @cInclude("windows.h");
    @cInclude("setupapi.h");
    @cInclude("guiddef.h");
});
const WinDevice = @import("device.zig").WinDevice;
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

pub const Driver = struct {
    const Self = @This();

    device_context: Context,
    hub_context: Context,

    pub fn init() Self {
        return Self{
            .device_context = setup_api.SetupDiGetClassDevsW(
                &GUID_DEVINTERFACE_USB_DEVICE,
                null,
                null,
                setup_api.DIGCF_PRESENT | setup_api.DIGCF_DEVICEINTERFACE,
            ),
            .hub_context = setup_api.SetupDiGetClassDevsW(
                &GUID_DEVINTERFACE_USB_HUB,
                null,
                null,
                setup_api.DIGCF_PRESENT | setup_api.DIGCF_DEVICEINTERFACE,
            ),
        };
    }

    pub fn closeDevice(self: Self, device: *DeviceData) !void {
        _ = self;
        if (device.open and device.file_handle != null and device.file_handle != win.INVALID_HANDLE_VALUE) {
            win.CloseHandle(device.file_handle.?);
            device.file_handle = null;
        }
        // TODO close handle
    }

    pub fn GetDevices(self: Self, allocator: std.mem.Allocator) ![]DeviceData {
        var devices = std.ArrayList(DeviceData).init(allocator);

        const enumerated_devices = try EnumerateDevices(
            self.device_context,
            GUID_DEVINTERFACE_USB_DEVICE,
            allocator,
        );
        defer {
            for (enumerated_devices) |device| {
                device.deinit();
            }
            allocator.free(enumerated_devices);
        }

        const enumerated_hubs = try EnumerateDevices(
            self.hub_context,
            GUID_DEVINTERFACE_USB_HUB,
            allocator,
        );
        defer {
            for (enumerated_hubs) |device| {
                device.deinit();
            }
            allocator.free(enumerated_hubs);
        }

        return devices.toOwnedSlice();
        //var interface_data: setup_api.SP_DEVICE_INTERFACE_DATA = undefined;
        //var result: win.BOOL = win.TRUE;
        //var index: u32 = 0;
        //var required_length: u32 = 0;

        //if (self.context != setup_api.INVALID_HANDLE_VALUE) {
        //interface_data.cbSize = @sizeOf(setup_api.SP_DEVICE_INTERFACE_DATA);

        //result = setup_api.SetupDiEnumDeviceInterfaces(
        //self.context,
        //null,
        //&GUID_DEVINTERFACE_USB_DEVICE,
        //index,
        //&interface_data,
        //);

        //while (result != win.FALSE) {
        //result = setup_api.SetupDiGetDeviceInterfaceDetailW(self.context, &interface_data, null, 0, &required_length, null)

        //if (result != win.TRUE) {
        //switch (win.kernel32.GetLastError()) {
        //win.Win32Error.INSUFFICIENT_BUFFER => {},
        //else => {
        //interface_data = undefined;
        //interface_data.cbSize = @sizeOf(setup_api.SP_DEVINFO_DATA);
        //index += 1;
        //result = setup_api.SetupDiEnumDeviceInterfaces(
        //self.context,
        //null,
        //&GUID_DEVINTERFACE_USB_DEVICE,
        //index,
        //&interface_data,
        //);
        //continue;
        //},
        //}
        //}

        //var buffer: [win.MAX_PATH * 2 + @sizeOf(win.WCHAR)]u8 align(16) = std.mem.zeroes([win.MAX_PATH * 2 + @sizeOf(win.WCHAR)]u8);
        //var fba = std.heap.FixedBufferAllocator.init(&buffer);

        //const detail_data = fba.allocator().create(setup_api.SP_DEVICE_INTERFACE_DETAIL_DATA_W) catch break;
        //defer {
        //fba.allocator().destroy(detail_data);
        //}
        //detail_data.*.cbSize = @sizeOf(setup_api.SP_DEVICE_INTERFACE_DETAIL_DATA_W);
        //const length = required_length;

        //var info_data: setup_api.SP_DEVINFO_DATA = undefined;
        //info_data.cbSize = @sizeOf(setup_api.SP_DEVINFO_DATA);

        //result = setup_api.SetupDiGetDeviceInterfaceDetailW(
        //self.context,
        //&interface_data,
        //detail_data,
        //length,
        //&required_length,
        //&info_data,
        //);

        //if (result != win.TRUE) {
        //interface_data = undefined;
        //interface_data.cbSize = @sizeOf(setup_api.SP_DEVINFO_DATA);
        //index += 1;
        //result = setup_api.SetupDiEnumDeviceInterfaces(
        //self.context,
        //null,
        //&GUID_DEVINTERFACE_USB_DEVICE,
        //index,
        //&interface_data,
        //);
        //continue;
        //}

        //var device: DeviceData = try .initCapacity(allocator, length);
        //var flexible_ptr: [*]win.WCHAR = &detail_data.DevicePath;
        //const flexible_array: [:0]win.WCHAR = @ptrCast(flexible_ptr[0..length]);
        //std.unicode.utf16LeToUtf8ArrayList(&device.path, flexible_array[0..length]) catch {
        //device.deinit();
        //break;
        //};

        //device.file_handle = win.kernel32.CreateFileW(
        //flexible_array,
        //win.GENERIC_READ | win.GENERIC_WRITE,
        //win.FILE_SHARE_READ | win.FILE_SHARE_WRITE,
        //null,
        //win.OPEN_EXISTING,
        //win.FILE_ATTRIBUTE_NORMAL | win.FILE_FLAG_OVERLAPPED,
        //null,
        //);

        //if (device.file_handle == win.INVALID_HANDLE_VALUE) {
        //_ = win.CloseHandle(device.file_handle.?);
        //defer {
        //device.deinit();
        //}
        //index += 1;
        //result = setup_api.SetupDiEnumDeviceInterfaces(
        //self.context,
        //null,
        //&GUID_DEVINTERFACE_USB_DEVICE,
        //index,
        //&interface_data,
        //);
        //continue;
        //}

        //device.open = true;
        //try devices.append(device);

        //index += 1;
        //result = setup_api.SetupDiEnumDeviceInterfaces(
        //self.context,
        //null,
        //&GUID_DEVINTERFACE_USB_DEVICE,
        //index,
        //&interface_data,
        //);
        //}
        //} else {
        //return UsbError.InvalidContext;
        //}

        //return devices.toOwnedSlice();
    }

    //pub fn GetDeviceDescriptor(self: Self, device_data: DeviceData) !DeviceDescriptor {
    //_ = self;
    //if (device_data.handle != win.INVALID_HANDLE_VALUE or
    //device_data.file_handle != win.INVALID_HANDLE_VALUE or
    //device_data.open == false)
    //{
    //const descriptor: DeviceDescriptor = undefined;
    //const result = win.FALSE;
    ////var length_out = 0;
    ////const result = win_usb.WinUsb_GetDescriptor(
    ////device_data.handle,
    ////win_usb.USB_DEVICE_DESCRIPTOR_TYPE,
    ////0,
    ////0,
    ////std.mem.asBytes(&descriptor),
    ////18,
    ////null,
    ////);
    //if (result == win.TRUE) {
    //return descriptor;
    //} else {
    //return UsbError.DriverFailure;
    //}
    //}

    //return UsbError.InvalidContext;
    //}

};

fn EnumerateDevices(context: Context, guid: setup_api.GUID, allocator: std.mem.Allocator) ![]WinDevice {
    var index: u32 = 0;
    var devices = std.ArrayList(WinDevice).init(allocator);
    var err: win.Win32Error = .SUCCESS;

    if (context == win.INVALID_HANDLE_VALUE) {
        devices.deinit();
        return UsbError.DriverFailure;
    }

    while (err != win.Win32Error.NO_MORE_ITEMS) {
        var win_device: WinDevice = .init(allocator);
        var length: win.ULONG = 0;

        var result = setup_api.SetupDiEnumDeviceInfo(
            context,
            index,
            &win_device.device_info_data,
        );

        if (result == win.FALSE) {
            @branchHint(.unlikely);
            err = win.kernel32.GetLastError();
            index += 1;
            continue;
        }

        const description_name = GetDeviceProperty(
            context,
            &win_device.device_info_data,
            setup_api.SPDRP_DEVICEDESC,
            allocator,
        ) catch |get_err| {
            win_device.deinit();
            return get_err;
        };
        win_device.device_description = std.ArrayList(win.WCHAR).fromOwnedSlice(allocator, description_name);

        const driver_name = GetDeviceProperty(
            context,
            &win_device.device_info_data,
            setup_api.SPDRP_DRIVER,
            allocator,
        ) catch |get_err| {
            win_device.deinit();
            return get_err;
        };
        win_device.driver_key = std.ArrayList(win.WCHAR).fromOwnedSlice(allocator, driver_name);

        result = setup_api.SetupDiEnumDeviceInterfaces(
            context,
            0,
            &guid,
            index,
            &win_device.interface_data,
        );

        if (result == win.FALSE) {
            @branchHint(.unlikely);
            win_device.deinit();
            err = win.kernel32.GetLastError();
            index += 1;
            continue;
        }

        result = setup_api.SetupDiGetDeviceInterfaceDetailW(
            context,
            &win_device.interface_data,
            null,
            0,
            &length,
            null,
        );

        if (result != win.FALSE) {
            @branchHint(.unlikely);
            win_device.deinit();
            err = win.kernel32.GetLastError();
            index += 1;
            continue;
        }

        result = setup_api.SetupDiGetDeviceInterfaceDetailW(
            context,
            &win_device.interface_data,
            &win_device.device_interface_detail_data,
            length,
            &length,
            null,
        );

        try devices.append(win_device);

        index += 1;
    }

    return devices.toOwnedSlice();
}

fn GetDeviceProperty(context: Context, device_info: setup_api.PSP_DEVINFO_DATA, property: win.DWORD, allocator: std.mem.Allocator) ![]win.WCHAR {
    var result: win.BOOL = win.TRUE;
    var length: win.DWORD = 0;

    if (context == win.INVALID_HANDLE_VALUE) {
        return UsbError.DriverFailure;
    }

    result = setup_api.SetupDiGetDeviceRegistryPropertyW(
        context,
        device_info,
        property,
        null,
        null,
        0,
        &length,
    );

    if (length == 0 or result != win.FALSE) {
        return UsbError.DriverFailure; // TODO: Maybe other error
    }

    const buffer = try allocator.alloc(win.WCHAR, length / @sizeOf(win.WCHAR));

    result = win.TRUE;

    result = setup_api.SetupDiGetDeviceRegistryPropertyW(
        context,
        device_info,
        property,
        null,
        @ptrCast(buffer),
        length,
        &length,
    );

    if (result == win.FALSE) {
        allocator.free(buffer);
        return UsbError.DriverFailure;
    }

    return buffer;
}
