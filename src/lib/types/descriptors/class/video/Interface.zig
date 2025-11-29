const std = @import("std");
const descriptors = @import("../../../descriptors.zig");
const class = descriptors.class;

const UsbError = @import("../../../error.zig").UsbError;

const ClassDescriptor = class.ClassDescriptor;
const Descriptor = descriptors.Descriptor;
const DescriptorType = descriptors.DescriptorType;

pub const VideoInterfaceSubClass = enum(u8) {
    Undefined = 0,
    VideoControl = 1,
    VideoStreaming = 2,
    VideoInterfaceCollection = 3,
};

pub const VideoInterfaceProtocolCodes = enum(u8) {
    Undefined = 0,
    _15 = 1,
};

pub const VideoInterfaceVCSubType = enum(u8) {
    Undefined = 0,
    Header,
    InputTerminal,
    OutputTerminal,
    SelectorUnit,
    ProcessingUnit,
    ExtensionUnit,
    EncodingUnit,
};

pub const VideoInterfaceVSSubType = enum(u8) {
    Undefined,
    InputHeader,
    OutputHeader,
    StillImageFrame,
    FormatUncompressed,
    FrameUncompressed,
    FormatMJPEG,
    FrameMJPEG,
    FormatMPEG2TS = 0x0a,
    FomratDV = 0xc,
    ColorFormat,
    FormatFrameBased,
    FrameFrameBased,
    FormatStreamBased,
    FormatH264,
    FrameH264,
    FormatH264Simulcast,
    FormatVP8,
    FrameVP8,
    FormatVP8Simulcast,
};

pub const VideoInterfaceHeaderDescriptor = extern struct {
    const Self = @This();

    descriptor: Descriptor,
    subtype: VideoInterfaceVCSubType,
    uvc: u16,
    total_length: u16,
    clock_frequency: u32,
    interface_collection: u8,
    interface_number: [256]u8,

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader, descriptor: Descriptor) !*Self {
        const len = descriptor.length;
        const ptr: *Self = @ptrCast(@alignCast(try reader.readAlloc(allocator, len)));

        if (ptr.descriptor.type != DescriptorType.ClassSpecificationInterface or ptr.subtype != .Header) {
            return UsbError.DescriptorDoesNotMatch;
        }
        return ptr;
    }
};

pub const VideoInterfaceOutputTerminalDescriptor = extern struct {
    const Self = @This();

    descriptor: Descriptor,
    subtype: VideoInterfaceVCSubType,
    terminal_id: u8,
    terminal_type: u16,
    associated_terminal: u8,
    source_id: u8,
    terminal: u8,
    additional: void, // TODO: Handle Unknown Additional Fields

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader, descriptor: Descriptor) !*Self {
        const len = descriptor.length;
        const ptr: *Self = @ptrCast(@alignCast(try reader.readAlloc(allocator, len)));

        if (ptr.descriptor.type != DescriptorType.ClassSpecificationInterface or ptr.subtype != .OutputTerminal) {
            return UsbError.DescriptorDoesNotMatch;
        }
        return ptr;
    }
};

pub const VideoInterfaceInputTerminalDescriptor = extern struct {
    const Self = @This();

    descriptor: Descriptor,
    subtype: VideoInterfaceVCSubType,
    terminal_id: u8,
    terminal_type: u16,
    associated_terminal: u8,
    terminal: u8,
    additional: void, // TODO: Handle Unknown Additional Fields

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader, descriptor: Descriptor) !*Self {
        const len = descriptor.length;
        const ptr: *Self = @ptrCast(@alignCast(try reader.readAlloc(allocator, len)));

        if (ptr.descriptor.type != DescriptorType.ClassSpecificationInterface or ptr.subtype != .InputTerminal) {
            return UsbError.DescriptorDoesNotMatch;
        }
        return ptr;
    }
};

pub const VideoInterfaceProcessingUnitDescriptor = extern struct {
    const Self = @This();

    descriptor: Descriptor,
    subtype: VideoInterfaceVCSubType,
    unit_id: u8,
    source_id: u8,
    max_multiplier: u16,
    control_size: u8,
    controls: [3]u8,
    processing: u8,
    video_standards: u8,

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader, descriptor: Descriptor) !*Self {
        const len = descriptor.length;
        const ptr: *Self = @ptrCast(@alignCast(try reader.readAlloc(allocator, len)));

        if (ptr.descriptor.type != DescriptorType.ClassSpecificationInterface or ptr.subtype != .ProcessingUnit) {
            return UsbError.DescriptorDoesNotMatch;
        }
        return ptr;
    }
};

pub const VideoExtensionUnit = struct {
    source_id: std.array_list.Managed(u8),
    controls: std.array_list.Managed(u8),
    extension: u8,
};

