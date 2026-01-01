const std = @import("std");

pub const c = @import("c.zig").c;
const wr = @import("widget_render.zig");
const wp = @import("widget_pointer.zig");
const wk = @import("widget_keyboard.zig");

const random = @import("random.zig");
const debugger = @import("debugger.zig");
const utils = @import("utils.zig");

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
    wl_keyboard: ?*c.wl_keyboard = null,

    old_buffer: ?*c.wl_buffer = null,
    current_buffer: ?*c.wl_buffer = null,
    shm_data: [*]u8 = undefined,

    // window properties
    win_title: [*c]const u8,
    win_width: i32 = 800,
    win_height: i32 = 600,
    layout_initialized: bool = false,


    // mouse
    pointer_x: f64 = 0,
    pointer_y: f64 = 0,
    mouse_dragging: bool = false,
    mouse_drag_start_widget: ?*Widget = null,
    mouse_drag_start_x: f64 = 0,
    mouse_drag_start_y: f64 = 0,
    mouse_last_click_time: i64 = 0,
    mouse_click_count: i32 = 0,
    mouse_last_click_widget: ?*Widget = null,
    mouse_quick_clink_interval: i64 = 500_000_000, // 500ms in nanoseconds

    // memory management
    gpa: std.heap.GeneralPurposeAllocator(.{}) = .{},
    memory: ?std.mem.Allocator = null,

    allocatorbtn: std.mem.Allocator = undefined,

    // ui component
    window: Widget = undefined,
    focused_widget: ?*Widget = null,

    // keyboard
    shift_pressed: bool = false,
    ctrl_pressed: bool = false,
    alt_pressed: bool = false,
    pressed_key: ?u32 = null,
    keyboard_rate: i32 = 0.0,
    keyboard_delay: i32 = 0.0,
    next_key_repeat_time: i64 = 0,

    key_repeat_active: bool = false,
    key_repeat_thread: ?std.Thread = null,
    key_repeat_mutex: std.Thread.Mutex = .{},
    // cursor blinking
    cursor_visible: bool = true,
    last_cursor_blink: i64 = 0,
    cursor_blink_interval: i64 = 500_000_000, // 500ms in nanoseconds

    pub const xdg_surface_listener = c.xdg_surface_listener{
        .configure = xdgSurfaceConfigure,
    };

    pub const xdg_wm_base_listener = c.xdg_wm_base_listener{
        .ping = xdgWmBasePing,
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

        if (std.mem.eql(u8, iface, "wl_seat")) {
            app.wl_seat = @ptrCast(c.wl_registry_bind(registry, name, &c.wl_seat_interface, version));

            _ = c.wl_seat_add_listener(app.wl_seat, &seat_listener, app);
        }
    }

    fn registryHandleGlobalRemove(user_data: ?*anyopaque, registry: ?*c.struct_wl_registry, name: u32) callconv(.c) void {
        _ = user_data;
        _ = registry;
        std.debug.print("Removed global {}\n", .{name});
    }

    pub fn init(self: *ginwaGTK) *ginwaGTK {
        self.display = c.wl_display_connect(null);

        const registry = c.wl_display_get_registry(self.display);

        const registry_listener = c.wl_registry_listener{
            .global = registryHandleGlobal,
            .global_remove = registryHandleGlobalRemove,
        };
        _ = c.wl_registry_add_listener(registry, &registry_listener, self);
        _ = c.wl_display_roundtrip(self.display);

        // c.xdg_toplevel_sst_title(self.xdg_toplevel, self.win_title);
        c.xdg_toplevel_set_title(self.xdg_toplevel, self.win_title);

        return self;
    }

    pub fn drawWindow(self: *ginwaGTK, allo: std.mem.Allocator) *Widget {
        var tk = allo.create(Widget) catch unreachable;
        tk.allocator = allo;
        tk.guid = "root";
        tk.children = null;
        tk.name = "parent_widget";
        tk.orientation = .Column;
        tk.widget_type = .Layout;
        tk.padding = 8;
        tk.gap = 8;

        self.window = tk.*;

        return tk;
    }

    pub fn event_loop(app: *ginwaGTK) !void {
        return wr.renderEventLoop(app);
    }

    pub fn redraw(self: *ginwaGTK, window_width: i32, window_height: i32) void {
        self.win_width = window_width;
        self.win_height = window_height;
        if (self.running == false) {
            return;
        }
        if (window_width == 0 or window_height == 0) {
            return;
        }
        std.debug.print("width: {d}, height: {d}\n", .{ window_width, window_height });
    }

    pub fn free(self: *ginwaGTK) void {
        std.debug.print("free\n", .{});

        // Clean up window children first
        if (self.window.children) |*children| {
            for (children.items) |child| {
                child.deinit();
                self.allocator().destroy(child);
            }
            children.deinit(self.allocator());
        }

        _ = c.wl_display_disconnect(self.display);
        _ = self.gpa.deinit();
    }

    pub fn allocator(self: *ginwaGTK) std.mem.Allocator {
        return self.memory orelse self.gpa.allocator();
    }
};

