const std = @import("std");
const utils = @import("utils.zig");

const w = @import("widget.zig");
const wr = @import("widget_render.zig");
const c = w.c;
const ginwaGTK = w.ginwaGTK;
const Widget = w.Widget;

fn pointer_enter(
    data: ?*anyopaque,
    pointer: ?*c.struct_wl_pointer,
    serial: u32,
    surface: ?*c.struct_wl_surface,
    surface_x: c.wl_fixed_t,
    surface_y: c.wl_fixed_t,
) callconv(.c) void {
    _ = pointer;
    _ = surface;
    const app: *ginwaGTK = @ptrCast(@alignCast(data.?));
    app.last_serial = serial;

    std.debug.print("Pointer ENTER surface at ({d:.1}, {d:.1})\n", .{
        c.wl_fixed_to_double(surface_x),
        c.wl_fixed_to_double(surface_y),
    });
}

fn pointer_leave(
    data: ?*anyopaque,
    pointer: ?*c.struct_wl_pointer,
    serial: u32,
    surface: ?*c.struct_wl_surface,
) callconv(.c) void {
    _ = pointer;
    _ = surface;
    std.debug.print("Pointer LEAVE surface\n", .{});
    const app: *ginwaGTK = @ptrCast(@alignCast(data.?));

    app.last_serial = serial;
    if (app.hovered_widget) |hovered_widget| {
        hovered_widget.backround_is_hovered = false;
        app.hovered_widget = null;
        wr.redraw(app);
    }
}

fn pointer_motion(
    data: ?*anyopaque,
    pointer: ?*c.struct_wl_pointer,
    time: u32,
    surface_x: c.wl_fixed_t,
    surface_y: c.wl_fixed_t,
) callconv(.c) void {
    _ = pointer;
    _ = time;
    std.debug.print("Pointer motion: ({d:.1}, {d:.1})\n", .{
        c.wl_fixed_to_double(surface_x),
        c.wl_fixed_to_double(surface_y),
    });

    const app: *ginwaGTK = @ptrCast(@alignCast(data.?));

    app.pointer_x = c.wl_fixed_to_double(surface_x);
    app.pointer_y = c.wl_fixed_to_double(surface_y);

    // Handle scrollbar dragging
    if (w.findWidgetAt(&app.window, app.pointer_x, app.pointer_y)) |clicked_widget| {
        var scrollable_widget = findScrollableAncestor(clicked_widget) orelse clicked_widget;

        if (scrollable_widget.is_dragging_scrollbar) {
            const drag_delta = @as(i32, @intFromFloat(app.pointer_y)) - scrollable_widget.scrollbar_drag_start;
            const content_h = scrollable_widget.getScrollableContentHeight();
            const viewport_h = scrollable_widget.height - scrollable_widget.getPaddingVertical();
            const max_scroll = @max(0, content_h - viewport_h);

            // Calculate scrollbar thumb movement ratio
            const scrollbar_track_h = viewport_h - scrollable_widget.scrollbar_width;
            const scroll_ratio = if (scrollbar_track_h > 0)
                @as(f64, @floatFromInt(drag_delta)) / @as(f64, @floatFromInt(scrollbar_track_h))
            else
                0.0;

            const new_scroll = @as(i32, @intFromFloat(scroll_ratio * @as(f64, @floatFromInt(max_scroll))));
            const clamped_scroll = @max(0, @min(new_scroll, max_scroll));

            scrollable_widget.scroll_offset = scrollable_widget.scrollbar_drag_start_offset + @as(usize, @intCast(clamped_scroll));
            std.debug.print("Dragging scroll: delta={d}, new_offset={d}\n", .{ drag_delta, scrollable_widget.scroll_offset orelse 0 });
            wr.redraw(app);
        }
    }

    if (app.mouse_dragging) {
        if (app.mouse_drag_start_widget) |drag_widget| {
            if (drag_widget.widget_type == .Input) {
                calculateCursorPositionFromMouse(drag_widget, app.pointer_x, app.pointer_y);

                if (drag_widget.selection_anchor == null) {
                    drag_widget.selection_anchor = drag_widget.cursor_position;
                }

                const anchor = drag_widget.selection_anchor.?;
                drag_widget.selection_start = @min(anchor, drag_widget.cursor_position);
                drag_widget.selection_end = @max(anchor, drag_widget.cursor_position);

                wr.redraw(app);
            }
        }
    }

    // handle hover
    // const previous_hovered_widget = app.hovered_widget;
    // if (previous_hovered_widget) |prev| {}

    const previous_hovered_widget = app.hovered_widget;
    app.hovered_widget = w.findWidgetAt(&app.window, app.pointer_x, app.pointer_y);

    if (previous_hovered_widget) |prev| {
        if (app.hovered_widget) |hovered_widget| {
            if (prev != hovered_widget) {
                prev.backround_is_hovered = false;
                wr.redraw(app);
            }
        }
    }

    if (app.hovered_widget) |hovered_widget| {
        std.debug.print("Hover widget: {s}\n", .{hovered_widget.name});
        hovered_widget.backround_is_hovered = true;

        if (hovered_widget.background_hover_color) |hover_color| {
            _ = hover_color;
            wr.redraw(app);
        }

        set_cursor_for_widget(app, hovered_widget, app.last_serial);
    }
}

