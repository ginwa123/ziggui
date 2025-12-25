const std = @import("std");

const c = @cImport({
    @cInclude("cairo.h");
    @cInclude("pango/pango.h");
    @cInclude("pango/pangocairo.h");
});

const random = @import("random.zig");

pub fn renderText(
    widget: *Widget,
    pixels: [*]u32,
    pitch_bytes: usize,
    buf_w: usize,
    buf_h: usize,
) void {
    if (widget.text.len == 0) return;

    const stride = @as(i32, @intCast(pitch_bytes));
    const surface = c.cairo_image_surface_create_for_data(
        @ptrCast(pixels),
        c.CAIRO_FORMAT_ARGB32,
        @as(i32, @intCast(buf_w)),
        @as(i32, @intCast(buf_h)),
        stride,
    );
    defer c.cairo_surface_destroy(surface);

    const cr = c.cairo_create(surface);
    defer c.cairo_destroy(cr);

    const layout = c.pango_cairo_create_layout(cr);
    defer c.g_object_unref(layout);

    c.pango_layout_set_text(layout, widget.text.ptr, @as(i32, @intCast(widget.text.len)));

    var font_buf: [128]u8 = undefined;

    const font_str_z = if (widget.font_size > 0)
        std.fmt.bufPrintZ(&font_buf, "{s} {d}", .{
            widget.font_type,
            widget.font_size,
        }) catch "Sans 16"
    else
        std.fmt.bufPrintZ(&font_buf, "{s}", .{widget.font_type}) catch "Sans";

    const font_desc = c.pango_font_description_from_string(font_str_z);

    defer c.pango_font_description_free(font_desc);
    c.pango_layout_set_font_description(layout, font_desc);

    c.pango_layout_set_width(layout, widget.width * c.PANGO_SCALE);
    c.pango_layout_set_alignment(layout, c.PANGO_ALIGN_CENTER);
    c.pango_layout_set_wrap(layout, c.PANGO_WRAP_WORD_CHAR);

    c.cairo_set_source_rgba(cr, 1.0, 1.0, 1.0, 1.0);

    c.cairo_move_to(cr, @floatFromInt(widget.x + widget.padding), @floatFromInt(widget.y + widget.padding));

    c.pango_cairo_show_layout(cr, layout);
}

pub const Orientation = enum {
    Row,
    Column,
};

pub const WidgetType = enum {
    Button,
    Layout,
};

pub const FontAllignment = enum {
    Left,
    LeftTop,
    LeftBottom,
    CenterLeft,
    Center,
    CenterRight,
    Right,
    RightTop,
    RightBottom,
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
    text: []const u8 = "",
    font_size: i32 = 16,
    font_type: [*:0]const u8 = "Arial",
    font_allignment: FontAllignment = .Left,
    background_color: u32 = 0xFF333333,
    border_radius: i32 = 0,
    border_color: ?u32 = null,
    border_width: ?i32 = 0,

    on_click: ?*const fn (*Widget, ?*anyopaque) void = null,
    click_data: ?*anyopaque = null,

    allocator: std.mem.Allocator,

    pub fn onClick(self: *Widget, comptime callback: anytype, data: ?*anyopaque) *Widget {
        const S = struct {
            fn wrapper(w: *Widget, d: ?*anyopaque) void {
                _ = w;
                @call(.auto, callback, .{d});
            }
        };
        self.on_click = S.wrapper;
        self.click_data = data;
        return self;
    }

    pub fn add_children(self: *Widget, allocator: std.mem.Allocator, child: *Widget) !void {
        if (self.children == null) {
            std.debug.print("self.children == null\n", .{});
            self.children = .empty;
        }

        std.debug.print("child: {any}\n", .{child});
        child.parent_guid = self.guid;
        try self.children.?.append(allocator, child);
    }

    pub fn deinit(self: *Widget) void {
        if (self.children) |*list| {
            for (list.items) |child| {
                child.deinit();
                self.allocator.destroy(child);
            }
            list.deinit();
        }
    }
};

