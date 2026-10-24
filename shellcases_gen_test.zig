// Code generated from conformance/{draw_ops,shell_cases}.zir by emitter/emit.go; DO NOT EDIT.

const std = @import("std");

pub const DrawKind = enum { integer, string, collect_integer, collect_unique_integer, clone_triplet, duplicate_pair, declared_length, cost_workload, key_digest, keyed_replay, key_sequence, trivial_span, descendant_chain, keyed_deep_clone, raise_gate, probe_extend };
pub const RepeatCoverage = struct { floor: i64, copies: i64, percent: i64 };
pub const Predicate = union(enum) { gte: i64, lte: i64, two_bug: [2]i64, cost_first: [3]i64, key_digest: []const u8, keyed_both_gte: [3]i64, key_sequence: [2]i64, trivial_span: i64, descendant_chain: [2]i64, keyed_deep_clone: [2]i64, raise_gate: [2]i64, probe_extend: void, always_lt: i64, sometimes_gt: i64, cover_first: i64, cover_repeats: RepeatCoverage, cover_exclusive: i64, codepoints_gte: i64, repeated_not: []const u8, any_gte: i64, any_lte: i64, all_gte: i64, all_lte: i64, equal_nonzero: void, difference: i64, set_equal: [2]i64, sparse_multiple: [2]i64, declared_length: i64, fails_first: void };
pub const ExpectedOutcome = enum { shrinks, rejects, fails, passes, puns, same_bug, cost_order, digest, keyed_replay, sequence_stable, extends, coverage, coverage_at_least, flaky };

pub const Case = struct {
    draw_kind: DrawKind,
    min_size: usize,
    max_size: ?usize,
    lo: i64,
    hi: i64,
    alphabet: ?[]const u8,
    predicate: Predicate,
    examples: usize,
    max_rejections: usize,
    max_shrinks: usize,
    seed: u64,
    reproduce: ?[]const u8,
    require_label: ?[]const u8,
    outcome: ExpectedOutcome,
    expected: [8]i64,
    expected_count: usize,
    expected_text: []const u8,
};

