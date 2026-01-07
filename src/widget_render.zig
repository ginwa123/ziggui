const std = @import("std");
const utils = @import("utils.zig");
const w = @import("widget.zig");
const wk = @import("widget_keyboard.zig");
const c = w.c;
const Widget = w.Widget;
const ginwaGTK = w.ginwaGTK;

fn renderEyeIcon(
    widget: *Widget,
    pixels: [*]u32,
    pitch: usize,
    buf_w: usize,
    buf_h: usize,
) void {
    _ = pixels;
    _ = pitch;
    _ = buf_w;
    _ = buf_h;
    // currentlyd disabled
    // Only show eye icon for password inputs
    if (widget.widget_type != .Input or
        widget.input_text_type != .Password)
    {
        return;
    }

    return;
    //
    // const stride = @as(i32, @intCast(pitch * 4));
    // const surface = c.cairo_image_surface_create_for_data(
    //     @ptrCast(pixels),
    //     c.CAIRO_FORMAT_ARGB32,
    //     @as(i32, @intCast(buf_w)),
    //     @as(i32, @intCast(buf_h)),
    //     stride,
    // );
    // defer c.cairo_surface_destroy(surface);
    //
    // const cr = c.cairo_create(surface);
    // defer c.cairo_destroy(cr);
    //
    // // Position eye icon on the right side of the input
    // const icon_size: i32 = 16;
    // const icon_padding: i32 = 10;
    // const icon_x = widget.x + widget.width - icon_size - icon_padding;
    // const icon_y = widget.y + @divTrunc(widget.height - icon_size, 2); // Fixed division
    // const center_x = icon_x + @divTrunc(icon_size, 2); // Fixed division
    // const center_y = icon_y + @divTrunc(icon_size, 2); // Fixed division
    // const radius = @divTrunc(icon_size, 2) - 2;
    //
    // // Eye outline (circle)
    // c.cairo_set_line_width(cr, 1.5);
    // c.cairo_set_source_rgba(cr, 0.7, 0.7, 0.7, 0.8); // Gray color
    // c.cairo_arc(cr, @as(f64, @floatFromInt(center_x)), @as(f64, @floatFromInt(center_y)), @as(f64, @floatFromInt(radius)), 0, 2 * std.math.pi);
    // c.cairo_stroke(cr);
    //
    // if (widget.password_visible) {
    //     // Password is VISIBLE - draw horizontal line through the eye
    //     c.cairo_set_line_width(cr, 1.5);
    //     c.cairo_set_source_rgba(cr, 0.7, 0.7, 0.7, 0.8);
    //     c.cairo_move_to(cr, @as(f64, @floatFromInt(icon_x + 3)), @as(f64, @floatFromInt(center_y)));
    //     c.cairo_line_to(cr, @as(f64, @floatFromInt(icon_x + icon_size - 3)), @as(f64, @floatFromInt(center_y)));
    //     c.cairo_stroke(cr);
    // } else {
    //     // Password is HIDDEN - draw pupil (filled circle)
    //     c.cairo_set_source_rgba(cr, 0.7, 0.7, 0.7, 0.8);
    //     c.cairo_arc(cr, @as(f64, @floatFromInt(center_x)), @as(f64, @floatFromInt(center_y)), 3, 0, 2 * std.math.pi);
    //     c.cairo_fill(cr);
    // }
}

fn renderIconImage(
    widget: *Widget,
    pixels: [*]u32,
    pitch: usize,
    buf_w: usize,
    buf_h: usize,
) void {
    if (widget.image == null) return;
    const decoded_image = widget.image.?;

    // Original image dimensions
    const orig_img_w = decoded_image.width;
    const orig_img_h = decoded_image.height;

    // Display dimensions (from widget)
    const display_w = widget.width;
    const display_h = widget.height;

    // Position the icon centered in the widget
    const img_x = widget.x + @divTrunc(widget.width - display_w, 2);
    const img_y = widget.y + @divTrunc(widget.height - display_h, 2);

    // Calculate scaling factors
    const scale_x = @as(f32, @floatFromInt(display_w)) / @as(f32, @floatFromInt(orig_img_w));
    const scale_y = @as(f32, @floatFromInt(display_h)) / @as(f32, @floatFromInt(orig_img_h));

    var py: i32 = 0;
    while (py < display_h) : (py += 1) {
        if (img_y + py < 0 or img_y + py >= @as(i32, @intCast(buf_h))) continue;
        const row = @as(usize, @intCast(img_y + py)) * pitch;

        var px: i32 = 0;
        while (px < display_w) : (px += 1) {
            if (img_x + px < 0 or img_x + px >= @as(i32, @intCast(buf_w))) continue;

            // Map display pixel to original image pixel using scaling
            const src_x_f = @as(f32, @floatFromInt(px)) / scale_x;
            const src_y_f = @as(f32, @floatFromInt(py)) / scale_y;

            const src_x = @min(orig_img_w - 1, @as(i32, @intFromFloat(src_x_f)));
            const src_y = @min(orig_img_h - 1, @as(i32, @intFromFloat(src_y_f)));

            const img_idx = (@as(usize, @intCast(src_y)) * orig_img_w + @as(usize, @intCast(src_x))) * 4;
            const screen_idx = row + @as(usize, @intCast(img_x + px));

            // Read channels as-is from stb_image
            const r = decoded_image.rgba[img_idx + 0];
            const g = decoded_image.rgba[img_idx + 1];
            const b = decoded_image.rgba[img_idx + 2];
            const a = decoded_image.rgba[img_idx + 3];

            // Render with alpha blending
            if (a > 0) {
                pixels[screen_idx] = @as(u32, r) | (@as(u32, g) << 8) | (@as(u32, b) << 16) | 0xFF000000;
            }
        }
    }
}

