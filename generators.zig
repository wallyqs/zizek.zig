const std = @import("std");
const core = @import("zizek_gen.zig");
const shell = @import("shell.zig");
const allocator = std.heap.smp_allocator;

pub const IntegerGenerator = struct {
    min: i64 = std.math.minInt(i64),
    max: i64 = std.math.maxInt(i64),
    // `target` is only read when `target_set` is true. Folding "shrink towards
    // 0" together with "no target given" is what made Zig and Go clamp an
    // explicit out-of-range target while the other four shells passed it
    // through.
    target: i64 = 0,
    target_set: bool = false,

    pub fn minValue(self: IntegerGenerator, value: i64) IntegerGenerator {
        var result = self;
        result.min = value;
        return result;
    }

    pub fn maxValue(self: IntegerGenerator, value: i64) IntegerGenerator {
        var result = self;
        result.max = value;
        return result;
    }

    pub fn shrinkTowards(self: IntegerGenerator, value: i64) IntegerGenerator {
        var result = self;
        result.target = value;
        result.target_set = true;
        return result;
    }

    pub fn draw(self: IntegerGenerator, case: *shell.TestCase) !i64 {
        const timer = case.startGeneration();
        defer case.finishGeneration(timer);
        // An explicit target is passed through unclamped: integer_simplest
        // already clamps it to the nearer bound, and clamping again here would
        // send a target above max down to min instead.
        const target = if (self.target_set) self.target else core.integer_default_shrink_target(self.min, self.max);
        return case.integer(self.min, self.max, target);
    }
};

pub fn integers() IntegerGenerator {
    return .{};
}

pub const FloatGenerator = struct {
    min: f64 = -std.math.inf(f64),
    max: f64 = std.math.inf(f64),
    allow_nan: bool = false,
    allow_infinity: bool = false,
    smallest_nonzero: f64 = 0,

    pub fn minValue(self: FloatGenerator, value: f64) FloatGenerator {
        var result = self;
        result.min = value;
        return result;
    }

    pub fn maxValue(self: FloatGenerator, value: f64) FloatGenerator {
        var result = self;
        result.max = value;
        return result;
    }

    pub fn allowNaN(self: FloatGenerator, value: bool) FloatGenerator {
        var result = self;
        result.allow_nan = value;
        return result;
    }

    pub fn allowInfinity(self: FloatGenerator, value: bool) FloatGenerator {
        var result = self;
        result.allow_infinity = value;
        return result;
    }

    pub fn smallestNonzeroMagnitude(self: FloatGenerator, value: f64) FloatGenerator {
        var result = self;
        result.smallest_nonzero = value;
        return result;
    }

    pub fn draw(self: FloatGenerator, case: *shell.TestCase) !f64 {
        const timer = case.startGeneration();
        defer case.finishGeneration(timer);
        return case.float(
            self.min,
            self.max,
            self.allow_nan,
            self.allow_infinity,
            self.smallest_nonzero,
        );
    }
};

pub fn floats() FloatGenerator {
    return .{};
}

/// Text over an alphabet, by default every Unicode scalar value. Values shrink
/// shortlex over the alphabet's shrink order — shorter first, then towards
/// '0', the digits, and the uppercase letters — so a minimal failing string is
/// one a reader can retype.
pub const TextGenerator = struct {
    min: usize = 0,
    max: ?usize = null,
    letters: ?[]const u8 = null,

    pub fn minSize(self: TextGenerator, value: usize) TextGenerator {
        var result = self;
        result.min = value;
        return result;
    }

    pub fn maxSize(self: TextGenerator, value: usize) TextGenerator {
        var result = self;
        result.max = value;
        return result;
    }

    /// Restrict the characters drawn to an interval set built by
    /// shell.alphabet or shell.alphabetRange.
    pub fn alphabet(self: TextGenerator, characters: []const u8) TextGenerator {
        var result = self;
        result.letters = characters;
        return result;
    }

    pub fn draw(self: TextGenerator, case: *shell.TestCase) ![]const u8 {
        const timer = case.startGeneration();
        defer case.finishGeneration(timer);
        const limit = self.max orelse @as(usize, @intCast(core.text_widened_max(self.min)));
        return case.string(self.min, limit, self.letters);
    }
};

pub fn text() TextGenerator {
    return .{};
}

/// A variable-length list of values drawn from one element generator.
pub fn ListGenerator(comptime T: type, comptime Element: type) type {
    return struct {
        element: Element,
        min: usize = 0,
        max: ?usize = null,

        const Self = @This();

        pub fn minSize(self: Self, value: usize) Self {
            var result = self;
            result.min = value;
            return result;
        }

        pub fn maxSize(self: Self, value: usize) Self {
            var result = self;
            result.max = value;
            return result;
        }

        pub fn draw(self: Self, case: *shell.TestCase) ![]const T {
            const timer = case.startGeneration();
            defer case.finishGeneration(timer);
            return case.collect(T, self.element, self.min, self.max, "list.element");
        }
    };
}

