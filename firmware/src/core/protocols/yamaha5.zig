const std = @import("std");
const protocol = @import("protocol.zig");
const Reading = @import("../reading.zig").Reading;

/// UNVERIFIED: 5-byte layout observed on an XT660X (Yamaha-DataLogger), a hypothesis
/// for the 2025 XSR700. See docs/research/data-sources.md.
/// [rpm/50, speed, error, coolant+30, checksum]
pub const frame_len = 5;
pub const rpm_per_count = 50;
pub const coolant_offset_c = 30;

pub const Frame = struct {
    rpm: u16,
    speed_raw: u8,
    error_code: u8,
    coolant_c: i16,
};

pub const Scaling = struct {
    kmh_per_speed_count: f32,
};

pub fn checksum(bytes: []const u8) u8 {
    var sum: u8 = 0;
    for (bytes) |b| sum +%= b;
    return sum;
}

pub fn withChecksum(data: [frame_len - 1]u8) [frame_len]u8 {
    var out: [frame_len]u8 = undefined;
    out[0 .. frame_len - 1].* = data;
    out[frame_len - 1] = checksum(&data);
    return out;
}

pub fn decode(bytes: [frame_len]u8) protocol.DecodeError!Frame {
    if (std.mem.allEqual(u8, &bytes, 0)) return error.EmptyFrame;
    if (checksum(bytes[0..4]) != bytes[4]) return error.BadChecksum;

    return .{
        .rpm = @as(u16, bytes[0]) * rpm_per_count,
        .speed_raw = bytes[1],
        .error_code = bytes[2],
        .coolant_c = @as(i16, bytes[3]) - coolant_offset_c,
    };
}

pub fn readings(frame: Frame, scaling: Scaling) [4]Reading {
    return .{
        .{ .rpm = frame.rpm },
        .{ .speed_kmh = @as(f32, @floatFromInt(frame.speed_raw)) * scaling.kmh_per_speed_count },
        .{ .coolant_c = frame.coolant_c },
        .{ .engine_error = frame.error_code },
    };
}

comptime {
    protocol.check(@This());
}

const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

test "checksum wraps at 256" {
    try expectEqual(@as(u8, 0x46), checksum(&.{ 136, 68, 0, 122 }));
    try expectEqual(@as(u8, 0), checksum(&.{ 0xFF, 0x01 }));
}

test "withChecksum appends the sum" {
    try expectEqual([frame_len]u8{ 136, 68, 0, 122, 0x46 }, withChecksum(.{ 136, 68, 0, 122 }));
}

test "decode a typical cruising frame" {
    const f = try decode(.{ 136, 68, 0, 122, 0x46 });
    try expectEqual(@as(u16, 6800), f.rpm);
    try expectEqual(@as(u8, 68), f.speed_raw);
    try expectEqual(@as(u8, 0), f.error_code);
    try expectEqual(@as(i16, 92), f.coolant_c);
}

test "max rpm byte does not overflow" {
    const f = try decode(withChecksum(.{ 255, 0, 0, 30 }));
    try expectEqual(@as(u16, 12_750), f.rpm);
}

test "coolant below zero" {
    const f = try decode(withChecksum(.{ 0, 0, 0, 10 }));
    try expectEqual(@as(i16, -20), f.coolant_c);
}

test "bad checksum is rejected" {
    var bytes = withChecksum(.{ 136, 68, 0, 122 });
    bytes[1] ^= 0x04;
    try expectError(error.BadChecksum, decode(bytes));
}

test "compensating bit flips slip past the checksum" {
    const f = try decode(.{ 136, 64, 4, 122, 0x46 });
    try expectEqual(@as(u8, 4), f.error_code);
}

test "all-zero frame is rejected even though its checksum matches" {
    try expectError(error.EmptyFrame, decode(.{ 0, 0, 0, 0, 0 }));
}

test "readings carry metric values" {
    const rs = readings(try decode(withChecksum(.{ 136, 100, 0x2A, 122 })), .{ .kmh_per_speed_count = 1.0 });
    try expectEqual(Reading{ .rpm = 6800 }, rs[0]);
    try expectEqual(Reading{ .speed_kmh = 100 }, rs[1]);
    try expectEqual(Reading{ .coolant_c = 92 }, rs[2]);
    try expectEqual(Reading{ .engine_error = 0x2A }, rs[3]);
}

test "speed scaling is applied" {
    const rs = readings(try decode(withChecksum(.{ 0, 100, 0, 30 })), .{ .kmh_per_speed_count = 0.5 });
    try expectEqual(Reading{ .speed_kmh = 50 }, rs[1]);
}
