const std = @import("std");
const chip8 = @import("chip8.zig");
const Chip8 = chip8.Chip8;

const TestHarness = struct {
    arena: std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,
    interpreter: Chip8,
};

fn initTestHarness() anyerror!TestHarness {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);

    const allocator = arena.allocator();

    var interpreter = Chip8{
        .memory = try allocator.create([4096]u8),
        .V = try allocator.create([16]u8),
        .stack = try allocator.create([16]u16),
        .screen = try allocator.create([chip8.resolution]u32),
        .screen_2d = try allocator.create([chip8.height][]u32),
        .keypad = try allocator.create([16]u8),
    };

    try interpreter.initialize();

    return TestHarness{
        .arena = arena,
        .allocator = allocator,
        .interpreter = interpreter,
    };
}

test "Clear Screen" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.screen.* = [_]u32{9} ** chip8.resolution;

    interpreter.opcode = 0x00E0;
    try interpreter.decode();
    try std.testing.expectEqualSlices(u32, ([_]u32{0} ** chip8.resolution)[0..], (interpreter.screen.*)[0..]);
}

test "Skip Instruction VX Equal" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.V[0] = 0xAB;

    var current_pc: u16 = interpreter.pc;

    interpreter.opcode = 0x30AB;
    try interpreter.decode();
    try std.testing.expectEqual(current_pc + 2, interpreter.pc);

    current_pc = interpreter.pc;

    interpreter.opcode = 0x30BC;
    try interpreter.decode();
    try std.testing.expectEqual(current_pc, interpreter.pc);
}

test "Skip Instruction VX Not Equal" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.V[0] = 0xBC;

    var current_pc: u16 = interpreter.pc;

    interpreter.opcode = 0x40AB;
    try interpreter.decode();
    try std.testing.expectEqual(current_pc + 2, interpreter.pc);

    current_pc = interpreter.pc;

    interpreter.opcode = 0x40BC;
    try interpreter.decode();
    try std.testing.expectEqual(current_pc, interpreter.pc);
}

test "Skip Instruction VX VY" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.V[0] = 0xAB;
    interpreter.V[1] = 0xAB;

    var current_pc: u16 = interpreter.pc;
    interpreter.opcode = 0x5010;

    try interpreter.decode();
    try std.testing.expectEqual(current_pc + 2, interpreter.pc);

    current_pc = interpreter.pc;
    interpreter.opcode = 0x9010;

    try interpreter.decode();
    try std.testing.expectEqual(current_pc, interpreter.pc);

    current_pc = interpreter.pc;
    interpreter.V[1] = 0xBC;
    interpreter.opcode = 0x5010;

    try interpreter.decode();
    try std.testing.expectEqual(current_pc, interpreter.pc);

    current_pc = interpreter.pc;
    interpreter.opcode = 0x9010;

    try interpreter.decode();
    try std.testing.expectEqual(current_pc + 2, interpreter.pc);
}

test "Call Subroutine and Return" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.opcode = 0x2201;
    try interpreter.decode();

    try std.testing.expectEqual(@as(u8, 1), interpreter.sp);
    try std.testing.expectEqual(@as(u16, 0x200), interpreter.stack[0]);
    try std.testing.expectEqual(@as(u16, 0x201), interpreter.pc);

    interpreter.opcode = 0x00EE;
    try interpreter.decode();

    try std.testing.expectEqual(@as(u8, 0), interpreter.sp);
    try std.testing.expectEqual(@as(u16, 0), interpreter.stack[0]);
    try std.testing.expectEqual(@as(u16, 0x200), interpreter.pc);
}

test "0NNN Skips Machine Code Instruction" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.opcode = 0x0FFF;
    try interpreter.decode();

    try std.testing.expectEqual(chip8.pc_init + 2, interpreter.pc);
}

