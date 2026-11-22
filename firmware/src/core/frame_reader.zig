const std = @import("std");
const protocol = @import("protocols/protocol.zig");

pub const Stats = struct {
    frames: u32 = 0,
    checksum_errors: u32 = 0,
    sync_losses: u32 = 0,
    bytes_skipped: u32 = 0,
};

pub const Sync = enum { hunting, confirming, locked };

pub fn FrameReader(comptime P: type) type {
    comptime protocol.check(P);

    return struct {
        const Self = @This();
        const frame_len = P.frame_len;

        lock_after: u8 = 3,
        miss_limit: u8 = 2,

        window: [frame_len]u8 = undefined,
        len: u8 = 0,
        sync: Sync = .hunting,
        matches: u8 = 0,
        misses: u8 = 0,
        stats: Stats = .{},

        pub fn push(self: *Self, byte: u8) ?P.Frame {
            self.window[self.len] = byte;
            self.len += 1;
            if (self.len < frame_len) return null;

            return switch (self.sync) {
                .hunting => self.hunt(),
                .confirming, .locked => self.check(),
            };
        }

        /// Call when the UART reports the line went idle between frames.
        pub fn gap(self: *Self) void {
            if (self.len == 0) return;
            self.stats.bytes_skipped +|= self.len;
            self.len = 0;
            self.dropSync();
        }

        fn hunt(self: *Self) ?P.Frame {
            const frame = P.decode(self.window) catch {
                self.slide();
                return null;
            };
            self.len = 0;
            self.matches = 1;
            return self.accept(frame);
        }

        fn check(self: *Self) ?P.Frame {
            const frame = P.decode(self.window) catch |err| switch (err) {
                error.EmptyFrame => {
                    self.len = 0;
                    return null;
                },
                error.BadChecksum => {
                    self.reject();
                    return null;
                },
            };
            self.len = 0;
            self.misses = 0;
            self.matches +|= 1;
            return self.accept(frame);
        }

        fn accept(self: *Self, frame: P.Frame) ?P.Frame {
            if (self.matches < self.lock_after) {
                self.sync = .confirming;
                return null;
            }
            self.sync = .locked;
            self.stats.frames +|= 1;
            return frame;
        }

        fn reject(self: *Self) void {
            if (self.sync == .locked) {
                self.stats.checksum_errors +|= 1;
                self.misses += 1;
                if (self.misses < self.miss_limit) {
                    self.len = 0;
                    return;
                }
            }
            self.dropSync();
            self.slide();
        }

        fn dropSync(self: *Self) void {
            if (self.sync == .locked) self.stats.sync_losses +|= 1;
            self.sync = .hunting;
            self.matches = 0;
            self.misses = 0;
        }

        fn slide(self: *Self) void {
            std.mem.copyForwards(u8, self.window[0 .. frame_len - 1], self.window[1..]);
            self.len = frame_len - 1;
            self.stats.bytes_skipped +|= 1;
        }
    };
}

const testing = std.testing;
const yamaha5 = @import("protocols/yamaha5.zig");

const Reader = FrameReader(yamaha5);
const Frame = yamaha5.Frame;

const cruise = yamaha5.withChecksum(.{ 136, 68, 0, 122 });
const idle = yamaha5.withChecksum(.{ 26, 0, 0, 128 });

const corrupted = blk: {
    var c = cruise;
    c[1] ^= 0x04;
    break :blk c;
};

fn times(comptime n: usize, frame: [yamaha5.frame_len]u8) [n * yamaha5.frame_len]u8 {
    var out: [n * yamaha5.frame_len]u8 = undefined;
    for (0..n) |i| out[i * yamaha5.frame_len ..][0..yamaha5.frame_len].* = frame;
    return out;
}

fn feed(r: anytype, bytes: []const u8, out: anytype) usize {
    var n: usize = 0;
    for (bytes) |b| {
        if (r.push(b)) |f| {
            out[n] = f;
            n += 1;
        }
    }
    return n;
}

fn expectAllRpm(frames: []const Frame, rpm: u16) !void {
    for (frames) |f| try testing.expectEqual(rpm, f.rpm);
}

test "clean stream locks after lock_after frames" {
    var r = Reader{};
    var out: [8]Frame = undefined;
    const n = feed(&r, &times(5, cruise), &out);

    try testing.expectEqual(@as(usize, 3), n);
    try expectAllRpm(out[0..n], 6800);
    try testing.expectEqual(Sync.locked, r.sync);
    try testing.expectEqual(@as(u32, 0), r.stats.bytes_skipped);
}

