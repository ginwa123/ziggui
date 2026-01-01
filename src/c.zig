// import library from C;
pub const c = @cImport({
    @cDefine("_GNU_SOURCE", "");
    @cInclude("wayland-client.h");
    @cInclude("wayland-cursor.h");
    @cInclude("xdg-shell-client-protocol.h");
    @cInclude("sys/mman.h");
    @cInclude("unistd.h");
    @cInclude("linux/input.h");
    @cInclude("sys/eventfd.h");
    @cInclude("cairo.h");
    @cInclude("pango/pango.h");
    @cInclude("pango/pangocairo.h");
});