/// Generate a list whose elements each occupy a deletable span.
///
/// Unlike the scalar generators this one has structure the shrinker can
/// reduce: it deletes whole elements before it simplifies the values inside
/// them, so a failing list minimizes towards the shortest list that still
/// fails rather than towards small elements in a long list.
pub fn lists(comptime T: type, element: anytype) ListGenerator(T, @TypeOf(element)) {
    return .{ .element = element };
}

/// A variable-length collection whose elements are distinct under a key.
pub fn UniqueListGenerator(
    comptime T: type,
    comptime K: type,
    comptime Element: type,
) type {
    return struct {
        element: Element,
        key: *const fn (T) K,
        label: []const u8 = "list.element",
        min: usize = 0,
        max: ?usize = null,

        const Self = @This();

        pub fn minSize(self: Self, value: usize) Self {
            var result = self;
            result.min = value;
            return result;
        }

        pub fn maxSize(self: Self, value: usize) Self {
            var result = self;
            result.max = value;
            return result;
        }

        pub fn draw(self: Self, case: *shell.TestCase) ![]const T {
            const timer = case.startGeneration();
            defer case.finishGeneration(timer);
            return case.collectUnique(T, K, self.element, self.key, self.min, self.max, self.label);
        }
    };
}

/// Generate a collection whose elements have distinct keys.
///
/// A duplicate costs the element, not the example: the candidate's choices are
/// discarded and another is drawn. See `TestCase.collectUnique`.
pub fn uniqueLists(
    comptime T: type,
    comptime K: type,
    element: anytype,
    key: *const fn (T) K,
) UniqueListGenerator(T, K, @TypeOf(element)) {
    return .{ .element = element, .key = key };
}

/// Generate a collection of distinct values.
///
/// Zig has no set type in the standard library's value vocabulary, so a set is a
/// slice whose elements are pairwise distinct — which is also the shape the
/// shrinker can delete elements from.
pub fn sets(comptime T: type, element: anytype) UniqueListGenerator(T, T, @TypeOf(element)) {
    const identity = struct {
        fn call(value: T) T {
            return value;
        }
    }.call;
    return .{ .element = element, .key = identity, .label = "set.element" };
}

fn smallIntegers(min: i64, max: i64) IntegerGenerator {
    return integers().minValue(min).maxValue(max);
}

// ---- scalars, constants, and combinators ----
//
// None of the wrappers below records a choice of its own — only SampledFrom
// and OneOf do, and each records exactly one integer — so composing them
// leaves the reproduce blob byte-compatible with the other packages.
//
// A generator here is any struct with a `draw` method, checked at comptime, so
// the combinators are generic over the source's type rather than over a trait.

pub const BooleanGenerator = struct {
    pub fn draw(_: BooleanGenerator, case: *shell.TestCase) !bool {
        return case.boolean();
    }
};

/// Generate booleans, shrinking towards false.
pub fn booleans() BooleanGenerator {
    return .{};
}

pub const WeightedBooleanGenerator = struct {
    probability: f64,

    pub fn draw(self: WeightedBooleanGenerator, case: *shell.TestCase) !bool {
        if (!std.math.isFinite(self.probability) or self.probability < 0.0 or self.probability > 1.0) {
            return error.InvalidProbability;
        }
        return case.weighted(self.probability);
    }
};

/// Generate booleans that are true with the given probability. Recorded as
/// an ordinary boolean choice: the weight biases generation only, so a blob
/// replays the same whatever probability produced it.
pub fn weightedBooleans(probability: f64) WeightedBooleanGenerator {
    return .{ .probability = probability };
}

pub const BytesGenerator = struct {
    min: usize = 0,
    max: usize = 16,

    pub fn minSize(self: BytesGenerator, value: usize) BytesGenerator {
        var result = self;
        result.min = value;
        return result;
    }

    pub fn maxSize(self: BytesGenerator, value: usize) BytesGenerator {
        var result = self;
        result.max = value;
        return result;
    }

    pub fn draw(self: BytesGenerator, case: *shell.TestCase) ![]const u8 {
        return case.bytes(self.min, self.max);
    }
};

/// Generate byte strings, shrinking towards shorter and lower values.
pub fn binary() BytesGenerator {
    return .{};
}