test "joining mid-frame skips the partial bytes" {
    var r = Reader{};
    var out: [8]Frame = undefined;
    const n = feed(&r, &([_]u8{ cruise[3], cruise[4] } ++ times(5, cruise)), &out);

    try testing.expectEqual(@as(usize, 3), n);
    try expectAllRpm(out[0..n], 6800);
    try testing.expectEqual(@as(u32, 2), r.stats.bytes_skipped);
}

test "a lucky garbage window is rejected during confirmation" {
    var r = Reader{};
    var out: [8]Frame = undefined;
    const n = feed(&r, &([_]u8{ 1, 2, 3, 4, 10, 99 } ++ times(5, cruise)), &out);

    try testing.expectEqual(@as(usize, 3), n);
    try expectAllRpm(out[0..n], 6800);
    try testing.expectEqual(@as(u32, 0), r.stats.sync_losses);
}

test "one corrupted frame is dropped without losing lock" {
    var r = Reader{};
    var out: [8]Frame = undefined;
    const n = feed(&r, &(times(4, cruise) ++ corrupted ++ times(2, cruise)), &out);

    try testing.expectEqual(@as(usize, 4), n);
    try expectAllRpm(out[0..n], 6800);
    try testing.expectEqual(@as(u32, 1), r.stats.checksum_errors);
    try testing.expectEqual(@as(u32, 0), r.stats.sync_losses);
    try testing.expectEqual(Sync.locked, r.sync);
}

test "a dropped byte forces a resync" {
    var r = Reader{};
    var out: [16]Frame = undefined;
    const n = feed(&r, &(times(4, cruise) ++ cruise[1..].* ++ times(10, cruise)), &out);

    try testing.expect(n > 2);
    try expectAllRpm(out[0..n], 6800);
    try testing.expectEqual(@as(u32, 1), r.stats.sync_losses);
    try testing.expectEqual(Sync.locked, r.sync);
}

test "steady idle stream can false-lock at the wrong offset" {
    var r = Reader{};
    var out: [8]Frame = undefined;
    const n = feed(&r, &(idle[1..].* ++ times(6, idle)), &out);

    try testing.expectEqual(@as(usize, 4), n);
    try testing.expectEqual(@as(u16, 0), out[0].rpm);
    try testing.expectEqual(@as(u8, 128), out[0].error_code);
}

test "gap markers prevent the false lock" {
    var r = Reader{};
    var out: [8]Frame = undefined;

    var n = feed(&r, idle[1..], &out);
    r.gap();
    for (0..6) |_| {
        n += feed(&r, &idle, out[n..]);
        r.gap();
    }

    try testing.expectEqual(@as(usize, 4), n);
    try expectAllRpm(out[0..n], 1300);
    try testing.expectEqual(@as(u32, 4), r.stats.bytes_skipped);
}

test "stats saturate instead of overflowing" {
    var r = Reader{};
    r.stats.bytes_skipped = std.math.maxInt(u32) - 1;
    for ([_]u8{ 1, 2, 3 }) |b| _ = r.push(b);
    r.gap();
    try testing.expectEqual(std.math.maxInt(u32), r.stats.bytes_skipped);
}

const Xor3 = struct {
    pub const frame_len = 3;
    pub const Frame = struct { a: u8, b: u8 };

    pub fn decode(bytes: [frame_len]u8) protocol.DecodeError!Xor3.Frame {
        if (std.mem.allEqual(u8, &bytes, 0)) return error.EmptyFrame;
        if (bytes[0] ^ bytes[1] != bytes[2]) return error.BadChecksum;
        return .{ .a = bytes[0], .b = bytes[1] };
    }

    fn encode(a: u8, b: u8) [frame_len]u8 {
        return .{ a, b, a ^ b };
    }
};

test "the reader works with any protocol that meets the contract" {
    var r = FrameReader(Xor3){};
    var out: [8]Xor3.Frame = undefined;
    const stream = comptime [_]u8{0x55} ++ Xor3.encode(1, 2) ++ Xor3.encode(3, 4) ++
        Xor3.encode(5, 6) ++ Xor3.encode(7, 8) ++ Xor3.encode(9, 10);
    const n = feed(&r, &stream, &out);

    try testing.expectEqual(@as(usize, 3), n);
    try testing.expectEqual(Xor3.Frame{ .a = 5, .b = 6 }, out[0]);
    try testing.expectEqual(Xor3.Frame{ .a = 9, .b = 10 }, out[2]);
    try testing.expectEqual(@as(u32, 1), r.stats.bytes_skipped);
}
