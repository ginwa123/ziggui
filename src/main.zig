const std = @import("std");
const image_viewer_with_gui_toolkit_co = @import("image_viewer_with_gui_toolkit_co");

const Widget = @import("widget.zig").Widget;
const Orientation = @import("widget.zig").Orientation;
const ui = @import("widget.zig");
const c = @import("c.zig").c;
const ginwaGTK = @import("widget.zig").ginwaGTK;

const button = @import("components/button.zig");
const input = @import("components/input.zig");
const text = @import("components/text.zig");
const container = @import("components/container.zig");
const icon = @import("components/icon.zig");

fn myButtonCallback(widget: *Widget, data: ?*anyopaque) void {
    _ = widget;
    _ = data;
}

fn onInputTextChange(input_text: []const u8, data: ?*anyopaque) void {
    _ = data;

    std.debug.print("onInputTextChange: {s}\n", .{input_text});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alllocator = gpa.allocator();

    const uiToolkit = try alllocator.create(ui.ginwaGTK);
    uiToolkit.* = .{
        .window = .{
            .widget_type = .Layout,
            .orientation = .Column,
            .background_color = 0xFF333333,
            .padding = 8,
            .gap = 8,
            .scrollable = true,
            .is_parent = true,
        },
    };

    var tk = try ui.init(alllocator, uiToolkit);
    defer tk.free();

    const row_icon = try container.build(.{
        .id = "row",
        // .background_color = 0xFF00FF00,
        .gap = 8,
        .orientation = .Row,
    });
    const icon1 = try icon.build(.{ .name = "icon1", .src_image = "assets/signing_903481.png", .width = 21, .height = 21 });

    _ = try row_icon.add_children(.{icon1});
    _ = try tk.window.add_child(row_icon);

    const longListColumn = try container.build(.{
        .id = "longListColumn",
        .padding = 8,
        .gap = 8,
        .orientation = .Column,
        .scrollable = true,
        .width = 300,
        .height = 200,
    });

    const textLongList1 = try text.build(.{ .name = "text", .text = "long list 1", .width = 100 });
    const textLongList2 = try text.build(.{ .name = "text", .text = "long list 2", .width = 100 });
    const textLongList3 = try text.build(.{ .name = "text", .text = "long list 3", .width = 100 });
    const textLongList4 = try text.build(.{ .name = "text", .text = "long list 4", .width = 100 });
    const textLongList5 = try text.build(.{ .name = "text", .text = "long list 5", .width = 100 });
    const textLongList6 = try text.build(.{ .name = "text", .text = "long list 6", .width = 100 });
    const textLongList7 = try text.build(.{ .name = "text", .text = "long list 7", .width = 100 });
    const textLongList8 = try text.build(.{ .name = "text", .text = "long list 8", .width = 100 });
    const textLongList9 = try text.build(.{ .name = "text", .text = "long list 9", .width = 100 });

    _ = try longListColumn.add_children(.{ textLongList1, textLongList2, textLongList3, textLongList4, textLongList5, textLongList6, textLongList7, textLongList8, textLongList9 });

    _ = try tk.window.add_child(longListColumn);

    const inputText = "init input text";
    const inputUsername = try input.build(.{
        .name = "inputUsername",
        .max_input_text_length = 255,
        .placeholder = "username",
        .padding = 8,
        .input_text_type = .Text,
        .input_text = inputText,
    });

    inputUsername.on_input_text_change = onInputTextChange;

    const inputPassword = try input.build(.{ .name = "inputPassword", .max_input_text_length = 255, .placeholder = "password", .padding = 8, .input_text_type = .Password });

    const columnLogin = try container.build(.{
        .id = "columnLogin",
        .padding = 8,
        .gap = 8,
        .orientation = .Row,
    });
    _ = try columnLogin.add_children(.{ inputUsername, inputPassword });
    _ = try tk.window.add_child(columnLogin);

    const input1 = try input.build(.{
        .name = "input",
        .max_input_text_length = 255,
        .placeholder = "placeholder",
        .padding = 8,
    });

    const rowCombineText = try container.build(.{
        .id = "row",
        .background_color = 0xFF00FF00,
        .gap = 8,
        .orientation = .Row,
    });

    const text1 = try text.build(.{ .name = "text", .text = "its just a text", .width = 100 });

    const btnHoverOnCLick = try button.build(.{
        .name = "text",
        .label = "TOmbol",
        .on_click_hover_color = 0xFF00FF00,
    });

    const input3 = try input.build(.{
        .name = "input",
        .width = 100,
    });

    _ = try rowCombineText.add_children(.{ text1, btnHoverOnCLick, input3 });

    _ = try tk.window.add_children(
        .{ input1, rowCombineText },
    );

    const btn1 = try button.build(
        .{ .name = "label1", .width = 100, .height = 100, .background_color = 0xFF1A1A1A, .label = "label1", .padding = 8, .background_hover_color = 0xFF0000FF },
    );
    btn1.on_click = myButtonCallback;
    _ = try tk.window.add_child(btn1);
    //
    const btn2 = try button.build(
        .{ .name = "button1", .background_color = 0xFF3488FF, .label = "Gambar" },
    );

    _ = try tk.window.add_child(btn2);

    const btn3 = try button.build(
        .{
            .name = "button1",
            // green
            .background_color = 0xFF00FF00,
            .label = "label3",
        },
    );

    _ = try tk.window.add_child(btn3);

    const rowwww = try container.build(.{ .id = "column1", .padding = 8, .gap = 14, .orientation = .Row });

    const btnColumn11 = try button.build(
        .{ .name = "button1", .background_color = 0xFFFF7F00, .label = "orange", .border_radius = 8 },
    );
    _ = try rowwww.add_child(btnColumn11);
    //
    const btnColumn12 = try button.build(
        .{
            .name = "button1",
            .background_color = 0xFFFFFF2D,
            .label = "label2",
        },
    );
    _ = try rowwww.add_child(btnColumn12);

    const btnColumn13 = try button.build(
        .{
            .name = "button1",
            .background_color = 0xFFFFFF2D,
            .label = "label2",
        },
    );
    _ = try rowwww.add_child(btnColumn13);

    _ = try tk.window.add_child(rowwww);

    // Test Stack orientation - children will overlap each other
    const stackContainer = try container.build(.{
        .id = "stack",
        .padding = 8,
        .gap = 8,
        .orientation = .Stack,
        .background_color = 0xFF800080, // Purple background
        .width = 200,
        .height = 150,
    });

    const stackBtn1 = try button.build(
        .{ .name = "stack-btn-1", .background_color = 0xFFFF0000, .label = "Bottom", .width = 180, .height = 130 },
    );
    const stackBtn2 = try button.build(
        .{ .name = "stack-btn-2", .background_color = 0xFF00FF00, .label = "Middle", .width = 160, .height = 110 },
    );
    const stackBtn3 = try button.build(
        .{ .name = "stack-btn-3", .background_color = 0xFF0000FF, .label = "Top", .width = 140, .height = 90 },
    );

    _ = try stackContainer.add_children(.{ stackBtn1, stackBtn2, stackBtn3 });
    _ = try tk.window.add_child(stackContainer);

    // Test Row orientation with horizontal alignment - Center
    const rowCenterAlign = try container.build(.{
        .id = "rowCenterAlign",
        .padding = 8,
        .gap = 8,
        .orientation = .Row,
        .background_color = 0xFF444444,
        .width = tk.win_width,
        .height = 60,
        .horizontal_alignment = .Center,
        .vertical_alignment = .Center,
    });
    const centerBtn1 = try button.build(.{ .name = "center-btn-1", .label = "Button 1", .width = 80, .height = 40 });
    const centerBtn2 = try button.build(.{ .name = "center-btn-2", .label = "Button 2", .width = 80, .height = 40 });
    const centerBtn3 = try button.build(.{ .name = "center-btn-3", .label = "Button 3", .width = 80, .height = 40 });
    _ = try rowCenterAlign.add_children(.{ centerBtn1, centerBtn2, centerBtn3 });
    _ = try tk.window.add_child(rowCenterAlign);

    // Test Row orientation with SpaceBetween alignment
    const rowSpaceBetween = try container.build(.{
        .id = "rowSpaceBetween",
        .padding = 8,
        .orientation = .Row,
        .background_color = 0xFF666666,
        .width = 300,
        .height = 60,
        .horizontal_alignment = .SpaceBetween,
        .vertical_alignment = .Center,
    });
    const spaceBtn1 = try button.build(.{ .name = "space-btn-1", .label = "A", .width = 60, .height = 40 });
    const spaceBtn2 = try button.build(.{ .name = "space-btn-2", .label = "B", .width = 60, .height = 40 });
    const spaceBtn3 = try button.build(.{ .name = "space-btn-3", .label = "C", .width = 60, .height = 40 });
    _ = try rowSpaceBetween.add_children(.{ spaceBtn1, spaceBtn2, spaceBtn3 });
    _ = try tk.window.add_child(rowSpaceBetween);

    // Test Column orientation with vertical alignment - End
    const columnEndAlign = try container.build(.{
        .id = "columnEndAlign",
        .padding = 8,
        .gap = 8,
        .orientation = .Column,
        .background_color = 0xFF888888,
        .width = 250,
        .height = 150,
        .horizontal_alignment = .End,
        .vertical_alignment = .SpaceAround,
        .scrollable = true,
    });
    const colBtn1 = try button.build(.{ .name = "col-btn-1", .label = "Item 1", .width = 120, .height = 30 });
    const colBtn2 = try button.build(.{ .name = "col-btn-2", .label = "Item 2", .width = 120, .height = 30 });
    const colBtn3 = try button.build(.{ .name = "col-btn-3", .label = "Item 3", .width = 120, .height = 30 });
    _ = try columnEndAlign.add_children(.{ colBtn1, colBtn2, colBtn3 });
    _ = try tk.window.add_child(columnEndAlign);

    // Test Column orientation with SpaceEvenly alignment
    const columnSpaceEvenly = try container.build(.{
        .id = "columnSpaceEvenly",
        .padding = 8,
        .orientation = .Column,
        .background_color = 0xFFAAAAAA,
        .width = 200,
        .height = 150,
        .horizontal_alignment = .Center,
        .vertical_alignment = .SpaceEvenly,
        .scrollable = true,
    });
    const evenBtn1 = try button.build(.{ .name = "even-btn-1", .label = "One", .width = 100, .height = 30 });
    const evenBtn2 = try button.build(.{ .name = "even-btn-2", .label = "Two", .width = 100, .height = 30 });
    const evenBtn3 = try button.build(.{ .name = "even-btn-3", .label = "Three", .width = 100, .height = 30 });
    _ = try columnSpaceEvenly.add_children(.{ evenBtn1, evenBtn2, evenBtn3 });
    _ = try tk.window.add_child(columnSpaceEvenly);



    tk.event_loop_callback = struct {
        // This callback will be called every time the event loop is called
        // You can use this to update the UI based on the current state of the app
        fn callback(app: *ginwaGTK) void {
            if (app.find_widget_by_id("rowCenterAlign")) |widget_row_center_align| {
                widget_row_center_align.width = app.win_width;
            }
        }
    }.callback;

    try tk.event_loop(); // Run the event loop

    std.debug.print("App closed!\n", .{});
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
