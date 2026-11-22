//! The bike this firmware targets: 2025 Yamaha XSR700 (CP2).
//! Every value is UNVERIFIED until Phase 1; see docs/research/data-sources.md.

const gear = @import("gear.zig");
const telemetry = @import("telemetry.zig");

pub const protocol = @import("protocols/yamaha5.zig");

/// Assumes one speed count is 1 km/h.
pub const scaling = protocol.Scaling{ .kmh_per_speed_count = 1.0 };

/// CP2 figures from community sources. The tire is an unloaded 180/55ZR17;
/// the loaded rolling circumference is a few percent smaller.
pub const drivetrain = gear.Drivetrain{
    .primary = 1.925,
    .gears = .{ 2.846, 2.125, 1.632, 1.300, 1.091, 0.964 },
    .final = 43.0 / 16.0,
    .tire_circumference_m = 1.979,
};

pub const gear_tolerance = 0.04;

pub const detector = gear.GearDetector.init(drivetrain, gear_tolerance, .{
    .rpm = protocol.rpm_per_count,
    .mph = telemetry.kmhToMph(scaling.kmh_per_speed_count),
}) catch unreachable;

pub const stale_after_ms = 500;
