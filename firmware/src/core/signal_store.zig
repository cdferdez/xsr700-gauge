const std = @import("std");
const gear = @import("gear.zig");
const telemetry = @import("telemetry.zig");
const Reading = @import("reading.zig").Reading;

fn Signal(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T = undefined,
        at_ms: ?u32 = null,

        fn set(self: *Self, value: T, now_ms: u32) void {
            self.value = value;
            self.at_ms = now_ms;
        }

        fn fresh(self: Self, now_ms: u32, max_age_ms: u32) ?T {
            const at = self.at_ms orelse return null;
            if (now_ms -% at > max_age_ms) return null;
            return self.value;
        }
    };
}

/// The only place Readings become display State.
pub const SignalStore = struct {
    detector: gear.GearDetector,
    stale_after_ms: u32,

    rpm: Signal(u16) = .{},
    speed_kmh: Signal(f32) = .{},
    coolant_c: Signal(i16) = .{},
    engine_error: Signal(u8) = .{},
    sensor_gear: Signal(?u3) = .{},
    neutral: Signal(bool) = .{},

    pub fn apply(self: *SignalStore, reading: Reading, now_ms: u32) void {
        switch (reading) {
            .rpm => |v| self.rpm.set(v, now_ms),
            .speed_kmh => |v| self.speed_kmh.set(v, now_ms),
            .coolant_c => |v| self.coolant_c.set(v, now_ms),
            .engine_error => |v| self.engine_error.set(v, now_ms),
            .gear => |v| self.sensor_gear.set(v, now_ms),
            .neutral => |v| self.neutral.set(v, now_ms),
        }
    }

    pub fn state(self: *const SignalStore, now_ms: u32) telemetry.State {
        const max_age = self.stale_after_ms;
        const rpm = self.rpm.fresh(now_ms, max_age);
        const mph = if (self.speed_kmh.fresh(now_ms, max_age)) |kmh| telemetry.kmhToMph(kmh) else null;
        const neutral = self.neutral.fresh(now_ms, max_age) orelse false;

        return .{
            .rpm = rpm,
            .speed_mph = mph,
            .coolant_f = if (self.coolant_c.fresh(now_ms, max_age)) |c| telemetry.coolantCtoF(c) else null,
            .gear = self.pickGear(rpm, mph, neutral, now_ms),
            .lamps = .{
                .neutral = neutral,
                .engine_warning = if (self.engine_error.fresh(now_ms, max_age)) |e| e != 0 else false,
            },
        };
    }

    fn pickGear(self: *const SignalStore, rpm: ?u16, mph: ?f32, neutral: bool, now_ms: u32) ?u3 {
        if (self.sensor_gear.fresh(now_ms, self.stale_after_ms)) |sensed| return sensed;
        if (neutral) return null;
        const r = rpm orelse return null;
        const m = mph orelse return null;
        return self.detector.gear(r, m);
    }
};

const testing = std.testing;
const profile = @import("profile.zig");

fn testStore() SignalStore {
    return .{ .detector = profile.detector, .stale_after_ms = 500 };
}

fn applyFourthGear(f: *SignalStore, now_ms: u32) void {
    f.apply(.{ .rpm = 2700 }, now_ms);
    f.apply(.{ .speed_kmh = 48 }, now_ms);
    f.apply(.{ .coolant_c = 90 }, now_ms);
    f.apply(.{ .engine_error = 0 }, now_ms);
}

test "readings become display state" {
    var f = testStore();
    applyFourthGear(&f, 0);
    const s = f.state(0);

    try testing.expectEqual(@as(?u16, 2700), s.rpm);
    try testing.expectApproxEqAbs(@as(f32, 29.83), s.speed_mph.?, 0.01);
    try testing.expectEqual(@as(?i16, 194), s.coolant_f);
    try testing.expectEqual(@as(?u3, 4), s.gear);
    try testing.expectEqual(false, s.lamps.engine_warning);
}

test "a nonzero error code lights the engine warning" {
    var f = testStore();
    f.apply(.{ .engine_error = 0x2A }, 0);
    try testing.expect(f.state(0).lamps.engine_warning);
}

test "a sensor gear overrides the calculated gear" {
    var f = testStore();
    applyFourthGear(&f, 0);
    f.apply(.{ .gear = 2 }, 0);
    try testing.expectEqual(@as(?u3, 2), f.state(0).gear);
}

test "a sensor reporting no gear also overrides the calculation" {
    var f = testStore();
    applyFourthGear(&f, 0);
    f.apply(.{ .gear = null }, 0);
    try testing.expectEqual(@as(?u3, null), f.state(0).gear);
}

test "the neutral switch blanks the gear and lights the lamp" {
    var f = testStore();
    applyFourthGear(&f, 0);
    f.apply(.{ .neutral = true }, 0);
    const s = f.state(0);
    try testing.expectEqual(@as(?u3, null), s.gear);
    try testing.expect(s.lamps.neutral);
}

test "signals go stale" {
    var f = testStore();
    applyFourthGear(&f, 0);
    try testing.expectEqual(@as(?u16, 2700), f.state(500).rpm);

    const s = f.state(501);
    try testing.expectEqual(@as(?u16, null), s.rpm);
    try testing.expectEqual(@as(?f32, null), s.speed_mph);
    try testing.expectEqual(@as(?u3, null), s.gear);
}

test "a stale sensor gear falls back to the calculation" {
    var f = testStore();
    f.apply(.{ .gear = 2 }, 0);
    applyFourthGear(&f, 600);
    try testing.expectEqual(@as(?u3, 4), f.state(600).gear);
}

test "staleness survives the millisecond clock wrapping" {
    var f = testStore();
    const before_wrap = std.math.maxInt(u32) - 100;
    applyFourthGear(&f, before_wrap);
    try testing.expectEqual(@as(?u16, 2700), f.state(200).rpm);
    try testing.expectEqual(@as(?u16, null), f.state(500).rpm);
}
