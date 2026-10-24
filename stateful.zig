const std = @import("std");
const core = @import("zizek_gen.zig");
const shell = @import("shell.zig");

/// How many successful rules a stateful case runs unless `runSteps` is told
/// otherwise.
pub const default_step_count: u64 = 50;

/// Chance a free per-step "stop here?" boolean comes up true under the stop
/// protocols (1 and 2), which only a replay of an older blob still records, and
/// which a probe extends from the RNG once that blob runs out. New cases record
/// a "continue?" boolean instead, at `stateful_continue_probability()`.
const stop_probability: f64 = 1.0 / 65536.0;

const FeatureFlags = struct {
    probability: f64,
    disabled: []?bool,
    candidates: []bool,
    candidate_count: u64,

    fn init(case: *shell.TestCase, rule_count: usize) !FeatureFlags {
        const raw = if (case.replay != null)
            try case.integer(0, 254, 0)
        else
            try case.forcedInteger(@intCast(core.stateful_feature_generation_raw()));
        const disabled = shell.allocator.alloc(?bool, rule_count) catch unreachable;
        @memset(disabled, null);
        const candidates = shell.allocator.alloc(bool, rule_count) catch unreachable;
        @memset(candidates, true);
        return .{
            .probability = core.stateful_feature_probability(@intCast(raw)),
            .disabled = disabled,
            .candidates = candidates,
            .candidate_count = @intCast(rule_count),
        };
    }

    fn enabled(self: *FeatureFlags, case: *shell.TestCase, index: usize) !bool {
        _ = case.startSpan("stateful.feature_flag");
        const decided = self.disabled[index];
        const forced = core.stateful_feature_forced(
            self.candidate_count,
            self.candidates[index],
            decided != null,
            decided orelse false,
        );
        const disabled = blk: {
            if (forced) |value| break :blk case.forcedBoolean(value);
            break :blk case.weighted(self.probability);
        } catch |err| {
            case.stopSpan(false);
            return err;
        };
        self.disabled[index] = disabled;
        if (!disabled) {
            @memset(self.candidates, false);
            self.candidate_count = 0;
        }
        if (self.candidates[index]) {
            self.candidates[index] = false;
            self.candidate_count -= 1;
        }
        case.stopSpan(false);
        return !disabled;
    }
};

fn drawRuleIndex(case: *shell.TestCase, rule_count: usize) !usize {
    return @intCast(try case.integer(0, @intCast(rule_count - 1), 0));
}

fn selectRule(case: *shell.TestCase, rule_count: usize, maybe_flags: *?FeatureFlags) !usize {
    if (maybe_flags.* == null) maybe_flags.* = try FeatureFlags.init(case, rule_count);
    const flags = &maybe_flags.*.?;
    const known_bad = shell.allocator.alloc(bool, rule_count) catch unreachable;
    @memset(known_bad, false);
    var known_bad_count: u64 = 0;
    var attempt: u64 = 0;
    while (attempt < core.stateful_rule_probe_count()) : (attempt += 1) {
        // A probe — the rule index and the flag it consults — is one span, so
        // the shrinker can delete a probe that landed on a disabled rule
        // without misaligning the draws after it. A misaligned continue
        // decision reads as a stop, so that deletion is the one that reaches
        // the minimal sequence; the span tree is not part of the blob.
        _ = case.startSpan("stateful.rule_probe");
        const index = drawRuleIndex(case, rule_count) catch |err| {
            case.stopSpan(false);
            return err;
        };
        const enabled = !known_bad[index] and (flags.enabled(case, index) catch |err| {
            case.stopSpan(false);
            return err;
        });
        case.stopSpan(false);
        if (enabled) return index;
        if (!known_bad[index]) {
            known_bad[index] = true;
            known_bad_count += 1;
        }
    }

    const max_good = core.stateful_fallback_max_good(@intCast(rule_count), known_bad_count);
    const speculative: u64 = @intCast(try case.integer(0, @intCast(max_good - 1), 0));
    const allowed = shell.allocator.alloc(usize, rule_count) catch unreachable;
    var allowed_count: usize = 0;
    for (0..rule_count) |index| {
        if (known_bad[index]) continue;
        if (try flags.enabled(case, index)) {
            allowed[allowed_count] = index;
            allowed_count += 1;
            if (core.stateful_fallback_accept(@intCast(allowed_count), speculative)) {
                return @intCast(try case.forcedInteger(@intCast(index)));
            }
        }
    }
    const offset: usize = @intCast(try case.integer(0, @intCast(allowed_count - 1), 0));
    return @intCast(try case.forcedInteger(@intCast(allowed[offset])));
}

