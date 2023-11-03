const std = @import("std");
const chip8 = @import("chip8");
const Chip8 = chip8.Chip8;
const sdlDisplay = @import("sdlDisplay");
const SdlDisplay = sdlDisplay.SdlDisplay;

const ch8_ext = ".ch8";

//TODO: Need to better encapsulate this FPS bound inside chip8 or display
const fps: f32 = 60.0;
const fps_interval = 1000.0 / fps;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var screen = try allocator.create([chip8.resolution]u32);

    var interpreter = Chip8{
        .memory = try allocator.create([4096]u8),
        .V = try allocator.create([16]u8),
        .stack = try allocator.create([16]u16),
        .screen = screen,
        .screen_2d = try allocator.create([chip8.height][]u32),
        .keypad = try allocator.create([16]u8),
    };

    try interpreter.initialize();

    var args_iterator = try std.process.argsWithAllocator(allocator);
    defer args_iterator.deinit();

    var program_path: ?([]const u8) = args_iterator.next();
    while (!hasCh8ExtOrNull(program_path)) program_path = args_iterator.next();

    if (program_path) |path| {
        var bytes_read = try interpreter.load(path);
        std.debug.print("Interpeter Initialized and program loaded! {} bytes read.\n", .{bytes_read});

        var display = try SdlDisplay.create("CHIP-8", 800, 600, chip8.width, chip8.height);
        defer display.free();

        var previous_time = std.time.milliTimestamp();
        var current_time = std.time.milliTimestamp();
        while (display.open) {
            display.input();

            current_time = std.time.milliTimestamp();
            if (@as(f32, @floatFromInt(current_time - previous_time)) > fps_interval) {
                try interpreter.emulateCycle();
                display.draw(interpreter.screen);
            }
        }
    } else {
        std.debug.print("Program file path not provided. Program not loaded! Exiting...", .{});
    }
}

/// Checks if the current arg:
/// - Matches the Chip-8 file extension
/// - Is null (we've reached the end)
fn hasCh8ExtOrNull(arg: ?([]const u8)) bool {
    return if (arg) |arg_slice| std.mem.endsWith(u8, arg_slice, ch8_ext) else true;
}

fn printScreen(interpreter: Chip8) void {
    var hBar = [_]u8{'_'} ** (chip8.width + 4);

    std.log.info("{s}", .{hBar});
    for (interpreter.screen_2d) |row| {
        std.log.info("||{b}||", .{row});
    }
    std.log.info("{s}", .{hBar});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