fn calculateCursorPositionFromMouse(widget: *Widget, mouse_x: f64, mouse_y: f64) void {
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

    // Use same text as displayed
    const display_text = if (widget.input_text.len > 0)
        widget.input_text
    else if (widget.placeholder.len > 0)
        widget.placeholder
    else
        widget.text;

    c.pango_layout_set_text(layout, display_text.ptr, @as(i32, @intCast(display_text.len)));

    // Set same font as widget
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

    // Calculate relative mouse position within the widget
    const text_x = @as(f64, @floatFromInt(widget.x + widget.getPaddingLeft()));
    const text_y = @as(f64, @floatFromInt(widget.y + widget.getPaddingTop()));

    // Account for scroll offset when calculating relative position
    const scroll_amount = widget.scroll_offset orelse 0;
    const relative_x = mouse_x - text_x + @as(f64, @floatFromInt(scroll_amount));
    const relative_y = mouse_y - text_y;

    // Convert to Pango units
    const pango_x = @as(i32, @intFromFloat(relative_x * @as(f64, @floatFromInt(c.PANGO_SCALE))));
    const pango_y = @as(i32, @intFromFloat(relative_y * @as(f64, @floatFromInt(c.PANGO_SCALE))));

    // Get the character index at this position
    var index: i32 = 0;
    var trailing: i32 = 0;
    _ = c.pango_layout_xy_to_index(layout, pango_x, pango_y, &index, &trailing);

    // Set cursor position
    // index is byte position, we need to handle UTF-8 properly
    var cursor_pos: usize = @intCast(index);

    // If trailing is set, move cursor after the character
    if (trailing > 0) {
        cursor_pos += @intCast(trailing);
    }

    // Clamp to valid range
    if (cursor_pos > display_text.len) {
        cursor_pos = display_text.len;
    }

    widget.cursor_position = cursor_pos;
}

