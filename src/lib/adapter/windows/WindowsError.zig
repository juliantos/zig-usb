pub const WindowsError = error{
    NoEnumInfo,
    NoRegistryProperty,
    NoDevInfo,
    NoInstanceInfo,
    NoDescriptors,
    NoDevice,
    NoHub,
    NoRootHub,
    NoNodeInformation,
    NoHubInformation,
    NoHubCapabilities,
    NoPortProperties,

    BadDescriptor,
    BadRootHub,

    EmptyPort,
};
