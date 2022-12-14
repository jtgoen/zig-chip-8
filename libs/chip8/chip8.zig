const std = @import("std");
const random = std.crypto.random;
const fs = std.fs;
const file = fs.File;
const file_reader = file.Reader;

// Initial position for the program counter for most programs
pub const pc_init: u16 = 0x200;

// Used for handling edge case of running ETI 660 programs,
//  as they start the program counter at a different memory address
pub const eti_660_pc_init: u16 = 0x600;

pub const fontset = [_]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};

pub const width = 64;
pub const height = 32;

pub const resolution = width * height;

pub const Chip8Error = error{
    SegmentationFault,
    SubroutineStackOverflow,
    SubroutineStackEmpty,
};

pub const Chip8 = struct {
    // All accessible memory
    memory: *[4096]u8,

    // General purpose registers, labeled V0-VF (VF is for the "carry flag")
    V: *[16]u8,

    // Index register, generally used for storing memory addresses,
    //  so only lowest 12 bits are usually used
    I: u16 = 0,

    // Special purpose register for timing delays, decremented at
    // a rate of 60Hz when non-zero
    delay_timer: u8 = 0,
    // Special purpose register for timing how long to play the
    //  Chip-8's buzzer, decremented at a rate of 60Hz when non-zero
    sound_timer: u8 = 0,

    // Program counter. Used to store the currently executing address
    pc: u16 = pc_init,

    // Stores addresses that the interpreter should return to when
    //  finishing subroutines (allows for up to 16 nested subroutines)
    stack: *[16]u16,
    // Stack pointer, points to current position on the stack
    sp: u8 = 0,

    // Current parsed opcode to be decoded and executed by the interpreter
    opcode: u16 = 0,

    // The screen with which to render the state of the program,
    //  representing a screen constrained by the resolution constant
    screen: *[resolution]u8,

    keypad: *[16]u8,

    eti_660_start: u16 = 0x600,
    is_eti_660: bool = false,

    pub fn initialize(self: *Chip8) !void {
        self.screen.* = std.mem.zeroes([resolution]u8);
        self.keypad.* = std.mem.zeroes([16]u8);

        self.opcode = 0;

        self.I = 0;

        if (self.is_eti_660) {
            self.pc = eti_660_pc_init;
        } else {
            self.pc = pc_init;
        }

        self.stack.* = std.mem.zeroes([16]u16);
        self.sp = 0;

        self.V.* = std.mem.zeroes([16]u8);

        self.memory.* = std.mem.zeroes([4096]u8);
        var fontset_slice = self.memory[0x050..0x0A0];
        for (fontset) |font_byte, i| {
            fontset_slice[i] = font_byte;
        }

        self.delay_timer = 0;
        self.sound_timer = 0;
    }

    pub fn load(self: *Chip8, file_path: []const u8) !usize {
        var open_file = try fs.cwd().openFile(file_path, .{});
        defer open_file.close();

        return try open_file.reader().readAll(self.workspace());
    }

    pub fn fontSet(self: *Chip8) []const u8 {
        return self.memory[0x050..0x0A0];
    }

    fn workspace(self: *Chip8) []u8 {
        if (self.is_eti_660) {
            return self.memory[eti_660_pc_init..0xFFF];
        } else {
            return self.memory[pc_init..0xFFF];
        }
    }

    pub fn emulateCycle(self: *Chip8) Chip8Error!void {
        self.opcode = @as(u16, self.memory[self.pc]) << 8 | @as(u16, self.memory[self.pc + 1]);
        std.log.info("Fetched Opcode: {x}", .{self.opcode});

        var result = try self.decode();

        if (@TypeOf(result) == Chip8Error) {
            return result;
        }

        if (self.delay_timer > 0) {
            self.delay_timer -= 1;
            if (self.delay_timer == 0) {
                std.log.info("Delay expired!", .{});
            }
        }
        if (self.sound_timer > 0) {
            std.log.info("BEEP!", .{});
            self.sound_timer -= 1;
        }
    }

    pub fn decode(self: *Chip8) Chip8Error!void {
        var opcode = self.opcode;
        switch (opcode & 0xF000) {
            0x0000 => {
                switch (opcode & 0x0F00) {
                    0x0000 => {
                        switch (opcode & 0x00FF) {
                            0x00E0 => { // 00E0: Clears the screen.
                                std.log.info("Clearing screen", .{});
                                self.screen.* = std.mem.zeroes([resolution]u8);
                                self.pc += 2;
                            },
                            0x00EE => { // 00EE: Returns from a subroutine.
                                if (self.sp == 0) {
                                    return Chip8Error.SubroutineStackEmpty;
                                }

                                self.sp -= 1;

                                std.log.info("Returning from subroutine to address {x}", .{self.stack[self.sp]});

                                if (!self.is_eti_660 and (self.stack[self.sp] < pc_init or self.stack[self.sp] >= 4096)) {
                                    return Chip8Error.SegmentationFault;
                                } else if (self.is_eti_660 and (self.stack[self.sp] < eti_660_pc_init or self.stack[self.sp] >= 4096)) {
                                    return Chip8Error.SegmentationFault;
                                }

                                self.pc = self.stack[self.sp];
                                self.stack[self.sp] = 0;
                            },
                            else => { // 0NNN: Calls machine code routine (RCA 1802 for COSMAC VIP) at address NNN. Not necessary for most ROMs.
                                self.skipMachineCodeInstruction();
                            },
                        }
                    },
                    else => { // 0NNN: Calls machine code routine (RCA 1802 for COSMAC VIP) at address NNN. Not necessary for most ROMs.
                        self.skipMachineCodeInstruction();
                    },
                }
            },
            0x1000 => { // 1NNN: Jumps to address NNN.
                var address = opcode & 0x0FFF;

                if (address < 0 or address >= 4096) {
                    return Chip8Error.SegmentationFault;
                }

                self.pc = address;
            },
            0x2000 => { // 2NNN: Calls subroutine at NNN.
                var sr_addr = opcode & 0x0FFF;
                std.log.info("Calling subroutine at address {x}", .{sr_addr});

                if (!self.is_eti_660 and (sr_addr < pc_init or sr_addr >= 4096)) {
                    return Chip8Error.SegmentationFault;
                } else if (self.is_eti_660 and (sr_addr < eti_660_pc_init or sr_addr >= 4096)) {
                    return Chip8Error.SegmentationFault;
                }

                if (self.sp >= 16) {
                    return Chip8Error.SubroutineStackOverflow;
                }

                self.stack[self.sp] = self.pc;
                self.sp += 1;

                self.pc = sr_addr;
            },
            0x3000 => { // 3XNN: Skips the next instruction if VX equals NN.
                self.skipNextInstrVxNn(true);
            },
            0x4000 => { // 4XNN: Skips the next instruction if VX does not equal NN.
                self.skipNextInstrVxNn(false);
            },
            0x5000 => {
                if (opcode & 0xF00F == 0x5000) { // 5XY0: Skips the next instruction if VX equals VY.
                    self.skipNextInstrVxVy(true);
                } else {
                    self.unknownOpcode();
                }
            },
            0x6000 => { // 6XNN: Sets VX to NN.
                var vx_index: u4 = @truncate(u4, (opcode & 0x0F00) >> 8);
                var nn: u8 = @truncate(u8, opcode & 0x00FF);

                self.V[vx_index] = nn;
            },
            0x7000 => { // 7XNN: Adds NN to VX. (Carry flag is not changed);
                var vx_index: u4 = @truncate(u4, (opcode & 0x0F00) >> 8);
                var nn: u8 = @truncate(u8, opcode & 0x00FF);

                self.V[vx_index] +%= nn;
            },
            0x8000 => {
                var vx_index: u4 = @truncate(u4, (opcode & 0x0F00) >> 8);
                var vy_index: u4 = @truncate(u4, (opcode & 0x00F0) >> 4);
                switch (opcode & 0xF00F) {
                    0x8000 => { // 8XY0: Sets VX to the value of VY.
                        self.V[vx_index] = self.V[vy_index];
                    },
                    0x8001 => { // 8XY1: Sets VX to VX or VY. (Bitwise OR operation);
                        self.V[vx_index] |= self.V[vy_index];
                    },
                    0x8002 => { // 8XY2: Sets VX to VX and VY. (Bitwise AND operation);
                        self.V[vx_index] &= self.V[vy_index];
                    },
                    0x8003 => { // 8XY3: Sets VX to VX xor VY.
                        self.V[vx_index] ^= self.V[vy_index];
                    },
                    0x8004 => { // 8XY4: Adds VY to VX. VF is set to 1 when there's a carry, and to 0 when there is not.
                        if (@addWithOverflow(u8, self.V[vx_index], self.V[vy_index], &self.V[vx_index])) {
                            self.V[0xF] = 1;
                        } else {
                            self.V[0xF] = 0;
                        }
                    },
                    0x8005 => { // 8XY5: VY is subtracted from VX. VF is set to 0 when there's a borrow, and 1 when there is not.
                        if (@subWithOverflow(u8, self.V[vx_index], self.V[vy_index], &self.V[vx_index]) == true) {
                            self.V[0xF] = 0;
                        } else {
                            self.V[0xF] = 1;
                        }
                    },
                    0x8006 => { // 8XY6: Stores the least significant bit of VX in VF and then shifts VX to the right by 1.
                        self.V[0xF] = self.V[vx_index] & 1;
                        self.V[vx_index] >>= 1;
                    },
                    0x8007 => { // 8XY7: Sets VX to VY minus VX. VF is set to 0 when there's a borrow, and 1 when there is not.
                        if (@subWithOverflow(u8, self.V[vy_index], self.V[vx_index], &self.V[vx_index]) == true) {
                            self.V[0xF] = 0;
                        } else {
                            self.V[0xF] = 1;
                        }
                    },
                    0x800E => { // 8XYE: Stores the most significant bit of VX in VF and then shifts VX to the left by 1.
                        self.V[0xF] = (self.V[vx_index] & 0b10000000) >> 7;
                        self.V[vx_index] <<= 1;
                    },
                    else => self.unknownOpcode(),
                }
            },
            0x9000 => {
                if (opcode & 0xF00F == 0x9000) { // 9XY0: Skips the next instruction if VX does not equal VY.
                    self.skipNextInstrVxVy(false);
                } else {
                    self.unknownOpcode();
                }
            },
            0xA000 => { // ANNN: Sets I to the address NNN
                self.I = opcode & 0x0FFF;
            },
            0xB000 => { // BNNN: Jumps to the address NNN plus V0.
                var addr: u12 = @as(u12, @truncate(u12, opcode & 0x0FFF));
                var of = @addWithOverflow(u12, addr, self.V[0], &addr);
                if (of == true) std.log.warn("{x} opcode jump overflowed {x}", .{ opcode, self.V[0] });
                self.pc = @as(u16, addr);
            },
            0xC000 => { // CXNN: Sets VX to the result of a bitwise and operation on a random number (Typically: 0 to 255) and NN.
                self.V[opcode & 0x0F00] = random.int(u8) & @truncate(u8, opcode & 0x00FF);
            },
            0xD000 => { // DXYN: Draws a sprite at coordinate (VX, VY) that has a width of 8 pixels and a height of N pixels. Each row of 8 pixels is read as bit-coded starting from memory location I; I value does not change after the execution of this instruction. As described above, VF is set to 1 if any screen pixels are flipped from set to unset when the sprite is drawn, and to 0 if that does not happen

            },
            0xE000 => {
                switch (opcode & 0xF0FF) {
                    0xE09E => { // EX9E: Skips the next instruction if the key stored in VX is pressed.

                    },
                    0xE0A1 => { // EXA1: Skips the next instruction if the key stored in VX is not pressed.

                    },
                    else => self.unknownOpcode(),
                }
            },
            0xF000 => {
                var vx_val = self.V[opcode & 0x0F00];
                switch (opcode & 0xF0FF) {
                    0xF007 => { // FX07: Sets VX to the value of the delay timer.
                        self.V[opcode & 0x0F00] = self.delay_timer;
                    },
                    0xF00A => { // FX0A: A key press is awaited, and then stored in VX. (Blocking Operation. All instruction halted until next key event);

                    },
                    0xF015 => { // FX15: Sets the delay timer to VX.
                        self.delay_timer = vx_val;
                    },
                    0xF018 => { // FX18: Sets the sound timer to VX.
                        self.sound_timer = vx_val;
                    },
                    0xF01E => { // FX1E: Adds VX to I. VF is not affected.
                        var of = @addWithOverflow(u16, self.I, @as(u16, vx_val), &self.I);
                        if (of == true) std.log.warn("{x} opcode FX1E overflowed I: {x} VX Val: {x}", .{ opcode, self.I, vx_val });
                    },
                    0xF029 => { // FX29: Sets I to the location of the sprite for the character in VX. Characters 0-F (in hexadecimal) are represented by a 4x5 font.

                    },
                    0xF033 => { // FX33: Stores the binary-coded decimal representation of VX, with the most significant of three digits at the address in I, the middle digit at I plus 1, and the least significant digit at I plus 2. (In other words, take the decimal representation of VX, place the hundreds digit in memory at location in I, the tens digit at location I+1, and the ones digit at location I+2.);

                    },
                    0xF055 => { // FX55: Stores from V0 to VX (including VX) in memory, starting at address I. The offset from I is increased by 1 for each value written, but I itself is left unmodified.

                    },
                    0xF065 => { // FX65: Fills from V0 to VX (including VX) with values from memory, starting at address I. The offset from I is increased by 1 for each value read, but I itself is left unmodified.

                    },
                    else => self.unknownOpcode(),
                }
            },
            else => self.unknownOpcode(),
        }
    }

    fn unknownOpcode(self: *Chip8) void {
        std.log.warn("Encountered unknown opcode {x}. Skipping.", .{self.opcode});
        self.pc += 2;
    }

    fn skipMachineCodeInstruction(self: *Chip8) void {
        std.log.warn("Encountered opcode 0{x}, which relies on executing machine-specific code. Ignoring.", .{self.opcode});
        self.pc += 2;
    }

    fn skipNextInstrVxNn(self: *Chip8, if_eq: bool) void {
        var vx_index: u4 = @truncate(u4, (self.opcode & 0x0F00) >> 8);
        var vx_value: u8 = self.V[vx_index];

        var nn: u8 = @truncate(u8, self.opcode & 0x00FF);

        switch (if_eq) {
            true => {
                if (vx_value == nn) {
                    self.pc += 4;
                } else {
                    self.pc += 2;
                }
            },
            false => {
                if (vx_value != nn) {
                    self.pc += 4;
                } else {
                    self.pc += 2;
                }
            },
        }
    }

    fn skipNextInstrVxVy(self: *Chip8, if_eq: bool) void {
        var vx_index: u4 = @truncate(u4, (self.opcode & 0x0F00) >> 8);
        var vx_value: u8 = self.V[vx_index];

        var vy_index: u4 = @truncate(u4, (self.opcode & 0x00F0) >> 4);
        var vy_value: u8 = self.V[vy_index];

        if (if_eq) {
            if (vx_value == vy_value) {
                self.pc += 4;
            } else {
                self.pc += 2;
            }
        } else {
            if (vx_value != vy_value) {
                self.pc += 4;
            } else {
                self.pc += 2;
            }
        }
    }
};
