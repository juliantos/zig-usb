const std = @import("std");

pub const VideoInterfaceDescriptorTree = @import("VideoInterface.zig").VideoInterfaceDescriptorTree;

pub const DeviceClassDescriptorType = enum(u8) {
    UseInterface = 0x00,
    Comms = 0x02,
    Hub = 0x09,
    Billboard = 0x11,
    Diagnositic = 0xdc,
    Misc = 0xef,
    VendorSpecific = 0xff,
};

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
    Audio: u64,
    Comms: u64,
    HID: u64,
    Physical: u64,
    Image: u64,
    Printer: u64,
    MassStorage: u64,
    CDC_Data: u64,
    SmartCard: u64,
    ContentSecurity: u64,
    Video: VideoInterfaceDescriptorTree,
    PersonalHealthcare: u64,
    AudioVideo: u64,
    UsbTypeC_Bridge: u64,
    UsbBulkDisplay: u64,
    MCTP_OverUsb: u64,
    I3C: u64,
    Diagnostic: u64,
    WirelessController: u64,
    Misc: u64,
    AppSpecific: u64,
    VendorSpecific: u64,

    pub fn peek(allocator: std.mem.Allocator, reader: *std.io.Reader) !InterfaceClassDescriptor {
        _ = allocator;
        _ = reader;
        @panic("Peek Interface Class");
    }
};
