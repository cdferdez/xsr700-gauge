const std = @import("std");

/// Display-ready telemetry in imperial units. null = no fresh data, so the UI shows dashes.
pub const State = struct {
    rpm: ?u16 = null,
    speed_mph: ?f32 = null,
    /// null = neutral, clutch pulled, unknown, or no fresh data.
    gear: ?u3 = null,
    coolant_f: ?i16 = null,
    fuel_pct: ?u8 = null,
    trip_mi: f32 = 0,
    lamps: Lamps = .{},
};

pub const Lamps = packed struct(u8) {
    turn_left: bool = false,
    turn_right: bool = false,
    high_beam: bool = false,
    neutral: bool = false,
    abs_warning: bool = false,
    engine_warning: bool = false,
    low_fuel: bool = false,
    _reserved: u1 = 0,
};

pub fn celsiusToF(c: f32) f32 {
    return c * 9.0 / 5.0 + 32.0;
}

pub fn kmhToMph(kmh: f32) f32 {
    return kmh * 0.621371;
}

pub fn coolantCtoF(c: i16) i16 {
    const f = celsiusToF(@floatFromInt(c));
    return @intFromFloat(@round(f));
}

comptime {
    std.debug.assert(std.math.maxInt(std.meta.Child(@FieldType(State, "rpm"))) >= 12_000);
    std.debug.assert(@sizeOf(Lamps) == 1);
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectApprox = std.testing.expectApproxEqAbs;

test "default state has no data" {
    const s = State{};
    try expectEqual(null, s.rpm);
    try expectEqual(null, s.speed_mph);
    try expectEqual(null, s.gear);
    try expect(!s.lamps.neutral);
}

test "gear optional" {
    var s = State{};
    try expect(s.gear == null);
    s.gear = 4;
    if (s.gear) |g| try expectEqual(4, g) else return error.TestUnexpectedResult;
}

test "celsiusToF" {
    try expectApprox(@as(f32, 32), celsiusToF(0), 0.001);
    try expectApprox(@as(f32, 212), celsiusToF(100), 0.001);
    try expectApprox(@as(f32, -40), celsiusToF(-40), 0.001);
}

test "kmhToMph" {
    try expectApprox(@as(f32, 0), kmhToMph(0), 0.001);
    try expectApprox(@as(f32, 62.137), kmhToMph(100), 0.01);
}

test "coolantCtoF rounds to whole degrees" {
    try expectEqual(@as(i16, 198), coolantCtoF(92));
    try expectEqual(@as(i16, -4), coolantCtoF(-20));
}

test "lamps pack into one byte" {
    const l = Lamps{ .turn_left = true, .high_beam = true };
    try expectEqual(@as(u8, 0b0000_0101), @as(u8, @bitCast(l)));
}