test "7XNN" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.V[0] = 0x01;

    interpreter.opcode = 0x7001;
    try interpreter.decode();

    try std.testing.expectEqual(@as(u8, 2), interpreter.V[0]);

    interpreter.V[0] = 0xFF;

    interpreter.opcode = 0x7002;
    try interpreter.decode();

    try std.testing.expectEqual(@as(u8, 1), interpreter.V[0]);
    try std.testing.expectEqual(@as(u8, 0), interpreter.V[0xF]);
}

test "Jump NNN" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.opcode = 0x1FF1;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u16, 0xFF1), interpreter.pc);
}

test "8***" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.V[0] = 0b10;
    interpreter.V[1] = 0b01;

    interpreter.opcode = 0x8010;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u8, 0b01), interpreter.V[0]);

    interpreter.V[0] = 0b10;
    interpreter.V[1] = 0b01;

    interpreter.opcode = 0x8011;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u8, 0b11), interpreter.V[0]);

    interpreter.V[0] = 0b101;
    interpreter.V[1] = 0b011;

    interpreter.opcode = 0x8012;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u8, 0b001), interpreter.V[0]);

    interpreter.V[0] = 0b101;
    interpreter.V[1] = 0b011;

    interpreter.opcode = 0x8013;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u8, 0b110), interpreter.V[0]);

    interpreter.V[0] = 0xFE;
    interpreter.V[1] = 0x01;

    interpreter.opcode = 0x8014;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u8, 0xFF), interpreter.V[0]);
    try std.testing.expectEqual(@as(u8, 0), interpreter.V[0xF]);

    try interpreter.initialize();
    interpreter.V[0] = 0xFF;
    interpreter.V[1] = 0x01;

    interpreter.opcode = 0x8014;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u8, 0x00), interpreter.V[0]);
    try std.testing.expectEqual(@as(u8, 1), interpreter.V[0xF]);

    try interpreter.initialize();
    interpreter.V[0] = 0xFF;
    interpreter.V[1] = 0x01;

    interpreter.opcode = 0x8015;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u8, 0xFE), interpreter.V[0]);
    try std.testing.expectEqual(@as(u8, 1), interpreter.V[0xF]);

    try interpreter.initialize();
    interpreter.V[0] = 0x00;
    interpreter.V[1] = 0x01;

    interpreter.opcode = 0x8015;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u8, 0xFF), interpreter.V[0]);
    try std.testing.expectEqual(@as(u8, 0), interpreter.V[0xF]);

    try interpreter.initialize();
    interpreter.V[0] = 0b101;

    interpreter.opcode = 0x8016;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u8, 0b010), interpreter.V[0]);
    try std.testing.expectEqual(@as(u8, 1), interpreter.V[0xF]);

    try interpreter.initialize();
    interpreter.V[0] = 0x01;
    interpreter.V[1] = 0xFF;

    interpreter.opcode = 0x8017;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u8, 0xFE), interpreter.V[0]);
    try std.testing.expectEqual(@as(u8, 1), interpreter.V[0xF]);

    try interpreter.initialize();
    interpreter.V[0] = 0x01;
    interpreter.V[1] = 0x00;

    interpreter.opcode = 0x8017;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u8, 0xFF), interpreter.V[0]);
    try std.testing.expectEqual(@as(u8, 0), interpreter.V[0xF]);

    try interpreter.initialize();
    interpreter.V[0] = 0b10000010;

    interpreter.opcode = 0x801E;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u8, 0b100), interpreter.V[0]);
    try std.testing.expectEqual(@as(u8, 1), interpreter.V[0xF]);
}

test "ANNN" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.opcode = 0xADED;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u16, 0xDED), interpreter.I);
}

test "BNNN" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.V[0] = 0x01;

    interpreter.opcode = 0xBFFE;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u16, 0x0FFF), interpreter.pc);

    try interpreter.initialize();

    interpreter.V[0] = 0x01;

    interpreter.opcode = 0xBFFF;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u16, 0), interpreter.pc);
}