pub fn layoutWidget(widget: *Widget, avail_w: i32, avail_h: i32) void {
    if (widget.widget_type == .Layout and widget.children != null) {
        if (widget.width == 0 or widget.height == 0) {
            const measured = measureLayout(widget);
            if (widget.width == 0) widget.width = measured.width;
            if (widget.height == 0) widget.height = measured.height;
        }
    }

    const final_w = if (avail_w > 0) @min(widget.width, avail_w) else widget.width;
    const final_h = if (avail_h > 0) @min(widget.height, avail_h) else widget.height;

    widget.width = final_w;
    widget.height = final_h;

    const inner_w = final_w - 2 * widget.padding;
    const inner_h = final_h - 2 * widget.padding;

    if (widget.children) |*children| {
        const child_count = children.items.len;
        if (child_count == 0) return;

        if (widget.widget_type == .Layout) {
            if (widget.orientation == .Row) {
                var cur_x: i32 = widget.padding;
                for (children.items, 0..) |child, idx| {
                    const child_w = @min(child.width, inner_w);
                    const child_h = @min(child.height, inner_h);

                    child.x = widget.x + cur_x;
                    child.y = widget.y + widget.padding;

                    layoutWidget(child, child_w, child_h);

                    cur_x += child.width;
                    if (idx + 1 < child_count) {
                        cur_x += widget.gap;
                    }
                }
            } else if (widget.orientation == .Column) {
                var cur_y: i32 = widget.padding;
                for (children.items, 0..) |child, idx| {
                    const child_w = @min(child.width, inner_w);
                    const child_h = @min(child.height, inner_h);

                    child.x = widget.x + widget.padding;
                    child.y = widget.y + cur_y;

                    layoutWidget(child, child_w, child_h);

                    cur_y += child.height;
                    if (idx + 1 < child_count) {
                        cur_y += widget.gap;
                    }
                }
            }
        } else {
            for (children.items) |child| {
                child.x = widget.x + widget.padding;
                child.y = widget.y + widget.padding;
                layoutWidget(child, child.width, child.height);
            }
        }
    }
}

fn measureLayout(widget: *Widget) struct { width: i32, height: i32 } {
    if (widget.children == null or widget.children.?.items.len == 0) {
        return .{ .width = 2 * widget.padding, .height = 2 * widget.padding };
    }

    const children = widget.children.?.items;
    var total_w: i32 = 2 * widget.padding;
    var total_h: i32 = 2 * widget.padding;

    if (widget.orientation == .Row) {
        var max_h: i32 = 0;
        for (children, 0..) |child, idx| {
            var child_w = child.width;
            var child_h = child.height;
            if (child.widget_type == .Layout and (child_w == 0 or child_h == 0)) {
                const measured = measureLayout(child);
                if (child_w == 0) child_w = measured.width;
                if (child_h == 0) child_h = measured.height;
            }

            total_w += child_w;
            if (idx + 1 < children.len) {
                total_w += widget.gap;
            }
            max_h = @max(max_h, child_h);
        }
        total_h += max_h;
    } else if (widget.orientation == .Column) {
        var max_w: i32 = 0;
        for (children, 0..) |child, idx| {
            var child_w = child.width;
            var child_h = child.height;
            if (child.widget_type == .Layout and (child_w == 0 or child_h == 0)) {
                const measured = measureLayout(child);
                if (child_w == 0) child_w = measured.width;
                if (child_h == 0) child_h = measured.height;
            }

            total_h += child_h;
            if (idx + 1 < children.len) {
                total_h += widget.gap;
            }
            max_w = @max(max_w, child_w);
        }
        total_w += max_w;
    }

    return .{ .width = total_w, .height = total_h };
}

pub fn renderWidget(
    widget: *Widget,
    pixels: [*]u32,
    pitch: usize,
    buf_w: usize,
    buf_h: usize,
) void {
    if (widget.width <= 0 or widget.height <= 0) return;

    const x = widget.x;
    const y = widget.y;
    const w = widget.width;
    const h = widget.height;

    // Render background and border with Cairo for rounded corners
    if (widget.border_radius > 0) {
        renderRoundedWidget(
            pixels,
            pitch,
            buf_w,
            buf_h,
            x,
            y,
            w,
            h,
            widget.background_color,
            widget.border_color,
            widget.border_width orelse 0,
            widget.border_radius,
        );
    } else {
        // Sharp corners - use simple rect fill
        fillRectClipped(
            pixels,
            pitch,
            buf_w,
            buf_h,
            x,
            y,
            w,
            h,
            widget.background_color,
        );

        // Render border if enabled
        if (widget.border_color != null and widget.border_width != null) {
            const border_w = widget.border_width.?;
            if (border_w > 0) {
                renderBorder(
                    pixels,
                    pitch,
                    buf_w,
                    buf_h,
                    x,
                    y,
                    w,
                    h,
                    widget.border_color.?,
                    border_w,
                );
            }
        }
    }

    // Render text
    const pitch_bytes = pitch * 4;
    renderText(widget, pixels, pitch_bytes, buf_w, buf_h);

    // Render children
    if (widget.children) |children| {
        for (children.items) |child| {
            renderWidget(child, pixels, pitch, buf_w, buf_h);
        }
    }
}