// Tambahkan fungsi ini di widget.zig
pub fn findWidgetAt(widget: *Widget, x: f64, y: f64) ?*Widget {
    const fx = @as(f64, @floatFromInt(widget.x));
    const fy = @as(f64, @floatFromInt(widget.y));
    const fw = @as(f64, @floatFromInt(widget.width));
    const fh = @as(f64, @floatFromInt(widget.height));

    // Cek apakah point berada di dalam widget ini
    const is_inside = x >= fx and x < fx + fw and y >= fy and y < fy + fh;

    if (!is_inside) return null;

    // Cek children dulu (dari depan ke belakang, karena yang di depan menutupi yang di belakang)
    if (widget.children) |children| {
        var i = children.items.len;
        while (i > 0) {
            i -= 1;
            if (findWidgetAt(children.items[i], x, y)) |found| {
                return found;
            }
        }
    }

    // Jika tidak ada children yang match, return widget ini
    return widget;
}
fn xdgSurfaceConfigure(
    data: ?*anyopaque,
    xdg_surface: ?*c.xdg_surface,
    serial: u32,
) callconv(.c) void {
    c.xdg_surface_ack_configure(xdg_surface, serial);
    _ = data;
}

fn xdgWmBasePing(
    data: ?*anyopaque,
    xdg_wm_base: ?*c.xdg_wm_base,
    serial: u32,
) callconv(.c) void {
    _ = data;
    c.xdg_wm_base_pong(xdg_wm_base, serial);
}

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
    ginwaGTK.redraw(app, width, height);
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

// input system

// ?*anyopaque, ?*struct_wl_seat, u32) callconv(.c) void = @import("std").mem.zeroes(?*const fn (?*anyopaque, ?*struct_wl_seat, u32) callconv(.c) void
fn seat_capabilities(
    data: ?*anyopaque,
    seat: ?*c.struct_wl_seat,
    capabilities: u32,
) callconv(.c) void {
    _ = seat;
    const app: *ginwaGTK = @ptrCast(@alignCast(data.?));

    std.debug.print("window witdh: {}\n", .{app.win_width});

    // Existing pointer code...
    if (capabilities & c.WL_SEAT_CAPABILITY_POINTER != 0) {
        if (app.wl_pointer == null) {
            app.wl_pointer = c.wl_seat_get_pointer(app.wl_seat);
            _ = c.wl_pointer_add_listener(app.wl_pointer, &wp.pointer_listener, app);
            std.debug.print("Mouse/trackpad pointer ready!\n", .{});
        }
    }

    // Add keyboard support
    if (capabilities & c.WL_SEAT_CAPABILITY_KEYBOARD != 0) {
        if (app.wl_keyboard == null) {
            app.wl_keyboard = c.wl_seat_get_keyboard(app.wl_seat);
            _ = c.wl_keyboard_add_listener(app.wl_keyboard, &wk.keyboard_listener, app);
            std.debug.print("Keyboard ready!\n", .{});
        }
    }
}

