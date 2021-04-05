pub fn portio_cpux(offset: u16) *volatile u32 {
    return @intToPtr(*volatile u32, @as(usize, 0x01C2_0800) + offset);
}

pub fn portio_cpus(offset: u16) *volatile u32 {
    return @intToPtr(*volatile u32, @as(usize, 0x01F0_2C00) + offset);
}

fn verify_port_pin(comptime port: u8, comptime pin: u5) void {
    switch(port) {
        'B' => if(pin >= 10) @compileError("Pin out of range!"),
        'C' => if(pin >= 17) @compileError("Pin out of range!"),
        'D' => if(pin >= 25) @compileError("Pin out of range!"),
        'E' => if(pin >= 18) @compileError("Pin out of range!"),
        'F' => if(pin >= 7)  @compileError("Pin out of range!"),
        'G' => if(pin >= 14) @compileError("Pin out of range!"),
        'H' => if(pin >= 12) @compileError("Pin out of range!"),
        'L' => if(pin >= 13) @compileError("Pin out of range!"),
        else => @compileError("Unknown port!"),
    }
}

fn get_config(comptime port: u8, comptime pin: u5) *volatile u32 {
    const offset = @as(u16, @divTrunc(pin, 8) * 4);
    return switch(port) {
        'B' => portio_cpux(0x0024 + offset),
        'C' => portio_cpux(0x0048 + offset),
        'D' => portio_cpux(0x006C + offset),
        'E' => portio_cpux(0x0090 + offset),
        'F' => portio_cpux(0x00B4 + offset),
        'G' => portio_cpux(0x00D8 + offset),
        'H' => portio_cpux(0x00FC + offset),
        'L' => portio_cpus(0x0000 + offset),
        else => @compileError("Unknown port!"),
    };
}

fn get_data(comptime port: u8) *volatile u32 {
    return switch(port) {
        'B' => portio_cpux(0x0034),
        'C' => portio_cpux(0x0058),
        'D' => portio_cpux(0x007C),
        'E' => portio_cpux(0x00A0),
        'F' => portio_cpux(0x00C4),
        'G' => portio_cpux(0x00E8),
        'H' => portio_cpux(0x010C),
        'L' => portio_cpus(0x0010),
        else => @compileError("Unknown port!"),
    };
}

pub fn configure_port(comptime port: u8, comptime pin: u5, io: enum{Input, Output}) void {
    comptime {
        verify_port_pin(port, pin);
    }

    const field: u32 = if(io == .Input) 0b000 else 0b001;
    const config = comptime get_config(port, pin);
    const start_bit = comptime @as(u8, (pin%8)) * 4;
    config.* = (config.* & ~@as(u32, 0x7 << start_bit)) | (field << start_bit);
}

// Sets a port to output and writes the value to the pin
pub fn output_port(comptime port: u8, comptime pin: u5, value: bool) void {
    configure_port(port, pin, .Output);
    write_port(port, pin, value);
}

// Sets a port to input and reads the value from the pin
pub fn input_port(comptime port: u8, comptime pin: u5) bool {
    configure_port(port, pin, .Input);
    return read_port(port, pin);
}

pub fn write_port(comptime port: u8, comptime pin: u5, value: bool) void {
    comptime {
        verify_port_pin(port, pin);
    }

    const curr_bit: u32 = 1 << pin;
    const d = get_data(port);
    if(value) {
        d.* |= curr_bit;
    } else {
        d.* &= ~curr_bit;
    }
}

pub fn read_port(comptime port: u8, comptime pin: u5) bool {
    comptime {
        verify_port_pin(port, pin);
    }

    const d = get_data(port);
    return (d.* & (1 << pin)) != 0;
}
