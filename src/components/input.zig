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
    padding_left: ?i32 = null,
    padding_right: ?i32 = null,
    padding_top: ?i32 = null,
    padding_bottom: ?i32 = null,
    font_size: i32 = 14,
    font_color: u32 = 0xFFFFFFFF,
    max_input_text_length: i32 = 0,
    min_input_text_length: i32 = 0,
    input_text: []const u8 = "",
    input_text_type: ?w.InputTextType = null,
};

pub fn build(props: PropsInput) !*Widget {
    const allocator = w.default_allocator;
    const widget = try allocator.create(Widget);

    // Allocate and duplicate input text so we own the memory
    const input_text = if (props.input_text.len > 0)
        try allocator.dupe(u8, props.input_text)
    else
        "";

    widget.* = .{
        .guid = try random.randomId(allocator),
        .name = props.name,
        .width = props.width,
        .height = props.height,
        .input_text = input_text,
        .input_text_type = props.input_text_type,
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
        .padding_left = props.padding_left,
        .padding_right = props.padding_right,
        .padding_top = props.padding_top,
        .padding_bottom = props.padding_bottom,
    };

    return widget;
}
