const std = @import("std");
const expect = std.testing.expect;
const warn = std.debug.warn;
const Cpu = @import("cpu.zig").Cpu;
const Opcode = @import("opcode.zig").Opcode;
const OpcodeEnum = @import("enum.zig").OpcodeEnum;
const AddressingModeEnum = @import("enum.zig").AddressingModeEnum;

test "should initialize correct internal registers and flags" {
    const cpu = Cpu.init();
    expect(cpu.program_counter == 0xC000);

    expect(cpu.reg_a == 0x00);
    expect(cpu.reg_x == 0x00);
    expect(cpu.reg_y == 0x00);

    expect(cpu.f_carry == 0x00);
    expect(cpu.f_zero == 0x00);
    expect(cpu.f_interrupt_disable == 0x01);
    expect(cpu.f_interrupt_disable_temp == 0x01);
    expect(cpu.f_decimal == 0x00);
    expect(cpu.f_break == 0x00);
    expect(cpu.f_break_temp == 0x00);
    expect(cpu.f_unused == 0x01);
    expect(cpu.f_overflow == 0x00);
    expect(cpu.f_negative == 0x00);
}

test "should correctly update status flags from value" {
    var cpu = Cpu.init();
    cpu.set_status_flags(0x42);
    expect(cpu.f_carry == 0);
    expect(cpu.f_zero == 1);
    expect(cpu.f_interrupt_disable == 0);
    expect(cpu.f_decimal == 0);
    expect(cpu.f_break == 0);
    expect(cpu.f_unused == 1);
    expect(cpu.f_overflow == 1);
    expect(cpu.f_negative == 0);

    cpu.set_status_flags(0x00);
    expect(cpu.f_carry == 0);
    expect(cpu.f_zero == 0);
    expect(cpu.f_interrupt_disable == 0);
    expect(cpu.f_decimal == 0);
    expect(cpu.f_break == 0);
    expect(cpu.f_unused == 1);
    expect(cpu.f_overflow == 0);
    expect(cpu.f_negative == 0);

    cpu.set_status_flags(0xFF);
    expect(cpu.f_carry == 1);
    expect(cpu.f_zero == 1);
    expect(cpu.f_interrupt_disable == 1);
    expect(cpu.f_decimal == 1);
    expect(cpu.f_break == 1);
    expect(cpu.f_unused == 1);
    expect(cpu.f_overflow == 1);
    expect(cpu.f_negative == 1);
}

test "should correctly get status flag value" {
    var cpu = Cpu.init();
    cpu.set_status_flags(0x42);
    expect(cpu.get_status_flags() == 0x62);
}

test "should correctly resolve Absolute address" {
    var cpu = Cpu.init();
    var address: u16 = undefined;

    cpu.ram.write(cpu.program_counter, 0x34);
    cpu.ram.write(cpu.program_counter + 1, 0x12);
    address = cpu.resolve_address(AddressingModeEnum.Absolute);
    expect(address == 0x1234);
    expect(cpu.cycles == 0);
}

test "should correctly resolve AbsoluteX address" {
    var cpu = Cpu.init();
    var address: u16 = undefined;

    cpu.program_counter = 0xC000;
    cpu.cycles = 0;
    cpu.ram.write(cpu.program_counter, 0x34);
    cpu.ram.write(cpu.program_counter + 1, 0x12);
    cpu.reg_x = 0x01;
    address = cpu.resolve_address(AddressingModeEnum.AbsoluteX);
    expect(address == 0x1235);
    expect(cpu.cycles == 0);

    cpu.program_counter = 0xC000;
    cpu.cycles = 0;
    cpu.ram.write(cpu.program_counter, 0xFF);
    cpu.ram.write(cpu.program_counter + 1, 0x01);
    cpu.reg_x = 0x01;
    address = cpu.resolve_address(AddressingModeEnum.AbsoluteX);
    expect(address == 0x0200);
    expect(cpu.cycles == 1);
}

