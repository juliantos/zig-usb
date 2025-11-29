const std = @import("std");
const builtin = @import("builtin");
pub const interface = @import("class/interface.zig");
pub const endpoint = @import("class/endpoint.zig");
pub const ClassDescriptor = @import("class/Descriptor.zig").ClassDescriptor;

// pub const DeviceClassDescriptorType = enum(u8) {
//     UseInterface = 0x00,
//     Comms = 0x02,
//     Hub = 0x09,
//     Billboard = 0x11,
//     Diagnositic = 0xdc,
//     Misc = 0xef,
//     VendorSpecific = 0xff,
// };
