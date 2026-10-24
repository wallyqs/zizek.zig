const std = @import("std");
const zizek = @import("zizek");

pub const legacy_zizek_failure = "AAwAAAABAAAKAQAAAAEBAAAKAQAAAAUBAAAKAQAAAAIBAAAKAQAAAAUBAAAKAQAAAAEBAAAKAQAAAAU=";
pub const portable_failure = "AXicbYo5CgAwDMPkQpeu/f9fc0AIgXixLfQBiSciWX6L3J5npdM1FrQAhg==";
pub const hegel_zlib_failure = "AXicbYoxCgBACMPSg1tc/f9fdRBFcCgNIQ4ILEed1OYPvtPuNgAVzACA";

const DieHard = struct {
    small: i32 = 0,
    big: i32 = 0,

    fn fillSmall(self: *DieHard, _: *zizek.TestCase) !void {
        self.small = 3;
    }

    fn fillBig(self: *DieHard, _: *zizek.TestCase) !void {
        self.big = 5;
    }

    fn emptySmall(self: *DieHard, _: *zizek.TestCase) !void {
        self.small = 0;
    }

    fn emptyBig(self: *DieHard, _: *zizek.TestCase) !void {
        self.big = 0;
    }

    fn pourSmallIntoBig(self: *DieHard, _: *zizek.TestCase) !void {
        const previous_big = self.big;
        self.big = @min(5, self.big + self.small);
        self.small -= self.big - previous_big;
    }

    fn pourBigIntoSmall(self: *DieHard, _: *zizek.TestCase) !void {
        const previous_small = self.small;
        self.small = @min(3, self.small + self.big);
        self.big -= self.small - previous_small;
    }

    fn physicsOfJugs(self: *DieHard, _: *zizek.TestCase) !void {
        if (self.small < 0 or self.small > 3) return error.SmallJugOutOfBounds;
        if (self.big < 0 or self.big > 5) return error.BigJugOutOfBounds;
    }

    fn dieHardProblemNotSolved(self: *DieHard, case: *zizek.TestCase) !void {
        case.note(std.fmt.allocPrint(
            zizek.shell.allocator,
            "small / big = {d} / {d}",
            .{ self.small, self.big },
        ) catch unreachable);
        if (self.big == 4) return error.FourLitres;
    }
};

fn property(case: *zizek.TestCase) !void {
    var state = DieHard{};
    const rules = [_]zizek.stateful.Rule(DieHard){
        .{ .name = "fill_small", .apply = DieHard.fillSmall },
        .{ .name = "fill_big", .apply = DieHard.fillBig },
        .{ .name = "empty_small", .apply = DieHard.emptySmall },
        .{ .name = "empty_big", .apply = DieHard.emptyBig },
        .{ .name = "pour_small_into_big", .apply = DieHard.pourSmallIntoBig },
        .{ .name = "pour_big_into_small", .apply = DieHard.pourBigIntoSmall },
    };
    const invariants = [_]zizek.stateful.Rule(DieHard){
        .{ .name = "physics_of_jugs", .apply = DieHard.physicsOfJugs },
        .{ .name = "die_hard_problem_not_solved", .apply = DieHard.dieHardProblemNotSolved },
    };
    try zizek.stateful.run(&state, zizek.stateful.Machine(DieHard){
        .rules = &rules,
        .invariants = &invariants,
    }, case);
}

pub fn findAndReplaySolution() !zizek.Failure {
    const found = (try zizek.check(property, .{
        .examples = 2_000,
        .seed = 0,
    })) orelse return error.SolutionNotFound;
    if (!std.mem.eql(u8, found.cause, "FourLitres")) return error.UnexpectedFailure;
    if (!std.mem.eql(u8, found.blob, portable_failure)) return error.NonPortableBlob;

    const replayed = (try zizek.check(property, .{
        .reproduce = found.blob,
    })) orelse return error.DidNotReplay;
    if (!std.mem.eql(u8, replayed.cause, found.cause)) return error.ReplayChangedFailure;
    for ([_][]const u8{ legacy_zizek_failure, hegel_zlib_failure }) |blob| {
        const compatible = (try zizek.check(property, .{ .reproduce = blob })) orelse
            return error.CompatibleBlobDidNotReplay;
        if (!std.mem.eql(u8, compatible.cause, found.cause)) return error.CompatibleReplayChangedFailure;
    }
    return replayed;
}

pub fn main(_: std.process.Init) !void {
    const failure = try findAndReplaySolution();
    std.debug.print("{s}\nreproduce: {s}\n", .{ failure.cause, failure.blob });
}

test "finds, shrinks, and replays the portable six-step solution" {
    const failure = try findAndReplaySolution();
    try std.testing.expectEqualStrings(portable_failure, failure.blob);
    try std.testing.expectEqualStrings("small / big = 3 / 4", failure.notes[failure.notes.len - 1]);

    const expected_steps = [_][]const u8{
        "step 1: fill_big",
        "step 2: pour_big_into_small",
        "step 3: empty_small",
        "step 4: pour_big_into_small",
        "step 5: fill_big",
        "step 6: pour_big_into_small",
    };
    for (expected_steps) |expected| {
        var found = false;
        for (failure.notes) |note| {
            if (std.mem.eql(u8, note, expected)) {
                found = true;
                break;
            }
        }
        try std.testing.expect(found);
    }
}