test "should correctly resolve AbsoluteY address" {
    var cpu = Cpu.init();
    var address: u16 = undefined;

    cpu.program_counter = 0xC000;
    cpu.cycles = 0;
    cpu.ram.write(cpu.program_counter, 0x34);
    cpu.ram.write(cpu.program_counter + 1, 0x12);
    cpu.reg_y = 0x01;
    address = cpu.resolve_address(AddressingModeEnum.AbsoluteY);
    expect(address == 0x1235);
    expect(cpu.cycles == 0);

    cpu.program_counter = 0xC000;
    cpu.cycles = 0;
    cpu.ram.write(cpu.program_counter, 0xFF);
    cpu.ram.write(cpu.program_counter + 1, 0x01);
    cpu.reg_y = 0x01;
    address = cpu.resolve_address(AddressingModeEnum.AbsoluteY);
    expect(address == 0x0200);
    expect(cpu.cycles == 1);
}

test "should correctly resolve Accumulator address" {
    var cpu = Cpu.init();
    var address: u16 = undefined;

    cpu.reg_a = 0x42;
    address = cpu.resolve_address(AddressingModeEnum.Accumulator);
    expect(address == 0x0042);
    expect(cpu.cycles == 0);
}

test "should correctly resolve Immediate address" {
    var cpu = Cpu.init();
    var address: u16 = undefined;

    address = cpu.resolve_address(AddressingModeEnum.Immediate);
    expect(address == 0xC000);
    expect(cpu.cycles == 0);
}

test "should correctly resolve Indirect address" {
    var cpu = Cpu.init();
    var address: u16 = undefined;

    cpu.program_counter = 0xC000;
    cpu.cycles = 0;
    cpu.ram.write(cpu.program_counter, 0x34);
    cpu.ram.write(cpu.program_counter + 1, 0x12);
    cpu.ram.write(0x1234, 0x78);
    cpu.ram.write(0x1235, 0x56);
    address = cpu.resolve_address(AddressingModeEnum.Indirect);
    expect(address == 0x5678);
    expect(cpu.cycles == 0);

    cpu.program_counter = 0xC000;
    cpu.cycles = 0;
    cpu.ram.write(cpu.program_counter, 0xFF);
    cpu.ram.write(cpu.program_counter + 1, 0x00);
    address = cpu.resolve_address(AddressingModeEnum.Indirect);
    expect(address == 0x0100);
    expect(cpu.cycles == 0);
}

test "should correctly resolve IndirectX address" {
    var cpu = Cpu.init();
    var address: u16 = undefined;

    cpu.program_counter = 0xC000;
    cpu.cycles = 0;
    cpu.ram.write(cpu.program_counter, 0x42);
    cpu.reg_x = 0x01;
    cpu.ram.write(0x0043, 0x78);
    cpu.ram.write(0x0044, 0x56);
    address = cpu.resolve_address(AddressingModeEnum.IndirectX);
    expect(address == 0x5678);
    expect(cpu.cycles == 0);

    cpu.program_counter = 0xC000;
    cpu.cycles = 0;
    cpu.ram.write(cpu.program_counter, 0xFF);
    cpu.reg_x = 0x00;
    cpu.ram.write(0x00FF, 0x34);
    cpu.ram.write(0x0000, 0x12);
    address = cpu.resolve_address(AddressingModeEnum.IndirectX);
    expect(address == 0x1234);
    expect(cpu.cycles == 0);
}

test "should correctly resolve IndirectY address" {
    var cpu = Cpu.init();
    var address: u16 = undefined;

    cpu.program_counter = 0xC000;
    cpu.cycles = 0;
    cpu.ram.write(cpu.program_counter, 0x42);
    cpu.reg_y = 0x01;
    cpu.ram.write(0x0042, 0x78);
    cpu.ram.write(0x0043, 0x56);
    address = cpu.resolve_address(AddressingModeEnum.IndirectY);
    expect(address == 0x5679);
    expect(cpu.cycles == 0);

    cpu.program_counter = 0xC000;
    cpu.cycles = 0;
    cpu.ram.write(cpu.program_counter, 0xFF);
    cpu.reg_y = 0x00;
    cpu.ram.write(0x00FF, 0x34);
    cpu.ram.write(0x0000, 0x12);
    address = cpu.resolve_address(AddressingModeEnum.IndirectY);
    expect(address == 0x1234);
    expect(cpu.cycles == 0);

    cpu.program_counter = 0xC000;
    cpu.cycles = 0;
    cpu.ram.write(cpu.program_counter, 0xFF);
    cpu.reg_y = 0x01;
    cpu.ram.write(0x00FF, 0xFF);
    cpu.ram.write(0x0000, 0x12);
    address = cpu.resolve_address(AddressingModeEnum.IndirectY);
    expect(address == 0x1300);
    expect(cpu.cycles == 1);
}

