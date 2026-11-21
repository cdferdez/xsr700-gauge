const std = @import("std");
const core = @import("core");

pub fn main(init: std.process.Init) !void {
    _ = init;
    std.debug.print("XSR700 gauge (core v{s})\n", .{core.version});
}

test "core is importable" {
    try std.testing.expectEqualStrings("0.1.0", core.version);
}
