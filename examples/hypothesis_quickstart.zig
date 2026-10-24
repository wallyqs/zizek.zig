const std = @import("std");
const zizek = @import("zizek");

/// Port of Hypothesis's introductory bounded-integer example.
pub const portable_failure = "AAEAAAAACgEAAAAy";

fn property(case: *zizek.TestCase) !void {
    const value = try zizek.integers().minValue(0).maxValue(200).draw(case);
    if (value >= 50) return error.NotLessThanFifty;
}

pub fn findAndReplayBoundary() !zizek.Failure {
    const found = (try zizek.check(property, .{
        .examples = 100,
        .seed = 1,
    })) orelse return error.BoundaryNotFound;
    if (!std.mem.eql(u8, found.cause, "NotLessThanFifty")) return error.UnexpectedFailure;
    if (!std.mem.eql(u8, found.blob, portable_failure)) return error.NonPortableBlob;

    return (try zizek.check(property, .{
        .reproduce = found.blob,
    })) orelse return error.DidNotReplay;
}

pub fn main(_: std.process.Init) !void {
    const failure = try findAndReplayBoundary();
    std.debug.print("{s}\nreproduce: {s}\n", .{ failure.cause, failure.blob });
}

test "shrinks to the first failing integer" {
    const failure = try findAndReplayBoundary();
    try std.testing.expectEqualStrings(portable_failure, failure.blob);
}
