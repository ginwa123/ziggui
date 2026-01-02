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

    const app: *ginwaGTK = @ptrCast(@alignCast(data.?));

    app.key_repeat_active = false;
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
    // const KEY_CTRL = 29;
    const KEY_C = 46;
    const KEY_V = 47;

    const app: *ginwaGTK = @ptrCast(@alignCast(data.?));

    std.debug.print("Keyboard key: {d}, state: {d}\n", .{ key, state });

    // state 1 = pressed, 0 = released

    if (state == c.WL_KEYBOARD_KEY_STATE_PRESSED) {
        app.pressed_key = key;
        app.key_repeat_active = true;

        if (app.focused_widget) |widget| {
            if (widget.widget_type == .Input) {
                const now = utils.getNanoTime();
                const delay_ms = app.keyboard_delay * 1_000_000;
                app.next_key_repeat_time = now + delay_ms;

                // Copy text to clipboard
                if (app.ctrl_pressed and key == KEY_C and state == c.WL_KEYBOARD_KEY_STATE_PRESSED) {
                    if (widget.input_text.len > 0) {
                        const start_selection = @min(widget.selection_start.?, widget.selection_end.?);
                        const end_selection = @max(widget.selection_start.?, widget.selection_end.?);

                        const selection_text = widget.input_text[start_selection..end_selection];

                        if (app.clipboard_text) |text| {
                            app.allocator().free(text);
                        }

                        const clipboard_len = end_selection - start_selection;
                        const new_clipboard = app.allocator().alloc(u8, clipboard_len) catch return;
                        @memcpy(new_clipboard, selection_text);
                        app.clipboard_text = new_clipboard;

                        std.debug.print("Copied text to clipboard: {s}\n", .{selection_text});
                        wr.redraw(app);
                        return;
                    }
                }

                // Paste text from clipboard
                if (app.ctrl_pressed and key == KEY_V and state == c.WL_KEYBOARD_KEY_STATE_PRESSED) {
                    if (app.clipboard_text) |text| {
                        const has_selection = widget.selection_start != null and widget.selection_end != null;
                        if (has_selection) {
                            deleteSelection(widget, app.allocator());
                        }

                        for (text) |char| {
                            // Check maximum length constraint
                            const max_len = widget.max_input_text_length;
                            if (max_len > 0 and @as(i32, @intCast(widget.input_text.len)) >= max_len) {
                                break;
                            }
                            insertCharAtCursor(widget, char, app.allocator());
                        }
                        wr.redraw(app);
                        return;
                    }
                }

                handleInputKey(app, widget, key, app.shift_pressed, app.ctrl_pressed, app.allocator());

                // Trigger redraw
                wr.redraw(app);
            }
        }
    }

    if (state == c.WL_KEYBOARD_KEY_STATE_RELEASED) {
        app.key_repeat_active = false;
        app.pressed_key = null;
    }
}

