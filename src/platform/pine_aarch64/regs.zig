// Register base addresses
fn register_base(comptime base: usize) fn(offset: usize) *volatile u32 {
    return struct {
        fn f(offset: usize) *volatile u32 {
            return @intToPtr(*volatile u32, comptime base + offset);
        }
    }.f;
}

pub const portio_cpux = register_base(0x01C2_0800);
pub const portio_cpus = register_base(0x01F0_2C00);
pub const tcon0       = register_base(0x01C0_C000);
pub const de          = register_base(0x0100_0000);
pub const mipi_dsi    = register_base(0x01CA_0000);
pub const rsb         = register_base(0x01F0_3400);
pub const ccu         = register_base(0x01C2_0000);
pub const prcm        = register_base(0x01F0_1400);
pub const pio         = register_base(0x01F0_2C00);

// Register collection offsets
fn register_offset(comptime base: anytype, comptime regs_offset: usize) fn(offset: usize) *volatile u32 {
    return struct {
        fn f(offset: usize) *volatile u32 {
            return base(comptime regs_offset + offset);
        }
    }.f;
}

pub const de_rt_mixer = register_offset(de,          0x0010_0000);
pub const de_bld      = register_offset(de_rt_mixer, 0x0000_1000);
pub const de_olv_ui   = register_offset(de_rt_mixer, 0x0000_3000);

// Extra PLL functionality
pub fn wait_stable(pll_addr: *volatile u32) void {
  while((pll_addr.* & (1 << 28)) == 0) { }
}

pub fn init_pll(offset: usize, pll_value: u32) void {
  const reg = ccu(offset);
  reg.* = pll_value;
  wait_stable(reg);
}

// GPIO
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
    const d = comptime get_data(port);
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

    const d = comptime get_data(port);
    return (d.* & (1 << pin)) != 0;
}

    // {
    //     // PH configure register 1
    //     const ph = regs.portio(0x100);
    //     sabaton.log_hex("PHCR1: ", ph.*);
    //     // Make pin 8 output
    //     ph.* = (ph.* & ~@as(u32, 0x7)) | 0b001;
    // }
    // // Enable output PH8
    // portio(0x10C).* |= (1 << 8);
    // sabaton.puts("Output on PH8 active\n");
