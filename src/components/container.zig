const std = @import("std");
const w = @import("../widget.zig");
const random = @import("../random.zig");
const Widget = w.Widget;
const Orientation = w.Orientation;
const LayoutAlignment = w.LayoutAlignment;

pub const PropsContainer = struct {
    name: []const u8 = "",
    width: i32 = -1,  // -1 means auto-size based on children
    height: i32 = -1, // -1 means auto-size based on children
    text: []const u8 = "",
    background_color: u32 = 0x00000000, // Transparent by default
    orientation: Orientation = .Row,
    gap: i32 = 0,
    horizontal_alignment: ?LayoutAlignment = null,
    vertical_alignment: ?LayoutAlignment = null,
    padding: i32 = 0,
    border_color: ?u32 = null,
    border_width: ?i32 = 0,
    border_radius: i32 = 0,
    scrollable: bool = false,
    scrollbar_width: i32 = 12,
};

pub fn build(props: PropsContainer) !*Widget {
    const allocator = w.default_allocator;
    const widget = try allocator.create(Widget);
    widget.* = .{
        .guid = try random.randomId(allocator),
        .name = props.name,
        .width = props.width,
        .height = props.height,
        .desired_width = if (props.width >= 0) props.width else null,
        .desired_height = if (props.height >= 0) props.height else null,
        .widget_type = .Layout,
        .background_color = props.background_color,
        .gap = props.gap,
        .border_color = props.border_color,
        .border_width = props.border_width,
        .border_radius = props.border_radius,
        .orientation = props.orientation,
        .scrollable = props.scrollable,
        .scrollbar_width = props.scrollbar_width,
        .vertical_scroll_enabled = props.scrollable,
        .horizontal_alignment = props.horizontal_alignment,
        .vertical_alignment = props.vertical_alignment,
    };

    return widget;
}
