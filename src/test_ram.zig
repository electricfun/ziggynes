const std = @import("std");
const expect = std.testing.expect;
const Ram = @import("ram.zig").Ram;

test "should initialize correct size of memory locations" {
    const ram = Ram.init();
    expect(ram.memory.len == 0xFFFF);
}

test "should initialize memory locations to correct values" {
    const ram = Ram.init();

    expect(ram.memory[0x0000] == 0xFF);
    expect(ram.memory[0x0001] == 0xFF);
    expect(ram.memory[0x0002] == 0xFF);
    expect(ram.memory[0x0003] == 0xFF);
    expect(ram.memory[0x0004] == 0xFF);
    expect(ram.memory[0x0005] == 0xFF);
    expect(ram.memory[0x0006] == 0xFF);
    expect(ram.memory[0x0007] == 0xFF);
    expect(ram.memory[0x0008] == 0xF7);
    expect(ram.memory[0x0009] == 0xEF);
    expect(ram.memory[0x000A] == 0xDF);
    expect(ram.memory[0x000B] == 0xFF);
    expect(ram.memory[0x000C] == 0xFF);
    expect(ram.memory[0x000D] == 0xFF);
    expect(ram.memory[0x000E] == 0xFF);
    expect(ram.memory[0x000F] == 0xBF);

    for (ram.memory[0x0010..0x07FF]) |value| {
        expect(value == 0xFF);
    }

    for (ram.memory[0x0800..0xFFFF]) |value| {
        expect(value == 0x00);
    }
}

test "should initialize stack pointer" {
    const ram = Ram.init();
    expect(ram.stack_pointer == 0xFD);
}

test "should correctly write 8 bit value to memory" {
    var ram = Ram.init();
    ram.write(0x0000, 0x42);
    expect(ram.memory[0x0000] == 0x42);
}

test "should correctly read 8 bit value from memory" {
    var ram = Ram.init();
    ram.write(0x0000, 0x42);
    expect(ram.read_8(0x0000) == 0x42);
}

test "should correctly read 16 bit value from memory" {
    var ram = Ram.init();
    ram.write(0x0000, 0x12);
    ram.write(0x0001, 0x34);
    expect(ram.read_16(0x0000) == 0x3412);
}

test "should correctly read 16 bit value with boundary bug from memory" {
    var ram = Ram.init();
    ram.write(0x00FF, 0x12);
    ram.write(0x0100, 0x34);
    ram.write(0x0000, 0x56);
    expect(ram.read_16_with_bug(0x00FF) == 0x5612);
}

test "should correctly push value to stack" {
    var ram = Ram.init();
    ram.push_to_stack(0x42);
    expect(ram.stack_pointer == 0xFC);
    expect(ram.read_8(0x0100 + @intCast(u16, ram.stack_pointer) + 0x0001) == 0x42);
}

test "should correctly pop value from the stack" {
    var ram = Ram.init();
    ram.push_to_stack(0x42);
    expect(ram.stack_pointer == 0xFC);
    expect(ram.pop_from_stack() == 0x42);
    expect(ram.stack_pointer == 0xFD);
}