test "should correctly resolve Relative address" {
    var cpu = Cpu.init();
    var address: u16 = undefined;

    cpu.program_counter = 0xC000;
    cpu.ram.write(cpu.program_counter, 0x01);
    address = cpu.resolve_address(AddressingModeEnum.Relative);
    expect(address == 0xC001);
    expect(cpu.cycles == 0);

    cpu.program_counter = 0xC000;
    cpu.ram.write(cpu.program_counter, 0x88);
    address = cpu.resolve_address(AddressingModeEnum.Relative);
    expect(address == 0xBF88);
    expect(cpu.cycles == 0);
}

test "should correctly resolve ZeroPage address" {
    var cpu = Cpu.init();
    var address: u16 = undefined;

    cpu.ram.write(cpu.program_counter, 0x42);
    address = cpu.resolve_address(AddressingModeEnum.ZeroPage);
    expect(address == 0x42);
    expect(cpu.cycles == 0);
}

test "should correctly resolve ZeroPageX address" {
    var cpu = Cpu.init();
    var address: u16 = undefined;

    cpu.program_counter = 0xC000;
    cpu.ram.write(cpu.program_counter, 0x42);
    cpu.reg_x = 0x01;
    address = cpu.resolve_address(AddressingModeEnum.ZeroPageX);
    expect(address == 0x43);
    expect(cpu.cycles == 0);

    cpu.program_counter = 0xC000;
    cpu.ram.write(cpu.program_counter, 0xFF);
    cpu.reg_x = 0x01;
    address = cpu.resolve_address(AddressingModeEnum.ZeroPageX);
    expect(address == 0x00);
    expect(cpu.cycles == 0);
}

test "should correctly resolve ZeroPageY address" {
    var cpu = Cpu.init();
    var address: u16 = undefined;

    cpu.program_counter = 0xC000;
    cpu.ram.write(cpu.program_counter, 0x42);
    cpu.reg_y = 0x01;
    address = cpu.resolve_address(AddressingModeEnum.ZeroPageY);
    expect(address == 0x43);
    expect(cpu.cycles == 0);

    cpu.program_counter = 0xC000;
    cpu.ram.write(cpu.program_counter, 0xFF);
    cpu.reg_y = 0x01;
    address = cpu.resolve_address(AddressingModeEnum.ZeroPageY);
    expect(address == 0x00);
    expect(cpu.cycles == 0);
}

test "should correctly execute AAC opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.AAC, 0x0B, AddressingModeEnum.Immediate, 2, 2);

    cpu.ram.write(0x0000, 0x88);
    cpu.reg_a = 0xFF;

    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_negative == 0x01);
    expect(cpu.f_zero == 0x00);
    expect(cpu.f_carry == 0x01);
}

test "should correctly execute AAX opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.AAX, 0x83, AddressingModeEnum.IndirectX, 2, 6);

    cpu.ram.write(0x0000, 0x00);
    cpu.reg_a = 0x44;
    cpu.reg_x = 0xFF;

    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.ram.read_8(0x0000) == 0x44);
}

test "should correctly execute ADC opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.ADC, 0x69, AddressingModeEnum.Immediate, 2, 2);

    cpu.ram.write(0x0000, 0x00);
    cpu.reg_a = 0xFF;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0xFF);
    expect(cpu.f_negative == 0x01);
    expect(cpu.f_zero == 0x00);
    expect(cpu.f_carry == 0x00);

    cpu.ram.write(0x0000, 0x01);
    cpu.reg_a = 0xFF;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0x00);
    expect(cpu.f_negative == 0x00);
    expect(cpu.f_zero == 0x01);
    expect(cpu.f_carry == 0x01);

    cpu.ram.write(0x0000, 0x00);
    cpu.reg_a = 0x42;
    cpu.f_carry = 0x01;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0x43);
    expect(cpu.f_negative == 0x00);
    expect(cpu.f_zero == 0x00);
    expect(cpu.f_carry == 0x00);

    cpu.ram.write(0x0000, 0x00);
    cpu.reg_a = 0xFF;
    cpu.f_carry = 0x01;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0x00);
    expect(cpu.f_negative == 0x00);
    expect(cpu.f_zero == 0x01);
    expect(cpu.f_carry == 0x01);
}

