pub const LinuxError = error{
    NoDescriptors,
    NoDeviceSysPath,
    NoDeviceEnum,
    NoDeviceEnumSubsystem,
    NoDeviceEnumUnref,
    NoConfiguration,
    NoAssociationOrInterface,
    UndefinedDescriptor,
};
