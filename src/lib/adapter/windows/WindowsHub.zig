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
const WindowsError = @import("WindowsError.zig").WindowsError;
const WindowsDevice = @import("WindowsDevice.zig").WindowsDevice;
const windows_helpers = @import("windows_helpers.zig");

const Port = union {
    hub: WindowsHub,
    dev: WindowsDevice,
};

const ConnectorProperties = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    data: []u8,

    fn UsbPortConnectorProperties(self: Self) !*windows_helpers.USB_PORT_CONNECTOR_PROPERTIES {
        if (self.data.len >= @sizeOf(windows_helpers.USB_PORT_CONNECTOR_PROPERTIES)) {
            return @ptrCast(@alignCast(self.data));
        }

        return WindowsError.NoPortProperties;
    }
};

pub const WindowsHub = struct {
    const Self = @This();

    name: std.array_list.Managed(u8),
    ports: u8,

    fp: *anyopaque,

    pub fn init(allocator: std.mem.Allocator, handle: setup_api.HDEVINFO, guid: setup_api.GUID, index: u32) !Self {
        _ = allocator;
        _ = handle;
        _ = guid;
        _ = index;
        @panic("Haven't Spec'd out building Hub from Identifier");
    }

    pub fn initName(allocator: std.mem.Allocator, name: [:0]const u8) !Self {
        const prefix = [_]u8{ '\\', '\\', '.', '\\' };

        const buf = try allocator.alloc(u8, prefix.len + name.len);
        const full_hub_name = try std.fmt.bufPrint(buf, "{s}{s}", .{ prefix, name });
        defer {
            allocator.free(buf);
        }
        const full_hub_name_wide = try std.unicode.utf8ToUtf16LeAllocZ(allocator, full_hub_name);
        defer {
            allocator.free(full_hub_name_wide);
        }

        const fp = windows.kernel32.CreateFileW(
            full_hub_name_wide,
            windows.GENERIC_WRITE,
            windows.FILE_SHARE_WRITE,
            null,
            windows.OPEN_EXISTING,
            0,
            null,
        );
        if (fp == windows.INVALID_HANDLE_VALUE) {
            return WindowsError.NoHub;
        }

        var hub = Self{
            .name = std.array_list.Managed(u8).init(allocator),
            .ports = 0,

            .fp = fp,
        };
        try hub.name.appendSlice(full_hub_name);

        hub.enumerate(allocator) catch |err| {
            hub.deinit();
            return err;
        };

        return hub;
    }

    pub fn deinit(self: Self) void {
        self.name.deinit();

        windows.CloseHandle(self.fp);
    }

    pub fn getName(self: Self) ![:0]const u8 {
        return self.name.items[0 .. self.name.items.len - 1 :0];
    }

    fn enumerate(self: *Self, allocator: std.mem.Allocator) !void {
        const node_info = try self.getNodeInfo(allocator);
        defer allocator.destroy(node_info);
        const hub_info = try self.getHubInfo(allocator);
        defer allocator.destroy(hub_info);
        const hub_caps = try self.getHubCapabilities(allocator);
        defer allocator.destroy(hub_caps);
        // std.debug.print("Info {any}\n", .{node_info.u.HubInformation.HubDescriptor});
        // std.debug.print("Info {any}\n", .{hub_info});
        // std.debug.print("Info {any}\n", .{hub_caps.CapabilityFlags.unamed_0});

        self.ports = node_info.u.HubInformation.HubDescriptor.bNumberOfPorts;

        for (1..self.ports + 1) |i| {
            _ = self.enumeratePort(allocator, i) catch {};
        }
    }

    fn enumeratePort(self: *Self, allocator: std.mem.Allocator, index: usize) !Port {
        const props = self.getPortConnectorProperties(allocator, index) catch |err| {
            std.debug.print("Error: {}\n", .{err});
            return err;
        };
        defer {
            if (props.data.len > 0) {
                props.allocator.free(props.data);
            }
        }

        std.debug.print("Port {any}\n", .{props.UsbPortConnectorProperties()});

        return WindowsError.EmptyPort;
    }

    fn getNodeInfo(self: Self, allocator: std.mem.Allocator) !*usb.USB_NODE_INFORMATION {
        const ptr = try allocator.create(usb.USB_NODE_INFORMATION);
        var num_bytes: u32 = 0;

        const result = io.DeviceIoControl(
            self.fp,
            windows_helpers.IOCTL_USB_GET_NODE_INFORMATION,
            ptr,
            @sizeOf(usb.USB_NODE_INFORMATION),
            ptr,
            @sizeOf(usb.USB_NODE_INFORMATION),
            &num_bytes,
            null,
        );

        if (result == 0) {
            @branchHint(.unlikely);
            allocator.destroy(ptr);
            return WindowsError.NoNodeInformation;
        }

        return ptr;
    }

    fn getHubInfo(self: Self, allocator: std.mem.Allocator) !*usb.USB_HUB_INFORMATION_EX {
        const ptr = try allocator.create(usb.USB_HUB_INFORMATION_EX);
        var num_bytes: u32 = 0;

        const result = io.DeviceIoControl(
            self.fp,
            windows_helpers.IOCTL_USB_GET_HUB_INFORMATION_EX,
            ptr,
            @sizeOf(usb.USB_HUB_INFORMATION_EX),
            ptr,
            @sizeOf(usb.USB_HUB_INFORMATION_EX),
            &num_bytes,
            null,
        );

        if (result == 0) {
            @branchHint(.unlikely);
            allocator.destroy(ptr);
            return WindowsError.NoHubInformation;
        }

        return ptr;
    }

    fn getHubCapabilities(self: Self, allocator: std.mem.Allocator) !*windows_helpers.USB_HUB_CAPABILITES_EX {
        const ptr = try allocator.create(windows_helpers.USB_HUB_CAPABILITES_EX);
        var num_bytes: u32 = 0;

        const result = io.DeviceIoControl(
            self.fp,
            windows_helpers.IOCTL_USB_GET_HUB_CAPABILITIES_EX,
            ptr,
            @sizeOf(windows_helpers.USB_HUB_CAPABILITES_EX),
            ptr,
            @sizeOf(windows_helpers.USB_HUB_CAPABILITES_EX),
            &num_bytes,
            null,
        );

        if (result == 0) {
            @branchHint(.unlikely);
            allocator.destroy(ptr);
            return WindowsError.NoHubCapabilities;
        }

        return ptr;
    }

    fn getPortConnectorProperties(self: Self, allocator: std.mem.Allocator, index: usize) !ConnectorProperties {
        var mem = try allocator.alloc(u8, windows_helpers.USB_PORT_CONNECTOR_PROPERTIES_SIZE);
        @memset(mem, 0);
        var ptr: *windows_helpers.USB_PORT_CONNECTOR_PROPERTIES = @ptrCast(@alignCast(mem));
        var num_bytes: u32 = 0;

        ptr.ConnectionIndex = @truncate(index);

        var result = io.DeviceIoControl(
            self.fp,
            windows_helpers.IOCTL_USB_GET_PORT_CONNECTOR_PROPERTIES,
            ptr,
            windows_helpers.USB_PORT_CONNECTOR_PROPERTIES_SIZE,
            ptr,
            windows_helpers.USB_PORT_CONNECTOR_PROPERTIES_SIZE,
            &num_bytes,
            null,
        );

        if (result == 0) {
            @branchHint(.unlikely);
            allocator.free(mem);
            return WindowsError.NoPortProperties;
        }

        const size = ptr.*.ActualLength;
        if (size > windows_helpers.USB_PORT_CONNECTOR_PROPERTIES_SIZE) {
            if (allocator.resize(mem, size)) {
                std.debug.print("Resized!\n", .{});
            } else {
                mem = try allocator.realloc(mem, size);
                ptr = @ptrCast(@alignCast(mem));
            }

            result = io.DeviceIoControl(
                self.fp,
                windows_helpers.IOCTL_USB_GET_PORT_CONNECTOR_PROPERTIES,
                ptr,
                size,
                ptr,
                size,
                &num_bytes,
                null,
            );

            if (result == 0) {
                @branchHint(.unlikely);
                allocator.free(mem);
                return WindowsError.NoPortProperties;
            }
        }

        const props = ConnectorProperties{
            .allocator = allocator,
            .data = mem,
        };

        return props;
    }
};
