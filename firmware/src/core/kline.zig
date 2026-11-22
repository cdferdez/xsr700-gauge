const std = @import("std");
const telemetry = @import("telemetry.zig");

/// UNVERIFIED: layout observed on an XT660X (Yamaha-DataLogger), a hypothesis for the 2025 XSR700. See docs/research/data-sources.md.
/// [rpm/50, speed, error, coolant+30, checksum]
pub const frame_len = 5;

pub const Frame = struct {
    rpm: u16,
    speed_raw: u8,
    error_code: u8,
    coolant_c: i16,
};

pub const DecodeError = error{
    BadChecksum,
    EmptyFrame,
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

pub fn decodeFrame(bytes: [frame_len]u8) DecodeError!Frame {
    if (std.mem.allEqual(u8, &bytes, 0)) return error.EmptyFrame;
    if (checksum(bytes[0..4]) != bytes[4]) return error.BadChecksum;

    return .{
        .rpm = @as(u16, bytes[0]) * 50,
        .speed_raw = bytes[1],
        .error_code = bytes[2],
        .coolant_c = @as(i16, bytes[3]) - 30,
    };
}

pub fn applyTo(frame: Frame, state: *telemetry.State) void {
    state.rpm = frame.rpm;
    state.speed_mph = telemetry.kmhToMph(@floatFromInt(frame.speed_raw));
    state.coolant_f = telemetry.coolantCtoF(frame.coolant_c);
    state.lamps.engine_warning = frame.error_code != 0;
}

const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;
const expectApprox = std.testing.expectApproxEqAbs;

test "checksum wraps at 256" {
    try expectEqual(@as(u8, 0x46), checksum(&.{ 136, 68, 0, 122 }));
    try expectEqual(@as(u8, 0), checksum(&.{ 0xFF, 0x01 }));
}

test "withChecksum appends the sum" {
    try expectEqual([frame_len]u8{ 136, 68, 0, 122, 0x46 }, withChecksum(.{ 136, 68, 0, 122 }));
}

test "decode a typical cruising frame" {
    const f = try decodeFrame(.{ 136, 68, 0, 122, 0x46 });
    try expectEqual(@as(u16, 6800), f.rpm);
    try expectEqual(@as(u8, 68), f.speed_raw);
    try expectEqual(@as(u8, 0), f.error_code);
    try expectEqual(@as(i16, 92), f.coolant_c);
}

test "max rpm byte does not overflow" {
    const f = try decodeFrame(withChecksum(.{ 255, 0, 0, 30 }));
    try expectEqual(@as(u16, 12_750), f.rpm);
}

test "coolant below zero" {
    const f = try decodeFrame(withChecksum(.{ 0, 0, 0, 10 }));
    try expectEqual(@as(i16, -20), f.coolant_c);
}

test "bad checksum is rejected" {
    var bytes = withChecksum(.{ 136, 68, 0, 122 });
    bytes[1] ^= 0x04;
    try expectError(error.BadChecksum, decodeFrame(bytes));
}

test "compensating bit flips slip past the checksum" {
    const f = try decodeFrame(.{ 136, 64, 4, 122, 0x46 });
    try expectEqual(@as(u8, 4), f.error_code);
}

test "all-zero frame is rejected even though its checksum matches" {
    try expectError(error.EmptyFrame, decodeFrame(.{ 0, 0, 0, 0, 0 }));
}

test "applyTo fills display state" {
    var s = telemetry.State{};
    applyTo(try decodeFrame(withChecksum(.{ 136, 100, 0, 122 })), &s);
    try expectEqual(@as(u16, 6800), s.rpm);
    try expectApprox(@as(f32, 62.137), s.speed_mph, 0.01);
    try expectEqual(@as(i16, 198), s.coolant_f);
    try expectEqual(false, s.lamps.engine_warning);
}

test "nonzero error code lights engine warning" {
    var s = telemetry.State{};
    applyTo(try decodeFrame(withChecksum(.{ 20, 0, 0x2A, 60 })), &s);
    try expectEqual(true, s.lamps.engine_warning);
}