pub fn Rule(comptime M: type) type {
    return struct {
        name: []const u8,
        apply: *const fn (*M, *shell.TestCase) anyerror!void,
    };
}

pub fn Machine(comptime M: type) type {
    return struct {
        rules: []const Rule(M),
        invariants: []const Rule(M) = &.{},
    };
}

fn checkInvariants(state: anytype, invariants: anytype, case: *shell.TestCase) !void {
    for (invariants) |invariant| {
        case.note(std.fmt.allocPrint(shell.allocator, "invariant: {s}", .{invariant.name}) catch unreachable);
        try invariant.apply(state, case);
    }
}

/// Draw one round's decision and report whether the case stops. Protocol 3
/// records "continue?"; protocols 1 and 2 recorded "stop here?", and a replay
/// of one of their blobs keeps drawing that.
fn stopDecision(case: *shell.TestCase, protocol: u64, steps_drawn: u64, steps_rejected: u64, step_count: u64) !bool {
    if (protocol == 3) {
        if (core.stateful_continue_forced(steps_drawn, steps_rejected, step_count)) |forced| {
            return !(try case.forcedBoolean(forced));
        }
        return !(try case.weighted(core.stateful_continue_probability()));
    }
    if (core.stateful_stop_forced(steps_drawn, steps_rejected, step_count)) |forced| {
        return case.forcedBoolean(forced);
    }
    return case.weighted(stop_probability);
}

/// Execute registered rules for `default_step_count` successful steps.
pub fn run(state: anytype, machine: anytype, case: *shell.TestCase) !void {
    return runSteps(state, machine, case, default_step_count);
}

/// Execute registered rules for at most `step_count` successful steps, with
/// initial and post-rule invariant checks.
///
/// The case runs at least one step and at most `step_count` successful ones.
/// There is no step budget drawn up front: before each step the case draws one
/// "continue?" boolean, which `stateful_continue_forced` either forces or
/// leaves to the choice stream. Its simplest value stops, so the simplest case
/// runs exactly one step and the shrinker can end a run at any step by lowering
/// one boolean. A rule that rejects via `assume` spends an attempt but not a
/// step, so a machine with selective assumptions still gets its full run.
///
/// A replayed blob recorded before the decision was inverted draws a "stop
/// here?" boolean instead; `stateful_choice_protocol` tells them apart.
pub fn runSteps(state: anytype, machine: anytype, case: *shell.TestCase, step_count: u64) !void {
    try case.assume(machine.rules.len != 0);
    case.note("initial invariant check");
    try checkInvariants(state, machine.invariants, case);

    var steps_drawn: u64 = 0;
    var steps_rejected: u64 = 0;
    // Generation and the simplest probe record protocol 3. The probe used to
    // record the legacy protocol, whose stream the sniffer reads back as
    // protocol 2 whenever the first rule's first draw is an integer, so its
    // failures did not replay.
    const protocol: u64 = if (case.replay) |raw| core.stateful_choice_protocol(raw, case.position, case.remaining) else 3;
    // The first decision, which is forced, and the feature probability sit
    // before any step's span; each step's span then holds its rule probes, the
    // rule's own draws, and the decision that follows it. That makes every
    // step, the first included, one span the shrinker can delete without
    // misaligning the steps after it. Upstream's span starts at the decision
    // instead, which leaves the first step undeletable here: deleting it takes
    // the forced decision and the probability with it, and a misread decision
    // stops the run. The span tree is not part of the blob.
    if (try stopDecision(case, protocol, steps_drawn, steps_rejected, step_count)) return;
    var feature_flags: ?FeatureFlags = if (protocol == 1) null else try FeatureFlags.init(case, machine.rules.len);

    while (true) {
        _ = case.startSpan("stateful.rule");
        const index = (if (feature_flags == null)
            drawRuleIndex(case, machine.rules.len)
        else
            selectRule(case, machine.rules.len, &feature_flags)) catch |err| {
            case.stopSpan(false);
            return err;
        };
        const rule = machine.rules[@intCast(index)];
        steps_drawn += 1;
        case.note(std.fmt.allocPrint(shell.allocator, "step {d}: {s}", .{ steps_drawn, rule.name }) catch unreachable);
        var rejected = false;
        rule.apply(state, case) catch |err| {
            if (err != error.AssumptionRejected) {
                case.stopSpan(false);
                return err;
            }
            steps_rejected += 1;
            rejected = true;
            case.note("rule rejected by assumption");
        };
        if (!rejected) checkInvariants(state, machine.invariants, case) catch |err| {
            case.stopSpan(false);
            return err;
        };
        const stop = stopDecision(case, protocol, steps_drawn, steps_rejected, step_count) catch |err| {
            case.stopSpan(false);
            return err;
        };
        case.stopSpan(rejected);
        if (stop) return;
    }
}