pub fn renderText(
    widget: *Widget,
    pixels: [*]u32,
    pitch_bytes: usize,
    buf_w: usize,
    buf_h: usize,
    app: *ginwaGTK, // ADD THIS PARAMETER
) void {
    // Skip rendering if no text and not an Input widget
    if (widget.text.len == 0 and widget.widget_type != .Input) return;

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

    c.cairo_rectangle(cr, @as(f64, @floatFromInt(widget.x)), @as(f64, @floatFromInt(widget.y)), @as(f64, @floatFromInt(widget.width)), @as(f64, @floatFromInt(widget.height)));
    c.cairo_clip(cr);

    const layout = c.pango_cairo_create_layout(cr);
    defer c.g_object_unref(layout);

    // Use input_text for Input widgets, otherwise use text
    var display_text = if (widget.widget_type == .Input)
        if (widget.input_text.len > 0)
            widget.input_text
        else if (widget.placeholder.len > 0)
            widget.placeholder
        else
            widget.text
    else
        widget.text;

    const text_to_render = if (widget.widget_type == .Input and widget.input_text.len > 0 and widget.input_text_type == .Password and widget.password_visible == false)
        // Create asterisks string for password display
        blk: {
            const password_len = widget.input_text.len;
            var password_buf: [256]u8 = undefined;
            @memset(password_buf[0..password_len], '*');
            break :blk password_buf[0..password_len];
        } else display_text;

    display_text = text_to_render;
    c.pango_layout_set_text(layout, display_text.ptr, @as(i32, @intCast(display_text.len)));

    // Create font description with size
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

    c.pango_font_description_set_weight(font_desc, widget.font_weight.toPangoWeight());
    c.pango_layout_set_font_description(layout, font_desc);

    if (widget.widget_type == .Input) {
        c.pango_layout_set_width(layout, -1);
    } else {
        c.pango_layout_set_width(layout, (widget.width - widget.getPaddingHorizontal()) * c.PANGO_SCALE);
        c.pango_layout_set_wrap(layout, c.PANGO_WRAP_WORD_CHAR);
    }

    c.pango_layout_set_alignment(layout, widget.font_alignment.toPangoAlign());

    var ink_rect: c.PangoRectangle = undefined;
    var logical_rect: c.PangoRectangle = undefined;
    c.pango_layout_get_pixel_extents(layout, &ink_rect, &logical_rect);

    const scroll_amount: usize = widget.scroll_offset orelse 0;

    const text_x: f64 = @as(f64, @floatFromInt(widget.x + widget.getPaddingLeft())) -
        @as(f64, @floatFromInt(scroll_amount));

    var text_y: f64 = @floatFromInt(widget.y + widget.getPaddingTop());

    const content_height = widget.height - widget.getPaddingVertical();
    const text_height = logical_rect.height;

    switch (widget.font_alignment) {
        .LeftTop, .RightTop => {},
        .CenterLeft, .Center, .CenterRight => {
            text_y += @as(f64, @floatFromInt(content_height - text_height)) / 2.0;
        },
        .LeftBottom, .RightBottom => {
            text_y += @floatFromInt(content_height - text_height);
        },
        else => {},
    }

    // Use gray color for placeholder text, otherwise use font_color
    const is_placeholder = widget.widget_type == .Input and widget.input_text.len == 0 and widget.placeholder.len > 0;
    const text_color: u32 = if (is_placeholder) 0xFF888888 else widget.font_color;

    const alpha = @as(f64, @floatFromInt((text_color >> 24) & 0xFF)) / 255.0;
    const red = @as(f64, @floatFromInt((text_color >> 16) & 0xFF)) / 255.0;
    const green = @as(f64, @floatFromInt((text_color >> 8) & 0xFF)) / 255.0;
    const blue = @as(f64, @floatFromInt(text_color & 0xFF)) / 255.0;

    c.cairo_set_source_rgba(cr, red, green, blue, alpha);
    c.cairo_move_to(cr, text_x, text_y);
    c.pango_cairo_show_layout(cr, layout);

    // ===== BLINKING CURSOR - ONLY FOR INPUT WIDGETS =====
    const is_focused = if (app.focused_widget) |focused| focused == widget else false;

    // ===== RENDER SELECTION HIGHLIGHT =====
    if (widget.widget_type == .Input and is_focused) {
        if (widget.selection_start != null and widget.selection_end != null) {
            const start = @min(widget.selection_start.?, widget.selection_end.?);
            const end = @max(widget.selection_start.?, widget.selection_end.?);

            if (start != end) {
                // Get the position of selection start and end
                var start_rect: c.PangoRectangle = undefined;
                var end_rect: c.PangoRectangle = undefined;
                c.pango_layout_get_cursor_pos(layout, @intCast(start), &start_rect, null);
                c.pango_layout_get_cursor_pos(layout, @intCast(end), &end_rect, null);

                const sel_x = text_x + @as(f64, @floatFromInt(start_rect.x)) / @as(f64, @floatFromInt(c.PANGO_SCALE));
                const sel_width = (@as(f64, @floatFromInt(end_rect.x - start_rect.x))) / @as(f64, @floatFromInt(c.PANGO_SCALE));
                const sel_y = text_y;
                const sel_height = @as(f64, @floatFromInt(logical_rect.height));

                // Draw selection background (light blue)
                c.cairo_set_source_rgba(cr, 0.3, 0.6, 1.0, 0.3);
                c.cairo_rectangle(cr, sel_x, sel_y, sel_width, sel_height);
                c.cairo_fill(cr);
            }
        }
    }

    // Only draw cursor if:
    // 1. This is an Input widget
    // 2. This widget is focused
    // 3. Cursor is in visible state (blinking)
    if (widget.widget_type == .Input and is_focused and app.cursor_visible) {
        // Get cursor position at the cursor_position index
        const cursor_index: i32 = @intCast(widget.cursor_position);
        var cursor_rect: c.PangoRectangle = undefined;
        c.pango_layout_get_cursor_pos(layout, cursor_index, &cursor_rect, null);

        const cursor_x = text_x + @as(f64, @floatFromInt(cursor_rect.x)) / @as(f64, @floatFromInt(c.PANGO_SCALE));
        const cursor_y = text_y + @as(f64, @floatFromInt(cursor_rect.y)) / @as(f64, @floatFromInt(c.PANGO_SCALE));
        const cursor_height = @as(f64, @floatFromInt(cursor_rect.height)) / @as(f64, @floatFromInt(c.PANGO_SCALE));

        // Draw cursor line
        c.cairo_set_line_width(cr, 2.0);
        c.cairo_set_source_rgba(cr, red, green, blue, alpha);
        c.cairo_move_to(cr, cursor_x, cursor_y);
        c.cairo_line_to(cr, cursor_x, cursor_y + cursor_height);
        c.cairo_stroke(cr);
    }
}

