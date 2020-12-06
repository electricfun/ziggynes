const std = @import("std");

pub const Cartridge = struct {
    header: []u8,
    prg_rom_size: u8,
    prg_rom: []u8,
    chr_rom_size: u8,
    chr_rom: []u8,
    ram_size: u8,
    ram: []u8,
    mirroring: u8,
    battery_sram: u8,
    trainer: u8,
    four_screen_vram: u8,
    mapper_number: u8,
    vs_system: u8,
    tv_system: u8,

    pub fn init() Cartridge {
        const file: [0xFFFF]u8 = []u8{0} ** 0x0000;
        const file_length = file.len;

        var header: [0x10]u8 = []u8;

        var cartridge = Cartridge{};

        return cartridge;
    }
};