/// Always produces one value, recording no choice.
pub fn JustGenerator(comptime T: type) type {
    return struct {
        value: T,

        pub fn draw(self: @This(), _: *shell.TestCase) !T {
            return self.value;
        }
    };
}

/// Always produce one value, recording no choice.
pub fn just(comptime T: type, value: T) JustGenerator(T) {
    return .{ .value = value };
}

/// Always produce null. Zig spells the other packages' `none()` as an optional,
/// since it has no null of its own.
pub fn none(comptime T: type) JustGenerator(?T) {
    return .{ .value = null };
}

/// One of a fixed sequence, shrinking towards the first element.
pub fn SampledGenerator(comptime T: type) type {
    return struct {
        values: []const T,

        pub fn draw(self: @This(), case: *shell.TestCase) !T {
            // A real integer choice, so the index shrinks and replays like any
            // other.
            const index = try case.integer(0, @intCast(self.values.len - 1), 0);
            return self.values[@intCast(index)];
        }
    };
}

/// Pick one of a fixed sequence, shrinking towards the first element.
pub fn sampledFrom(comptime T: type, values: []const T) SampledGenerator(T) {
    return .{ .values = values };
}

/// One of several generators, shrinking towards the first.
pub fn OneOfGenerator(comptime T: type, comptime Element: type) type {
    return struct {
        choices: []const Element,

        pub fn draw(self: @This(), case: *shell.TestCase) !T {
            const index = try case.integer(0, @intCast(self.choices.len - 1), 0);
            return self.choices[@intCast(index)].draw(case);
        }
    };
}

/// Draw from one of several generators, shrinking towards the first. They
/// share one type, which is what lets them live in a slice.
pub fn oneOf(comptime T: type, choices: anytype) OneOfGenerator(T, @TypeOf(choices[0])) {
    return .{ .choices = choices };
}

/// Two generators drawn in order, paired. Zig has no variadic type parameters,
/// so tuples are built by nesting rather than by a variadic `tuples(..)`, and
/// both drawn types are named rather than inferred from the sources.
pub fn PairGenerator(comptime T: type, comptime U: type, comptime A: type, comptime B: type) type {
    return struct {
        first: A,
        second: B,

        pub const Value = struct { first: T, second: U };

        pub fn draw(self: @This(), case: *shell.TestCase) !Value {
            const a = try self.first.draw(case);
            const b = try self.second.draw(case);
            return .{ .first = a, .second = b };
        }
    };
}

/// Draw two generators in order and pair the values.
pub fn pair(comptime T: type, comptime U: type, first: anytype, second: anytype) PairGenerator(T, U, @TypeOf(first), @TypeOf(second)) {
    return .{ .first = first, .second = second };
}

/// Applies a function to each value a generator draws.
pub fn MappedGenerator(comptime U: type, comptime Source: type, comptime transform: anytype) type {
    return struct {
        source: Source,

        pub fn draw(self: @This(), case: *shell.TestCase) !U {
            return transform(try self.source.draw(case));
        }
    };
}

/// Apply a function to each value a generator draws. The transform is comptime
/// so the result type is known without naming it.
pub fn map(comptime U: type, source: anytype, comptime transform: anytype) MappedGenerator(U, @TypeOf(source), transform) {
    return .{ .source = source };
}

/// Builds the next generator from each drawn value — monadic bind.
pub fn FlatMappedGenerator(comptime U: type, comptime Source: type, comptime transform: anytype) type {
    return struct {
        source: Source,

        pub fn draw(self: @This(), case: *shell.TestCase) !U {
            _ = case.startSpan("flat_map");
            // An open span is closed for us when the execution unwinds.
            const value = try self.source.draw(case);
            const result = try transform(value).draw(case);
            case.stopSpan(false);
            return result;
        }
    };
}

/// Build the next generator from each drawn value — monadic bind. Both draws
/// share one "flat_map" span, so the shrinker can delete or simplify the
/// whole unit together: shrinking the source value changes which inner
/// generator runs, and the inner draws replay or pun by the ordinary prefix
/// rules. The transform is comptime so the result type is known without
/// naming it.
pub fn flatMap(comptime U: type, source: anytype, comptime transform: anytype) FlatMappedGenerator(U, @TypeOf(source), transform) {
    return .{ .source = source };
}

/// Keeps only values satisfying a predicate.
pub fn FilteredGenerator(comptime T: type, comptime Source: type, comptime predicate: anytype) type {
    return struct {
        source: Source,

        pub fn draw(self: @This(), case: *shell.TestCase) !T {
            // The attempt budget is the same one a unique collection spends per
            // element, so it comes from ir/many.zir rather than a constant here.
            var attempts: u64 = 0;
            while (core.filter_retry_allowed(attempts)) {
                const value = try self.source.draw(case);
                attempts += 1;
                if (predicate(value)) return value;
            }
            // A rejection discards the example rather than failing the property.
            try case.assume(false);
            return error.AssumptionRejected;
        }
    };
}

