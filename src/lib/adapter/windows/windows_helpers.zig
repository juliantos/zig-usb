const std = @import("std");
const windows = std.os.windows;
const setup_api = @cImport({
    @cInclude("windows.h");
    @cInclude("setupapi.h");
    @cInclude("guiddef.h");
});
const iodef = @cImport({
    @cInclude("windows.h");
    @cInclude("usbiodef.h");
});
const WindowsError = @import("WindowsError.zig").WindowsError;

fn CTL_CODE(device_type: u32, function: u32, method: u32, access: u32) u32 {
    return (device_type << 16) | (access << 14) | (function << 2) | method;
}

pub const IOCTL_USB_GET_ROOT_HUB_NAME = CTL_CODE(iodef.FILE_DEVICE_USB, iodef.HCD_GET_ROOT_HUB_NAME, iodef.METHOD_BUFFERED, iodef.FILE_ANY_ACCESS);
pub const IOCTL_USB_GET_NODE_INFORMATION = CTL_CODE(iodef.FILE_DEVICE_USB, iodef.USB_GET_NODE_INFORMATION, iodef.METHOD_BUFFERED, iodef.FILE_ANY_ACCESS);
pub const IOCTL_USB_GET_HUB_INFORMATION_EX = CTL_CODE(iodef.FILE_DEVICE_USB, iodef.USB_GET_HUB_INFORMATION_EX, iodef.METHOD_BUFFERED, iodef.FILE_ANY_ACCESS);
pub const IOCTL_USB_GET_HUB_CAPABILITIES_EX = CTL_CODE(iodef.FILE_DEVICE_USB, iodef.USB_GET_HUB_CAPABILITIES_EX, iodef.METHOD_BUFFERED, iodef.FILE_ANY_ACCESS);
pub const IOCTL_USB_GET_PORT_CONNECTOR_PROPERTIES = CTL_CODE(iodef.FILE_DEVICE_USB, iodef.USB_GET_PORT_CONNECTOR_PROPERTIES, iodef.METHOD_BUFFERED, iodef.FILE_ANY_ACCESS);

pub const UsbCapFlags = packed struct {
    HubIsHighSpeedCapable: u1 = std.mem.zeroes(u1),
    HubIsHighSpeed: u1 = std.mem.zeroes(u1),
    HubIsMultiTtCapable: u1 = std.mem.zeroes(u1),
    HubIsMultiTt: u1 = std.mem.zeroes(u1),
    HubIsRoot: u1 = std.mem.zeroes(u1),
    HubIsArmedWakeOnConnect: u1 = std.mem.zeroes(u1),
    HubIsBusPowered: u1 = std.mem.zeroes(u1),
    ReservedMBZ: u25 = std.mem.zeroes(u25),
};
pub const USB_HUB_CAPABILITES_EX = struct {
    CapabilityFlags: UsbCapFlags,
};

pub const UsbPortPropertiesFlags = packed struct {
    PortIsUserConnectable: u1 = std.mem.zeroes(u1),
    PortIsDebugCapable: u1 = std.mem.zeroes(u1),
    PortHasMultipleCompanions: u1 = std.mem.zeroes(u1),
    PortConnectorIsTypeC: u1 = std.mem.zeroes(u1),
    ReservedMBZ: u28 = std.mem.zeroes(u28),
};
pub const USB_PORT_CONNECTOR_PROPERTIES = struct {
    ConnectionIndex: c_ulong = @import("std").mem.zeroes(c_ulong),
    ActualLength: c_ulong = @import("std").mem.zeroes(c_ulong),
    UsbPortProperties: UsbPortPropertiesFlags,
    CompanionIndex: c_ushort = @import("std").mem.zeroes(c_ushort),
    CompanionPortNumber: c_ushort = @import("std").mem.zeroes(c_ushort),
    // CompanionHubSymbolicLinkName: [1]u16 = @import("std").mem.zeroes([1]u16),
};
pub const USB_PORT_CONNECTOR_PROPERTIES_SIZE = 18;

pub fn getDeviceProperty(allocator: std.mem.Allocator, handle: setup_api.HDEVINFO, device_info: setup_api.PSP_DEVINFO_DATA, property: windows.DWORD) ![]windows.WCHAR {
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
