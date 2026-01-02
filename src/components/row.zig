const std = @import("std");
const w = @import("../widget.zig");
const random = @import("../random.zig");
const Widget = w.Widget;
const Orientation = w.Orientation;

pub const PropsRow = struct {
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

pub fn c_row(alloc: std.mem.Allocator, props: PropsRow) !*Widget {
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