/// Keep only values satisfying a predicate, rejecting the example if a bounded
/// number of attempts all fail it.
pub fn filter(comptime T: type, source: anytype, comptime predicate: anytype) FilteredGenerator(T, @TypeOf(source), predicate) {
    return .{ .source = source };
}

/// A generator assembled by a function that draws as it goes.
pub fn CompositeGenerator(comptime T: type, comptime build: anytype) type {
    return struct {
        pub fn draw(_: @This(), case: *shell.TestCase) !T {
            return build(case);
        }
    };
}

/// Build a generator from a function that draws as it goes. Zig already hands
/// the test case to a property, so the natural spelling takes it directly
/// rather than the draw callback the dynamic packages use.
pub fn composite(comptime T: type, comptime build: anytype) CompositeGenerator(T, build) {
    return .{};
}

/// Generator for bounded recursively-defined values.
pub fn RecursiveGenerator(comptime T: type, comptime Leaf: type, comptime branch: anytype) type {
    return struct {
        leaf: Leaf,
        max_depth: u64 = 32,
        max_leaves: u64 = 100,

        const Self = @This();
        const OpenBranch = struct { depth: u64, children: u64 };
        const State = struct {
            max_depth: u64,
            max_leaves: u64,
            target: u64,
            attempt: u64 = 0,
            leaves: u64 = 0,
            start_price: f64,
            closed_children: u64 = 0,
            closed_branches: u64 = 0,
            open_branches: std.ArrayList(OpenBranch) = .empty,
            reprices: u64 = 0,

            fn observeDecision(self: *State, depth: u64) void {
                while (self.open_branches.items.len != 0 and
                    self.open_branches.items[self.open_branches.items.len - 1].depth >= depth)
                {
                    const closed = self.open_branches.pop().?;
                    self.closed_children += closed.children;
                    self.closed_branches += 1;
                }
                if (depth > 0 and self.open_branches.items.len != 0) {
                    self.open_branches.items[self.open_branches.items.len - 1].children += 1;
                }
            }

            fn closeBranches(self: *State) void {
                while (self.open_branches.pop()) |closed| {
                    self.closed_children += closed.children;
                    self.closed_branches += 1;
                }
            }
        };

        const Subtree = struct {
            owner: *const Self,
            state: *State,
            depth: u64,

            pub fn draw(self: Subtree, case: *shell.TestCase) anyerror!T {
                _ = case.startSpan("recursive");
                self.state.observeDecision(self.depth);
                const probability = core.recursive_decision_probability(
                    self.state.max_depth,
                    self.depth,
                    self.state.target,
                    self.state.attempt,
                    self.state.closed_children,
                    self.state.closed_branches,
                );
                const is_branch = if (self.depth >= self.state.max_depth)
                    try case.forcedBoolean(false)
                else
                    try case.weighted(probability);
                const value = if (is_branch) value: {
                    self.state.open_branches.append(allocator, .{
                        .depth = self.depth,
                        .children = 0,
                    }) catch unreachable;
                    const child = Subtree{
                        .owner = self.owner,
                        .state = self.state,
                        .depth = self.depth + 1,
                    };
                    break :value try branch(child).draw(case);
                } else value: {
                    if (self.state.leaves >= self.state.max_leaves) {
                        return error.RecursiveLeafBudget;
                    }
                    self.state.leaves += 1;
                    break :value try self.owner.leaf.draw(case);
                };
                if (self.depth != 0) case.stopSpan(false);
                return value;
            }
        };

        pub fn maxDepth(self: Self, value: u64) Self {
            var result = self;
            result.max_depth = value;
            return result;
        }

        pub fn maxLeaves(self: Self, value: u64) Self {
            if (value > std.math.maxInt(i64)) @panic("maxLeaves must fit signed 64 bits");
            var result = self;
            result.max_leaves = value;
            return result;
        }

        pub fn draw(self: Self, case: *shell.TestCase) !T {
            const timer = case.startGeneration();
            defer case.finishGeneration(timer);
            const base_depth = case.openSpanDepth();
            var target: u64 = 1;
            if (core.recursive_target_drawn(self.max_leaves) and
                try case.weighted(core.recursive_large_target_probability()))
            {
                target = @intCast(try case.integerUniform(2, @intCast(self.max_leaves), 0));
            }
            var state = State{
                .max_depth = self.max_depth,
                .max_leaves = self.max_leaves,
                .target = target,
                .start_price = core.recursive_priced_probability(0, 0, 0, target),
            };
            defer state.open_branches.deinit(allocator);
            while (true) {
                var over_budget = false;
                const value: T = (Subtree{
                    .owner = &self,
                    .state = &state,
                    .depth = 0,
                }).draw(case) catch |err| switch (err) {
                    error.RecursiveLeafBudget => value: {
                        over_budget = true;
                        break :value undefined;
                    },
                    else => return err,
                };
                if (over_budget) {
                    case.resetOpenSpansTo(base_depth);
                    state.open_branches.clearRetainingCapacity();
                    state.leaves = 0;
                    state.attempt += 1;
                    if (!core.recursive_retry_allowed(state.attempt)) {
                        try case.assume(false);
                        return error.AssumptionRejected;
                    }
                    state.start_price = core.recursive_priced_probability(
                        state.closed_children,
                        state.closed_branches,
                        state.attempt,
                        state.target,
                    );
                    continue;
                }
                state.closeBranches();
                if (!core.recursive_finish_mispriced(
                    state.max_depth,
                    state.target,
                    state.attempt,
                    state.leaves,
                    state.closed_children,
                    state.closed_branches,
                    state.start_price,
                    state.reprices,
                )) {
                    case.stopSpan(false);
                    return value;
                }
                case.resetOpenSpansTo(base_depth);
                state.leaves = 0;
                state.reprices += 1;
                state.start_price = core.recursive_priced_probability(
                    state.closed_children,
                    state.closed_branches,
                    state.attempt,
                    state.target,
                );
            }
        }
    };
}