pub fn renderWidget(
    widget: *Widget,
    pixels: [*]u32,
    pitch: usize,
    buf_w: usize,
    buf_h: usize,
    app: *ginwaGTK, // Add app parameter
) void {
    if (widget.width <= 0 or widget.height <= 0) return;

    const widget_x = widget.x;
    const widget_y = widget.y;
    const widget_width = widget.width;
    const widget_height = widget.height;

    // Only render background if not transparent (alpha > 0)
    const bg_alpha = (widget.background_color >> 24) & 0xFF;
    if (bg_alpha > 0) {
        var current_bg_color = widget.background_color;
        if (widget.backround_is_hovered) {
            current_bg_color = widget.background_hover_color orelse widget.background_color;
        }

        if (widget.on_click_backgroud_is_hovered) {
            current_bg_color = widget.on_click_hover_color orelse widget.background_color;
        }

        if (widget.border_radius > 0) {
            renderRoundedWidget(
                pixels,
                pitch,
                buf_w,
                buf_h,
                widget_x,
                widget_y,
                widget_width,
                widget_height,
                current_bg_color,
                widget.border_color,
                widget.border_width orelse 0,
                widget.border_radius,
            );
        } else {
            fillRectClipped(
                pixels,
                pitch,
                buf_w,
                buf_h,
                widget_x,
                widget_y,
                widget_width,
                widget_height,
                current_bg_color,
            );

            if (widget.border_color != null and widget.border_width != null) {
                const border_w = widget.border_width.?;
                if (border_w > 0) {
                    renderBorder(
                        pixels,
                        pitch,
                        buf_w,
                        buf_h,
                        widget_x,
                        widget_y,
                        widget_width,
                        widget_height,
                        widget.border_color.?,
                        border_w,
                    );
                }
            }
        }
    }

    // Render text with app reference
    const pitch_bytes = pitch * 4;
    renderText(widget, pixels, pitch_bytes, buf_w, buf_h, app);

    // Render icon image
    if (widget.widget_type == .Icon and widget.image != null) {
        renderIconImage(widget, pixels, pitch, buf_w, buf_h);
    }

    renderEyeIcon(widget, pixels, pitch, buf_w, buf_h);

    // Render children with simple viewport clipping for scrollable containers
    if (widget.children) |children| {
        // For scrollable containers, calculate viewport bounds to prevent overlap
        if (widget.widget_type == .Layout and widget.isScrollable()) {
            // Calculate viewport bounds (exclude scrollbar area)
            const viewport_x = widget.x + widget.getPaddingLeft();
            const viewport_y = widget.y + widget.getPaddingTop();
            const scrollbar_offset = if (widget.hasVerticalOverflow()) widget.scrollbar_width + 2 else 0;
            const viewport_w = widget.width - widget.getPaddingHorizontal() - scrollbar_offset;
            const viewport_h = widget.height - widget.getPaddingVertical();

            // Render children, but skip those completely outside the viewport
            for (children.items) |child| {
                // Check if child is at least partially visible in the viewport
                const child_visible = child.x < (viewport_x + viewport_w) and
                    (child.x + child.width) > viewport_x and
                    child.y < (viewport_y + viewport_h) and
                    (child.y + child.height) > viewport_y;

                if (child_visible) {
                    renderWidget(child, pixels, pitch, buf_w, buf_h, app);
                }
                // If not visible, skip rendering (this is the clipping)
            }
        } else {
            // Regular rendering without clipping
            for (children.items) |child| {
                renderWidget(child, pixels, pitch, buf_w, buf_h, app);
            }
        }
    }

    // Render scrollbar for scrollable containers
    if (widget.widget_type == .Layout and widget.hasVerticalOverflow()) {
        renderVerticalScrollbar(widget, pixels, pitch, buf_w, buf_h);
    }
}

