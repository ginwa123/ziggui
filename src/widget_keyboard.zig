const std = @import("std");
const utils = @import("utils.zig");

const w = @import("widget.zig");
const wr = @import("widget_render.zig");
const c = w.c;
const ginwaGTK = w.ginwaGTK;
const Widget = w.Widget;

const BACKSPACE_KEY = 14;

fn keyboard_repeat_info(
    data: ?*anyopaque,
    keyboard: ?*c.wl_keyboard,
    rate: i32,
    delay: i32,
) callconv(.c) void {
    _ = keyboard;

    const app: *ginwaGTK = @ptrCast(@alignCast(data.?));
    app.keyboard_delay = delay;
    app.keyboard_rate = rate;
    std.debug.print("Keyboard repeat rate: {d}, delay: {d}\n", .{ rate, delay });
}

fn keyboard_keymap(
    data: ?*anyopaque,
    keyboard: ?*c.wl_keyboard,
    format: u32,
    fd: i32,
    size: u32,
) callconv(.c) void {
    _ = data;
    _ = keyboard;
    _ = format;
    _ = size;
    _ = c.close(fd);
}

fn keyboard_enter(
    data: ?*anyopaque,
    keyboard: ?*c.wl_keyboard,
    serial: u32,
    surface: ?*c.wl_surface,
    keys: ?*c.wl_array,
) callconv(.c) void {
    _ = keyboard;
    _ = serial;
    _ = surface;
    _ = keys;
    _ = data;
    std.debug.print("Keyboard focus gained\n", .{});
}

fn keyboard_leave(
    data: ?*anyopaque,
    keyboard: ?*c.wl_keyboard,
    serial: u32,
    surface: ?*c.wl_surface,
) callconv(.c) void {
    _ = keyboard;
    _ = serial;
    _ = surface;
    _ = data;
    std.debug.print("Keyboard focus lost\n", .{});
}

fn keyboard_key(
    data: ?*anyopaque,
    keyboard: ?*c.wl_keyboard,
    serial: u32,
    time: u32,
    key: u32,
    state: u32,
) callconv(.c) void {
    _ = keyboard;
    _ = serial;
    _ = time;

    const app: *ginwaGTK = @ptrCast(@alignCast(data.?));

    std.debug.print("Keyboard key: {d}, state: {d}\n", .{ key, state });

    // state 1 = pressed, 0 = released

    if (state == c.WL_KEYBOARD_KEY_STATE_PRESSED) {
        app.pressed_key = key;
        app.key_repeat_active = true;

        if (app.focused_widget) |widget| {
            if (widget.widget_type == .Input) {
                handleInputKey(app, widget, key, app.shift_pressed, app.ctrl_pressed, app.allocator());

                // Trigger redraw
                wr.redraw(app);

                const now = utils.getNanoTime();
                const delay_ms = app.keyboard_delay * 1_000_000;
                app.next_key_repeat_time = now + delay_ms;
            }
        }
    }

    if (state == c.WL_KEYBOARD_KEY_STATE_RELEASED) {
        app.key_repeat_active = false;
        app.pressed_key = null;
    }
}

// this is keycode to char for linux only
fn keycodeToChar(keycode: u32, shift_pressed: bool) ?u8 {
    // Letters (a-z / A-Z)
    const qwerty_lower = "qwertyuiopasdfghjklzxcvbnm";
    const qwerty_codes = [_]u32{
        16, 17, 18, 19, 20, 21, 22, 23, 24, 25, // q-p
        30, 31, 32, 33, 34, 35, 36, 37, 38, // a-l
        44, 45, 46, 47, 48, 49, 50, // z-m
    };

    for (qwerty_codes, 0..) |code, i| {
        if (code == keycode) {
            const char = qwerty_lower[i];
            return if (shift_pressed) char - 32 else char; // uppercase
        }
    }

    // Numbers (1-0) and shift symbols (!@#$%^&*())
    if (keycode >= 2 and keycode <= 11) {
        if (shift_pressed) {
            const symbols = "!@#$%^&*()";
            return symbols[keycode - 2];
        }
        return if (keycode == 11) '0' else @as(u8, @intCast(keycode - 2 + '1'));
    }

    // Space
    if (keycode == 57) return ' ';

    // Punctuation and symbols
    return switch (keycode) {
        12 => if (shift_pressed) '_' else '-',
        13 => if (shift_pressed) '+' else '=',
        26 => if (shift_pressed) '{' else '[',
        27 => if (shift_pressed) '}' else ']',
        39 => if (shift_pressed) ':' else ';',
        40 => if (shift_pressed) '"' else '\'',
        41 => if (shift_pressed) '~' else '`',
        43 => if (shift_pressed) '|' else '\\',
        51 => if (shift_pressed) '<' else ',',
        52 => if (shift_pressed) '>' else '.',
        53 => if (shift_pressed) '?' else '/',
        else => null,
    };
}