/// Generate recursively-defined values such as trees or JSON documents.
pub fn recursive(comptime T: type, leaf: anytype, comptime branch: anytype) RecursiveGenerator(T, @TypeOf(leaf), branch) {
    return .{ .leaf = leaf };
}

fn RecursiveCountBranch(comptime Child: type) type {
    return struct {
        child: Child,

        pub fn draw(self: @This(), case: *shell.TestCase) !usize {
            return 1 + try self.child.draw(case) + try self.child.draw(case);
        }
    };
}

fn recursiveCountBranch(child: anytype) RecursiveCountBranch(@TypeOf(child)) {
    return .{ .child = child };
}

test "recursive binary trees obey depth and leaf bounds" {
    const property = struct {
        fn run(case: *shell.TestCase) !void {
            const trees = recursive(usize, just(usize, 1), recursiveCountBranch)
                .maxDepth(4)
                .maxLeaves(16);
            const nodes = try trees.draw(case);
            if (nodes > 31 or nodes % 2 == 0) return error.InvalidRecursiveTree;
        }
    }.run;
    try std.testing.expect((try shell.check(property, .{ .examples = 200, .seed = 17 })) == null);
}

test "a list shrinks by deleting elements" {
    const property = struct {
        fn run(case: *shell.TestCase) !void {
            const values = try lists(i64, smallIntegers(0, 1000)).draw(case);
            var total: i64 = 0;
            for (values) |value| total += value;
            if (total >= 50) return error.SumTooLarge;
        }
    }.run;
    const failure = (try shell.check(property, .{ .examples = 200, .seed = 7 })).?;
    const replay = struct {
        var output: *[]const i64 = undefined;
        fn run(case: *shell.TestCase) !void {
            output.* = try lists(i64, smallIntegers(0, 1000)).draw(case);
            return error.Replayed;
        }
    };
    var seen: []const i64 = &.{};
    replay.output = &seen;
    _ = (try shell.check(replay.run, .{ .reproduce = failure.blob })).?;
    // Not merely "shorter": the one element left is the smallest that fails.
    try std.testing.expectEqualSlices(i64, &[_]i64{50}, seen);
}

test "a list deletes an element from the middle" {
    const property = struct {
        fn run(case: *shell.TestCase) !void {
            const values = try lists(i64, smallIntegers(0, 10)).draw(case);
            for (values) |value| {
                if (value == 3) return error.FoundThree;
            }
        }
    }.run;
    const failure = (try shell.check(property, .{ .examples = 500, .seed = 3 })).?;
    const replay = struct {
        var output: *[]const i64 = undefined;
        fn run(case: *shell.TestCase) !void {
            output.* = try lists(i64, smallIntegers(0, 10)).draw(case);
            return error.Replayed;
        }
    };
    var seen: []const i64 = &.{};
    replay.output = &seen;
    _ = (try shell.check(replay.run, .{ .reproduce = failure.blob })).?;
    // Every element around the interesting one has to be deletable, not only
    // the trailing ones a truncating shrinker can drop.
    try std.testing.expectEqualSlices(i64, &[_]i64{3}, seen);
}

