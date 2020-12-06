const std = @import("std");
const expect = std.testing.expect;
const Opcode = @import("opcode.zig");
const OpcodeEnum = @import("enum.zig").OpcodeEnum;
const AddressingModeEnum = @import("enum.zig").AddressingModeEnum;

test "should successfully create a new opcode" {
    const opcode = Opcode.Opcode.init(OpcodeEnum.ADC, 0x69, AddressingModeEnum.Immediate, 2, 2);
    expect(opcode.name == OpcodeEnum.ADC);
    expect(opcode.code == 0x69);
    expect(opcode.addressing_mode == AddressingModeEnum.Immediate);
    expect(opcode.size == 2);
    expect(opcode.cycles == 2);
}

test "should successfully generate a list of all opcodes" {
    const opcodes = Opcode.generate_opcodes();
    expect(opcodes.len == 0x100);

    var testOpcode0x00 = opcodes[0x00];
    expect(testOpcode0x00.name == OpcodeEnum.BRK);
    expect(testOpcode0x00.code == 0x00);
    expect(testOpcode0x00.addressing_mode == AddressingModeEnum.Implicit);
    expect(testOpcode0x00.size == 1);
    expect(testOpcode0x00.cycles == 7);

    var testOpcode0xFF = opcodes[0xFF];
    expect(testOpcode0xFF.name == OpcodeEnum.ISC);
    expect(testOpcode0xFF.code == 0xFF);
    expect(testOpcode0xFF.addressing_mode == AddressingModeEnum.AbsoluteX);
    expect(testOpcode0xFF.size == 3);
    expect(testOpcode0xFF.cycles == 7);
}
