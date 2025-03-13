pub const ConfigurationDescriptor = packed struct {
    length: u8,
    descriptor_type: u8,
    total_length: u8,
    num_interfaces: u8,
    configuration_value: u8,
    configuration: u8,
    attributes: u8,
    max_power: u8,
};