fn renderRoundedWidget(
    pixels: [*]u32,
    pitch: usize,
    buf_w: usize,
    buf_h: usize,
    x: i32,
    y: i32,
    widget_width: i32,
    widget_height: i32,
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
    const fw = @as(f64, @floatFromInt(widget_width));
    const fh = @as(f64, @floatFromInt(widget_height));
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
    widget_width: i32,
    widget_height: i32,
    color: u32,
    border_width: i32,
) void {
    // Top border
    fillRectClipped(pixels, pitch, buf_w, buf_h, x, y, widget_width, border_width, color);

    // Bottom border
    fillRectClipped(pixels, pitch, buf_w, buf_h, x, y + widget_height - border_width, widget_width, border_width, color);

    // Left border
    fillRectClipped(pixels, pitch, buf_w, buf_h, x, y, border_width, widget_height, color);

    // Right border
    fillRectClipped(pixels, pitch, buf_w, buf_h, x + widget_width - border_width, y, border_width, widget_height, color);
}

fn fillRectClipped(
    pixels: [*]u32,
    pitch: usize,
    buf_w: usize,
    buf_h: usize,
    x: i32,
    y: i32,
    widget_width: i32,
    widget_height: i32,
    color: u32,
) void {
    const x0 = @max(x, 0);
    const y0 = @max(y, 0);
    const x1 = @min(x + widget_width, @as(i32, @intCast(buf_w)));
    const y1 = @min(y + widget_height, @as(i32, @intCast(buf_h)));

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

fn renderVerticalScrollbar(
    widget: *Widget,
    pixels: [*]u32,
    pitch: usize,
    buf_w: usize,
    buf_h: usize,
) void {
    if (!widget.hasVerticalOverflow()) return;

    const scrollbar_width = widget.scrollbar_width;
    const content_h = widget.getScrollableContentHeight();
    const viewport_h = widget.height - widget.getPaddingVertical();
    const scroll_offset = @as(i32, @intCast(widget.scroll_offset orelse 0));

    // Calculate scrollbar position and size
    const scrollbar_x = widget.x + widget.width - scrollbar_width - 2;
    const scrollbar_y = widget.y + widget.getPaddingTop();
    const scrollbar_h = viewport_h;

    // Calculate thumb position and size
    const max_scroll = @max(0, content_h - viewport_h);
    const thumb_h = @max(20, @as(i32, @intFromFloat(@as(f64, @floatFromInt(viewport_h)) * @as(f64, @floatFromInt(viewport_h)) / @as(f64, @floatFromInt(content_h)))));
    const thumb_track = scrollbar_h - thumb_h; // Available space for thumb to move
    const thumb_ratio = if (max_scroll > 0) @as(f64, @floatFromInt(scroll_offset)) / @as(f64, @floatFromInt(max_scroll)) else 0.0;
    const thumb_y = scrollbar_y + @as(i32, @intFromFloat(thumb_ratio * @as(f64, @floatFromInt(thumb_track))));

    // Draw scrollbar track (light gray)
    fillRectClipped(pixels, pitch, buf_w, buf_h, scrollbar_x, scrollbar_y, scrollbar_width, scrollbar_h, 0xFF444444);

    // Draw scrollbar thumb (darker gray)
    fillRectClipped(pixels, pitch, buf_w, buf_h, scrollbar_x + 2, thumb_y, scrollbar_width - 4, thumb_h, 0xFF666666);
}

fn measureLayout(widget: *Widget) struct { width: i32, height: i32, content_width: i32, content_height: i32 } {
    if (widget.children == null or widget.children.?.items.len == 0) {
        const padding_w = widget.getPaddingHorizontal();
        const padding_h = widget.getPaddingVertical();
        return .{ .width = padding_w, .height = padding_h, .content_width = padding_w, .content_height = padding_h };
    }

    const children = widget.children.?.items;
    var total_w: i32 = widget.getPaddingHorizontal();
    var total_h: i32 = widget.getPaddingVertical();
    var content_w: i32 = widget.getPaddingHorizontal();
    var content_h: i32 = widget.getPaddingVertical();

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

            content_w += child_w;
            if (idx + 1 < children.len) {
                content_w += widget.gap;
            }
            max_h = @max(max_h, child_h);
        }
        content_h += max_h;

        // Viewport dimensions (constrained)
        total_w = @min(widget.width, content_w);
        total_h = @min(widget.height, content_h);
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

            content_h += child_h;
            if (idx + 1 < children.len) {
                content_h += widget.gap;
            }
            max_w = @max(max_w, child_w);
        }
        content_w += max_w;

        // Viewport dimensions (constrained)
        total_w = @min(widget.width, content_w);
        total_h = @min(widget.height, content_h);
    } else if (widget.orientation == .Stack) {
        var max_w: i32 = 0;
        var max_h: i32 = 0;
        for (children) |child| {
            var child_w = child.width;
            var child_h = child.height;
            if (child.widget_type == .Layout and (child_w == 0 or child_h == 0)) {
                const measured = measureLayout(child);
                if (child_w == 0) child_w = measured.width;
                if (child_h == 0) child_h = measured.height;
            }

            max_w = @max(max_w, child_w);
            max_h = @max(max_h, child_h);
        }
        content_w += max_w;
        content_h += max_h;

        // Viewport dimensions (constrained)
        total_w = @min(widget.width, content_w);
        total_h = @min(widget.height, content_h);
    }

    return .{ .width = total_w, .height = total_h, .content_width = content_w, .content_height = content_h };
}

