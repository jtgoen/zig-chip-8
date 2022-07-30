const std = @import("std");
const fs = std.fs;
const file = fs.File;
const file_reader = file.Reader;

// Initial position for the program counter for most programs
const pc_init: u16 = 0x200;

// Used for handling edge case of running ETI 660 programs,
//  as they start the program counter at a different memory address
const eti_660_pc_init: u16 = 0x600;

pub const resolution = 64 * 32;

pub const Chip8 = struct {
    // All accessible memory
    memory: *[4096]u8,

    // General purpose registers, labeled V0-VF
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
        clear(u8, self.screen);
        clear(u8, self.keypad);

        self.opcode = 0;

        self.I = 0;

        if (self.is_eti_660) {
            self.pc = eti_660_pc_init;
        } else {
            self.pc = pc_init;
        }

        self.delay_timer = 0;
        self.sound_timer = 0;

        clear(u16, self.stack);
        self.sp = 0;

        clear(u8, self.V);

        clear(u8, self.memory);

        // Load fontset
    }

    pub fn load(self: *Chip8, file_path: []const u8) !usize {
        var open_file = try fs.cwd().openFile(file_path, .{});
        defer open_file.close();

        return try open_file.reader().readAll(self.workspace());
    }

    fn clear(comptime T: type, arrayToClear: []T) void {
        for(arrayToClear) |_, i| {
            arrayToClear[i] = 0;
        }
    }

    // fn interpreterReserve(self: *Chip8) []u8 {
    //     return self.memory[0x000..0x1FF];
    // }

    // fn fontSet(self: *Chip8) []u8 {
    //     return self.memory[0x050..0x0A0];
    // }

    fn workspace(self: *Chip8) []u8 {
        if (self.is_eti_660) {
            return self.memory[eti_660_pc_init..0xFFF];
        } else {
            return self.memory[pc_init..0xFFF];
        }
    }

    pub fn emulateCycle(self: *Chip8) !void {
        var opcode: u16 = @as(u16, self.memory[self.pc]) << 8 | @as(u16, self.memory[self.pc + 1]);
        std.log.info("Pulled Opcode: {x}", .{opcode});
    }
};