test "should correctly execute AND opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.AND, 0x29, AddressingModeEnum.Immediate, 2, 2);

    cpu.ram.write(0x0000, 0xFF);
    cpu.reg_a = 0x44;

    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0x44);
    expect(cpu.f_negative == 0x00);
    expect(cpu.f_zero == 0x00);
    expect(cpu.f_carry == 0x00);
}

test "should correctly execute ASL opcode" {
    var cpu = Cpu.init();

    var opcode = Opcode.init(OpcodeEnum.ASL, 0x06, AddressingModeEnum.ZeroPage, 2, 5);
    cpu.ram.write(0x0000, 0x42);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.ram.read_8(0x0000) == 0x84);
    expect(cpu.f_negative == 0x01);
    expect(cpu.f_zero == 0x00);
    expect(cpu.f_carry == 0x00);

    cpu.ram.write(0x0000, 0xFF);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.ram.read_8(0x0000) == 0xFE);
    expect(cpu.f_negative == 0x01);
    expect(cpu.f_zero == 0x00);
    expect(cpu.f_carry == 0x01);

    opcode = Opcode.init(OpcodeEnum.ASL, 0x06, AddressingModeEnum.Accumulator, 2, 5);
    cpu.reg_a = 0x42;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0x84);
    expect(cpu.f_negative == 0x01);
    expect(cpu.f_zero == 0x00);
    expect(cpu.f_carry == 0x00);
}

test "should correctly execute ATX opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.ATX, 0xAB, AddressingModeEnum.Immediate, 2, 2);

    cpu.ram.write(0x0000, 0x42);
    cpu.reg_a = 0xDD;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0x42);
    expect(cpu.reg_x == 0x42);
    expect(cpu.f_zero == 0x00);
    expect(cpu.f_negative == 0x00);
}

test "should correctly execute BCC opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.BCC, 0x90, AddressingModeEnum.Relative, 2, 2);

    cpu.program_counter = 0xFFFF;
    cpu.f_carry = 0x00;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.program_counter == 0x0000);

    cpu.program_counter = 0xFFFF;
    cpu.f_carry = 0x01;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.program_counter == 0x0001);
}

test "should correctly execute BCS opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.BCS, 0xB0, AddressingModeEnum.Relative, 2, 2);

    cpu.program_counter = 0xFFFF;
    cpu.f_carry = 0x00;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.program_counter == 0x0001);

    cpu.program_counter = 0xFFFF;
    cpu.f_carry = 0x01;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.program_counter == 0x0000);
}

test "should correctly execute BEQ opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.BEQ, 0xF0, AddressingModeEnum.Relative, 2, 2);

    cpu.program_counter = 0xFFFF;
    cpu.f_zero = 0x00;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.program_counter == 0x0001);

    cpu.program_counter = 0xFFFF;
    cpu.f_zero = 0x01;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.program_counter == 0x0000);
}

test "should correctly execute BIT opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.BIT, 0x2C, AddressingModeEnum.Absolute, 3, 4);

    cpu.ram.write(0x0000, 0x42);
    cpu.reg_a = 0x42;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_zero == 0x00);
    expect(cpu.f_overflow == 0x01);
    expect(cpu.f_negative == 0x00);
}

test "should correctly execute BMI opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.BMI, 0x30, AddressingModeEnum.Relative, 2, 2);

    cpu.program_counter = 0xFFFF;
    cpu.f_negative = 0x00;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.program_counter == 0x0001);

    cpu.program_counter = 0xFFFF;
    cpu.f_negative = 0x01;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.program_counter == 0x0000);
}

test "should correctly execute BNE opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.BNE, 0xD0, AddressingModeEnum.Relative, 2, 2);

    cpu.program_counter = 0xFFFF;
    cpu.f_zero = 0x00;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.program_counter == 0x0000);

    cpu.program_counter = 0xFFFF;
    cpu.f_zero = 0x01;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.program_counter == 0x0001);
}

test "should correctly execute BPL opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.BPL, 0x10, AddressingModeEnum.Relative, 2, 2);

    cpu.program_counter = 0xFFFF;
    cpu.f_negative = 0x00;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.program_counter == 0x0000);

    cpu.program_counter = 0xFFFF;
    cpu.f_negative = 0x01;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.program_counter == 0x0001);
}