pub fn layoutWidget(widget: *Widget, avail_w: i32, avail_h: i32) void {
    // Auto-size containers based on their children if width/height is -1 (auto-size)
    if (widget.widget_type == .Layout and widget.children != null) {
        if (widget.width < 0 or widget.height < 0) {
            const measured = measureLayout(widget);
            if (widget.width < 0) {
                widget.width = measured.content_width;
                if (!widget.is_parent) {
                    widget.desired_width = widget.width;
                }
            }
            if (widget.height < 0) {
                widget.height = measured.content_height;
                if (!widget.is_parent) {
                    widget.desired_height = widget.height;
                }
            }
        }
    }

    // For root widget, always use available dimensions
    var layout_w = if (avail_w > 0) avail_w else widget.width;
    var layout_h = if (avail_h > 0) avail_h else widget.height;

    // If this looks like a root widget (parent_guid is empty), force it to use available space
    if (widget.parent_guid.len == 0 and avail_w > 0 and avail_h > 0) {
        layout_w = avail_w;
        layout_h = avail_h;
    } else {
        // For child widgets: preserve desired size and only constrain if space is limited
        if (avail_w > 0) {
            if (widget.desired_width) |desired_w| {
                // Has explicit desired size - restore to it if space allows, otherwise constrain
                layout_w = @min(desired_w, avail_w);
            } else if (widget.width >= 0) {
                // No desired size but has explicit width - use it but can be constrained
                layout_w = @min(widget.width, avail_w);
            }
            // else: auto-sized, use widget.width (already set from measureLayout)
        }
        if (avail_h > 0) {
            if (widget.desired_height) |desired_h| {
                // Has explicit desired size - restore to it if space allows, otherwise constrain
                layout_h = @min(desired_h, avail_h);
            } else if (widget.height >= 0) {
                // No desired size but has explicit height - use it but can be constrained
                layout_h = @min(widget.height, avail_h);
            }
            // else: auto-sized, use widget.height (already set from measureLayout)
        }
    }

    // Only update widget dimensions if they don't have desired values
    // This preserves the original desired size for restoration when space is available
    if (widget.desired_width == null) {
        widget.width = layout_w;
    }
    if (widget.desired_height == null) {
        widget.height = layout_h;
    }

    // Store content dimensions for scrollable containers
    if (widget.widget_type == .Layout and widget.isScrollable()) {
        const measured = measureLayout(widget);
        widget.content_width = measured.content_width;
        widget.content_height = measured.content_height;

        // Clamp scroll offset to valid range
        if (widget.vertical_scroll_enabled or widget.scrollable) {
            const max_scroll_y = @max(0, widget.getScrollableContentHeight() - (layout_h - widget.getPaddingVertical()));
            if (widget.scroll_offset == null) {
                widget.scroll_offset = 0; // Start at top
            } else if (widget.scroll_offset.? > @as(usize, @intCast(max_scroll_y))) {
                widget.scroll_offset = @as(usize, @intCast(max_scroll_y));
            }
        }
        if (widget.horizontal_scroll_enabled) {
            // Horizontal scroll offset would need similar clamping when implemented
        }
    }

    const inner_w = layout_w - widget.getPaddingHorizontal();
    const inner_h = layout_h - widget.getPaddingVertical();

    if (widget.children == null) return;
    if (widget.children) |*children| {
        const child_count = children.items.len;
        if (child_count == 0) return;

        if (widget.widget_type == .Layout) {
            if (widget.orientation == .Row) {
                var cur_x: i32 = widget.getPaddingLeft();
                const scroll_x = @as(i32, @intCast(widget.scroll_offset orelse 0));

                for (children.items, 0..) |child, idx| {
                    const child_w = @min(child.width, inner_w);
                    const child_h = @min(child.height, inner_h);

                    // Apply scroll offset to child positioning
                    child.x = widget.x + cur_x - scroll_x;
                    child.y = widget.y + widget.getPaddingTop();

                    layoutWidget(child, child_w, child_h);

                    cur_x += child.width;
                    if (idx + 1 < child_count) {
                        cur_x += widget.gap;
                    }
                }
            } else if (widget.orientation == .Column) {
                var cur_y: i32 = widget.getPaddingTop();
                const scroll_y = @as(i32, @intCast(widget.scroll_offset orelse 0));

                for (children.items, 0..) |child, idx| {
                    const child_w = @min(child.width, inner_w);
                    const child_h = @min(child.height, inner_h);

                    child.x = widget.x + widget.getPaddingLeft();
                    // Apply scroll offset to child positioning
                    child.y = widget.y + cur_y - scroll_y;

                    layoutWidget(child, child_w, child_h);

                    cur_y += child.height;
                    if (idx + 1 < child_count) {
                        cur_y += widget.gap;
                    }
                }
            } else if (widget.orientation == .Stack) {
                for (children.items) |child| {
                    const child_w = @min(child.width, inner_w);
                    const child_h = @min(child.height, inner_h);

                    child.x = widget.x + widget.getPaddingLeft();
                    child.y = widget.y + widget.getPaddingTop();

                    layoutWidget(child, child_w, child_h);
                }
            }
        } else {
            for (children.items) |child| {
                child.x = widget.x + widget.getPaddingLeft();
                child.y = widget.y + widget.getPaddingTop();
                layoutWidget(child, child.width, child.height);
            }
        }
    }
}

