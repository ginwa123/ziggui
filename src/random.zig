const std = @import("std");

pub fn randomId(alloc: std.mem.Allocator) ![]u8 {
    var v: u64 = undefined;
    std.crypto.random.bytes(std.mem.asBytes(&v));
    return try std.fmt.allocPrint(alloc, "w-{x}", .{v});
}
