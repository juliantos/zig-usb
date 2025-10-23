const std = @import("std");
const Descriptor = @import("Descriptor.zig").Descriptor;
const DescriptorType = @import("Descriptor.zig").DescriptorType;
const UsbError = @import("../error.zig").UsbError;

pub const EndpointDescriptor = packed struct {
    descriptor: Descriptor,
    endpoint_address: u8,
    attributes: u8,
    max_packet_size: u16,
    interval: u8,

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader, descriptor: ?Descriptor) !EndpointDescriptor {
        var len: u8 = DescriptorType.Endpoint.size();
        if (descriptor) |d| {
            len = d.length;
        }
        const ptr = try reader.readAlloc(allocator, len);
        defer allocator.free(ptr);

        var desc: EndpointDescriptor = undefined;
        const max = @min(len, @sizeOf(EndpointDescriptor));
        std.mem.copyForwards(u8, @as([]u8, @ptrCast(&desc)), ptr[0..max]);

        if (desc.descriptor.type != DescriptorType.Endpoint) {
            return UsbError.DescriptorDoesNotMatch;
        }
        return desc;
    }
};

pub const EndpointDescriptorTree = struct {
    const Self = @This();

    descriptor: EndpointDescriptor,

    pub fn init(allocator: std.mem.Allocator, descriptor: EndpointDescriptor) !EndpointDescriptorTree {
        _ = allocator;
        return EndpointDescriptorTree{
            .descriptor = descriptor,
        };
    }

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader) !EndpointDescriptorTree {
        if (Descriptor.peek(reader)) |descriptor| {
            if (descriptor.type == .Endpoint) {
                const endpoint = try EndpointDescriptor.read(allocator, reader, descriptor);
                const endpoint_tree = try EndpointDescriptorTree.init(allocator, endpoint);

                return endpoint_tree;
            } else {
                return UsbError.NoDescriptor;
            }
        } else |err| {
            return err;
        }
        @panic("Read Endpoint");
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }
};
