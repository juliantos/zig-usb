const std = @import("std");
const Descriptor = @import("Descriptor.zig").Descriptor;
const DescriptorType = @import("Descriptor.zig").DescriptorType;
const InterfaceDescriptorTree = @import("Interface.zig").InterfaceDescriptorTree;
const UsbError = @import("../error.zig").UsbError;

pub const AssociationDescriptor = packed struct {
    descriptor: Descriptor,
    first_interface: u8,
    interface_count: u8,
    class: u8,
    subclass: u8,
    protocol: u8,
    function: u8,

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader, descriptor: ?Descriptor) !*AssociationDescriptor {
        var len: u8 = DescriptorType.Association.size();
        if (descriptor) |d| {
            len = d.length;
        }
        const ptr: *AssociationDescriptor = @ptrCast(@alignCast(try reader.readAlloc(allocator, len)));

        if (ptr.descriptor.type != DescriptorType.Association) {
            return UsbError.DescriptorDoesNotMatch;
        }
        return ptr;
    }
};

pub const AssociationDescriptorTree = struct {
    const Self = @This();

    descriptor: *AssociationDescriptor,
    interfaces: std.array_list.Managed(InterfaceDescriptorTree),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, descriptor: *AssociationDescriptor) !AssociationDescriptorTree {
        return AssociationDescriptorTree{
            .descriptor = descriptor,
            .interfaces = std.array_list.Managed(InterfaceDescriptorTree).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader) !AssociationDescriptorTree {
        if (Descriptor.peek(reader)) |descriptor| {
            if (descriptor.type == .Association) {
                const association = try AssociationDescriptor.read(allocator, reader, descriptor);
                var association_tree = try AssociationDescriptorTree.init(allocator, association);
                var interfaces: u8 = 0;
                while (interfaces < association.interface_count) {
                    if (Descriptor.peek(reader)) |next| {
                        switch (next.type) {
                            .Interface => {
                                if (InterfaceDescriptorTree.read(allocator, reader)) |interface| {
                                    association_tree.addInterface(interface) catch |err| {
                                        association_tree.deinit();
                                        return err;
                                    };
                                } else |err| {
                                    association_tree.deinit();
                                    return err;
                                }
                                interfaces += 1;
                            },
                            else => {
                                std.debug.print("Type: {any}\n", .{next.type});
                                @panic("Associations should only have interfaces");
                            },
                        }
                    } else |err| {
                        association_tree.deinit();
                        return err;
                    }
                }
                return association_tree;
            } else {
                return UsbError.NoDescriptor;
            }
        } else |err| {
            return err;
        }
    }

    pub fn deinit(self: Self) void {
        for (self.interfaces.items) |interface| {
            interface.deinit();
        }
        self.interfaces.deinit();

        self.allocator.free(@as([]u8, @ptrCast(self.descriptor)));
    }

    pub fn addInterface(self: *Self, interface: InterfaceDescriptorTree) !void {
        try self.interfaces.append(interface);
    }
};