pub const VideoInterfaceExtensionUnitDescriptor = extern struct {
    const Self = @This();

    descriptor: Descriptor,
    subtype: VideoInterfaceVCSubType,
    unit_id: u8,
    guid_extension_code: [16]u8,
    number_controls: u8,
    number_input_pins: u8,
    data: [514]u8,

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader, descriptor: Descriptor) !*Self {
        const len = descriptor.length;
        const ptr: *Self = @ptrCast(@alignCast(try reader.readAlloc(allocator, len)));

        if (ptr.descriptor.type != DescriptorType.ClassSpecificationInterface or ptr.subtype != .ExtensionUnit) {
            return UsbError.DescriptorDoesNotMatch;
        }
        return ptr;
    }

    pub fn decode(self: Self, allocator: std.mem.Allocator) !VideoExtensionUnit {
        var source_id = try std.array_list.Managed(u8).initCapacity(allocator, self.number_input_pins);
        try source_id.appendSlice(self.data[0..self.number_input_pins]);

        const control_size = self.data[self.number_input_pins];

        var controls = try std.array_list.Managed(u8).initCapacity(allocator, control_size);
        try controls.appendSlice(self.data[self.number_input_pins + 1 .. self.number_input_pins + 1 + control_size]);

        const unit = VideoExtensionUnit{
            .source_id = source_id,
            .controls = controls,
            .extension = self.data[self.number_input_pins + control_size + 1],
        };

        return unit;
    }
};

pub const VideoInterfaceEncodingUnitDescriptor = extern struct {
    const Self = @This();

    descriptor: Descriptor,
    subtype: VideoInterfaceVCSubType,

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader, descriptor: Descriptor) !*Self {
        const len = descriptor.length;
        const ptr: *Self = @ptrCast(@alignCast(try reader.readAlloc(allocator, len)));

        if (ptr.descriptor.type != DescriptorType.ClassSpecificationInterface or ptr.subtype != .EncodingUnit) {
            return UsbError.DescriptorDoesNotMatch;
        }
        return ptr;
    }
};

pub const VideoInterfaceDescriptor = union(VideoInterfaceVCSubType) {
    Undefined: void,
    Header: *VideoInterfaceHeaderDescriptor,
    InputTerminal: *VideoInterfaceInputTerminalDescriptor,
    OutputTerminal: *VideoInterfaceOutputTerminalDescriptor,
    SelectorUnit: void,
    ProcessingUnit: *VideoInterfaceProcessingUnitDescriptor,
    ExtensionUnit: *VideoInterfaceExtensionUnitDescriptor,
    EncodingUnit: *VideoInterfaceEncodingUnitDescriptor,
};

pub const VideoInterfaceDescriptorTree = struct {
    const Self = @This();

    descriptor: VideoInterfaceDescriptor,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, descriptor: VideoInterfaceDescriptor) !Self {
        return VideoInterfaceDescriptorTree{
            .descriptor = descriptor,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Self) void {
        var bytes: ?[]u8 = null;
        switch (self.descriptor) {
            .Header => |d| {
                bytes = @ptrCast(d);
                bytes.?.len = d.descriptor.length;
            },
            .InputTerminal => |d| {
                bytes = @ptrCast(d);
                bytes.?.len = d.descriptor.length;
            },
            .OutputTerminal => |d| {
                bytes = @ptrCast(d);
                bytes.?.len = d.descriptor.length;
            },
            .ProcessingUnit => |d| {
                bytes = @ptrCast(d);
                bytes.?.len = d.descriptor.length;
            },
            .ExtensionUnit => |d| {
                bytes = @ptrCast(d);
                bytes.?.len = d.descriptor.length;
            },
            else => {
                @panic("Handle Deinit");
            },
        }
        if (bytes) |b| {
            self.allocator.free(b);
        }
    }

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader) !VideoInterfaceDescriptorTree {
        if (ClassDescriptor.peek(reader)) |descriptor| {
            if (descriptor.descriptor.type == .ClassSpecificationInterface) {
                const sub_type: VideoInterfaceVCSubType = @enumFromInt(descriptor.sub_type);
                switch (sub_type) {
                    .Header => {
                        const header = try VideoInterfaceHeaderDescriptor.read(allocator, reader, descriptor.descriptor);
                        return try VideoInterfaceDescriptorTree.init(allocator, VideoInterfaceDescriptor{
                            .Header = header,
                        });
                    },
                    .InputTerminal => {
                        const input = try VideoInterfaceInputTerminalDescriptor.read(allocator, reader, descriptor.descriptor);
                        return try VideoInterfaceDescriptorTree.init(allocator, VideoInterfaceDescriptor{
                            .InputTerminal = input,
                        });
                    },
                    .OutputTerminal => {
                        const output = try VideoInterfaceOutputTerminalDescriptor.read(allocator, reader, descriptor.descriptor);
                        return try VideoInterfaceDescriptorTree.init(allocator, VideoInterfaceDescriptor{
                            .OutputTerminal = output,
                        });
                    },
                    .ProcessingUnit => {
                        const unit = try VideoInterfaceProcessingUnitDescriptor.read(allocator, reader, descriptor.descriptor);
                        return try VideoInterfaceDescriptorTree.init(allocator, VideoInterfaceDescriptor{
                            .ProcessingUnit = unit,
                        });
                    },
                    .ExtensionUnit => {
                        const unit = try VideoInterfaceExtensionUnitDescriptor.read(allocator, reader, descriptor.descriptor);
                        return try VideoInterfaceDescriptorTree.init(allocator, VideoInterfaceDescriptor{
                            .ExtensionUnit = unit,
                        });
                    },
                    else => {
                        std.debug.print("SubType: {any}\n", .{sub_type});
                        @panic("Handle Video Class Descriptors");
                    },
                }
            } else {
                return UsbError.NoDescriptor;
            }
        } else |err| {
            return err;
        }
        @panic("Handle Read of Video Interface Tree");
    }
};
