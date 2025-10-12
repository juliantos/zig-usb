const std = @import("std");
const descriptors = @import("usb-types").descriptors;
const LinuxError = @import("LinuxError.zig").LinuxError;
// const udev = @cImport({
//     @cInclude("libudev.h");
// });
const device = @cImport({
    @cInclude("systemd/sd-device.h");
});

const CreateState = enum {
    Device,
    Configs,
    General,
    Done,
    Error,
};

pub const LinuxDevice = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    ref: ?*device.sd_device,
    path: []const u8,
    desc: descriptors.DeviceDescriptorTree,

    pub fn init(allocator: std.mem.Allocator, ref: ?*device.sd_device) !Self {
        var path: [*c]u8 = null;
        if (device.sd_device_get_syspath(ref, @ptrCast(&path)) == 0 and path != null) {
            const path_slice = std.mem.span(path);
            return Self{
                .allocator = allocator,
                .ref = ref,
                .path = path_slice,
                .desc = try readDescriptors(allocator, path_slice),
            };
        } else {
            return LinuxError.NoDeviceSysPath;
        }
    }

    pub fn deinit(self: Self) void {
        if (self.ref) |r| {
            _ = device.sd_device_unref(r);
        }
        self.desc.deinit();
    }

    pub inline fn getPath(self: Self) ![:0]const u8 {
        return self.path;
    }

    pub fn getPID(self: Self) u16 {
        _ = self;
        return 0;
    }

    pub fn getVID(self: Self) u16 {
        _ = self;
        return 0;
    }

    pub fn getDescriptors(self: Self) !descriptors.DeviceDescriptor {
        _ = self;
        return LinuxError.NoDescriptors;
    }

    pub fn enumerateDevice(allocator: std.mem.Allocator) ![]LinuxDevice {
        var devices = std.array_list.Managed(LinuxDevice).init(allocator);

        var enumerator: ?*device.sd_device_enumerator = null;
        var r = device.sd_device_enumerator_new(&enumerator);
        if (r < 0) {
            return LinuxError.NoDeviceEnum;
        }

        r = device.sd_device_enumerator_add_match_subsystem(enumerator, "usb", 1);
        if (r < 0) {
            return LinuxError.NoDeviceEnumSubsystem;
        }

        var dev = device.sd_device_enumerator_get_device_first(enumerator);
        while (dev != null) {
            var devname: [*c]u8 = null;
            if (device.sd_device_get_devname(dev, @ptrCast(&devname)) == 0 and devname != null) {
                if (LinuxDevice.init(allocator, device.sd_device_ref(dev))) |linux_device| {
                    devices.append(linux_device) catch {
                        linux_device.deinit();
                    };
                } else |_| {}
            }
            dev = device.sd_device_enumerator_get_device_next(enumerator);
        }

        if (device.sd_device_enumerator_unref(enumerator) != null) {
            for (devices.items) |d| {
                d.deinit();
            }
            devices.deinit();
            return LinuxError.NoDeviceEnumUnref;
        }

        return devices.toOwnedSlice();
    }
};

fn readDescriptors(allocator: std.mem.Allocator, syspath: []const u8) !descriptors.DeviceDescriptorTree {
    const descriptor_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ syspath, "descriptors" });
    defer {
        allocator.free(descriptor_path);
    }
    try std.fs.accessAbsolute(descriptor_path, .{});
    const file = try std.fs.openFileAbsolute(descriptor_path, .{ .mode = .read_only });
    defer file.close();
    const size = (try file.stat()).size;

    var buffer: [16384]u8 = undefined;
    var freader = file.reader(&buffer);
    const reader = &freader.interface;

    return createDescriptorTree(allocator, reader, size);
}