fn pointer_button(
    data: ?*anyopaque,
    pointer: ?*c.wl_pointer,
    serial: u32,
    time: u32,
    button: u32,
    state: u32,
) callconv(.c) void {
    _ = pointer;
    _ = time;

    const app: *ginwaGTK = @ptrCast(@alignCast(data.?));
    const now = utils.getNanoTime();

    app.last_serial = serial;

    if (state == c.WL_POINTER_BUTTON_STATE_PRESSED) {
        if (button == 0x110) { // left click
            const previous_focus = app.focused_widget;

            if (w.findWidgetAt(&app.window, app.pointer_x, app.pointer_y)) |clicked_widget| {
                std.debug.print("Clicked on widget: {s}\n", .{clicked_widget.name});

                // Handle scrollbar drag
                var scrollable_widget = findScrollableAncestor(clicked_widget) orelse clicked_widget;

                if (scrollable_widget.isPointOnVerticalScrollbar(app.pointer_x, app.pointer_y)) {
                    if (scrollable_widget.isPointOnVerticalScrollbarThumb(app.pointer_x, app.pointer_y)) {
                        // Start dragging the scrollbar thumb
                        scrollable_widget.is_dragging_scrollbar = true;
                        scrollable_widget.scrollbar_drag_start = @as(i32, @intFromFloat(app.pointer_y));
                        scrollable_widget.scrollbar_drag_start_offset = scrollable_widget.scroll_offset orelse 0;
                        std.debug.print("Started scrolling drag\n", .{});
                    } else {
                        // Click on scrollbar track - jump to position
                        const content_h = scrollable_widget.getScrollableContentHeight();
                        const viewport_h = scrollable_widget.height - scrollable_widget.getPaddingVertical();
                        const scrollbar_h = viewport_h;

                        const scrollbar_y = scrollable_widget.y + scrollable_widget.getPaddingTop();
                        const click_ratio = @as(f64, @floatFromInt(@as(i32, @intFromFloat(app.pointer_y)) - scrollbar_y)) / @as(f64, @floatFromInt(scrollbar_h));
                        const max_scroll = @max(0, content_h - viewport_h);
                        const new_scroll = @as(i32, @intFromFloat(click_ratio * @as(f64, @floatFromInt(max_scroll))));

                        scrollable_widget.scroll_offset = @as(usize, @intCast(@max(0, new_scroll)));
                        std.debug.print("Jumped scroll to {d}\n", .{scrollable_widget.scroll_offset orelse 0});
                        wr.redraw(app);
                    }
                    return; // Don't process as regular click
                }

                // Check if clicked on eye icon of a password input
                if (clicked_widget.widget_type == .Input and
                    clicked_widget.input_text_type == .Password)
                {

                    // Calculate eye icon bounds
                    const icon_size: i32 = 16;
                    const icon_padding: i32 = 10;
                    const icon_x = clicked_widget.x + clicked_widget.width - icon_size - icon_padding;
                    const icon_y = clicked_widget.y + @divTrunc(clicked_widget.height - icon_size, 2);
                    const icon_x2 = icon_x + icon_size;
                    const icon_y2 = icon_y + icon_size;

                    // Check if click is within eye icon bounds
                    if (app.pointer_x >= @as(f64, @floatFromInt(icon_x)) and
                        app.pointer_x <= @as(f64, @floatFromInt(icon_x2)) and
                        app.pointer_y >= @as(f64, @floatFromInt(icon_y)) and
                        app.pointer_y <= @as(f64, @floatFromInt(icon_y2)))
                    {

                        // Toggle password visibility
                        clicked_widget.password_visible = !clicked_widget.password_visible;
                        std.debug.print("Password visibility toggled: {}\n", .{clicked_widget.password_visible});
                        wr.redraw(app);
                        return; // Don't trigger input focus when clicking eye icon
                    }
                }

                if (clicked_widget.widget_type == .Input) {
                    app.focused_widget = clicked_widget;
                    app.cursor_visible = true;
                    app.last_cursor_blink = utils.getNanoTime();

                    const click_interval = now - app.mouse_last_click_time;
                    const is_quick_click = click_interval < app.mouse_quick_clink_interval;
                    const is_same_widget = app.mouse_last_click_widget == clicked_widget;

                    if (is_quick_click and is_same_widget) {
                        app.mouse_click_count += 1;
                    } else {
                        app.mouse_click_count = 1;
                    }

                    app.mouse_last_click_time = now;
                    app.mouse_last_click_widget = clicked_widget;

                    // Calculate cursor position from mouse click
                    calculateCursorPositionFromMouse(clicked_widget, app.pointer_x, app.pointer_y);

                    // Clear selection when clicking
                    clicked_widget.selection_start = null;
                    clicked_widget.selection_end = null;

                    // handle click type
                    if (app.mouse_click_count == 1) {
                        clicked_widget.selection_start = null;
                        clicked_widget.selection_end = null;
                        clicked_widget.selection_anchor = clicked_widget.cursor_position;
                    } else if (app.mouse_click_count >= 2) {
                        selectWordAtCursor(clicked_widget);
                    }

                    app.mouse_dragging = true;
                    app.mouse_drag_start_widget = clicked_widget;
                    app.mouse_drag_start_x = app.pointer_x;
                    app.mouse_drag_start_y = app.pointer_y;

                    // wr.redraw(app);

                    std.debug.print("Input focused: {s}, cursor at: {}\n", .{ clicked_widget.name, clicked_widget.cursor_position });
                } else if (clicked_widget.widget_type == .Button) {
                    clicked_widget.on_click_backgroud_is_hovered = true;
                    app.mouse_dragging = false;
                    app.mouse_drag_start_widget = null;
                    app.mouse_click_count = 0;

                    // redraw ui to show the change
                    wr.redraw(app);
                } else {
                    app.focused_widget = null;
                    app.mouse_dragging = false;
                    app.mouse_drag_start_widget = null;
                    app.mouse_click_count = 0;
                }

                clicked_widget.trigger_click();
            } else {
                app.focused_widget = null;
            }

            // If focus changed, redraw to show/hide cursor
            if (previous_focus != app.focused_widget) {
                // wr.redraw(app);
            }
        }
    } else if (state == c.WL_POINTER_BUTTON_STATE_RELEASED) {
        if (button == 0x110) { // left click
            // Stop scrollbar dragging if active
            if (w.findWidgetAt(&app.window, app.pointer_x, app.pointer_y)) |clicked_widget| {
                var scrollable_widget = findScrollableAncestor(clicked_widget) orelse clicked_widget;
                if (scrollable_widget.is_dragging_scrollbar) {
                    scrollable_widget.is_dragging_scrollbar = false;
                    std.debug.print("Stopped scrolling drag\n", .{});
                }
            }

            app.mouse_dragging = false;
            app.mouse_drag_start_widget = null;

            if (w.findWidgetAt(&app.window, app.pointer_x, app.pointer_y)) |clicked_widget| {
                clicked_widget.on_click_backgroud_is_hovered = false;
            }
        }
    }

    wr.redraw(app);
}

