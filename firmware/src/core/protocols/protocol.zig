const std = @import("std");

/// EmptyFrame: the bytes line up as a frame but carry no data, so alignment is kept.
/// BadChecksum: these bytes are not a valid frame at this position.
pub const DecodeError = error{ BadChecksum, EmptyFrame };

/// What FrameReader needs from a protocol: `frame_len`, `Frame`, and
/// `decode([frame_len]u8) DecodeError!Frame`.
pub fn check(comptime P: type) void {
    const name = @typeName(P);
    inline for (.{ "frame_len", "Frame", "decode" }) |decl| {
        if (!@hasDecl(P, decl)) @compileError("protocol " ++ name ++ " is missing pub declaration `" ++ decl ++ "`");
    }
    if (P.frame_len < 2 or P.frame_len > std.math.maxInt(u8)) {
        @compileError("protocol " ++ name ++ ": frame_len must be between 2 and 255");
    }
    const Expected = fn ([P.frame_len]u8) DecodeError!P.Frame;
    if (@TypeOf(P.decode) != Expected) {
        @compileError("protocol " ++ name ++ ": decode must have type " ++ @typeName(Expected));
    }
}