pub fn create_shm_buffer(self: *ginwaGTK) ?*c.wl_buffer {
    // std.debug.print("create_shm_buffer\n", .{});
    const win_width: usize = @intCast(self.win_width);
    const win_height: usize = @intCast(self.win_height);

    // std.debug.print("win_width: {d}, win_height: {d}\n", .{ win_width, win_height });

    const stride: usize = win_width * 4;
    const size: usize = stride * win_height;
    const buf_w: usize = win_width;
    const buf_h: usize = win_height;
    const stride_u32: usize = @intCast(win_width);

    const fd = c.memfd_create("wl-buffer", 0);
    _ = c.ftruncate(fd, @intCast(size));

    const shm_data_void = c.mmap(null, size, c.PROT_READ | c.PROT_WRITE, c.MAP_SHARED, fd, 0);
    self.shm_data = @ptrCast(shm_data_void);

    if (self.shm == null) {
        std.log.err("No shm", .{});
    }

    if (fd < 0) {
        std.log.err("Failed to create shm", .{});
    }

    const pool = c.wl_shm_create_pool(self.shm, fd, @intCast(size));
    const buffer = c.wl_shm_pool_create_buffer(
        pool,
        0,
        @intCast(self.win_width),
        @intCast(self.win_height),
        @intCast(stride),
        c.WL_SHM_FORMAT_XRGB8888,
    );

    const pixels: [*]u32 = @ptrCast(@alignCast(self.shm_data));
    for (0..@intCast(self.win_width * self.win_height)) |i| {
        pixels[i] = 0xFF000000;
    }

    // std.debug.print("before layouting self.window: {s}\n", .{""});
    // debugger.printWidget(&self.window);

    // This will now properly maintain window size
    layoutWidget(&self.window, self.win_width, self.win_height);

    // std.debug.print("after layouting self.window: {s}\n", .{""});
    // debugger.printWidget(&self.window);

    renderWidget(&self.window, pixels, stride_u32, buf_w, buf_h, self);

    defer _ = c.wl_shm_pool_destroy(pool);
    defer _ = c.close(fd);
    defer _ = c.munmap(shm_data_void, size);

    return buffer;
}

