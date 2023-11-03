const std = @import("std");
const sdl = @import("sdl.zig");

pub const SdlDisplay = struct {
    const Self = @This();

    window: *sdl.SDL_Window,
    renderer: *sdl.SDL_Renderer,
    framebuffer: *sdl.SDL_Texture,
    framebuffer_width: u8,
    framebuffer_height: u8,
    open: bool,

    pub fn create(title: [*]const u8, width: i32, height: i32, framebuffer_width: u8, framebuffer_height: u8) !Self {

        // Initialize SDL2
        if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_AUDIO) != 0) {
            return error.SDLInitializationFailed;
        }

        // Create SDL2 window
        var window = sdl.SDL_CreateWindow(
            title,
            sdl.SDL_WINDOWPOS_UNDEFINED,
            sdl.SDL_WINDOWPOS_UNDEFINED,
            width,
            height,
            sdl.SDL_WINDOW_SHOWN,
        ) orelse {
            sdl.SDL_Quit();
            return error.SDLWindowCreationFailed;
        };

        // Create SDL2 renderer
        var renderer = sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_ACCELERATED) orelse {
            sdl.SDL_DestroyWindow(window);
            sdl.SDL_Quit();
            return error.SDLRendererCreationFailed;
        };

        // Create display framebuffer
        var framebuffer = sdl.SDL_CreateTexture(renderer, sdl.SDL_PIXELFORMAT_RGBA8888, sdl.SDL_TEXTUREACCESS_STREAMING, framebuffer_width, framebuffer_height) orelse {
            sdl.SDL_DestroyRenderer(renderer);
            sdl.SDL_DestroyWindow(window);
            sdl.SDL_Quit();
            return error.SDLTextureNull;
        };

        // Return Self type struct
        return Self{
            .window = window,
            .renderer = renderer,
            .framebuffer = framebuffer,
            .framebuffer_width = framebuffer_width,
            .framebuffer_height = framebuffer_height,
            .open = true,
        };
    }

    pub fn free(self: *Self) void {
        sdl.SDL_DestroyWindow(self.window);
        sdl.SDL_Quit();
    }

    pub fn input(self: *Self) void {
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                sdl.SDL_QUIT => {
                    self.open = false;
                },
                else => {},
            }
        }
    }

    pub fn draw(self: *Self, screen: []const u32) void {
        if (screen.len % self.framebuffer_width != 0) return;
        if (screen.len % self.framebuffer_height != 0) return;

        // You can use whatever colors you want
        const clear_value = sdl.SDL_Color{
            .r = 0,
            .g = 0,
            .b = 0,
            .a = 255,
        };
        const color_value = sdl.SDL_Color{
            .r = 255,
            .g = 255,
            .b = 255,
            .a = 255,
        };

        var pixels: ?*anyopaque = null;
        var pitch: i32 = 0;

        // Lock framebuffer so we can write pixel data to it
        if (sdl.SDL_LockTexture(self.framebuffer, null, &pixels, &pitch) != 0) {
            sdl.SDL_Log("Failed to lock texture: %s\n", sdl.SDL_GetError());
            return;
        }

        // Cast pixels pointer so that we can use offsets
        var upixels: [*]u32 = @ptrCast(@alignCast(pixels.?));

        // Copy pixel loop
        var y: u8 = 0;
        while (y < self.framebuffer_height) : (y += 1) {
            var x: u8 = 0;
            while (x < self.framebuffer_width) : (x += 1) {
                var index: usize = @as(usize, y) * @divExact(@as(usize, @intCast(pitch)), @sizeOf(u32)) + @as(usize, x);
                var pixel: u32 = screen[index];
                var color = if (pixel == 0) clear_value else color_value;

                var r: u32 = @as(u32, color.r) << 24;
                var g: u32 = @as(u32, color.g) << 16;
                var b: u32 = @as(u32, color.b) << 8;
                var a: u32 = @as(u32, color.a) << 0;

                upixels[index] = r | g | b | a;
            }
        }

        _ = sdl.SDL_UnlockTexture(self.framebuffer);

        _ = sdl.SDL_RenderClear(self.renderer);
        _ = sdl.SDL_RenderCopy(self.renderer, self.framebuffer, null, null);
        _ = sdl.SDL_RenderPresent(self.renderer);
    }
};
