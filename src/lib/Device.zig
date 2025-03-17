const std = @import("std");
const types = @import("usb-types");
const Context = types.Context;
const DeviceData = types.DeviceData;
const DeviceDescriptor = types.DeviceDescriptor;
const UsbError = types.UsbError;
const Driver = @import("usb-driver").Driver;

pub const Device = struct {
    const Self = @This();

    usb_vid: u16,
    usb_pid: u16,
    device_data: DeviceData,
    device_descriptor: DeviceDescriptor,
    driver: Driver,

    pub fn init(usb_vid: u16, usb_pid: u16) Self {
        const driver = Driver.init();
        return Self{
            .usb_vid = usb_vid,
            .usb_pid = usb_pid,
            .device_data = undefined,
            .device_descriptor = undefined,
            .driver = driver,
        };
    }

    pub fn open(self: Self) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();
        const devices = try self.driver.GetDevices(allocator);
        defer {
            for (devices) |*device| {
                device.deinit();
            }
            allocator.free(devices);
        }
        for (devices, 0..) |*device, i| {
            std.debug.print("Device {any} {d}\n", .{ device, i });
            try self.driver.closeDevice(device);
            //const device_descriptor: DeviceDescriptor = try self.driver.GetDeviceDescriptor(device);
            //std.debug.print("{d} {any}", .{ i, device_descriptor });
        }

        return UsbError.DeviceNotFound;
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