fn renderRoundedWidget(
    pixels: [*]u32,
    pitch: usize,
    buf_w: usize,
    buf_h: usize,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    bg_color: u32,
    border_color: ?u32,
    border_width: i32,
    radius: i32,
) void {
    const stride = @as(i32, @intCast(pitch * 4));
    const surface = c.cairo_image_surface_create_for_data(
        @ptrCast(pixels),
        c.CAIRO_FORMAT_ARGB32,
        @as(i32, @intCast(buf_w)),
        @as(i32, @intCast(buf_h)),
        stride,
    );
    defer c.cairo_surface_destroy(surface);

    const cr = c.cairo_create(surface);
    defer c.cairo_destroy(cr);

    const fx = @as(f64, @floatFromInt(x));
    const fy = @as(f64, @floatFromInt(y));
    const fw = @as(f64, @floatFromInt(w));
    const fh = @as(f64, @floatFromInt(h));
    const fr = @as(f64, @floatFromInt(radius));

    // Create rounded rectangle path
    c.cairo_new_sub_path(cr);
    c.cairo_arc(cr, fx + fw - fr, fy + fr, fr, -std.math.pi / 2.0, 0.0);
    c.cairo_arc(cr, fx + fw - fr, fy + fh - fr, fr, 0.0, std.math.pi / 2.0);
    c.cairo_arc(cr, fx + fr, fy + fh - fr, fr, std.math.pi / 2.0, std.math.pi);
    c.cairo_arc(cr, fx + fr, fy + fr, fr, std.math.pi, 3.0 * std.math.pi / 2.0);
    c.cairo_close_path(cr);

    // Fill background
    const bg_r = @as(f64, @floatFromInt((bg_color >> 16) & 0xFF)) / 255.0;
    const bg_g = @as(f64, @floatFromInt((bg_color >> 8) & 0xFF)) / 255.0;
    const bg_b = @as(f64, @floatFromInt(bg_color & 0xFF)) / 255.0;
    const bg_a = @as(f64, @floatFromInt((bg_color >> 24) & 0xFF)) / 255.0;
    c.cairo_set_source_rgba(cr, bg_r, bg_g, bg_b, bg_a);
    c.cairo_fill_preserve(cr);

    // Draw border if specified
    if (border_color != null and border_width > 0) {
        const bcolor = border_color.?;
        const b_r = @as(f64, @floatFromInt((bcolor >> 16) & 0xFF)) / 255.0;
        const b_g = @as(f64, @floatFromInt((bcolor >> 8) & 0xFF)) / 255.0;
        const b_b = @as(f64, @floatFromInt(bcolor & 0xFF)) / 255.0;
        const b_a = @as(f64, @floatFromInt((bcolor >> 24) & 0xFF)) / 255.0;
        c.cairo_set_source_rgba(cr, b_r, b_g, b_b, b_a);
        c.cairo_set_line_width(cr, @floatFromInt(border_width));
        c.cairo_stroke(cr);
    } else {
        c.cairo_new_path(cr); // Clear the path
    }
}

fn renderBorder(
    pixels: [*]u32,
    pitch: usize,
    buf_w: usize,
    buf_h: usize,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    color: u32,
    border_width: i32,
) void {
    // Top border
    fillRectClipped(pixels, pitch, buf_w, buf_h, x, y, w, border_width, color);

    // Bottom border
    fillRectClipped(pixels, pitch, buf_w, buf_h, x, y + h - border_width, w, border_width, color);

    // Left border
    fillRectClipped(pixels, pitch, buf_w, buf_h, x, y, border_width, h, color);

    // Right border
    fillRectClipped(pixels, pitch, buf_w, buf_h, x + w - border_width, y, border_width, h, color);
}

fn fillRectClipped(
    pixels: [*]u32,
    pitch: usize,
    buf_w: usize,
    buf_h: usize,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    color: u32,
) void {
    const x0 = @max(x, 0);
    const y0 = @max(y, 0);
    const x1 = @min(x + w, @as(i32, @intCast(buf_w)));
    const y1 = @min(y + h, @as(i32, @intCast(buf_h)));

    if (x0 >= x1 or y0 >= y1) return;

    var py: i32 = y0;
    while (py < y1) : (py += 1) {
        const row = @as(usize, @intCast(py)) * pitch;
        var px: i32 = x0;
        while (px < x1) : (px += 1) {
            pixels[row + @as(usize, @intCast(px))] = color;
        }
    }
}

// Widget constructors

pub const PColumn = struct {
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

pub fn c_collumn(alloc: std.mem.Allocator, props: PColumn) !*Widget {
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

pub const PRow = struct {
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

pub fn c_row(alloc: std.mem.Allocator, props: PRow) !*Widget {
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

pub const PButton = struct {
    name: []const u8 = "",
    width: i32 = 0,
    height: i32 = 0,
    label: []const u8 = "",
    background_color: u32 = 0xFF333333,
    border_color: ?u32 = null,
    border_width: ?i32 = 0,
    border_radius: i32 = 0,
};

pub fn c_btn(alloc: std.mem.Allocator, props: PButton) !*Widget {
    const widget = try alloc.create(Widget);
    widget.* = .{
        .guid = try random.randomId(alloc),
        .name = props.name,
        .width = props.width,
        .height = props.height,
        .text = props.label,
        .widget_type = .Button,
        .allocator = alloc,
        .background_color = props.background_color,
        .border_color = props.border_color,
        .border_width = props.border_width,
        .border_radius = props.border_radius
    };

    return widget;
}
