const std = @import("std");
const core = @import("core");

const profile = core.profile;

pub fn main(init: std.process.Init) !void {
    _ = init;

    var reader = core.frame_reader.FrameReader(profile.protocol){};
    var store = core.signal_store.SignalStore{ .detector = profile.detector, .stale_after_ms = profile.stale_after_ms };

    const frame = profile.protocol.withChecksum(.{ 54, 48, 0, 120 });
    for (frame ++ frame ++ frame) |byte| {
        const decoded = reader.push(byte) orelse continue;
        for (profile.protocol.readings(decoded, profile.scaling)) |r| store.apply(r, 0);
    }

    const s = store.state(0);
    std.debug.print("XSR700 gauge (core v{s})\n", .{core.version});
    std.debug.print("rpm={?d} mph={?d:.1} gear={?d} coolant={?d}F\n", .{ s.rpm, s.speed_mph, s.gear, s.coolant_f });
}

test "core is importable" {
    try std.testing.expectEqualStrings("0.1.0", core.version);
}