// this method is for update ui and intensive in cpu, use it carefully
pub fn redraw(app: *ginwaGTK) void {
    const buffer = create_shm_buffer(app);
    defer c.wl_buffer_destroy(buffer);
    c.wl_surface_attach(app.surface, buffer, 0, 0);
    c.wl_surface_damage(app.surface, 0, 0, app.win_width, app.win_height);
    c.wl_surface_commit(app.surface);
}

pub fn renderEventLoop(app: *ginwaGTK) void {
    redraw(app);
    c.wl_surface_commit(app.surface);

    app.running = true;
    app.last_cursor_blink = utils.getNanoTime();

    // Event loop
    while (app.running) {
        // std.debug.print("Event loop time {d}\n", .{utils.getNanoTime()});
        // First, dispatch any pending events
        while (c.wl_display_prepare_read(app.display) != 0) {
            _ = c.wl_display_dispatch_pending(app.display);
        }

        _ = c.wl_display_flush(app.display);

        const current_time = utils.getNanoTime();
        const time_since_blink = current_time - app.last_cursor_blink;

        // Check if cursor needs to blink
        var should_blink = false;
        if (app.focused_widget) |widget| {
            if (widget.widget_type == .Input) {
                if (time_since_blink >= app.cursor_blink_interval) {
                    should_blink = true;
                }
            }
        }

        if (should_blink and app.key_repeat_active == false) {
            // std.debug.print("Blinking cursor\n", .{});
            // Cancel the read since we're going to redraw
            c.wl_display_cancel_read(app.display);

            app.cursor_visible = !app.cursor_visible;
            app.last_cursor_blink = current_time;

            // Redraw for cursor blink
            redraw(app);

            if (app.focused_widget) |widget| {
                c.wl_surface_damage(app.surface, widget.x, widget.y, widget.width, widget.height);
            }
            c.wl_surface_commit(app.surface);
        } else {
            if (app.key_repeat_active and app.keyboard_rate > 0) {
                const now = utils.getNanoTime();
                if (now >= app.next_key_repeat_time) {
                    if (app.pressed_key) |k| {
                        if (app.focused_widget) |fw| {
                            if (fw.widget_type == .Input) {
                                wk.handleInputKey(app, fw, k, app.shift_pressed, app.ctrl_pressed, app.allocator());

                                redraw(app);

                                // Schedule next repeat
                                const interval_ms = @divFloor(1000, app.keyboard_rate);
                                app.next_key_repeat_time = now + (interval_ms * 1_000_000);
                            }
                        }
                    }
                }
            }

            const fd = c.wl_display_get_fd(app.display);
            var poll_fd = std.os.linux.pollfd{
                .fd = fd,
                .events = std.os.linux.POLL.IN,
                .revents = 0,
            };

            // Calculate timeout until next blink
            var timeout_ms: i32 = 2; // Default 16ms
            if (app.focused_widget) |widget| {
                if (widget.widget_type == .Input) {
                    const remaining = app.cursor_blink_interval - time_since_blink;
                    timeout_ms = @intCast(@divFloor(remaining, 1_000_000));
                    if (timeout_ms < 1) timeout_ms = 1;
                }
            }

            const poll_result = std.os.linux.poll(@ptrCast(&poll_fd), 1, timeout_ms);

            if (poll_result > 0) {
                // Events are ready, read them
                _ = c.wl_display_read_events(app.display);
                _ = c.wl_display_dispatch_pending(app.display);
            } else {
                // Timeout or error, cancel the read
                c.wl_display_cancel_read(app.display);
            }
        }
    }
}