test "a bounded list respects its size bounds" {
    const property = struct {
        var lengths: *[5]bool = undefined;
        fn run(case: *shell.TestCase) !void {
            const values = try lists(i64, smallIntegers(0, 10)).minSize(2).maxSize(4).draw(case);
            try std.testing.expect(values.len >= 2 and values.len <= 4);
            lengths.*[values.len] = true;
        }
    };
    var lengths: [5]bool = @splat(false);
    property.lengths = &lengths;
    try std.testing.expect((try shell.check(property.run, .{ .examples = 200, .seed = 5 })) == null);
    var distinct: usize = 0;
    for (lengths) |present| {
        if (present) distinct += 1;
    }
    try std.testing.expect(distinct > 1);
}

test "a fixed-size list draws no length choice, and elements are spans" {
    const property = struct {
        var output: *[]const shell.ChoiceSpan = undefined;
        fn run(case: *shell.TestCase) !void {
            const values = try lists(i64, smallIntegers(0, 3)).minSize(2).maxSize(2).draw(case);
            try std.testing.expectEqual(@as(usize, 2), values.len);
            output.* = case.spans();
        }
    };
    var captured: []const shell.ChoiceSpan = &.{};
    property.output = &captured;
    try std.testing.expect((try shell.check(property.run, .{ .examples = 1, .seed = 1 })) == null);
    // One span per element plus the empty span of the iteration that stopped;
    // each element span is exactly the range deletion removes. Coinciding
    // bounds decide nothing, so the spans hold only the two element draws.
    try std.testing.expectEqual(@as(usize, 3), captured.len);
    try std.testing.expectEqual(@as(usize, 0), captured[0].start);
    try std.testing.expectEqual(@as(usize, 1), captured[0].end);
    try std.testing.expectEqual(@as(usize, 2), captured[2].start);
    try std.testing.expectEqual(@as(usize, 2), captured[2].end);
    try std.testing.expect(captured[2].discarded);
}

test "set elements are always distinct" {
    const property = struct {
        var longest: *usize = undefined;
        fn run(case: *shell.TestCase) !void {
            const values = try sets(i64, smallIntegers(0, 6)).maxSize(6).draw(case);
            for (values, 0..) |value, index| {
                for (values[index + 1 ..]) |other| {
                    try std.testing.expect(value != other);
                }
            }
            if (values.len > longest.*) longest.* = values.len;
        }
    };
    var longest: usize = 0;
    property.longest = &longest;
    try std.testing.expect((try shell.check(property.run, .{ .examples = 300, .seed = 3 })) == null);
    // That a set grew past one element at all is what proves the element loop
    // kept asking after a duplicate rather than stopping on the first one.
    try std.testing.expect(longest > 1);
}

test "duplicate candidates are discarded, not kept" {
    const property = struct {
        var output: *[]const shell.ChoiceSpan = undefined;
        fn run(case: *shell.TestCase) !void {
            // Two distinct values in the range and three requested elements, so
            // the third element is guaranteed to burn its candidates and reject.
            _ = try sets(i64, smallIntegers(0, 1)).maxSize(3).draw(case);
            output.* = case.spans();
        }
    };
    var captured: []const shell.ChoiceSpan = &.{};
    property.output = &captured;
    try std.testing.expect((try shell.check(property.run, .{ .examples = 1, .seed = 1 })) == null);
    var discarded = false;
    for (captured) |span| {
        if (span.discarded and span.end > span.start) discarded = true;
    }
    try std.testing.expect(discarded);
}

test "unsatisfiable uniqueness rejects rather than hanging" {
    const property = struct {
        fn run(case: *shell.TestCase) !void {
            // Four distinct values cannot come out of a two-value range.
            _ = try sets(i64, smallIntegers(0, 1)).minSize(4).draw(case);
            return error.Unreachable;
        }
    }.run;
    const outcome = shell.check(property, .{ .examples = 50, .seed = 1 });
    if (outcome) |failure| {
        try std.testing.expect(failure == null);
    } else |err| {
        try std.testing.expect(err == error.TooManyRejections or err == error.FilterTooMuch);
    }
}

test "the reject action matches the generated rule" {
    // The three actions, read straight off the compiled decision so the shell's
    // branch names cannot drift from what they dispatch on.
    try std.testing.expectEqual(@as(u64, 0), core.many_reject_action(1, 0, 0));
    try std.testing.expectEqual(@as(u64, 1), core.many_reject_action(4, 0, 0));
    try std.testing.expectEqual(@as(u64, 2), core.many_reject_action(4, 0, 1));
    try std.testing.expectEqual(@as(u64, 0), core.many_reject_action(4, 2, 0));
    try std.testing.expectEqual(@as(u64, 3), core.many_rejection_budget(0));
}