test "should correctly execute BVC opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.BVC, 0x50, AddressingModeEnum.Relative, 2, 2);

    cpu.program_counter = 0xFFFF;
    cpu.f_overflow = 0x00;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.program_counter == 0x0000);

    cpu.program_counter = 0xFFFF;
    cpu.f_overflow = 0x01;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.program_counter == 0x0001);
}

test "should correctly execute BVS opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.BVS, 0x70, AddressingModeEnum.Relative, 2, 2);

    cpu.program_counter = 0xFFFF;
    cpu.f_overflow = 0x00;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.program_counter == 0x0001);

    cpu.program_counter = 0xFFFF;
    cpu.f_overflow = 0x01;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.program_counter == 0x0000);
}

test "should correctly execute CLC opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.CLC, 0x18, AddressingModeEnum.Implicit, 1, 2);

    cpu.f_carry = 0x01;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_carry == 0x00);
}

test "should correctly execute CLD opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.CLD, 0xD8, AddressingModeEnum.Implicit, 1, 2);

    cpu.f_decimal = 0x01;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_decimal == 0x00);
}

test "should correctly execute CLI opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.CLI, 0x58, AddressingModeEnum.Implicit, 1, 2);

    cpu.f_interrupt_disable = 0x01;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_interrupt_disable == 0x00);
}

test "should correctly execute CLV opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.CLV, 0xB8, AddressingModeEnum.Implicit, 1, 2);

    cpu.f_overflow = 0x01;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_overflow == 0x00);
}

test "should correctly execute CMP opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.CMP, 0xC5, AddressingModeEnum.ZeroPage, 2, 3);

    cpu.reg_a = 0x42;
    cpu.ram.write(0x0000, 0x42);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_carry == 0x00);

    cpu.reg_a = 0xFF;
    cpu.ram.write(0x0000, 0x0F);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_carry == 0x01);
}

test "should correctly execute CPX opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.CPX, 0xE0, AddressingModeEnum.Immediate, 2, 2);

    cpu.reg_x = 0x42;
    cpu.ram.write(0x0000, 0x42);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_carry == 0x00);

    cpu.reg_x = 0xFF;
    cpu.ram.write(0x0000, 0x0F);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_carry == 0x01);
}

test "should correctly execute CPY opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.CPY, 0xC0, AddressingModeEnum.Immediate, 2, 2);

    cpu.reg_y = 0x42;
    cpu.ram.write(0x0000, 0x42);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_carry == 0x00);

    cpu.reg_y = 0xFF;
    cpu.ram.write(0x0000, 0x0F);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_carry == 0x01);
}

test "should correctly execute DCP opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.DCP, 0xC3, AddressingModeEnum.IndirectX, 2, 8);

    cpu.reg_a = 0x42;
    cpu.ram.write(0x0000, 0x42);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_carry == 0x00);

    cpu.reg_a = 0xFF;
    cpu.ram.write(0x0000, 0x0F);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_carry == 0x01);
}

test "should correctly execute DEC opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.DEC, 0xC6, AddressingModeEnum.ZeroPage, 2, 5);

    cpu.ram.write(0x0000, 0x42);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.ram.read_8(0x0000) == 0x41);
}

test "should correctly execute DEX opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.DEX, 0xCA, AddressingModeEnum.Implicit, 1, 2);

    cpu.reg_x = 0x42;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_x == 0x41);
}

test "should correctly execute DEY opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.DEY, 0x88, AddressingModeEnum.Implicit, 1, 2);

    cpu.reg_y = 0x42;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_y == 0x41);
}

test "should correctly execute EOR opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.EOR, 0x41, AddressingModeEnum.IndirectX, 2, 6);

    cpu.reg_a = 0x42;
    cpu.ram.write(0x0000, 0x24);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0x66);
}

test "should correctly execute INC opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.INC, 0xE6, AddressingModeEnum.ZeroPage, 2, 5);

    cpu.ram.write(0x0000, 0x42);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.ram.read_8(0x0000) == 0x43);
}

test "should correctly execute INX opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.INX, 0xE8, AddressingModeEnum.Implicit, 1, 2);

    cpu.reg_x = 0x42;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_x == 0x43);
}

test "should correctly execute INY opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.INY, 0xC8, AddressingModeEnum.Implicit, 1, 2);

    cpu.reg_y = 0x42;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_y == 0x43);
}

