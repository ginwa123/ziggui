

const std = @import("std");
const w = @import("../widget.zig");
const wr = @import("../widget_render.zig");
const random = @import("../random.zig");
const Widget = w.Widget;


// Input component constructor
pub const PropsIcon = struct {
    name: []const u8 = "",
    width: i32 = 32,
    height: i32 = 32,
    background_color: u32 = 0x00000000,
    src_image: []const u8 = "",
};

pub fn build(props: PropsIcon) !*Widget {
    const alloc = w.default_allocator;
    const widget = try alloc.create(Widget);

    widget.* = .{
        .guid = try random.randomId(alloc),
        .id = props.name,
        .width = props.width,
        .height = props.height,
        .desired_width = if (props.width >= 0) props.width else null,
        .desired_height = if (props.height >= 0) props.height else null,
        .widget_type = .Icon,
        .font_alignment = .CenterLeft,
        .background_color = props.background_color,
    };

    // Load the PNG image if src_image is provided
    if (props.src_image.len > 0) {
        std.debug.print("Loading icon from: {s}\n", .{props.src_image});
        const decoded_image = try wr.decode_image(alloc, props.src_image);
        if (decoded_image.rgba == null) {
            std.debug.print("ERROR: Failed to load image\n", .{});
            return error.ImageLoadFailed;
        }
        std.debug.print("Image loaded: {}x{}\n", .{ decoded_image.width, decoded_image.height });
        widget.image = try alloc.create(w.DecodedImage);
        widget.image.?.* = decoded_image;
        widget.image.?.file_path = props.src_image;
    }

    return widget;
}
