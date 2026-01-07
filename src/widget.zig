const std = @import("std");

pub const c = @import("c.zig").c;
const wr = @import("widget_render.zig");
const wp = @import("widget_pointer.zig");
const wk = @import("widget_keyboard.zig");

const random = @import("random.zig");
const debugger = @import("debugger.zig");
const utils = @import("utils.zig");

pub var default_allocator: std.mem.Allocator = undefined;

pub fn init(alloc: std.mem.Allocator, app: *ginwaGTK) !*ginwaGTK {
    default_allocator = alloc;

    app.display = c.wl_display_connect(null);

    const registry = c.wl_display_get_registry(app.display);

    const registry_listener = c.wl_registry_listener{
        .global = registryHandleGlobal,
        .global_remove = registryHandleGlobalRemove,
    };
    _ = c.wl_registry_add_listener(registry, &registry_listener, app);
    _ = c.wl_display_roundtrip(app.display);

    // c.xdg_toplevel_sst_title(self.xdg_toplevel, self.win_title);
    c.xdg_toplevel_set_title(app.xdg_toplevel, app.win_title);

    // default_gpa = self.gpa;
    // default_allocator = self.allocator();

    return app;
}

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
        app.cursor_surface = c.wl_compositor_create_surface(app.compositor);
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

        app.cursor_theme = c.wl_cursor_theme_load("todo", 24, app.shm);
        app.default_cursor = c.wl_cursor_theme_get_cursor(app.cursor_theme, "left_ptr");
        app.text_cursor = c.wl_cursor_theme_get_cursor(app.cursor_theme, "xterm");
        app.hand_cursor = c.wl_cursor_theme_get_cursor(app.cursor_theme, "hand1");
    }

    if (std.mem.eql(u8, iface, "wl_seat")) {
        app.wl_seat = @ptrCast(c.wl_registry_bind(registry, name, &c.wl_seat_interface, version));

        _ = c.wl_seat_add_listener(app.wl_seat, &seat_listener, app);
    }

    if (std.mem.eql(u8, iface, "wl_data_device_manager")) {
        app.data_device_manager = @ptrCast(c.wl_registry_bind(registry, name, &c.wl_data_device_manager_interface, version));

        app.data_device = c.wl_data_device_manager_get_data_device(app.data_device_manager, app.wl_seat);

        app.data_source = c.wl_data_device_manager_create_data_source(app.data_device_manager);

        // Add text/plain MIME type
        c.wl_data_source_offer(app.data_source, "text/plain");

        // Set up listeners for data source
        _ = c.wl_data_source_add_listener(app.data_source, &data_source_listener, app);

        // Set the selection on the data device
        c.wl_data_device_set_selection(app.data_device, app.data_source, 0);
    }
}

pub const data_source_listener = c.wl_data_source_listener{
    .target = dataSourceTarget,
    .send = dataSourceSend,
    .cancelled = dataSourceCancelled,
};

fn dataSourceSend(data: ?*anyopaque, data_source: ?*c.wl_data_source, mime_type: [*c]const u8, fd: i32) callconv(.c) void {
    _ = data_source;
    const app: *ginwaGTK = @ptrCast(@alignCast(data.?));
    const mime_str = std.mem.span(mime_type);

    if (std.mem.eql(u8, mime_str, "text/plain")) {
        if (app.clipboard_text) |text| {
            _ = c.write(fd, text.ptr, text.len);
        }
    }
    _ = c.close(fd);
}

fn dataSourceTarget(data: ?*anyopaque, data_source: ?*c.wl_data_source, mime_type: [*c]const u8) callconv(.c) void {
    _ = data;
    _ = data_source;
    _ = mime_type;
}

fn dataSourceCancelled(data: ?*anyopaque, data_source: ?*c.wl_data_source) callconv(.c) void {
    _ = data_source;
    const app: *ginwaGTK = @ptrCast(@alignCast(data.?));
    _ = c.wl_data_source_destroy(app.data_source);
    app.data_source = null;
}