fn seat_name(data: ?*anyopaque, seat: ?*c.wl_seat, name: [*c]const u8) callconv(.c) void {
    _ = seat;
    _ = data;
    const seat_name_str = std.mem.span(name);
    std.debug.print("Seat name: {s}\n", .{seat_name_str});
}

pub const seat_listener = c.struct_wl_seat_listener{
    .capabilities = seat_capabilities,
    .name = seat_name,
};

/// rendering system
pub const Orientation = enum {
    Row,
    Column,
};

pub const WidgetType = enum { Button, Layout, Input };

pub const FontWeight = enum {
    Normal,
    Bold,
    Light,

    pub fn toPangoWeight(self: FontWeight) c_uint {
        return switch (self) {
            .Light => c.PANGO_WEIGHT_LIGHT,
            .Normal => c.PANGO_WEIGHT_NORMAL,
            .Bold => c.PANGO_WEIGHT_BOLD,
        };
    }
};

pub const FontAlignment = enum {
    Left,
    LeftTop,
    LeftBottom,
    CenterLeft,
    Center,
    CenterRight,
    Right,
    RightTop,
    RightBottom,

    pub fn toPangoAlign(self: FontAlignment) c_uint {
        return switch (self) {
            .Left, .LeftTop, .LeftBottom, .CenterLeft => c.PANGO_ALIGN_LEFT,
            .Center => c.PANGO_ALIGN_CENTER,
            .Right, .RightTop, .RightBottom, .CenterRight => c.PANGO_ALIGN_RIGHT,
        };
    }
};

pub const Widget = struct {
    guid: []const u8 = "",
    parent_guid: []const u8 = "",
    name: []const u8 = "",
    orientation: ?Orientation = null,

    gap: i32 = 0,
    children: ?std.ArrayList(*Widget) = null,

    widget_type: WidgetType = .Layout,

    x: i32 = 0,
    y: i32 = 0,
    width: i32 = 0,
    height: i32 = 0,
    padding: i32 = 0,
    input_text: []const u8 = "",
    text: []const u8 = "",
    font_size: i32 = 11,
    font_type: [*:0]const u8 = "Arial",
    font_alignment: FontAlignment = .CenterLeft,
    font_color: u32 = 0xFFFFFFFF,
    font_weight: FontWeight = .Normal, // Added font weight
    background_color: u32 = 0xFF333333,
    border_radius: i32 = 0,
    border_color: ?u32 = null,
    border_width: ?i32 = 0,

    on_click: ?*const fn (*Widget, ?*anyopaque) void = null,
    click_data: ?*anyopaque = null,

    allocator: std.mem.Allocator,

    cursor_position: usize = 0,
    selection_start: ?usize = null,
    selection_end: ?usize = null,
    selection_anchor: ?usize = null,
    scroll_offset: ?usize = null,
    keyboard_last_state: u32 = 0, // enggak kepake kayaknya
    keyboard_last_time: i64 = 0, // enggak kepake kayakany

    pub fn triggerClick(self: *Widget) void {
        if (self.on_click) |callback| {
            callback(self, self.click_data);
        }
    }

    pub fn add_children(self: *Widget, child: *Widget) !void {
        if (self.children == null) {
            std.debug.print("create children list\n", .{});
            self.children = .empty;
        }

        child.parent_guid = self.guid;
        try self.children.?.append(self.allocator, child);
    }

    pub fn deinit(self: *Widget) void {
        if (self.children) |*list| {
            for (list.items) |child| {
                child.deinit();
                self.allocator.destroy(child);
            }
            list.deinit(self.allocator);
        }
    }
};

// Widget constructors

