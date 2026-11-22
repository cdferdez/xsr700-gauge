pub const version = "0.1.0";
pub const telemetry = @import("telemetry.zig");
pub const kline = @import("kline.zig");
pub const frame_reader = @import("frame_reader.zig");

test {
    @import("std").testing.refAllDecls(@This());
    _ = @import("kline_vectors_test.zig");
}
