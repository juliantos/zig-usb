pub const UsbError = error{
    AccessDenied,
    OutOfMemory,
    DeviceNotFound,
    InvalidContext,
    DriverFailure,
};