fn registryHandleGlobalRemove(user_data: ?*anyopaque, registry: ?*c.struct_wl_registry, name: u32) callconv(.c) void {
    _ = user_data;
    _ = registry;
    std.debug.print("Removed global {}\n", .{name});
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
    wl_keyboard: ?*c.wl_keyboard = null,
    data_device_manager: ?*c.wl_data_device_manager = null,
    data_source: ?*c.wl_data_source = null,
    data_device: ?*c.wl_data_device = null,

    last_serial: u32 = 0,

    // cursor
    cursor_surface: ?*c.wl_surface = null,
    cursor_theme: ?*c.wl_cursor_theme = null,
    default_cursor: ?*c.wl_cursor = null,
    text_cursor: ?*c.wl_cursor = null,
    hand_cursor: ?*c.wl_cursor = null,

    // screen
    old_buffer: ?*c.wl_buffer = null,
    current_buffer: ?*c.wl_buffer = null,
    shm_data: [*]u8 = undefined,

    // clipboard to copy paste text
    clipboard_text: ?[]u8 = null,

    // window properties
    win_title: [*c]const u8 = "App",
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
    // gpa: std.heap.GeneralPurposeAllocator(.{}) = .{},
    // memory: ?std.mem.Allocator = null,

    // ui component
    window: Widget = undefined,
    focused_widget: ?*Widget = null,
    hovered_widget: ?*Widget = null,

    // keyboard
    shift_pressed: bool = false,
    ctrl_pressed: bool = false,
    alt_pressed: bool = false,
    pressed_key: ?u32 = null,
    keyboard_rate: i32 = 0.0,
    keyboard_delay: i32 = 0.0,
    next_key_repeat_time: i64 = 0,

    key_repeat_active: bool = false,

    // cursor blinking
    cursor_visible: bool = true,
    last_cursor_blink: i64 = 0,
    cursor_blink_interval: i64 = 500_000_000, // 500ms in nanoseconds
    //
    event_loop_callback: ?*const fn (*ginwaGTK) void = null,

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

        wr.redraw(self);
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
        if (self.cursor_theme) |cursor_theme| {
            c.wl_cursor_theme_destroy(cursor_theme);
        }

        if (self.display) |display| {
            _ = c.wl_display_disconnect(display);
        }
    }

    pub fn allocator(self: *ginwaGTK) std.mem.Allocator {
        _ = self;
        return default_allocator;
    }

    pub fn trigger_event_callback(self: *ginwaGTK) void {
        if (self.event_loop_callback) |callback| {
            callback(self);
        }
    }

    pub fn find_widget_by_id(self: *ginwaGTK, id: []const u8) ?*Widget {
        const widget = self.window.find_widget_by_id(id);
        if (widget) |found_widget| {
            return found_widget;
        }

        return null;
    }
};

