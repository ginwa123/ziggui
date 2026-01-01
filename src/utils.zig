const std = @import("std");

pub fn getNanoTime() i64 {
    var ts: std.os.linux.timespec = undefined;
    _ = std.os.linux.clock_gettime(std.os.linux.CLOCK.MONOTONIC, &ts);
    return @as(i64, ts.sec) * 1_000_000_000 + @as(i64, ts.nsec);
}
