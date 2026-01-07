const std = @import("std");

const w = @import("widget.zig");

pub fn printWidget(widget: *w.Widget) void {
    std.debug.print("Widget:\n", .{});
    std.debug.print("  guid: {s}\n", .{widget.guid}); // Ubah {any} jadi {s}
    std.debug.print("  parent_guid: {s}\n", .{widget.parent_guid}); // Ubah {any} jadi {s}
    std.debug.print("  id: {s}\n", .{widget.id}); // Ubah {any} jadi {s}
    std.debug.print("  text: {s}\n", .{widget.text}); // Ubah {} jadi {s}
    std.debug.print("  font_size: {}\n", .{widget.font_size});
    std.debug.print("  font_type: {s}\n", .{widget.font_type}); // Ubah {any} jadi {s}
    std.debug.print("  font_allignment: {any}\n", .{widget.font_alignment});
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
        for (children.items) |child| {
            printWidget(child);
        }
    }
    std.debug.print("\n", .{});
}
