const std = @import("std");
const descriptors = @import("../descriptors.zig");
const Descriptor = @import("Descriptor.zig").Descriptor;
const DescriptorType = @import("Descriptor.zig").DescriptorType;
const InterfaceDescriptor = @import("Interface.zig").InterfaceDescriptor;
const UsbError = @import("../error.zig").UsbError;

pub const EndpointDescriptor = packed struct {
    descriptor: Descriptor,
    endpoint_address: u8,
    attributes: u8,
    max_packet_size: u16,
    interval: u8,

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader, descriptor: ?Descriptor) !*EndpointDescriptor {
        var len: u8 = DescriptorType.Endpoint.size();
        if (descriptor) |d| {
            len = d.length;
        }
        const ptr: *EndpointDescriptor = @ptrCast(@alignCast(try reader.readAlloc(allocator, len)));

        if (ptr.descriptor.type != DescriptorType.Endpoint) {
            return UsbError.DescriptorDoesNotMatch;
        }
        return ptr;
    }
};

pub const EndpointDescriptorTree = struct {
    const Self = @This();

    descriptor: *EndpointDescriptor,
    sub_descriptors: std.array_list.Managed(descriptors.class.endpoint.EndpointClassDescriptor),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, descriptor: *EndpointDescriptor) !EndpointDescriptorTree {
        return EndpointDescriptorTree{
            .descriptor = descriptor,
            .sub_descriptors = std.array_list.Managed(descriptors.class.endpoint.EndpointClassDescriptor).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader, interface: *const InterfaceDescriptor) !EndpointDescriptorTree {
        if (Descriptor.peek(reader)) |descriptor| {
            if (descriptor.type == .Endpoint) {
                const endpoint = try EndpointDescriptor.read(allocator, reader, descriptor);
                var endpoint_tree = try EndpointDescriptorTree.init(allocator, endpoint);

                if (Descriptor.peek(reader)) |next| {
                    if (next.type == .ClassSpecificationEndpoint) {
                        const endpoint_class = try descriptors.class.endpoint.EndpointClassDescriptor.read(allocator, reader, interface);
                        endpoint_tree.addEndpointClassDescriptor(endpoint_class) catch |err| {
                            endpoint_tree.deinit();
                            return err;
                        };
                    }
                } else |err| {
                    switch (err) {
                        error.ReadFailed => {
                            endpoint_tree.deinit();
                            return err;
                        },
                        else => {},
                    }
                }

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
        for (self.sub_descriptors.items) |*descriptor| {
            descriptor.deinit();
        }
        self.sub_descriptors.deinit();

        descriptors.freeDescriptorTypePtr(EndpointDescriptor, self.allocator, self.descriptor);
    }

    pub fn addEndpointClassDescriptor(self: *Self, descriptor: descriptors.class.endpoint.EndpointClassDescriptor) !void {
        try self.sub_descriptors.append(descriptor);
    }
};
