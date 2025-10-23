const std = @import("std");
const builtin = @import("builtin");
pub const class = @import("descriptors/class.zig");
pub const Descriptor = @import("descriptors/Descriptor.zig").Descriptor;
pub const DescriptorType = @import("descriptors/Descriptor.zig").DescriptorType;
pub const DeviceDescriptor = @import("descriptors/Device.zig").DeviceDescriptor;
pub const DeviceDescriptorTree = @import("descriptors/Device.zig").DeviceDescriptorTree;
pub const ConfigurationDescriptor = @import("descriptors/Configuration.zig").ConfigurationDescriptor;
pub const ConfigurationDescriptorTree = @import("descriptors/Configuration.zig").ConfigurationDescriptorTree;
pub const AssociationDescriptor = @import("descriptors/Association.zig").AssociationDescriptor;
pub const AssociationDescriptorTree = @import("descriptors/Association.zig").AssociationDescriptorTree;
pub const InterfaceDescriptor = @import("descriptors/Interface.zig").InterfaceDescriptor;
pub const InterfaceDescriptorTree = @import("descriptors/Interface.zig").InterfaceDescriptorTree;
pub const EndpointDescriptor = @import("descriptors/Endpoint.zig").EndpointDescriptor;
pub const EndpointDescriptorTree = @import("descriptors/Endpoint.zig").EndpointDescriptorTree;
pub const HIDDescriptor = @import("descriptors/HID.zig").HIDDescriptor;
// pub const HIDDescriptorTree = @import("descriptors/HID.zig").HIDDescriptorTree;
// pub const ClassSpecificationInterfaceDescriptor = @import("descriptors/ClassSpecificationInterface.zig").ClassSpecificationInterfaceDescriptor;
// pub const peekClassInterfaceDescriptor = @import("descriptors/ClassSpecificationInterface.zig").peekClassInterfaceDescriptor;
const UsbError = @import("error.zig").UsbError;

// TODO: Maybe this public functions should be moved to the linux expansion.
// Not sure if we are given Window's Device Descriptors as one uninterrupted reader?

pub fn peekDescriptor(reader: *std.io.Reader) std.io.Reader.Error!Descriptor {
    const desc = try reader.peekStruct(Descriptor, comptime builtin.cpu.arch.endian());
    return desc;
}

pub fn readDescriptorToType(allocator: std.mem.Allocator, reader: *std.io.Reader, descriptor: Descriptor, comptime T: type) !T {
    comptime std.debug.assert(std.mem.eql(u8, @typeName(T), "descriptors.Device.DeviceDescriptor") or
        std.mem.eql(u8, @typeName(T), "descriptors.Configuration.ConfigurationDescriptor") or
        std.mem.eql(u8, @typeName(T), "descriptors.Interface.InterfaceDescriptor") or
        std.mem.eql(u8, @typeName(T), "descriptors.Association.AssociationDescriptor") or
        std.mem.eql(u8, @typeName(T), "descriptors.Endpoint.EndpointDescriptor") or
        std.mem.eql(u8, @typeName(T), "descriptors.ClassSpecificationInterface.ClassSepecificationInterfaceDescriptor"));
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

pub fn readDescriptorToTypePtr(allocator: std.mem.Allocator, reader: *std.io.Reader, descriptor: Descriptor, comptime T: type) !*T {
    comptime std.debug.assert(std.mem.eql(u8, @typeName(T), "descriptors.HID.HIDDescriptor"));
    const ptr: *T = @ptrCast(@alignCast(try reader.readAlloc(allocator, descriptor.length)));

    const d = @as(*Descriptor, @ptrCast(ptr));
    if (d.type != descriptor.type) {
        // TODO: Can we get a zig macro for this? @as([]u8, @ptrCast(ptr)) -> assumes that the length is the size of the ptr size
        // Can we get a @byteCast(ptr, len)?
        var bytes: []u8 align(1) = undefined;
        bytes = @ptrCast(@alignCast(ptr));
        bytes.len = d.length;
        return UsbError.DescriptorDoesNotMatch;
    }

    return ptr;
}

pub fn freeDescriptorTypePtr(comptime T: type, allocator: std.mem.Allocator, ptr: *T) !void {
    comptime std.debug.assert(std.mem.eql(u8, @typeName(T), "descriptors.HID.HIDDescriptor"));
    // TODO: Can we get a zig macro for this? @as([]u8, @ptrCast(ptr)) -> assumes that the length is the size of the ptr size
    // Can we get a @byteCast(ptr, len)?
    var bytes: []u8 align(1) = undefined;
    const descriptor: *Descriptor = @ptrCast(ptr);
    bytes = @ptrCast(@alignCast(ptr));
    bytes.len = descriptor.length;
    allocator.free(bytes);
}

pub fn readDescriptorToNull(allocator: std.mem.Allocator, reader: *std.io.Reader, descriptor: Descriptor) !void {
    const bytes = try reader.readAlloc(allocator, descriptor.length);
    defer allocator.free(bytes);
}
