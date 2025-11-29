const std = @import("std");
const descriptors = @import("../descriptors.zig");
const class = descriptors.class;

const UsbError = @import("../error.zig").UsbError;

const Descriptor = descriptors.Descriptor;
const DescriptorType = descriptors.DescriptorType;
const EndpointDescriptorTree = descriptors.EndpointDescriptorTree;
const HIDDescriptor = descriptors.HIDDescriptor;
const InterfaceClassDescriptor = class.interface.InterfaceClassDescriptor;

pub const InterfaceDescriptor = packed struct {
    descriptor: Descriptor,
    number: u8,
    alternate_setting: u8,
    num_endpoints: u8,
    class: u8,
    subclass: u8,
    protocol: u8,
    interface: u8,

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader, descriptor: ?Descriptor) !*InterfaceDescriptor {
        var len: u8 = DescriptorType.Interface.size();
        if (descriptor) |d| {
            len = d.length;
        }
        const ptr: *InterfaceDescriptor = @ptrCast(@alignCast(try reader.readAlloc(allocator, len)));

        if (ptr.descriptor.type != DescriptorType.Interface) {
            return UsbError.DescriptorDoesNotMatch;
        }
        return ptr;
    }
};

pub const InterfaceDescriptorTree = struct {
    const Self = @This();

    descriptor: *InterfaceDescriptor,
    endpoints: std.array_list.Managed(EndpointDescriptorTree),
    sub_descriptors: std.array_list.Managed(InterfaceClassDescriptor),

    allocator: std.mem.Allocator,
    hid: ?*HIDDescriptor,

    pub fn init(allocator: std.mem.Allocator, descriptor: *InterfaceDescriptor) !InterfaceDescriptorTree {
        return InterfaceDescriptorTree{
            .descriptor = descriptor,
            .endpoints = std.array_list.Managed(EndpointDescriptorTree).init(allocator),
            .sub_descriptors = std.array_list.Managed(InterfaceClassDescriptor).init(allocator),
            .allocator = allocator,
            .hid = null,
        };
    }

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader) !InterfaceDescriptorTree {
        if (Descriptor.peek(reader)) |descriptor| {
            if (descriptor.type == .Interface) {
                const interface = try InterfaceDescriptor.read(allocator, reader, descriptor);
                var interface_tree = try InterfaceDescriptorTree.init(allocator, interface);
                var endpoints: u8 = 0;
                while (endpoints < interface.num_endpoints) {
                    if (Descriptor.peek(reader)) |next| {
                        switch (next.type) {
                            .Endpoint => {
                                if (EndpointDescriptorTree.read(allocator, reader, interface)) |endpoint| {
                                    interface_tree.addEndpoint(endpoint) catch |err| {
                                        interface_tree.deinit();
                                        return err;
                                    };
                                } else |err| {
                                    interface_tree.deinit();
                                    return err;
                                }
                                endpoints += 1;
                            },
                            .HID => {
                                const hid = try HIDDescriptor.read(allocator, reader, next);
                                interface_tree.addHid(hid);
                            },
                            .ClassSpecificationInterface => {
                                const interface_class = try InterfaceClassDescriptor.read(allocator, reader, interface);
                                try interface_tree.addInterfaceClassDescriptor(interface_class);
                            },
                            else => |t| {
                                std.debug.print("Handle {any}\n", .{t});
                                @panic("Unknown Type In Interface");
                            },
                        }
                    } else |_| {
                        @panic("EOF Likely");
                    }
                }
                return interface_tree;
            } else {
                return UsbError.NoDescriptor;
            }
        } else |err| {
            return err;
        }
        @panic("Handle Interface Tree");
    }

    pub fn deinit(self: Self) void {
        for (self.endpoints.items) |endpoint| {
            endpoint.deinit();
        }
        self.endpoints.deinit();

        if (self.hid) |hid| {
            descriptors.freeDescriptorTypePtr(HIDDescriptor, self.allocator, hid);
        }

        for (self.sub_descriptors.items) |*descriptor| {
            descriptor.deinit();
        }
        self.sub_descriptors.deinit();

        descriptors.freeDescriptorTypePtr(InterfaceDescriptor, self.allocator, self.descriptor);
    }

    pub fn addEndpoint(self: *Self, endpoint: EndpointDescriptorTree) !void {
        try self.endpoints.append(endpoint);
    }

    pub fn addHid(self: *Self, hid: *HIDDescriptor) void {
        self.hid = hid;
    }

    pub fn addInterfaceClassDescriptor(self: *Self, descriptor: InterfaceClassDescriptor) !void {
        try self.sub_descriptors.append(descriptor);
    }
};
