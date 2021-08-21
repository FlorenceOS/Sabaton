pub const MMIO_BASE = 0x3F000000;
const MMIO_BANK = RegBank.base(0x3F000000);

const AUX_BANK = MMIO_BANK.sub(0x215000);
pub const AUX_ENABLES = AUX_BANK.reg(0x04);
pub const AUX_MU_IO = AUX_BANK.reg(0x40);
pub const AUX_MU_IER = AUX_BANK.reg(0x44);
pub const AUX_MU_IIR = AUX_BANK.reg(0x48);
pub const AUX_MU_LCR = AUX_BANK.reg(0x4C);
pub const AUX_MU_MCR = AUX_BANK.reg(0x50);
pub const AUX_MU_LSR = AUX_BANK.reg(0x54);
pub const AUX_MU_MSR = AUX_BANK.reg(0x58);
pub const AUX_MU_SCRATCH = AUX_BANK.reg(0x5C);
pub const AUX_MU_CNTL = AUX_BANK.reg(0x60);
pub const AUX_MU_STAT = AUX_BANK.reg(0x64);
pub const AUX_MU_BAUD = AUX_BANK.reg(0x68);

const GPIO_BANK = MMIO_BANK.sub(0x200000);
pub const GPFSEL0 = GPIO_BANK.reg(0x00);
pub const GPFSEL1 = GPIO_BANK.reg(0x04);
pub const GPPUD = GPIO_BANK.reg(0x94);
pub const GPPUDCLK0 = GPIO_BANK.reg(0x98);

const MBOX_BANK = MMIO_BANK.sub(0xB880);
pub const MBOX_READ = MBOX_BANK.reg(0x00);
pub const MBOX_CONFIG = MBOX_BANK.reg(0x1C);
pub const MBOX_WRITE = MBOX_BANK.reg(0x20);
pub const MBOX_STATUS = MBOX_BANK.reg(0x18);

const RegBank = struct {
    bank_base: usize,

    /// Create the base register bank
    pub fn base(comptime bank_base: comptime_int) @This() {
        return .{ .bank_base = bank_base };
    }

    /// Make a smaller register sub-bank out of a bigger one
    pub fn sub(self: @This(), comptime offset: comptime_int) @This() {
        return .{ .bank_base = self.bank_base + offset };
    }

    /// Define a single register
    pub fn reg(self: @This(), comptime offset: comptime_int) *volatile u32 {
        return @intToPtr(*volatile u32, self.bank_base + offset);
    }
};

pub fn mbox_call(channel: u4, ptr: usize) void {
    while ((MBOX_STATUS.* & 0x80000000) != 0) {}
    const addr = @truncate(u32, ptr) | @as(u32, channel);
    MBOX_WRITE.* = addr;
}

// This is the miniUART, it requires enable_uart=1 in config.txt
pub fn miniuart_init() void {
    // set pins 14-15 to alt5 (miniuart). gpfsel1 handles pins 10 to 19
    GPFSEL1.* = gpio_fsel(14 - 10, .Alt5, gpio_fsel(15 - 10, .Alt5, GPFSEL1.*));
    GPPUD.* = 0; // disable pullup, pulldown for the clocked regs
    delay(150);
    GPPUDCLK0.* = (1 << 14) | (1 << 15); // clock pins 14-15
    delay(150);
    GPPUDCLK0.* = 0; // clear clock for next usage
    delay(150);

    AUX_ENABLES.* |= 1; // enable the uart regs
    AUX_MU_CNTL.* = 0; // disable uart functionality to set the regs
    AUX_MU_IER.* = 0; // disable uart interrupts
    AUX_MU_LCR.* = 0b11; // 8-bit mode
    AUX_MU_MCR.* = 0; // RTS always high
    AUX_MU_IIR.* = 0xc6;
    AUX_MU_BAUD.* = minuart_calculate_baud(115200);
    AUX_MU_CNTL.* = 0b11; // enable tx and rx fifos
}

const VC4_CLOCK = 250 * 1000 * 1000; // 250 MHz

fn minuart_calculate_baud(baudrate: u32) u32 {
    return VC4_CLOCK / (8 * baudrate) - 1; // the bcm2835 spec gives this formula: baudrate = vc4_clock / (8*(reg + 1))
}

fn delay(cycles: usize) void {
    var i: u32 = 0;
    while (i < cycles) : (i += 1) {
        asm volatile ("nop");
    }
}

const GpioMode = enum(u3) {
    // zig fmt: off
    Input  = 0b000,
    Output = 0b001,
    Alt5   = 0b010,
    Alt4   = 0b011,
    Alt0   = 0b100,
    Alt1   = 0b101,
    Alt2   = 0b110,
    Alt3   = 0b111,
    // zig fmt: on
};

fn gpio_fsel(pin: u5, mode: GpioMode, val: u32) u32 {
    const mode_int: u32 = @enumToInt(mode);
    const bit = pin * 3;
    var temp = val;
    temp &= ~(@as(u32, 0b111) << bit);
    temp |= mode_int << bit;
    return temp;
}