/// Execution-local pool of arbitrary host-language values.
///
/// A variable's identity is a *recorded* choice rather than a host-side
/// counter, and a draw from the pool records the identifier it selected rather
/// than a position in the live list. That is what lets the shrinker delete an
/// earlier addition without changing what every later draw refers to — see
/// `ir/stateful.zir`'s stable-identifier section. Before that, deleting one
/// addition renumbered every reference after it, so most deletions produced a
/// different rule sequence that no longer failed and shrinking stalled far
/// from minimal.
pub fn Pool(comptime T: type) type {
    return struct {
        /// Live identifiers in insertion order, alongside the values they
        /// name: `active.items[i]` is the identifier of `values.items[i]`.
        /// Only the identifier is ever recorded; the pairing is host-side
        /// bookkeeping the choice stream never sees.
        active: std.ArrayList(i64) = .empty,
        values: std.ArrayList(T) = .empty,

        const Self = @This();

        pub fn init(_: *shell.TestCase) Self {
            return .{};
        }

        pub fn len(self: *const Self) usize {
            return self.active.items.len;
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.active.items.len == 0;
        }

        /// Add a value under a freshly drawn identifier.
        ///
        /// Takes the case because adding is now a *draw*: the identifier is
        /// recorded in the choice stream rather than handed out by a host-side
        /// counter, which is what lets a later reference to this variable keep
        /// meaning this variable when an earlier addition is shrunk away.
        pub fn add(self: *Self, case: *shell.TestCase, value: T) !void {
            const variable_id = try case.freshId();
            self.active.append(shell.allocator, variable_id) catch unreachable;
            self.values.append(shell.allocator, value) catch unreachable;
        }

        /// Where a live identifier sits, or null once the pool has let it go.
        fn positionOf(self: *const Self, variable_id: i64) ?usize {
            for (self.active.items, 0..) |active_id, position| {
                if (active_id == variable_id) return position;
            }
            return null;
        }

        /// Draw a live pool value without removing it.
        pub fn reusable(self: *Self, case: *shell.TestCase) !T {
            try case.assume(!self.isEmpty());
            const variable_id = try case.fromSet(self.active.items);
            const position = self.positionOf(variable_id) orelse return error.UnknownPoolIdentifier;
            return self.values.items[position];
        }

        /// Draw a live pool value and remove it.
        pub fn consumed(self: *Self, case: *shell.TestCase) !T {
            try case.assume(!self.isEmpty());
            const variable_id = try case.fromSet(self.active.items);
            const position = self.positionOf(variable_id) orelse return error.UnknownPoolIdentifier;
            _ = self.active.orderedRemove(position);
            return self.values.orderedRemove(position);
        }
    };
}

test "pools are reusable and consumable" {
    const property = struct {
        fn run(case: *shell.TestCase) !void {
            var values = Pool([]const u8).init(case);
            try values.add(case, "old");
            try values.add(case, "new");
            const reused = try values.reusable(case);
            try std.testing.expect(std.mem.eql(u8, reused, "old") or std.mem.eql(u8, reused, "new"));
            _ = try values.consumed(case);
            try std.testing.expectEqual(@as(usize, 1), values.len());
        }
    }.run;
    try std.testing.expect((try shell.check(property, .{ .examples = 20, .seed = 11 })) == null);
}

