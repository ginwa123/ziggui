// import library from C;
pub const c = @cImport({
    @cDefine("_GNU_SOURCE", "");

    // linux wayland compositor
    @cInclude("wayland-client.h");
    @cInclude("wayland-cursor.h");

    @cInclude("xdg-shell-client-protocol.h");
    @cInclude("sys/mman.h");
    @cInclude("unistd.h");
    @cInclude("linux/input.h");
    @cInclude("sys/eventfd.h");

    // render text
    @cInclude("cairo.h");
    @cInclude("pango/pango.h");
    @cInclude("pango/pangocairo.h");

    // render icon
    @cDefine("STB_IMAGE_IMPLEMENTATION", "");
    @cDefine("STBI_NO_SIMD", "");
    @cDefine("STBI_NO_GIF", "");
    @cDefine("STBI_NO_PSD", "");
    @cDefine("STBI_NO_TGA", "");
    @cDefine("STBI_NO_HDR", "");
    @cDefine("STBI_NO_BMP", "");
    @cDefine("STBI_NO_PIC", "");
    @cInclude("stb_image.h");
});
