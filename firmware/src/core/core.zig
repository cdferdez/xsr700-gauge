pub const version = "0.1.0";
pub const telemetry = @import("telemetry.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
