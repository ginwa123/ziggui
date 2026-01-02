const std = @import("std");
const w = @import("../widget.zig");
const random = @import("../random.zig");
const Widget = w.Widget;
const Orientation = w.Orientation;

pub const PropsContainer = struct {
    name: []const u8 = "",
    width: i32 = 0,
    height: i32 = 0,
    text: []const u8 = "",
    background_color: u32 = 0x00000000, // Transparent by default
    orientation: Orientation = .Row,
    gap: i32 = 0,
    padding: i32 = 0,
    border_color: ?u32 = null,
    border_width: ?i32 = 0,
    border_radius: i32 = 0,
};

pub fn build(props: PropsContainer) !*Widget {
    const allocator = w.default_allocator;
    const widget = try allocator.create(Widget);
    widget.* = .{
        .guid = try random.randomId(allocator),
        .name = props.name,
        .width = props.width,
        .height = props.height,
        .widget_type = .Layout,
        .background_color = props.background_color,
        .gap = props.gap,
        .border_color = props.border_color,
        .border_width = props.border_width,
        .border_radius = props.border_radius,
        .orientation = props.orientation,
    };

    return widget;
}
