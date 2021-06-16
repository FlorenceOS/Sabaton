const regs = @import("regs.zig");
const timer = @import("root").timer;
const sabaton = @import("root").sabaton;

const runtime_addr  = 0x002D;
const hardware_addr = 0x03A3;

const cpux_clock = 408000000;
const k = if(cpux_clock >= 768000000) 2 else 1;
const n = cpux_clock / (24000000 * k);

pub fn init() void {
  if(true)
    return;
  regs.ccu(0x0320).* = 0x1FFF;
  regs.ccu(0x0050).* = (2 << 0) | (1 << 8) | (1 << 16);
  timer.sleep_us(2);
  regs.init_pll(0x0000, (1 << 31) | (0 << 16) | ((n - 1) << 8) | ((k - 1) << 4) | (0 << 0));
  regs.ccu(0x0050).* = (2 << 0) | (1 << 8) | (2 << 16);
  regs.init_pll(0x0028, 0x80041811);
  timer.sleep_us(2);
  regs.ccu(0x0054).* = (3 << 12) | (1 << 8) | (2 << 6) | (1 << 4);
  // Set new clock
  sabaton.log_hex("The reg is ", regs.ccu(0x015C).*);
  regs.ccu(0x015C).* = (1 << 31) | (1 << 24) | (2 << 0);

  // 
  regs.ccu(0x0058).* = (1 << 24) | (0 << 16) | (0 << 0);

  if(sabaton.safety) {
    if(regs.prcm(0x0028).* & 0x01 != 0x01) @panic("PMIC: Invalid prcm 0x0028");
    if(regs.pio (0x0000).* & 0xFF != 0x22) @panic("PMIC: Invalid pio  0x0000");
    if(regs.pio (0x0014).* & 0x0F != 0x0A) @panic("PMIC: Invalid pio  0x0014");
    if(regs.pio (0x001C).* & 0x0F != 0x05) @panic("PMIC: Invalid pio  0x001C");
  }

  regs.prcm(0x00B0).* &= ~@as(u32, 1 << 3);
  regs.prcm(0x00B0).* |=  @as(u32, 1 << 3);

  // Soft reset the controller
  regs.rsb(0x0000).* = 0x01;
  wait_eq("init soft reset", regs.rsb(0x0000), 0x01, 0x01);

  set_bus_speed(24000000, 400000);
  set_device_mode(0x7C3E00);
  set_bus_speed(24000000, 3000000);

  regs.rsb(0x0030).* = (runtime_addr << 16) | hardware_addr;
  regs.rsb(0x002C).* = 0xE8;
  regs.rsb(0x0000).* = 0x80;
  wait_transaction();
}

fn set_bus_speed(comptime source: u32, comptime freq: u32) void {
  regs.rsb(0x0004).* = (source / freq / 2 - 1) | (1 << 8);
}

fn set_device_mode(comptime mode: u32) void {
  regs.rsb(0x0028).* = mode | (1 << 31);
  wait_eq("set_device_mode", regs.rsb(0x0028), (1 << 31), (1 << 31));
}

fn wait_eq(reason: [*:0]const u8, reg: *volatile u32, mask: u32, value: u32) void {
  var counter: usize = 0;
  while(reg.* & mask != value) : (counter += 1) {
    if(counter > 100000) {
      if(sabaton.safety) {
        sabaton.puts("PMIC: Wait_eq reason: ");
        sabaton.puts(reason);
        sabaton.putchar('\n');
        sabaton.log_hex("Waiting for register at ", reg);
        sabaton.log_hex("Mask:  ", mask);
        sabaton.log_hex("Value: ", value);
      }
      @panic("PMIC: Wait_eq timeout!");
    }
  }
}

fn wait_transaction() void {
  wait_eq("wait_transaction", regs.rsb(0x0000), (1 << 7), (1 << 7));
  if(true)
    return;
  if(sabaton.safety) {
    const val = regs.rsb(0x000C).*;
    if(val != 0x01) {
      sabaton.log_hex("PMIC STAT: ", val);
      @panic("PMIC: STAT invalid!");
    }
  }
}

fn rw_common(reg: u32) void {
  regs.rsb(0x0030).* = (runtime_addr << 16);
  regs.rsb(0x0010).* = reg;
  // Start transaction
  regs.rsb(0x0000).* = 0x80;
  wait_transaction();
}

pub fn write(reg: u32, value: u8) void {
  // Read one byte
  regs.rsb(0x002C).* = 0x8B;
  regs.rsb(0x001C).* = value;
  rw_common(reg);
}

pub fn read(reg: u32) u8 {
  // Write one byte
  regs.rsb(0x002C).* = 0x4E;
  rw_common(reg);
  return @truncate(u8, regs.rsb(0x001C).*);
}

pub fn clearset_bits(reg: u32, to_clear: u8, to_set: u8) void {
  write(reg, (read(reg) & ~to_clear) | to_set);
}

pub fn set_bits(reg: u32, bits: u8) void {
  clearset_bits(reg, 0, bits);
}

pub fn clear_bits(reg: u32, bits: u8) void {
  clearset_bits(reg, bits, 0);
}