test "CXNN" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    var nn: u8 = 0b10101010;
    interpreter.opcode = 0xC100 + @as(u16, nn);
    try interpreter.decode();
    try std.testing.expectEqual(@as(u8, 0), ~nn & interpreter.V[1]);
}

test "FX07, FX15" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.V[0] = 0xAB;
    interpreter.delay_timer = 0xBC;

    interpreter.opcode = 0xF007;

    try interpreter.decode();
    try std.testing.expectEqual(@as(u8, 0xBC), interpreter.delay_timer);
    try std.testing.expectEqual(interpreter.delay_timer, interpreter.V[0]);

    interpreter.delay_timer = 0xAB;

    interpreter.opcode = 0xF015;

    try interpreter.decode();
    try std.testing.expectEqual(@as(u8, 0xBC), interpreter.V[0]);
    try std.testing.expectEqual(interpreter.V[0], interpreter.delay_timer);
}

test "FX18" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.V[0] = 0xAB;
    interpreter.sound_timer = 0xBC;

    interpreter.opcode = 0xF018;

    try interpreter.decode();
    try std.testing.expectEqual(@as(u8, 0xAB), interpreter.V[0]);
    try std.testing.expectEqual(interpreter.V[0], interpreter.sound_timer);
}

test "FX1E" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.V[0] = 0x01;
    interpreter.I = 0xFE;

    interpreter.opcode = 0xF01E;

    try interpreter.decode();
    try std.testing.expectEqual(@as(u16, 0xFF), interpreter.I);

    interpreter.I = 0xFFFF;

    interpreter.opcode = 0xF01E;

    try interpreter.decode();
    try std.testing.expectEqual(@as(u16, 0x0000), interpreter.I);
}

test "FX33" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.I = 1;
    interpreter.V[2] = 123;

    interpreter.opcode = 0xF233;

    try interpreter.decode();
    try std.testing.expectEqual(@as(u8, 1), interpreter.memory[interpreter.I]);
    try std.testing.expectEqual(@as(u8, 2), interpreter.memory[interpreter.I + 1]);
    try std.testing.expectEqual(@as(u8, 3), interpreter.memory[interpreter.I + 2]);

    interpreter.I = interpreter.memory.len;

    try std.testing.expectError(chip8.Chip8Error.SegmentationFault, interpreter.decode());
}

test "FX55" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.I = interpreter.I + 5;

    var vals = [_]u8{ 1, 2, 3 };
    var v_slice = interpreter.V[0..3];

    for (vals, 0..) |_, i| {
        v_slice[i] = vals[i];
    }

    interpreter.opcode = 0xF255;

    try interpreter.decode();

    var mem_slice = interpreter.memory[interpreter.I .. interpreter.I + 3];
    for (vals, 0..) |val, i| {
        try std.testing.expectEqual(val, mem_slice[i]);
    }
}

test "FX65" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.I = interpreter.I + 5;

    var vals = [_]u8{ 1, 2, 3 };
    var mem_slice = interpreter.memory[interpreter.I .. interpreter.I + 3];

    for (vals, 0..) |val, i| {
        mem_slice[i] = val;
    }

    interpreter.opcode = 0xF265;

    try interpreter.decode();

    var v_slice = interpreter.V[0..3];
    for (vals, 0..) |val, i| {
        try std.testing.expectEqual(val, v_slice[i]);
    }
}

test "FX55/65 SegFault" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.I = interpreter.memory.len - 2;

    interpreter.opcode = 0xF255;
    try std.testing.expectError(chip8.Chip8Error.SegmentationFault, interpreter.decode());

    interpreter.opcode = 0xF265;
    try std.testing.expectError(chip8.Chip8Error.SegmentationFault, interpreter.decode());
}

