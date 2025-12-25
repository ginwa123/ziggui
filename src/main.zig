const std = @import("std");
const image_viewer_with_gui_toolkit_co = @import("image_viewer_with_gui_toolkit_co");

const Widget = @import("widget.zig").Widget;
const Orientation = @import("widget.zig").Orientation;
const ui = @import("widget.zig");
const debugger = @import("debugger.zig");

const c = @import("c.zig").c;
pub fn randomId(alloc: std.mem.Allocator) ![]u8 {
    var v: u64 = undefined;
    std.crypto.random.bytes(std.mem.asBytes(&v));
    return try std.fmt.allocPrint(alloc, "w-{x}", .{v});
}

pub const ginwaGTK = struct {
    // wayland
    display: ?*c.wl_display = null,
    registry: ?*c.wl_registry = null,
    compositor: ?*c.wl_compositor = null,
    shm: ?*c.wl_shm = null,
    xdg_wm_base: ?*c.xdg_wm_base = null,
    surface: ?*c.wl_surface = null,
    xdg_surface: ?*c.xdg_surface = null,
    xdg_toplevel: ?*c.xdg_toplevel = null,
    running: bool = false,
    wl_pointer: ?*c.wl_pointer = null,
    wl_seat: ?*c.wl_seat = null,

    old_buffer: ?*c.wl_buffer = null,
    current_buffer: ?*c.wl_buffer = null,
    shm_data: [*]u8 = undefined,

    // window properties
    win_title: [*c]const u8,
    win_width: i32 = 800,
    win_height: i32 = 600,

    // memory management
    gpa: std.heap.GeneralPurposeAllocator(.{}) = .{},

    allocatorbtn: std.mem.Allocator = undefined,

    // ui component
    window: Widget = undefined,

    fn xdgSurfaceConfigure(
        data: ?*anyopaque,
        xdg_surface: ?*c.xdg_surface,
        serial: u32,
    ) callconv(.c) void {
        c.xdg_surface_ack_configure(xdg_surface, serial);
        _ = data;
    }

    pub const xdg_surface_listener = c.xdg_surface_listener{
        .configure = xdgSurfaceConfigure,
    };

    fn xdgWmBasePing(
        data: ?*anyopaque,
        xdg_wm_base: ?*c.xdg_wm_base,
        serial: u32,
    ) callconv(.c) void {
        _ = data;
        c.xdg_wm_base_pong(xdg_wm_base, serial);
    }

    pub const xdg_wm_base_listener = c.xdg_wm_base_listener{
        .ping = xdgWmBasePing,
    };

    fn xdgToplevelConfigure(
        data: ?*anyopaque,
        xdg_toplevel: ?*c.xdg_toplevel,
        width: i32,
        height: i32,
        states: ?*c.wl_array,
    ) callconv(.c) void {
        _ = xdg_toplevel;
        _ = states;

        const app: *ginwaGTK = @ptrCast(@alignCast(data));
        redraw(app, width, height);
    }

    fn xdgToplevelClose(
        data: ?*anyopaque,
        xdg_toplevel: ?*c.xdg_toplevel,
    ) callconv(.c) void {
        _ = xdg_toplevel;
        const app: *ginwaGTK = @ptrCast(@alignCast(data));
        app.running = false;
        std.debug.print("Window closed\n", .{});
    }

    pub const xdg_toplevel_listener = c.xdg_toplevel_listener{
        .configure = xdgToplevelConfigure,
        .close = xdgToplevelClose,
    };

    fn registryHandleGlobal(user_data: ?*anyopaque, registry: ?*c.struct_wl_registry, name: u32, interface: [*c]const u8, version: u32) callconv(.c) void {
        const app: *ginwaGTK = @ptrCast(@alignCast(user_data));
        std.debug.print("Found global {} of interface {s} version {}\n", .{ name, interface, version });

        const iface = std.mem.span(interface);
        if (std.mem.eql(u8, iface, "wl_compositor")) {
            app.compositor = @ptrCast(c.wl_registry_bind(
                registry,
                name,
                &c.wl_compositor_interface,
                version,
            ));
            app.surface = c.wl_compositor_create_surface(app.compositor);
        }

        if (std.mem.eql(u8, iface, "xdg_wm_base")) {
            app.xdg_wm_base = @ptrCast(c.wl_registry_bind(
                registry,
                name,
                &c.xdg_wm_base_interface,
                4,
            ));
            app.xdg_surface = c.xdg_wm_base_get_xdg_surface(app.xdg_wm_base, app.surface);
            _ = c.xdg_surface_add_listener(app.xdg_surface, &xdg_surface_listener, app);

            app.xdg_toplevel = c.xdg_surface_get_toplevel(app.xdg_surface);
            _ = c.xdg_toplevel_add_listener(app.xdg_toplevel, &xdg_toplevel_listener, app);
            _ = c.xdg_wm_base_add_listener(app.xdg_wm_base, &xdg_wm_base_listener, app);
        }

        if (std.mem.eql(u8, iface, "wl_shm")) {
            app.shm = @ptrCast(c.wl_registry_bind(registry, name, &c.wl_shm_interface, 1));
        }

        // if (std.mem.eql(u8, iface, "wl_seat")) {
        //     app.wl_seat = @ptrCast(c.wl_registry_bind(registry, name, &c.wl_seat_interface, version));
        //
        //     _ = c.wl_seat_add_listener(app.wl_seat, &wl_seat.seat_listener, app);
        // }
    }

    fn registryHandleGlobalRemove(user_data: ?*anyopaque, registry: ?*c.struct_wl_registry, name: u32) callconv(.c) void {
        _ = user_data;
        _ = registry;
        std.debug.print("Removed global {}\n", .{name});
    }

    pub fn init(self: *ginwaGTK) ginwaGTK {
        self.display = c.wl_display_connect(null);

        const registry = c.wl_display_get_registry(self.display);

        const registry_listener = c.wl_registry_listener{
            .global = registryHandleGlobal,
            .global_remove = registryHandleGlobalRemove,
        };
        _ = c.wl_registry_add_listener(registry, &registry_listener, self);
        _ = c.wl_display_roundtrip(self.display);

        c.xdg_toplevel_set_title(self.xdg_toplevel, self.win_title);

        return self.*;
    }

    pub fn event_loop(self: *ginwaGTK) !void {
        c.wl_surface_commit(self.surface);

        self.running = true;
        // Event loop
        while (self.running) {
            _ = c.wl_display_dispatch(self.display);
        }
    }

    fn create_shm_buffer(self: *ginwaGTK) ?*c.wl_buffer {
        // self.old_buffer = self.current_buffer;
        std.debug.print("create_shm_buffer\n", .{});
        const win_width: usize = @intCast(self.win_width);
        const win_height: usize = @intCast(self.win_height);

        std.debug.print("win_width: {d}, win_height: {d}\n", .{ win_width, win_height });

        const stride: usize = win_width * 4;
        const size: usize = stride * win_height;
        const buf_w: usize = win_width;
        const buf_h: usize = win_height;
        const stride_u32: usize = @intCast(win_width);

        // Buat shared memory file

        const fd = c.memfd_create("wl-buffer", 0);
        _ = c.ftruncate(fd, @intCast(size));

        const shm_data_void = c.mmap(null, size, c.PROT_READ | c.PROT_WRITE, c.MAP_SHARED, fd, 0);

        self.shm_data = @ptrCast(shm_data_void);

        // pending_shm_data = shm_data;
        // pending_shm_size = @intCast(size);
        // pending_fd = fd;
        //
        if (self.shm == null) {
            std.log.err("No shm", .{});
        }

        if (fd < 0) {
            std.log.err("Failed to create shm", .{});
        }

        std.debug.print("shm_data: {any}\n", .{self.shm});
        std.debug.print("fd: {d}\n", .{fd});

        std.debug.print("stride: {d}, size: {d}\n", .{ stride, size });
        const pool = c.wl_shm_create_pool(self.shm, fd, @intCast(size));
        std.debug.print("after create pool: \n", .{});
        const buffer = c.wl_shm_pool_create_buffer(
            pool,
            0,
            @intCast(self.win_width),
            @intCast(self.win_height),
            @intCast(stride),
            c.WL_SHM_FORMAT_XRGB8888,
        );

        // // Isi dengan warna hitam (ARGB8888: 0xFF000000 = opaque black)
        const pixels: [*]u32 = @ptrCast(@alignCast(self.shm_data));
        for (0..@intCast(self.win_width * self.win_height)) |i| {
            pixels[i] = 0xFF000000; // Alpha=255, R=0, G=0, B=0 → hitam pekat
        }
        std.debug.print("before layouting self.window: {s}\n", .{""});
        debugger.printWidget(&self.window);

        ui.layoutWidget(&self.window, self.win_width, self.win_height);

        std.debug.print("after layouting self.window: {s}\n", .{""});
        debugger.printWidget(&self.window);

        ui.renderWidget(&self.window, pixels, stride_u32, buf_w, buf_h);

        defer _ = c.wl_shm_pool_destroy(pool); // dijalankan terakhir
        defer _ = c.close(fd); // dijalankan kedua
        defer _ = c.munmap(shm_data_void, size); // dijalankan pertama → benar!
        //
        return buffer;
    }

    pub fn redraw(self: *ginwaGTK, window_width: i32, window_height: i32) void {
        // _ = self;
        //
        if (self.running == false) {
            return;
        }
        if (window_width == 0 or window_height == 0) {
            return;
        }
        std.debug.print("width: {d}, height: {d}\n", .{ window_width, window_height });
        // self.win_width = 1024;
        // self.win_height = 1024;

    }

    pub fn free(self: *ginwaGTK) void {
        _ = c.wl_display_disconnect(self.display);

        _ = self.gpa.deinit();

        // self.buttons.deinit()// todo relase butionn
    }

    pub fn allocator(self: *ginwaGTK) std.mem.Allocator {
        return self.gpa.allocator();
    }
};