test "should correctly execute JMP opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.JMP, 0x4C, AddressingModeEnum.Absolute, 3, 3);

    cpu.ram.write(0x0000, 0x42);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.program_counter == 0x0000);
}

test "should correctly execute JSR opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.JSR, 0x20, AddressingModeEnum.Absolute, 3, 6);

    cpu.program_counter = 0x1234;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.ram.pop_from_stack() == 0x37);
    expect(cpu.ram.pop_from_stack() == 0x12);
    expect(cpu.program_counter == 0x0000);
}

test "should correctly execute LAX opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.LAX, 0xA3, AddressingModeEnum.IndirectX, 2, 6);

    cpu.ram.write(0x0000, 0x42);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0x42);
    expect(cpu.reg_x == 0x42);
}

test "should correctly execute LDA opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.LDA, 0xA1, AddressingModeEnum.IndirectX, 2, 6);

    cpu.ram.write(0x0000, 0x42);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0x42);
}

test "should correctly execute LDX opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.LDX, 0xA2, AddressingModeEnum.Immediate, 2, 2);

    cpu.ram.write(0x0000, 0x42);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_x == 0x42);
}

test "should correctly execute LDY opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.LDY, 0xA0, AddressingModeEnum.Immediate, 2, 2);

    cpu.ram.write(0x0000, 0x42);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_y == 0x42);
}

test "should correctly execute LSR opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.LSR, 0x46, AddressingModeEnum.ZeroPage, 2, 5);

    cpu.ram.write(0x0000, 0x42);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_carry == 0x00);
    expect(cpu.ram.read_8(0x0000) == 0x21);

    cpu.ram.write(0x0000, 0x21);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_carry == 0x01);
    expect(cpu.ram.read_8(0x0000) == 0x10);
}

test "should correctly execute ORA opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.ORA, 0x01, AddressingModeEnum.IndirectX, 2, 6);

    cpu.ram.write(0x0000, 0xAA);
    cpu.reg_a = 0x55;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_zero == 0x00);

    cpu.ram.write(0x0000, 0x00);
    cpu.reg_a = 0x00;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_zero == 0x01);
}

test "should correctly execute PHA opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.PHA, 0x48, AddressingModeEnum.Implicit, 1, 3);

    cpu.reg_a = 0x42;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.ram.pop_from_stack() == 0x42);
}

test "should correctly execute PHP opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.PHP, 0x08, AddressingModeEnum.Implicit, 1, 3);

    cpu.ram.push_to_stack(0x42);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.ram.pop_from_stack() == 0x52);
}

test "should correctly execute PLA opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.PLA, 0x68, AddressingModeEnum.Implicit, 1, 4);

    cpu.ram.push_to_stack(0x42);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0x42);
}

test "should correctly execute PLP opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.PLP, 0x28, AddressingModeEnum.Implicit, 1, 4);

    cpu.ram.push_to_stack(0xAA);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.get_status_flags() == 0xAA);
}

test "should correctly execute RLA opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.RLA, 0x23, AddressingModeEnum.IndirectX, 2, 8);

    cpu.ram.write(0x0000, 0xFF);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_carry == 0x01);
    expect(cpu.reg_a == 0x00);
}

test "should correctly execute ROL opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.ROL, 0x26, AddressingModeEnum.ZeroPage, 2, 5);

    cpu.ram.write(0x0000, 0xFF);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_carry == 0x01);
    expect(cpu.reg_a == 0x00);
}

test "should correctly execute ROR opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.ROR, 0x66, AddressingModeEnum.ZeroPage, 2, 5);

    cpu.ram.write(0x0000, 0xFF);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_carry == 0x01);
    expect(cpu.reg_a == 0x00);
}

test "should correctly execute RTI opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.RTI, 0x40, AddressingModeEnum.Implicit, 1, 6);

    cpu.ram.push_to_stack(0x12);
    cpu.ram.push_to_stack(0x34);
    cpu.ram.push_to_stack(0xAA);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.get_status_flags() == 0xAA);
    expect(cpu.program_counter == 0x1234);
}

test "should correctly execute RTS opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.RTS, 0x60, AddressingModeEnum.Implicit, 1, 6);

    cpu.ram.push_to_stack(0x12);
    cpu.ram.push_to_stack(0x34);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.program_counter == 0x1234);
}

