const std = @import("std");
const builtin = @import("builtin");
const descriptors = @import("../../descriptors.zig");

pub const ClassDescriptor = extern struct {
    descriptor: descriptors.Descriptor,
    sub_type: u8,

    pub fn peek(reader: *std.io.Reader) std.io.Reader.Error!ClassDescriptor {
        return try reader.peekStruct(ClassDescriptor, comptime builtin.cpu.arch.endian());
    }
};
