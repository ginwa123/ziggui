const std = @import("std");
const w = @import("../widget.zig");
const random = @import("../random.zig");
const Widget = w.Widget;

pub const PropsButton = struct {
    name: []const u8 = "",
    width: i32 = 120,
    height: i32 = 30,
    label: []const u8 = "",
    background_color: u32 = 0xFF333333,
    border_color: ?u32 = null,
    border_width: ?i32 = 0,
    border_radius: i32 = 0,
    padding: i32 = 8,
};

pub fn build( props: PropsButton) !*Widget {
    const allocator = w.default_allocator;
    const widget = try allocator.create(Widget);
    widget.* = .{ .guid = try random.randomId(allocator), .name = props.name, .width = props.width, .height = props.height, .text = props.label, .widget_type = .Button, .background_color = props.background_color, .border_color = props.border_color, .border_width = props.border_width, .border_radius = props.border_radius };

    widget.padding = props.padding;

    return widget;
}