test "EX9E, EXA1" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.V[1] = 2;
    interpreter.keypad[2] = 1;

    var current_pc = interpreter.pc;
    interpreter.opcode = 0xE19E;
    try interpreter.decode();
    try std.testing.expectEqual(current_pc + 2, interpreter.pc);

    current_pc = interpreter.pc;
    interpreter.opcode = 0xE1A1;
    try interpreter.decode();
    try std.testing.expectEqual(current_pc, interpreter.pc);

    interpreter.keypad[2] = 0;

    current_pc = interpreter.pc;
    interpreter.opcode = 0xE19E;
    try interpreter.decode();
    try std.testing.expectEqual(current_pc, interpreter.pc);

    current_pc = interpreter.pc;
    interpreter.opcode = 0xE1A1;
    try interpreter.decode();
    try std.testing.expectEqual(current_pc + 2, interpreter.pc);
}

test "DXYN draws sprite" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.V[1] = 2;
    interpreter.V[2] = 4;
    interpreter.I = 0x50; // Index of font glyph '0'

    interpreter.opcode = 0xD125;
    try interpreter.decode();

    var x_index = interpreter.V[1];
    var y_index = interpreter.V[2];

    // Check that '0' glyph was drawn to the screen
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 0, 0, 0, 1, 1, 1, 1 }, interpreter.screen_2d[y_index][x_index .. x_index + 8]);
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 0, 0, 0, 1, 0, 0, 1 }, interpreter.screen_2d[y_index + 1][x_index .. x_index + 8]);
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 0, 0, 0, 1, 0, 0, 1 }, interpreter.screen_2d[y_index + 2][x_index .. x_index + 8]);
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 0, 0, 0, 1, 0, 0, 1 }, interpreter.screen_2d[y_index + 3][x_index .. x_index + 8]);
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 0, 0, 0, 1, 1, 1, 1 }, interpreter.screen_2d[y_index + 4][x_index .. x_index + 8]);

    // Confirm that "unset" flag is off
}

test "DXYN draws portion of sprite in screen bounds" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.V[1] = chip8.width - 7;
    interpreter.V[2] = chip8.height - 4;
    interpreter.I = 0x50; // Index of font glyph '0'

    interpreter.opcode = 0xD125;
    try interpreter.decode();

    var x_index = interpreter.V[1];
    var y_index = interpreter.V[2];

    // Check that '0' glyph was drawn to the screen
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 0, 0, 0, 1, 1, 1 }, interpreter.screen_2d[y_index][x_index..chip8.width]);
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 0, 0, 0, 1, 0, 0 }, interpreter.screen_2d[y_index + 1][x_index..chip8.width]);
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 0, 0, 0, 1, 0, 0 }, interpreter.screen_2d[y_index + 2][x_index..chip8.width]);
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 0, 0, 0, 1, 0, 0 }, interpreter.screen_2d[y_index + 3][x_index..chip8.width]);

    // TODO: Confirm that "unset" flag is off
}

test "DXYN does not draw sprite that is outside of screen bounds" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.V[1] = chip8.width + 1;
    interpreter.V[2] = chip8.height + 1;
    interpreter.I = 0x50; // Index of font glyph '0'

    interpreter.opcode = 0xD125;
    try interpreter.decode();

    // TODO: Confirm that "unset" flag is unchanged (or just on? need to think about behavior here)
}

test "DXYN mapping unaddressable sprite data returns error" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.V[1] = 2;
    interpreter.V[2] = 4;
    interpreter.I = chip8.mem_size - 10; // Starting index within addressable memory, but ends outside

    interpreter.opcode = 0xD125;

    try std.testing.expectError(chip8.Chip8Error.SegmentationFault, interpreter.decode());

    // TODO: Confirm that "unset" flag is unchanged
}

test "2D Screen View Updates" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    const pixel_index = 64;
    interpreter.screen[pixel_index] = 999;

    var x: u8 = pixel_index / chip8.width;
    var y: u8 = pixel_index % chip8.width;

    try std.testing.expectEqual(interpreter.screen[pixel_index], interpreter.screen_2d[x][y]);
}
