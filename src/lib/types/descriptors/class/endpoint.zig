const std = @import("std");
const video = @import("video/Endpoint.zig");
const InterfaceClassDescriptorType = @import("interface.zig").InterfaceClassDescriptorType;
const InterfaceDescriptor = @import("../Interface.zig").InterfaceDescriptor;

pub const EndpointClassDescriptor = union(InterfaceClassDescriptorType) {
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
    Video: video.VideoEndpointDescriptorTree,
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

    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader, interface: *const InterfaceDescriptor) !EndpointClassDescriptor {
        const class_type = @as(InterfaceClassDescriptorType, @enumFromInt(interface.class));
        switch (class_type) {
            .Video => {
                if (video.VideoEndpointDescriptorTree.read(allocator, reader)) |endpoint| {
                    return EndpointClassDescriptor{
                        .Video = endpoint,
                    };
                } else |err| {
                    return err;
                }
            },
            else => {
                std.debug.print("Type: {any}\n", .{class_type});
                @panic("Read Class Descriptor");
            },
        }
    }

    pub fn deinit(self: *EndpointClassDescriptor) void {
        switch (self.*) {
            .Video => |*v| {
                v.deinit();
            },
            else => {
                @panic("Deallocate Self");
            },
        }
    }
};
