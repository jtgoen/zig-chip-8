const std = @import("std");
const chip8 = @import("chip8.zig");
const Chip8 = chip8.Chip8;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var interpreter = Chip8{
        .memory = try allocator.create([4096]u8),
        .V = try allocator.create([16]u8),
        .stack = try allocator.create([16]u16),
        .screen = try allocator.create([chip8.resolution]u8),
        .keypad = try allocator.create([16]u8)
    };

    try interpreter.initialize();

    _ = try interpreter.load("/home/gogogoen/code/zig/chip-8/programs/hex-to-dec.chip8");

    std.debug.print("Interpeter Initialized! {}. {s}\n", .{interpreter, interpreter.memory});
}