fn selectWordAtCursor(widget: *Widget) void {
    const text = widget.input_text;
    const cursor = widget.cursor_position;

    // Return early if text is empty
    if (text.len == 0) {
        widget.selection_start = null;
        widget.selection_end = null;
        widget.selection_anchor = null;
        return;
    }

    // Find start of word (whitespace or punctuation before)
    var word_start = cursor;
    while (word_start > 0) {
        const prev_char = text[word_start - 1];
        if (prev_char == ' ' or prev_char == '\t' or prev_char == '\n' or prev_char == ',' or prev_char == '.' or prev_char == ';' or prev_char == ':' or prev_char == '!' or prev_char == '?' or prev_char == '(' or prev_char == ')' or prev_char == '"' or prev_char == '\'' or prev_char == '[' or prev_char == ']' or prev_char == '{' or prev_char == '}') {
            break;
        }
        word_start -= 1;
    }

    // Find end of word
    var word_end = cursor;
    while (word_end < text.len) {
        const char = text[word_end];
        if (char == ' ' or char == '\t' or char == '\n' or char == ',' or char == '.' or char == ';' or char == ':' or char == '!' or char == '?' or char == '(' or char == ')' or char == '"' or char == '\'' or char == '[' or char == ']' or char == '{' or char == '}') {
            break;
        }
        word_end += 1;
    }

    // Select the word
    widget.selection_start = word_start;
    widget.selection_end = word_end;
    widget.selection_anchor = word_start;
    widget.cursor_position = word_end;
}

fn pointer_frame(data: ?*anyopaque, pointer: ?*c.struct_wl_pointer) callconv(.c) void {
    _ = data;
    _ = pointer;
}

fn findScrollableAncestor(widget: *Widget) ?*Widget {
    var current = widget;
    while (current.parent) |parent| {
        if (parent.vertical_scroll_enabled or parent.scrollable) {
            return parent;
        }
        current = parent;
    }
    return null;
}

fn pointer_axis(
    data: ?*anyopaque,
    pointer: ?*c.struct_wl_pointer,
    time: u32,
    axis: u32,
    value: c.wl_fixed_t,
) callconv(.c) void {
    _ = pointer;
    _ = time;

    const app: *ginwaGTK = @ptrCast(@alignCast(data.?));

    // Find the widget under cursor
    if (w.findWidgetAt(&app.window, app.pointer_x, app.pointer_y)) |target_widget| {
        // Find parent scrollable container
        const scrollable_widget = findScrollableAncestor(target_widget) orelse target_widget;

        // Handle vertical scrolling
        if (axis == c.WL_POINTER_AXIS_VERTICAL_SCROLL) {
            const scroll_amount = @divFloor(value, 10); // Smaller divisor = faster scroll
            const current_scroll = scrollable_widget.scroll_offset orelse 0;
            const new_scroll = @max(0, @as(i32, @intCast(current_scroll)) + scroll_amount);

            const max_scroll = @max(0, scrollable_widget.getScrollableContentHeight() - (scrollable_widget.height - scrollable_widget.getPaddingVertical()));
            scrollable_widget.scroll_offset = @min(@as(usize, @intCast(new_scroll)), @as(usize, @intCast(max_scroll)));

            wr.redraw(app);
        }
    }
}

fn set_cursor_for_widget(app: *ginwaGTK, widget: *Widget, serial: u32) void {
    var cursor_name: [*c]const u8 = "left_ptr";

    if (widget.widget_type == .Button) {
        cursor_name = "hand1";
    }

    if (widget.widget_type == .Text) {
        cursor_name = "left_ptr";
    }

    if (widget.widget_type == .Layout) {
        cursor_name = "left_ptr";
    }

    if (widget.widget_type == .Input) {
        cursor_name = "xterm";
    }

    if (app.wl_pointer) |pointer| {
        if (app.cursor_theme) |cursor_theme| {
            const cursor = c.wl_cursor_theme_get_cursor(cursor_theme, cursor_name);
            const image = cursor.*.images[0];

            // const buffer = c.wl_cursor_image_get_buffer(image);
            const hotspot_x: i32 = @intCast(image.*.hotspot_x);
            const hotspot_y: i32 = @intCast(image.*.hotspot_y);

            const buffer = c.wl_cursor_image_get_buffer(image);

            const image_width: i32 = @intCast(image.*.width);
            const image_height: i32 = @intCast(image.*.height);
            c.wl_surface_damage(app.cursor_surface, 0, 0, image_width, image_height);

            c.wl_surface_attach(app.cursor_surface, buffer, 0, 0);
            c.wl_surface_commit(app.cursor_surface);

            c.wl_pointer_set_cursor(pointer, serial, app.cursor_surface, hotspot_x, hotspot_y);
        }
    }
}

pub const pointer_listener = c.struct_wl_pointer_listener{
    .enter = pointer_enter,
    .leave = pointer_leave,
    .motion = pointer_motion,
    .button = pointer_button,
    .axis = pointer_axis,
    .frame = pointer_frame,
};
