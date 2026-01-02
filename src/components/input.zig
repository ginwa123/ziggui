const std = @import("std");
const w = @import("../widget.zig");
const random = @import("../random.zig");
const Widget = w.Widget;
const ginwaGTK = w.ginwaGTK;


// Input component constructor
pub const PropsInput = struct {
    name: []const u8 = "",
    width: i32 = 200,
    height: i32 = 30,
    placeholder: []const u8 = "",
    background_color: u32 = 0xFF222222,
    border_color: ?u32 = 0xFF555555,
    border_width: ?i32 = 0,
    border_radius: i32 = 0,
    padding: i32 = 0,
    font_size: i32 = 14,
    font_color: u32 = 0xFFFFFFFF,
    max_input_text_length: i32 = 0,
    min_input_text_length: i32 = 0,
};

pub fn build(props: PropsInput) !*Widget {
    const allocator = w.default_allocator;
    const widget = try allocator.create(Widget);

    // Initialize empty input text
    const initial_text = try allocator.alloc(u8, 0);

    widget.* = .{
        .guid = try random.randomId(allocator),
        .name = props.name,
        .width = props.width,
        .height = props.height,
        .input_text = initial_text,
        .placeholder = props.placeholder,
        .widget_type = .Input,
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