test "should correctly execute SBC opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.SBC, 0xE1, AddressingModeEnum.IndirectX, 2, 6);

    cpu.ram.write(0x0000, 0x00);
    cpu.reg_a = 0xFF;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0xFF);
    expect(cpu.f_negative == 0x01);
    expect(cpu.f_zero == 0x00);
    expect(cpu.f_carry == 0x00);

    cpu.ram.write(0x0000, 0x01);
    cpu.reg_a = 0xFF;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0xFE);
    expect(cpu.f_negative == 0x01);
    expect(cpu.f_zero == 0x00);
    expect(cpu.f_carry == 0x00);

    cpu.ram.write(0x0000, 0x00);
    cpu.reg_a = 0x42;
    cpu.f_carry = 0x01;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0x41);
    expect(cpu.f_negative == 0x00);
    expect(cpu.f_zero == 0x00);
    expect(cpu.f_carry == 0x00);

    cpu.ram.write(0x0000, 0x00);
    cpu.reg_a = 0x01;
    cpu.f_carry = 0x01;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0x00);
    expect(cpu.f_negative == 0x00);
    expect(cpu.f_zero == 0x01);
    expect(cpu.f_carry == 0x00);

    cpu.ram.write(0x0000, 0x01);
    cpu.reg_a = 0x00;
    cpu.f_carry = 0x00;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0xFF);
    expect(cpu.f_negative == 0x01);
    expect(cpu.f_zero == 0x00);
    expect(cpu.f_carry == 0x01);

    cpu.ram.write(0x0000, 0x01);
    cpu.reg_a = 0x00;
    cpu.f_carry = 0x01;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0xFE);
    expect(cpu.f_negative == 0x01);
    expect(cpu.f_zero == 0x00);
    expect(cpu.f_carry == 0x01);
}

test "should correctly execute SEC opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.SEC, 0x38, AddressingModeEnum.Implicit, 1, 2);

    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_carry == 0x01);
}

test "should correctly execute SED opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.SED, 0xF8, AddressingModeEnum.Implicit, 1, 2);

    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_decimal == 0x01);
}

test "should correctly execute SEI opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.SEI, 0x78, AddressingModeEnum.Implicit, 1, 2);

    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.f_interrupt_disable == 0x01);
}

test "should correctly execute SLO opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.SLO, 0x03, AddressingModeEnum.IndirectX, 2, 8);

    cpu.ram.write(0x0000, 0xAA);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0x54);
}

test "should correctly execute SRE opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.SRE, 0x43, AddressingModeEnum.IndirectX, 2, 8);

    cpu.ram.write(0x0000, 0xAA);
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0x55);
}

test "should correctly execute STA opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.STA, 0x81, AddressingModeEnum.IndirectX, 2, 6);

    cpu.reg_a = 0x42;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.ram.read_8(0x0000) == 0x42);
}

test "should correctly execute STX opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.STX, 0x86, AddressingModeEnum.ZeroPage, 2, 3);

    cpu.reg_x = 0x42;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.ram.read_8(0x0000) == 0x42);
}

test "should correctly execute STY opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.STY, 0x84, AddressingModeEnum.ZeroPage, 2, 3);

    cpu.reg_y = 0x42;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.ram.read_8(0x0000) == 0x42);
}

test "should correctly execute TAX opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.TAX, 0xAA, AddressingModeEnum.Implicit, 1, 2);

    cpu.reg_a = 0x42;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_x == 0x42);
}

test "should correctly execute TSX opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.TSX, 0xBA, AddressingModeEnum.Implicit, 1, 2);

    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_x == 0xFD);
}

test "should correctly execute TXA opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.TXA, 0x8A, AddressingModeEnum.Implicit, 1, 2);

    cpu.reg_x = 0x42;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0x42);
}

test "should correctly execute TXS opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.TXS, 0x9A, AddressingModeEnum.Implicit, 1, 2);

    cpu.reg_x = 0x42;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.ram.stack_pointer == 0x42);
}

test "should correctly execute TYA opcode" {
    var cpu = Cpu.init();
    var opcode = Opcode.init(OpcodeEnum.TYA, 0x98, AddressingModeEnum.Implicit, 1, 2);

    cpu.reg_y = 0x42;
    cpu.execute_instruction(opcode, 0x0000);
    expect(cpu.reg_a == 0x42);
}
