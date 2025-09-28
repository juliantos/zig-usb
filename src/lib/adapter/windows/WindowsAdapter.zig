const std = @import("std");
const win = std.os.windows;
const setup_api = @cImport({
    @cInclude("windows.h");
    @cInclude("setupapi.h");
    @cInclude("guiddef.h");
});
const WindowsDevice = @import("WindowsDevice.zig").WindowsDevice;
const WindowsHostController = @import("WindowsHostController.zig").WindowsHostController;
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

pub const WindowsAdapter = struct {
    const Self = @This();

    device_handle: setup_api.HDEVINFO,
    hub_handle: setup_api.HDEVINFO,
    controller_handle: setup_api.HDEVINFO,

    pub fn init() Self {
        return Self{
            .device_handle = setup_api.SetupDiGetClassDevsW(
                &GUID_DEVINTERFACE_USB_DEVICE,
                null,
                null,
                setup_api.DIGCF_PRESENT | setup_api.DIGCF_DEVICEINTERFACE,
            ),
            .hub_handle = setup_api.SetupDiGetClassDevsW(
                &GUID_DEVINTERFACE_USB_HUB,
                null,
                null,
                setup_api.DIGCF_PRESENT | setup_api.DIGCF_DEVICEINTERFACE,
            ),
            .controller_handle = setup_api.SetupDiGetClassDevsW(
                &GUID_DEVINTERFACE_USB_HOST_CONTROLLER,
                null,
                null,
                setup_api.DIGCF_PRESENT | setup_api.DIGCF_DEVICEINTERFACE,
            ),
        };
    }

    pub fn deinit(self: Self) void {
        _ = self;
        return;
    }

    pub fn deinitDevice(self: Self, device: WindowsDevice) void {
        _ = self;
        device.deinit();
    }

    pub fn getDevices(self: Self, allocator: std.mem.Allocator) ![]DeviceData {
        var devices = std.array_list.Managed(DeviceData).init(allocator);

        const windows_host_controllers = try WindowsHostController.enumerateControllers(allocator, self.controller_handle);
        defer {
            for (windows_host_controllers) |controller| {
                controller.deinit();
            }
            allocator.free(windows_host_controllers);
        }

        for (windows_host_controllers) |controller| {
            std.debug.print("Controller: {s}\n", .{try controller.getPath()});
        }

        // const windows_devices = try WindowsDevice.enumerateDevices(allocator, self.device_handle);
        // defer allocator.free(windows_devices);
        // const windows_hubs = try WindowsDevice.enumerateHubs(allocator, self.hub_handle);
        // defer allocator.free(windows_hubs);
        // for (windows_devices) |device| {
        //     const path = device.getPath() catch {
        //         device.deinit();
        //         continue;
        //     };
        //     try devices.append(DeviceData{
        //         .adapter = self,
        //         .handle = device,
        //         .open = false,
        //         .path = path,
        //     });
        // }
        // // TODO: Maybe Place in array of non-forward facing devices
        // for (windows_hubs) |device| {
        //     const path = device.getPath() catch {
        //         device.deinit();
        //         continue;
        //     };
        //     try devices.append(DeviceData{
        //         .adapter = self,
        //         .handle = device,
        //         .open = false,
        //         .path = path,
        //     });
        // }
        return devices.toOwnedSlice();
    }
};
