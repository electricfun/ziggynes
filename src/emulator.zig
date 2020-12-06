const std = @import("std");
const Cpu = @import("cpu.zig").Cpu;
const Opcode = @import("opcode.zig");
const warn = std.debug.warn;

pub const Emulator = struct {
    cpu: Cpu,
    opcodes: [0x100]Opcode.Opcode,
    current_opcode: Opcode.Opcode,
    current_address: u16,

    pub fn init() Emulator {
        var emulator = Emulator{
            .cpu = Cpu.init(),
            .opcodes = Opcode.generate_opcodes(),
            .current_address = 0x0000,
            .current_opcode = undefined,
        };
        return emulator;
    }

    pub fn emulate(self: *Emulator) void {
        self.current_opcode = self.opcodes[self.cpu.get_next_opcode_index()];
        self.current_address = self.cpu.resolve_address(self.current_opcode.addressing_mode);
        self.cpu.execute_instruction(self.current_opcode, self.current_address);
        self.log();
    }

    fn log(self: *Emulator) void {
        warn("\n{} A:{X} X:{X} Y:{X} P:{X} SP:{X}", self.current_opcode.name, self.cpu.reg_a, self.cpu.reg_x, self.cpu.reg_y, self.cpu.get_status_flags(), self.cpu.ram.stack_pointer);
    }
};