pub fn ensureCursorVisible(self: *Widget, widget_width: i32) void {
    const text = if (self.input_text.len > 0)
        self.input_text
    else if (self.placeholder.len > 0)
        self.placeholder
    else
        self.text;
    if (text.len == 0) {
        self.scroll_offset = 0; // Reset scroll when empty
        return;
    }

    // Create a temporary Cairo surface for text measurement
    const temp_width = 1;
    const temp_height = 1;
    const temp_stride = temp_width * 4;

    var temp_data: [4]u8 = undefined;
    const surface = c.cairo_image_surface_create_for_data(
        @ptrCast(&temp_data),
        c.CAIRO_FORMAT_ARGB32,
        temp_width,
        temp_height,
        temp_stride,
    );
    defer c.cairo_surface_destroy(surface);

    const cr = c.cairo_create(surface);
    defer c.cairo_destroy(cr);

    const layout = c.pango_cairo_create_layout(cr);
    defer c.g_object_unref(layout);

    c.pango_layout_set_text(layout, text.ptr, @as(i32, @intCast(text.len)));

    // Set font
    var font_buf: [128]u8 = undefined;
    const font_str_z = if (self.font_size > 0)
        std.fmt.bufPrintZ(&font_buf, "{s} {d}", .{ self.font_type, self.font_size }) catch "Sans 16"
    else
        std.fmt.bufPrintZ(&font_buf, "{s}", .{self.font_type}) catch "Sans";

    const font_desc = c.pango_font_description_from_string(font_str_z);
    defer c.pango_font_description_free(font_desc);

    c.pango_font_description_set_weight(font_desc, self.font_weight.toPangoWeight());
    c.pango_layout_set_font_description(layout, font_desc);

    // Get cursor position in pixels (relative to text start)
    var cursor_rect: c.PangoRectangle = undefined;
    _ = c.pango_layout_get_cursor_pos(layout, @as(i32, @intCast(self.cursor_position)), &cursor_rect, null);

    const cursor_pixel_x = @as(usize, @intCast(@divFloor(cursor_rect.x, c.PANGO_SCALE)));

    // Get total text width
    var ink_rect: c.PangoRectangle = undefined;
    var logical_rect: c.PangoRectangle = undefined;
    c.pango_layout_get_pixel_extents(layout, &ink_rect, &logical_rect);
    const text_width = @as(usize, @intCast(logical_rect.width));

    // Calculate visible area (accounting for padding)
    const available_width: usize = @intCast(@max(0, widget_width - self.getPaddingHorizontal()));

    // FIX: If total text is longer than available space, auto-scroll to show the end
    if (text_width > available_width) {
        // Scroll to show the end of the text (like HTML input)
        self.scroll_offset = text_width - available_width;
    } else {
        // Text fits - no scroll needed
        self.scroll_offset = 0;
    }

    // Also ensure cursor is visible (keep existing logic)
    const current_scroll = self.scroll_offset orelse 0;
    if (cursor_pixel_x < current_scroll) {
        self.scroll_offset = if (cursor_pixel_x < 50) 0 else cursor_pixel_x - 50;
    } else if (cursor_pixel_x > current_scroll + available_width) {
        self.scroll_offset = cursor_pixel_x - available_width + 50;
    }

    // Don't scroll past text end
    const final_scroll = self.scroll_offset orelse 0;
    if (final_scroll > text_width) {
        self.scroll_offset = text_width;
    }
}

pub fn decode_image(alloc: std.mem.Allocator, imagePath: []const u8) !w.DecodedImage {
    const file = try std.fs.cwd().openFile(imagePath, .{});
    defer file.close();

    const stat = try file.stat();
    const data = try file.readToEndAlloc(alloc, stat.size);

    var width: c_int = 0;
    var height: c_int = 0;
    var channels: c_int = 0;
    const pixels = c.stbi_load_from_memory(data.ptr, @intCast(data.len), &width, &height, &channels, 4);

    if (pixels == null) {
        std.debug.print("ERROR: stbi_load_from_memory failed for {s}\n", .{imagePath});
        return error.InvalidImageData;
    }

    std.debug.print("Image loaded: {}x{}, channels={}\n", .{ width, height, channels });

    return w.DecodedImage{ .width = @intCast(width), .height = @intCast(height), .rgba = pixels, .file_buffer = data, .file_path = imagePath };
}
