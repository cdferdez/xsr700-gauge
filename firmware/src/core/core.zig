//! core: everything that does not care whether it runs on a Mac or on the bike.
//! Each step adds a file here and re-exports it, e.g.:
//!   pub const telemetry = @import("telemetry.zig");

pub const version = "0.1.0";

test {
    // Makes `zig build test` also run tests inside the files imported above.
    @import("std").testing.refAllDecls(@This());
}