pub const windo = struct { title: [*c]const u8 = undefined, width: i32 = undefined, height: i32 = undefined, layout: Widget = undefined };

pub fn main() !void {
    var uiToolkit: ginwaGTK = .{
        .win_title = "ginwaGTK",
    };
    defer uiToolkit.free();

    std.debug.print("Init!\n", .{});
    var tk = uiToolkit.init();

    tk.window.guid = "root";
    tk.window.allocator = tk.allocator();
    tk.window.name = "parent_widget";
    tk.window.orientation = .Column;
    tk.window.widget_type = .Layout;
    tk.window.padding = 8;
    tk.window.gap = 8;

    const btn1 = try ui.c_btn(
        uiToolkit.allocator(),
        .{ .name = "button1", .width = 100, .height = 100, .background_color = 0xFF1A1A1A, .label = "label1" },
    );

    _ = try tk.window.add_children(tk.window.allocator, btn1);
    //
    const btn2 = try ui.c_btn(
        uiToolkit.allocator(),
        .{ .name = "button1", .width = 500, .height = 100, .background_color = 0xFF3488FF, .label = "Gambar" },
    );

    _ = try tk.window.add_children(tk.window.allocator, btn2);

    const btn3 = try ui.c_btn(
        uiToolkit.allocator(),
        .{
            .name = "button1",
            .width = 100,
            .height = 50,
            // green
            .background_color = 0xFF00FF00,
            .label = "label3",
        },
    );

    _ = try tk.window.add_children(tk.window.allocator, btn3);

    const rowwww = try ui.c_collumn(uiToolkit.allocator(), .{
        .name = "column1",
        .padding = 8,
        .background_color = 0xFF1A1A1A,
        .gap = 8,
        .height = 500,
    });

    const btnColumn11 = try ui.c_btn(
        uiToolkit.allocator(),
        .{
            .name = "button1",
            .width = 400,
            .height = 100,
            .background_color = 0xFFFF7F00,
        },
    );
    _ = try rowwww.add_children(uiToolkit.allocator(), btnColumn11);
    //
    const btnColumn12 = try ui.c_btn(
        uiToolkit.allocator(),
        .{
            .name = "button1",
            .width = 100,
            .height = 100,
            .background_color = 0xFFFFFF2D,
        },
    );
    _ = try rowwww.add_children(uiToolkit.allocator(), btnColumn12);

    _ = try tk.window.add_children(tk.window.allocator, rowwww);
    const new_buffer = tk.create_shm_buffer();
    c.wl_surface_attach(tk.surface, new_buffer, 0, 0);
    c.wl_surface_damage(tk.surface, 0, 0, tk.win_width, tk.win_height);
    c.wl_surface_commit(tk.surface);

    std.debug.print("Event loop!\n", .{});
    try uiToolkit.event_loop();
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
