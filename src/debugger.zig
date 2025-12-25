const std = @import("std");

const w = @import("widget.zig");

pub fn printWidget(widget: *w.Widget) void {
    std.debug.print("Widget:\n", .{});
    std.debug.print("  guid: {any}\n", .{widget.guid});
    std.debug.print("  parent_guid: {any}\n", .{widget.parent_guid});
    std.debug.print("  name: {any}\n", .{widget.name});
    std.debug.print("  text: {any}\n", .{widget.text});
    std.debug.print("  font_size: {}\n", .{widget.font_size});
    std.debug.print("  font_type: {any}\n", .{widget.font_type});
    std.debug.print("  font_allignment: {any}\n", .{widget.font_allignment});
    std.debug.print("  border_radius: {}\n", .{widget.border_radius});
    std.debug.print("  border_color: {?}\n", .{widget.border_color});
    std.debug.print("  border_width: {?}\n", .{widget.border_width});
    std.debug.print("  type: {any}\n", .{widget.widget_type});
    std.debug.print("  x: {}, y: {}\n", .{ widget.x, widget.y });
    std.debug.print("  width: {}, height: {}\n", .{ widget.width, widget.height });
    std.debug.print("  background_color: {}\n", .{widget.background_color});
    std.debug.print("  gap: {}\n", .{widget.gap});
    std.debug.print("  padding: {}\n", .{widget.padding});
    std.debug.print("  orientation: {any}\n", .{widget.orientation});
    std.debug.print("  children count: {}\n", .{if (widget.children) |children| children.items.len else 0});

    // Print children recursively
    if (widget.children) |children| {
        std.debug.print("  Children:\n", .{});
        for (children.items) |child| { // child sudah bertipe Widget
            printWidget(child); // Ambil address of child
        }
    }

    std.debug.print("\n", .{});
}
