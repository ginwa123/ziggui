const std = @import("std");
const w = @import("../widget.zig");
const random = @import("../random.zig");
const Widget = w.Widget;


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
    max_input_text_length: i32 = 0,
    min_input_text_length: i32 = 0,
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
        .placeholder = props.placeholder,
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
        .max_input_text_length = props.max_input_text_length,
        .min_input_text_length = props.min_input_text_length,
    };

    return widget;
}
