const std = @import("std");
const warn = std.debug.warn;
const Ram = @import("ram.zig").Ram;
const Opcode = @import("opcode.zig").Opcode;
const OpcodeEnum = @import("enum.zig").OpcodeEnum;
const AddressingModeEnum = @import("enum.zig").AddressingModeEnum;
const IrqTypeEnum = @import("enum.zig").IrqTypeEnum;

pub const Cpu = struct {
    program_counter: u16,

    reg_a: u8,
    reg_x: u8,
    reg_y: u8,

    f_carry: u8,
    f_zero: u8,
    f_interrupt_disable: u8,
    f_interrupt_disable_temp: u8,
    f_decimal: u8,
    f_break: u8,
    f_break_temp: u8,
    f_unused: u8,
    f_overflow: u8,
    f_negative: u8,

    interrupt_requested: bool,
    interrupt_request_type: IrqTypeEnum,

    cycles: u64,

    ram: Ram,

    pub fn init() Cpu {
        var cpu = Cpu{
            .program_counter = 0xC000,
            .cycles = 0,
            .reg_a = 0x00,
            .reg_x = 0x00,
            .reg_y = 0x00,
            .f_carry = (0x24 >> 0) & 1,
            .f_zero = (0x24 >> 1) & 1,
            .f_interrupt_disable = (0x24 >> 2) & 1,
            .f_interrupt_disable_temp = (0x24 >> 2) & 1,
            .f_decimal = (0x24 >> 3) & 1,
            .f_break = (0x24 >> 4) & 1,
            .f_break_temp = (0x24 >> 4) & 1,
            .f_unused = 0x01,
            .f_overflow = (0x24 >> 6) & 1,
            .f_negative = (0x24 >> 7) & 1,
            .ram = Ram.init(),
            .interrupt_requested = false,
            .interrupt_request_type = IrqTypeEnum.IrqNone,
        };

        return cpu;
    }

    pub fn get_next_opcode_index(self: *Cpu) u8 {
        return self.ram.read_8(self.program_counter);
    }

    pub fn request_interrupt(self: *Cpu, interrupt_request_type: IrqTypeEnum) void {
        if (self.interrupt_requested and interrupt_request_type == IrqTypeEnum.IrqNormal) {
            return;
        }

        self.interrupt_requested = true;
        self.interrupt_request_type = interrupt_request_type;
    }

    pub fn set_status_flags(self: *Cpu, value: u8) void {
        self.f_carry = (value >> 0) & 1;
        self.f_zero = (value >> 1) & 1;
        self.f_interrupt_disable = (value >> 2) & 1;
        self.f_decimal = (value >> 3) & 1;
        self.f_break = (value >> 4) & 1;
        self.f_unused = 1;
        self.f_overflow = (value >> 6) & 1;
        self.f_negative = (value >> 7) & 1;
    }

    pub fn get_status_flags(self: *Cpu) u8 {
        return self.f_carry |
            (self.f_zero << 1) |
            (self.f_interrupt_disable << 2) |
            (self.f_decimal << 3) |
            (self.f_break << 4) |
            (1 << 5) |
            (self.f_overflow << 6) |
            (self.f_negative << 7);
    }

    fn update_zero_flag(self: *Cpu, value: u8) void {
        if (value == 0x00) {
            self.f_zero = 0x01;
        } else {
            self.f_zero = 0x00;
        }
    }

    fn update_negative_flag(self: *Cpu, value: u8) void {
        if ((value & 0x80) != 0x00) {
            self.f_negative = 0x01;
        } else {
            self.f_negative = 0x00;
        }
    }

    fn check_for_page_cross(self: *Cpu, address1: u16, address2: u16) bool {
        return ((address1 & 0xFF00) != (address2 & 0xFF00));
    }

    pub fn resolve_address(self: *Cpu, addressing_mode: AddressingModeEnum) u16 {
        var address: u16 = undefined;

        switch (addressing_mode) {
            AddressingModeEnum.Absolute => {
                address = self.ram.read_16(self.program_counter);
            },
            AddressingModeEnum.AbsoluteX => {
                address = self.ram.read_16(self.program_counter);
                if (self.check_for_page_cross(address, address + self.reg_x)) {
                    self.cycles += 1;
                }
                address += self.reg_x;
            },
            AddressingModeEnum.AbsoluteY => {
                address = self.ram.read_16(self.program_counter);
                if (self.check_for_page_cross(address, address + self.reg_y)) {
                    self.cycles += 1;
                }
                address += self.reg_y;
            },
            AddressingModeEnum.Accumulator => {
                address = self.reg_a;
            },
            AddressingModeEnum.Immediate => {
                address = self.program_counter;
            },
            AddressingModeEnum.Implicit => {},
            AddressingModeEnum.Indirect => {
                var highByte: u16 = self.ram.read_8(self.program_counter);
                var lowByte: u16 = self.ram.read_8(self.program_counter + 1);
                address = (lowByte << 8) | highByte;
                if (self.check_for_page_cross(address, address + 1)) {
                    lowByte = ((address << 8) + 1);
                    highByte = address & 0xFF00;
                    address = (lowByte << 8) | highByte;
                } else {
                    address = self.ram.read_16(address);
                }
            },
            AddressingModeEnum.IndirectX => {
                var temp: u8 = self.ram.read_8(self.program_counter) +% self.reg_x;
                address = temp;
                if (self.check_for_page_cross(address, address + 1)) {
                    address = self.ram.read_16_with_bug(address);
                } else {
                    address = self.ram.read_16(address);
                }
            },
            AddressingModeEnum.IndirectY => {
                address = self.ram.read_8(self.program_counter);
                if (self.check_for_page_cross(address, address + 1)) {
                    address = self.ram.read_16_with_bug(address);
                } else {
                    address = self.ram.read_16(address);
                }
                if (self.check_for_page_cross(address, address + self.reg_y)) {
                    self.cycles += 1;
                }
                address += self.reg_y;
            },
            AddressingModeEnum.Relative => {
                var offset: u8 = self.ram.read_8(self.program_counter);
                address = self.program_counter + offset;
                if (offset >= 0x80) {
                    address -= 0x0100;
                }
            },
            AddressingModeEnum.ZeroPage => {
                address = self.ram.read_8(self.program_counter);
            },
            AddressingModeEnum.ZeroPageX => {
                address = self.ram.read_8(self.program_counter) +% self.reg_x;
            },
            AddressingModeEnum.ZeroPageY => {
                address = self.ram.read_8(self.program_counter) +% self.reg_y;
            },
        }

        return address;
    }

    pub fn execute_instruction(self: *Cpu, opcode: Opcode, address: u16) void {  
        self.cycles += opcode.cycles;
        var overflow: bool = @addWithOverflow(u16, self.program_counter, opcode.size, &self.program_counter);

        switch (opcode.name) {
            OpcodeEnum.AAC => _aac(self, address),
            OpcodeEnum.AAX => _aax(self, address),
            OpcodeEnum.ADC => _adc(self, address),
            OpcodeEnum.AND => _and(self, address),
            OpcodeEnum.ARR => _arr(self, address),
            OpcodeEnum.ASL => if (opcode.addressing_mode == AddressingModeEnum.Accumulator) {
                _asl_a(self);
            } else {
                _asl(self, address);
            },
            OpcodeEnum.ASR => _asr(self, address),
            OpcodeEnum.ATX => _atx(self, address),
            OpcodeEnum.AXA => _axa(self, address),
            OpcodeEnum.AXS => _axs(self, address),
            OpcodeEnum.BCC => _bcc(self, address),
            OpcodeEnum.BCS => _bcs(self, address),
            OpcodeEnum.BEQ => _beq(self, address),
            OpcodeEnum.BIT => _bit(self, address),
            OpcodeEnum.BMI => _bmi(self, address),
            OpcodeEnum.BNE => _bne(self, address),
            OpcodeEnum.BPL => _bpl(self, address),
            OpcodeEnum.BRK => _brk(self, address),
            OpcodeEnum.BVC => _bvc(self, address),
            OpcodeEnum.BVS => _bvs(self, address),
            OpcodeEnum.CLC => _clc(self, address),
            OpcodeEnum.CLD => _cld(self, address),
            OpcodeEnum.CLI => _cli(self, address),
            OpcodeEnum.CLV => _clv(self, address),
            OpcodeEnum.CMP => _cmp(self, address),
            OpcodeEnum.CPX => _cpx(self, address),
            OpcodeEnum.CPY => _cpy(self, address),
            OpcodeEnum.DCP => _dcp(self, address),
            OpcodeEnum.DEC => _dec(self, address),
            OpcodeEnum.DEX => _dex(self, address),
            OpcodeEnum.DEY => _dey(self, address),
            OpcodeEnum.DOP => _dop(self, address),
            OpcodeEnum.EOR => _eor(self, address),
            OpcodeEnum.INC => _inc(self, address),
            OpcodeEnum.INX => _inx(self, address),
            OpcodeEnum.INY => _iny(self, address),
            OpcodeEnum.ISC => _isc(self, address),
            OpcodeEnum.JMP => _jmp(self, address),
            OpcodeEnum.JSR => _jsr(self, address),
            OpcodeEnum.KIL => _kil(self, address),
            OpcodeEnum.LAR => _lar(self, address),
            OpcodeEnum.LAX => _lax(self, address),
            OpcodeEnum.LDA => _lda(self, address),
            OpcodeEnum.LDX => _ldx(self, address),
            OpcodeEnum.LDY => _ldy(self, address),
            OpcodeEnum.LSR => if (opcode.addressing_mode == AddressingModeEnum.Accumulator) {
                _lsr_a(self);
            } else {
                _lsr(self, address);
            },
            OpcodeEnum.NOP => _nop(self, address),
            OpcodeEnum.ORA => _ora(self, address),
            OpcodeEnum.PHA => _pha(self, address),
            OpcodeEnum.PHP => _php(self, address),
            OpcodeEnum.PLA => _pla(self, address),
            OpcodeEnum.PLP => _plp(self, address),
            OpcodeEnum.RLA => _rla(self, address),
            OpcodeEnum.ROL => if (opcode.addressing_mode == AddressingModeEnum.Accumulator) {
                _rol_a(self, address);
            } else {
                _rol(self, address);
            },
            OpcodeEnum.ROR => if (opcode.addressing_mode == AddressingModeEnum.Accumulator) {
                _ror_a(self, address);
            } else {
                _ror(self, address);
            },
            OpcodeEnum.RRA => _rra(self, address),
            OpcodeEnum.RTI => _rti(self, address),
            OpcodeEnum.RTS => _rts(self, address),
            OpcodeEnum.SBC => _sbc(self, address),
            OpcodeEnum.SEC => _sec(self, address),
            OpcodeEnum.SED => _sed(self, address),
            OpcodeEnum.SEI => _sei(self, address),
            OpcodeEnum.SLO => _slo(self, address),
            OpcodeEnum.SRE => _sre(self, address),
            OpcodeEnum.STA => _sta(self, address),
            OpcodeEnum.STX => _stx(self, address),
            OpcodeEnum.STY => _sty(self, address),
            OpcodeEnum.SXA => _sxa(self, address),
            OpcodeEnum.SYA => _sya(self, address),
            OpcodeEnum.TAX => _tax(self, address),
            OpcodeEnum.TAY => _tay(self, address),
            OpcodeEnum.TOP => _top(self, address),
            OpcodeEnum.TSX => _tsx(self, address),
            OpcodeEnum.TXA => _txa(self, address),
            OpcodeEnum.TXS => _txs(self, address),
            OpcodeEnum.TYA => _tya(self, address),
            OpcodeEnum.XAA => _xaa(self, address),
            OpcodeEnum.XAS => _xas(self, address),
        }
    }

    fn _aac(self: *Cpu, address: u16) void {
        var value: u8 = undefined;
        value = self.ram.read_8(address) & self.reg_a;
        self.update_negative_flag(value);
        self.update_zero_flag(value);
        if (self.f_negative == 0x01) {
            self.f_carry = 0x01;
        }
    }

    fn _aax(self: *Cpu, address: u16) void {
        var value: u8 = undefined;
        value = self.reg_x & self.reg_a;
        self.ram.write(address, value);
    }

    fn _adc(self: *Cpu, address: u16) void {
        var value: u8 = undefined;
        var overflow: bool = undefined;
        var already_set_overflow: bool = false;

        overflow = @addWithOverflow(u8, self.reg_a, self.f_carry, &self.reg_a);
        if (overflow) {
            self.f_carry = 0x01;
            already_set_overflow = true;
        }

        overflow = @addWithOverflow(u8, self.ram.read_8(address), self.reg_a, &value);
        self.reg_a = value;
        if (!already_set_overflow) {
            if (overflow) {
                self.f_carry = 0x01;
            } else {
                self.f_carry = 0x00;
            }
        }

        self.update_zero_flag(self.reg_a);
        self.update_negative_flag(self.reg_a);
    }

    fn _and(self: *Cpu, address: u16) void {
        self.reg_a = self.reg_a & self.ram.read_8(address);
        self.update_zero_flag(self.reg_a);
        self.update_negative_flag(self.reg_a);
    }

    fn _arr(self: *Cpu, address: u16) void {
        // TODO
    }

    fn _asl(self: *Cpu, address: u16) void {
        var value: u8 = self.ram.read_8(address);
        self.f_carry = (value >> 7) & 1;
        value = value << 1;
        self.update_zero_flag(value);
        self.update_negative_flag(value);
        self.ram.write(address, value);
    }

    fn _asl_a(self: *Cpu) void {
        self.f_carry = (self.reg_a >> 7) & 1;
        self.reg_a = self.reg_a << 1;
        self.update_zero_flag(self.reg_a);
        self.update_negative_flag(self.reg_a);
    }

    fn _asr(self: *Cpu, address: u16) void {
        // TODO
    }

    fn _atx(self: *Cpu, address: u16) void {
        var value: u8 = self.reg_a | 0xEE;
        value &= self.ram.read_8(address);
        self.reg_a = value;
        self.reg_x = value;
        self.update_zero_flag(value);
        self.update_negative_flag(value);
    }

    fn _axa(self: *Cpu, address: u16) void {
        // TODO
    }

    fn _axs(self: *Cpu, address: u16) void {
        // TODO
    }

    fn _bcc(self: *Cpu, address: u16) void {
        if (self.f_carry == 0x00) {
            if (self.check_for_page_cross(address, address + 1)) {
                self.cycles += 2;
            } else {
                self.cycles += 1;
            }
            self.program_counter = address;
        }
    }

    fn _bcs(self: *Cpu, address: u16) void {
        if (self.f_carry == 0x01) {
            if (self.check_for_page_cross(address, address + 1)) {
                self.cycles += 2;
            } else {
                self.cycles += 1;
            }
            self.program_counter = address;
        }
    }

    fn _beq(self: *Cpu, address: u16) void {
        if (self.f_zero == 0x01) {
            if (self.check_for_page_cross(address, address + 1)) {
                self.cycles += 2;
            } else {
                self.cycles += 1;
            }
            self.program_counter = address;
        }
    }

    fn _bit(self: *Cpu, address: u16) void {
        var value: u8 = self.ram.read_8(address);
        self.update_zero_flag(value & self.reg_a);
        self.f_overflow = (value >> 6) & 1;
        self.f_negative = (value >> 7) & 1;
    }

    fn _bmi(self: *Cpu, address: u16) void {
        if (self.f_negative == 0x01) {
            if (self.check_for_page_cross(address, address + 1)) {
                self.cycles += 2;
            } else {
                self.cycles += 1;
            }
            self.program_counter = address;
        }
    }

    fn _bne(self: *Cpu, address: u16) void {
        if (self.f_zero == 0x00) {
            if (self.check_for_page_cross(address, address + 1)) {
                self.cycles += 2;
            } else {
                self.cycles += 1;
            }
            self.program_counter = address;
        }
    }

    fn _bpl(self: *Cpu, address: u16) void {
        if (self.f_negative == 0x00) {
            if (self.check_for_page_cross(address, address + 1)) {
                self.cycles += 2;
            } else {
                self.cycles += 1;
            }
            self.program_counter = address;
        }
    }

    fn _brk(self: *Cpu, address: u16) void {
        // Forced interrupt
    }

    fn _bvc(self: *Cpu, address: u16) void {
        if (self.f_overflow == 0x00) {
            if (self.check_for_page_cross(address, address + 1)) {
                self.cycles += 2;
            } else {
                self.cycles += 1;
            }
            self.program_counter = address;
        }
    }

    fn _bvs(self: *Cpu, address: u16) void {
        if (self.f_overflow == 0x01) {
            if (self.check_for_page_cross(address, address + 1)) {
                self.cycles += 2;
            } else {
                self.cycles += 1;
            }
            self.program_counter = address;
        }
    }

    fn _clc(self: *Cpu, address: u16) void {
        self.f_carry = 0x00;
    }

    fn _cld(self: *Cpu, address: u16) void {
        self.f_decimal = 0x00;
    }

    fn _cli(self: *Cpu, address: u16) void {
        self.f_interrupt_disable = 0x00;
    }

    fn _clv(self: *Cpu, address: u16) void {
        self.f_overflow = 0x00;
    }

    fn _cmp(self: *Cpu, address: u16) void {
        var value: u8 = self.ram.read_8(address);
        value = self.reg_a -% value;
        if (value < 0x80) {
            self.f_carry = 0x00;
        } else {
            self.f_carry = 0x01;
        }
        self.update_zero_flag(value);
        self.update_negative_flag(value);
    }

    fn _cpx(self: *Cpu, address: u16) void {
        var value: u8 = self.ram.read_8(address);
        value = self.reg_x -% value;
        if (value < 0x80) {
            self.f_carry = 0x00;
        } else {
            self.f_carry = 0x01;
        }
        self.update_zero_flag(value);
        self.update_negative_flag(value);
    }

    fn _cpy(self: *Cpu, address: u16) void {
        var value: u8 = self.ram.read_8(address);
        value = self.reg_y -% value;
        if (value < 0x80) {
            self.f_carry = 0x00;
        } else {
            self.f_carry = 0x01;
        }
        self.update_zero_flag(value);
        self.update_negative_flag(value);
    }

    fn _dcp(self: *Cpu, address: u16) void {
        var value: u8 = self.ram.read_8(address);
        value -%= 1;
        self.ram.write(address, value);
        value = self.reg_a - value;
        if (value < 0x80) {
            self.f_carry = 0x00;
        } else {
            self.f_carry = 0x01;
        }
        self.update_zero_flag(value);
        self.update_negative_flag(value);
    }

    fn _dec(self: *Cpu, address: u16) void {
        var value: u8 = self.ram.read_8(address);
        value -%= 1;
        self.ram.write(address, value);
        self.update_zero_flag(value);
        self.update_negative_flag(value);
    }

    fn _dex(self: *Cpu, address: u16) void {
        self.reg_x -%= 1;
        self.update_zero_flag(self.reg_x);
        self.update_negative_flag(self.reg_x);
    }

    fn _dey(self: *Cpu, address: u16) void {
        self.reg_y -%= 1;
        self.update_zero_flag(self.reg_y);
        self.update_negative_flag(self.reg_y);
    }

    fn _dop(self: *Cpu, address: u16) void {
        // TODO
    }

    fn _eor(self: *Cpu, address: u16) void {
        self.reg_a ^= self.ram.read_8(address);
        self.update_zero_flag(self.reg_a);
        self.update_negative_flag(self.reg_a);
    }

    fn _inc(self: *Cpu, address: u16) void {
        var value: u8 = self.ram.read_8(address);
        value +%= 1;
        self.ram.write(address, value);
        self.update_zero_flag(value);
        self.update_negative_flag(value);
    }

    fn _inx(self: *Cpu, address: u16) void {
        self.reg_x +%= 1;
        self.update_zero_flag(self.reg_x);
        self.update_negative_flag(self.reg_x);
    }

    fn _iny(self: *Cpu, address: u16) void {
        self.reg_y +%= 1;
        self.update_zero_flag(self.reg_y);
        self.update_negative_flag(self.reg_y);
    }

    fn _isc(self: *Cpu, address: u16) void {
        // TODO
    }

    fn _jmp(self: *Cpu, address: u16) void {
        self.program_counter = address;
    }

    fn _jsr(self: *Cpu, address: u16) void {
        var value: u16 = self.program_counter;
        var lowByte = @intCast(u8, (value >> 8) & 0xFF);
        var highByte = @intCast(u8, value & 0xFF);
        self.ram.push_to_stack(lowByte);
        self.ram.push_to_stack(highByte);
        self.program_counter = address;
    }

    fn _kil(self: *Cpu, address: u16) void {
        // TODO
    }

    fn _lar(self: *Cpu, address: u16) void {
        // TODO
    }

    fn _lax(self: *Cpu, address: u16) void {
        var value: u8 = self.ram.read_8(address);
        self.reg_a = value;
        self.reg_x = value;
        self.update_zero_flag(value);
        self.update_negative_flag(value);
    }

    fn _lda(self: *Cpu, address: u16) void {
        self.reg_a = self.ram.read_8(address);
        self.update_zero_flag(self.reg_a);
        self.update_negative_flag(self.reg_a);
    }

    fn _ldx(self: *Cpu, address: u16) void {
        self.reg_x = self.ram.read_8(address);
        self.update_zero_flag(self.reg_x);
        self.update_negative_flag(self.reg_x);
    }

    fn _ldy(self: *Cpu, address: u16) void {
        self.reg_y = self.ram.read_8(address);
        self.update_zero_flag(self.reg_y);
        self.update_negative_flag(self.reg_y);
    }

    fn _lsr_a(self: *Cpu) void {
        self.f_carry = self.reg_a & 1;
        self.reg_a = self.reg_a >> 1;
        self.update_zero_flag(self.reg_a);
        self.update_negative_flag(self.reg_a);
    }

    fn _lsr(self: *Cpu, address: u16) void {
        var value: u8 = self.ram.read_8(address);
        self.f_carry = value & 1;
        value = value >> 1;
        self.update_zero_flag(value);
        self.update_negative_flag(value);
        self.ram.write(address, value);
    }

    fn _nop(self: *Cpu, address: u16) void {
        // TODO
    }

    fn _ora(self: *Cpu, address: u16) void {
        self.reg_a |= self.ram.read_8(address);
        self.update_zero_flag(self.reg_a);
        self.update_negative_flag(self.reg_a);
    }

    fn _pha(self: *Cpu, address: u16) void {
        self.ram.push_to_stack(self.reg_a);
    }

    fn _php(self: *Cpu, address: u16) void {
        var value: u8 = self.ram.pop_from_stack() ^ 0x10;
        self.ram.push_to_stack(value);
    }

    fn _pla(self: *Cpu, address: u16) void {
        self.reg_a = self.ram.pop_from_stack();
        self.update_zero_flag(self.reg_a);
        self.update_negative_flag(self.reg_a);
    }

    fn _plp(self: *Cpu, address: u16) void {
        self.set_status_flags(self.ram.pop_from_stack());
    }

    fn _rla(self: *Cpu, address: u16) void {
        var value: u8 = self.ram.read_8(address);
        var old_carry = self.f_carry;
        self.f_carry = ((value >> 7) & 1);
        value = value << 1;
        value |= (old_carry & 1);
        self.update_zero_flag(value);
        self.update_negative_flag(value);
        self.ram.write(address, value);
        self.reg_a &= value;
        self.update_zero_flag(self.reg_a);
        self.update_negative_flag(self.reg_a);
    }

    fn _rol(self: *Cpu, address: u16) void {
        var value: u8 = self.ram.read_8(address);
        var old_carry = self.f_carry;
        self.f_carry = (value >> 7) & 1;
        value = value << 1;
        value |= (old_carry & 1);
        self.ram.write(address, value);
        self.update_zero_flag(value);
        self.update_negative_flag(value);
    }

    fn _rol_a(self: *Cpu, address: u16) void {
        var value: u8 = self.ram.read_8(address);
        var old_carry = self.f_carry;
        self.f_carry = (value >> 7) & 1;
        value = value << 1;
        value |= (old_carry & 1);
        self.reg_a = value;
        self.update_zero_flag(self.reg_a);
        self.update_negative_flag(self.reg_a);
    }

    fn _ror(self: *Cpu, address: u16) void {
        var value: u8 = self.ram.read_8(address);
        var old_carry = self.f_carry;
        self.f_carry = value & 1;
        value = value >> 1;
        value |= ((old_carry & 1) << 7);
        self.ram.write(address, value);
        self.update_zero_flag(value);
        self.update_negative_flag(value);
    }

    fn _ror_a(self: *Cpu, address: u16) void {
        var value: u8 = self.ram.read_8(address);
        var old_carry = self.f_carry;
        self.f_carry = value & 1;
        value = value >> 1;
        value |= ((old_carry & 1) << 7);
        self.reg_a = value;
        self.update_zero_flag(self.reg_a);
        self.update_negative_flag(self.reg_a);
    }

    fn _rra(self: *Cpu, address: u16) void {
        // TODO
    }

    fn _rti(self: *Cpu, address: u16) void {
        self.set_status_flags(self.ram.pop_from_stack());
        self.program_counter = @intCast(u16, self.ram.pop_from_stack()) | (@intCast(u16, self.ram.pop_from_stack()) << 8);
    }

    fn _rts(self: *Cpu, address: u16) void {
        self.program_counter = @intCast(u16, self.ram.pop_from_stack()) | (@intCast(u16, self.ram.pop_from_stack()) << 8);
    }

    fn _sbc(self: *Cpu, address: u16) void {
        var value: u8 = undefined;
        var overflow: bool = undefined;
        var already_set_overflow: bool = false;

        overflow = @subWithOverflow(u8, self.reg_a, self.f_carry, &self.reg_a);
        if (overflow) {
            self.f_carry = 0x01;
            already_set_overflow = true;
        }

        overflow = @subWithOverflow(u8, self.reg_a, self.ram.read_8(address), &value);
        self.reg_a = value;
        if (!already_set_overflow) {
            if (overflow) {
                self.f_carry = 0x01;
            } else {
                self.f_carry = 0x00;
            }
        }

        self.update_zero_flag(self.reg_a);
        self.update_negative_flag(self.reg_a);
    }

    fn _sec(self: *Cpu, address: u16) void {
        self.f_carry = 0x01;
    }

    fn _sed(self: *Cpu, address: u16) void {
        self.f_decimal = 0x01;
    }

    fn _sei(self: *Cpu, address: u16) void {
        self.f_interrupt_disable = 0x01;
    }

    fn _slo(self: *Cpu, address: u16) void {
        var value: u8 = self.ram.read_8(address);
        self.f_carry = (value >> 7) & 1;
        self.update_zero_flag(value);
        self.update_negative_flag(value);
        value = value << 1;
        self.ram.write(address, value);
        self.reg_a |= value;
        self.update_zero_flag(self.reg_a);
        self.update_negative_flag(self.reg_a);
    }

    fn _sre(self: *Cpu, address: u16) void {
        var value: u8 = self.ram.read_8(address);
        self.f_carry = (value >> 0) & 1;
        self.update_zero_flag(value);
        self.update_negative_flag(value);
        value = value >> 1;
        self.ram.write(address, value);
        self.reg_a ^= value;
        self.update_zero_flag(self.reg_a);
        self.update_negative_flag(self.reg_a);
    }

    fn _sta(self: *Cpu, address: u16) void {
        self.ram.write(address, self.reg_a);
    }

    fn _stx(self: *Cpu, address: u16) void {
        self.ram.write(address, self.reg_x);
    }

    fn _sty(self: *Cpu, address: u16) void {
        self.ram.write(address, self.reg_y);
    }

    fn _sxa(self: *Cpu, address: u16) void {
        // TODO
    }

    fn _sya(self: *Cpu, address: u16) void {
        // TODO
    }

    fn _tay(self: *Cpu, address: u16) void {
        // TODO
    }

    fn _tax(self: *Cpu, address: u16) void {
        self.reg_x = self.reg_a;
        self.update_zero_flag(self.reg_x);
        self.update_negative_flag(self.reg_x);
    }

    fn _top(self: *Cpu, address: u16) void {
        // TODO
    }

    fn _tsx(self: *Cpu, address: u16) void {
        self.reg_x = self.ram.stack_pointer;
        self.update_zero_flag(self.reg_x);
        self.update_negative_flag(self.reg_x);
    }

    fn _txa(self: *Cpu, address: u16) void {
        self.reg_a = self.reg_x;
        self.update_zero_flag(self.reg_a);
        self.update_negative_flag(self.reg_a);
    }

    fn _txs(self: *Cpu, address: u16) void {
        self.ram.stack_pointer = self.reg_x;
    }

    fn _tya(self: *Cpu, address: u16) void {
        self.reg_a = self.reg_y;
        self.update_zero_flag(self.reg_a);
        self.update_negative_flag(self.reg_a);
    }

    fn _xaa(self: *Cpu, address: u16) void {
        // TODO
    }

    fn _xas(self: *Cpu, address: u16) void {
        // TODO
    }
};
