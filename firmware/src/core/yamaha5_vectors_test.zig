const std = @import("std");
const yamaha5 = @import("protocols/yamaha5.zig");

const testing = std.testing;

const Expected = struct {
    rpm: u16,
    speed_raw: u8,
    error_code: u8,
    coolant_c: i16,
};

const ExpectedError = enum { BadChecksum, EmptyFrame };

const Vector = struct {
    kind: []const u8,
    bytes: [yamaha5.frame_len]u8,
    ok: ?Expected = null,
    err: ?ExpectedError = null,
};

const File = struct {
    generator: []const u8,
    seed: u32,
    count: usize,
    vectors: []const Vector,
};

const min_vectors = 1000;

test "decoder agrees with the Python reference on every vector" {
    const parsed = try std.json.parseFromSlice(File, testing.allocator, @embedFile("yamaha5_vectors"), .{});
    defer parsed.deinit();
    const file = parsed.value;

    try testing.expectEqual(file.count, file.vectors.len);
    try testing.expect(file.vectors.len >= min_vectors);

    for (file.vectors, 0..) |v, i| {
        errdefer std.debug.print("vector {d} ({s}) {any} failed\n", .{ i, v.kind, v.bytes });

        const result = yamaha5.decode(v.bytes);
        if (v.ok) |want| {
            const got = try result;
            try testing.expectEqual(want.rpm, got.rpm);
            try testing.expectEqual(want.speed_raw, got.speed_raw);
            try testing.expectEqual(want.error_code, got.error_code);
            try testing.expectEqual(want.coolant_c, got.coolant_c);
        } else if (v.err) |want| {
            if (result) |_| return error.TestExpectedError else |got| {
                try testing.expectEqualStrings(@tagName(want), @errorName(got));
            }
        } else return error.VectorHasNoExpectation;
    }
}
