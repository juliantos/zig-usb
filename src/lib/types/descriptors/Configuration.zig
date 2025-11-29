const std = @import("std");
const descriptors = @import("../descriptors.zig");

const UsbError = @import("../error.zig").UsbError;

const Descriptor = descriptors.Descriptor;
const DescriptorType = descriptors.DescriptorType;
const InterfaceDescriptorTree = descriptors.InterfaceDescriptorTree;
const AssociationDescriptorTree = descriptors.AssociationDescriptorTree;

pub const ConfigurationDescriptor = packed struct {
    descriptor: Descriptor,
    total_length: u16,
    num_interfaces: u8,
    configuration_value: u8,
    configuration: u8,
    attributes: u8,
    max_power: u8,

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader, descriptor: ?Descriptor) !*ConfigurationDescriptor {
        var len: u8 = DescriptorType.Configuration.size();
        if (descriptor) |d| {
            len = d.length;
        }
        const ptr: *ConfigurationDescriptor = @ptrCast(@alignCast(try reader.readAlloc(allocator, len)));

        if (ptr.descriptor.type != DescriptorType.Configuration) {
            return UsbError.DescriptorDoesNotMatch;
        }
        return ptr;
    }
};

const IOA = enum { interface, association };
pub const InterfaceOrAssociation = union(IOA) {
    interface: InterfaceDescriptorTree,
    association: AssociationDescriptorTree,
};

pub const ConfigurationDescriptorTree = struct {
    const Self = @This();

    descriptor: *ConfigurationDescriptor,
    interfaces_or_associations: std.array_list.Managed(InterfaceOrAssociation),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, descriptor: *ConfigurationDescriptor) !ConfigurationDescriptorTree {
        return ConfigurationDescriptorTree{
            .descriptor = descriptor,
            .interfaces_or_associations = std.array_list.Managed(InterfaceOrAssociation).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader) !ConfigurationDescriptorTree {
        if (Descriptor.peek(reader)) |descriptor| {
            if (descriptor.type == .Configuration) {
                const config = try ConfigurationDescriptor.read(allocator, reader, descriptor);
                var config_tree = try ConfigurationDescriptorTree.init(allocator, config);
                var interfaces: u8 = 0;
                while (interfaces < config.num_interfaces) {
                    if (Descriptor.peek(reader)) |next| {
                        switch (next.type) {
                            .Association => {
                                if (AssociationDescriptorTree.read(allocator, reader)) |association| {
                                    try config_tree.addAssociation(association);
                                } else |err| {
                                    config_tree.deinit();
                                    return err;
                                }
                            },
                            .Interface => {
                                if (InterfaceDescriptorTree.read(allocator, reader)) |interface| {
                                    config_tree.addInterface(interface) catch |err| {
                                        config_tree.deinit();
                                        return err;
                                    };
                                } else |err| {
                                    config_tree.deinit();
                                    return err;
                                }
                                interfaces += 1;
                            },
                            else => {
                                config_tree.deinit();
                                return UsbError.NoDescriptor;
                            },
                        }
                    } else |err| {
                        config_tree.deinit();
                        return err;
                    }
                }
                return config_tree;
            } else {
                return UsbError.NoDescriptor;
            }
        } else |err| {
            return err; // Should not be reading extra configuration
        }
        @panic("Read Configuration");
    }

    pub fn deinit(self: Self) void {
        for (self.interfaces_or_associations.items) |*ioa| {
            switch (ioa.*) {
                .interface => |*interface| interface.deinit(),
                .association => |*association| association.deinit(),
            }
        }
        self.interfaces_or_associations.deinit();

        descriptors.freeDescriptorTypePtr(ConfigurationDescriptor, self.allocator, self.descriptor);
    }

    pub fn addInterface(self: *Self, interface: InterfaceDescriptorTree) !void {
        try self.interfaces_or_associations.append(InterfaceOrAssociation{
            .interface = interface,
        });
    }

    pub fn addAssociation(self: *Self, association: AssociationDescriptorTree) !void {
        try self.interfaces_or_associations.append(InterfaceOrAssociation{
            .association = association,
        });
    }

    pub fn getCurrentInterface(self: *Self) !*InterfaceDescriptorTree {
        var iface: ?*InterfaceDescriptorTree = null;
        const len = self.interfaces_or_associations.items.len;
        if (len > 0) {
            const ioa = &self.interfaces_or_associations.items[len - 1];
            switch (ioa.*) {
                .interface => |*interface| {
                    iface = interface;
                },
                .association => {
                    @panic("should have been caught by the association builder");
                },
            }
        }

        if (iface) |interface| {
            return interface;
        } else {
            return error.NoDescriptor;
        }
    }
};