fn createDescriptorTree(allocator: std.mem.Allocator, reader: *std.io.Reader, size: u64) !descriptors.DeviceDescriptorTree {
    var state = CreateState.Device;
    var bytes_read: u64 = 0;
    var dev: descriptors.DeviceDescriptorTree = undefined;
    var num_configs: u8 = 0;
    var num_interfaces: u8 = 0;
    var num_endpoints: u8 = 0;
    create: while (bytes_read < size and state != .Error) { // Read Bytes until EOF
        if (descriptors.peekDescriptor(reader)) |descriptor| {
            switch (state) {
                .Device => {
                    switch (descriptor.type) {
                        .Device => {
                            const d = try descriptors.readDescriptorToType(allocator, reader, descriptor, descriptors.DeviceDescriptor);
                            dev = try descriptors.DeviceDescriptorTree.init(allocator, d);
                            num_configs = dev.descriptor.num_configurations;
                            state = .Configs;
                        },
                        else => {
                            state = .Error;
                        },
                    }
                },
                .Configs => {
                    switch (descriptor.type) {
                        .Configuration => {
                            const c = try descriptors.readDescriptorToType(allocator, reader, descriptor, descriptors.ConfigurationDescriptor);
                            const config = try descriptors.ConfigurationDescriptorTree.init(allocator, c);
                            dev.configurations.append(config) catch {
                                config.deinit();
                                state = .Error;
                                break;
                            };
                            num_configs -= 1; // TODO: Handle Underflow when too many configs
                            num_interfaces = config.descriptor.num_interfaces;
                            state = .General;
                        },
                        else => state = .Error,
                    }
                },
                .General => {
                    switch (descriptor.type) {
                        .Interface => {
                            const i = try descriptors.readDescriptorToType(allocator, reader, descriptor, descriptors.InterfaceDescriptor);
                            const interface = try descriptors.InterfaceDescriptorTree.init(allocator, i);
                            var config = &dev.configurations.items[dev.configurations.items.len - 1];
                            if (config.addInterface(interface)) |_| {
                                num_endpoints = interface.descriptor.num_endpoints;
                                if (i.alternate_setting == 0) {
                                    num_interfaces -= 1; // TODO: Handle Underflow when too many interfaces
                                }
                            } else |_| {
                                state = .Error;
                            }
                        },
                        .Association => {
                            const a = try descriptors.readDescriptorToType(allocator, reader, descriptor, descriptors.AssociationDescriptor);
                            const association = try descriptors.AssociationDescriptorTree.init(allocator, a);
                            var config = &dev.configurations.items[dev.configurations.items.len - 1];
                            config.addAssociation(association) catch {
                                state = .Error;
                            };
                        },
                        .Endpoint => {
                            const e = try descriptors.readDescriptorToType(allocator, reader, descriptor, descriptors.EndpointDescriptor);
                            const endpoint = try descriptors.EndpointDescriptorTree.init(allocator, e);
                            var config = &dev.configurations.items[dev.configurations.items.len - 1];
                            var interface = config.getCurrentInterface() catch {
                                state = .Error;
                                break;
                            };
                            if (interface.addEndpoint(endpoint)) |_| {
                                num_endpoints -= 1; // TODO: Handle Underflow when a bad descriptor is presented
                            } else |_| {
                                state = .Error;
                            }
                        },
                        .Device, .Configuration => {
                            state = .Error;
                            @panic("Switch Back to configurations");
                        },
                        else => {
                            try descriptors.readDescriptorToNull(allocator, reader, descriptor);
                            std.debug.print("Handle Descriptor Type 0x{x:0>2}\n", .{descriptor.type});
                        },
                    }
                },
                .Done => {
                    bytes_read = size;
                    break :create;
                },
                .Error => {
                    bytes_read = size;
                    break :create;
                },
            }
            bytes_read += descriptor.length;
        } else |err| {
            switch (err) {
                std.io.Reader.Error.EndOfStream => {
                    break;
                },
                else => return err,
            }
        }
    }

    if (state == .Error) {
        std.debug.print("Device-Error: {any}\n", .{dev});
        dev.deinit();
        return LinuxError.NoDescriptors;
    }

    std.debug.print("Device: {any}\n", .{dev});

    return dev;
}
