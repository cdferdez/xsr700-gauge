const std = @import("std");
const profile = @import("profile.zig");
const FrameReader = @import("frame_reader.zig").FrameReader;
const SignalStore = @import("signal_store.zig").SignalStore;

const testing = std.testing;

test "bytes become display state through the profile" {
    var reader = FrameReader(profile.protocol){};
    var store = SignalStore{ .detector = profile.detector, .stale_after_ms = profile.stale_after_ms };

    const frame = profile.protocol.withChecksum(.{ 54, 48, 0, 120 });
    const garbage = [_]u8{ 0x13, 0x37 };
    const stream = garbage ++ frame ++ frame ++ frame ++ frame;

    for (stream) |byte| {
        const decoded = reader.push(byte) orelse continue;
        for (profile.protocol.readings(decoded, profile.scaling)) |r| store.apply(r, 0);
    }
    const s = store.state(0);

    try testing.expectEqual(@as(?u16, 2700), s.rpm);
    try testing.expectEqual(@as(?u3, 4), s.gear);
    try testing.expectEqual(@as(?i16, 194), s.coolant_f);
}