test "a unique collection judges distinctness on the key" {
    const residue = struct {
        fn call(value: i64) i64 {
            return @mod(value, 3);
        }
    }.call;
    const property = struct {
        var grew: *bool = undefined;
        fn run(case: *shell.TestCase) !void {
            const values = try uniqueLists(i64, i64, smallIntegers(0, 9), residue)
                .maxSize(6)
                .draw(case);
            for (values, 0..) |value, index| {
                for (values[index + 1 ..]) |other| {
                    try std.testing.expect(@mod(value, 3) != @mod(other, 3));
                }
            }
            if (values.len > 1) grew.* = true;
        }
    };
    var grew = false;
    property.grew = &grew;
    try std.testing.expect((try shell.check(property.run, .{ .examples = 200, .seed = 6 })) == null);
    try std.testing.expect(grew);
}

// The regression guard for the allocator this package hands the generated core.
//
// Nothing in the shell or the core frees, so resident memory tracks total
// allocation volume — and on a page-granular allocator every one of those
// allocations costs a whole page. That is how this package quietly reached 5.4 GB
// and 26 seconds for a run of 20,000 examples, which is a real user's run and not
// just a test artifact. It surfaced as an OOM in the conformance checker rather
// than as a failure here, because nothing here was watching memory at all.
//
// The bound is deliberately loose. It is not a performance target; it is the gap
// between packing allocations and spending a page on each, which for this
// workload is two orders of magnitude. Anything within the same order as today's
// figure passes.
test "a run's memory does not scale with the number of examples" {
    if (@import("builtin").os.tag != .linux) return error.SkipZigTest;

    const workload = struct {
        fn run(case: *shell.TestCase) !void {
            const values = try lists(i64, integers().minValue(0).maxValue(1_000_000))
                .maxSize(40)
                .draw(case);
            var total: i64 = 0;
            for (values) |value| total +%= value;
            _ = try text().minSize(1).maxSize(16).draw(case);
        }
    }.run;

    try std.testing.expect((try shell.check(workload, .{ .examples = 5000, .seed = 7 })) == null);

    // An absolute high-water mark rather than a before/after difference: maxrss
    // is per process, so a difference depends on how much the tests that ran
    // first had already leaked, and under the regression that baseline is itself
    // inflated enough to hide most of the growth.
    //
    // Measured here at 30 MB. The same suite with a page-granular allocator
    // reaches 334 MB by this point, so the bound sits about six times above
    // healthy and still catches the regression by more than double.
    const peak_kb: usize = @intCast(std.posix.getrusage(std.posix.rusage.SELF).maxrss);
    if (peak_kb > 192 * 1024) {
        std.debug.print(
            "resident memory reached {d} kB running 5,000 examples; see shell.setAllocator\n",
            .{peak_kb},
        );
        return error.MemoryScalesWithExampleCount;
    }
}

test "integer and text generators draw through the test case" {
    const property = struct {
        fn run(case: *shell.TestCase) !void {
            const value = try integers().minValue(10).maxValue(20).shrinkTowards(10).draw(case);
            try std.testing.expect(value >= 10 and value <= 20);
            const value_text = try text().minSize(2).maxSize(4).draw(case);
            // Sizes are in codepoints; the value is UTF-8, so its byte length
            // is only an upper bound on how many characters were drawn.
            const characters = try std.unicode.utf8CountCodepoints(value_text);
            try std.testing.expect(characters >= 2 and characters <= 4);
        }
    }.run;
    try std.testing.expect((try shell.check(property, .{ .examples = 10, .seed = 9 })) == null);
}

// An explicit shrinkTowards above max must clamp to max, not to min. Zig and Go
// used to fold this together with the "no target given" default and clamped to
// min instead. The blob is the same fixture the other six packages pin.
test "an out-of-range shrink target clamps to the nearer bound" {
    const cross_language_clamped_target = "AAEAAAAACgEAAAAK";
    const Probe = struct {
        var drawn: i64 = 0;
        fn run(case: *shell.TestCase) !void {
            drawn = try integers().minValue(0).maxValue(10).shrinkTowards(99).draw(case);
            return error.AlwaysFails;
        }
    };
    Probe.drawn = 0;
    const failure = (try shell.check(Probe.run, .{ .examples = 50, .seed = 7 })).?;
    try std.testing.expectEqual(@as(i64, 10), Probe.drawn);
    try std.testing.expectEqualStrings(cross_language_clamped_target, failure.blob);
}