fn validLetterKey(keycode: u32) u32 {
    const qwerty_codes = [_]u32{
        16, 17, 18, 19, 20, 21, 22, 23, 24, 25, // q-p
        30, 31, 32, 33, 34, 35, 36, 37, 38, // a-l
        44, 45, 46, 47, 48, 49, 50, // z-m
        12, 13, 26, 27, 39, 40, 41,
        43, 51, 52, 53,
    };

    for (qwerty_codes, 0..) |code, i| {
        _ = i;
        if (code == keycode) {
            return code;
        }
    }
    return 0;
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
    // const KEY_CTRL = 29;
    // const KEY_SHIFT = 42;
    const KEY_C = 46;
    const KEY_SPACE = 57;

    const truncated_key: u8 = @truncate(key);
    const result = validLetterKey(truncated_key);
    const is_letter = truncated_key == result;

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
    if (has_selection and
        ctrl_pressed == false and
        is_letter == true)
    {
        deleteSelection(widget, alloc);
    } else if (has_selection and
        ctrl_pressed == false and (KEY_BACKSPACE == key or
        KEY_DELETE == key or
        KEY_SPACE == key))
    {
        // If there's a selection and user types something (not arrow keys), delete selection first
        deleteSelection(widget, alloc);
    }

    std.debug.print("key: {d}\n", .{key});
    if (ctrl_pressed and key == KEY_C) {
        return;
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
        // Clamp cursor position to actual text length
        const safe_cursor_pos = @min(widget.cursor_position, widget.input_text.len);

        if (safe_cursor_pos > 0) {
            // Check minimum length constraint
            const min_len = @max(0, widget.min_input_text_length);
            if (@as(i32, @intCast(widget.input_text.len)) <= min_len) {
                // At minimum length, can't delete more
                return;
            }

            const new_text = alloc.alloc(u8, widget.input_text.len - 1) catch return;

            if (safe_cursor_pos > 1) {
                @memcpy(new_text[0 .. safe_cursor_pos - 1], widget.input_text[0 .. safe_cursor_pos - 1]);
            }

            if (safe_cursor_pos < widget.input_text.len) {
                @memcpy(new_text[safe_cursor_pos - 1 ..], widget.input_text[safe_cursor_pos..]);
            }

            alloc.free(widget.input_text);
            widget.input_text = new_text;
            widget.text = widget.input_text;
            widget.cursor_position = safe_cursor_pos - 1;
        }
    } else if (key == KEY_DELETE) {
        // Delete character at cursor
        // Clamp cursor position to actual text length
        const safe_cursor_pos = @min(widget.cursor_position, widget.input_text.len);

        if (safe_cursor_pos < widget.input_text.len) {
            // Check minimum length constraint
            const min_len = @max(0, widget.min_input_text_length);
            if (@as(i32, @intCast(widget.input_text.len)) <= min_len) {
                // At minimum length, can't delete more
                return;
            }

            const new_text = alloc.alloc(u8, widget.input_text.len - 1) catch return;

            if (safe_cursor_pos > 0) {
                @memcpy(new_text[0..safe_cursor_pos], widget.input_text[0..safe_cursor_pos]);
            }

            if (safe_cursor_pos + 1 < widget.input_text.len) {
                @memcpy(new_text[safe_cursor_pos..], widget.input_text[safe_cursor_pos + 1 ..]);
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
    // Clamp cursor position to actual text length
    // This handles the case where cursor is in a placeholder but input_text is empty
    const safe_cursor_pos = @min(widget.cursor_position, widget.input_text.len);

    const new_text = alloc.alloc(u8, widget.input_text.len + 1) catch return;

    // Copy text before cursor
    if (safe_cursor_pos > 0) {
        @memcpy(new_text[0..safe_cursor_pos], widget.input_text[0..safe_cursor_pos]);
    }

    // Insert new character
    new_text[safe_cursor_pos] = char;

    // Copy text after cursor
    if (safe_cursor_pos < widget.input_text.len) {
        @memcpy(new_text[safe_cursor_pos + 1 ..], widget.input_text[safe_cursor_pos..]);
    }

    if (widget.input_text.len > 0) {
        alloc.free(widget.input_text);
    }
    widget.input_text = new_text;
    widget.text = widget.input_text;
    widget.cursor_position = safe_cursor_pos + 1;
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
    _ = serial; // not used
    _ = mods_latched; // not used
    _ = group; // not used
    const app: *ginwaGTK = @ptrCast(@alignCast(data.?));

    // Wayland modifier masks
    const SHIFT_MASK = 0x1;
    const CTRL_MASK = 0x4;
    const ALT_MASK = 0x8;

    app.shift_pressed = (mods_depressed & SHIFT_MASK) != 0 or (mods_locked & SHIFT_MASK) != 0;
    app.ctrl_pressed = (mods_depressed & CTRL_MASK) != 0;
    app.alt_pressed = (mods_depressed & ALT_MASK) != 0;

    std.debug.print("keyboard_modifiers: shift: {}, ctrl: {}, alt: {}\n", .{ app.shift_pressed, app.ctrl_pressed, app.alt_pressed });
}

pub const keyboard_listener = c.wl_keyboard_listener{
    .keymap = keyboard_keymap,
    .enter = keyboard_enter,
    .leave = keyboard_leave,
    .key = keyboard_key,
    .modifiers = keyboard_modifiers,
    .repeat_info = keyboard_repeat_info,
};