pub const PropwColumn = struct {
    name: []const u8 = "",
    width: i32 = 0,
    height: i32 = 0,
    label: []const u8 = "",
    font_type: [*:0]const u8 = "",
    font_size: i32 = 16,
    background_color: u32 = 0xFF333333,
    orientation: Orientation = .Column,
    gap: i32 = 0,
    padding: i32 = 0,
    border_color: ?u32 = null,
    border_width: ?i32 = 0,
    border_radius: i32 = 0,
};

pub fn c_column(alloc: std.mem.Allocator, props: PropwColumn) !*Widget {
    const widget = try alloc.create(Widget);
    widget.* = .{
        .guid = try random.randomId(alloc),
        .name = props.name,
        .width = props.width,
        .height = props.height,
        .text = props.label,
        .widget_type = .Layout,
        .allocator = alloc,
        .background_color = props.background_color,
        .orientation = props.orientation,
        .font_size = props.font_size,
        .font_type = props.font_type,
        .border_color = props.border_color,
        .border_width = props.border_width,
        .border_radius = props.border_radius,
    };

    return widget;
}

pub const PropsRow = struct {
    name: []const u8 = "",
    width: i32 = 0,
    height: i32 = 0,
    text: []const u8 = "",
    background_color: u32 = 0xFF333333,
    orientation: Orientation = .Row,
    gap: i32 = 0,
    padding: i32 = 0,
    border_color: ?u32 = null,
    border_width: ?i32 = 0,
    border_radius: i32 = 0,
};

pub fn c_row(alloc: std.mem.Allocator, props: PropsRow) !*Widget {
    const widget = try alloc.create(Widget);
    widget.* = .{
        .guid = try random.randomId(alloc),
        .name = props.name,
        .width = props.width,
        .height = props.height,
        .text = props.text,
        .widget_type = .Layout,
        .allocator = alloc,
        .background_color = props.background_color,
        .orientation = props.orientation,
        .border_color = props.border_color,
        .border_width = props.border_width,
        .border_radius = props.border_radius,
    };

    return widget;
}

pub const PropsButton = struct {
    name: []const u8 = "",
    width: i32 = 120,
    height: i32 = 30,
    label: []const u8 = "",
    background_color: u32 = 0xFF333333,
    border_color: ?u32 = null,
    border_width: ?i32 = 0,
    border_radius: i32 = 0,
    padding: i32 = 8,
};

pub fn c_btn(alloc: std.mem.Allocator, props: PropsButton) !*Widget {
    const widget = try alloc.create(Widget);
    widget.* = .{ .guid = try random.randomId(alloc), .name = props.name, .width = props.width, .height = props.height, .text = props.label, .widget_type = .Button, .allocator = alloc, .background_color = props.background_color, .border_color = props.border_color, .border_width = props.border_width, .border_radius = props.border_radius };

    widget.padding = props.padding;

    return widget;
}

// Input component constructor
pub const PropsInput = struct {
    name: []const u8 = "",
    width: i32 = 200,
    height: i32 = 30,
    placeholder: []const u8 = "",
    background_color: u32 = 0xFF222222,
    border_color: ?u32 = 0xFF555555,
    border_width: ?i32 = 1,
    border_radius: i32 = 4,
    padding: i32 = 8,
    font_size: i32 = 14,
    font_color: u32 = 0xFFFFFFFF,
};

pub fn c_input(alloc: std.mem.Allocator, props: PropsInput) !*Widget {
    const widget = try alloc.create(Widget);

    // Initialize empty input text
    const initial_text = try alloc.alloc(u8, 0);

    widget.* = .{
        .guid = try random.randomId(alloc),
        .name = props.name,
        .width = props.width,
        .height = props.height,
        .input_text = initial_text,
        .text = if (props.placeholder.len > 0) props.placeholder else initial_text,
        .widget_type = .Input,
        .allocator = alloc,
        .background_color = props.background_color,
        .border_color = props.border_color,
        .border_width = props.border_width,
        .border_radius = props.border_radius,
        .padding = props.padding,
        .font_size = props.font_size,
        .font_color = props.font_color,
        .font_alignment = .CenterLeft,
    };

    return widget;
}
