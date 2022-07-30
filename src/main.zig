const std = @import("std");
const chip8 = @import("chip8.zig");
const Chip8 = chip8.Chip8;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var interpreter = Chip8{ .memory = try allocator.create([4096]u8), .V = try allocator.create([16]u8), .stack = try allocator.create([16]u16), .screen = try allocator.create([chip8.resolution]u8), .keypad = try allocator.create([16]u8) };

    try interpreter.initialize();

    _ = try interpreter.load("programs/test_opcode.ch8");

    std.debug.print("Interpeter Initialized and program loaded! \n{}\nMemory:\n{s}\n", .{ interpreter, interpreter.memory });

    while (true) {
        _ = try interpreter.emulateCycle();
        break;
    }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
