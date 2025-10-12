const std = @import("std");
const builtin = @import("builtin");
const UsbError = @import("error.zig").UsbError;

pub const DescriptorType = enum(u8) {
    const Self = @This();

    Device = 0x01,
    Configuration,
    String,
    Interface,
    Endpoint,
    Qualifier,
    Speed,
    Association = 0x0b,
    _,

    pub fn size(self: Self) u8 {
        switch (self) {
            .Device => return 18,
            .Configuration => return 9,
            .Interface => return 9,
            .Endpoint => return 7,
            _ => return 255,
            else => return 255,
        }
    }
};

pub const Descriptor = packed struct {
    length: u8,
    type: DescriptorType,
};

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
};

pub const ConfigurationDescriptor = packed struct {
    descriptor: Descriptor,
    total_length: u16,
    num_interfaces: u8,
    configuration_value: u8,
    configuration: u8,
    attributes: u8,
    max_power: u8,
};

pub const InterfaceDescriptor = packed struct {
    descriptor: Descriptor,
    number: u8,
    alternate_setting: u8,
    num_endpoints: u8,
    class: u8,
    subclass: u8,
    protocol: u8,
    interface: u8,
};

pub const AssociationDescriptor = packed struct {
    descriptor: Descriptor,
    first_interface: u8,
    interface_count: u8,
    class: u8,
    subclass: u8,
    protocol: u8,
    function: u8,
};

pub const EndpointDescriptor = packed struct {
    descriptor: Descriptor,
    endpoint_address: u8,
    attributes: u8,
    max_packet_size: u16,
    interval: u8,
};

pub const DescriptorTree = struct {
    descriptor: Descriptor,
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

    pub fn deinit(self: Self) void {
        for (self.configurations.items) |config| {
            config.deinit();
        }
        self.configurations.deinit();
    }
};

pub const ConfigurationDescriptorTree = struct {
    const Self = @This();

    descriptor: ConfigurationDescriptor,
    interfaces_or_associations: std.array_list.Managed(InterfaceOrAssociation),

    pub fn init(allocator: std.mem.Allocator, descriptor: ConfigurationDescriptor) !ConfigurationDescriptorTree {
        return ConfigurationDescriptorTree{
            .descriptor = descriptor,
            .interfaces_or_associations = std.array_list.Managed(InterfaceOrAssociation).init(allocator),
        };
    }

    pub fn deinit(self: Self) void {
        for (self.interfaces_or_associations.items) |*ioa| {
            switch (ioa.*) {
                .interface => |*interface| interface.deinit(),
                .association => |*association| association.deinit(),
            }
        }
        self.interfaces_or_associations.deinit();
    }

    pub fn addInterface(self: *Self, interface: InterfaceDescriptorTree) !void {
        var associated = false;
        for (self.interfaces_or_associations.items) |*ioa| {
            switch (ioa.*) {
                .association => |assc| {
                    const end = assc.descriptor.first_interface + assc.descriptor.interface_count;
                    if (interface.descriptor.number >= assc.descriptor.first_interface and interface.descriptor.number < end) {
                        try ioa.association.interfaces.append(interface);
                        associated = true;
                        return;
                    }
                },
                else => {},
            }
        }
        if (!associated) {
            try self.interfaces_or_associations.append(InterfaceOrAssociation{
                .interface = interface,
            });
        }
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
                .association => |*association| {
                    iface = try association.getCurrentInterface();
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

pub const IOA = enum { interface, association };
pub const InterfaceOrAssociation = union(IOA) {
    interface: InterfaceDescriptorTree,
    association: AssociationDescriptorTree,
};

pub const InterfaceDescriptorTree = struct {
    const Self = @This();

    descriptor: InterfaceDescriptor,

    pub fn init(allocator: std.mem.Allocator, descriptor: InterfaceDescriptor) !InterfaceDescriptorTree {
        _ = allocator;
        return InterfaceDescriptorTree{
            .descriptor = descriptor,
        };
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }

    pub fn addEndpoint(self: *Self, endpoint: EndpointDescriptorTree) !void {
        _ = self;
        _ = endpoint;
    }
};

pub const AssociationDescriptorTree = struct {
    const Self = @This();

    descriptor: AssociationDescriptor,
    interfaces: std.array_list.Managed(InterfaceDescriptorTree),

    pub fn init(allocator: std.mem.Allocator, descriptor: AssociationDescriptor) !AssociationDescriptorTree {
        return AssociationDescriptorTree{
            .descriptor = descriptor,
            .interfaces = std.array_list.Managed(InterfaceDescriptorTree).init(allocator),
        };
    }

    pub fn deinit(self: Self) void {
        for (self.interfaces.items) |interface| {
            interface.deinit();
        }
        self.interfaces.deinit();
    }

    pub fn getCurrentInterface(self: *Self) !*InterfaceDescriptorTree {
        var iface: ?*InterfaceDescriptorTree = null;
        const len = self.interfaces.items.len;
        if (len > 0) {
            iface = &self.interfaces.items[len - 1];
        }

        if (iface) |interface| {
            return interface;
        } else {
            return error.NoDescriptor;
        }
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
};

// TODO: Maybe this public functions should be moved to the linux expansion.
// Not sure if we are given Window's Device Descriptors as one uninterrupted reader?

pub fn peekDescriptor(reader: *std.io.Reader) std.io.Reader.Error!Descriptor {
    const desc = try reader.peekStruct(Descriptor, comptime builtin.cpu.arch.endian());
    return desc;
}

pub fn readDescriptorToType(allocator: std.mem.Allocator, reader: *std.io.Reader, descriptor: Descriptor, comptime T: type) !T {
    comptime std.debug.assert(std.mem.eql(u8, @typeName(T), "descriptors.DeviceDescriptor") or
        std.mem.eql(u8, @typeName(T), "descriptors.ConfigurationDescriptor") or
        std.mem.eql(u8, @typeName(T), "descriptors.InterfaceDescriptor") or
        std.mem.eql(u8, @typeName(T), "descriptors.AssociationDescriptor") or
        std.mem.eql(u8, @typeName(T), "descriptors.EndpointDescriptor"));
    var desc: T = undefined;
    const bytes = try reader.readAlloc(allocator, descriptor.length);
    defer allocator.free(bytes);
    const max_index = @min(descriptor.length, descriptor.type.size());
    std.mem.copyForwards(u8, @as([]u8, @ptrCast(&desc)), bytes[0..max_index]);

    const d = @as(*Descriptor, @ptrCast(&desc));
    if (d.type != descriptor.type) {
        return UsbError.DescriptorDoesNotMatch;
    }
    return desc;
}

pub fn readDescriptorToNull(allocator: std.mem.Allocator, reader: *std.io.Reader, descriptor: Descriptor) !void {
    const bytes = try reader.readAlloc(allocator, descriptor.length);
    defer allocator.free(bytes);
}