// The catalogue combinators, pinned across every package. just and oneOf's
// chosen branch record no choice of their own, and sampledFrom and oneOf
// record exactly one integer each, so the blob is the check that all eight
// shells compose them identically.
const cross_language_catalogue = "AAMAAAABAQAKAQAAAAIACgEAAAAA";

const Catalogue = struct {
    var flag: bool = false;
    var pick: i64 = 0;
    var extra: i64 = 0;

    // oneOf's branches have to share a type, so both are the same struct with
    // a comptime tag rather than two different generator types.
    const Branch = struct {
        wide: bool,

        pub fn draw(self: Branch, case: *shell.TestCase) !i64 {
            if (!self.wide) return 0;
            return case.integer(1, 9, 0);
        }
    };

    fn drawAll(case: *shell.TestCase) !void {
        flag = try booleans().draw(case);
        pick = try sampledFrom(i64, &[_]i64{ 2, 3, 5, 7 }).draw(case);
        const branches = [_]Branch{ .{ .wide = false }, .{ .wide = true } };
        extra = try oneOf(i64, &branches).draw(case);
    }

    fn property(case: *shell.TestCase) !void {
        try drawAll(case);
        if (flag and pick >= 5) return error.FlaggedAndLarge;
    }

    fn replay(case: *shell.TestCase) !void {
        try drawAll(case);
        return error.Replayed;
    }
};

test "catalogue generators shrink and replay portably" {
    const failure = try shell.check(Catalogue.property, .{ .examples = 300, .seed = 1 });
    try std.testing.expect(failure != null);
    try std.testing.expectEqualStrings(cross_language_catalogue, failure.?.blob);

    Catalogue.flag = false;
    Catalogue.pick = 0;
    Catalogue.extra = 0;
    const replayed = try shell.check(Catalogue.replay, .{ .reproduce = failure.?.blob });
    try std.testing.expect(replayed != null);
    // oneOf shrinks towards its first branch, so the minimal example takes
    // just(0) rather than paying for an integer draw.
    try std.testing.expect(Catalogue.flag);
    try std.testing.expectEqual(@as(i64, 5), Catalogue.pick);
    try std.testing.expectEqual(@as(i64, 0), Catalogue.extra);
}

// flat_map, pinned across every package that has it. The drawn scale decides
// the inner generator's bounds, so the two draws only make sense together;
// the blob is the check that all nine shells compose and shrink the bind
// identically.
const cross_language_flat_map = "AXicY2IAAi5GBjjFCgABCgAe";

const FlatMapCase = struct {
    var seen: i64 = 0;

    // The transform's result must be one comptime-known type, so the inner
    // generator is a struct holding the drawn scale rather than a closure.
    const Inner = struct {
        scale: i64,

        pub fn draw(self: Inner, case: *shell.TestCase) !i64 {
            return integers().minValue(self.scale * 10).maxValue(self.scale * 10 + 100).draw(case);
        }
    };

    fn scaled(value: i64) Inner {
        return .{ .scale = value };
    }

    fn property(case: *shell.TestCase) !void {
        const value = try flatMap(i64, integers().minValue(0).maxValue(3), scaled).draw(case);
        if (value >= 5) return error.ValueReachedFive;
    }

    fn replay(case: *shell.TestCase) !void {
        seen = try flatMap(i64, integers().minValue(0).maxValue(3), scaled).draw(case);
        return error.Replayed;
    }
};

test "flat_map shrinks and replays portably" {
    const failure = try shell.check(FlatMapCase.property, .{ .examples = 300, .seed = 1 });
    try std.testing.expect(failure != null);
    try std.testing.expectEqualStrings(cross_language_flat_map, failure.?.blob);

    FlatMapCase.seen = 0;
    const replayed = try shell.check(FlatMapCase.replay, .{ .reproduce = failure.?.blob });
    try std.testing.expect(replayed != null);
    // The minimal example takes scale 0, then the smallest value the property
    // notices.
    try std.testing.expectEqual(@as(i64, 5), FlatMapCase.seen);
}

const MapFilter = struct {
    fn double(value: i64) i64 {
        return value * 2;
    }

    fn isEven(value: i64) bool {
        return @rem(value, 2) == 0;
    }

    fn property(case: *shell.TestCase) !void {
        const doubled = try map(i64, integers().minValue(0).maxValue(10), double).draw(case);
        const evens = try filter(i64, integers().minValue(0).maxValue(20), isEven).draw(case);
        if (@rem(doubled, 2) != 0 or @rem(evens, 2) != 0) return error.DrewOddValues;
    }
};

test "map and filter compose without recording a choice" {
    const failure = try shell.check(MapFilter.property, .{ .examples = 50, .seed = 3 });
    try std.testing.expect(failure == null);
}
