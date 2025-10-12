const std = @import("std");
const types = @import("usb-types");
const Adapter = @import("usb-adapter").Adapter;
const Context = types.Context;
const DeviceData = types.DeviceData;
const DeviceDescriptor = types.descriptors.DeviceDescriptor;
const UsbError = types.UsbError;

pub const DeviceID = struct {
    vid: u16,
    pid: u16,
};

pub const Device = struct {
    const Self = @This();

    usb_vid: u16,
    usb_pid: u16,
    device_data: DeviceData,
    device_descriptor: DeviceDescriptor,
    adapter: Adapter,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, usb_vid: u16, usb_pid: u16) Self {
        const adapter = Adapter.init();
        return Self{
            .usb_vid = usb_vid,
            .usb_pid = usb_pid,
            .device_data = undefined,
            .device_descriptor = undefined,
            .adapter = adapter,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Self) void {
        self.adapter.deinit();
        self.device_data.deinit();
    }

    pub fn open(self: *Self) !void {
        const devices = try self.adapter.getDevices(self.allocator);
        var found = false;
        for (devices) |device| {
            // TODO: Handle Identical Devices
            if (!found and try device.getPID() == self.usb_pid and try device.getVID() == self.usb_vid) {
                if (device.getDescriptors()) |desc| {
                    self.device_data = device;
                    self.device_descriptor = desc;
                    found = true;
                } else |e| {
                    std.debug.print("Error {any}\n", .{e});
                    device.deinit();
                }
            } else {
                device.deinit();
            }
        }
        self.allocator.free(devices);

        if (!found) {
            return UsbError.DeviceNotFound;
        }
    }

    pub fn getIDs(allocator: std.mem.Allocator) ![]DeviceID {
        var adapter = Adapter.init();
        const devices = try adapter.getDevices(allocator);
        defer {
            for (devices) |device| {
                device.deinit();
            }
            allocator.free(devices);
            adapter.deinit();
        }

        var device_ids = std.array_list.AlignedManaged(DeviceID, std.mem.Alignment.@"2").init(allocator);
        for (devices) |device| {
            try device_ids.append(DeviceID{
                .pid = try device.getPID(),
                .vid = try device.getVID(),
            });
        }

        return device_ids.toOwnedSlice();
    }
};

//pub fn OpenDevice(context: Context, usb_vid: u16, usb_pid: u16) !*DeviceData {
//_ = usb_vid;
//_ = usb_pid;

//Driver.getDevices(context, &devices);
//for (devices.items, 0..) |usb_device, i| {
//const device_descriptor: DeviceDescriptor = usb_device.GetDeviceDescriptor();
//_ = device_descriptor;
//_ = i;
////if (usb_device.getDeviceDescriptor(&device_descriptor)) {
////if (device_descriptor.id_vendor == usb_vid and
////device_descriptor.id_product == usb_pid)
////{
////var data_buffer: [@sizeOf(DeviceData)]u8 = std.mem.zeroes([@sizeOf(DeviceData)]u8);
////var fba = std.heap.FixedBufferAllocator(&data_buffer);
////const new_device: *DeviceData = fba.allocator.create(DeviceData);
////new_device.* = devices.swapRemove(i);
////return new_device;
////}
////}
//}

//return UsbError.DeviceNotFound;
//}
