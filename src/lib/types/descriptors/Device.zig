const std = @import("std");
const Descriptor = @import("Descriptor.zig").Descriptor;
const DescriptorType = @import("Descriptor.zig").DescriptorType;
const ConfigurationDescriptorTree = @import("Configuration.zig").ConfigurationDescriptorTree;
const UsbError = @import("../error.zig").UsbError;

pub const DeviceDescriptor = packed struct {
    descriptor: Descriptor,
    usb: u16,
    class: u8,
    subclass: u8,
    protocol: u8,
    max_packet_size: u8,
    id_vendor: u16,
    id_product: u16,
    device: u16,
    manufacturer: u8,
    product: u8,
    serial_number: u8,
    num_configurations: u8,

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader, descriptor: ?Descriptor) !DeviceDescriptor {
        var len: u8 = DescriptorType.Device.size();
        if (descriptor) |d| {
            len = d.length;
        }
        const ptr = try reader.readAlloc(allocator, len);
        defer allocator.free(ptr);

        var desc: DeviceDescriptor = undefined;
        const max = @min(len, @sizeOf(DeviceDescriptor));
        std.mem.copyForwards(u8, @as([]u8, @ptrCast(&desc)), ptr[0..max]);

        if (desc.descriptor.type != DescriptorType.Device) {
            return UsbError.DescriptorDoesNotMatch;
        }
        return desc;
    }
};

pub const DeviceDescriptorTree = struct {
    const Self = @This();

    descriptor: DeviceDescriptor,
    configurations: std.array_list.Managed(ConfigurationDescriptorTree),

    pub fn init(allocator: std.mem.Allocator, descriptor: DeviceDescriptor) !DeviceDescriptorTree {
        return DeviceDescriptorTree{
            .descriptor = descriptor,
            .configurations = std.array_list.Managed(ConfigurationDescriptorTree).init(allocator),
        };
    }

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader) !DeviceDescriptorTree {
        if (Descriptor.peek(reader)) |descriptor| {
            if (descriptor.type == .Device) {
                const device = try DeviceDescriptor.read(allocator, reader, descriptor);
                var dev_tree = try DeviceDescriptorTree.init(allocator, device);
                for (0..device.num_configurations) |_| {
                    if (ConfigurationDescriptorTree.read(allocator, reader)) |config| {
                        dev_tree.configurations.append(config) catch |err| {
                            dev_tree.deinit();
                            return err;
                        };
                    } else |err| {
                        dev_tree.deinit();
                        return err;
                    }
                }
                return dev_tree;
            } else {
                return UsbError.NoDescriptor;
            }
        } else |err| {
            return err;
        }
    }

    pub fn deinit(self: Self) void {
        for (self.configurations.items) |config| {
            config.deinit();
        }
        self.configurations.deinit();
    }

    // pub fn getCurrentConfig(self: *Self) !*ConfigurationDescriptorTree {
    //     var config: ?*ConfigurationDescriptorTree = null;
    //     const len = self.configurations.items.len;
    //     if (len > 0) {
    //         config = &self.configurations.items[len - 1];
    //     }

    //     if (config) |conf| {
    //         return conf;
    //     } else {
    //         return UsbError.NoDescriptor;
    //     }
    // }
};
