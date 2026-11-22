pub const version = "0.1.0";

pub const telemetry = @import("telemetry.zig");
pub const reading = @import("reading.zig");
pub const protocol = @import("protocols/protocol.zig");
pub const yamaha5 = @import("protocols/yamaha5.zig");
pub const frame_reader = @import("frame_reader.zig");
pub const gear = @import("gear.zig");
pub const signal_store = @import("signal_store.zig");
pub const profile = @import("profile.zig");

test {
    @import("std").testing.refAllDecls(@This());
    _ = @import("yamaha5_vectors_test.zig");
    _ = @import("end_to_end_test.zig");
}