pub fn findWidgetAt(widget: *Widget, x: f64, y: f64) ?*Widget {
    const fx = @as(f64, @floatFromInt(widget.x));
    const fy = @as(f64, @floatFromInt(widget.y));
    const fw = @as(f64, @floatFromInt(widget.width));
    const fh = @as(f64, @floatFromInt(widget.height));

    const is_inside = x >= fx and x < fx + fw and y >= fy and y < fy + fh;

    if (!is_inside) return null;

    if (widget.children) |children| {
        var i = children.items.len;
        while (i > 0) {
            i -= 1;
            if (findWidgetAt(children.items[i], x, y)) |found| {
                return found;
            }
        }
    }

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
pub const Orientation = enum { Row, Column, Stack };

pub const WidgetType = enum { Button, Layout, Input, Text, Icon };

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

pub const InputTextType = enum {
    Text,
    Password,
    Number,
    Email,
};

pub const DecodedImage = struct {
    width: u32,
    height: u32,
    rgba: [*c]u8,
    file_buffer: []u8,
    file_path: []const u8,
};

pub const WidthType = enum { Flexible, Expanded };
pub const HeightType = enum { Flexible, Expanded };

// to be used in layout for children items
pub const LayoutAlignment = enum { Start, Center, End, SpaceBetween, SpaceAround, SpaceEvenly };

pub const Widget = struct {
    guid: []const u8 = "",
    parent_guid: []const u8 = "",
    id: []const u8 = "root",

    gap: i32 = 0,
    children: ?std.ArrayList(*Widget) = null,

    widget_type: WidgetType = .Layout,
    is_parent: bool = false,

    x: i32 = 0,
    y: i32 = 0,
    width: i32 = -1, // -1 means auto-size // widget width
    height: i32 = -1, // -1 means auto-size // widget height
    desired_width: ?i32 = null, // Original desired width (for layout restoration)
    desired_height: ?i32 = null, // Original desired height (for layout restoration)

    padding: i32 = 0,
    padding_left: ?i32 = null,
    padding_right: ?i32 = null,
    padding_top: ?i32 = null,
    padding_bottom: ?i32 = null,
    horizontal_alignment: ?LayoutAlignment = null,
    vertical_alignment: ?LayoutAlignment = null,
    orientation: ?Orientation = null,

    input_text: []const u8 = "",
    input_text_type: ?InputTextType = null,
    placeholder: []const u8 = "",
    max_input_text_length: i32 = 0,
    min_input_text_length: i32 = 0,
    text: []const u8 = "",

    font_size: i32 = 11,
    font_type: [*:0]const u8 = "Arial",
    font_alignment: FontAlignment = .CenterLeft,
    font_color: u32 = 0xFFFFFFFF,
    font_weight: FontWeight = .Normal, // Added font weight
    password_visible: bool = false,

    background_color: u32 = 0x00000000,
    backround_is_hovered: bool = false,
    background_hover_color: ?u32 = null,
    border_radius: i32 = 0,
    border_color: ?u32 = null,
    border_width: ?i32 = 0,

    on_click: ?*const fn (*Widget, ?*anyopaque) void = null,
    click_data: ?*anyopaque = null,

    on_input_text_change: ?*const fn (input_text: []const u8, data: ?*anyopaque) void = null,

    cursor_position: usize = 0,
    selection_start: ?usize = null,
    selection_end: ?usize = null,
    selection_anchor: ?usize = null,
    scroll_offset: ?usize = null,

    on_click_backgroud_is_hovered: bool = false,
    on_click_hover_color: ?u32 = null,

    scrollable: bool = false,

    content_width: ?i32 = null,
    content_height: ?i32 = null,
    scrollbar_width: i32 = 12,
    vertical_scroll_enabled: bool = false,
    horizontal_scroll_enabled: bool = false,
    parent: ?*Widget = null,

    // Scrollbar drag state
    is_dragging_scrollbar: bool = false,
    scrollbar_drag_start: i32 = 0,
    scrollbar_drag_start_offset: usize = 0,

    // Image
    image: ?*DecodedImage = null,

    // Helper methods for directional padding
    pub fn getPaddingLeft(self: *const Widget) i32 {
        return self.padding_left orelse self.padding;
    }

    pub fn getPaddingRight(self: *const Widget) i32 {
        return self.padding_right orelse self.padding;
    }

    pub fn getPaddingTop(self: *const Widget) i32 {
        return self.padding_top orelse self.padding;
    }

    pub fn getPaddingBottom(self: *const Widget) i32 {
        return self.padding_bottom orelse self.padding;
    }

    pub fn getPaddingHorizontal(self: *const Widget) i32 {
        return self.getPaddingLeft() + self.getPaddingRight();
    }

    pub fn getPaddingVertical(self: *const Widget) i32 {
        return self.getPaddingTop() + self.getPaddingBottom();
    }

    pub fn isScrollable(self: *const Widget) bool {
        return self.scrollable or self.vertical_scroll_enabled or self.horizontal_scroll_enabled;
    }

    pub fn hasVerticalOverflow(self: *const Widget) bool {
        if (!self.vertical_scroll_enabled and !self.scrollable) return false;
        const content_h = self.content_height orelse 0;
        const viewport_h = self.height - self.getPaddingVertical();
        return content_h > viewport_h;
    }

    pub fn hasHorizontalOverflow(self: *const Widget) bool {
        if (!self.horizontal_scroll_enabled and !self.scrollable) return false;
        const content_w = self.content_width orelse 0;
        const viewport_w = self.width - self.getPaddingHorizontal();
        return content_w > viewport_w;
    }

    pub fn getScrollableContentWidth(self: *const Widget) i32 {
        return self.content_width orelse self.width - self.getPaddingHorizontal();
    }

    pub fn getScrollableContentHeight(self: *const Widget) i32 {
        return self.content_height orelse self.height - self.getPaddingVertical();
    }

    pub fn isPointOnVerticalScrollbar(self: *const Widget, x: f64, y: f64) bool {
        if (!self.hasVerticalOverflow()) return false;

        const scrollbar_x = self.x + self.width - self.scrollbar_width - 2;
        const scrollbar_y = self.y + self.getPaddingTop();
        const scrollbar_h = self.height - self.getPaddingVertical();

        return x >= @as(f64, @floatFromInt(scrollbar_x)) and
            x <= @as(f64, @floatFromInt(scrollbar_x + self.scrollbar_width)) and
            y >= @as(f64, @floatFromInt(scrollbar_y)) and
            y <= @as(f64, @floatFromInt(scrollbar_y + scrollbar_h));
    }

    pub fn getVerticalScrollbarThumbRect(self: *const Widget) struct { x: i32, y: i32, width: i32, height: i32 } {
        if (!self.hasVerticalOverflow()) {
            return .{ .x = 0, .y = 0, .width = 0, .height = 0 };
        }

        const scrollbar_width = self.scrollbar_width;
        const content_h = self.getScrollableContentHeight();
        const viewport_h = self.height - self.getPaddingVertical();
        const scroll_offset = @as(i32, @intCast(self.scroll_offset orelse 0));

        const scrollbar_x = self.x + self.width - scrollbar_width - 2;
        const scrollbar_y = self.y + self.getPaddingTop();
        const scrollbar_h = viewport_h;

        const max_scroll = @max(0, content_h - viewport_h);
        const thumb_h = @max(20, @as(i32, @intFromFloat(@as(f64, @floatFromInt(viewport_h)) * @as(f64, @floatFromInt(viewport_h)) / @as(f64, @floatFromInt(content_h)))));
        const thumb_track = scrollbar_h - thumb_h;
        const thumb_ratio = if (max_scroll > 0) @as(f64, @floatFromInt(scroll_offset)) / @as(f64, @floatFromInt(max_scroll)) else 0.0;
        const thumb_y = scrollbar_y + @as(i32, @intFromFloat(thumb_ratio * @as(f64, @floatFromInt(thumb_track))));

        return .{
            .x = scrollbar_x + 2,
            .y = thumb_y,
            .width = scrollbar_width - 4,
            .height = thumb_h,
        };
    }

    pub fn isPointOnVerticalScrollbarThumb(self: *const Widget, x: f64, y: f64) bool {
        if (!self.hasVerticalOverflow()) return false;

        const rect = self.getVerticalScrollbarThumbRect();
        return x >= @as(f64, @floatFromInt(rect.x)) and
            x <= @as(f64, @floatFromInt(rect.x + rect.width)) and
            y >= @as(f64, @floatFromInt(rect.y)) and
            y <= @as(f64, @floatFromInt(rect.y + rect.height));
    }

    pub fn trigger_click(self: *Widget) void {
        if (self.on_click) |callback| {
            callback(self, self.click_data);
        }
    }

    pub fn trigger_input_text_change(self: *Widget) void {
        if (self.on_input_text_change) |callback| {
            callback(self.input_text, self.click_data);
        }
    }

    pub fn add_child(self: *Widget, child: *Widget) !void {
        if (self.children == null) {
            std.debug.print("create children list\n", .{});
            self.children = .empty;
        }

        child.parent_guid = self.guid;
        child.parent = self;
        try self.children.?.append(default_allocator, child);
    }

    pub fn add_children(self: *Widget, children: anytype) !void {
        // @TypeOf(children) is a tuple or array of *Widget
        inline for (children) |child| {
            try self.add_child(child);
        }
    }

    pub fn deinit(self: *Widget) void {
        if (self.children) |*list| {
            for (list.items) |child| {
                if (child.image) |decodedImage| {
                    c.stbi_image_free(decodedImage.rgba);
                    default_allocator.free(decodedImage.file_buffer);
                }
                child.deinit();
                default_allocator.destroy(child);
            }
            list.deinit(default_allocator);
        }
    }

    pub fn find_widget_by_id(self: *Widget, id: []const u8) ?*Widget {
        if (id.len == 0) return null;
        if (std.mem.eql(u8, self.id, id)) {
            return self;
        }

        if (self.children) |children| {
            for (children.items) |child| {
                const found = child.find_widget_by_id(id);
                if (found) |found_widget| {
                    return found_widget;
                }
            }
        }

        return null;
    }
};
