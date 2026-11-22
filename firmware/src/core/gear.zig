const std = @import("std");

pub const gear_count = 6;

const meters_per_mile = 1609.344;

pub const Drivetrain = struct {
    primary: f32,
    /// Ordered 1st to top gear.
    gears: [gear_count]f32,
    final: f32,
    tire_circumference_m: f32,

    pub fn rpmPerMph(self: Drivetrain, index: usize) f32 {
        const wheel_rpm_per_mph = meters_per_mile / 60.0 / self.tire_circumference_m;
        return wheel_rpm_per_mph * self.primary * self.gears[index] * self.final;
    }
};

/// Size of one step in each measured value.
pub const Resolution = struct {
    rpm: f32,
    mph: f32,
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

const testing = std.testing;

const cp2 = Drivetrain{
    .primary = 1.925,
    .gears = .{ 2.846, 2.125, 1.632, 1.300, 1.091, 0.964 },
    .final = 43.0 / 16.0,
    .tire_circumference_m = 1.979,
};
const test_resolution = Resolution{ .rpm = 50, .mph = 0.621371 };
const detector = GearDetector.init(cp2, 0.04, test_resolution) catch unreachable;

test "rpm per mph matches the hand calculation" {
    const dt = cp2;
    try testing.expectApproxEqAbs(@as(f32, 199.56), dt.rpmPerMph(0), 0.05);
    try testing.expectApproxEqAbs(@as(f32, 67.59), dt.rpmPerMph(5), 0.05);
}

test "6th gear at 70 mph" {
    try testing.expectEqual(@as(?u3, 6), detector.gear(4750, 70));
}

test "every gear at 30 mph" {
    const dt = cp2;
    for (0..gear_count) |i| {
        const rpm: u16 = @intFromFloat(@round(dt.rpmPerMph(i) * 30 / 50) * 50);
        try testing.expectEqual(@as(?u3, @intCast(i + 1)), detector.gear(rpm, 30));
    }
}

test "stopped is null" {
    try testing.expectEqual(@as(?u3, null), detector.gear(1300, 0));
}

test "revving with the clutch pulled is null" {
    try testing.expectEqual(@as(?u3, null), detector.gear(7000, 40));
}

test "coasting in neutral is null" {
    try testing.expectEqual(@as(?u3, null), detector.gear(1300, 30));
}

test "the same ratio is certain at speed but ambiguous when slow" {
    try testing.expectEqual(@as(?u3, 6), detector.gear(2100, 30));
    try testing.expectEqual(@as(?u3, null), detector.gear(700, 10));
}

test "never reports the wrong gear under rpm and speed quantization" {
    const dt = cp2;
    for (0..gear_count) |i| {
        const want: u3 = @intCast(i + 1);
        for (4..720) |quarter_kmh| {
            const kmh = @as(f32, @floatFromInt(quarter_kmh)) / 4;
            const true_mph = kmh * 0.621371;
            const true_rpm = dt.rpmPerMph(i) * true_mph;
            if (true_rpm > 10_000) break;

            const rpm: u16 = @intFromFloat(@round(true_rpm / 50) * 50);
            const mph = @round(kmh) * 0.621371;
            const got = detector.gear(rpm, mph);

            if (got) |g| try testing.expectEqual(want, g);
            if (true_mph > 16) try testing.expectEqual(@as(?u3, want), got);
        }
    }
}

test "a tolerance wide enough to overlap 5th and 6th is rejected" {
    try testing.expectError(error.BandsOverlap, GearDetector.init(cp2, 0.07, test_resolution));
}
