const std = @import("std");
const zizek = @import("zizek");

const edge: i64 = 1_337;

/// Port of Hegel's two-assertion example. Distinct Zig errors identify the two
/// failure sites, and shrinking must remain on the selected one.
fn property(case: *zizek.TestCase) !void {
    const value = try zizek.integers().minValue(0).maxValue(2_000).draw(case);
    if (value == edge) return error.ForbiddenEdge;
    if (value >= edge) return error.NotBelowEdge;
}

pub fn findAndReplayOneOrigin() !zizek.Failure {
    const found = (try zizek.check(property, .{
        .examples = 100,
        .seed = 1,
    })) orelse return error.BugNotFound;
    if (!std.mem.eql(u8, found.cause, "ForbiddenEdge") and
        !std.mem.eql(u8, found.cause, "NotBelowEdge")) return error.UnexpectedFailure;

    const replayed = (try zizek.check(property, .{
        .reproduce = found.blob,
    })) orelse return error.DidNotReplay;
    if (!std.mem.eql(u8, replayed.cause, found.cause)) return error.ReplayChangedOrigin;
    return replayed;
}

pub fn main(_: std.process.Init) !void {
    const failure = try findAndReplayOneOrigin();
    std.debug.print("{s}\nreproduce: {s}\n", .{ failure.cause, failure.blob });
}

test "shrinking preserves the selected failure origin" {
    _ = try findAndReplayOneOrigin();
}
