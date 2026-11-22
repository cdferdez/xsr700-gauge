const std = @import("std");

pub const gear_count = 6;

const meters_per_mile = 1609.344;

/// UNVERIFIED: CP2 (MT-07 / XSR700) ratios from community sources; confirm against the service manual.
pub const Drivetrain = struct {
    primary: f32 = 1.925,
    gears: [gear_count]f32 = .{ 2.846, 2.125, 1.632, 1.300, 1.091, 0.964 },
    final: f32 = 43.0 / 16.0,
    /// 180/55ZR17, unloaded. The loaded rolling circumference is a few percent smaller.
    tire_circumference_m: f32 = 1.979,

    pub fn rpmPerMph(self: Drivetrain, index: usize) f32 {
        const wheel_rpm_per_mph = meters_per_mile / 60.0 / self.tire_circumference_m;
        return wheel_rpm_per_mph * self.primary * self.gears[index] * self.final;
    }
};

/// Size of one step in each measured value.
pub const Resolution = struct {
    rpm: f32 = 50,
    /// UNVERIFIED: assumes speed_raw counts whole km/h.
    mph: f32 = 0.621371,
};

const Band = struct {
    lo: f32,
    hi: f32,

    fn contains(self: Band, x: f32) bool {
        return x >= self.lo and x <= self.hi;
    }

    fn overlaps(self: Band, lo: f32, hi: f32) bool {
        return lo <= self.hi and hi >= self.lo;
    }
};

pub const GearDetector = struct {
    bands: [gear_count]Band,
    half_rpm: f32,
    half_mph: f32,

    pub fn init(dt: Drivetrain, tolerance: f32, res: Resolution) error{BandsOverlap}!GearDetector {
        var bands: [gear_count]Band = undefined;
        for (&bands, 0..) |*b, i| {
            const expected = dt.rpmPerMph(i);
            b.* = .{ .lo = expected * (1 - tolerance), .hi = expected * (1 + tolerance) };
        }
        for (bands[0 .. gear_count - 1], bands[1..]) |lower_gear, higher_gear| {
            if (higher_gear.hi >= lower_gear.lo) return error.BandsOverlap;
        }
        return .{ .bands = bands, .half_rpm = res.rpm / 2, .half_mph = res.mph / 2 };
    }

    /// null = neutral, clutch slipping or pulled, stopped, or too slow to tell.
    pub fn gear(self: GearDetector, rpm: u16, mph: f32) ?u3 {
        if (mph <= self.half_mph) return null;

        const rpm_f: f32 = @floatFromInt(rpm);
        const ratio = rpm_f / mph;
        const lo = (rpm_f - self.half_rpm) / (mph + self.half_mph);
        const hi = (rpm_f + self.half_rpm) / (mph - self.half_mph);

        const index = for (self.bands, 0..) |b, i| {
            if (b.contains(ratio)) break i;
        } else return null;

        for (self.bands, 0..) |b, i| {
            if (i != index and b.overlaps(lo, hi)) return null;
        }
        return @intCast(index + 1);
    }
};

pub const default = GearDetector.init(.{}, 0.04, .{}) catch unreachable;

const testing = std.testing;

test "rpm per mph matches the hand calculation" {
    const dt = Drivetrain{};
    try testing.expectApproxEqAbs(@as(f32, 199.56), dt.rpmPerMph(0), 0.05);
    try testing.expectApproxEqAbs(@as(f32, 67.59), dt.rpmPerMph(5), 0.05);
}

test "6th gear at 70 mph" {
    try testing.expectEqual(@as(?u3, 6), default.gear(4750, 70));
}

test "every gear at 30 mph" {
    const dt = Drivetrain{};
    for (0..gear_count) |i| {
        const rpm: u16 = @intFromFloat(@round(dt.rpmPerMph(i) * 30 / 50) * 50);
        try testing.expectEqual(@as(?u3, @intCast(i + 1)), default.gear(rpm, 30));
    }
}

test "stopped is null" {
    try testing.expectEqual(@as(?u3, null), default.gear(1300, 0));
}

test "revving with the clutch pulled is null" {
    try testing.expectEqual(@as(?u3, null), default.gear(7000, 40));
}

test "coasting in neutral is null" {
    try testing.expectEqual(@as(?u3, null), default.gear(1300, 30));
}

test "the same ratio is certain at speed but ambiguous when slow" {
    try testing.expectEqual(@as(?u3, 6), default.gear(2100, 30));
    try testing.expectEqual(@as(?u3, null), default.gear(700, 10));
}

test "never reports the wrong gear under rpm and speed quantization" {
    const dt = Drivetrain{};
    for (0..gear_count) |i| {
        const want: u3 = @intCast(i + 1);
        for (4..720) |quarter_kmh| {
            const kmh = @as(f32, @floatFromInt(quarter_kmh)) / 4;
            const true_mph = kmh * 0.621371;
            const true_rpm = dt.rpmPerMph(i) * true_mph;
            if (true_rpm > 10_000) break;

            const rpm: u16 = @intFromFloat(@round(true_rpm / 50) * 50);
            const mph = @round(kmh) * 0.621371;
            const got = default.gear(rpm, mph);

            if (got) |g| try testing.expectEqual(want, g);
            if (true_mph > 16) try testing.expectEqual(@as(?u3, want), got);
        }
    }
}

test "a tolerance wide enough to overlap 5th and 6th is rejected" {
    try testing.expectError(error.BandsOverlap, GearDetector.init(.{}, 0.07, .{}));
}
