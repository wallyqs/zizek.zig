const std = @import("std");
const zizek = @import("zizek");

/// Shared with the Go, Ruby, and Rust ports.
pub const portable_failure = "AXicdYixCQAACIB0jf6/tyJoy0UxASVkWHnhd9oFC6sAWQ==";

const MinStack = struct {
    stack: [64]i64 = undefined,
    stack_len: usize = 0,
    minimums: [64]i64 = undefined,
    minimums_len: usize = 0,

    fn minimum(self: *const MinStack) ?i64 {
        if (self.minimums_len == 0) return null;
        return self.minimums[self.minimums_len - 1];
    }

    fn push(self: *MinStack, value: i64) void {
        self.stack[self.stack_len] = value;
        self.stack_len += 1;
        if (self.minimum() == null or value < self.minimum().?) {
            self.minimums[self.minimums_len] = value;
            self.minimums_len += 1;
        }
    }

    fn pop(self: *MinStack) ?i64 {
        if (self.stack_len == 0) return null;
        self.stack_len -= 1;
        const value = self.stack[self.stack_len];
        if (self.minimum() != null and self.minimum().? == value) self.minimums_len -= 1;
        return value;
    }

    fn referenceMinimum(self: *const MinStack) ?i64 {
        if (self.stack_len == 0) return null;
        var result = self.stack[0];
        for (self.stack[1..self.stack_len]) |value| result = @min(result, value);
        return result;
    }
};

const MinStackTest = struct {
    stack: MinStack = .{},

    fn push(self: *MinStackTest, case: *zizek.TestCase) !void {
        const value = try zizek.integers().draw(case);
        case.note(std.fmt.allocPrint(zizek.shell.allocator, "push {d}", .{value}) catch unreachable);
        self.stack.push(value);
    }

    fn pop(self: *MinStackTest, case: *zizek.TestCase) !void {
        const value = self.stack.pop();
        case.note(if (value) |present|
            std.fmt.allocPrint(zizek.shell.allocator, "pop {d}", .{present}) catch unreachable
        else
            "pop nothing");
    }

    fn minimumsAgree(self: *MinStackTest, _: *zizek.TestCase) !void {
        if (!std.meta.eql(self.stack.minimum(), self.stack.referenceMinimum())) {
            return error.MinimumsDisagree;
        }
    }
};

fn property(case: *zizek.TestCase) !void {
    var state = MinStackTest{};
    const rules = [_]zizek.stateful.Rule(MinStackTest){
        .{ .name = "push", .apply = MinStackTest.push },
        .{ .name = "pop", .apply = MinStackTest.pop },
    };
    const invariants = [_]zizek.stateful.Rule(MinStackTest){
        .{ .name = "minimums_agree", .apply = MinStackTest.minimumsAgree },
    };
    try zizek.stateful.run(&state, .{
        .rules = &rules,
        .invariants = &invariants,
    }, case);
}

pub fn findAndReplayBug() !zizek.Failure {
    const found = (try zizek.check(property, .{
        .examples = 2_000,
        .seed = 1,
    })) orelse return error.BugNotFound;
    if (!std.mem.eql(u8, found.cause, "MinimumsDisagree")) return error.UnexpectedFailure;
    if (!std.mem.eql(u8, found.blob, portable_failure)) return error.NonPortableBlob;

    return (try zizek.check(property, .{
        .reproduce = found.blob,
    })) orelse return error.DidNotReplay;
}

pub fn main(_: std.process.Init) !void {
    const failure = try findAndReplayBug();
    std.debug.print("{s}\nreproduce: {s}\n", .{ failure.cause, failure.blob });
}

test "finds the repeated minimum and shrinks to three operations" {
    const failure = try findAndReplayBug();
    try std.testing.expectEqualStrings(portable_failure, failure.blob);
    var saw_third_step = false;
    for (failure.notes) |note| {
        if (std.mem.eql(u8, note, "step 3: pop")) saw_third_step = true;
        try std.testing.expect(!std.mem.startsWith(u8, note, "step 4:"));
    }
    try std.testing.expect(saw_third_step);
}
