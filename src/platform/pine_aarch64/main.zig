pub const sabaton = @import("../../sabaton.zig");
pub const io = sabaton.io_impl.status_uart_mmio_32;
pub const ElfType = [*]u8;
pub const panic = sabaton.panic;

pub const display = @import("display.zig");
pub const smp = @import("smp.zig");
pub const timer = @import("../timer.zig");

const led = @import("led.zig");

// We know the page size is 0x1000
pub fn get_page_size() u64 {
  return 0x1000;
}

fn clocks_init() void {
  // Cock and ball torture?
  // Clock and PLL torture.
  init_pll(0x0010, 0x83001801); // PLL_VIDEO0
  init_pll(0x0028, 0x80041811); // PLL_PERIPH0
  init_pll(0x0048, 0x83006207); // PLL_DE
  ccu(0x0040).* = 0x00C00000;
  init_pll(0x0040, 0x80C00418); // PLL_MIPI

  // Cock gating registers?
  // Clock gating registers.
  ccu(0x0060).* = 0x33800040; // BUS_CLK_GATING_REG0
  ccu(0x0064).* = 0x0020181A; // BUS_CLK_GATING_REG1
  ccu(0x0068).* = 0x00000020; // BUS_CLK_GATING_REG2
  ccu(0x006C).* = 0x00010000; // BUS_CLK_GATING_REG3
  //ccu(0x0070).* = 0x00000000; // BUS_CLK_GATING_REG4

  ccu(0x0088).* = 0x0100000B; // SMHC0_CLK_REG
  ccu(0x008C).* = 0x0001000E; // SMHC0_CLK_REG
  ccu(0x0090).* = 0x01000005; // SMHC0_CLK_REG

  ccu(0x00CC).* = 0x00030303; // USBPHY_CFG_REG

  ccu(0x0104).* = 0x81000000; // DE_CLK_REG
  ccu(0x0118).* = 0x80000000; // TCON0_CLK_REG
  ccu(0x0150).* = 0x80000000; // HDMI_CLK_REG
  ccu(0x0154).* = 0x80000000; // HDMI_SLOW_CLK_REG
  ccu(0x0168).* = 0x00008001; // MIPI_DSI_CLK_REG

  //ccu(0x0224).* = 0x10040000; // PLL_AUDIO_BIAS_REG

  ccu(0x021C).* = 0x10100010;
  ccu(0x0224).* = 0x10040000;
  ccu(0x0228).* = 0x10100000;
  ccu(0x022C).* = 0x10100000;
  ccu(0x0234).* = 0x10100010;
  ccu(0x0238).* = 0x10100000;
  ccu(0x023C).* = 0x10100000;
  ccu(0x0240).* = 0xF8100400;
  ccu(0x0244).* = 0x10100000;
  ccu(0x0248).* = 0x10100000;
  ccu(0x0270).* = 0x8A002005;
}

fn reset_devices() void {
  const reg0_devs: u32 = 0
    | (1 << 29) // USB-OHCI0
    | (1 << 28) // USB-OTG-OHCI
    | (1 << 25) // USB-EHCI0
    | (1 << 24) // USB-OTG-EHCI0
    | (1 << 23) // USB-OTG-Device
    | (1 << 13) // NAND
    | (1 << 1) // MIPI_DSI
  ;

  const reg1_devs: u32 = 0
    | (1 << 22) // SPINLOCK
    | (1 << 21) // MSGBOX
    | (1 << 20) // GPU
    | (1 << 12) // DE
    | (1 << 11) // HDMI1
    | (1 << 10) // HDMI0
    | (1 << 5) // DEINTERLACE
    | (1 << 4) // TCON1
    | (1 << 3) // TCON0
  ;

  ccu(0x02C0).* &= ~reg0_devs;
  ccu(0x02C4).* &= ~reg1_devs;

  ccu(0x02C0).* |= reg0_devs;
  ccu(0x02C4).* |= reg1_devs;
}

export fn _main() linksection(".text.main") noreturn {
  // @call(.{.modifier = .always_inline}, clocks_init, .{});
  // @call(.{.modifier = .always_inline}, reset_devices, .{});
  // ccu(0x0320).* = 0x00001FFF;
  @call(.{.modifier = .always_inline}, @import("pmic.zig").init, .{});
  @call(.{.modifier = .always_inline}, led.configure_led, .{});
  // Orange
  led.output(.{.green = true, .red = true, .blue = false});
  @call(.{.modifier = .always_inline}, sabaton.main, .{});
}

pub fn panic_hook() void {
  // Red
  led.output(.{.green = false, .red = true, .blue = false});
}

pub fn launch_kernel_hook() void {
  // Blue
  led.output(.{.green = false, .red = false, .blue = true});
}

pub fn get_kernel() ElfType {
  return sabaton.near("kernel_file_loc").read([*]u8);
}

// pub fn get_dtb() []u8 {
//   return sabaton.near("dram_base").read([*]u8)[0..0x100000];
// }

pub fn get_dram() []u8 {
  return sabaton.near("dram_base").read([*]u8)[0..get_dram_size()];
}

fn get_dram_size() u64 {
  return 0x80000000;
}

pub fn map_platform(root: *sabaton.paging.Root) void {
  // MMIO area
  sabaton.paging.map(0, 0, 1024 * 1024 * 1024, .rw, .mmio, root);
  sabaton.paging.map(sabaton.upper_half_phys_base, 0, 1024 * 1024 * 1024, .rw, .mmio, root);
}

pub fn add_platform_tags(kernel_header: *sabaton.Stivale2hdr) void {
  sabaton.add_tag(&sabaton.near("uart_tag").addr(sabaton.Stivale2tag)[0]);
  sabaton.add_tag(&sabaton.near("devicetree_tag").addr(sabaton.Stivale2tag)[0]);
}

pub fn get_uart_info() io.Info {
  const base = 0x1C28000;
  return .{
    .uart = @intToPtr(*volatile u32, base),
    .status = @intToPtr(*volatile u32, base + 0x14),
    .mask = 0x20,
    .value = 0x20,
  };
}
