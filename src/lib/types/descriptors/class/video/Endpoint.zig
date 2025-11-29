const std = @import("std");
const descriptors = @import("../../../descriptors.zig");
const class = descriptors.class;

const UsbError = @import("../../../error.zig").UsbError;

const ClassDescriptor = class.ClassDescriptor;
const Descriptor = descriptors.Descriptor;

pub const VideoEndpointSubType = enum(u8) {
    Undefined = 0x00,
    General,
    Endpoint,
    Interrupt,
};

pub const VideoEndpointInterruptDescriptor = extern struct {
    const Self = @This();

    descriptor: Descriptor,
    subtype: VideoEndpointSubType,
	max_transfer_size: u16,

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader, descriptor: Descriptor) !*Self {
        const len = descriptor.length;
        const ptr: *Self = @ptrCast(@alignCast(try reader.readAlloc(allocator, len)));

        if (ptr.descriptor.type != .ClassSpecificationEndpoint or ptr.subtype != .Interrupt) {
            return UsbError.DescriptorDoesNotMatch;
        }
        return ptr;
    }
};

pub const VideoEndpointDescriptor = union(VideoEndpointSubType) {
    Undefined: void,
    General: void,
    Endpoint: void,
    Interrupt: *VideoEndpointInterruptDescriptor,
};

pub const VideoEndpointDescriptorTree = struct {
    const Self = @This();

    descriptor: VideoEndpointDescriptor,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, descriptor: VideoEndpointDescriptor) !Self {
        return Self{
            .descriptor = descriptor,
            .allocator = allocator,
        };
    }

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader) !VideoEndpointDescriptorTree {
        if (ClassDescriptor.peek(reader)) |descriptor| {
            const sub_type: VideoEndpointSubType = @enumFromInt(descriptor.sub_type);
            switch (sub_type) {
                .Interrupt => {
                    const interrupt = try VideoEndpointInterruptDescriptor.read(allocator, reader, descriptor.descriptor);
                    return try VideoEndpointDescriptorTree.init(allocator, VideoEndpointDescriptor{
                        .Interrupt = interrupt,
                    });
                },
                else => {
                    std.debug.print("Descriptor: {any}\n", .{sub_type});
                    @panic("Handle Sub Type");
                },
            }
        } else |err| {
            return err;
        }
        @panic("Build Tree");
    }

    pub fn deinit(self: *Self) void {
		var bytes: ?[]u8 = null;
		switch (self.descriptor) {
			.Interrupt => |d| {
				bytes = @ptrCast(d);
				bytes.?.len = d.descriptor.length;
			},
			else => {
				@panic("Handle Deinit");
			}
		}
		if (bytes) |b| {
			self.allocator.free(b);
		}
    }
};