pub fn resolve(kind: []const u8, fields: []const []const u8) !?Case {
    if (std.mem.eql(u8, kind, "PROBE_EXTEND")) {
        if (fields.len != 6) return error.InvalidShellCaseFields;
        const blob = fields[0];
        const lo = try std.fmt.parseInt(i64, fields[1], 10);
        const hi = try std.fmt.parseInt(i64, fields[2], 10);
        const expected = fields[3];
        const total = try std.fmt.parseInt(i64, fields[4], 10);
        const probe_seed = try std.fmt.parseInt(i64, fields[5], 10);
        return .{
            .draw_kind = .probe_extend,
            .min_size = @intCast(total),
            .max_size = null,
            .lo = lo,
            .hi = hi,
            .alphabet = blob,
            .predicate = .{ .probe_extend = {} },
            .examples = @intCast(0),
            .max_rejections = @intCast(0),
            .max_shrinks = @intCast(0),
            .seed = @intCast(probe_seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .extends,
            .expected = .{ 0, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 0,
            .expected_text = expected,
        };
    }
    if (std.mem.eql(u8, kind, "SHRINK_DESCENDANT")) {
        if (fields.len != 4) return error.InvalidShellCaseFields;
        const hi = try std.fmt.parseInt(i64, fields[0], 10);
        const threshold = try std.fmt.parseInt(i64, fields[1], 10);
        const seed = try std.fmt.parseInt(i64, fields[2], 10);
        const examples = try std.fmt.parseInt(i64, fields[3], 10);
        return .{
            .draw_kind = .descendant_chain,
            .min_size = 0,
            .max_size = null,
            .lo = 0,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .descendant_chain = .{ hi, threshold } },
            .examples = @intCast(examples),
            .max_rejections = @intCast(2000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .shrinks,
            .expected = .{ threshold, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 1,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "SHRINK_TRIVIAL")) {
        if (fields.len != 3) return error.InvalidShellCaseFields;
        const hi = try std.fmt.parseInt(i64, fields[0], 10);
        const seed = try std.fmt.parseInt(i64, fields[1], 10);
        const examples = try std.fmt.parseInt(i64, fields[2], 10);
        return .{
            .draw_kind = .trivial_span,
            .min_size = 0,
            .max_size = null,
            .lo = 0,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .trivial_span = hi },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .shrinks,
            .expected = .{ 1, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 4,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "KEY_SEQUENCE")) {
        if (fields.len != 5) return error.InvalidShellCaseFields;
        const lo = try std.fmt.parseInt(i64, fields[0], 10);
        const hi = try std.fmt.parseInt(i64, fields[1], 10);
        const seed = try std.fmt.parseInt(i64, fields[2], 10);
        const examples = try std.fmt.parseInt(i64, fields[3], 10);
        const expected_misses = try std.fmt.parseInt(i64, fields[4], 10);
        return .{
            .draw_kind = .key_sequence,
            .min_size = 0,
            .max_size = null,
            .lo = lo,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .key_sequence = .{ lo, hi } },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(1),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .sequence_stable,
            .expected = .{ expected_misses, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 1,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "KEYED_REPLAY")) {
        if (fields.len != 7) return error.InvalidShellCaseFields;
        const lo = try std.fmt.parseInt(i64, fields[0], 10);
        const hi = try std.fmt.parseInt(i64, fields[1], 10);
        const threshold = try std.fmt.parseInt(i64, fields[2], 10);
        const seed = try std.fmt.parseInt(i64, fields[3], 10);
        const examples = try std.fmt.parseInt(i64, fields[4], 10);
        const expected = try std.fmt.parseInt(i64, fields[5], 10);
        const expected_misses = try std.fmt.parseInt(i64, fields[6], 10);
        return .{
            .draw_kind = .keyed_replay,
            .min_size = 0,
            .max_size = null,
            .lo = lo,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .keyed_both_gte = .{ lo, hi, threshold } },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .keyed_replay,
            .expected = .{ expected, expected_misses, 0, 0, 0, 0, 0, 0 },
            .expected_count = 2,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "KEYED_DEEP_CLONE")) {
        if (fields.len != 4) return error.InvalidShellCaseFields;
        const depth = try std.fmt.parseInt(i64, fields[0], 10);
        const hi = try std.fmt.parseInt(i64, fields[1], 10);
        const seed = try std.fmt.parseInt(i64, fields[2], 10);
        const examples = try std.fmt.parseInt(i64, fields[3], 10);
        return .{
            .draw_kind = .keyed_deep_clone,
            .min_size = 0,
            .max_size = null,
            .lo = 0,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .keyed_deep_clone = .{ depth, hi } },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .shrinks,
            .expected = .{ hi, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 1,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "KEY_DIGEST")) {
        if (fields.len != 2) return error.InvalidShellCaseFields;
        const name = fields[0];
        const expected = fields[1];
        return .{
            .draw_kind = .key_digest,
            .min_size = 0,
            .max_size = null,
            .lo = 0,
            .hi = 0,
            .alphabet = name,
            .predicate = .{ .key_digest = name },
            .examples = @intCast(0),
            .max_rejections = @intCast(0),
            .max_shrinks = @intCast(0),
            .seed = @intCast(0),
            .reproduce = null,
            .require_label = null,
            .outcome = .digest,
            .expected = .{ 0, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 1,
            .expected_text = expected,
        };
    }
    if (std.mem.eql(u8, kind, "COST_FIRST")) {
        if (fields.len != 6) return error.InvalidShellCaseFields;
        const sites = try std.fmt.parseInt(i64, fields[0], 10);
        const bound = try std.fmt.parseInt(i64, fields[1], 10);
        const threshold = try std.fmt.parseInt(i64, fields[2], 10);
        const seed = try std.fmt.parseInt(i64, fields[3], 10);
        const examples = try std.fmt.parseInt(i64, fields[4], 10);
        const expected_faults = try std.fmt.parseInt(i64, fields[5], 10);
        return .{
            .draw_kind = .cost_workload,
            .min_size = 0,
            .max_size = null,
            .lo = sites,
            .hi = bound,
            .alphabet = null,
            .predicate = .{ .cost_first = .{ sites, bound, threshold } },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .cost_order,
            .expected = .{ expected_faults, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 1,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "TWO_BUG")) {
        if (fields.len != 6) return error.InvalidShellCaseFields;
        const lo = try std.fmt.parseInt(i64, fields[0], 10);
        const hi = try std.fmt.parseInt(i64, fields[1], 10);
        const a_threshold = try std.fmt.parseInt(i64, fields[2], 10);
        const b_value = try std.fmt.parseInt(i64, fields[3], 10);
        const seed = try std.fmt.parseInt(i64, fields[4], 10);
        const examples = try std.fmt.parseInt(i64, fields[5], 10);
        return .{
            .draw_kind = .integer,
            .min_size = 0,
            .max_size = null,
            .lo = lo,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .two_bug = .{ a_threshold, b_value } },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .same_bug,
            .expected = .{ 0, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 0,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "SHRINK_MIN")) {
        if (fields.len != 6) return error.InvalidShellCaseFields;
        const lo = try std.fmt.parseInt(i64, fields[0], 10);
        const hi = try std.fmt.parseInt(i64, fields[1], 10);
        const threshold = try std.fmt.parseInt(i64, fields[2], 10);
        const seed = try std.fmt.parseInt(i64, fields[3], 10);
        const examples = try std.fmt.parseInt(i64, fields[4], 10);
        const expected = try std.fmt.parseInt(i64, fields[5], 10);
        return .{
            .draw_kind = .integer,
            .min_size = 0,
            .max_size = null,
            .lo = lo,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .gte = threshold },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .shrinks,
            .expected = .{ expected, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 1,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "SHRINK_SPARSE")) {
        if (fields.len != 5) return error.InvalidShellCaseFields;
        const hi = try std.fmt.parseInt(i64, fields[0], 10);
        const period = try std.fmt.parseInt(i64, fields[1], 10);
        const dense = try std.fmt.parseInt(i64, fields[2], 10);
        const seed = try std.fmt.parseInt(i64, fields[3], 10);
        const examples = try std.fmt.parseInt(i64, fields[4], 10);
        return .{
            .draw_kind = .integer,
            .min_size = 0,
            .max_size = null,
            .lo = 0,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .sparse_multiple = .{ period, dense } },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .shrinks,
            .expected = .{ period, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 1,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "SHRINK_DECLARED_LEN")) {
        if (fields.len != 4) return error.InvalidShellCaseFields;
        const hi = try std.fmt.parseInt(i64, fields[0], 10);
        const threshold = try std.fmt.parseInt(i64, fields[1], 10);
        const seed = try std.fmt.parseInt(i64, fields[2], 10);
        const examples = try std.fmt.parseInt(i64, fields[3], 10);
        return .{
            .draw_kind = .declared_length,
            .min_size = @intCast(0),
            .max_size = @intCast(10),
            .lo = 0,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .declared_length = threshold },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .shrinks,
            .expected = .{ threshold, 1, 0, 0, 0, 0, 0, 0 },
            .expected_count = 2,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "SHRINK_GATE")) {
        if (fields.len != 4) return error.InvalidShellCaseFields;
        const hi = try std.fmt.parseInt(i64, fields[0], 10);
        const threshold = try std.fmt.parseInt(i64, fields[1], 10);
        const seed = try std.fmt.parseInt(i64, fields[2], 10);
        const examples = try std.fmt.parseInt(i64, fields[3], 10);
        return .{
            .draw_kind = .raise_gate,
            .min_size = 0,
            .max_size = null,
            .lo = 0,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .raise_gate = .{ hi, threshold } },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .shrinks,
            .expected = .{ threshold, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 2,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "SHRINK_LIST")) {
        if (fields.len != 6) return error.InvalidShellCaseFields;
        const lo = try std.fmt.parseInt(i64, fields[0], 10);
        const hi = try std.fmt.parseInt(i64, fields[1], 10);
        const threshold = try std.fmt.parseInt(i64, fields[2], 10);
        const seed = try std.fmt.parseInt(i64, fields[3], 10);
        const examples = try std.fmt.parseInt(i64, fields[4], 10);
        const expected = try std.fmt.parseInt(i64, fields[5], 10);
        return .{
            .draw_kind = .collect_integer,
            .min_size = @intCast(0),
            .max_size = null,
            .lo = lo,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .any_gte = threshold },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .shrinks,
            .expected = .{ expected, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 1,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "SHRINK_SET")) {
        if (fields.len != 6) return error.InvalidShellCaseFields;
        const lo = try std.fmt.parseInt(i64, fields[0], 10);
        const hi = try std.fmt.parseInt(i64, fields[1], 10);
        const threshold = try std.fmt.parseInt(i64, fields[2], 10);
        const seed = try std.fmt.parseInt(i64, fields[3], 10);
        const examples = try std.fmt.parseInt(i64, fields[4], 10);
        const expected = try std.fmt.parseInt(i64, fields[5], 10);
        return .{
            .draw_kind = .collect_unique_integer,
            .min_size = @intCast(0),
            .max_size = null,
            .lo = lo,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .any_gte = threshold },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .shrinks,
            .expected = .{ expected, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 1,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "SHRINK_CLONE")) {
        if (fields.len != 4) return error.InvalidShellCaseFields;
        const hi = try std.fmt.parseInt(i64, fields[0], 10);
        const threshold = try std.fmt.parseInt(i64, fields[1], 10);
        const seed = try std.fmt.parseInt(i64, fields[2], 10);
        const examples = try std.fmt.parseInt(i64, fields[3], 10);
        return .{
            .draw_kind = .clone_triplet,
            .min_size = 0,
            .max_size = null,
            .lo = 0,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .gte = threshold },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .shrinks,
            .expected = .{ 0, threshold, 0, 0, 0, 0, 0, 0 },
            .expected_count = 3,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "SHRINK_DUPLICATE")) {
        if (fields.len != 5) return error.InvalidShellCaseFields;
        const lo = try std.fmt.parseInt(i64, fields[0], 10);
        const hi = try std.fmt.parseInt(i64, fields[1], 10);
        const seed = try std.fmt.parseInt(i64, fields[2], 10);
        const examples = try std.fmt.parseInt(i64, fields[3], 10);
        const expected = try std.fmt.parseInt(i64, fields[4], 10);
        return .{
            .draw_kind = .duplicate_pair,
            .min_size = 0,
            .max_size = null,
            .lo = lo,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .equal_nonzero = {} },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .shrinks,
            .expected = .{ expected, expected, 0, 0, 0, 0, 0, 0 },
            .expected_count = 2,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "SHRINK_PAIR")) {
        if (fields.len != 7) return error.InvalidShellCaseFields;
        const lo = try std.fmt.parseInt(i64, fields[0], 10);
        const hi = try std.fmt.parseInt(i64, fields[1], 10);
        const gap = try std.fmt.parseInt(i64, fields[2], 10);
        const seed = try std.fmt.parseInt(i64, fields[3], 10);
        const examples = try std.fmt.parseInt(i64, fields[4], 10);
        const expected_first = try std.fmt.parseInt(i64, fields[5], 10);
        const expected_second = try std.fmt.parseInt(i64, fields[6], 10);
        return .{
            .draw_kind = .duplicate_pair,
            .min_size = 0,
            .max_size = null,
            .lo = lo,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .difference = gap },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .shrinks,
            .expected = .{ expected_first, expected_second, 0, 0, 0, 0, 0, 0 },
            .expected_count = 2,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "ALWAYS_SHRINK")) {
        if (fields.len != 6) return error.InvalidShellCaseFields;
        const lo = try std.fmt.parseInt(i64, fields[0], 10);
        const hi = try std.fmt.parseInt(i64, fields[1], 10);
        const threshold = try std.fmt.parseInt(i64, fields[2], 10);
        const seed = try std.fmt.parseInt(i64, fields[3], 10);
        const examples = try std.fmt.parseInt(i64, fields[4], 10);
        const expected = try std.fmt.parseInt(i64, fields[5], 10);
        return .{
            .draw_kind = .integer,
            .min_size = 0,
            .max_size = null,
            .lo = lo,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .always_lt = threshold },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .shrinks,
            .expected = .{ expected, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 1,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "SHRINK_REORDER")) {
        if (fields.len != 6) return error.InvalidShellCaseFields;
        const lo = try std.fmt.parseInt(i64, fields[0], 10);
        const hi = try std.fmt.parseInt(i64, fields[1], 10);
        const first = try std.fmt.parseInt(i64, fields[2], 10);
        const second = try std.fmt.parseInt(i64, fields[3], 10);
        const seed = try std.fmt.parseInt(i64, fields[4], 10);
        const examples = try std.fmt.parseInt(i64, fields[5], 10);
        return .{
            .draw_kind = .collect_integer,
            .min_size = @intCast(0),
            .max_size = null,
            .lo = lo,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .set_equal = .{ first, second } },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .shrinks,
            .expected = .{ first, second, 0, 0, 0, 0, 0, 0 },
            .expected_count = 2,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "SHRINK_TEXT")) {
        if (fields.len != 7) return error.InvalidShellCaseFields;
        const alphabet = fields[0];
        const min_size = try std.fmt.parseInt(i64, fields[1], 10);
        const max_size = try std.fmt.parseInt(i64, fields[2], 10);
        const threshold = try std.fmt.parseInt(i64, fields[3], 10);
        const seed = try std.fmt.parseInt(i64, fields[4], 10);
        const examples = try std.fmt.parseInt(i64, fields[5], 10);
        const expected = fields[6];
        return .{
            .draw_kind = .string,
            .min_size = @intCast(min_size),
            .max_size = @intCast(max_size),
            .lo = 0,
            .hi = 0,
            .alphabet = if (std.mem.eql(u8, alphabet, "-")) null else alphabet,
            .predicate = .{ .codepoints_gte = threshold },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .shrinks,
            .expected = .{ 0, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 1,
            .expected_text = expected,
        };
    }
    if (std.mem.eql(u8, kind, "SHRINK_CHARS")) {
        if (fields.len != 5) return error.InvalidShellCaseFields;
        const alphabet = fields[0];
        const simplest = fields[1];
        const expected = fields[2];
        const seed = try std.fmt.parseInt(i64, fields[3], 10);
        const examples = try std.fmt.parseInt(i64, fields[4], 10);
        return .{
            .draw_kind = .string,
            .min_size = @intCast(2),
            .max_size = @intCast(5),
            .lo = 0,
            .hi = 0,
            .alphabet = if (std.mem.eql(u8, alphabet, "-")) null else alphabet,
            .predicate = .{ .repeated_not = simplest },
            .examples = @intCast(examples),
            .max_rejections = @intCast(2000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .shrinks,
            .expected = .{ 0, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 1,
            .expected_text = expected,
        };
    }
    if (std.mem.eql(u8, kind, "UNIQUE_EXHAUSTED")) {
        if (fields.len != 5) return error.InvalidShellCaseFields;
        const lo = try std.fmt.parseInt(i64, fields[0], 10);
        const hi = try std.fmt.parseInt(i64, fields[1], 10);
        const min_size = try std.fmt.parseInt(i64, fields[2], 10);
        const seed = try std.fmt.parseInt(i64, fields[3], 10);
        const examples = try std.fmt.parseInt(i64, fields[4], 10);
        return .{
            .draw_kind = .collect_unique_integer,
            .min_size = @intCast(min_size),
            .max_size = null,
            .lo = lo,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .all_gte = lo },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .rejects,
            .expected = .{ 0, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 0,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "REPRODUCE_FAILS")) {
        if (fields.len != 4) return error.InvalidShellCaseFields;
        const blob = fields[0];
        const lo = try std.fmt.parseInt(i64, fields[1], 10);
        const hi = try std.fmt.parseInt(i64, fields[2], 10);
        const expected = try std.fmt.parseInt(i64, fields[3], 10);
        return .{
            .draw_kind = .integer,
            .min_size = 0,
            .max_size = null,
            .lo = lo,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .lte = hi },
            .examples = 0,
            .max_rejections = 0,
            .max_shrinks = 0,
            .seed = 0,
            .reproduce = blob,
            .require_label = null,
            .outcome = .fails,
            .expected = .{ expected, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 1,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "REPRODUCE_PASSES")) {
        if (fields.len != 3) return error.InvalidShellCaseFields;
        const blob = fields[0];
        const lo = try std.fmt.parseInt(i64, fields[1], 10);
        const hi = try std.fmt.parseInt(i64, fields[2], 10);
        return .{
            .draw_kind = .integer,
            .min_size = 0,
            .max_size = null,
            .lo = lo,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .gte = hi },
            .examples = 0,
            .max_rejections = 0,
            .max_shrinks = 0,
            .seed = 0,
            .reproduce = blob,
            .require_label = null,
            .outcome = .passes,
            .expected = .{ 0, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 0,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "PUN_REPORT")) {
        if (fields.len != 4) return error.InvalidShellCaseFields;
        const blob = fields[0];
        const lo = try std.fmt.parseInt(i64, fields[1], 10);
        const hi = try std.fmt.parseInt(i64, fields[2], 10);
        const expected_puns = try std.fmt.parseInt(i64, fields[3], 10);
        return .{
            .draw_kind = .integer,
            .min_size = 0,
            .max_size = null,
            .lo = lo,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .lte = hi },
            .examples = 0,
            .max_rejections = 0,
            .max_shrinks = 0,
            .seed = 0,
            .reproduce = blob,
            .require_label = null,
            .outcome = .puns,
            .expected = .{ expected_puns, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 1,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "SOMETIMES_MISSED")) {
        if (fields.len != 5) return error.InvalidShellCaseFields;
        const lo = try std.fmt.parseInt(i64, fields[0], 10);
        const hi = try std.fmt.parseInt(i64, fields[1], 10);
        const threshold = try std.fmt.parseInt(i64, fields[2], 10);
        const seed = try std.fmt.parseInt(i64, fields[3], 10);
        const examples = try std.fmt.parseInt(i64, fields[4], 10);
        return .{
            .draw_kind = .integer,
            .min_size = 0,
            .max_size = null,
            .lo = lo,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .sometimes_gt = threshold },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .coverage,
            .expected = .{ 0, examples, 0, 0, 0, 0, 0, 0 },
            .expected_count = 2,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "REQUIRE_MISSED")) {
        if (fields.len != 1) return error.InvalidShellCaseFields;
        const examples = try std.fmt.parseInt(i64, fields[0], 10);
        return .{
            .draw_kind = .integer,
            .min_size = 0,
            .max_size = null,
            .lo = 0,
            .hi = 0,
            .alphabet = null,
            .predicate = .{ .gte = 1 },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(1),
            .reproduce = null,
            .require_label = "unreached",
            .outcome = .coverage,
            .expected = .{ 0, examples, 0, 0, 0, 0, 0, 0 },
            .expected_count = 2,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "COVER_RATE")) {
        if (fields.len != 2) return error.InvalidShellCaseFields;
        const examples = try std.fmt.parseInt(i64, fields[0], 10);
        const percent = try std.fmt.parseInt(i64, fields[1], 10);
        return .{
            .draw_kind = .integer,
            .min_size = 0,
            .max_size = null,
            .lo = 0,
            .hi = 0,
            .alphabet = null,
            .predicate = .{ .cover_first = percent },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(1),
            .reproduce = null,
            .require_label = null,
            .outcome = .coverage,
            .expected = .{ 1, examples, 0, 0, 0, 0, 0, 0 },
            .expected_count = 2,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "COVER_STEERS")) {
        if (fields.len != 8) return error.InvalidShellCaseFields;
        const lo = try std.fmt.parseInt(i64, fields[0], 10);
        const hi = try std.fmt.parseInt(i64, fields[1], 10);
        const floor = try std.fmt.parseInt(i64, fields[2], 10);
        const copies = try std.fmt.parseInt(i64, fields[3], 10);
        const percent = try std.fmt.parseInt(i64, fields[4], 10);
        const seed = try std.fmt.parseInt(i64, fields[5], 10);
        const examples = try std.fmt.parseInt(i64, fields[6], 10);
        const min_observed = try std.fmt.parseInt(i64, fields[7], 10);
        return .{
            .draw_kind = .collect_integer,
            .min_size = @intCast(0),
            .max_size = null,
            .lo = lo,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .cover_repeats = .{ .floor = floor, .copies = copies, .percent = percent } },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .coverage_at_least,
            .expected = .{ min_observed, examples, 0, 0, 0, 0, 0, 0 },
            .expected_count = 2,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "RARE_STEERS")) {
        if (fields.len != 7) return error.InvalidShellCaseFields;
        const lo = try std.fmt.parseInt(i64, fields[0], 10);
        const hi = try std.fmt.parseInt(i64, fields[1], 10);
        const floor = try std.fmt.parseInt(i64, fields[2], 10);
        const copies = try std.fmt.parseInt(i64, fields[3], 10);
        const percent = try std.fmt.parseInt(i64, fields[4], 10);
        const seed = try std.fmt.parseInt(i64, fields[5], 10);
        const examples = try std.fmt.parseInt(i64, fields[6], 10);
        return .{
            .draw_kind = .collect_integer,
            .min_size = @intCast(0),
            .max_size = null,
            .lo = lo,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .cover_repeats = .{ .floor = floor, .copies = copies, .percent = percent } },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .passes,
            .expected = .{ 0, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 0,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "FLAKY_FAILURE")) {
        if (fields.len != 4) return error.InvalidShellCaseFields;
        const lo = try std.fmt.parseInt(i64, fields[0], 10);
        const hi = try std.fmt.parseInt(i64, fields[1], 10);
        const seed = try std.fmt.parseInt(i64, fields[2], 10);
        const examples = try std.fmt.parseInt(i64, fields[3], 10);
        return .{
            .draw_kind = .integer,
            .min_size = 0,
            .max_size = null,
            .lo = lo,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .fails_first = {} },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .flaky,
            .expected = .{ 0, 0, 0, 0, 0, 0, 0, 0 },
            .expected_count = 0,
            .expected_text = "",
        };
    }
    if (std.mem.eql(u8, kind, "STEER_KEEPS_RANDOM")) {
        if (fields.len != 6) return error.InvalidShellCaseFields;
        const lo = try std.fmt.parseInt(i64, fields[0], 10);
        const hi = try std.fmt.parseInt(i64, fields[1], 10);
        const percent = try std.fmt.parseInt(i64, fields[2], 10);
        const seed = try std.fmt.parseInt(i64, fields[3], 10);
        const examples = try std.fmt.parseInt(i64, fields[4], 10);
        const min_observed = try std.fmt.parseInt(i64, fields[5], 10);
        return .{
            .draw_kind = .collect_integer,
            .min_size = @intCast(0),
            .max_size = null,
            .lo = lo,
            .hi = hi,
            .alphabet = null,
            .predicate = .{ .cover_exclusive = percent },
            .examples = @intCast(examples),
            .max_rejections = @intCast(1000),
            .max_shrinks = @intCast(0),
            .seed = @intCast(seed),
            .reproduce = null,
            .require_label = null,
            .outcome = .coverage_at_least,
            .expected = .{ min_observed, examples, 0, 0, 0, 0, 0, 0 },
            .expected_count = 2,
            .expected_text = "",
        };
    }
    return null;
}
