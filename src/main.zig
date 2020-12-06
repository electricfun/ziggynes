const std = @import("std");
const Emulator = @import("emulator.zig").Emulator;
const warn = std.debug.warn;

pub fn main() void {
    var emulator = Emulator.init();
}