var pool_drawn: [2][]const u8 = .{ "", "" };

fn poolIdentityProperty(case: *shell.TestCase) !void {
    var values = Pool([]const u8).init(case);
    const names = [_][]const u8{ "a", "b", "c" };
    for (names) |name| try values.add(case, name);
    pool_drawn = .{ try values.reusable(case), try values.reusable(case) };
    return error.AlwaysFails;
}

// Adding to a pool draws a recorded identifier, and every reference replays
// onto the same value it named when recorded. Adding used to consume no choice
// at all and a reference used to be a reverse index into the live list, so the
// pool's whole identity scheme lived in host state the blob never saw. Both
// halves are now in the stream (`hegel-c` 0.32.4), which is what this pins: the
// identifier draws are real entries, and replaying the blob resolves the same
// variables rather than whatever now sits at those positions.
test "adding to a pool records an identifier that replays" {
    const failure = (try shell.check(poolIdentityProperty, .{ .examples = 1, .seed = 5 })).?;
    const raw = core.raw_failure_decode(failure.blob).?;
    // Three adds and two references: five recorded entries, where the old
    // encoding recorded only the two references.
    try std.testing.expectEqual(@as(u64, 5), core.choice_stream_count(raw));

    const recorded = pool_drawn;
    pool_drawn = .{ "", "" };
    _ = (try shell.check(poolIdentityProperty, .{ .reproduce = failure.blob })).?;
    try std.testing.expectEqualStrings(recorded[0], pool_drawn[0]);
    try std.testing.expectEqualStrings(recorded[1], pool_drawn[1]);
}

// The minimal failure of ThirdA under the continue protocol, and the same
// failure as the stop protocol recorded it before the decision was inverted.
const stateful_third_a_failure = "AXichYgxCgAACIR0Dfr/dyOC1nNRbEApWU5+mM8ADpIAZA==";
const stateful_third_a_stop_protocol = "AXiclcaxDQAACMMwd0Xi/3dh4QCGKG6E2tzywQAOIgBh";
// ThirdA's failure behind one integer drawn before the machine starts.
const stateful_draw_before_third_a_failure = "AXicfYmxDQAACMLs6uD/56qJTiQwEGgrJsk23PgvwpAGEhwAcA==";

/// One rule that draws one integer: the smallest machine a step count can
/// make large.
const Pusher = struct {
    pushed: usize = 0,

    fn push(self: *Pusher, case: *shell.TestCase) !void {
        _ = try case.integer(0, 10, 0);
        self.pushed += 1;
    }
};

/// Rule "a" fails on its third run. Both rules draw an integer first, which is
/// what made the legacy stream read back as protocol 2. `seen` holds the first
/// rules run, one letter each.
const ThirdA = struct {
    seen: [16]u8 = undefined,
    seen_len: usize = 0,
    a_runs: usize = 0,

    fn record(self: *ThirdA, name: u8) void {
        if (self.seen_len < self.seen.len) {
            self.seen[self.seen_len] = name;
            self.seen_len += 1;
        }
    }

    fn a(self: *ThirdA, case: *shell.TestCase) !void {
        _ = try case.integer(0, 10, 0);
        self.record('a');
        self.a_runs += 1;
        if (self.a_runs >= 3) return error.ARanThreeTimes;
    }

    fn b(self: *ThirdA, case: *shell.TestCase) !void {
        _ = try case.integer(0, 10, 0);
        self.record('b');
    }
};

const third_a_rules = [_]Rule(ThirdA){
    .{ .name = "a", .apply = ThirdA.a },
    .{ .name = "b", .apply = ThirdA.b },
};
var third_a_last: ThirdA = .{};

fn thirdAProperty(case: *shell.TestCase) !void {
    third_a_last = .{};
    try run(&third_a_last, Machine(ThirdA){ .rules = &third_a_rules }, case);
}

/// ThirdA behind one integer drawn first, as a property that draws its own
/// configuration before running the machine does.
fn thirdAAfterDrawProperty(case: *shell.TestCase) !void {
    _ = try case.integer(0, 10, 0);
    try thirdAProperty(case);
}

