const std = @import("std");
const video = @import("video/Interface.zig");
const InterfaceDescriptor = @import("../Interface.zig").InterfaceDescriptor;

pub const InterfaceClassDescriptorType = enum(u8) {
    Audio = 0x01,
    Comms = 0x02,
    HID = 0x03,
    Physical = 0x05,
    Image = 0x06,
    Printer = 0x07,
    MassStorage = 0x08,
    CDC_Data = 0x0a,
    SmartCard = 0x0b,
    ContentSecurity = 0x0d,
    Video = 0x0e,
    PersonalHealthcare = 0x0f,
    AudioVideo = 0x10,
    UsbTypeC_Bridge = 0x12,
    UsbBulkDisplay = 0x13,
    MCTP_OverUsb = 0x14,
    I3C = 0x3c,
    Diagnostic = 0xdc,
    WirelessController = 0xe0,
    Misc = 0xef,
    AppSpecific = 0xfe,
    VendorSpecific = 0xff,
};

pub const InterfaceClassDescriptor = union(InterfaceClassDescriptorType) {
    Audio: void,
    Comms: void,
    HID: void,
    Physical: void,
    Image: void,
    Printer: void,
    MassStorage: void,
    CDC_Data: void,
    SmartCard: void,
    ContentSecurity: void,
    Video: video.VideoInterfaceDescriptorTree,
    PersonalHealthcare: void,
    AudioVideo: void,
    UsbTypeC_Bridge: void,
    UsbBulkDisplay: void,
    MCTP_OverUsb: void,
    I3C: void,
    Diagnostic: void,
    WirelessController: void,
    Misc: void,
    AppSpecific: void,
    VendorSpecific: void,

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader, interface: *const InterfaceDescriptor) !InterfaceClassDescriptor {
        const class_type = @as(InterfaceClassDescriptorType, @enumFromInt(interface.class));
        switch (class_type) {
            .Video => {
                if (video.VideoInterfaceDescriptorTree.read(allocator, reader)) |class| {
                    return InterfaceClassDescriptor{
                        .Video = class,
                    };
                } else |err| {
                    return err;
                }
            },
            else => |t| {
                std.debug.print("Class {any}\n", .{t});
                @panic("Handle Other Interface Class");
            },
        }
        @panic("Peek Interface Class");
    }

    pub fn deinit(self: *InterfaceClassDescriptor) void {
        switch (self.*) {
            .Video => |v| {
                v.deinit();
            },
            else => {
                @panic("Deallocate Self");
            },
        }
    }
};
