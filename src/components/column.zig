const std = @import("std");
const w = @import("../widget.zig");
const random = @import("../random.zig");
const Widget = w.Widget;
const Orientation = w.Orientation;

pub const PropwColumn = struct {
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

pub fn build(alloc: std.mem.Allocator, props: PropwColumn) !*Widget {
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