/// The rules a ThirdA blob runs, asserting that it fails.
fn replayThirdA(blob: []const u8) ![]const u8 {
    _ = (try shell.check(thirdAProperty, .{ .reproduce = blob })) orelse return error.DidNotFail;
    return third_a_last.seen[0..third_a_last.seen_len];
}

var pusher_counts: [4]usize = undefined;
var pusher_runs: usize = 0;

fn pusherProperty(case: *shell.TestCase) !void {
    var state = Pusher{};
    const rules = [_]Rule(Pusher){.{ .name = "push", .apply = Pusher.push }};
    defer {
        if (pusher_runs < pusher_counts.len) pusher_counts[pusher_runs] = state.pushed;
        pusher_runs += 1;
    }
    try runSteps(&state, Machine(Pusher){ .rules = &rules }, case, 5000);
}

// The per-step continue decision (`hegel-c` 0.36.1). The next three tests run
// with the same constants in every shell's test file, because the shared
// shell-case table has no way to describe a machine.

// The simplest value of a continue decision stops. Under the old stop decision
// the all-simplest probe ran every one of its steps, so a one-rule machine at
// 5000 steps overran the choice budget and failed the large_base_example
// health check (upstream #433). With one example the probe is the only case
// the run executes.
test "the simplest probe runs one step under a large step count" {
    pusher_runs = 0;
    try std.testing.expect((try shell.check(pusherProperty, .{ .examples = 1, .seed = 1 })) == null);
    try std.testing.expectEqual(@as(usize, 1), pusher_runs);
    try std.testing.expectEqual(@as(usize, 1), pusher_counts[0]);
}

// A failure the simplest probe cannot reach shrinks and replays. The probe used
// to record the legacy protocol, which the sniffer reads back as protocol 2
// once a rule draws an integer first, so this run failed with "shrunk example
// no longer fails". Every shell converges on the same three-step stream, so the
// blob is pinned.
test "a third-run failure shrinks to three steps and replays" {
    const failure = (try shell.check(thirdAProperty, .{ .examples = 100, .seed = 1 })) orelse
        return error.DidNotFail;
    const raw = core.raw_failure_decode(failure.blob).?;
    try std.testing.expectEqual(@as(u64, 3), core.stateful_choice_protocol(raw, 4, core.choice_stream_count(raw)));
    try std.testing.expectEqualStrings(stateful_third_a_failure, failure.blob);
    try std.testing.expectEqualStrings("aaa", try replayThirdA(failure.blob));
}

// A draw before the machine starts is not read as the machine's own. The
// protocol sniffer used to read the head of the stream, so the leading integer
// made a continue-protocol stream look like a stop-protocol one: the replay
// inverted every decision and stopped after one step, the shrinker reported the
// failure as flaky, and the blob it printed did not reproduce.
test "a draw before the machine shrinks and replays" {
    const failure = (try shell.check(thirdAAfterDrawProperty, .{ .examples = 100, .seed = 1 })) orelse
        return error.DidNotFail;
    try std.testing.expectEqualStrings(stateful_draw_before_third_a_failure, failure.blob);
    _ = (try shell.check(thirdAAfterDrawProperty, .{ .reproduce = failure.blob })) orelse
        return error.DidNotFail;
    try std.testing.expectEqualStrings("aaa", third_a_last.seen[0..third_a_last.seen_len]);
}

// A continue-protocol blob replays in every shell, and blobs recorded under the
// stop decision keep their meaning. The shared ledger fixture is the other
// stop-protocol blob, gated by examples/ledger.zig.
test "pinned blobs of both protocols replay" {
    const pinned = [_]struct { blob: []const u8, protocol: u64 }{
        .{ .blob = stateful_third_a_failure, .protocol = 3 },
        .{ .blob = stateful_third_a_stop_protocol, .protocol = 2 },
    };
    for (pinned) |entry| {
        const raw = core.raw_failure_decode(entry.blob).?;
        try std.testing.expectEqual(entry.protocol, core.stateful_choice_protocol(raw, 4, core.choice_stream_count(raw)));
        try std.testing.expectEqualStrings("aaa", try replayThirdA(entry.blob));
    }
}
