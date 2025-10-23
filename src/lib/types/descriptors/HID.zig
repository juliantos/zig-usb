const std = @import("std");
const descriptors = @import("../descriptors.zig");
const Descriptor = @import("Descriptor.zig").Descriptor;
const EndpointDescriptorTree = @import("Endpoint.zig").EndpointDescriptorTree;

const SubDescriptors = extern struct {
    descriptor_type: u8,
    descriptor_length: u16,
};

pub const HIDDescriptor = extern struct {
    descriptor: Descriptor,
    hid: u16,
    country_code: u8,
    num_descriptors: u8,
    sub_descriptors: [1]SubDescriptors,

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader, descriptor: Descriptor) !*HIDDescriptor {
        return try descriptors.readDescriptorToTypePtr(allocator, reader, descriptor, HIDDescriptor);
    }
};
