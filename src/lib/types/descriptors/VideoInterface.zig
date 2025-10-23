const Descriptor = @import("Descriptor.zig").Descriptor;
const InterfaceDescriptor = @import("Interface.zig").InterfaceDescriptor;

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

pub const VideoEndpointSubType = enum(u8) {
    Undefined,
    General,
    Endpoint,
    Interrupt,
};

pub const VideoClassInterfaceDescriptor = extern struct {
    descriptor: Descriptor,
    subtype: VideoInterfaceVCSubType,
    uvc: u16,
    total_length: u16,
    clock_frequency: u32,
    interface_collection: u8,
    interface_number: [1]u8,
};

pub const VideoInterfaceDescriptorTree = struct {
    const Self = @This();

    interface: InterfaceDescriptor,
    descriptor: VideoClassInterfaceDescriptor,
};
