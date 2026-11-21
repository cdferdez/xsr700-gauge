const std = @import("std");
const kline = @import("kline.zig");

const Frame = kline.Frame;
const frame_len = kline.frame_len;

pub const Stats = struct {
    frames: u32 = 0,
    checksum_errors: u32 = 0,
    sync_losses: u32 = 0,
    bytes_skipped: u32 = 0,
};

pub const Sync = enum { hunting, confirming, locked };

pub const FrameReader = struct {
    lock_after: u8 = 3,
    miss_limit: u8 = 2,

    window: [frame_len]u8 = undefined,
    len: u8 = 0,
    sync: Sync = .hunting,
    matches: u8 = 0,
    misses: u8 = 0,
    stats: Stats = .{},

    pub fn push(self: *FrameReader, byte: u8) ?Frame {
        self.window[self.len] = byte;
        self.len += 1;
        if (self.len < frame_len) return null;

        return switch (self.sync) {
            .hunting => self.hunt(),
            .confirming, .locked => self.check(),
        };
    }

    /// Call when the UART reports the line went idle between frames.
    pub fn gap(self: *FrameReader) void {
        if (self.len == 0) return;
        self.stats.bytes_skipped +|= self.len;
        self.len = 0;
        self.dropSync();
    }

    fn hunt(self: *FrameReader) ?Frame {
        const frame = kline.decodeFrame(self.window) catch {
            self.slide();
            return null;
        };
        self.len = 0;
        self.matches = 1;
        return self.accept(frame);
    }

    fn check(self: *FrameReader) ?Frame {
        const frame = kline.decodeFrame(self.window) catch |err| switch (err) {
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

    fn accept(self: *FrameReader, frame: Frame) ?Frame {
        if (self.matches < self.lock_after) {
            self.sync = .confirming;
            return null;
        }
        self.sync = .locked;
        self.stats.frames +|= 1;
        return frame;
    }

    fn reject(self: *FrameReader) void {
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

    fn dropSync(self: *FrameReader) void {
        if (self.sync == .locked) self.stats.sync_losses +|= 1;
        self.sync = .hunting;
        self.matches = 0;
        self.misses = 0;
    }

    fn slide(self: *FrameReader) void {
        std.mem.copyForwards(u8, self.window[0 .. frame_len - 1], self.window[1..]);
        self.len = frame_len - 1;
        self.stats.bytes_skipped +|= 1;
    }
};

const testing = std.testing;

const cruise = kline.withChecksum(.{ 136, 68, 0, 122 });
const idle = kline.withChecksum(.{ 26, 0, 0, 128 });

const corrupted = blk: {
    var c = cruise;
    c[1] ^= 0x04;
    break :blk c;
};

fn times(comptime n: usize, frame: [frame_len]u8) [n * frame_len]u8 {
    var out: [n * frame_len]u8 = undefined;
    for (0..n) |i| out[i * frame_len ..][0..frame_len].* = frame;
    return out;
}

fn feed(r: *FrameReader, bytes: []const u8, out: []Frame) usize {
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
    var r = FrameReader{};
    var out: [8]Frame = undefined;
    const n = feed(&r, &times(5, cruise), &out);

    try testing.expectEqual(@as(usize, 3), n);
    try expectAllRpm(out[0..n], 6800);
    try testing.expectEqual(Sync.locked, r.sync);
    try testing.expectEqual(@as(u32, 0), r.stats.bytes_skipped);
}

test "joining mid-frame skips the partial bytes" {
    var r = FrameReader{};
    var out: [8]Frame = undefined;
    const n = feed(&r, &([_]u8{ cruise[3], cruise[4] } ++ times(5, cruise)), &out);

    try testing.expectEqual(@as(usize, 3), n);
    try expectAllRpm(out[0..n], 6800);
    try testing.expectEqual(@as(u32, 2), r.stats.bytes_skipped);
}

test "a lucky garbage window is rejected during confirmation" {
    var r = FrameReader{};
    var out: [8]Frame = undefined;
    const n = feed(&r, &([_]u8{ 1, 2, 3, 4, 10, 99 } ++ times(5, cruise)), &out);

    try testing.expectEqual(@as(usize, 3), n);
    try expectAllRpm(out[0..n], 6800);
    try testing.expectEqual(@as(u32, 0), r.stats.sync_losses);
}

test "one corrupted frame is dropped without losing lock" {
    var r = FrameReader{};
    var out: [8]Frame = undefined;
    const n = feed(&r, &(times(4, cruise) ++ corrupted ++ times(2, cruise)), &out);

    try testing.expectEqual(@as(usize, 4), n);
    try expectAllRpm(out[0..n], 6800);
    try testing.expectEqual(@as(u32, 1), r.stats.checksum_errors);
    try testing.expectEqual(@as(u32, 0), r.stats.sync_losses);
    try testing.expectEqual(Sync.locked, r.sync);
}

test "a dropped byte forces a resync" {
    var r = FrameReader{};
    var out: [16]Frame = undefined;
    const n = feed(&r, &(times(4, cruise) ++ cruise[1..].* ++ times(10, cruise)), &out);

    try testing.expect(n > 2);
    try expectAllRpm(out[0..n], 6800);
    try testing.expectEqual(@as(u32, 1), r.stats.sync_losses);
    try testing.expectEqual(Sync.locked, r.sync);
}

test "steady idle stream can false-lock at the wrong offset" {
    var r = FrameReader{};
    var out: [8]Frame = undefined;
    const n = feed(&r, &(idle[1..].* ++ times(6, idle)), &out);

    try testing.expectEqual(@as(usize, 4), n);
    try testing.expectEqual(@as(u16, 0), out[0].rpm);
    try testing.expectEqual(@as(u8, 128), out[0].error_code);
}

test "gap markers prevent the false lock" {
    var r = FrameReader{};
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
    var r = FrameReader{};
    r.stats.bytes_skipped = std.math.maxInt(u32) - 1;
    for ([_]u8{ 1, 2, 3 }) |b| _ = r.push(b);
    r.gap();
    try testing.expectEqual(std.math.maxInt(u32), r.stats.bytes_skipped);
}