pub fn handleInputKey(app: *ginwaGTK, widget: *Widget, key: u32, shift_pressed: bool, ctrl_pressed: bool, alloc: std.mem.Allocator) void {
    const KEY_BACKSPACE = 14;
    const KEY_ENTER = 28;
    const KEY_LEFT = 105; // Arrow left
    const KEY_RIGHT = 106; // Arrow right
    const KEY_HOME = 102; // Home key
    const KEY_END = 107; // End key
    const KEY_DELETE = 111; // Delete key
    const KEY_A = 30; // A key for Ctrl+A
    const KEY_CTRL = 29;
    const KEY_SHIFT = 42;

    // const is_char = keycodeToChar(key, app.shift_pressed) != null;

    // Handle Ctrl+A for select all
    if (ctrl_pressed and key == KEY_A) {
        if (widget.input_text.len > 0) {
            widget.selection_start = 0;
            widget.selection_end = widget.input_text.len;
            widget.cursor_position = widget.input_text.len;
            std.debug.print("Select all: 0-{}\n", .{widget.input_text.len});
        }
        // Ensure cursor is visible after select all
        wr.ensureCursorVisible(widget, widget.width);
        return;
    }

    // If there's a selection and user types something (not arrow keys), delete selection first
    const has_selection = widget.selection_start != null and widget.selection_end != null;
    if (has_selection and key != KEY_LEFT and key != KEY_RIGHT and key != KEY_HOME and key != KEY_END and key != KEY_SHIFT and key != KEY_CTRL) {
        deleteSelection(widget, alloc);
    }

    const previous_anchor = widget.cursor_position;
    if (key == KEY_LEFT) {
        if (widget.cursor_position > 0) {
            widget.cursor_position -= 1;
        }

        if (app.shift_pressed) {
            if (widget.selection_anchor == null) {
                widget.selection_anchor = previous_anchor;
            }
            const anchor = widget.selection_anchor.?;
            widget.selection_start = @min(anchor, widget.cursor_position);
            widget.selection_end = @max(anchor, widget.cursor_position);
        } else {
            widget.selection_start = null;
            widget.selection_end = null;
            widget.selection_anchor = null;
        }
    } else if (key == KEY_RIGHT) {
        if (widget.cursor_position < widget.input_text.len) {
            widget.cursor_position += 1;
        }

        if (app.shift_pressed) {
            if (widget.selection_anchor == null) {
                widget.selection_anchor = previous_anchor;
            }
            const anchor = widget.selection_anchor.?;
            widget.selection_start = @min(anchor, widget.cursor_position);
            widget.selection_end = @max(anchor, widget.cursor_position);
        } else {
            widget.selection_start = null;
            widget.selection_end = null;
            widget.selection_anchor = null;
        }
    } else if (key == KEY_HOME) {
        // Clear selection and move to start
        widget.selection_start = null;
        widget.selection_end = null;
        widget.cursor_position = 0;
    } else if (key == KEY_END) {
        // Clear selection and move to end
        widget.selection_start = null;
        widget.selection_end = null;
        widget.cursor_position = widget.input_text.len;
    } else if (key == KEY_BACKSPACE) {
        // Delete character before cursor (selection already deleted above if exists)
        if (widget.cursor_position > 0) {
            // Check minimum length constraint
            const min_len = @max(0, widget.min_input_text_length);
            if (@as(i32, @intCast(widget.input_text.len)) <= min_len) {
                // At minimum length, can't delete more
                return;
            }

            const new_text = alloc.alloc(u8, widget.input_text.len - 1) catch return;

            if (widget.cursor_position > 1) {
                @memcpy(new_text[0 .. widget.cursor_position - 1], widget.input_text[0 .. widget.cursor_position - 1]);
            }

            if (widget.cursor_position < widget.input_text.len) {
                @memcpy(new_text[widget.cursor_position - 1 ..], widget.input_text[widget.cursor_position..]);
            }

            alloc.free(widget.input_text);
            widget.input_text = new_text;
            widget.text = widget.input_text;
            widget.cursor_position -= 1;
        }
    } else if (key == KEY_DELETE) {
        // Delete character at cursor
        if (widget.cursor_position < widget.input_text.len) {
            // Check minimum length constraint
            const min_len = @max(0, widget.min_input_text_length);
            if (@as(i32, @intCast(widget.input_text.len)) <= min_len) {
                // At minimum length, can't delete more
                return;
            }

            const new_text = alloc.alloc(u8, widget.input_text.len - 1) catch return;

            if (widget.cursor_position > 0) {
                @memcpy(new_text[0..widget.cursor_position], widget.input_text[0..widget.cursor_position]);
            }

            if (widget.cursor_position + 1 < widget.input_text.len) {
                @memcpy(new_text[widget.cursor_position..], widget.input_text[widget.cursor_position + 1 ..]);
            }

            alloc.free(widget.input_text);
            widget.input_text = new_text;
            widget.text = widget.input_text;
        }
    } else if (key == KEY_ENTER) {
        std.debug.print("Input submitted: {s}\n", .{widget.input_text});
    } else {
        // Insert character at cursor position
        if (keycodeToChar(key, shift_pressed)) |char| {
            // Check maximum length constraint
            const max_len = widget.max_input_text_length;
            if (max_len > 0 and @as(i32, @intCast(widget.input_text.len)) >= max_len) {
                // At maximum length, can't add more
                return;
            }
            insertCharAtCursor(widget, char, alloc);
        }
    }

    // Ensure cursor is visible after any operation
    wr.ensureCursorVisible(widget, widget.width);
}

