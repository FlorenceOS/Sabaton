const regs = @import("regs.zig");

pub fn output(col: struct {red: bool, green: bool, blue: bool}) void {
  regs.write_port('D', 18, col.green);
  regs.write_port('D', 19, col.red);
  regs.write_port('D', 20, col.blue);
}

pub fn configure_led() void {
  regs.configure_port('D', 18, .Output);
  regs.configure_port('D', 19, .Output);
  regs.configure_port('D', 20, .Output);
}
