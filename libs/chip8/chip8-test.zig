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
        .screen = try allocator.create([chip8.resolution]u8),
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

    interpreter.screen.* = [_]u8{9} ** chip8.resolution;

    var current_pc: u16 = interpreter.pc;

    interpreter.opcode = 0x00E0;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u16, current_pc + 2), interpreter.pc);
    try std.testing.expectEqualSlices(u8, ([_]u8{0} ** chip8.resolution)[0..], (interpreter.screen.*)[0..]);
}

test "Skip Instruction VX Equal" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.V[0] = 0xAB;

    var current_pc: u16 = interpreter.pc;

    interpreter.opcode = 0x30AB;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u16, current_pc + 4), interpreter.pc);

    current_pc = interpreter.pc;

    interpreter.opcode = 0x30BC;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u16, current_pc + 2), interpreter.pc);
}

test "Skip Instruction VX Not Equal" {
    var test_harness = try initTestHarness();
    defer test_harness.arena.deinit();
    var interpreter = test_harness.interpreter;

    interpreter.V[0] = 0xBC;

    var current_pc: u16 = interpreter.pc;

    interpreter.opcode = 0x40AB;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u16, current_pc + 4), interpreter.pc);

    current_pc = interpreter.pc;

    interpreter.opcode = 0x40BC;
    try interpreter.decode();
    try std.testing.expectEqual(@as(u16, current_pc + 2), interpreter.pc);
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
    try std.testing.expectEqual(@as(u16, current_pc + 4), interpreter.pc);

    current_pc = interpreter.pc;
    interpreter.opcode = 0x9010;

    try interpreter.decode();
    try std.testing.expectEqual(@as(u16, current_pc + 2), interpreter.pc);

    current_pc = interpreter.pc;
    interpreter.V[1] = 0xBC;
    interpreter.opcode = 0x5010;

    try interpreter.decode();
    try std.testing.expectEqual(@as(u16, current_pc + 2), interpreter.pc);

    current_pc = interpreter.pc;
    interpreter.opcode = 0x9010;

    try interpreter.decode();
    try std.testing.expectEqual(@as(u16, current_pc + 4), interpreter.pc);
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
    interpreter.opcode = 0xC000 + @as(u16, nn);
    try interpreter.decode();
    try std.testing.expectEqual(@as(u8, 0), ~nn & interpreter.V[0]);
}