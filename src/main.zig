const std = @import("std");
const image_viewer_with_gui_toolkit_co = @import("image_viewer_with_gui_toolkit_co");

const Widget = @import("widget.zig").Widget;
const Orientation = @import("widget.zig").Orientation;
const ui = @import("widget.zig");
const c = @import("c.zig").c;

fn myButtonCallback(widget: *Widget, data: ?*anyopaque) void {
    _ = widget;
    _ = data;
}

pub fn main() !void {
    var uiToolkit: ui.ginwaGTK = .{
        .win_title = "ginwaGTK",
    };
    defer uiToolkit.free();

    const allocator = uiToolkit.allocator();
    std.debug.print("Init!\n", .{});
    var tk = uiToolkit.init();

    tk.window = .{ .allocator = allocator };
    tk.window.guid = "root";
    tk.window.children = null;
    tk.window.name = "parent_widget";
    tk.window.orientation = .Column;
    tk.window.widget_type = .Layout;
    tk.window.padding = 8;
    tk.window.gap = 8;

    const input = try ui.c_input(tk.window.allocator, .{
        .name = "input",
    });
    _ = try tk.window.add_children(input);

    const btn1 = try ui.c_btn(
        tk.window.allocator,
        .{ .name = "label1", .width = 100, .height = 100, .background_color = 0xFF1A1A1A, .label = "label1", .padding = 8 },
    );
    btn1.on_click = myButtonCallback;
    _ = try tk.window.add_children(btn1);
    //
    const btn2 = try ui.c_btn(
        tk.window.allocator,
        .{ .name = "button1", .background_color = 0xFF3488FF, .label = "Gambar" },
    );

    _ = try tk.window.add_children(btn2);

    const btn3 = try ui.c_btn(
        tk.window.allocator,
        .{
            .name = "button1",
            // green
            .background_color = 0xFF00FF00,
            .label = "label3",
        },
    );

    _ = try tk.window.add_children(btn3);

    const rowwww = try ui.c_row(tk.window.allocator, .{ .name = "column1", .padding = 8, .background_color = 0xFF1A1A1A, .gap = 14 });

    const btnColumn11 = try ui.c_btn(
        tk.window.allocator,
        .{ .name = "button1", .background_color = 0xFFFF7F00, .label = "orange", .border_radius = 8 },
    );
    _ = try rowwww.add_children(btnColumn11);
    //
    const btnColumn12 = try ui.c_btn(
        uiToolkit.allocator(),
        .{
            .name = "button1",
            .background_color = 0xFFFFFF2D,
            .label = "label2",
        },
    );
    _ = try rowwww.add_children(btnColumn12);

    const btnColumn13 = try ui.c_btn(
        uiToolkit.allocator(),
        .{
            .name = "button1",
            .background_color = 0xFFFFFF2D,
            .label = "label2",
        },
    );
    _ = try rowwww.add_children(btnColumn13);

    _ = try tk.window.add_children(rowwww);
    // const new_buffer = tk.create_shm_buffer();
    // defer c.wl_buffer_destroy(new_buffer);
    // c.wl_surface_attach(tk.surface, new_buffer, 0, 0);
    // c.wl_surface_damage(tk.surface, 0, 0, tk.win_width, tk.win_height);
    // c.wl_surface_commit(tk.surface);

    std.debug.print("Event loop!\n", .{});
    try uiToolkit.event_loop();
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
