const std = @import("std");
const builtin = @import("builtin");
const Descriptor = @import("Descriptor.zig").Descriptor;
const DeviceDescriptor = @import("Device.zig").DeviceDescriptor;

pub const ClassSpecificationType = enum(u8) {
    Undefined = 0x20,
    Device = 0x21,
    Configuration = 0x22,
    String = 0x23,
    Interface = 0x24,
    Endpoint = 0x25,
};

pub const ClassSpecificationDescriptor = packed struct {
    descriptor: Descriptor,
    subtype: u8,
};

pub fn peekClassSpecificationDescriptor(reader: *std.io.Reader) !ClassSpecificationDescriptor {
    return try reader.peekStruct(ClassSpecificationDescriptor, comptime builtin.cpu.arch.endian());
}
