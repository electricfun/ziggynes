const mem = @import("std").mem;
const warn = @import("std").debug.warn;

pub const Ram = struct {
    memory: [0xFFFF]u8,
    stack_pointer: u8,

    pub fn init() Ram {
        var ram = Ram{
            .memory = []u8{0} ** 0xFFFF,
            .stack_pointer = 0xFD,
        };

        mem.set(u8, ram.memory[0x0000..0x07FF], 0xFF);
        mem.set(u8, ram.memory[0x4000..0x400F], 0x00);

        ram.memory[0x0008] = 0xF7;
        ram.memory[0x0009] = 0xEF;
        ram.memory[0x000A] = 0xDF;
        ram.memory[0x000F] = 0xBF;
        ram.memory[0x4015] = 0x00;
        ram.memory[0x4017] = 0x00;

        return ram;
    }

    pub fn read_8(self: *Ram, address: u16) u8 {
        return self.memory[address];
    }

    pub fn read_16(self: *Ram, address: u16) u16 {
        var highByte: u16 = @intCast(u16, self.read_8(address + 1));
        var lowByte: u16 = @intCast(u16, self.read_8(address));
        return highByte << 8 | lowByte;
    }

    pub fn read_16_with_bug(self: *Ram, address: u16) u16 {
        var highByte: u16 = @intCast(u16, self.read_8((address + 1) & 0xFF));
        var lowByte: u16 = @intCast(u16, self.read_8(address));
        return highByte << 8 | lowByte;
    }

    pub fn write(self: *Ram, address: u16, value: u8) void {
        self.memory[address] = value;
    }

    pub fn push_to_stack(self: *Ram, value: u8) void {
        self.write(0x0100 + @intCast(u16, self.stack_pointer), value);
        self.decrement_stack_pointer();
    }

    pub fn pop_from_stack(self: *Ram) u8 {
        self.increment_stack_pointer();
        return self.read_8(0x0100 + @intCast(u16, self.stack_pointer));
    }

    pub fn increment_stack_pointer(self: *Ram) void {
        self.stack_pointer += 1;
        self.stack_pointer &= 0xFF;
    }

    pub fn decrement_stack_pointer(self: *Ram) void {
        self.stack_pointer -= 1;
        self.stack_pointer &= 0xFF;
    }
};
