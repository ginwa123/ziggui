const std = @import("std");

const w = @import("widget.zig");

// pub const Widget = struct {
//     guid: []const u8 = "",
//     parent_guid: []const u8 = "",
//     name: []const u8 = "",
//     orientation: ?Orientation = null,
//
//     gap: i32 = 0,
//     children: ?std.ArrayList(*Widget) = null,
//
//     widget_type: WidgetType = .Layout,
//
//     x: i32 = 0,
//     y: i32 = 0,
//     width: i32 = 0,
//     height: i32 = 0,
//     padding: i32 = 0,
//     text: []const u8 = "",
//     font_size: i32 = 11,
//     font_type: [*:0]const u8 = "Arial",
//     font_allignment: FontAllignment = .Left,
//     background_color: u32 = 0xFF333333,
//     border_radius: i32 = 0,
//     border_color: ?u32 = null,
//     border_width: ?i32 = 0,
//
//     on_click: ?*const fn (*Widget, ?*anyopaque) void = null,
//     click_data: ?*anyopaque = null,
//
//     allocator: std.mem.Allocator,
//
//     pub fn onClick(self: *Widget, comptime callback: anytype, data: ?*anyopaque) *Widget {
//         const S = struct {
//             fn wrapper(w: *Widget, d: ?*anyopaque) void {
//                 _ = w;
//                 @call(.auto, callback, .{d});
//             }
//         };
//         self.on_click = S.wrapper;
//         self.click_data = data;
//         return self;
//     }
//
//     pub fn add_children(self: *Widget, allocator: std.mem.Allocator, child: *Widget) !void {
//         if (self.children == null) {
//             std.debug.print("self.children == null\n", .{});
//             self.children = .empty;
//         }
//
//         std.debug.print("child: {any}\n", .{child});
//         child.parent_guid = self.guid;
//         try self.children.?.append(allocator, child);
//     }
//
//     pub fn deinit(self: *Widget) void {
//         if (self.children) |*list| {
//             for (list.items) |child| {
//                 child.deinit();
//                 self.allocator.destroy(child);
//             }
//             list.deinit();
//         }
//     }
// };
//
pub fn printWidget(widget: *w.Widget) void {
    std.debug.print("Widget:\n", .{});
    std.debug.print("  guid: {s}\n", .{widget.guid});  // Ubah {any} jadi {s}
    std.debug.print("  parent_guid: {s}\n", .{widget.parent_guid});  // Ubah {any} jadi {s}
    std.debug.print("  name: {s}\n", .{widget.name});  // Ubah {any} jadi {s}
    std.debug.print("  text: {s}\n", .{widget.text});  // Ubah {} jadi {s}
    std.debug.print("  font_size: {}\n", .{widget.font_size});
    std.debug.print("  font_type: {s}\n", .{widget.font_type});  // Ubah {any} jadi {s}
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
