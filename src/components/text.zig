

const std = @import("std");
const w = @import("../widget.zig");
const random = @import("../random.zig");
const Widget = w.Widget;


// Input component constructor
pub const PropsText = struct {
    name: []const u8 = "",
    width: i32 = 200,
    height: i32 = 30,
    font_size: i32 = 14,
    font_color: u32 = 0xFFFFFFFF,
    text: []const u8 = "",
    background_color: u32 = 0x00000000, // Transparent by default
};

pub fn build(props: PropsText) !*Widget {
    const alloc = w.default_allocator;
    const widget = try alloc.create(Widget);

    // Initialize empty input text
    widget.* = .{
        .guid = try random.randomId(alloc),
        .name = props.name,
        .width = props.width,
        .height = props.height,
        .desired_width = if (props.width >= 0) props.width else null,
        .desired_height = if (props.height >= 0) props.height else null,
        .text = props.text,
        .widget_type = .Text,
        .font_size = props.font_size,
        .font_color = props.font_color,
        .font_alignment = .CenterLeft,
        .background_color = props.background_color, // Use transparent background from props
    };

    return widget;
}
