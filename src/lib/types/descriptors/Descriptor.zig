const std = @import("std");
const builtin = @import("builtin");

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
    HID = 0x21,
    ClassSpecificationInterface = 0x24,
    ClassSpecificationEndpoint,
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

    pub fn peek(reader: *std.io.Reader) std.io.Reader.Error!Descriptor {
        return try reader.peekStruct(Descriptor, comptime builtin.cpu.arch.endian());
    }
};
