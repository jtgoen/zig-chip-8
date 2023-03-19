const std = @import("std");
const chip8 = @import("chip8");
const Chip8 = chip8.Chip8;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

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

    var args_iterator = try std.process.argsWithAllocator(allocator);
    defer args_iterator.deinit();

    var program_path: ?([]const u8) = args_iterator.next();

    if (program_path) |*path| {
        _ = try interpreter.load(path.*);

        std.debug.print("Interpeter Initialized and program loaded! \n{}\nMemory:\n{s}\n", .{ interpreter, interpreter.memory });

        while (true) {
            try interpreter.emulateCycle();
            break;
        }
    } else {
        std.debug.print("Program file path not provided. Program not loaded! Exiting...", .{});
    }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
