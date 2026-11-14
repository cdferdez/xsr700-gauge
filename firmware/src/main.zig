const std = @import("std");
const core = @import("core");

// Zig 0.17: `main` receives an `Init` bundle (allocators, args, and the `io`
// interface used for files/stdout). Older tutorials use a different signature.
pub fn main(init: std.process.Init) !void {
    _ = init; // not needed yet
    std.debug.print("XSR700 gauge (core v{s})\n", .{core.version});
}

test "core is importable" {
    try std.testing.expectEqualStrings("0.1.0", core.version);
}
