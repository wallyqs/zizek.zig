const std = @import("std");
const zizek = @import("zizek");

/// Port of Hegel's passing stack state machine.
const IntegerStack = struct {
    values: [64]i64 = undefined,
    len: usize = 0,

    fn push(self: *IntegerStack, case: *zizek.TestCase) !void {
        self.values[self.len] = try zizek.integers().draw(case);
        self.len += 1;
    }

    fn pop(self: *IntegerStack, _: *zizek.TestCase) !void {
        if (self.len != 0) self.len -= 1;
    }

    fn popPush(self: *IntegerStack, case: *zizek.TestCase) !void {
        const initial = self.values[0..self.len];
        var copy: [64]i64 = undefined;
        @memcpy(copy[0..self.len], initial);
        const value = try zizek.integers().draw(case);
        self.values[self.len] = value;
        self.len += 1;
        self.len -= 1;
        if (self.values[self.len] != value) return error.WrongPoppedValue;
        if (!std.mem.eql(i64, self.values[0..self.len], copy[0..self.len])) return error.StackChanged;
    }

    fn pushPop(self: *IntegerStack, case: *zizek.TestCase) !void {
        try case.assume(self.len != 0);
        var copy: [64]i64 = undefined;
        @memcpy(copy[0..self.len], self.values[0..self.len]);
        self.len -= 1;
        const value = self.values[self.len];
        self.values[self.len] = value;
        self.len += 1;
        if (!std.mem.eql(i64, self.values[0..self.len], copy[0..self.len])) return error.StackChanged;
    }
};

fn property(case: *zizek.TestCase) !void {
    var state = IntegerStack{};
    const rules = [_]zizek.stateful.Rule(IntegerStack){
        .{ .name = "push", .apply = IntegerStack.push },
        .{ .name = "pop", .apply = IntegerStack.pop },
        .{ .name = "pop_push", .apply = IntegerStack.popPush },
        .{ .name = "push_pop", .apply = IntegerStack.pushPop },
    };
    try zizek.stateful.run(&state, zizek.stateful.Machine(IntegerStack){
        .rules = &rules,
    }, case);
}

pub fn verifyStackModel() !void {
    if ((try zizek.check(property, .{ .examples = 100, .seed = 1 })) != null) {
        return error.StackModelFailed;
    }
}

pub fn main(_: std.process.Init) !void {
    try verifyStackModel();
    std.debug.print("stack model passed\n", .{});
}

test "stack model passes" {
    try verifyStackModel();
}
