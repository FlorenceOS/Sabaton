const sabaton = @import("../../sabaton.zig");

var ready = false;

pub fn init() void {
  if(ready)
    return;

  ready = true;
}