fn deleteSelection(widget: *Widget, alloc: std.mem.Allocator) void {
    if (widget.selection_start == null or widget.selection_end == null) return;

    const start = @min(widget.selection_start.?, widget.selection_end.?);
    const end = @max(widget.selection_start.?, widget.selection_end.?);

    if (start == end) {
        widget.selection_start = null;
        widget.selection_end = null;
        return;
    }

    const new_len = widget.input_text.len - (end - start);

    // Check minimum length constraint
    const min_len = @max(0, widget.min_input_text_length);
    if (@as(i32, @intCast(new_len)) < min_len) {
        // Can't delete selection as it would go below minimum length
        widget.selection_start = null;
        widget.selection_end = null;
        return;
    }

    if (new_len == 0) {
        if (widget.input_text.len > 0) {
            alloc.free(widget.input_text);
        }
        widget.input_text = "";
        widget.text = "";
        widget.cursor_position = 0;
    } else {
        const new_text = alloc.alloc(u8, new_len) catch return;

        // Copy text before selection
        if (start > 0) {
            @memcpy(new_text[0..start], widget.input_text[0..start]);
        }

        // Copy text after selection
        if (end < widget.input_text.len) {
            @memcpy(new_text[start..], widget.input_text[end..]);
        }

        alloc.free(widget.input_text);
        widget.input_text = new_text;
        widget.text = widget.input_text;
        widget.cursor_position = start;
    }

    widget.selection_start = null;
    widget.selection_end = null;
}

fn insertCharAtCursor(widget: *Widget, char: u8, alloc: std.mem.Allocator) void {
    const new_text = alloc.alloc(u8, widget.input_text.len + 1) catch return;

    // Copy text before cursor
    if (widget.cursor_position > 0) {
        @memcpy(new_text[0..widget.cursor_position], widget.input_text[0..widget.cursor_position]);
    }

    // Insert new character
    new_text[widget.cursor_position] = char;

    // Copy text after cursor
    if (widget.cursor_position < widget.input_text.len) {
        @memcpy(new_text[widget.cursor_position + 1 ..], widget.input_text[widget.cursor_position..]);
    }

    if (widget.input_text.len > 0) {
        alloc.free(widget.input_text);
    }
    widget.input_text = new_text;
    widget.text = widget.input_text;
    widget.cursor_position += 1;
}

fn appendChar(widget: *Widget, char: u8, alloc: std.mem.Allocator) void {
    const new_text = alloc.alloc(u8, widget.input_text.len + 1) catch return;
    if (widget.input_text.len > 0) {
        @memcpy(new_text[0..widget.input_text.len], widget.input_text);
    }
    new_text[widget.input_text.len] = char;

    if (widget.input_text.len > 0) {
        alloc.free(widget.input_text);
    }
    widget.input_text = new_text;
    widget.text = widget.input_text;
}

fn keyboard_modifiers(
    data: ?*anyopaque,
    keyboard: ?*c.wl_keyboard,
    serial: u32,
    mods_depressed: u32,
    mods_latched: u32,
    mods_locked: u32,
    group: u32,
) callconv(.c) void {
    _ = keyboard;
    _ = serial;
    _ = mods_latched;
    _ = group;

    const app: *ginwaGTK = @ptrCast(@alignCast(data.?));

    // Wayland modifier masks
    const SHIFT_MASK = 0x1;
    const CTRL_MASK = 0x4;
    const ALT_MASK = 0x8;

    app.shift_pressed = (mods_depressed & SHIFT_MASK) != 0 or (mods_locked & SHIFT_MASK) != 0;
    app.ctrl_pressed = (mods_depressed & CTRL_MASK) != 0;
    app.alt_pressed = (mods_depressed & ALT_MASK) != 0;
}

pub const keyboard_listener = c.wl_keyboard_listener{
    .keymap = keyboard_keymap,
    .enter = keyboard_enter,
    .leave = keyboard_leave,
    .key = keyboard_key,
    .modifiers = keyboard_modifiers,
    .repeat_info = keyboard_repeat_info,
};
