const std = @import("std");
const core = @import("zizek_gen.zig");
// The generated conformance readers are modules that only the test build
// provides, so the public module never loads them.
const drawops = @import("drawops_gen_test");
const shellcases = @import("shellcases_gen_test");
const databasecases = @import("databasecases_gen_test");

/// The allocator this shell and the generated core allocate from.
///
/// Every generated function returns an owned slice and frees nothing — they are
/// pure, so a caller keeping a result must outlive the call and one discarding it
/// has no hook to free on — and the shell follows suit. Memory is therefore
/// reclaimed when the process exits, or when a caller installs an arena here and
/// resets it.
///
/// The default packs small allocations into shared blocks. A page-granular
/// allocator spends a whole page on each one, which is not a rounding detail at
/// this volume: over 20,000 examples drawing a list and some text it measured
/// 5.4 GB and 26 s against 41 MB and 0.17 s. See setAllocator.
pub var allocator: std.mem.Allocator = std.heap.smp_allocator;

/// Point this shell, its state machines, and the generated core at one
/// allocator.
///
/// Useful for an arena a long-running caller resets itself, or for a counting
/// allocator — `shell.zig`'s own memory-growth test installs one.
pub fn setAllocator(target: std.mem.Allocator) void {
    allocator = target;
    core.allocator = target;
}

/// What a rejected element costs a unique collection. Defined by
/// ir/many.zir::many_reject_action.
const reject_retry: u64 = 0;
const reject_stop: u64 = 1;
const reject_invalid: u64 = 2;

/// One part of a draw's name.
pub const KeyPart = union(enum) {
    text: []const u8,
    int: i64,
};

/// Hash a draw's name into the 64-bit key a stream records.
///
/// The encoding is compiled (ir/keys.zir), so the same name hashes identically
/// in every language: `zizek.key(&.{ .{ .text = "read" }, .{ .int = conn } })`.
pub fn keyFor(parts: []const KeyPart) u64 {
    return core.key_hash(keyEncode(parts));
}

/// The portable 16-lowercase-hex name used for database keys and entries.
pub fn databaseDigest(value: []const u8) []const u8 {
    return std.fmt.allocPrint(allocator, "{x:0>16}", .{core.key_hash(core.key_append_text(&.{}, value))}) catch unreachable;
}

/// Type-erased best-effort storage for raw serialized counterexample streams.
pub const Database = struct {
    context: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        fetch: *const fn (*anyopaque, []const u8) []const []const u8,
        save: *const fn (*anyopaque, []const u8, []const u8) void,
        delete: *const fn (*anyopaque, []const u8, []const u8) void,
    };

    pub fn init(pointer: anytype) Database {
        const Pointer = @TypeOf(pointer);
        const pointer_info = @typeInfo(Pointer);
        if (pointer_info != .pointer or pointer_info.pointer.size != .one) {
            @compileError("Database.init expects a single-item pointer");
        }
        const Wrapper = struct {
            fn target(context: *anyopaque) Pointer {
                return @ptrCast(@alignCast(context));
            }
            fn fetchImpl(context: *anyopaque, key: []const u8) []const []const u8 {
                return target(context).fetch(key);
            }
            fn saveImpl(context: *anyopaque, key: []const u8, value: []const u8) void {
                target(context).save(key, value);
            }
            fn deleteImpl(context: *anyopaque, key: []const u8, value: []const u8) void {
                target(context).delete(key, value);
            }
            const vtable = VTable{ .fetch = fetchImpl, .save = saveImpl, .delete = deleteImpl };
        };
        return .{ .context = pointer, .vtable = &Wrapper.vtable };
    }

    pub fn fetch(self: Database, key: []const u8) []const []const u8 {
        return self.vtable.fetch(self.context, key);
    }
    pub fn save(self: Database, key: []const u8, value: []const u8) void {
        self.vtable.save(self.context, key, value);
    }
    pub fn delete(self: Database, key: []const u8, value: []const u8) void {
        self.vtable.delete(self.context, key, value);
    }
};

/// Process-local example storage. Values are copied and duplicate saves are ignored.
pub const InMemoryDatabase = struct {
    entries: std.StringHashMap(std.ArrayList([]const u8)),

    pub fn init() InMemoryDatabase {
        return .{ .entries = std.StringHashMap(std.ArrayList([]const u8)).init(allocator) };
    }

    pub fn database(self: *InMemoryDatabase) Database {
        return Database.init(self);
    }

    pub fn fetch(self: *InMemoryDatabase, key: []const u8) []const []const u8 {
        const values = self.entries.getPtr(key) orelse return &.{};
        return values.items;
    }

    pub fn save(self: *InMemoryDatabase, key: []const u8, value: []const u8) void {
        if (self.entries.getPtr(key)) |values| {
            for (values.items) |entry| if (std.mem.eql(u8, entry, value)) return;
            values.append(allocator, allocator.dupe(u8, value) catch return) catch return;
            return;
        }
        const owned_key = allocator.dupe(u8, key) catch return;
        var values: std.ArrayList([]const u8) = .empty;
        values.append(allocator, allocator.dupe(u8, value) catch return) catch return;
        self.entries.put(owned_key, values) catch return;
    }

    pub fn delete(self: *InMemoryDatabase, key: []const u8, value: []const u8) void {
        const values = self.entries.getPtr(key) orelse return;
        for (values.items, 0..) |entry, at| {
            if (std.mem.eql(u8, entry, value)) {
                _ = values.orderedRemove(at);
                break;
            }
        }
        if (values.items.len == 0) _ = self.entries.remove(key);
    }
};

/// Filesystem example storage using `<root>/<key digest>/{.name,<value digest>}`.
pub const DirectoryDatabase = struct {
    root: std.Io.Dir,
    path: []const u8,

    pub fn init(path: []const u8) DirectoryDatabase {
        return .{ .root = .cwd(), .path = path };
    }

    /// Use an already-open directory as the database root. The caller owns it.
    pub fn initDir(root: std.Io.Dir) DirectoryDatabase {
        return .{ .root = root, .path = "." };
    }

    pub fn database(self: *DirectoryDatabase) Database {
        return Database.init(self);
    }

    fn io() std.Io {
        return std.Io.Threaded.global_single_threaded.io();
    }

    fn keyPath(self: *DirectoryDatabase, key: []const u8) []const u8 {
        return std.fs.path.join(allocator, &.{ self.path, databaseDigest(key) }) catch unreachable;
    }

    fn isEntry(name: []const u8) bool {
        if (name.len != 16) return false;
        for (name) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
        return true;
    }

    fn atomicWrite(directory: std.Io.Dir, name: []const u8, value: []const u8) void {
        var file = directory.createFileAtomic(io(), name, .{}) catch return;
        defer file.deinit(io());
        file.file.writeStreamingAll(io(), value) catch return;
        file.link(io()) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return,
        };
    }

    pub fn fetch(self: *DirectoryDatabase, key: []const u8) []const []const u8 {
        var directory = self.root.openDir(io(), self.keyPath(key), .{ .iterate = true }) catch return &.{};
        defer directory.close(io());
        var values: std.ArrayList([]const u8) = .empty;
        var entries = directory.iterate();
        while (entries.next(io()) catch return values.items) |entry| {
            if (!isEntry(entry.name)) continue;
            const value = directory.readFileAlloc(io(), entry.name, allocator, .unlimited) catch continue;
            values.append(allocator, value) catch return values.items;
        }
        return values.items;
    }

    pub fn save(self: *DirectoryDatabase, key: []const u8, value: []const u8) void {
        const key_path = self.keyPath(key);
        self.root.createDirPath(io(), key_path) catch return;
        var directory = self.root.openDir(io(), key_path, .{}) catch return;
        defer directory.close(io());
        atomicWrite(directory, ".name", key);
        atomicWrite(directory, databaseDigest(value), value);
    }

    pub fn delete(self: *DirectoryDatabase, key: []const u8, value: []const u8) void {
        const key_path = self.keyPath(key);
        var directory = self.root.openDir(io(), key_path, .{ .iterate = true }) catch return;
        directory.deleteFile(io(), databaseDigest(value)) catch {};
        var has_entry = false;
        var entries = directory.iterate();
        while (entries.next(io()) catch null) |entry| {
            if (isEntry(entry.name)) {
                has_entry = true;
                break;
            }
        }
        directory.close(io());
        if (!has_entry) {
            self.root.deleteFile(io(), std.fs.path.join(allocator, &.{ key_path, ".name" }) catch return) catch {};
            self.root.deleteDir(io(), key_path) catch {};
        }
    }
};

fn keyEncode(parts: []const KeyPart) []const u8 {
    var encoded: []const u8 = &.{};
    for (parts) |part| {
        encoded = switch (part) {
            .text => |text| core.key_append_text(encoded, text),
            .int => |value| core.key_append_int(encoded, signedBytes(value)),
        };
    }
    return encoded;
}

pub const Failure = struct {
    blob: []const u8,
    cause: []const u8,
    examples_run: usize,
    rejections: usize,
    notes: []const []const u8,
    /// Replayed draws that could not use their recorded value. See
    /// ir/replay.zir: a pun is legal but silent, so it is counted rather than
    /// returned as an error. A non-zero count means the reported example is
    /// not the one the blob recorded.
    puns: usize = 0,
    /// Keyed draws whose name the blob did not carry.
    key_misses: usize = 0,
    /// What the reported example spent in total; see TestCase.cost.
    cost: u64 = 0,
};

pub const Config = struct {
    examples: usize = 100,
    /// Initial rejection allowance; each valid example earns 100 more.
    max_rejections: usize = 458,
    suppress_filter_too_much: bool = false,
    suppress_data_too_large: bool = false,
    /// Allow an all-simplest input that uses more than half the choice budget.
    suppress_large_base_example: bool = false,
    /// Disable the cumulative generation-time health check.
    suppress_too_slow: bool = false,
    /// Zero disables the corresponding shrink cap.
    max_shrinks: u64 = 500,
    max_stall: u64 = 200,
    seed: u64 = 0,
    reproduce: ?[]const u8 = null,
    /// Labels the completed run must have covered, whether or not any call
    /// site for them ever executed. See TestCase.cover.
    require: []const Coverage = &.{},
    /// Reuse and store raw counterexample streams; disabled by default.
    database: ?Database = null,
    /// Portable property name used by the database. Defaults to the Zig type name.
    database_key: ?[]const u8 = null,
};

/// A label a completed run must have observed, declared in Config.require. A
/// zero percent requires the label's condition to have held in at least one
/// valid example; a positive percent requires at least that share of them.
pub const Coverage = struct {
    label: []const u8,
    percent: f64 = 0,
};

/// A coverage requirement the completed run missed.
///
/// There is no counterexample and so no blob or shrinking: the failure is the
/// absence of an example, not an example. A Zig error is a bare value with no
/// payload, so check reports this as error.FailedCoverage and leaves the
/// details here, in `failed_coverage`. The counters are a pure function of the
/// run's choice streams, so rerunning with the same seed reproduces the
/// identical verdict.
pub const FailedCoverage = struct {
    label: []const u8,
    observed: u64,
    valid: u64,
    /// The strongest rate required for the label across its call sites and
    /// Config.require entries; zero means "at least once".
    min_percent: f64,

    pub fn format(self: FailedCoverage, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        if (self.min_percent == 0) {
            return writer.print(
                "coverage: \"{s}\" never held in {d} valid examples",
                .{ self.label, self.valid },
            );
        }
        return writer.print(
            "coverage: \"{s}\" held in {d} of {d} valid examples, below the required {d}%",
            .{ self.label, self.observed, self.valid, self.min_percent },
        );
    }
};

/// The details behind the last error.FailedCoverage check reported. A pub var
/// like `allocator`: the shell is single-threaded by construction, and check
/// clears it on entry.
pub var failed_coverage: ?FailedCoverage = null;

/// A failing example did not fail the same way when it was replayed: the
/// property depends on something other than the choices it drew. A Zig error
/// is a bare value with no payload, so check reports this as error.Flaky and
/// leaves the details here, in `flaky`. There is no shrunk example to trust, so
/// this carries the failure as first found and the blob of the stream that
/// produced it; unlike a Failure's, that blob need not fail when reproduced.
pub const Flaky = struct {
    blob: []const u8,
    cause: []const u8,
    examples_run: usize,
    rejections: usize,

    pub fn format(self: Flaky, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        return writer.print(
            "flaky test: the property failed, then did not fail the same way when that " ++
                "example was replayed\noriginal failure: {s}\nreproduce with .reproduce = \"{s}\"",
            .{ self.cause, self.blob },
        );
    }
};

/// The details behind the last error.Flaky check reported, cleared on entry
/// like `failed_coverage`.
pub var flaky: ?Flaky = null;

/// Report a failing example whose replay during shrinking did not fail: the
/// failure as found and the blob of the stream that produced it, unshrunk.
/// Nothing is stored in or collected from the database for it.
fn flakyFailure(case: *const TestCase, cause: []const u8, attempts: usize, rejections: usize) error{Flaky} {
    flaky = .{
        .blob = core.raw_failure_encode(case.serialized()),
        .cause = cause,
        .examples_run = attempts,
        .rejections = rejections,
    };
    return error.Flaky;
}

/// One label's buffered per-example coverage observation.
const CoverageObservation = struct { held: bool = false, permille: u64 = 0 };

/// One label's run-level coverage. Declared requirements are registered before
/// the first example and observed-only labels in first-observation order,
/// which is also the order verdicts are checked in — so shells that agree on
/// the counters agree on the label a failure names.
const CoverageCounter = struct { label: []const u8, observed: u64 = 0, permille: u64 = 0 };

pub const ChoiceSpan = struct {
    start: usize,
    end: usize,
    label: []const u8,
    depth: usize,
    parent: ?usize,
    discarded: bool = false,
};

const Draw = union(enum) {
    integer: struct {
        encoded: []const u8,
        value: i64,
        min: i64,
        max: i64,
        target: i64,
        forced: bool = false,
        key: ?u64 = null,
    },
    boolean: struct {
        encoded: []const u8,
        value: bool,
        forced: bool = false,
        key: ?u64 = null,
    },
    bytes: struct {
        encoded: []const u8,
        value: []const u8,
        min: i64,
        max: i64,
        forced: bool = false,
        key: ?u64 = null,
    },
    /// `value` holds the packed u32-LE codepoints the stream records, and
    /// `alphabet` the interval set the draw was made over.
    string: struct {
        encoded: []const u8,
        value: []const u8,
        alphabet: []const u8,
        min: i64,
        max: i64,
        forced: bool = false,
        key: ?u64 = null,
    },
    float: struct {
        encoded: []const u8,
        value: f64,
        min: f64,
        max: f64,
        allow_nan: bool,
        allow_infinity: bool,
        smallest_nonzero: f64,
        forced: bool = false,
        key: ?u64 = null,
    },
    /// The stream a clone draw carries. Its entry is built at serialization
    /// time rather than at record time, because the child keeps drawing after
    /// the clone is recorded; the child is heap-allocated so the parent's own
    /// draw list can be copied without copying it.
    clone: struct {
        encoded: []const u8 = "",
        child: *TestCase,
        forced: bool = false,
        key: ?u64 = null,
    },

    fn child(self: Draw) ?*TestCase {
        return switch (self) {
            .clone => |value| value.child,
            else => null,
        };
    }

    fn encoded(self: Draw) []const u8 {
        return switch (self) {
            inline else => |value| value.encoded,
        };
    }

    fn forced(self: Draw) bool {
        return switch (self) {
            inline else => |value| value.forced,
        };
    }

    fn key(self: Draw) ?u64 {
        return switch (self) {
            inline else => |value| value.key,
        };
    }

    /// The stream entry for this draw: its value, wrapped if it has a name.
    fn entry(self: Draw) []const u8 {
        var framed = self.encoded();
        if (self.child()) |stream| {
            const children = stream.draws.items;
            var out: std.ArrayList(u8) = .empty;
            out.appendSlice(
                allocator,
                core.serialize_clone_header(children.len),
            ) catch unreachable;
            for (children) |item| {
                out.appendSlice(allocator, item.entry()) catch unreachable;
            }
            framed = out.toOwnedSlice(allocator) catch unreachable;
        }
        const named = self.key() orelse return framed;
        return core.serialize_keyed_choice(named, framed);
    }
};

/// Count a draw list the way Hegel's flattened length does: a clone
/// contributes itself plus everything inside it.
fn flatDrawCount(draws: []const Draw) usize {
    var total: usize = 0;
    for (draws) |draw| {
        total += 1;
        if (draw.child()) |stream| total += flatDrawCount(stream.draws.items);
    }
    return total;
}

/// How deeply clones may nest. This is Hegel's MAX_CLONE_DEPTH and the wire
/// format's own limit (ir/wire.zir @choice_entry_end): a stream nested deeper
/// than this cannot be validated, so refusing to build one keeps the shell
/// from emitting a blob nothing can read.
pub const max_clone_depth: usize = 100;

/// What a run reports, shared by every stream in one example.
///
/// Notes, costs, coverage, puns, and the choice budget belong to the family
/// rather than to one stream, and a TestCase is a value that gets copied out of
/// a run — so the shared half lives behind one pointer every stream holds.
const Family = struct {
    notes_list: std.ArrayList([]const u8) = .empty,
    costs: ?std.StringHashMap(u64) = null,
    /// Targeting observations for this example, per label. The run keeps the
    /// best-scoring example per label and hill-climbs it on a schedule.
    targets: ?std.StringHashMap(f64) = null,
    coverage_order: std.ArrayList([]const u8) = .empty,
    coverage: ?std.StringHashMap(CoverageObservation) = null,
    puns: usize = 0,
    /// Identifiers handed out by freshId, family-wide so an identifier is
    /// unique across every stream of the case. Kept ascending — which is the
    /// order the smallest-unused fold is defined over — and only ever grows:
    /// that is what keeps the recorded windows monotone within a run, so
    /// consuming a value cannot destabilize the identifiers recorded after it.
    fresh_ids: std.ArrayList(i64) = .empty,
    key_misses: usize = 0,
    /// Every draw in the family, including those inside clones, so the choice
    /// budget stays O(1) per draw.
    flat_draws: usize = 0,
    /// Lazily sampled once and shared by every clone stream in the case.
    integer_swarm: ?u64 = null,
    /// The float counterpart of `integer_swarm`, sampled on the first float.
    float_swarm: ?u64 = null,

    fn create() *Family {
        const out = allocator.create(Family) catch unreachable;
        out.* = .{};
        return out;
    }

    /// Whether this identifier has ever been drawn in this family.
    fn holdsFreshId(self: *const Family, value: i64) bool {
        for (self.fresh_ids.items) |used_id| {
            if (used_id == value) return true;
        }
        return false;
    }

    /// Record an identifier, keeping the registry ascending.
    fn addFreshId(self: *Family, value: i64) void {
        var at: usize = 0;
        while (at < self.fresh_ids.items.len and self.fresh_ids.items[at] < value) at += 1;
        if (at < self.fresh_ids.items.len and self.fresh_ids.items[at] == value) return;
        self.fresh_ids.insert(allocator, at, value) catch unreachable;
    }

    /// One more than the largest identifier this family has ever drawn, or
    /// zero before the first draw: what both identifier windows are anchored
    /// on. The registry is ascending, so that is its last entry.
    fn identifierMaxPlusOne(self: *const Family) u64 {
        const used = self.fresh_ids.items;
        if (used.len == 0) return 0;
        return @as(u64, @intCast(used[used.len - 1])) + 1;
    }
};

const SplitMix64 = struct {
    state: u64,

    fn next(self: *SplitMix64) u64 {
        self.state +%= 0x9e3779b97f4a7c15;
        var value = self.state;
        value = (value ^ (value >> 30)) *% 0xbf58476d1ce4e5b9;
        value = (value ^ (value >> 27)) *% 0x94d049bb133111eb;
        return value ^ (value >> 31);
    }
};

pub const TestCase = struct {
    rng: ?SplitMix64 = null,
    replay: ?[]const u8 = null,
    simplest: bool = false,
    position: i64 = 4,
    remaining: u64 = 0,
    draws: std.ArrayList(Draw) = .empty,
    spans_list: std.ArrayList(ChoiceSpan) = .empty,
    span_stack: std.ArrayList(usize) = .empty,
    /// What the run reports, shared with every clone of this stream.
    family: *Family = undefined,
    /// How many clones deep this stream sits.
    depth: usize = 0,
    generation_depth: usize = 0,
    generation_us: u64 = 0,
    keyed: ?std.AutoHashMap(u64, std.ArrayList(i64)) = null,
    /// Per-name ordinals for nextKey. Execution-local by construction: a
    /// counter that outlives one example produces different keys on the replay
    /// than on the run that recorded it, and every draw misses.
    key_counts: ?std.StringHashMap(i64) = null,

    /// The message of an assertion this shell failed on the property's behalf
    /// (always / unreachable). A Zig error is a bare value, so the message —
    /// which embeds the label — doubles as the failure's reported cause and as
    /// its bug identity; without it every always site would collapse into one
    /// origin and the shrinker could migrate between distinct assertions.
    assertion_failure: ?[]const u8 = null,

    /// Record that this example spent something scarce.
    ///
    /// The shrinker orders candidates by total cost first and by the choice
    /// stream second, so a candidate injecting one fewer fault wins even when
    /// its stream is longer. A property that never calls this is ordered as
    /// before.
    pub fn cost(self: *TestCase, label: []const u8, amount: u64) void {
        if (self.family.costs == null) self.family.costs = std.StringHashMap(u64).init(allocator);
        const found = self.family.costs.?.getOrPut(label) catch unreachable;
        if (!found.found_existing) found.value_ptr.* = 0;
        found.value_ptr.* += amount;
    }

    pub fn totalCost(self: *const TestCase) u64 {
        var total: u64 = 0;
        if (self.family.costs) |costs| {
            var walk = costs.valueIterator();
            while (walk.next()) |amount| total += amount.*;
        }
        return total;
    }

    /// What this example spent for one label.
    pub fn costOf(self: *const TestCase, label: []const u8) u64 {
        if (self.family.costs) |costs| {
            if (costs.get(label)) |amount| return amount;
        }
        return 0;
    }

    /// Record a targeting observation under the empty label: generation is
    /// steered towards examples that maximize the score. The run keeps, per
    /// label, the best-scoring valid example, and hill-climbs those examples
    /// on a schedule between ordinary generation. The score must be finite.
    pub fn target(self: *TestCase, score: f64) void {
        self.targetLabelled(score, "");
    }

    /// Record a targeting observation under an explicit label. A label may be
    /// observed at most once per example — a property targeting several
    /// quantities names them apart.
    pub fn targetLabelled(self: *TestCase, score: f64, label: []const u8) void {
        if (std.math.isNan(score) or std.math.isInf(score)) {
            @panic("zizek: target requires a finite score");
        }
        if (self.family.targets == null) {
            self.family.targets = std.StringHashMap(f64).init(allocator);
        }
        const found = self.family.targets.?.getOrPut(label) catch unreachable;
        if (found.found_existing) {
            @panic("zizek: each target label can be observed at most once per example");
        }
        found.value_ptr.* = score;
    }

    pub const GenerationTimer = struct {
        started_ns: i96,
        outer: bool,
    };

    pub fn startGeneration(self: *TestCase) GenerationTimer {
        const outer = self.generation_depth == 0;
        self.generation_depth += 1;
        return .{
            .started_ns = if (outer)
                std.Io.Clock.awake.now(std.Io.Threaded.global_single_threaded.io()).nanoseconds
            else
                0,
            .outer = outer,
        };
    }

    pub fn finishGeneration(self: *TestCase, timer: GenerationTimer) void {
        self.generation_depth -= 1;
        if (!timer.outer) return;
        const finished = std.Io.Clock.awake.now(
            std.Io.Threaded.global_single_threaded.io(),
        ).nanoseconds;
        const elapsed_ns = @max(finished - timer.started_ns, 0);
        const elapsed_us: u64 = @intCast(@divTrunc(elapsed_ns, std.time.ns_per_us));
        self.generation_us +|= elapsed_us;
    }

    fn random(rng: SplitMix64) TestCase {
        return .{ .rng = rng, .family = Family.create() };
    }

    fn simplestCase() TestCase {
        return .{ .simplest = true, .family = Family.create() };
    }

    fn replaying(raw: []const u8) TestCase {
        return .{
            .replay = raw,
            .remaining = core.choice_stream_count(raw),
            .family = Family.create(),
        };
    }

    fn probe(raw: []const u8, rng: SplitMix64) TestCase {
        return .{
            .rng = rng,
            .replay = raw,
            .remaining = core.choice_stream_count(raw),
            .family = Family.create(),
        };
    }

    /// A child test case that draws from a stream of its own.
    ///
    /// The clone occupies one choice position in this stream and gets its own
    /// prefix, RNG, and span structure, so its draws neither shift nor are
    /// shifted by the parent's — which is what makes it the seam a concurrent
    /// runner would use. Everything the run reports is shared: notes, costs,
    /// coverage, and the choice budget all belong to the family.
    ///
    /// This is Hegel's hegel_test_case_clone without threads. The child is
    /// drawn from sequentially, but the wire framing
    /// (`[5][u32 child count][children]`) and the replay rules are the
    /// engine's, so a blob carrying a clone crosses between the two.
    ///
    /// On replay a clone value at this position hands the child its recorded
    /// stream. Any other value puns to an empty child, which overruns on its
    /// first draw in a bare replay and extends randomly under a probe.
    pub fn cloneStream(self: *TestCase) !*TestCase {
        try self.checkChoiceBudget();
        // Upstream concludes the family invalid past the limit rather than
        // failing the property, so this is a rejection: a false assume's path.
        if (self.depth + 1 > max_clone_depth) return error.AssumptionRejected;
        const at = try self.resolve(null);
        const child = allocator.create(TestCase) catch unreachable;
        child.* = .{ .family = self.family, .depth = self.depth + 1 };
        if (at.simplest) {
            child.simplest = true;
        } else if (at.random) {
            child.rng = self.spawnRng();
        } else {
            const inner = core.clone_inner_stream(self.replay.?, @intCast(at.at)) orelse blk: {
                // A non-clone entry where a clone belongs: pun to an empty
                // child.
                self.family.puns += 1;
                break :blk core.choice_list_header(0);
            };
            child.replay = inner;
            child.remaining = core.choice_stream_count(inner);
            child.rng = self.spawnRng();
        }
        self.record(.{ .clone = .{ .child = child } });
        return child;
    }

    /// Give a clone a stream of its own, drawn from this one's, so two streams
    /// never hand back the same values. A case without a generator (a bare
    /// replay, or the all-simplest probe) has none to give.
    fn spawnRng(self: *TestCase) ?SplitMix64 {
        if (self.rng) |*rng| return SplitMix64{ .state = rng.next() };
        return null;
    }

    /// Append a draw and count it against the family's choice budget.
    fn record(self: *TestCase, draw: Draw) void {
        self.draws.append(allocator, draw) catch unreachable;
        self.family.flat_draws += 1;
    }

    /// The key naming the next draw in a sequence.
    ///
    /// Appends an ordinal counted *within this name*, so a per-connection read
    /// sequence is numbered independently of every other sequence. An insertion
    /// then shifts only its own sequence.
    pub fn nextKey(self: *TestCase, parts: []const KeyPart) u64 {
        if (self.key_counts == null) self.key_counts = std.StringHashMap(i64).init(allocator);
        const scope = keyEncode(parts);
        const found = self.key_counts.?.getOrPut(scope) catch unreachable;
        if (!found.found_existing) found.value_ptr.* = 0;
        const ordinal = found.value_ptr.*;
        found.value_ptr.* = ordinal + 1;
        return core.key_hash(core.key_append_int(scope, signedBytes(ordinal)));
    }

    /// Reject the current example without treating it as a property failure.
    pub fn assume(_: *TestCase, condition: bool) !void {
        if (!condition) return error.AssumptionRejected;
    }

    /// Fail this example unless condition holds.
    ///
    /// An ordinary property failure that shrinks and replays like any other,
    /// with the label as part of the bug's identity. A passing evaluation also
    /// counts as covering the label, so a call site that may legitimately
    /// never execute is fine on its own ("always or unreachable"), while
    /// listing the label in `Config.require` additionally fails a run that
    /// never reached it.
    pub fn always(self: *TestCase, label: []const u8, condition: bool) !void {
        if (!condition) {
            self.assertion_failure = std.fmt.allocPrint(
                allocator,
                "always: \"{s}\" did not hold",
                .{label},
            ) catch unreachable;
            return error.AlwaysFailed;
        }
        self.recordCoverage(label, true, 0);
    }

    /// Fail this example: the assertion is that nothing reaches this call.
    ///
    /// The failure shrinks and replays like any other, so the reported
    /// counterexample is the simplest input that reaches the branch.
    /// (`unreachable` is a Zig keyword, hence the quoted name; call it as
    /// `try case.@"unreachable"("dead branch")`.)
    pub fn @"unreachable"(self: *TestCase, label: []const u8) !void {
        self.assertion_failure = std.fmt.allocPrint(
            allocator,
            "unreachable: \"{s}\" was reached",
            .{label},
        ) catch unreachable;
        return error.UnreachableReached;
    }

    /// Assert that condition holds in at least one valid example of the run.
    ///
    /// A property passes vacuously when the branch it exists to test never
    /// executes; sometimes turns that silent gap into a failure. The verdict
    /// is per run, not per example, so a false condition here never fails the
    /// current example — only a completed run in which it never held.
    pub fn sometimes(self: *TestCase, label: []const u8, condition: bool) void {
        self.recordCoverage(label, condition, 0);
    }

    /// Assert that condition holds in at least percent% of valid examples.
    ///
    /// And at least once, whatever the rate. A label counts once per example
    /// in which its condition held, however many times the call site ran.
    /// Labels a run must observe even when the call site itself may never
    /// execute are declared up front via `Config.require`.
    pub fn cover(self: *TestCase, label: []const u8, condition: bool, percent: f64) !void {
        if (!(percent >= 0 and percent <= 100)) return error.InvalidPercent;
        self.recordCoverage(label, condition, @intFromFloat(percent * 10));
    }

    fn recordCoverage(self: *TestCase, label: []const u8, condition: bool, permille: u64) void {
        if (self.family.coverage == null) self.family.coverage = std.StringHashMap(CoverageObservation).init(allocator);
        const found = self.family.coverage.?.getOrPut(label) catch unreachable;
        if (!found.found_existing) {
            found.value_ptr.* = .{};
            self.family.coverage_order.append(allocator, label) catch unreachable;
        }
        if (condition) found.value_ptr.held = true;
        if (permille > found.value_ptr.permille) found.value_ptr.permille = permille;
    }

    /// Attach diagnostic context to the current example.
    pub fn note(self: *TestCase, message: []const u8) void {
        self.family.notes_list.append(allocator, allocator.dupe(u8, message) catch unreachable) catch unreachable;
    }

    pub fn notes(self: *const TestCase) []const []const u8 {
        return self.family.notes_list.items;
    }

    pub fn startSpan(self: *TestCase, label: []const u8) usize {
        const id = self.spans_list.items.len;
        self.spans_list.append(allocator, .{
            .start = self.draws.items.len,
            .end = self.draws.items.len,
            .label = allocator.dupe(u8, label) catch unreachable,
            .depth = self.span_stack.items.len,
            .parent = if (self.span_stack.items.len == 0) null else self.span_stack.items[self.span_stack.items.len - 1],
        }) catch unreachable;
        self.span_stack.append(allocator, id) catch unreachable;
        return id;
    }

    pub fn stopSpan(self: *TestCase, discarded: bool) void {
        if (self.span_stack.items.len == 0) return;
        const id = self.span_stack.pop().?;
        self.spans_list.items[id].end = self.draws.items.len;
        self.spans_list.items[id].discarded = discarded;
    }

    pub fn openSpanDepth(self: *const TestCase) usize {
        return self.span_stack.items.len;
    }

    pub fn resetOpenSpansTo(self: *TestCase, depth: usize) void {
        while (self.span_stack.items.len > depth) self.stopSpan(true);
    }

    pub fn spans(self: *const TestCase) []const ChoiceSpan {
        return self.spans_list.items;
    }

    fn closeOpenSpans(self: *TestCase) void {
        while (self.span_stack.items.len != 0) self.stopSpan(false);
        // A clone has its own span structure, and the property may leave one
        // open on a child exactly as it may on the stream it was handed.
        for (self.draws.items) |draw| {
            if (draw.child()) |stream| stream.closeOpenSpans();
        }
    }

    fn advanceReplay(self: *TestCase) !i64 {
        while (true) {
            const replay = self.replay orelse return error.ReplayOverrun;
            if (self.remaining == 0) return error.ReplayOverrun;
            const start = self.position;
            const end = core.choice_entry_end(replay, start, 0);
            if (end == 0) return error.InvalidReplay;
            self.position = end;
            self.remaining -= 1;
            // A named entry belongs to the draw that names it, wherever that
            // draw happens to fall. The positional cursor steps over it, so
            // adding or removing keyed draws cannot shift unkeyed ones.
            if (core.keyed_entry_key(replay, start) == null) return start;
        }
    }

    /// Index the replay stream by key, innermost entry offset first.
    fn keyOffsets(self: *TestCase) *std.AutoHashMap(u64, std.ArrayList(i64)) {
        if (self.keyed == null) {
            var offsets = std.AutoHashMap(u64, std.ArrayList(i64)).init(allocator);
            if (self.replay) |replay| {
                var at: i64 = 4;
                var left = core.choice_stream_count(replay);
                while (left > 0) : (left -= 1) {
                    const end = core.choice_entry_end(replay, at, 0);
                    if (end == 0) break;
                    if (core.keyed_entry_key(replay, at)) |named| {
                        const found = offsets.getOrPut(named) catch unreachable;
                        if (!found.found_existing) found.value_ptr.* = .empty;
                        found.value_ptr.append(
                            allocator,
                            core.keyed_entry_inner(replay, at),
                        ) catch unreachable;
                    }
                    at = end;
                }
            }
            self.keyed = offsets;
        }
        return &self.keyed.?;
    }

    /// Where to read this draw from, and whether to use its simplest value.
    ///
    /// An unkeyed draw takes the next positional entry and overruns when there
    /// is none. A keyed draw takes the next entry recorded under its name and
    /// falls back to the simplest value when the stream has none — a missing
    /// name is an edit to the property, not a malformed blob.
    const Resolved = struct { at: i64 = 0, simplest: bool = false, random: bool = false };

    fn resolve(self: *TestCase, key: ?u64) !Resolved {
        if (self.simplest) return .{ .simplest = true };
        if (self.replay == null) return .{ .random = true };
        const named = key orelse return .{ .at = try self.advanceReplay() };
        if (self.keyOffsets().getPtr(named)) |pending| {
            if (pending.items.len != 0) {
                const at = pending.orderedRemove(0);
                return .{ .at = at };
            }
        }
        self.family.key_misses += 1;
        return .{ .simplest = true };
    }

    fn checkChoiceBudget(self: *TestCase) !void {
        if (self.replay != null and self.remaining == 0 and self.rng != null) {
            self.replay = null;
        }
        // The budget belongs to the family, not to one stream: upstream's cap
        // is on the whole pieced-together choice sequence, so a clone cannot
        // buy another 8,192 draws by starting a stream of its own.
        if (self.replay == null and core.choice_budget_exhausted(self.family.flat_draws)) {
            return error.ChoiceOverrun;
        }
    }

    /// Draw an integer in the inclusive range, shrinking toward `shrink_towards`.
    pub fn integer(self: *TestCase, min: i64, max: i64, shrink_towards: i64) !i64 {
        return self.integerNamed(min, max, shrink_towards, null, false);
    }

    /// Draw an integer addressed by a name rather than by position. The key
    /// comes from `zizek.key`.
    pub fn integerKeyed(self: *TestCase, min: i64, max: i64, shrink_towards: i64, key: u64) !i64 {
        return self.integerNamed(min, max, shrink_towards, key, false);
    }

    pub fn integerUniform(self: *TestCase, min: i64, max: i64, shrink_towards: i64) !i64 {
        return self.integerNamed(min, max, shrink_towards, null, true);
    }

    fn integerNamed(self: *TestCase, min: i64, max: i64, shrink_towards: i64, key: ?u64, uniform: bool) !i64 {
        if (min > max) return error.InvalidBounds;
        try self.checkChoiceBudget();
        const where = try self.resolve(key);
        var value: i64 = undefined;
        if (where.simplest) {
            value = signedInt(core.integer_simplest(
                signedBytes(min),
                signedBytes(max),
                signedBytes(shrink_towards),
            )).?;
        } else if (self.replay) |raw| {
            const start = where.at;
            const low = signedBytes(min);
            const high = signedBytes(max);
            if (core.replay_integer_puns(raw, start, low, high)) self.family.puns += 1;
            value = signedInt(
                core.replay_integer(raw, start, low, high, signedBytes(shrink_towards)),
            ).?;
        } else {
            value = if (uniform) randomUniformI64(&self.rng.?, min, max) else self.randomSwarmI64(min, max);
        }
        self.record(.{ .integer = .{
            .encoded = core.serialize_integer_choice(signedBytes(value)),
            .value = value,
            .min = min,
            .max = max,
            .target = shrink_towards,
            .key = key,
        } });
        return value;
    }

    fn randomSwarmI64(self: *TestCase, min: i64, max: i64) i64 {
        // Narrow ranges are uniform: a boundary boost here over-picked the
        // ends of small ranges, i.e. the first and last option of a list
        // indexed by this draw.
        if (!core.integer_swarm_is_wide(min, max)) return randomUniformI64(&self.rng.?, min, max);
        if (self.family.integer_swarm == null) self.family.integer_swarm = self.rng.?.next();
        const category = core.integer_swarm_category(
            self.family.integer_swarm.?,
            self.rng.?.next() % 1000,
        );
        const count = core.integer_boundary_count(min, max);
        const candidate = switch (category) {
            0 => core.integer_swarm_endpoint_candidate(min, max, self.rng.?.next() % 4),
            1 => if (count > 2)
                core.integer_boundary_candidate(min, max, 2 + self.rng.?.next() % (count - 2))
            else
                null,
            2 => core.integer_swarm_diffuse_candidate(
                min,
                max,
                self.rng.?.next() % core.integer_swarm_diffuse_count(),
            ),
            else => null,
        };
        return candidate orelse randomUniformI64(&self.rng.?, min, max);
    }

    /// One float from the family-wide category mixture: a roll picks the
    /// category, and a category the spec rules out yields to the default draw,
    /// so its mass never goes to a neighbouring category. Like the integer
    /// swarm, the mixture word is never recorded.
    fn randomSwarmF64(
        self: *TestCase,
        min: f64,
        max: f64,
        allow_nan: bool,
        allow_infinity: bool,
        smallest_nonzero: f64,
    ) f64 {
        const rng = &self.rng.?;
        if (self.family.float_swarm == null) self.family.float_swarm = rng.next();
        const category = core.float_swarm_category(
            self.family.float_swarm.?,
            rng.next() % core.float_swarm_roll_span(),
        );
        var words: [5]u64 = undefined;
        for (&words) |*word| word.* = rng.next();
        if (core.float_category_candidate(
            category,
            min,
            max,
            allow_nan,
            allow_infinity,
            smallest_nonzero,
            words[0],
            words[1],
            words[2],
            words[3],
            words[4],
        )) |candidate| return candidate;
        for (words[0..4]) |*word| word.* = rng.next();
        return core.float_default_candidate(
            min,
            max,
            allow_nan,
            allow_infinity,
            smallest_nonzero,
            words[0],
            words[1],
            words[2],
            words[3],
        );
    }

    /// What an identifier draw hands out when it generates, and what it
    /// repairs a replayed value onto.
    ///
    /// Zig has no closures, so the two identifier draws below pass their
    /// inputs by value and `drawIdentifier` branches on which kind it has,
    /// where the reference implementations pass a pair of callbacks.
    const Identifier = union(enum) {
        /// A fresh identifier: `fallback` is the smallest identifier the
        /// family has not used, which is both what generation hands out and
        /// what a replayed value that is out of window or already in use is
        /// repaired to.
        fresh: i64,
        /// One of these members, ascending and de-duplicated. A replayed value
        /// is repaired to the largest member at or below it, or to the
        /// smallest member when it sits below every one of them.
        member_of: []const i64,
    };

    /// Record one identifier choice: an integer in `[0, window_hi]`.
    ///
    /// Identifier draws differ from `integer` only in how a replayed value is
    /// resolved — an ordinary integer puns to the nearest legal value, while
    /// an identifier is *repaired* onto one the pool still holds — so what
    /// reaches the stream is an ordinary integer entry and nothing downstream
    /// (the wire format, the shrinker, the indexers) has to know these exist.
    /// The repaired value is what gets recorded, which is what lets a replayed
    /// stream heal rather than drift.
    fn drawIdentifier(
        self: *TestCase,
        window_hi: i64,
        simplest_value: i64,
        kind: Identifier,
    ) !i64 {
        try self.checkChoiceBudget();
        const where = try self.resolve(null);
        var value: i64 = undefined;
        if (where.simplest) {
            value = simplest_value;
        } else if (self.replay) |raw_stream| {
            const start = where.at;
            const low = signedBytes(0);
            const high = signedBytes(window_hi);
            // A recorded value outside the window is *punned*, not repaired.
            // Repair is for a value that named a member which has since gone,
            // and it slides towards an earlier one; a value that was never in
            // the window names nothing, so it falls back to the simplest
            // member the way every other out-of-range replay value does.
            // Reading `replay_integer` first would lose the distinction — it
            // clamps to the window, which would send a runaway value to the
            // *largest* member rather than the smallest.
            if (core.replay_integer_puns(raw_stream, start, low, high)) {
                self.family.puns += 1;
                value = simplest_value;
            } else {
                const raw = signedInt(
                    core.replay_integer(raw_stream, start, low, high, signedBytes(0)),
                ).?;
                value = switch (kind) {
                    .fresh => |fallback| if (core.stateful_fresh_id_accepts(
                        @intCast(raw),
                        @intCast(window_hi),
                        self.family.holdsFreshId(raw),
                    )) raw else fallback,
                    .member_of => |members| repaired: {
                        if (!core.stateful_set_choice_accepts(@intCast(raw), @intCast(window_hi))) {
                            break :repaired simplest_value;
                        }
                        var best = simplest_value;
                        for (members) |candidate| {
                            if (core.stateful_set_choice_better(
                                @intCast(candidate),
                                @intCast(raw),
                                @intCast(best),
                            )) best = candidate;
                        }
                        break :repaired best;
                    },
                };
            }
        } else {
            value = switch (kind) {
                .fresh => |fallback| fallback,
                .member_of => |members| members[
                    @intCast(
                        self.rng.?.next() % @as(u64, @intCast(members.len)),
                    )
                ],
            };
        }
        self.record(.{ .integer = .{
            .encoded = core.serialize_integer_choice(signedBytes(value)),
            .value = value,
            .min = 0,
            .max = window_hi,
            .target = 0,
        } });
        return value;
    }

    /// Draw an identifier that is arbitrary but unique within this family.
    ///
    /// The identifier is recorded *by value*, so it keeps meaning the same
    /// variable when unrelated earlier draws are deleted during shrinking —
    /// which is the whole point of it, and what a positional index cannot do.
    /// Generation always hands out the smallest unused identifier, and a
    /// replayed identifier that is already in use is repaired to that same
    /// smallest unused one.
    ///
    /// This is Hegel's `draw_fresh_id` (`hegel-c` 0.32.4).
    pub fn freshId(self: *TestCase) !i64 {
        const window_hi: i64 = @intCast(
            core.stateful_fresh_id_window(self.family.identifierMaxPlusOne()),
        );
        // The registry is ascending, so this walks it the way the fold is
        // defined: a candidate advances only while the registry holds it, and
        // the first gap stops it climbing.
        var fallback: u64 = 0;
        for (self.family.fresh_ids.items) |used_id| {
            fallback = core.stateful_fresh_id_fallback_step(fallback, @intCast(used_id));
        }
        const smallest_unused: i64 = @intCast(fallback);

        const value = try self.drawIdentifier(
            window_hi,
            smallest_unused,
            .{ .fresh = smallest_unused },
        );
        self.family.addFreshId(value);
        return value;
    }

    /// Draw one of `members`, recording the member itself.
    ///
    /// Recording the member rather than an index into the live set is what
    /// makes a reference survive the deletion of *other* members: while the
    /// member it names is still there it keeps naming it, and when that member
    /// goes the reference slides to an earlier one rather than to whatever now
    /// occupies some shifted position.
    ///
    /// This is Hegel's `draw_from_set` (`hegel-c` 0.32.4).
    pub fn fromSet(self: *TestCase, members: []const i64) !i64 {
        if (members.len == 0) return error.EmptyMemberSet;
        // A copy: the caller's slice is the pool's own active list, which the
        // repair fold reads in whatever order the pool keeps it in, and which
        // this draw has no business reordering.
        const ordered = allocator.dupe(i64, members) catch unreachable;
        std.mem.sort(i64, ordered, {}, std.sort.asc(i64));
        var unique_count: usize = 0;
        for (ordered) |member| {
            if (unique_count != 0 and ordered[unique_count - 1] == member) continue;
            ordered[unique_count] = member;
            unique_count += 1;
        }
        const unique = ordered[0..unique_count];
        if (unique[0] < 0) return error.NegativeMember;
        const smallest = unique[0];
        const window_hi: i64 = @intCast(
            core.stateful_set_choice_window(self.family.identifierMaxPlusOne()),
        );

        return self.drawIdentifier(window_hi, smallest, .{ .member_of = unique });
    }

    /// Draw a boolean, shrinking toward false.
    pub fn boolean(self: *TestCase) !bool {
        return self.booleanNamed(null);
    }

    /// Draw a boolean addressed by a name rather than by position.
    pub fn booleanKeyed(self: *TestCase, key: u64) !bool {
        return self.booleanNamed(key);
    }

    fn booleanNamed(self: *TestCase, key: ?u64) !bool {
        try self.checkChoiceBudget();
        const where = try self.resolve(key);
        var value: bool = undefined;
        if (where.simplest) {
            value = false;
        } else if (self.replay) |raw| {
            if (core.replay_boolean_puns(raw, where.at)) self.family.puns += 1;
            value = core.replay_boolean(raw, where.at);
        } else {
            value = (self.rng.?.next() & 1) != 0;
        }
        self.record(.{ .boolean = .{
            .encoded = core.serialize_boolean_choice(value),
            .value = value,
            .key = key,
        } });
        return value;
    }

    /// Draw a boolean that is true with the given probability.
    ///
    /// Recorded as an ordinary boolean choice: the weight biases generation
    /// only, so a blob replays the same whatever probability produced it.
    pub fn weighted(self: *TestCase, probability: f64) !bool {
        return self.weightedNamed(probability, null);
    }

    /// Draw a weighted boolean addressed by a name rather than by position.
    pub fn weightedKeyed(self: *TestCase, probability: f64, key: u64) !bool {
        return self.weightedNamed(probability, key);
    }

    fn weightedNamed(self: *TestCase, probability: f64, key: ?u64) !bool {
        try self.checkChoiceBudget();
        const where = try self.resolve(key);
        var value: bool = undefined;
        if (where.simplest) {
            value = false;
        } else if (self.replay) |raw| {
            if (core.replay_boolean_puns(raw, where.at)) self.family.puns += 1;
            value = core.replay_boolean(raw, where.at);
        } else {
            // The top 53 bits are the ones an f64 can hold exactly.
            const sample: f64 = @floatFromInt(self.rng.?.next() >> 11);
            value = sample / 9007199254740992.0 < probability;
        }
        self.record(.{ .boolean = .{
            .encoded = core.serialize_boolean_choice(value),
            .value = value,
            .key = key,
        } });
        return value;
    }

    /// Draw a variable-length sequence of values from one generator.
    ///
    /// The length is never a choice of its own. Each iteration draws a single
    /// "another element?" boolean inside a span that also holds that element's
    /// own choices, which is what makes a collection structurally shrinkable:
    /// deleting the span removes exactly one element and leaves the rest of
    /// the stream framed correctly. Truncation falls out of the same shape —
    /// lowering one of those booleans to false ends the sequence there.
    ///
    /// The decision itself lives in the core (ir/many.zir); this loop only
    /// supplies entropy and records spans.
    pub fn collect(
        self: *TestCase,
        comptime T: type,
        element: anytype,
        min_size: usize,
        max_size: ?usize,
        label: []const u8,
    ) ![]const T {
        const has_max = max_size != null;
        const bound = max_size orelse 0;
        if (has_max and bound < min_size) return error.InvalidBounds;
        const low: i64 = @intCast(min_size);
        const high: i64 = @intCast(bound);
        const probability = core.length_p_continue(low, high, has_max);
        const draws_choice = core.many_draws_choice(low, high, has_max);
        var values: std.ArrayList(T) = .empty;
        while (true) {
            _ = self.startSpan(label);
            const forced = core.many_forced_value(
                false,
                @intCast(values.items.len),
                low,
                high,
                has_max,
                probability,
            );
            const more = if (!draws_choice)
                // Bounds coincide: upstream draws nothing at all here.
                values.items.len < min_size
            else if (forced) |value|
                try self.forcedBoolean(value)
            else
                try self.weighted(probability);
            if (!more) {
                self.stopSpan(true);
                return values.toOwnedSlice(allocator) catch unreachable;
            }
            // An open span is closed for us when the execution unwinds.
            values.append(allocator, try element.draw(self)) catch unreachable;
            self.stopSpan(false);
        }
    }

    /// Draw a variable-length sequence whose elements are all distinct under
    /// `key`.
    ///
    /// Same pacing as `collect`, with one extra decision layered on: what a
    /// duplicate costs. Upstream spells a unique collection as a *filtered*
    /// element draw inside the same "another element?" loop, so this does too.
    /// Each element gets up to `filter_retry_allowed` candidates, each in its own
    /// span that is discarded when the candidate is already present — the choices
    /// stay in the stream, so a replay walks the same positions, but the shrinker
    /// may delete them freely.
    ///
    /// When every candidate for one element is a duplicate the *element* is
    /// rejected rather than the example, and `many_reject_action` decides what
    /// that costs: retry, stop the collection where it is, or — when the
    /// collection cannot reach its own `min_size` — reject the example the way a
    /// failed assumption does. Both rules live in ir/many.zir.
    ///
    /// Seen keys are compared with `std.meta.eql`, so `K` must be a value type:
    /// a slice key would compare by pointer rather than by contents.
    pub fn collectUnique(
        self: *TestCase,
        comptime T: type,
        comptime K: type,
        element: anytype,
        key: *const fn (T) K,
        min_size: usize,
        max_size: ?usize,
        label: []const u8,
    ) ![]const T {
        const has_max = max_size != null;
        const bound = max_size orelse 0;
        if (has_max and bound < min_size) return error.InvalidBounds;
        const low: i64 = @intCast(min_size);
        const high: i64 = @intCast(bound);
        const probability = core.length_p_continue(low, high, has_max);
        const draws_choice = core.many_draws_choice(low, high, has_max);
        var values: std.ArrayList(T) = .empty;
        var seen: std.ArrayList(K) = .empty;
        var rejections: u64 = 0;
        var force_stop = false;
        while (true) {
            _ = self.startSpan(label);
            const forced = core.many_forced_value(
                force_stop,
                @intCast(values.items.len),
                low,
                high,
                has_max,
                probability,
            );
            const more = if (!draws_choice)
                // Bounds coincide: upstream draws nothing at all here.
                values.items.len < min_size
            else if (forced) |value|
                try self.forcedBoolean(value)
            else
                try self.weighted(probability);
            if (!more) {
                self.stopSpan(true);
                return values.toOwnedSlice(allocator) catch unreachable;
            }
            var accepted: ?T = null;
            var fingerprint: K = undefined;
            var attempts: u64 = 0;
            while (accepted == null and core.filter_retry_allowed(attempts)) : (attempts += 1) {
                _ = self.startSpan("collection.candidate");
                // An open span is closed for us when the execution unwinds.
                const candidate = try element.draw(self);
                const mark = key(candidate);
                var duplicate = false;
                for (seen.items) |previous| {
                    if (std.meta.eql(previous, mark)) duplicate = true;
                }
                if (duplicate) {
                    self.stopSpan(true);
                    continue;
                }
                self.stopSpan(false);
                accepted = candidate;
                fingerprint = mark;
            }
            if (accepted) |candidate| {
                seen.append(allocator, fingerprint) catch unreachable;
                values.append(allocator, candidate) catch unreachable;
                self.stopSpan(false);
            } else {
                self.stopSpan(true);
                rejections += 1;
                switch (core.many_reject_action(rejections, @intCast(values.items.len), low)) {
                    reject_invalid => return error.AssumptionRejected,
                    reject_stop => force_stop = true,
                    else => {},
                }
            }
        }
    }

    /// Draw a byte string whose length is within the inclusive size range.
    pub fn bytes(self: *TestCase, min_size: usize, max_size: usize) ![]const u8 {
        return self.bytesNamed(min_size, max_size, null);
    }

    /// Draw a byte string addressed by a name rather than by position.
    pub fn bytesKeyed(self: *TestCase, min_size: usize, max_size: usize, key: u64) ![]const u8 {
        return self.bytesNamed(min_size, max_size, key);
    }

    fn bytesNamed(self: *TestCase, min_size: usize, max_size: usize, key: ?u64) ![]const u8 {
        if (min_size > max_size) return error.InvalidBounds;
        try self.checkChoiceBudget();
        const where = try self.resolve(key);
        var value: []const u8 = undefined;
        if (where.simplest) {
            value = core.bytes_simplest(@intCast(min_size));
        } else if (self.replay) |raw| {
            const start = where.at;
            if (core.replay_bytes_puns(raw, start, @intCast(min_size), @intCast(max_size))) {
                self.family.puns += 1;
            }
            value = core.replay_bytes(raw, start, @intCast(min_size), @intCast(max_size));
        } else {
            const size = min_size + @as(usize, @intCast(self.rng.?.next() % (max_size - min_size + 1)));
            const generated = allocator.alloc(u8, size) catch unreachable;
            for (generated) |*byte| byte.* = @truncate(self.rng.?.next());
            value = generated;
        }
        const owned = allocator.dupe(u8, value) catch unreachable;
        self.record(.{ .bytes = .{
            .encoded = core.serialize_bytes_choice(owned),
            .value = owned,
            .min = @intCast(min_size),
            .max = @intCast(max_size),
            .key = key,
        } });
        return allocator.dupe(u8, owned) catch unreachable;
    }

    /// Draw text of length [min_size, max_size] over an alphabet; null means
    /// every Unicode scalar value.
    ///
    /// Shrinking is shortlex over the alphabet's shrink order, which puts '0'
    /// through 'Z' first, so a minimal counterexample reads as "0" rather than
    /// as a control character.
    pub fn string(self: *TestCase, min_size: usize, max_size: usize, letters: ?[]const u8) ![]const u8 {
        return self.stringNamed(min_size, max_size, letters, null);
    }

    /// Draw text addressed by a name rather than by position.
    pub fn stringKeyed(
        self: *TestCase,
        min_size: usize,
        max_size: usize,
        letters: ?[]const u8,
        key: u64,
    ) ![]const u8 {
        return self.stringNamed(min_size, max_size, letters, key);
    }

    fn stringNamed(
        self: *TestCase,
        min_size: usize,
        max_size: usize,
        letters: ?[]const u8,
        key: ?u64,
    ) ![]const u8 {
        const characters = letters orelse unicode();
        if (min_size > max_size) return error.InvalidBounds;
        if (!core.alphabet_valid(characters)) return error.InvalidAlphabet;
        try self.checkChoiceBudget();
        const where = try self.resolve(key);
        var value: []const u8 = undefined;
        if (where.simplest) {
            value = core.string_simplest(characters, @intCast(min_size));
        } else if (self.replay) |raw| {
            const start = where.at;
            if (core.replay_string_puns(raw, start, characters, @intCast(min_size), @intCast(max_size))) {
                self.family.puns += 1;
            }
            value = core.replay_string(raw, start, characters, @intCast(min_size), @intCast(max_size));
        } else {
            const size = min_size + @as(usize, @intCast(self.rng.?.next() % (max_size - min_size + 1)));
            const biased = self.rng.?.next() % 1000 < core.text_bias_threshold();
            const span = core.text_rank_span(characters, biased);
            const generated = allocator.alloc(u8, 4 * size) catch unreachable;
            for (0..size) |position| {
                const rank = self.rng.?.next() % span;
                const codepoint: u32 = @intCast(core.alphabet_shrink_codepoint(characters, rank) orelse 0);
                std.mem.writeInt(u32, generated[4 * position ..][0..4], codepoint, .little);
            }
            value = generated;
        }
        const owned = allocator.dupe(u8, value) catch unreachable;
        self.record(.{ .string = .{
            .encoded = core.serialize_string_choice_packed(owned.len / 4, owned),
            .value = owned,
            .alphabet = characters,
            .min = @intCast(min_size),
            .max = @intCast(max_size),
            .key = key,
        } });
        return unpackCodepoints(owned);
    }

    /// Draw an IEEE-754 binary64 value with portable replay and shrinking.
    pub fn float(
        self: *TestCase,
        min: f64,
        max: f64,
        allow_nan: bool,
        allow_infinity: bool,
        smallest_nonzero: f64,
    ) !f64 {
        return self.floatNamed(min, max, allow_nan, allow_infinity, smallest_nonzero, null);
    }

    /// Draw a float addressed by a name rather than by position.
    pub fn floatKeyed(
        self: *TestCase,
        min: f64,
        max: f64,
        allow_nan: bool,
        allow_infinity: bool,
        smallest_nonzero: f64,
        key: u64,
    ) !f64 {
        return self.floatNamed(min, max, allow_nan, allow_infinity, smallest_nonzero, key);
    }

    fn floatNamed(
        self: *TestCase,
        min: f64,
        max: f64,
        allow_nan: bool,
        allow_infinity: bool,
        smallest_nonzero: f64,
        key: ?u64,
    ) !f64 {
        if (!core.float_generation_spec_valid(
            min,
            max,
            allow_nan,
            allow_infinity,
            smallest_nonzero,
        )) return error.InvalidBounds;
        const unit = core.float_unit(
            min,
            max,
            allow_nan,
            allow_infinity,
            smallest_nonzero,
        ) orelse return error.InvalidBounds;
        try self.checkChoiceBudget();

        var value: f64 = undefined;
        const where = try self.resolve(key);
        if (where.simplest) {
            value = core.float_simplest(
                min,
                max,
                allow_nan,
                allow_infinity,
                smallest_nonzero,
            ).?;
        } else if (self.replay) |raw| {
            const start = where.at;
            if (core.replay_float_puns(
                raw,
                start,
                min,
                max,
                allow_nan,
                allow_infinity,
                smallest_nonzero,
            )) self.family.puns += 1;
            value = core.replay_float(
                raw,
                start,
                min,
                max,
                allow_nan,
                allow_infinity,
                smallest_nonzero,
            ) orelse unit;
        } else {
            value = self.randomSwarmF64(min, max, allow_nan, allow_infinity, smallest_nonzero);
        }
        self.record(.{ .float = .{
            .encoded = core.serialize_float_choice(value),
            .value = value,
            .min = min,
            .max = max,
            .allow_nan = allow_nan,
            .allow_infinity = allow_infinity,
            .smallest_nonzero = smallest_nonzero,
            .key = key,
        } });
        return value;
    }

    pub fn forcedInteger(self: *TestCase, value: i64) !i64 {
        try self.checkChoiceBudget();
        if (self.replay != null) _ = try self.advanceReplay();
        self.record(.{ .integer = .{
            .encoded = core.serialize_integer_choice(signedBytes(value)),
            .value = value,
            .min = value,
            .max = value,
            .target = value,
            .forced = true,
        } });
        return value;
    }

    pub fn forcedBoolean(self: *TestCase, value: bool) !bool {
        try self.checkChoiceBudget();
        if (self.replay != null) _ = try self.advanceReplay();
        self.record(.{ .boolean = .{
            .encoded = core.serialize_boolean_choice(value),
            .value = value,
            .forced = true,
        } });
        return value;
    }

    fn serialized(self: *const TestCase) []u8 {
        return serializeDraws(self.draws.items);
    }
};

/// The default text alphabet: every Unicode scalar value, as Hypothesis uses.
/// Generation is biased towards the simple end of the shrink order, so most
/// drawn characters are still ASCII (see ir/generation.zir).
pub fn unicode() []const u8 {
    return core.alphabet_range(0, 0x10FFFF);
}

/// The alphabet holding exactly these characters.
///
/// Alphabets are interval sets, canonical by construction: the order the
/// characters are written in and any repeats among them do not change the
/// result, so alphabet("cab") and alphabet("abc") are the same alphabet and
/// index their members identically.
pub fn alphabet(characters: []const u8) ![]const u8 {
    var encoded: []const u8 = &.{};
    var view = (std.unicode.Utf8View.init(characters) catch return error.InvalidAlphabet).iterator();
    while (view.nextCodepoint()) |codepoint| {
        if (!core.alphabet_codepoint_allowed(codepoint)) return error.InvalidAlphabet;
        encoded = core.alphabet_insert(encoded, codepoint);
    }
    return encoded;
}

/// The alphabet holding every scalar value in a codepoint range. Surrogates
/// are not scalar values and are dropped from the range rather than rejected,
/// so alphabetRange(0, 0x10FFFF) is the whole of Unicode.
pub fn alphabetRange(min_codepoint: u64, max_codepoint: u64) []const u8 {
    return core.alphabet_range(min_codepoint, max_codepoint);
}

/// Packed u32-LE codepoints as UTF-8. Alphabet members are scalar values by
/// construction, so every codepoint encodes.
fn unpackCodepoints(packed_codepoints: []const u8) []const u8 {
    var out = std.ArrayList(u8).empty;
    var at: usize = 0;
    while (at + 4 <= packed_codepoints.len) : (at += 4) {
        const codepoint = std.mem.readInt(u32, packed_codepoints[at..][0..4], .little);
        var buffer: [4]u8 = undefined;
        const written = std.unicode.utf8Encode(@intCast(codepoint), &buffer) catch continue;
        out.appendSlice(allocator, buffer[0..written]) catch unreachable;
    }
    return out.toOwnedSlice(allocator) catch unreachable;
}

fn packCodepoints(value: []const u8) []const u8 {
    var out = std.ArrayList(u8).empty;
    var view = (std.unicode.Utf8View.init(value) catch return &.{}).iterator();
    while (view.nextCodepoint()) |codepoint| {
        var buffer: [4]u8 = undefined;
        std.mem.writeInt(u32, &buffer, codepoint, .little);
        out.appendSlice(allocator, &buffer) catch unreachable;
    }
    return out.toOwnedSlice(allocator) catch unreachable;
}

fn signedBytes(value: i64) []u8 {
    var raw: [8]u8 = undefined;
    const bits: u64 = @bitCast(value);
    for (&raw, 0..) |*byte, shift| byte.* = @truncate(bits >> @intCast(shift * 8));
    return core.canonicalize_signed_le(&raw);
}

fn positiveBytes(value: u64) []u8 {
    var raw: [9]u8 = @splat(0);
    for (raw[0..8], 0..) |*byte, shift| byte.* = @truncate(value >> @intCast(shift * 8));
    return core.canonicalize_signed_le(if ((value >> 63) != 0) &raw else raw[0..8]);
}

fn signedInt(value: []const u8) ?i64 {
    const canonical = core.canonicalize_signed_le(value);
    if (canonical.len > 8) return null;
    var bits: u64 = if ((canonical[canonical.len - 1] & 0x80) != 0) std.math.maxInt(u64) else 0;
    for (canonical, 0..) |byte, shift| {
        const mask: u64 = @as(u64, 0xff) << @intCast(shift * 8);
        bits = (bits & ~mask) | (@as(u64, byte) << @intCast(shift * 8));
    }
    return @bitCast(bits);
}

fn positiveInt(value: []const u8) ?u64 {
    const canonical = core.canonicalize_signed_le(value);
    if ((canonical[canonical.len - 1] & 0x80) != 0 or canonical.len > 9) return null;
    if (canonical.len == 9 and canonical[8] != 0) return null;
    var result: u64 = 0;
    for (canonical[0..@min(canonical.len, 8)], 0..) |byte, shift| {
        result |= @as(u64, byte) << @intCast(shift * 8);
    }
    return result;
}

fn randomUniformI64(rng: *SplitMix64, min: i64, max: i64) i64 {
    const min_bits: u64 = @bitCast(min);
    const max_bits: u64 = @bitCast(max);
    const span = max_bits -% min_bits +% 1;
    if (span == 0) return @bitCast(rng.next());
    const limit = std.math.maxInt(u64) - (std.math.maxInt(u64) % span);
    while (true) {
        const value = rng.next();
        if (value < limit) return @bitCast(min_bits +% (value % span));
    }
}

fn serializeDraws(draws: []const Draw) []u8 {
    var out = std.ArrayList(u8).empty;
    out.appendSlice(allocator, core.choice_list_header(draws.len)) catch unreachable;
    for (draws) |item| out.appendSlice(allocator, item.entry()) catch unreachable;
    return out.toOwnedSlice(allocator) catch unreachable;
}

/// Every choice stream a run has executed, so a mutation that would only repeat
/// one is skipped. Membership is of whole streams, never of prefixes: a trie
/// with a node per byte answered the same questions while holding megabytes for
/// each long example until the run ended. Keys are owned copies, kept like the
/// rest of the shell's memory.
const StreamSet = struct {
    streams: std.StringHashMap(void),

    fn init() StreamSet {
        return .{ .streams = std.StringHashMap(void).init(allocator) };
    }

    fn contains(self: *const StreamSet, stream: []const u8) bool {
        return self.streams.contains(stream);
    }

    fn insert(self: *StreamSet, stream: []const u8) void {
        if (self.streams.contains(stream)) return;
        const owned = allocator.dupe(u8, stream) catch unreachable;
        self.streams.put(owned, {}) catch unreachable;
    }
};

fn spanLessThan(_: void, left: ChoiceSpan, right: ChoiceSpan) bool {
    const label_order = std.mem.order(u8, left.label, right.label);
    if (label_order != .eq) return label_order == .lt;
    if (left.start != right.start) return left.start < right.start;
    return left.end < right.end;
}

fn spanMutationCandidates(draws: []const Draw, spans: []const ChoiceSpan, rng: *SplitMix64) [][]u8 {
    for (draws) |item| if (item.key() != null) return &.{};

    var ranges = std.ArrayList(ChoiceSpan).empty;
    for (spans) |span| {
        if (!span.discarded and span.end > span.start and span.end <= draws.len) {
            ranges.append(allocator, span) catch unreachable;
        }
    }
    std.mem.sort(ChoiceSpan, ranges.items, {}, spanLessThan);

    var groups = std.ArrayList(struct { start: usize, end: usize }).empty;
    var group_start: usize = 0;
    while (group_start < ranges.items.len) {
        var group_end = group_start + 1;
        while (group_end < ranges.items.len and
            std.mem.eql(u8, ranges.items[group_start].label, ranges.items[group_end].label)) : (group_end += 1)
        {}
        var unique_count: usize = 0;
        for (ranges.items[group_start..group_end], 0..) |span, at| {
            if (at == 0 or span.start != ranges.items[group_start + at - 1].start or
                span.end != ranges.items[group_start + at - 1].end) unique_count += 1;
        }
        if (unique_count >= 2) groups.append(allocator, .{ .start = group_start, .end = group_end }) catch unreachable;
        group_start = group_end;
    }
    if (groups.items.len == 0) return &.{};

    const original = serializeDraws(draws);
    var candidates = std.ArrayList([]u8).empty;
    var attempt: u64 = 0;
    while (attempt < core.mutation_attempt_count()) : (attempt += 1) {
        const randomized = core.mutation_attempt_randomized(attempt);
        const selected_group = if (randomized)
            core.mutation_index(@intCast(groups.items.len), rng.next()) orelse break
        else
            0;
        const group = groups.items[selected_group];
        var unique = std.ArrayList(ChoiceSpan).empty;
        for (ranges.items[group.start..group.end], 0..) |span, at| {
            if (at == 0 or span.start != ranges.items[group.start + at - 1].start or
                span.end != ranges.items[group.start + at - 1].end) unique.append(allocator, span) catch unreachable;
        }
        const first = if (randomized)
            core.mutation_index(@intCast(unique.items.len), rng.next()) orelse continue
        else
            0;
        const second = if (randomized)
            core.mutation_distinct_index(@intCast(unique.items.len), first, rng.next()) orelse continue
        else
            1;
        var a = unique.items[first];
        var b = unique.items[second];
        if (a.start > b.start or (a.start == b.start and a.end > b.end)) std.mem.swap(ChoiceSpan, &a, &b);
        const raw = core.choice_mutate_ranges(
            original,
            a.start,
            a.end,
            b.start,
            b.end,
            core.mutation_use_first(if (randomized) rng.next() else attempt),
        ) orelse continue;
        if (std.mem.eql(u8, raw, original)) continue;
        var seen = false;
        for (candidates.items) |candidate| {
            if (std.mem.eql(u8, candidate, raw)) {
                seen = true;
                break;
            }
        }
        if (!seen) candidates.append(allocator, raw) catch unreachable;
    }
    return candidates.toOwnedSlice(allocator) catch unreachable;
}

// The choice's unconstrained index for shortlex comparison.
fn drawSortIndex(item: Draw) ?[]const u8 {
    return switch (item) {
        // A clone carries a stream, not a value: it has no index of its own,
        // and drawsCompare compares it by that stream instead.
        .clone => null,
        .boolean => |draw| core.boolean_to_index(draw.value),
        .integer => |draw| core.integer_to_index(
            signedBytes(draw.min),
            signedBytes(draw.max),
            signedBytes(draw.target),
            signedBytes(draw.value),
        ),
        .bytes => |draw| core.bytes_to_index(draw.min, draw.value),
        .string => |draw| core.string_to_index(draw.alphabet, draw.min, draw.value),
        .float => |draw| core.float_choice_to_index(
            draw.min,
            draw.max,
            draw.allow_nan,
            draw.allow_infinity,
            draw.smallest_nonzero,
            draw.value,
        ) orelse return null,
    };
}

// Where a draw currently sits in its own shrink schedule. The compiled
// schedule is defined over u64 indexes; byte draws can sit beyond that, and
// saturating keeps their earliest (most useful) candidates reachable.
fn drawIndex(item: Draw) ?u64 {
    if (item.forced()) return null;
    const index_bytes = drawSortIndex(item) orelse return null;
    return saturatedInt(index_bytes);
}

const RaiseBounds = struct { current: u64, largest: u64 };

// Where a draw sits and the largest index it could move to, for the raise pass,
// or null for a draw the pass leaves alone.
//
// Upstream raises every node but a sequence, so strings and byte strings are
// skipped — their index bundles length and content, and a larger one is a
// longer value — and so are clones, which carry a stream rather than a value,
// and forced draws, which are not this stream's to change.
fn raiseBounds(item: Draw) ?RaiseBounds {
    if (item.forced()) return null;
    const largest = switch (item) {
        .boolean => core.boolean_max_index(),
        .integer => |integer| core.integer_max_index(signedBytes(integer.min), signedBytes(integer.max)),
        .float => core.float_choice_max_index(),
        else => return null,
    };
    return .{
        .current = drawIndex(item) orelse return null,
        .largest = saturatedInt(largest) orelse return null,
    };
}

// What makes two draws duplicates of each other: the choice type — which for a
// tagged union is its tag — and the index it currently sits at.
//
// Upstream groups by (choice type, value) and lowers the group using the first
// member's constraints, accepting that a member with different constraints may
// reject the shared value. Grouping by the *index* instead is the same idea in
// the coordinate the schedule already walks: two draws with equal bounds share an
// index exactly when they share a value, and a member whose bounds differ is
// rebuilt for its own bounds or misses. A forced draw is never a member — it has
// no index and may not be rewritten.
const GroupKey = struct { tag: std.meta.Tag(Draw), index: u64 };

fn drawGroupKey(item: Draw) ?GroupKey {
    const index = drawIndex(item) orelse return null;
    return .{ .tag = std.meta.activeTag(item), .index = index };
}

// Rebuild every choice in a span at its simplest value, and report how many of
// them the pass was actually able to move.
//
// This is upstream's try_trivial_spans. Per-choice descent walks one draw at a
// time and stops the moment a candidate stops failing, so a span whose choices
// only fail *together* at their simplest values is out of its reach — and the
// all-simplest probe does not help either, because it collapses the whole
// example rather than one span of it. A forced draw is left alone, as in every
// other pass, and a draw already at index 0 is copied rather than rebuilt.
fn trivialSpanCandidate(draws: []const Draw, span: ChoiceSpan) struct { trial: []Draw, rewritable: u64 } {
    const trial = allocator.dupe(Draw, draws) catch unreachable;
    var rewritable: u64 = 0;
    var at = span.start;
    const end = @min(span.end, draws.len);
    while (at < end) : (at += 1) {
        const index = drawIndex(draws[at]) orelse continue;
        if (index == 0) continue;
        if (drawAtIndex(draws[at], 0)) |simplest| {
            trial[at] = simplest;
            rewritable += 1;
        }
    }
    return .{ .trial = trial, .rewritable = rewritable };
}

// A string draw with the character at one position removed.
//
// The whole-value index bundles length and content into one number, and the
// downward search over it converges on the wrong end of the interval: from
// "abb" over an "abcdef" alphabet it probes eleven candidates and never reaches
// "bb", which sits far below. Removing a character is the candidate that search
// cannot produce. `value` is already the packed u32-LE form.
fn shortenString(item: Draw, position: u64) ?Draw {
    if (std.meta.activeTag(item) != .string) return null;
    const text = item.string;
    if (text.forced) return null;
    const shortened = core.string_drop_character(text.value, text.min, @intCast(position)) orelse return null;
    return .{ .string = .{
        .encoded = core.serialize_string_choice_packed(shortened.len / 4, shortened),
        .value = shortened,
        .alphabet = text.alphabet,
        .min = text.min,
        .max = text.max,
        .forced = false,
        .key = text.key,
    } };
}

// A string draw with every copy of one repeated character lowered.
//
// A string draw carries a single whole-value index, so the per-choice schedule
// can only slide the entire value along one linear order. A property that
// depends on two *characters* of that value agreeing is the case it cannot
// serve — M12's shape, one level down and inside a single draw.
fn lowerCharacters(item: Draw, ordinal: u64) ?Draw {
    if (std.meta.activeTag(item) != .string) return null;
    const text = item.string;
    if (text.forced) return null;
    // `value` is already the packed u32-LE form the stream records, as
    // @string_to_index consumes it — not the host's UTF-8 string.
    const rank = core.string_duplicate_rank(text.alphabet, text.value) orelse return null;
    const target = core.shrink_candidate_at(rank, ordinal) orelse return null;
    const replaced = core.string_replace_rank(text.alphabet, text.value, rank, target) orelse return null;
    return .{ .string = .{
        .encoded = core.serialize_string_choice_packed(replaced.len / 4, replaced),
        .value = replaced,
        .alphabet = text.alphabet,
        .min = text.min,
        .max = text.max,
        .forced = false,
        .key = text.key,
    } };
}

// The ordinal-th span strictly nested inside spans[at].
//
// Upstream's pass_to_descendant picks a random descendant; a cursor machine has
// no chooser, so the ancestor is the cursor and the descendant is the ordinal.
// Spans are recorded in the order they open, so scanning forward from the
// ancestor gives a stable enumeration in every language.
fn descendantSpan(spans: []const ChoiceSpan, at: usize, ordinal: u64) ?ChoiceSpan {
    const ancestor = spans[at];
    if (ancestor.discarded or ancestor.end <= ancestor.start) return null;
    var seen: u64 = 0;
    var other = at + 1;
    while (other < spans.len) : (other += 1) {
        const candidate = spans[other];
        if (candidate.start < ancestor.start or candidate.end > ancestor.end) continue;
        if (candidate.discarded or candidate.depth <= ancestor.depth) continue;
        if (!core.shrink_descendant_worthwhile(
            ancestor.end - ancestor.start,
            candidate.end - candidate.start,
        )) continue;
        if (seen == ordinal) return candidate;
        seen += 1;
    }
    return null;
}

// The span that should trade places with spans[at].
//
// Upstream groups a span's children by label and sorts the group; taking only
// the *next* member makes each request one adjacent swap, and repeating it
// until nothing moves sorts the group the same way. A discarded span is never a
// member: its choices are a rejected candidate's debris, so its position
// carries no meaning to canonicalize.
const PaidExtent = struct { start: usize, end: usize, widened: bool };

// The choices a paid deletion of spans[at] removes, and whether that extent is
// wider than the span itself.
//
// A span of two or more choices is deleted exactly, as the deletion pass
// already tried on its own. A single-choice span takes upstream's extent: the
// span with the spanless choice before it, or else stretched to the start of
// the next span. A discarded span is never a candidate — its choices are a
// rejected candidate's debris or a collection's stop marker, and paying for
// their deletion buys nothing — and neither is an extent covering the whole
// stream.
fn paidExtent(draws: []const Draw, spans: []const ChoiceSpan, at: usize) ?PaidExtent {
    const span = spans[at];
    if (span.discarded or span.end <= span.start or span.end > draws.len) return null;
    var extent = PaidExtent{ .start = span.start, .end = span.end, .widened = false };
    if (extent.end - extent.start < 2) {
        extent.widened = true;
        var preceded = extent.start > 0;
        for (spans) |other| {
            if (other.end == extent.start and other.start < extent.start) preceded = false;
        }
        if (preceded) {
            extent.start -= 1;
        } else {
            extent.end = draws.len;
            for (spans) |other| {
                if (other.start >= span.end and other.start < extent.end) extent.end = other.start;
            }
            if (extent.end <= span.end) return null;
        }
    }
    if (extent.start == 0 and extent.end == draws.len) return null;
    return extent;
}

// The draw that pays for deleting spans[at]: the first one after the structure
// enclosing it.
//
// Upstream takes the innermost ancestor span reaching past the deletion. A
// zizek collection opens no span of its own — its elements are a run of
// adjacent sibling spans sharing a label, ending in the discarded span of its
// final "no more" choice — so that run is what plays the part of the list, and
// only a span outside any such run falls back to its ancestors.
fn paidFollower(spans: []const ChoiceSpan, at: usize, end: usize, draw_count: usize) ?usize {
    const span = spans[at];
    var run_end = span.end;
    var extended = false;
    for (spans[at + 1 ..]) |candidate| {
        if (!std.meta.eql(candidate.parent, span.parent)) continue;
        if (!std.mem.eql(u8, candidate.label, span.label) or candidate.start != run_end) break;
        run_end = candidate.end;
        extended = true;
    }
    var boundary: ?usize = null;
    if (extended) {
        boundary = run_end;
    } else {
        var parent = span.parent;
        while (parent) |index| {
            if (spans[index].end > end) {
                boundary = spans[index].end;
                break;
            }
            parent = spans[index].parent;
        }
    }
    const found = boundary orelse return null;
    if (found < end or found >= draw_count) return null;
    return found;
}

// The paying draw moved one step: an integer down or up, a boolean to the side
// the step names, a string one character shorter. Null when this draw cannot
// take this step, so the pass moves to the next one without running the
// property.
fn nudgeDraw(item: Draw, step: i64) ?Draw {
    switch (item) {
        .integer => |integer| {
            if (integer.forced) return null;
            return stepDraw(item, step);
        },
        .boolean => |boolean| {
            if (boolean.forced) return null;
            const stepped = stepDraw(item, step) orelse return null;
            if (stepped.boolean.value == boolean.value) return null;
            return stepped;
        },
        .string => |text| {
            if (step >= 0) return null;
            return shortenString(item, text.value.len / 4 - 1);
        },
        else => return null,
    }
}

fn nextSibling(spans: []const ChoiceSpan, at: usize) ?usize {
    const span = spans[at];
    if (span.discarded or span.end <= span.start) return null;
    var other = at + 1;
    while (other < spans.len) : (other += 1) {
        const candidate = spans[other];
        if (candidate.discarded or !std.meta.eql(candidate.parent, span.parent)) continue;
        if (!std.mem.eql(u8, candidate.label, span.label)) continue;
        if (candidate.end <= candidate.start or candidate.start < span.end) continue;
        return other;
    }
    return null;
}

// Where a draw sits in its schedule, for the adjacent-pair pass.
//
// Upstream's lower_integers_together takes integer nodes only, and so does
// this: the shift it makes is meaningful in value space precisely because an
// integer's index is its distance from its own shrink target. A byte string's
// index is a shortlex position, and shifting two of those by a shared amount
// preserves nothing a property could depend on.
fn pairIndex(item: Draw) ?u64 {
    if (std.meta.activeTag(item) != .integer) return null;
    return drawIndex(item);
}

fn saturatedInt(value: []const u8) ?u64 {
    if (positiveInt(value)) |index| return index;
    const canonical = core.canonicalize_signed_le(value);
    if ((canonical[canonical.len - 1] & 0x80) != 0) return null;
    return std.math.maxInt(u64);
}

fn compareDrawIndexes(left: []const u8, right: []const u8) i64 {
    return core.signed_compare_le(left, right);
}

// Choice-count-first shortlex.
fn drawsSimpler(candidate: []const Draw, current: []const Draw) bool {
    return drawsCompare(candidate, current) < 0;
}

/// Order two draw lists: negative when candidate is the simpler of the two.
///
/// The count that decides first is the *flattened* one, so a candidate that
/// removes a choice from inside a clone is simpler even though the parent's own
/// entry count has not moved — without that, a nested shrink could never make
/// progress the accept rule would keep. A clone is then compared by its own
/// stream, recursively, which is the same rule one level down.
fn drawsCompare(candidate: []const Draw, current: []const Draw) i64 {
    const left = flatDrawCount(candidate);
    const right = flatDrawCount(current);
    if (left != right) return if (left < right) -1 else 1;
    if (candidate.len != current.len) return if (candidate.len < current.len) -1 else 1;
    for (candidate, current) |candidate_draw, current_draw| {
        if (candidate_draw.child() != null or current_draw.child() != null) {
            const left_child = candidate_draw.child() orelse return 1;
            const right_child = current_draw.child() orelse return 1;
            const nested = drawsCompare(left_child.draws.items, right_child.draws.items);
            if (nested != 0) return nested;
            continue;
        }
        if (stringDrawsCompare(candidate_draw, current_draw)) |order| {
            if (order != 0) return order;
            continue;
        }
        const candidate_index = drawSortIndex(candidate_draw) orelse return 1;
        const current_index = drawSortIndex(current_draw) orelse return 1;
        const order = compareDrawIndexes(candidate_index, current_index);
        if (order != 0) return order;
    }
    return 0;
}

// Order two string draws of one alphabet and minimum size by index, or null
// for any other pair. The core compares them without building either index; a
// long string's index is too costly to build for every shrink candidate.
fn stringDrawsCompare(candidate: Draw, current: Draw) ?i64 {
    const left = switch (candidate) {
        .string => |draw| draw,
        else => return null,
    };
    const right = switch (current) {
        .string => |draw| draw,
        else => return null,
    };
    if (left.min != right.min or !std.mem.eql(u8, left.alphabet, right.alphabet)) return null;
    return core.string_index_compare(left.alphabet, left.min, left.value, right.value);
}

// Rebuild a draw at a schedule index, or report a miss with null.
/// The rebuilt draw keeps its key: a lowered candidate that lost its name
/// would be looked up positionally on the next execution, so every candidate
/// for a keyed draw would be rejected and nothing would shrink.
fn drawAtIndex(item: Draw, index: u64) ?Draw {
    switch (item) {
        // A clone is not rebuilt at an index; the nested pass shrinks the
        // stream inside it instead.
        .clone => return null,
        .boolean => {
            const value = core.boolean_from_index(positiveBytes(index)) orelse return null;
            return .{ .boolean = .{
                .encoded = core.serialize_boolean_choice(value),
                .value = value,
                .key = item.key(),
            } };
        },
        .integer => |draw| {
            const encoded = core.integer_from_index(
                signedBytes(draw.min),
                signedBytes(draw.max),
                signedBytes(draw.target),
                positiveBytes(index),
            ) orelse return null;
            const value = signedInt(encoded) orelse return null;
            return .{ .integer = .{
                .encoded = core.serialize_integer_choice(encoded),
                .value = value,
                .min = draw.min,
                .max = draw.max,
                .target = draw.target,
                .key = draw.key,
            } };
        },
        .bytes => |draw| {
            const value = core.bytes_from_index(draw.min, draw.max, positiveBytes(index)) orelse return null;
            return .{ .bytes = .{
                .encoded = core.serialize_bytes_choice(value),
                .value = value,
                .min = draw.min,
                .max = draw.max,
                .key = draw.key,
            } };
        },
        .string => |draw| {
            const value = core.string_from_index(
                draw.alphabet,
                draw.min,
                draw.max,
                positiveBytes(index),
            ) orelse return null;
            return .{ .string = .{
                .encoded = core.serialize_string_choice_packed(value.len / 4, value),
                .value = value,
                .alphabet = draw.alphabet,
                .min = draw.min,
                .max = draw.max,
                .key = draw.key,
            } };
        },
        .float => |draw| {
            const value = core.float_choice_from_index(
                draw.min,
                draw.max,
                draw.allow_nan,
                draw.allow_infinity,
                draw.smallest_nonzero,
                positiveBytes(index),
            ) orelse return null;
            return .{ .float = .{
                .encoded = core.serialize_float_choice(value),
                .value = value,
                .min = draw.min,
                .max = draw.max,
                .allow_nan = draw.allow_nan,
                .allow_infinity = draw.allow_infinity,
                .smallest_nonzero = draw.smallest_nonzero,
                .key = draw.key,
            } };
        },
    }
}

// Every shrink candidate for a draw, in schedule order.
fn candidateDraws(item: Draw) []Draw {
    var out = std.ArrayList(Draw).empty;
    const current = drawIndex(item) orelse return out.toOwnedSlice(allocator) catch unreachable;
    var ordinal: u64 = 0;
    while (core.shrink_candidate_at(current, ordinal)) |index| : (ordinal += 1) {
        const candidate = drawAtIndex(item, index) orelse continue;
        out.append(allocator, candidate) catch unreachable;
    }
    return out.toOwnedSlice(allocator) catch unreachable;
}

// ---------- targeted generation ----------

const TargetEntry = struct { score: f64, stream: []const u8 };

/// Run-level targeting state: per-label best score and the stream that
/// produced it, the firing schedule, the per-firing trial budget, and the
/// run's shared valid/attempt counters while a firing is underway. The
/// schedule, budgets, record and accept rules, stepping, and the step-size
/// search are all compiled (ir/targeting.zir); the shell holds the maps and
/// runs the trials.
const TargetingRun = struct {
    best: std.StringHashMap(TargetEntry),
    step: u64,
    next_at: u64,
    budget: u64,
    valid: usize = 0,
    attempts: usize = 0,
    found: ?TestCase = null,
    found_err: anyerror = error.Unreachable,

    fn init(examples: usize) TargetingRun {
        const step = core.targeting_schedule_step(@intCast(examples));
        return .{
            .best = std.StringHashMap(TargetEntry).init(allocator),
            .step = step,
            .next_at = step,
            .budget = core.targeting_trial_budget(@intCast(examples)),
        };
    }

    /// Folds a valid example's observations into the per-label bests.
    fn record(self: *TargetingRun, case: *TestCase) void {
        const targets = case.family.targets orelse return;
        var walk = targets.iterator();
        while (walk.next()) |observation| {
            const entry = self.best.get(observation.key_ptr.*);
            const best_score = if (entry) |seen| seen.score else 0.0;
            if (core.targeting_record(entry != null, best_score, observation.value_ptr.*)) {
                self.best.put(observation.key_ptr.*, .{
                    .score = observation.value_ptr.*,
                    .stream = case.serialized(),
                }) catch unreachable;
            }
        }
    }
};

/// Whether the targeting hill climber can step a draw. Strings have no
/// sensible "one larger", clones are streams rather than values, and a forced
/// draw is not this stream's to change.
fn climbableDraw(draw: Draw) bool {
    if (draw.forced()) return false;
    return switch (draw) {
        .integer, .boolean, .float, .bytes => true,
        else => false,
    };
}

/// An integer draw at the ordinal-th extra lowering candidate, or null.
///
/// The index schedule bisects, which finds the edge of an interval; a sparse
/// failing set such as the positive multiples of 1000 is not one, and from
/// 10^9 the bisection stops at 875000. The divisions and trailing-zeros moves
/// that carry on from there are compiled (integer_shrink_extra); this only
/// re-encodes the value they choose.
fn integerExtraDraw(draw: Draw, ordinal: u64) ?Draw {
    switch (draw) {
        .integer => |integer| {
            if (integer.forced) return null;
            const next = core.integer_shrink_extra(
                signedBytes(integer.min),
                signedBytes(integer.max),
                signedBytes(integer.target),
                signedBytes(integer.value),
                ordinal,
            ) orelse return null;
            var lowered = integer;
            lowered.value = signedInt(next) orelse return null;
            lowered.encoded = core.serialize_integer_choice(next);
            return Draw{ .integer = lowered };
        },
        else => return null,
    }
}

/// The draw stepped by delta, or null when the stepped value is not
/// representable within the draw's own constraints. Which values are
/// reachable is compiled (ir/targeting.zir targeting_step_*); this only
/// re-encodes the answer as a stream entry.
fn stepDraw(draw: Draw, delta: i64) ?Draw {
    switch (draw) {
        .integer => |integer| {
            const next = core.targeting_step_integer(
                signedBytes(integer.min),
                signedBytes(integer.max),
                signedBytes(integer.value),
                delta,
            ) orelse return null;
            var stepped = integer;
            stepped.value = signedInt(next) orelse return null;
            stepped.encoded = core.serialize_integer_choice(next);
            stepped.forced = false;
            return Draw{ .integer = stepped };
        },
        .boolean => |boolean| {
            const next = core.targeting_step_boolean(boolean.value, delta) orelse return null;
            var stepped = boolean;
            stepped.value = next;
            stepped.encoded = core.serialize_boolean_choice(next);
            stepped.forced = false;
            return Draw{ .boolean = stepped };
        },
        .float => |float| {
            const next = core.targeting_step_float(
                float.min,
                float.max,
                float.allow_nan,
                float.allow_infinity,
                float.smallest_nonzero,
                float.value,
                delta,
            ) orelse return null;
            var stepped = float;
            stepped.value = next;
            stepped.encoded = core.serialize_float_choice(next);
            stepped.forced = false;
            return Draw{ .float = stepped };
        },
        .bytes => |bytes| {
            const next = core.targeting_step_bytes(bytes.min, bytes.max, bytes.value, delta) orelse
                return null;
            var stepped = bytes;
            stepped.value = next;
            stepped.encoded = core.serialize_bytes_choice(next);
            stepped.forced = false;
            return Draw{ .bytes = stepped };
        },
        else => return null,
    }
}

const TargetingTrial = struct { case: TestCase, outcome: anyerror!void };

/// One targeting trial: replay a stepped stream with fresh-RNG extension —
/// the execution mode mutation probes already use — counting it as an
/// ordinary attempt. Answers null when the firing's budget is spent.
fn targetingTrial(
    property: anytype,
    stream: []const u8,
    rng: *SplitMix64,
    seen_streams: *StreamSet,
    run: *TargetingRun,
    examples: usize,
) ?TargetingTrial {
    if (run.valid >= examples or run.attempts >= run.budget) return null;
    run.attempts += 1;
    var case = TestCase.probe(stream, rng.*);
    _ = rng.next();
    const outcome = execute(property, &case);
    seen_streams.insert(case.serialized());
    if (outcome) |_| {
        run.valid += 1;
        run.record(&case);
    } else |_| {}
    return .{ .case = case, .outcome = outcome };
}

/// Hill-climbs one label's best-known stream: walk its realized draws from
/// the end backwards, stepping each climbable draw through the compiled
/// step-size search, in the +k direction and then -k. A failing trial is
/// stored on the run for the ordinary counterexample path. Mirrors
/// hegel-c/src/native/targeting.rs::hill_climb.
fn targetingClimb(
    property: anytype,
    label: []const u8,
    allowance: u64,
    rng: *SplitMix64,
    seen_streams: *StreamSet,
    run: *TargetingRun,
    examples: usize,
) u64 {
    const start = run.best.get(label).?.stream;
    const first = targetingTrial(property, start, rng, seen_streams, run, examples) orelse return 0;
    if (classify(first.outcome) == outcome_interesting) {
        run.found = first.case;
        first.outcome catch |err| {
            run.found_err = err;
        };
        return 0;
    }
    if (classify(first.outcome) != outcome_valid) return 0;

    var current = first.case;
    var current_score = -std.math.inf(f64);
    if (current.family.targets) |targets| {
        if (targets.get(label)) |score| current_score = score;
    }
    var improvements: u64 = 0;
    var examined = std.AutoHashMap(usize, void).init(allocator);
    defer examined.deinit();
    var at: isize = @as(isize, @intCast(current.draws.items.len)) - 1;
    var previous_length = current.draws.items.len;
    while (at >= 0 and improvements <= allowance) {
        if (current.draws.items.len != previous_length) {
            at = @as(isize, @intCast(current.draws.items.len)) - 1;
            previous_length = current.draws.items.len;
            continue;
        }
        const index: usize = @intCast(at);
        const seen = examined.getOrPut(index) catch unreachable;
        if (seen.found_existing) {
            at -= 1;
            continue;
        }
        if (climbableDraw(current.draws.items[index])) {
            const length_before = current.draws.items.len;
            for ([_]i64{ 1, -1 }) |direction| {
                // The -k direction only makes sense while the draw survived
                // the +k climb at the same index with the stream length
                // unchanged.
                if (direction == -1 and
                    (index >= current.draws.items.len or
                        current.draws.items.len != length_before))
                {
                    break;
                }
                var mode: u64 = 0;
                var a: u64 = 1;
                var b: u64 = 0;
                while (true) {
                    // A committed improvement may have shortened the stream
                    // below this index; the outer walk restarts from the new
                    // end.
                    if (index >= current.draws.items.len) break;
                    const probe = core.find_integer_probe(mode, a, b) orelse break;
                    var committed = false;
                    if (probe <= core.targeting_step_cap()) {
                        if (stepDraw(current.draws.items[index], direction * @as(i64, @intCast(probe)))) |stepped| {
                            var draws = allocator.alloc(Draw, current.draws.items.len) catch unreachable;
                            @memcpy(draws, current.draws.items);
                            draws[index] = stepped;
                            const trial = targetingTrial(
                                property,
                                serializeDraws(draws),
                                rng,
                                seen_streams,
                                run,
                                examples,
                            ) orelse return improvements;
                            if (classify(trial.outcome) == outcome_interesting) {
                                run.found = trial.case;
                                trial.outcome catch |err| {
                                    run.found_err = err;
                                };
                                return improvements;
                            }
                            if (classify(trial.outcome) == outcome_valid) {
                                const trial_case = trial.case;
                                var trial_score = -std.math.inf(f64);
                                if (trial_case.family.targets) |targets| {
                                    if (targets.get(label)) |score| trial_score = score;
                                }
                                const accept = core.targeting_accept(
                                    trial_score,
                                    current_score,
                                    @intCast(flatDrawCount(trial_case.draws.items)),
                                    @intCast(flatDrawCount(current.draws.items)),
                                );
                                if (accept != 0) {
                                    current = trial_case;
                                    current_score = trial_score;
                                    if (accept == 2) improvements += 1;
                                    committed = true;
                                }
                            }
                        }
                    }
                    const next_mode = core.find_integer_next_mode(mode, a, b, committed);
                    const next_a = core.find_integer_next_a(mode, a, b, committed);
                    const next_b = core.find_integer_next_b(mode, a, b, committed);
                    mode = next_mode;
                    a = next_a;
                    b = next_b;
                }
            }
        }
        at -= 1;
    }
    return improvements;
}

/// Climbs every label until a full round improves nothing or the budget is
/// spent. Mirrors targeting.rs::optimise_targets, with the improvement
/// allowance doubling each round.
fn optimiseTargets(
    property: anytype,
    rng: *SplitMix64,
    seen_streams: *StreamSet,
    run: *TargetingRun,
    examples: usize,
) void {
    var round: u64 = 0;
    while (true) {
        const calls_before = run.attempts;
        var any_improvements = false;
        const allowance = core.targeting_improvement_allowance(round);
        var labels: std.ArrayList([]const u8) = .empty;
        defer labels.deinit(allocator);
        var walk = run.best.keyIterator();
        while (walk.next()) |label| labels.append(allocator, label.*) catch unreachable;
        std.mem.sort([]const u8, labels.items, {}, stringLessThan);
        for (labels.items) |label| {
            if (targetingClimb(property, label, allowance, rng, seen_streams, run, examples) > 0) {
                any_improvements = true;
            }
            if (run.found != null) return;
        }
        round += 1;
        if (!any_improvements or run.attempts == calls_before) return;
    }
}

fn stringLessThan(_: void, left: []const u8, right: []const u8) bool {
    return std.mem.order(u8, left, right) == .lt;
}

fn execute(property: anytype, case: *TestCase) anyerror!void {
    defer case.closeOpenSpans();
    return property(case);
}

// Outcome tags are defined by ir/lifecycle.zir. Deriving one from a Zig error
// is this shell's job; deciding what it means is the core's.
const outcome_valid: u64 = 0;
const outcome_rejected: u64 = 1;
const outcome_overrun: u64 = 2;
const outcome_invalid: u64 = 3;
const outcome_interesting: u64 = 4;

fn classify(result: anyerror!void) u64 {
    result catch |err| {
        if (err == error.AssumptionRejected) return outcome_rejected;
        if (err == error.ReplayOverrun or err == error.ChoiceOverrun) return outcome_overrun;
        if (err == error.InvalidReplay) return outcome_invalid;
        return outcome_interesting;
    };
    return outcome_valid;
}

/// What a failure reports as its cause: the assertion message when the shell
/// failed the example on the property's behalf (always / unreachable), the
/// error name otherwise.
fn failureCause(case: *const TestCase, err: anyerror) []const u8 {
    if (err == error.AlwaysFailed or err == error.UnreachableReached) {
        if (case.assertion_failure) |message| return message;
    }
    return @errorName(err);
}

/// Identify which bug a failure represents. A Zig error is a named value, so
/// the name is the identity; distinct errors give distinct attribution, while
/// one error value raised from several places cannot be told apart. An
/// assertion the shell fails on the property's behalf (always / unreachable)
/// is instead identified by its recorded message, which embeds the label — so
/// two assertion labels stay two bugs even though they share one error value.
fn interestingOrigin(case: *const TestCase, result: anyerror!void) []const u8 {
    result catch |err| return failureCause(case, err);
    return "";
}

/// Whether an outcome is a failure of the bug being shrunk. Accepting any
/// failure lets the search migrate to an unrelated bug that happens to be
/// easier to reach, and then report a minimal counterexample for a bug the run
/// never found.
fn isFailure(case: *const TestCase, result: anyerror!void, origin: []const u8) bool {
    const outcome = classify(result);
    if (!core.outcome_is_failure(outcome)) return false;
    const matches = origin.len == 0 or std.mem.eql(u8, interestingOrigin(case, result), origin);
    return core.shrink_accept(outcome, matches);
}

// Request kinds and feedback codes are defined by ir/lifecycle.zir.
const request_done: u64 = 0;
const request_baseline: u64 = 1;
const request_delete_span: u64 = 2;
const request_lower: u64 = 3;
const request_verify: u64 = 4;
const request_lower_duplicates: u64 = 5;
const request_lower_pair: u64 = 6;
const request_reorder: u64 = 7;
const request_trivial_span: u64 = 8;
const request_descendant: u64 = 9;
const request_lower_characters: u64 = 10;
const request_shorten_string: u64 = 11;
const request_delete_paid: u64 = 12;
const request_raise: u64 = 13;

const feedback_skip: u64 = 0;
const feedback_rejected: u64 = 1;
const feedback_accepted: u64 = 2;

// Serve the generated shrink schedule until it reports done.
//
// The search order lives in the core; this loop only runs the property, maps
// the host's outcome onto a feedback code, and turns a request into a
// concrete candidate. Zero caps leave the search unbounded.
/// One stream the driver can minimize: the family's own, or the stream inside
/// the clone at `path`.
const Level = union(enum) {
    family,
    clone: struct { stream: []const u8, path: []const usize },
};

/// One execution of a candidate: the whole family it produced, and the draws
/// and spans of the case the candidate stream became. The two differ only when
/// the level being shrunk is a clone's stream rather than the family's own.
const ShrinkRun = struct {
    case: TestCase,
    outcome: anyerror!void,
    subject_draws: []const Draw,
    subject_spans: []const ChoiceSpan,
};

/// Walk a path from a family to the clone stream it names.
fn caseAt(family: *TestCase, path: []const usize) ?*TestCase {
    var at: *TestCase = family;
    for (path) |index| {
        if (index >= at.draws.items.len) return null;
        at = at.draws.items[index].child() orelse return null;
    }
    return at;
}

/// Every clone position in a family, outermost first, as the index path from
/// the family's own stream down to the clone.
///
/// A path rather than a pointer because each candidate re-runs the property and
/// so builds a whole new family: the case a path names survives that, a pointer
/// into the previous run does not.
fn clonePaths(draws: []const Draw, prefix: []const usize, out: *std.ArrayList([]const usize)) void {
    for (draws, 0..) |draw, at| {
        const stream = draw.child() orelse continue;
        var path = allocator.alloc(usize, prefix.len + 1) catch unreachable;
        @memcpy(path[0..prefix.len], prefix);
        path[prefix.len] = at;
        out.append(allocator, path) catch unreachable;
        clonePaths(stream.draws.items, path, out);
    }
}

/// Rebuild `stream` with the clone named by `path` carrying `inner`.
///
/// This is the extract-and-splice the structural core is built around
/// (ir/structure.zir): the bytes inside a clone entry are already a well-formed
/// choice stream, so descending is one extraction per level and the recursion
/// lives here rather than in the IR, which forbids it.
fn spliceAt(stream: []const u8, path: []const usize, inner: []const u8) ?[]const u8 {
    const offset = core.choice_offset_at(stream, path[0]) orelse return null;
    if (path.len > 1) {
        const nested = core.clone_inner_stream(stream, offset) orelse return null;
        const rebuilt = spliceAt(nested, path[1..], inner) orelse return null;
        return core.clone_replace_inner(stream, offset, rebuilt);
    }
    return core.clone_replace_inner(stream, offset, inner);
}

/// Run one candidate through a level.
///
/// A clone level splices the candidate into the family's stream at the clone's
/// position and replays the whole property, so what is judged is the family's
/// outcome — the child's choices matter only through the failure they still
/// produce. The realized child stream is then read back out of that run.
fn runLevel(property: anytype, level: Level, candidate: []const u8) *ShrinkRun {
    const run = allocator.create(ShrinkRun) catch unreachable;
    // A candidate this level cannot even build reports as a run that did not
    // fail, which the accept rule rejects like any other.
    run.* = .{
        .case = TestCase.replaying(core.choice_list_header(0)),
        .outcome = {},
        .subject_draws = &.{},
        .subject_spans = &.{},
    };
    switch (level) {
        .family => {
            run.case = TestCase.replaying(candidate);
            run.outcome = execute(property, &run.case);
            run.subject_draws = run.case.draws.items;
            run.subject_spans = run.case.spans_list.items;
        },
        .clone => |nested| {
            const spliced = spliceAt(nested.stream, nested.path, candidate) orelse return run;
            run.case = TestCase.replaying(spliced);
            run.outcome = execute(property, &run.case);
            // The candidate changed the shape of the run: whatever it is, it is
            // not this clone's stream any more, so there is nothing to adopt.
            const subject = caseAt(&run.case, nested.path) orelse {
                run.outcome = {};
                return run;
            };
            run.subject_draws = subject.draws.items;
            run.subject_spans = subject.spans_list.items;
        },
    }
    return run;
}

/// What one run of the driver over a level reached. `shrinks` is how many
/// shrinks the sweep accepted, which is what its cap counts.
const ShrinkStream = struct {
    cause: ?[]const u8,
    case: TestCase,
    best: TestCase,
    accepted: bool,
    shrinks: u64,
};

/// The shrinker replayed an example that had failed and it did not fail the
/// same way. check reports it as error.Flaky.
const FlakyReplay = error{FlakyReplay};

/// Serve the generated shrink schedule over one level until it reports done.
fn shrinkStream(
    property: anytype,
    level: Level,
    family: *TestCase,
    subject_draws: []const Draw,
    subject_spans: []const ChoiceSpan,
    origin: []const u8,
    max_shrinks: u64,
    max_stall: u64,
) FlakyReplay!ShrinkStream {
    var draws = allocator.dupe(Draw, subject_draws) catch unreachable;
    var spans = allocator.dupe(ChoiceSpan, subject_spans) catch unreachable;
    var family_draws = allocator.dupe(Draw, family.draws.items) catch unreachable;
    var cost = family.totalCost();
    var best: TestCase = family.*;
    var accepted = false;
    var verified_cause: ?[]const u8 = null;
    var verified_case: TestCase = undefined;
    var schedule_at: ?u64 = null;
    var schedule_index: ?u64 = null;
    var schedule_count: u64 = 0;

    var phase: u64 = 0;
    var span_cursor: u64 = 0;
    var duplicate_cursor: u64 = 0;
    var position: u64 = 0;
    var pair_cursor: u64 = 0;
    var reorder_cursor: u64 = 0;
    var trivial_cursor: u64 = 0;
    var descendant_cursor: u64 = 0;
    var character_cursor: u64 = 0;
    var shorten_cursor: u64 = 0;
    var paid_cursor: u64 = 0;
    var raise_cursor: u64 = 0;
    var ordinal: u64 = 0;
    var shrinks: u64 = 0;
    var stall: u64 = 0;
    while (true) {
        const kind = core.shrink_request_kind(
            phase,
            span_cursor,
            duplicate_cursor,
            position,
            pair_cursor,
            reorder_cursor,
            trivial_cursor,
            descendant_cursor,
            character_cursor,
            shorten_cursor,
            paid_cursor,
            raise_cursor,
            draws.len,
            spans.len,
        );
        if (kind == request_done) break;

        var feedback: u64 = feedback_skip;
        switch (kind) {
            request_baseline => {
                // The baseline replays a stream that has already failed — the
                // example as found, or a candidate that failed when it was
                // adopted — so one that does not fail now is the property, not
                // the search.
                const run = runLevel(property, level, serializeDraws(draws));
                if (!isFailure(&run.case, run.outcome, origin)) return error.FlakyReplay;
                if (run.case.totalCost() < cost or
                    drawsCompare(run.case.draws.items, family_draws) < 0) accepted = true;

                draws = allocator.dupe(Draw, run.subject_draws) catch unreachable;

                spans = allocator.dupe(ChoiceSpan, run.subject_spans) catch unreachable;

                family_draws = allocator.dupe(Draw, run.case.draws.items) catch unreachable;

                cost = run.case.totalCost();

                best = run.case;

                schedule_at = null;
                feedback = feedback_accepted;
            },
            request_delete_span => {
                const span = spans[@intCast(core.shrink_request_span(span_cursor, spans.len))];
                const candidate = if (span.end > span.start)
                    core.choice_delete_range(serializeDraws(draws), span.start, span.end)
                else
                    null;
                if (candidate) |raw| {
                    const run = runLevel(property, level, raw);
                    if (isFailure(&run.case, run.outcome, origin) and core.shrink_cost_progress(
                        run.case.totalCost(),
                        cost,
                        drawsSimpler(run.case.draws.items, family_draws),
                    )) {
                        if (run.case.totalCost() < cost or
                            drawsCompare(run.case.draws.items, family_draws) < 0) accepted = true;

                        draws = allocator.dupe(Draw, run.subject_draws) catch unreachable;

                        spans = allocator.dupe(ChoiceSpan, run.subject_spans) catch unreachable;

                        family_draws = allocator.dupe(Draw, run.case.draws.items) catch unreachable;

                        cost = run.case.totalCost();

                        best = run.case;

                        schedule_at = null;
                        feedback = feedback_accepted;
                    } else {
                        feedback = feedback_rejected;
                    }
                }
            },
            request_delete_paid => {
                // A deletion the plain pass could not make, paid for by moving
                // the draw after the enclosing structure one step: a list's
                // declared length, an index into it, a parity flag drawn after
                // it.
                const at: usize = @intCast(core.shrink_request_span(paid_cursor, spans.len));
                if (paidExtent(draws, spans, at)) |extent| {
                    const follower = paidFollower(spans, at, extent.end, draws.len);
                    const step: ?i64 = if (follower != null or extent.widened)
                        core.shrink_delete_paid_variant(ordinal, extent.widened)
                    else
                        null;
                    if (step) |nudge| {
                        const width = extent.end - extent.start;
                        const trial = allocator.alloc(Draw, draws.len - width) catch unreachable;
                        @memcpy(trial[0..extent.start], draws[0..extent.start]);
                        @memcpy(trial[extent.start..], draws[extent.end..]);
                        var legal = true;
                        if (nudge != 0) {
                            if (follower) |index| {
                                if (nudgeDraw(draws[index], nudge)) |nudged| {
                                    trial[index - width] = nudged;
                                } else legal = false;
                            } else legal = false;
                        }
                        if (!legal) {
                            // This draw cannot take this step; try the next one
                            // without running the property.
                            feedback = feedback_rejected;
                        } else {
                            const run = runLevel(property, level, serializeDraws(trial));
                            if (isFailure(&run.case, run.outcome, origin) and core.shrink_cost_progress(
                                run.case.totalCost(),
                                cost,
                                drawsSimpler(run.case.draws.items, family_draws),
                            )) {
                                if (run.case.totalCost() < cost or
                                    drawsCompare(run.case.draws.items, family_draws) < 0) accepted = true;

                                draws = allocator.dupe(Draw, run.subject_draws) catch unreachable;

                                spans = allocator.dupe(ChoiceSpan, run.subject_spans) catch unreachable;

                                family_draws = allocator.dupe(Draw, run.case.draws.items) catch unreachable;

                                cost = run.case.totalCost();

                                best = run.case;

                                schedule_at = null;
                                feedback = feedback_accepted;
                            } else {
                                feedback = feedback_rejected;
                            }
                        }
                    }
                }
            },
            request_lower => {
                if (schedule_at == null or schedule_at.? != position) {
                    schedule_at = position;
                    schedule_index = drawIndex(draws[@intCast(position)]);
                    schedule_count = if (schedule_index) |current| core.shrink_candidate_count(current) else 0;
                }
                var scheduled = false;
                var lowered: ?Draw = null;
                if (schedule_index) |current| {
                    if (core.shrink_candidate_at(current, ordinal)) |target_index| {
                        scheduled = true;
                        lowered = drawAtIndex(draws[@intCast(position)], target_index);
                    } else if (integerExtraDraw(draws[@intCast(position)], ordinal - schedule_count)) |extra| {
                        // Past the index schedule an integer still has the
                        // value-space moves bisection cannot make.
                        scheduled = true;
                        lowered = extra;
                    }
                }
                if (scheduled) {
                    if (lowered) |candidate| {
                        const trial = allocator.dupe(Draw, draws) catch unreachable;
                        trial[@intCast(position)] = candidate;
                        const run = runLevel(property, level, serializeDraws(trial));
                        if (isFailure(&run.case, run.outcome, origin) and core.shrink_cost_progress(
                            run.case.totalCost(),
                            cost,
                            drawsSimpler(run.case.draws.items, family_draws),
                        )) {
                            if (run.case.totalCost() < cost or
                                drawsCompare(run.case.draws.items, family_draws) < 0) accepted = true;

                            draws = allocator.dupe(Draw, run.subject_draws) catch unreachable;

                            spans = allocator.dupe(ChoiceSpan, run.subject_spans) catch unreachable;

                            family_draws = allocator.dupe(Draw, run.case.draws.items) catch unreachable;

                            cost = run.case.totalCost();

                            best = run.case;

                            schedule_at = null;
                            feedback = feedback_accepted;
                        } else {
                            feedback = feedback_rejected;
                        }
                    } else {
                        // No legal value here; step the schedule without
                        // running.
                        feedback = feedback_rejected;
                    }
                }
            },
            request_lower_duplicates => {
                // Every draw that currently sits where this one does, lowered as
                // one. Neither member can move alone when the property depends on
                // them being equal: dropping either breaks the failure, so the
                // per-choice pass rejects every candidate and leaves the pair
                // where it was.
                var members: std.ArrayList(usize) = .empty;
                var group_index: u64 = 0;
                if (drawGroupKey(draws[@intCast(duplicate_cursor)])) |key| {
                    group_index = key.index;
                    for (draws, 0..) |item, at| {
                        if (drawGroupKey(item)) |other| {
                            if (other.tag == key.tag and other.index == key.index) {
                                members.append(allocator, at) catch unreachable;
                            }
                        }
                    }
                }
                // One position drives each group, so a group of n is tried once
                // and not n times.
                const leads = members.items.len > 0 and
                    members.items[0] == @as(usize, @intCast(duplicate_cursor));
                const index = if (leads and
                    core.shrink_duplicate_worthwhile(members.items.len, group_index))
                    core.shrink_candidate_at(group_index, ordinal)
                else
                    null;
                if (index) |target_index| {
                    const trial = allocator.dupe(Draw, draws) catch unreachable;
                    var missed = false;
                    for (members.items) |at| {
                        if (drawAtIndex(draws[at], target_index)) |candidate| {
                            trial[at] = candidate;
                        } else {
                            missed = true;
                            break;
                        }
                    }
                    if (missed) {
                        // No legal value for some member; step the schedule
                        // without running the property.
                        feedback = feedback_rejected;
                    } else {
                        const run = runLevel(property, level, serializeDraws(trial));
                        if (isFailure(&run.case, run.outcome, origin) and core.shrink_cost_progress(
                            run.case.totalCost(),
                            cost,
                            drawsSimpler(run.case.draws.items, family_draws),
                        )) {
                            if (run.case.totalCost() < cost or
                                drawsCompare(run.case.draws.items, family_draws) < 0) accepted = true;

                            draws = allocator.dupe(Draw, run.subject_draws) catch unreachable;

                            spans = allocator.dupe(ChoiceSpan, run.subject_spans) catch unreachable;

                            family_draws = allocator.dupe(Draw, run.case.draws.items) catch unreachable;

                            cost = run.case.totalCost();

                            best = run.case;

                            schedule_at = null;
                            feedback = feedback_accepted;
                        } else {
                            feedback = feedback_rejected;
                        }
                    }
                }
            },
            request_lower_pair => {
                // Two adjacent integer draws, lowered by one shared amount.
                // This is the difference-preserving move: a property that fails
                // on x-y==5 rejects every candidate the per-choice pass offers,
                // because lowering either member alone changes the difference.
                const members = [2]usize{
                    @intCast(pair_cursor),
                    @as(usize, @intCast(pair_cursor)) + 1,
                };
                const indexes = [2]?u64{
                    pairIndex(draws[members[0]]),
                    pairIndex(draws[members[1]]),
                };
                var base: u64 = 0;
                const index = if (indexes[0] != null and indexes[1] != null and
                    core.shrink_pair_worthwhile(indexes[0].?, indexes[1].?))
                blk: {
                    base = core.shrink_pair_base(indexes[0].?, indexes[1].?);
                    break :blk core.shrink_candidate_at(base, ordinal);
                } else null;
                if (index) |target_index| {
                    const trial = allocator.dupe(Draw, draws) catch unreachable;
                    var missed = false;
                    for (members, indexes) |at, current| {
                        const shifted = core.shrink_pair_candidate(current.?, base, target_index);
                        if (shifted == null) {
                            missed = true;
                            break;
                        }
                        if (drawAtIndex(draws[at], shifted.?)) |candidate| {
                            trial[at] = candidate;
                        } else {
                            missed = true;
                            break;
                        }
                    }
                    if (missed) {
                        // No legal value for one member; step the schedule
                        // without running the property.
                        feedback = feedback_rejected;
                    } else {
                        const run = runLevel(property, level, serializeDraws(trial));
                        if (isFailure(&run.case, run.outcome, origin) and core.shrink_cost_progress(
                            run.case.totalCost(),
                            cost,
                            drawsSimpler(run.case.draws.items, family_draws),
                        )) {
                            if (run.case.totalCost() < cost or
                                drawsCompare(run.case.draws.items, family_draws) < 0) accepted = true;

                            draws = allocator.dupe(Draw, run.subject_draws) catch unreachable;

                            spans = allocator.dupe(ChoiceSpan, run.subject_spans) catch unreachable;

                            family_draws = allocator.dupe(Draw, run.case.draws.items) catch unreachable;

                            cost = run.case.totalCost();

                            best = run.case;

                            schedule_at = null;
                            feedback = feedback_accepted;
                        } else {
                            feedback = feedback_rejected;
                        }
                    }
                }
            },
            request_trivial_span => {
                // A whole span at its simplest values, in one execution.
                const span = spans[@intCast(trivial_cursor)];
                if (!span.discarded and span.end > span.start) {
                    const built = trivialSpanCandidate(draws, span);
                    if (core.shrink_trivial_worthwhile(built.rewritable)) {
                        const run = runLevel(property, level, serializeDraws(built.trial));
                        if (isFailure(&run.case, run.outcome, origin) and core.shrink_cost_progress(
                            run.case.totalCost(),
                            cost,
                            drawsSimpler(run.case.draws.items, family_draws),
                        )) {
                            if (run.case.totalCost() < cost or
                                drawsCompare(run.case.draws.items, family_draws) < 0) accepted = true;

                            draws = allocator.dupe(Draw, run.subject_draws) catch unreachable;

                            spans = allocator.dupe(ChoiceSpan, run.subject_spans) catch unreachable;

                            family_draws = allocator.dupe(Draw, run.case.draws.items) catch unreachable;

                            cost = run.case.totalCost();

                            best = run.case;

                            schedule_at = null;
                            feedback = feedback_accepted;
                        } else {
                            feedback = feedback_rejected;
                        }
                    }
                }
            },
            request_descendant => {
                // A span replaced by one of its own descendants. Deletion
                // removes a whole subtree; this keeps the subtree and discards
                // the structure wrapped around it, which is the move a nested
                // failure needs when the interesting part is buried rather than
                // beside something.
                const candidate = if (descendantSpan(spans, @intCast(descendant_cursor), ordinal)) |inner| blk: {
                    const outer = spans[@intCast(descendant_cursor)];
                    // Two deletions rather than a new primitive: drop the tail
                    // after the descendant, then the head before it. Trailing
                    // first, so the leading offsets are still the ones measured
                    // above.
                    const after = core.choice_delete_range(
                        serializeDraws(draws),
                        inner.end,
                        outer.end,
                    ) orelse break :blk null;
                    break :blk core.choice_delete_range(after, outer.start, inner.start);
                } else null;
                if (candidate) |stream| {
                    const run = runLevel(property, level, stream);
                    if (isFailure(&run.case, run.outcome, origin) and core.shrink_cost_progress(
                        run.case.totalCost(),
                        cost,
                        drawsSimpler(run.case.draws.items, family_draws),
                    )) {
                        if (run.case.totalCost() < cost or
                            drawsCompare(run.case.draws.items, family_draws) < 0) accepted = true;

                        draws = allocator.dupe(Draw, run.subject_draws) catch unreachable;

                        spans = allocator.dupe(ChoiceSpan, run.subject_spans) catch unreachable;

                        family_draws = allocator.dupe(Draw, run.case.draws.items) catch unreachable;

                        cost = run.case.totalCost();

                        best = run.case;

                        schedule_at = null;
                        feedback = feedback_accepted;
                    } else {
                        feedback = feedback_rejected;
                    }
                }
            },
            request_reorder => {
                // Two sibling spans trade places. Nothing about the example
                // changes except which order its parts were drawn in, so this
                // reports a canonical arrangement rather than the one
                // generation stumbled on.
                const candidate = if (nextSibling(spans, @intCast(reorder_cursor))) |sibling| blk: {
                    const first = spans[@intCast(reorder_cursor)];
                    const second = spans[sibling];
                    break :blk core.choice_swap_ranges(
                        serializeDraws(draws),
                        first.start,
                        first.end,
                        second.start,
                        second.end,
                    );
                } else null;
                if (candidate) |stream| {
                    const run = runLevel(property, level, stream);
                    if (isFailure(&run.case, run.outcome, origin) and core.shrink_cost_progress(
                        run.case.totalCost(),
                        cost,
                        drawsSimpler(run.case.draws.items, family_draws),
                    )) {
                        if (run.case.totalCost() < cost or
                            drawsCompare(run.case.draws.items, family_draws) < 0) accepted = true;

                        draws = allocator.dupe(Draw, run.subject_draws) catch unreachable;

                        spans = allocator.dupe(ChoiceSpan, run.subject_spans) catch unreachable;

                        family_draws = allocator.dupe(Draw, run.case.draws.items) catch unreachable;

                        cost = run.case.totalCost();

                        best = run.case;

                        schedule_at = null;
                        feedback = feedback_accepted;
                    } else {
                        feedback = feedback_rejected;
                    }
                }
            },
            request_shorten_string => {
                // One character removed from a string draw.
                if (shortenString(draws[@intCast(shorten_cursor)], ordinal)) |candidate| {
                    const trial = allocator.dupe(Draw, draws) catch unreachable;
                    trial[@intCast(shorten_cursor)] = candidate;
                    const run = runLevel(property, level, serializeDraws(trial));
                    if (isFailure(&run.case, run.outcome, origin) and core.shrink_cost_progress(
                        run.case.totalCost(),
                        cost,
                        drawsSimpler(run.case.draws.items, family_draws),
                    )) {
                        if (run.case.totalCost() < cost or
                            drawsCompare(run.case.draws.items, family_draws) < 0) accepted = true;

                        draws = allocator.dupe(Draw, run.subject_draws) catch unreachable;

                        spans = allocator.dupe(ChoiceSpan, run.subject_spans) catch unreachable;

                        family_draws = allocator.dupe(Draw, run.case.draws.items) catch unreachable;

                        cost = run.case.totalCost();

                        best = run.case;

                        schedule_at = null;
                        feedback = feedback_accepted;
                    } else {
                        feedback = feedback_rejected;
                    }
                }
            },
            request_lower_characters => {
                // Every copy of one repeated character in a string draw,
                // lowered together.
                if (lowerCharacters(draws[@intCast(character_cursor)], ordinal)) |candidate| {
                    const trial = allocator.dupe(Draw, draws) catch unreachable;
                    trial[@intCast(character_cursor)] = candidate;
                    const run = runLevel(property, level, serializeDraws(trial));
                    if (isFailure(&run.case, run.outcome, origin) and core.shrink_cost_progress(
                        run.case.totalCost(),
                        cost,
                        drawsSimpler(run.case.draws.items, family_draws),
                    )) {
                        if (run.case.totalCost() < cost or
                            drawsCompare(run.case.draws.items, family_draws) < 0) accepted = true;

                        draws = allocator.dupe(Draw, run.subject_draws) catch unreachable;

                        spans = allocator.dupe(ChoiceSpan, run.subject_spans) catch unreachable;

                        family_draws = allocator.dupe(Draw, run.case.draws.items) catch unreachable;

                        cost = run.case.totalCost();

                        best = run.case;

                        schedule_at = null;
                        feedback = feedback_accepted;
                    } else {
                        feedback = feedback_rejected;
                    }
                }
            },
            request_raise => {
                // One draw made *less* simple, kept only when the run that
                // comes back is smaller: a gate past its threshold, so the
                // draws behind it are never made. The candidate is larger as
                // written, so the accept rule judges the executed run alone.
                const raised: ?u64 = if (raiseBounds(draws[@intCast(raise_cursor)])) |bounds|
                    core.shrink_raise_candidate(bounds.current, bounds.largest, ordinal)
                else
                    null;
                if (raised) |index| {
                    if (drawAtIndex(draws[@intCast(raise_cursor)], index)) |candidate| {
                        const trial = allocator.dupe(Draw, draws) catch unreachable;
                        trial[@intCast(raise_cursor)] = candidate;
                        const run = runLevel(property, level, serializeDraws(trial));
                        if (isFailure(&run.case, run.outcome, origin) and core.shrink_cost_progress(
                            run.case.totalCost(),
                            cost,
                            drawsSimpler(run.case.draws.items, family_draws),
                        )) {
                            if (run.case.totalCost() < cost or
                                drawsCompare(run.case.draws.items, family_draws) < 0) accepted = true;

                            draws = allocator.dupe(Draw, run.subject_draws) catch unreachable;

                            spans = allocator.dupe(ChoiceSpan, run.subject_spans) catch unreachable;

                            family_draws = allocator.dupe(Draw, run.case.draws.items) catch unreachable;

                            cost = run.case.totalCost();

                            best = run.case;

                            schedule_at = null;
                            feedback = feedback_accepted;
                        } else {
                            feedback = feedback_rejected;
                        }
                    } else {
                        // No legal value there; try the next raise without
                        // running.
                        feedback = feedback_rejected;
                    }
                }
            },
            request_verify => {
                const run = runLevel(property, level, serializeDraws(draws));
                if (!isFailure(&run.case, run.outcome, origin)) return error.FlakyReplay;
                run.outcome catch |err| {
                    verified_cause = failureCause(&run.case, err);
                };
                verified_case = run.case;
                best = run.case;
                feedback = feedback_accepted;
            },
            else => {},
        }

        const next_phase = core.shrink_next_phase(
            phase,
            feedback,
            span_cursor,
            duplicate_cursor,
            position,
            pair_cursor,
            reorder_cursor,
            trivial_cursor,
            descendant_cursor,
            character_cursor,
            shorten_cursor,
            paid_cursor,
            raise_cursor,
            shrinks,
            stall,
            max_shrinks,
            max_stall,
            draws.len,
            spans.len,
        );
        const next_span_cursor = core.shrink_next_span_cursor(phase, feedback, span_cursor);
        const next_duplicate_cursor = core.shrink_next_duplicate_cursor(phase, feedback, duplicate_cursor);
        const next_position = core.shrink_next_position(phase, feedback, position);
        const next_pair_cursor = core.shrink_next_pair_cursor(phase, feedback, pair_cursor);
        const next_reorder_cursor = core.shrink_next_reorder_cursor(phase, feedback, reorder_cursor);
        const next_trivial_cursor = core.shrink_next_trivial_cursor(phase, feedback, trivial_cursor);
        const next_descendant_cursor = core.shrink_next_descendant_cursor(phase, feedback, descendant_cursor);
        const next_character_cursor = core.shrink_next_character_cursor(phase, feedback, character_cursor);
        const next_shorten_cursor = core.shrink_next_shorten_cursor(phase, feedback, shorten_cursor);
        const next_paid_cursor = core.shrink_next_paid_cursor(phase, feedback, paid_cursor);
        const next_raise_cursor = core.shrink_next_raise_cursor(phase, feedback, raise_cursor);
        const next_ordinal = core.shrink_next_ordinal(phase, feedback, ordinal);
        const next_shrinks = core.shrink_next_shrinks(phase, feedback, shrinks);
        const next_stall = core.shrink_next_stall(stall, feedback);
        phase = next_phase;
        span_cursor = next_span_cursor;
        duplicate_cursor = next_duplicate_cursor;
        position = next_position;
        pair_cursor = next_pair_cursor;
        reorder_cursor = next_reorder_cursor;
        trivial_cursor = next_trivial_cursor;
        descendant_cursor = next_descendant_cursor;
        character_cursor = next_character_cursor;
        shorten_cursor = next_shorten_cursor;
        paid_cursor = next_paid_cursor;
        raise_cursor = next_raise_cursor;
        ordinal = next_ordinal;
        shrinks = next_shrinks;
        stall = next_stall;
    }

    if (verified_cause == null) @panic("internal error: shrink finished without verifying");
    return .{
        .cause = verified_cause,
        .case = verified_case,
        .best = best,
        .accepted = accepted,
        .shrinks = shrinks,
    };
}

/// Run the whole schedule inside each clone of a family.
///
/// The flat passes treat a clone entry as one atomic choice — they can delete
/// it or move it, never reach the choices inside it — so a failure that depends
/// on a value drawn from a clone would otherwise be reported exactly as
/// generation found it. Each clone gets its own run of the same compiled driver
/// over its own stream, which is upstream's shrink_clone_streams.
fn shrinkCloneStreams(
    property: anytype,
    family: *TestCase,
    origin: []const u8,
    max_shrinks: u64,
    max_stall: u64,
) FlakyReplay!bool {
    var improved = false;
    var paths: std.ArrayList([]const usize) = .empty;
    clonePaths(family.draws.items, &.{}, &paths);
    for (paths.items) |path| {
        const subject = caseAt(family, path) orelse continue;
        if (subject.draws.items.len == 0) continue;
        const stream = serializeDraws(family.draws.items);
        const run = try shrinkStream(
            property,
            .{ .clone = .{ .stream = stream, .path = path } },
            family,
            subject.draws.items,
            subject.spans_list.items,
            origin,
            max_shrinks,
            max_stall,
        );
        if (run.accepted) {
            family.* = run.best;
            improved = true;
        }
    }
    return improved;
}

/// Minimize a failing example: the family's own stream first, then the stream
/// inside each of its clones, to a fixpoint.
///
/// The two alternate because they feed each other — a deletion at the top can
/// expose a clone worth descending into, and a smaller child stream can make a
/// parent candidate legal that was not before. Each accepted candidate is
/// strictly simpler than the one it replaces, so the alternation terminates.
fn shrink(
    property: anytype,
    initial: *TestCase,
    origin: []const u8,
    max_shrinks: u64,
    max_stall: u64,
) FlakyReplay!struct { cause: []const u8, case: TestCase } {
    var family = initial.*;
    while (true) {
        const run = try shrinkStream(
            property,
            .family,
            &family,
            family.draws.items,
            family.spans_list.items,
            origin,
            max_shrinks,
            max_stall,
        );
        const cause = run.cause orelse @panic("internal error: shrink finished without verifying");
        var best = run.best;
        const improved = try shrinkCloneStreams(property, &best, origin, max_shrinks, max_stall);
        // A sweep that improved the stream goes round again even when no clone
        // did, unless it stopped at its shrink cap: a later pass's accept can
        // make an earlier pass's candidate legal, and one sweep never revisits
        // it. A state machine needs this most, because a continue decision
        // misread after a deletion stops the run, so lowering a rule is often
        // what lets a whole step go.
        if (!improved and !core.shrink_sweep_again(run.accepted, run.shrinks, max_shrinks)) {
            return .{ .cause = cause, .case = run.case };
        }
        family = best;
    }
}

/// Run a property, shrink its first failure, and return a portable failure blob.
pub fn check(property: anytype, config: Config) !?Failure {
    failed_coverage = null;
    flaky = null;
    if (config.reproduce) |blob| {
        const raw = core.raw_failure_decode(blob) orelse return error.InvalidReplay;
        var case = TestCase.replaying(raw);
        execute(property, &case) catch |err| {
            if (err == error.AssumptionRejected or err == error.InvalidReplay) return error.InvalidReplay;
            if (err == error.ReplayOverrun) return error.ReplayOverrun;
            return Failure{
                .blob = allocator.dupe(u8, blob) catch unreachable,
                .cause = failureCause(&case, err),
                .examples_run = 1,
                .rejections = 0,
                .notes = case.notes(),
                .puns = case.family.puns,
                .key_misses = case.family.key_misses,
                .cost = case.totalCost(),
            };
        };
        // A blob whose property does not fail is a bad reproduce request, not a
        // discovery. The other four packages report it as an invalid replay.
        return error.InvalidReplay;
    }

    const database = config.database;
    const database_key = config.database_key orelse @typeName(@TypeOf(property));

    // Declared requirements are registered before the first example, in
    // declaration order; duplicate labels merge by the strongest rate.
    var coverage: std.ArrayList(CoverageCounter) = .empty;
    var coverage_index = std.StringHashMap(usize).init(allocator);
    for (config.require) |required| {
        if (!(required.percent >= 0 and required.percent <= 100)) return error.InvalidPercent;
        const permille: u64 = @intFromFloat(required.percent * 10);
        if (coverage_index.get(required.label)) |at| {
            if (permille > coverage.items[at].permille) coverage.items[at].permille = permille;
            continue;
        }
        coverage_index.put(required.label, coverage.items.len) catch unreachable;
        coverage.append(allocator, .{
            .label = required.label,
            .permille = permille,
        }) catch unreachable;
    }

    var rng = SplitMix64{ .state = config.seed };
    var valid: usize = 0;
    var attempts: usize = 0;
    // Database replays are attempts but not generation. The schedule is told
    // generation's own count, so a stale entry cannot take the all-simplest
    // probe's place as the first request.
    var replays: usize = 0;
    var rejections: usize = 0;
    var overruns: usize = 0;
    var generation_us: u64 = 0;
    var pending_mutations = std.ArrayList([]u8).empty;
    // Consecutive executed mutation requests; the schedule caps it at one
    // brood so fresh random generation keeps its share of the run.
    var mutation_streak: u64 = 0;
    var seen_streams = StreamSet.init();
    var targeting = TargetingRun.init(config.examples);

    // Stored failures replay before generation. Replays count as attempts but
    // consume neither the exploration budget nor coverage/health accounting.
    if (database) |db| {
        const fetched = db.fetch(database_key);
        const stored = allocator.dupe([]const u8, fetched) catch unreachable;
        std.mem.sort([]const u8, stored, {}, struct {
            fn lessThan(_: void, left: []const u8, right: []const u8) bool {
                if (left.len != right.len) return left.len < right.len;
                return std.mem.order(u8, left, right) == .lt;
            }
        }.lessThan);
        for (stored) |entry| {
            if (!core.choice_stream_validate(entry)) {
                db.delete(database_key, entry);
                continue;
            }
            attempts += 1;
            replays += 1;
            var case = TestCase.replaying(entry);
            const outcome = execute(property, &case);
            if (outcome) |_| {
                db.delete(database_key, entry);
                continue;
            } else |err| switch (err) {
                error.AssumptionRejected, error.InvalidReplay, error.ReplayOverrun, error.ChoiceOverrun => {
                    db.delete(database_key, entry);
                    continue;
                },
                else => {
                    const cause = failureCause(&case, err);
                    const minimized = shrink(
                        property,
                        &case,
                        cause,
                        config.max_shrinks,
                        config.max_stall,
                    ) catch return flakyFailure(&case, cause, attempts, rejections);
                    const stream = minimized.case.serialized();
                    db.save(database_key, stream);
                    if (!std.mem.eql(u8, stream, entry)) db.delete(database_key, entry);
                    return Failure{
                        .blob = core.raw_failure_encode(stream),
                        .cause = minimized.cause,
                        .examples_run = attempts,
                        .rejections = rejections,
                        .notes = minimized.case.notes(),
                        .puns = minimized.case.family.puns,
                        .key_misses = minimized.case.family.key_misses,
                        .cost = minimized.case.totalCost(),
                    };
                },
            }
        }
    }
    while (core.generation_should_continue(@intCast(valid), @intCast(config.examples))) {
        const request = core.generation_request_kind(@intCast(attempts - replays), @intCast(pending_mutations.items.len), mutation_streak);
        const simplest_probe = request == 1;
        const mutation_probe = request == 2;
        const mutation = if (mutation_probe)
            pending_mutations.orderedRemove(0)
        else
            null;
        const exact_seen = if (mutation) |raw| seen_streams.contains(raw) else false;
        const novelty = core.generation_novelty_action(request, exact_seen);
        if (novelty == 0) continue;
        if (novelty == 2) seen_streams.insert(mutation.?);
        attempts += 1;
        mutation_streak = if (mutation_probe) mutation_streak + 1 else 0;
        var case = if (simplest_probe)
            TestCase.simplestCase()
        else if (mutation) |raw|
            TestCase.probe(raw, rng)
        else
            TestCase.random(rng);
        if (!simplest_probe) _ = rng.next();
        const outcome = execute(property, &case);
        seen_streams.insert(case.serialized());
        generation_us +|= case.generation_us;
        const outcome_code = classify(outcome);
        var probe_overran = false;
        outcome catch |err| {
            probe_overran = err == error.ChoiceOverrun;
        };
        if (simplest_probe and core.health_large_base_example(
            probe_overran,
            outcome_code,
            case.draws.items.len,
            config.suppress_large_base_example,
        )) return error.LargeBaseExample;
        var health_valid = valid;
        if (outcome) |_| {
            health_valid += 1;
        } else |_| {}
        if (outcome_code != 4 and core.health_too_slow(
            generation_us,
            @intCast(health_valid),
            config.suppress_too_slow,
        )) return error.TooSlow;
        outcome catch |err| {
            if (err == error.AssumptionRejected) {
                rejections += 1;
                const rejection_limit = core.generation_rejection_limit(
                    @intCast(config.max_rejections),
                    @intCast(valid),
                );
                if (@as(u64, @intCast(rejections + overruns)) > rejection_limit) return error.TooManyRejections;
                if (core.health_filter_too_much(
                    @intCast(rejections),
                    @intCast(valid),
                    config.suppress_filter_too_much,
                )) {
                    return error.FilterTooMuch;
                }
                continue;
            }
            if (err == error.ChoiceOverrun) {
                overruns += 1;
                const rejection_limit = core.generation_rejection_limit(
                    @intCast(config.max_rejections),
                    @intCast(valid),
                );
                if (@as(u64, @intCast(rejections + overruns)) > rejection_limit) return error.TooManyRejections;
                if (core.health_data_too_large(
                    @intCast(overruns),
                    @intCast(valid),
                    config.suppress_data_too_large,
                )) {
                    return error.DataTooLarge;
                }
                continue;
            }
            if (err == error.InvalidReplay or err == error.ReplayOverrun) return err;
            const cause = failureCause(&case, err);
            const minimized = shrink(
                property,
                &case,
                cause,
                config.max_shrinks,
                config.max_stall,
            ) catch return flakyFailure(&case, cause, attempts, rejections);
            const stream = minimized.case.serialized();
            if (database) |db| db.save(database_key, stream);
            return Failure{
                .blob = core.raw_failure_encode(stream),
                .cause = minimized.cause,
                .examples_run = attempts,
                .rejections = rejections,
                .notes = minimized.case.notes(),
                .puns = minimized.case.family.puns,
                .key_misses = minimized.case.family.key_misses,
                .cost = minimized.case.totalCost(),
            };
        };
        valid += 1;
        // Commit this valid example's buffered observations: an unseen label
        // fixes its place in observed-label order, the rate merges by max, and
        // observed counts the labels whose condition held this example.
        var held_rare = false;
        for (case.family.coverage_order.items) |label| {
            const found = coverage_index.getOrPut(label) catch unreachable;
            if (!found.found_existing) {
                found.value_ptr.* = coverage.items.len;
                coverage.append(allocator, .{ .label = label }) catch unreachable;
            }
            const counter = &coverage.items[found.value_ptr.*];
            const observation = case.family.coverage.?.get(label).?;
            if (observation.permille > counter.permille) counter.permille = observation.permille;
            if (observation.held) {
                counter.observed += 1;
                if (core.generation_label_rare(counter.observed, @intCast(valid), counter.permille)) {
                    held_rare = true;
                }
            }
        }
        // An example that reached a label the run has barely covered is on the
        // frontier, so its mutation proposals jump the queue ahead of ones bred
        // from the common path, and may be bred at all when the base rule
        // declines.
        switch (core.generation_mutation_admission(
            request,
            @intCast(valid),
            @intCast(pending_mutations.items.len),
            held_rare,
        )) {
            1 => pending_mutations.appendSlice(
                allocator,
                spanMutationCandidates(case.draws.items, case.spans_list.items, &rng),
            ) catch unreachable,
            2 => pending_mutations.insertSlice(
                allocator,
                0,
                spanMutationCandidates(case.draws.items, case.spans_list.items, &rng),
            ) catch unreachable,
            else => {},
        }
        // Targeting: fold this example's observations in, and fire the hill
        // climber when the schedule says so. A failing trial is a
        // counterexample like any other.
        targeting.record(&case);
        if (targeting.best.count() > 0 and
            core.targeting_should_fire(@intCast(valid), targeting.next_at))
        {
            targeting.next_at = core.targeting_next_threshold(targeting.next_at, targeting.step);
            targeting.valid = valid;
            targeting.attempts = attempts;
            optimiseTargets(property, &rng, &seen_streams, &targeting, config.examples);
            valid = targeting.valid;
            attempts = targeting.attempts;
            if (targeting.found) |*found| {
                const cause = failureCause(found, targeting.found_err);
                const minimized = shrink(
                    property,
                    found,
                    cause,
                    config.max_shrinks,
                    config.max_stall,
                ) catch return flakyFailure(found, cause, attempts, rejections);
                const stream = minimized.case.serialized();
                if (database) |db| db.save(database_key, stream);
                return Failure{
                    .blob = core.raw_failure_encode(stream),
                    .cause = minimized.cause,
                    .examples_run = attempts,
                    .rejections = rejections,
                    .notes = minimized.case.notes(),
                    .puns = minimized.case.family.puns,
                    .key_misses = minimized.case.family.key_misses,
                    .cost = minimized.case.totalCost(),
                };
            }
        }
    }
    // The coverage verdict runs only on a run that completed fully valid: a
    // counterexample or an aborted run reports that instead, and a verdict
    // about a truncated run would be noise. The accept rule is compiled
    // (ir/lifecycle.zir @coverage_failed) so every shell agrees on it.
    for (coverage.items) |counter| {
        if (core.coverage_failed(counter.observed, @intCast(valid), counter.permille)) {
            failed_coverage = .{
                .label = counter.label,
                .observed = counter.observed,
                .valid = @intCast(valid),
                .min_percent = @as(f64, @floatFromInt(counter.permille)) / 10,
            };
            return error.FailedCoverage;
        }
    }
    return null;
}

test "failure shrinks and replays across the portable fixture" {
    const property = struct {
        fn run(case: *TestCase) !void {
            const value = try case.integer(-100, 100, 0);
            if (value >= 5) return error.TooLarge;
        }
    }.run;

    const failure = (try check(property, .{ .examples = 200, .seed = 1 })).?;
    var seen: i64 = 0;
    const replay_property = struct {
        var output: *i64 = undefined;
        fn run(case: *TestCase) !void {
            output.* = try case.integer(-100, 100, 0);
            return error.AlwaysFails;
        }
    };
    replay_property.output = &seen;
    _ = (try check(replay_property.run, .{ .reproduce = failure.blob })).?;
    try std.testing.expectEqual(@as(i64, 5), seen);

    seen = 0;
    _ = (try check(replay_property.run, .{ .reproduce = "AAEAAAAACgEAAAAF" })).?;
    try std.testing.expectEqual(@as(i64, 5), seen);
}

test "targeting steers generation toward high scores" {
    // With 200 examples the compiled schedule fires the hill climber at 100
    // valid examples; unguided random search hits the failing band in roughly
    // one example per ten thousand.
    const property = struct {
        fn run(case: *TestCase) !void {
            const value = try case.integer(0, 100_000, 0);
            case.target(@floatFromInt(value));
            if (value >= 99_990) return error.ReachedTheTop;
        }
    }.run;
    const failure = (try check(property, .{ .examples = 200, .seed = 5 })).?;

    var seen: i64 = 0;
    const replay_property = struct {
        var output: *i64 = undefined;
        fn run(case: *TestCase) !void {
            output.* = try case.integer(0, 100_000, 0);
            return error.Replay;
        }
    };
    replay_property.output = &seen;
    _ = (try check(replay_property.run, .{ .reproduce = failure.blob })).?;
    try std.testing.expectEqual(@as(i64, 99_990), seen);
}

test "targeting climbs each label separately" {
    // The failing band is reachable only through the *second* label in sorted
    // order, so finding it requires the per-label bookkeeping: "high" is
    // climbed first, discovers nothing, and the climb moves on to "low".
    const property = struct {
        fn run(case: *TestCase) !void {
            const low = try case.integer(0, 20_000, 0);
            const high = try case.integer(0, 20_000, 0);
            case.targetLabelled(@floatFromInt(low), "low");
            case.targetLabelled(@floatFromInt(high), "high");
            if (low >= 19_990) return error.LowClimbed;
        }
    }.run;
    const failure = (try check(property, .{ .examples = 600, .seed = 7 })).?;

    var seen: [2]i64 = .{ 0, 0 };
    const replay_property = struct {
        var output: *[2]i64 = undefined;
        fn run(case: *TestCase) !void {
            output.*[0] = try case.integer(0, 20_000, 0);
            output.*[1] = try case.integer(0, 20_000, 0);
            return error.Replay;
        }
    };
    replay_property.output = &seen;
    _ = (try check(replay_property.run, .{ .reproduce = failure.blob })).?;
    try std.testing.expectEqual(@as(i64, 19_990), seen[0]);
    try std.testing.expectEqual(@as(i64, 0), seen[1]);
}

test "boolean and bytes failures replay" {
    const property = struct {
        fn run(case: *TestCase) !void {
            const enabled = try case.boolean();
            const payload = try case.bytes(0, 4);
            if (enabled and payload.len != 0) return error.EnabledPayload;
        }
    }.run;
    const failure = (try check(property, .{ .examples = 200, .seed = 7 })).?;
    _ = (try check(property, .{ .reproduce = failure.blob })).?;
}

test "assumptions, punning, forced positions, overruns, and spans" {
    var attempts: usize = 0;
    const assumption_property = struct {
        var count: *usize = undefined;
        fn run(case: *TestCase) !void {
            count.* += 1;
            try case.assume(count.* % 2 == 0);
        }
    };
    assumption_property.count = &attempts;
    try std.testing.expect((try check(assumption_property.run, .{ .examples = 3, .seed = 11 })) == null);
    try std.testing.expectEqual(@as(usize, 6), attempts);

    var seen = false;
    const pun_property = struct {
        var output: *bool = undefined;
        fn run(case: *TestCase) !void {
            output.* = try case.boolean();
            return error.AlwaysFails;
        }
    };
    pun_property.output = &seen;
    _ = (try check(pun_property.run, .{ .reproduce = "AAEAAAAACgEAAAAF" })).?;
    try std.testing.expect(seen);

    const overrun = struct {
        fn run(case: *TestCase) !void {
            _ = try case.integer(0, 10, 0);
            _ = try case.integer(0, 10, 0);
            return error.UnreachableFailure;
        }
    }.run;
    try std.testing.expectError(error.ReplayOverrun, check(overrun, .{ .reproduce = "AAEAAAAACgEAAAAF" }));

    var captured: []const ChoiceSpan = &.{};
    const span_property = struct {
        var output: *[]const ChoiceSpan = undefined;
        fn run(case: *TestCase) !void {
            _ = case.startSpan("outer");
            _ = try case.integer(0, 10, 0);
            _ = case.startSpan("inner");
            _ = try case.boolean();
            case.stopSpan(true);
            _ = try case.bytes(0, 2);
            case.stopSpan(false);
            output.* = case.spans();
        }
    };
    span_property.output = &captured;
    try std.testing.expect((try check(span_property.run, .{ .examples = 1, .seed = 17 })) == null);
    try std.testing.expectEqual(@as(usize, 2), captured.len);
    try std.testing.expectEqual(@as(usize, 3), captured[0].end);
    try std.testing.expect(captured[1].discarded);
}

test "valid examples expand the rejection budget" {
    var attempts: usize = 0;
    const property = struct {
        var count: *usize = undefined;
        fn run(case: *TestCase) !void {
            count.* += 1;
            try case.assume(count.* % 101 == 0);
        }
    };
    property.count = &attempts;
    try std.testing.expect((try check(property.run, .{
        .examples = 15,
        .seed = 11,
        .suppress_filter_too_much = true,
    })) == null);
    try std.testing.expectEqual(@as(usize, 1515), attempts);
}

test "simplest probe uses choice simplest values" {
    var attempts: usize = 0;
    const property = struct {
        var count: *usize = undefined;
        fn run(case: *TestCase) !void {
            count.* += 1;
            try std.testing.expectEqual(@as(i64, 7), try case.integer(5, 10, 7));
            try std.testing.expect(!(try case.boolean()));
            try std.testing.expectEqualSlices(u8, &.{ 0, 0 }, try case.bytes(2, 4));
            try std.testing.expectEqual(@as(f64, 1.0), try case.float(1.0, 2.0, false, false, 0.0));
        }
    };
    property.count = &attempts;
    try std.testing.expect((try check(property.run, .{ .examples = 1 })) == null);
    try std.testing.expectEqual(@as(usize, 1), attempts);
}

test "large-base-example health check and suppression" {
    const property = struct {
        fn run(case: *TestCase) !void {
            for (0..4097) |_| _ = try case.boolean();
        }
    }.run;
    try std.testing.expectError(error.LargeBaseExample, check(property, .{ .examples = 1 }));
    try std.testing.expect((try check(property, .{
        .examples = 1,
        .suppress_large_base_example = true,
    })) == null);
}

test "too-slow health check and suppression" {
    const property = struct {
        fn run(case: *TestCase) !void {
            case.generation_us = 1_000_001;
        }
    }.run;
    try std.testing.expectError(error.TooSlow, check(property, .{ .examples = 1 }));
    try std.testing.expect((try check(property, .{
        .examples = 1,
        .suppress_too_slow = true,
    })) == null);
}

test "filter-too-much health check and suppression" {
    const property = struct {
        fn run(case: *TestCase) !void {
            try case.assume(false);
        }
    }.run;
    try std.testing.expectError(error.FilterTooMuch, check(property, .{ .examples = 1 }));
    try std.testing.expectError(error.TooManyRejections, check(property, .{
        .examples = 1,
        .max_rejections = 50,
        .suppress_filter_too_much = true,
    }));
}

test "data-too-large health check and suppression" {
    var attempts: usize = 0;
    const property = struct {
        var count: *usize = undefined;
        fn run(case: *TestCase) !void {
            count.* += 1;
            if (count.* <= 20) {
                for (0..8193) |_| _ = try case.boolean();
            }
        }
    };
    property.count = &attempts;
    try std.testing.expectError(error.DataTooLarge, check(property.run, .{
        .examples = 1,
        .suppress_large_base_example = true,
    }));

    attempts = 0;
    try std.testing.expect((try check(property.run, .{
        .examples = 1,
        .suppress_data_too_large = true,
        .suppress_large_base_example = true,
    })) == null);
    try std.testing.expectEqual(@as(usize, 21), attempts);
}

test "integer shrink candidates enumerate simpler indexes" {
    const item = Draw{ .integer = .{
        .encoded = core.serialize_integer_choice(signedBytes(3)),
        .value = 3,
        .min = 0,
        .max = std.math.maxInt(i64),
        .target = 0,
    } };
    const candidates = candidateDraws(item);
    try std.testing.expect(candidates.len >= 3);
    try std.testing.expectEqual(@as(i64, 0), candidates[0].integer.value);
    try std.testing.expectEqual(@as(i64, 1), candidates[1].integer.value);
    try std.testing.expectEqual(@as(i64, 2), candidates[2].integer.value);
}

test "sort key is choice-count-first shortlex" {
    const false_draw = Draw{ .boolean = .{
        .encoded = core.serialize_boolean_choice(false),
        .value = false,
    } };
    const true_draw = Draw{ .boolean = .{
        .encoded = core.serialize_boolean_choice(true),
        .value = true,
    } };
    const shorter = [_]Draw{true_draw};
    const longer = [_]Draw{ false_draw, false_draw };
    try std.testing.expect(drawsSimpler(&shorter, &longer));

    const lower_first = [_]Draw{ false_draw, true_draw };
    const higher_first = [_]Draw{ true_draw, false_draw };
    try std.testing.expect(drawsSimpler(&lower_first, &higher_first));
    try std.testing.expect(!drawsSimpler(&higher_first, &lower_first));

    const forced_false = Draw{ .boolean = .{
        .encoded = core.serialize_boolean_choice(false),
        .value = false,
        .forced = true,
    } };
    const forced_true = Draw{ .boolean = .{
        .encoded = core.serialize_boolean_choice(true),
        .value = true,
        .forced = true,
    } };
    try std.testing.expect(drawsSimpler(&.{forced_false}, &.{forced_true}));

    const bytes8: [8]u8 = @splat(0);
    const bytes9: [9]u8 = @splat(0);
    const draw8 = Draw{ .bytes = .{
        .encoded = core.serialize_bytes_choice(&bytes8),
        .value = &bytes8,
        .min = 0,
        .max = 16,
    } };
    const draw9 = Draw{ .bytes = .{
        .encoded = core.serialize_bytes_choice(&bytes9),
        .value = &bytes9,
        .min = 0,
        .max = 16,
    } };
    try std.testing.expect(drawsSimpler(&.{draw8}, &.{draw9}));
    try std.testing.expect(!drawsSimpler(&.{draw9}, &.{draw8}));
}

var bug_found: []const u8 = "";

test "shrinking stays on the bug that was found" {
    const property = struct {
        fn run(case: *TestCase) !void {
            const value = try case.integer(0, 100, 0);
            if (value > 50) {
                if (bug_found.len == 0) bug_found = "A";
                return error.BugA;
            }
            if (value == 7) {
                if (bug_found.len == 0) bug_found = "B";
                return error.BugB;
            }
        }
    }.run;
    var seed: u64 = 1;
    while (seed <= 3) : (seed += 1) {
        bug_found = "";
        const failure = try check(property, .{ .examples = 50, .seed = seed });
        if (failure) |f| {
            if (std.mem.eql(u8, bug_found, "A")) {
                try std.testing.expectEqualStrings("BugA", f.cause);
            }
        }
    }
}

// The shell-level counterpart to the golden vector gate. Every shell runs the
// same table from conformance/shell/shell_cases.tsv, so a behavior that drifts in one
// language fails there rather than in review.
const shell_cases_tsv = @embedFile("shell_cases");
/// Generated by tools/tracegen from the real Hegel engine, embedded separately
/// rather than merged into the hand-written table so that it stays regenerable.
const trace_vectors_tsv = @embedFile("trace_vectors");
const database_cases_tsv = @embedFile("database_cases");

// TRACE state. Zig has no closures, so a scripted property reads globals the
// same way every other case here does.
var trace_ops: [16][]const u8 = undefined;
var trace_ops_len: usize = 0;
var trace_encoded: [512]u8 = undefined;
var trace_encoded_len: usize = 0;

fn traceAlphabetFromHex(text: []const u8) !?[]const u8 {
    if (text.len == 0) return null;
    const characters = try allocator.alloc(u8, text.len / 2);
    _ = try std.fmt.hexToBytes(characters, text);
    return try alphabet(characters);
}

const TraceIntegerElement = struct {
    lo: i64,
    hi: i64,

    fn draw(self: TraceIntegerElement, case: *TestCase) !i64 {
        return case.integer(self.lo, self.hi, 0);
    }
};

fn traceCollectInteger(case: *TestCase, min_size: usize, max_size: ?usize, lo: i64, hi: i64) ![]const i64 {
    return case.collect(i64, TraceIntegerElement{ .lo = lo, .hi = hi }, min_size, max_size, "list.element");
}

fn traceCollectUniqueInteger(case: *TestCase, min_size: usize, max_size: ?usize, lo: i64, hi: i64) ![]const i64 {
    return case.collectUnique(i64, i64, TraceIntegerElement{ .lo = lo, .hi = hi }, caseIdentity, min_size, max_size, "set.element");
}

fn traceProperty(case: *TestCase) !void {
    for (trace_ops[0..trace_ops_len]) |op| {
        if (trace_encoded_len != 0) {
            trace_encoded[trace_encoded_len] = ',';
            trace_encoded_len += 1;
        }
        const written = try drawops.traceDraw(
            case,
            op,
            trace_encoded[trace_encoded_len..],
            traceAlphabetFromHex,
            traceCollectInteger,
            traceCollectUniqueInteger,
        );
        trace_encoded_len += written.len;
    }
}

fn traceFailingProperty(case: *TestCase) !void {
    try traceProperty(case);
    return error.Replayed;
}

/// Replays a blob the real Hegel engine emitted. See tools/tracegen: the golden
/// vectors bind each IR function to the engine, this binds a whole shell to it.
fn caseTrace(fields: [][]const u8) !?[]const u8 {
    const envelope = fields[0];
    const blob = fields[1];
    trace_ops_len = 0;
    var ops = std.mem.splitScalar(u8, fields[2], ',');
    while (ops.next()) |op| : (trace_ops_len += 1) trace_ops[trace_ops_len] = op;
    const expected = fields[3];
    trace_encoded_len = 0;
    _ = envelope;
    const failure = try check(traceFailingProperty, .{ .reproduce = blob });
    try std.testing.expect(failure != null);
    try std.testing.expectEqualStrings(expected, trace_encoded[0..trace_encoded_len]);
    return null;
}

var case_found: []const u8 = "";

fn caseNumber(value: []const u8) i64 {
    return std.fmt.parseInt(i64, value, 10) catch unreachable;
}

test "shared shell cases" {
    var ran: usize = 0;
    var pinned: usize = 0;
    for ([_][]const u8{ shell_cases_tsv, trace_vectors_tsv }) |table| {
        var lines = std.mem.splitScalar(u8, table, '\n');
        while (lines.next()) |line| {
            if (line.len == 0 or line[0] == '#') continue;
            var fields = std.mem.splitScalar(u8, line, '\t');
            const kind = fields.next() orelse continue;
            var rest: [10][]const u8 = undefined;
            var count: usize = 0;
            while (fields.next()) |field| : (count += 1) rest[count] = field;
            // An optional trailing blob=<base64> pins the reproduce blob the case
            // must emit. It is stripped before dispatch so the handlers keep their
            // positional fields, and compared against what the handler returns.
            // See conformance/shell/shell_cases.tsv.
            var expected_blob: ?[]const u8 = null;
            if (count != 0 and std.mem.startsWith(u8, rest[count - 1], "blob=")) {
                expected_blob = rest[count - 1]["blob=".len..];
                count -= 1;
                pinned += 1;
            }
            const declared = try runDeclaredShellCase(kind, rest[0..count]);
            var emitted = declared.emitted;
            if (declared.handled) {
                // The generated descriptor and generic interpreter own this case.
            } else if (std.mem.eql(u8, kind, "TRACE")) {
                emitted = try caseTrace(rest[0..count]);
            } else {
                return error.UnknownShellCase;
            }
            if (expected_blob) |expected| {
                if (emitted) |actual| {
                    std.testing.expectEqualStrings(expected, actual) catch |err| {
                        std.debug.print("{s} emitted the wrong blob\n", .{kind});
                        return err;
                    };
                } else {
                    std.debug.print("{s} emitted no blob; the row pins one\n", .{kind});
                    return error.NoBlobEmitted;
                }
            }
            ran += 1;
        }
    }
    try std.testing.expect(ran > 0);
    try std.testing.expect(pinned > 0);
}

var database_case_lo: i64 = 0;
var database_case_hi: i64 = 0;
var database_case_threshold: i64 = 0;

fn databaseThresholdProperty(case: *TestCase) !void {
    if (try case.integer(database_case_lo, database_case_hi, 0) >= database_case_threshold) {
        return error.DatabaseThreshold;
    }
}

fn databaseHarmlessProperty(case: *TestCase) !void {
    _ = try case.integer(database_case_lo, database_case_hi, 0);
}

// The first few values a recording property drew, in execution order.
var database_case_drawn: [4]i64 = undefined;
var database_case_drawn_len: usize = 0;

fn databaseRecordingProperty(case: *TestCase) !void {
    const value = try case.integer(database_case_lo, database_case_hi, 0);
    if (database_case_drawn_len < database_case_drawn.len) {
        database_case_drawn[database_case_drawn_len] = value;
        database_case_drawn_len += 1;
    }
}

fn databaseConfigure(run: databasecases.Threshold) void {
    database_case_lo = run.lo;
    database_case_hi = run.hi;
    database_case_threshold = run.threshold;
}

fn databaseHex(text: []const u8) ![]const u8 {
    if (text.len % 2 != 0) return error.OddHex;
    const bytes = try allocator.alloc(u8, text.len / 2);
    _ = try std.fmt.hexToBytes(bytes, text);
    return bytes;
}

fn runDeclaredDatabaseCase(declared: databasecases.Case) !?[]const u8 {
    switch (declared) {
        .digest => |item| {
            try std.testing.expectEqualStrings(item.key_digest, databaseDigest(item.name));
            try std.testing.expectEqualStrings(item.value_digest, databaseDigest(try databaseHex(item.stream_hex)));
            return null;
        },
        .reuse => |run| {
            databaseConfigure(run);
            var memory = InMemoryDatabase.init();
            const database = memory.database();
            const first = (try check(databaseThresholdProperty, .{
                .examples = run.examples,
                .seed = run.seed,
                .database = database,
                .database_key = "case",
            })) orelse return error.DatabaseCaseDidNotFail;
            const stream = core.raw_failure_decode(first.blob) orelse return error.InvalidReplay;
            const stored = memory.fetch("case");
            try std.testing.expectEqual(@as(usize, 1), stored.len);
            try std.testing.expectEqualSlices(u8, stream, stored[0]);
            const second = (try check(databaseThresholdProperty, .{
                .examples = run.examples,
                .seed = run.seed + 1000,
                .database = database,
                .database_key = "case",
            })) orelse return error.StoredCaseDidNotFail;
            try std.testing.expectEqualStrings(first.blob, second.blob);
            try std.testing.expectEqual(@as(usize, 1), second.examples_run);
            return first.blob;
        },
        .stale => |run| {
            databaseConfigure(run);
            var memory = InMemoryDatabase.init();
            const database = memory.database();
            _ = (try check(databaseThresholdProperty, .{
                .examples = run.examples,
                .seed = run.seed,
                .database = database,
                .database_key = "case",
            })) orelse return error.DatabaseCaseDidNotFail;
            try std.testing.expectEqual(@as(usize, 1), memory.fetch("case").len);
            try std.testing.expect((try check(databaseHarmlessProperty, .{
                .examples = run.examples,
                .seed = run.seed,
                .database = database,
                .database_key = "case",
            })) == null);
            try std.testing.expectEqual(@as(usize, 0), memory.fetch("case").len);
            return null;
        },
        .stale_probe => |item| {
            databaseConfigure(item.run);
            var memory = InMemoryDatabase.init();
            const database = memory.database();
            _ = (try check(databaseThresholdProperty, .{
                .examples = item.run.examples,
                .seed = item.run.seed,
                .database = database,
                .database_key = "case",
            })) orelse return error.DatabaseCaseDidNotFail;
            database_case_drawn_len = 0;
            try std.testing.expect((try check(databaseRecordingProperty, .{
                .examples = item.run.examples,
                .seed = item.run.seed,
                .database = database,
                .database_key = "case",
            })) == null);
            // A stale entry must be followed by the all-simplest probe.
            try std.testing.expect(database_case_drawn_len >= 2);
            try std.testing.expectEqualSlices(i64, &.{ item.run.threshold, item.simplest }, database_case_drawn[0..2]);
            return null;
        },
        .corrupt => |item| {
            database_case_lo = item.lo;
            database_case_hi = item.hi;
            var memory = InMemoryDatabase.init();
            memory.save("case", try databaseHex(item.entry_hex));
            try std.testing.expect((try check(databaseHarmlessProperty, .{
                .examples = 10,
                .seed = 1,
                .database = memory.database(),
                .database_key = "case",
            })) == null);
            try std.testing.expectEqual(@as(usize, 0), memory.fetch("case").len);
            return null;
        },
        .layout => |item| {
            databaseConfigure(item.run);
            var temporary = std.testing.tmpDir(.{ .iterate = true });
            defer temporary.cleanup();
            var directory_database = DirectoryDatabase.initDir(temporary.dir);
            const failure = (try check(databaseThresholdProperty, .{
                .examples = item.run.examples,
                .seed = item.run.seed,
                .database = directory_database.database(),
                .database_key = item.name,
            })) orelse return error.DatabaseCaseDidNotFail;
            const stream = core.raw_failure_decode(failure.blob) orelse return error.InvalidReplay;
            const key_digest = databaseDigest(item.name);
            var key_dir = try temporary.dir.openDir(DirectoryDatabase.io(), key_digest, .{ .iterate = true });
            defer key_dir.close(DirectoryDatabase.io());
            const name = try key_dir.readFileAlloc(DirectoryDatabase.io(), ".name", allocator, .unlimited);
            try std.testing.expectEqualStrings(item.name, name);
            var entry_name: ?[]const u8 = null;
            var entries = key_dir.iterate();
            while (try entries.next(DirectoryDatabase.io())) |entry| {
                if (DirectoryDatabase.isEntry(entry.name)) {
                    try std.testing.expect(entry_name == null);
                    entry_name = try allocator.dupe(u8, entry.name);
                }
            }
            try std.testing.expectEqualStrings(databaseDigest(stream), entry_name orelse return error.MissingDatabaseEntry);
            const payload = try key_dir.readFileAlloc(DirectoryDatabase.io(), entry_name.?, allocator, .unlimited);
            try std.testing.expectEqualSlices(u8, stream, payload);
            return failure.blob;
        },
    }
}

test "shared database cases" {
    var ran: usize = 0;
    var pinned: usize = 0;
    var lines = std.mem.splitScalar(u8, database_cases_tsv, '\n');
    while (lines.next()) |line| {
        if (line.len == 0 or line[0] == '#') continue;
        var fields = std.mem.splitScalar(u8, line, '\t');
        const kind = fields.next() orelse continue;
        var rest: [7][]const u8 = undefined;
        var count: usize = 0;
        while (fields.next()) |field| : (count += 1) rest[count] = field;
        var expected_blob: ?[]const u8 = null;
        if (count != 0 and std.mem.startsWith(u8, rest[count - 1], "blob=")) {
            expected_blob = rest[count - 1]["blob=".len..];
            count -= 1;
            pinned += 1;
        }
        const declared = (try databasecases.resolve(kind, rest[0..count])) orelse return error.UnknownDatabaseCase;
        const emitted = try runDeclaredDatabaseCase(declared);
        if (expected_blob) |expected| {
            try std.testing.expectEqualStrings(expected, emitted orelse return error.NoBlobEmitted);
        }
        ran += 1;
    }
    try std.testing.expect(ran > 0);
    try std.testing.expect(pinned > 0);
}

test "database defaults derive a key and manual reproduction does not touch storage" {
    try std.testing.expect((Config{}).database == null);
    database_case_lo = -100;
    database_case_hi = 100;
    database_case_threshold = 5;

    var derived = InMemoryDatabase.init();
    const first = (try check(databaseThresholdProperty, .{
        .examples = 100,
        .seed = 1,
        .database = derived.database(),
    })) orelse return error.DatabaseCaseDidNotFail;
    const derived_key = @typeName(@TypeOf(databaseThresholdProperty));
    try std.testing.expectEqual(@as(usize, 1), derived.fetch(derived_key).len);

    var manual = InMemoryDatabase.init();
    manual.save("case", "corrupt");
    const replayed = (try check(databaseThresholdProperty, .{
        .reproduce = first.blob,
        .database = manual.database(),
        .database_key = "case",
    })) orelse return error.DatabaseCaseDidNotFail;
    try std.testing.expectEqualStrings(first.blob, replayed.blob);
    try std.testing.expectEqual(@as(usize, 1), manual.fetch("case").len);
    try std.testing.expectEqualStrings("corrupt", manual.fetch("case")[0]);
}

var case_lo: i64 = 0;
var case_hi: i64 = 0;
var case_threshold: i64 = 0;
var case_seen: [4]i64 = undefined;
var case_seen_len: usize = 0;

const DeclaredShellCaseResult = struct { emitted: ?[]const u8, handled: bool };
var declared_shell_case: shellcases.Case = undefined;
var declared_shell_case_attempts: usize = 0;
var declared_shell_case_cost: u64 = 0;
var declared_shell_case_pairs: [4][2]i64 = undefined;
var declared_shell_case_pairs_len: usize = 0;
var declared_shell_case_insert = false;
var declared_shell_case_countdown: usize = 0;
var declared_shell_case_reads: [8]i64 = undefined;
var declared_shell_case_reads_len: usize = 0;
var declared_shell_case_coins: [8]i64 = undefined;
var declared_shell_case_coins_len: usize = 0;
var declared_shell_case_quad: [4]i64 = undefined;
var declared_shell_case_chain: [64]i64 = undefined;
var declared_shell_case_chain_len: usize = 0;

const DeclaredListElement = struct {
    fn draw(_: DeclaredListElement, test_case: *TestCase) !i64 {
        return test_case.integer(declared_shell_case.lo, declared_shell_case.hi, 0);
    }
};

fn declaredShellCaseChainNode(test_case: *TestCase) !void {
    _ = test_case.startSpan("node");
    defer test_case.stopSpan(false);
    const workload = declared_shell_case.predicate.descendant_chain;
    const value = try test_case.integer(0, workload[0], 0);
    if (declared_shell_case_chain_len < declared_shell_case_chain.len) {
        declared_shell_case_chain[declared_shell_case_chain_len] = value;
        declared_shell_case_chain_len += 1;
    }
    if (try test_case.boolean()) try declaredShellCaseChainNode(test_case);
}

// The keyed draw at the bottom of `depth` nested clones: the deepest stream a
// shell will open, where a key must still cost no nesting level.
fn declaredShellCaseDeepKeyed(test_case: *TestCase) !i64 {
    const workload = declared_shell_case.predicate.keyed_deep_clone;
    var current = test_case;
    var level: i64 = 0;
    while (level < workload[0]) : (level += 1) current = try current.cloneStream();
    return current.integerKeyed(0, workload[1], 0, keyFor(&.{.{ .text = "deep" }}));
}

// A gate whose small values cost an extra draw: the coin, then a pick only
// below the threshold, then a value. What was drawn is kept in the chain buffer
// so a replay can report it.
fn declaredShellCaseGate(test_case: *TestCase) !void {
    const gate = declared_shell_case.predicate.raise_gate;
    declared_shell_case_chain_len = 0;
    const coin = try test_case.integer(0, gate[0], 0);
    declared_shell_case_chain[declared_shell_case_chain_len] = coin;
    declared_shell_case_chain_len += 1;
    if (coin < gate[1]) {
        declared_shell_case_chain[declared_shell_case_chain_len] = try test_case.integer(0, 2, 0);
        declared_shell_case_chain_len += 1;
    }
    declared_shell_case_chain[declared_shell_case_chain_len] = try test_case.integer(-1000, 1000, 0);
    declared_shell_case_chain_len += 1;
}

fn declaredShellCaseProperty(test_case: *TestCase) !void {
    const fails = switch (declared_shell_case.draw_kind) {
        .integer => blk: {
            const value = try test_case.integer(declared_shell_case.lo, declared_shell_case.hi, 0);
            switch (declared_shell_case.predicate) {
                .two_bug => |bugs| {
                    if (value > bugs[0]) {
                        if (case_found.len == 0) case_found = "A";
                        return error.DeclaredBugA;
                    }
                    if (value == bugs[1]) {
                        if (case_found.len == 0) case_found = "B";
                        return error.DeclaredBugB;
                    }
                    return;
                },
                else => {},
            }
            if (declared_shell_case.outcome == .fails) {
                case_seen[case_seen_len] = value;
                case_seen_len += 1;
            }
            break :blk switch (declared_shell_case.predicate) {
                .gte => |threshold| value >= threshold,
                .lte => |threshold| value <= threshold,
                .sparse_multiple => |lattice| value >= lattice[0] and (@mod(value, lattice[0]) == 0 or value >= lattice[1]),
                .always_lt => |threshold| always: {
                    try test_case.always("stays small", value < threshold);
                    break :always false;
                },
                .sometimes_gt => |threshold| sometimes: {
                    test_case.sometimes("above threshold", value > threshold);
                    break :sometimes false;
                },
                .cover_first => |percent| cover: {
                    declared_shell_case_attempts += 1;
                    const held = declared_shell_case_attempts == 1;
                    try test_case.cover("first example", held, @floatFromInt(percent));
                    try test_case.cover("first example", held, @floatFromInt(percent));
                    break :cover false;
                },
                .fails_first => first: {
                    declared_shell_case_attempts += 1;
                    break :first declared_shell_case_attempts == 1;
                },
                else => unreachable,
            };
        },
        .string => blk: {
            const characters = if (declared_shell_case.alphabet) |text| try alphabet(text) else null;
            const value = try test_case.string(declared_shell_case.min_size, declared_shell_case.max_size.?, characters);
            break :blk switch (declared_shell_case.predicate) {
                .codepoints_gte => |threshold| try std.unicode.utf8CountCodepoints(value) >= @as(usize, @intCast(threshold)),
                .repeated_not => |simplest| repeated: {
                    var simplest_iterator = (try std.unicode.Utf8View.init(simplest)).iterator();
                    const simplest_character = simplest_iterator.nextCodepoint().?;
                    var repeats: [16]u21 = undefined;
                    const found = try repeatedCodepoints(value, &repeats);
                    for (repeats[0..found]) |repeat| {
                        if (repeat != simplest_character) break :repeated true;
                    }
                    break :repeated false;
                },
                else => unreachable,
            };
        },
        .collect_integer => blk: {
            const values = try test_case.collect(i64, DeclaredListElement{}, declared_shell_case.min_size, declared_shell_case.max_size, "list.element");
            break :blk switch (declared_shell_case.predicate) {
                .any_gte => |threshold| for (values) |value| {
                    if (value >= threshold) break true;
                } else false,
                .any_lte => |threshold| for (values) |value| {
                    if (value <= threshold) break true;
                } else false,
                .all_gte => |threshold| for (values) |value| {
                    if (value < threshold) break false;
                } else true,
                .all_lte => |threshold| for (values) |value| {
                    if (value > threshold) break false;
                } else true,
                .set_equal => |target| exact: {
                    var has_first = false;
                    var has_second = false;
                    for (values) |value| {
                        if (value != target[0] and value != target[1]) break :exact false;
                        if (value == target[0]) has_first = true;
                        if (value == target[1]) has_second = true;
                    }
                    break :exact has_first and has_second;
                },
                .cover_repeats => |coverage| cover: {
                    var held = false;
                    for (values) |value| {
                        if (value < coverage.floor) continue;
                        var seen: i64 = 0;
                        for (values) |other| {
                            if (other == value) seen += 1;
                        }
                        if (seen >= coverage.copies) held = true;
                    }
                    try test_case.cover("repeat", held, @floatFromInt(coverage.percent));
                    break :cover false;
                },
                .cover_exclusive => |percent| cover: {
                    if (values.len > 0) {
                        const bucket: usize = @intCast(@mod(values[0], 10));
                        try test_case.cover(exclusive_bucket_labels[bucket], true, 0);
                    }
                    try test_case.cover("empty", values.len == 0, @floatFromInt(percent));
                    break :cover false;
                },
                else => unreachable,
            };
        },
        .collect_unique_integer => blk: {
            const values = try test_case.collectUnique(
                i64,
                i64,
                DeclaredListElement{},
                caseIdentity,
                declared_shell_case.min_size,
                declared_shell_case.max_size,
                "set.element",
            );
            break :blk switch (declared_shell_case.predicate) {
                .any_gte => |threshold| for (values) |value| {
                    if (value >= threshold) break true;
                } else false,
                .any_lte => |threshold| for (values) |value| {
                    if (value <= threshold) break true;
                } else false,
                .all_gte => |threshold| for (values) |value| {
                    if (value < threshold) break false;
                } else true,
                .all_lte => |threshold| for (values) |value| {
                    if (value > threshold) break false;
                } else true,
                .set_equal => |target| exact: {
                    var has_first = false;
                    var has_second = false;
                    for (values) |value| {
                        if (value != target[0] and value != target[1]) break :exact false;
                        if (value == target[0]) has_first = true;
                        if (value == target[1]) has_second = true;
                    }
                    break :exact has_first and has_second;
                },
                else => unreachable,
            };
        },
        .clone_triplet => blk: {
            _ = try test_case.integer(declared_shell_case.lo, declared_shell_case.hi, 0);
            const child = try test_case.cloneStream();
            const value = try child.integer(declared_shell_case.lo, declared_shell_case.hi, 0);
            _ = try test_case.integer(declared_shell_case.lo, declared_shell_case.hi, 0);
            break :blk switch (declared_shell_case.predicate) {
                .gte => |threshold| value >= threshold,
                .lte => |threshold| value <= threshold,
                else => unreachable,
            };
        },
        .declared_length => blk: {
            // A list, then a length the property declares for it over the
            // list's own size range.
            const values = try test_case.collect(i64, DeclaredListElement{}, declared_shell_case.min_size, declared_shell_case.max_size, "list.element");
            const length = try test_case.integer(0, @intCast(declared_shell_case.max_size.?), 0);
            if (length != @as(i64, @intCast(values.len))) break :blk false;
            for (values) |value| {
                if (value >= declared_shell_case.predicate.declared_length) break :blk true;
            }
            break :blk false;
        },
        .duplicate_pair => blk: {
            const first = try test_case.integer(declared_shell_case.lo, declared_shell_case.hi, 0);
            const second = try test_case.integer(declared_shell_case.lo, declared_shell_case.hi, 0);
            break :blk switch (declared_shell_case.predicate) {
                .equal_nonzero => first == second and first != 0,
                .difference => |gap| first - second == gap,
                else => unreachable,
            };
        },
        .cost_workload => blk: {
            const workload = declared_shell_case.predicate.cost_first;
            declared_shell_case_cost = 0;
            var total: i64 = 0;
            var site: i64 = 0;
            while (site < workload[0]) : (site += 1) {
                if (try test_case.booleanKeyed(test_case.nextKey(&.{ .{ .text = "inject" }, .{ .int = site } }))) {
                    declared_shell_case_cost += 1;
                    test_case.cost("fault", 1);
                    continue;
                }
                total += try test_case.integerKeyed(
                    0,
                    workload[1],
                    0,
                    test_case.nextKey(&.{ .{ .text = "payload" }, .{ .int = site } }),
                );
            }
            break :blk declared_shell_case_cost > 0 and total >= workload[2];
        },
        .key_digest => unreachable,
        .keyed_replay => blk: {
            const workload = declared_shell_case.predicate.keyed_both_gte;
            const first_key = keyFor(&.{ .{ .text = "read" }, .{ .int = 1 } });
            const second_key = keyFor(&.{ .{ .text = "read" }, .{ .int = 2 } });
            const first = try test_case.integerKeyed(workload[0], workload[1], 0, first_key);
            const second = try test_case.integerKeyed(workload[0], workload[1], 0, second_key);
            break :blk first >= workload[2] and second >= workload[2];
        },
        .key_sequence => unreachable,
        .trivial_span => blk: {
            const hi = declared_shell_case.predicate.trivial_span;
            const guard = try test_case.integer(0, hi, 0);
            _ = test_case.startSpan("pair");
            const first = try test_case.integer(0, hi, 0);
            _ = try test_case.boolean();
            const second = try test_case.integer(0, hi, 0);
            test_case.stopSpan(false);
            break :blk guard >= 1 and (first == 0) == (second == 0);
        },
        .raise_gate => blk: {
            try declaredShellCaseGate(test_case);
            break :blk true;
        },
        .descendant_chain => blk: {
            const workload = declared_shell_case.predicate.descendant_chain;
            declared_shell_case_chain_len = 0;
            try declaredShellCaseChainNode(test_case);
            break :blk declared_shell_case_chain[declared_shell_case_chain_len - 1] >= workload[1];
        },
        .keyed_deep_clone => (try declaredShellCaseDeepKeyed(test_case)) >= declared_shell_case.hi,
        .probe_extend => unreachable,
    };
    if (fails) return error.DeclaredFailure;
}

fn declaredShellCaseKeyedReplay(test_case: *TestCase) !void {
    const workload = declared_shell_case.predicate.keyed_both_gte;
    const first_key = keyFor(&.{ .{ .text = "read" }, .{ .int = 1 } });
    const second_key = keyFor(&.{ .{ .text = "read" }, .{ .int = 2 } });
    const fresh_key = keyFor(&.{ .{ .text = "retry" }, .{ .int = 1 } });
    const second = try test_case.integerKeyed(workload[0], workload[1], 0, second_key);
    _ = try test_case.integerKeyed(workload[0], workload[1], 0, fresh_key);
    const first = try test_case.integerKeyed(workload[0], workload[1], 0, first_key);
    declared_shell_case_pairs[declared_shell_case_pairs_len] = .{ first, second };
    declared_shell_case_pairs_len += 1;
    return error.Replayed;
}

fn declaredShellCaseKeySequence(test_case: *TestCase) !void {
    const workload = declared_shell_case.predicate.key_sequence;
    declared_shell_case_reads_len = 0;
    declared_shell_case_coins_len = 0;
    for (0..6) |step| {
        if (step % 2 == 0) {
            declared_shell_case_reads[declared_shell_case_reads_len] = try test_case.integerKeyed(
                workload[0],
                workload[1],
                0,
                test_case.nextKey(&.{.{ .text = "read" }}),
            );
            declared_shell_case_reads_len += 1;
            if (declared_shell_case_insert and step == 0) {
                declared_shell_case_reads[declared_shell_case_reads_len] = try test_case.integerKeyed(
                    workload[0],
                    workload[1],
                    0,
                    test_case.nextKey(&.{.{ .text = "read" }}),
                );
                declared_shell_case_reads_len += 1;
            }
        } else {
            declared_shell_case_coins[declared_shell_case_coins_len] = try test_case.integerKeyed(
                0,
                1,
                0,
                test_case.nextKey(&.{.{ .text = "coin" }}),
            );
            declared_shell_case_coins_len += 1;
        }
    }
    declared_shell_case_countdown += 1;
    if (declared_shell_case_countdown >= 4) return error.Boom;
}

fn declaredShellCaseReplay(test_case: *TestCase) !void {
    switch (declared_shell_case.draw_kind) {
        .integer => {
            case_seen[case_seen_len] = try test_case.integer(declared_shell_case.lo, declared_shell_case.hi, 0);
            case_seen_len += 1;
        },
        .string => {
            const characters = if (declared_shell_case.alphabet) |text| try alphabet(text) else null;
            case_texts[case_texts_len] = try test_case.string(declared_shell_case.min_size, declared_shell_case.max_size.?, characters);
            case_texts_len += 1;
        },
        .collect_integer => {
            case_lists[case_lists_len] = try test_case.collect(i64, DeclaredListElement{}, declared_shell_case.min_size, declared_shell_case.max_size, "list.element");
            case_lists_len += 1;
        },
        .collect_unique_integer => {
            case_lists[case_lists_len] = try test_case.collectUnique(
                i64,
                i64,
                DeclaredListElement{},
                caseIdentity,
                declared_shell_case.min_size,
                declared_shell_case.max_size,
                "set.element",
            );
            case_lists_len += 1;
        },
        .clone_triplet => {
            case_seen[0] = try test_case.integer(declared_shell_case.lo, declared_shell_case.hi, 0);
            const child = try test_case.cloneStream();
            case_seen[1] = try child.integer(declared_shell_case.lo, declared_shell_case.hi, 0);
            case_seen[2] = try test_case.integer(declared_shell_case.lo, declared_shell_case.hi, 0);
            case_seen_len = 3;
        },
        .declared_length => {
            case_lists[case_lists_len] = try test_case.collect(i64, DeclaredListElement{}, declared_shell_case.min_size, declared_shell_case.max_size, "list.element");
            case_lists_len += 1;
            case_seen[0] = try test_case.integer(0, @intCast(declared_shell_case.max_size.?), 0);
            case_seen_len = 1;
        },
        .duplicate_pair => {
            case_seen[0] = try test_case.integer(declared_shell_case.lo, declared_shell_case.hi, 0);
            case_seen[1] = try test_case.integer(declared_shell_case.lo, declared_shell_case.hi, 0);
            case_seen_len = 2;
        },
        .cost_workload => unreachable,
        .key_digest => unreachable,
        .keyed_replay => unreachable,
        .key_sequence => unreachable,
        .trivial_span => {
            const hi = declared_shell_case.predicate.trivial_span;
            const guard = try test_case.integer(0, hi, 0);
            _ = test_case.startSpan("pair");
            const first = try test_case.integer(0, hi, 0);
            const flag = try test_case.boolean();
            const second = try test_case.integer(0, hi, 0);
            test_case.stopSpan(false);
            declared_shell_case_quad = .{ guard, first, if (flag) 1 else 0, second };
        },
        .descendant_chain => {
            declared_shell_case_chain_len = 0;
            try declaredShellCaseChainNode(test_case);
        },
        .keyed_deep_clone => {
            case_seen[0] = try declaredShellCaseDeepKeyed(test_case);
            case_seen_len = 1;
        },
        .raise_gate => try declaredShellCaseGate(test_case),
        .probe_extend => unreachable,
    }
    return error.Replayed;
}

fn runDeclaredShellCase(kind: []const u8, fields: [][]const u8) !DeclaredShellCaseResult {
    declared_shell_case = (try shellcases.resolve(kind, fields)) orelse
        return .{ .emitted = null, .handled = false };
    declared_shell_case_attempts = 0;
    if (declared_shell_case.draw_kind == .probe_extend) {
        try declaredShellCaseProbeExtend();
        return .{ .emitted = null, .handled = true };
    }
    if (declared_shell_case.outcome == .same_bug) {
        case_found = "";
        const failure = try check(declaredShellCaseProperty, .{
            .examples = declared_shell_case.examples,
            .max_rejections = declared_shell_case.max_rejections,
            .seed = declared_shell_case.seed,
        });
        if (failure) |f| {
            const reported: []const u8 = if (std.mem.eql(u8, f.cause, "DeclaredBugA")) "A" else "B";
            try std.testing.expectEqualStrings(case_found, reported);
        }
        return .{ .emitted = null, .handled = true };
    }
    if (declared_shell_case.outcome == .cost_order) {
        const failure = try check(declaredShellCaseProperty, .{
            .examples = declared_shell_case.examples,
            .max_rejections = declared_shell_case.max_rejections,
            .seed = declared_shell_case.seed,
        });
        try std.testing.expect(failure != null);
        try std.testing.expectEqual(@as(u64, @intCast(declared_shell_case.expected[0])), failure.?.cost);
        return .{ .emitted = null, .handled = true };
    }
    if (declared_shell_case.outcome == .digest) {
        var digest: [16]u8 = undefined;
        const name = declared_shell_case.predicate.key_digest;
        const printed = try std.fmt.bufPrint(&digest, "{x:0>16}", .{keyFor(&.{.{ .text = name }})});
        try std.testing.expectEqualStrings(declared_shell_case.expected_text, printed);
        return .{ .emitted = null, .handled = true };
    }
    if (declared_shell_case.outcome == .keyed_replay) {
        const failure = try check(declaredShellCaseProperty, .{
            .examples = declared_shell_case.examples,
            .max_rejections = declared_shell_case.max_rejections,
            .seed = declared_shell_case.seed,
        });
        try std.testing.expect(failure != null);
        declared_shell_case_pairs_len = 0;
        const replayed = try check(declaredShellCaseKeyedReplay, .{ .reproduce = failure.?.blob });
        try std.testing.expect(replayed != null);
        try std.testing.expectEqual(@as(usize, 1), declared_shell_case_pairs_len);
        try std.testing.expectEqual(declared_shell_case.expected[0], declared_shell_case_pairs[0][0]);
        try std.testing.expectEqual(declared_shell_case.expected[0], declared_shell_case_pairs[0][1]);
        try std.testing.expectEqual(@as(usize, @intCast(declared_shell_case.expected[1])), replayed.?.key_misses);
        return .{ .emitted = failure.?.blob, .handled = true };
    }
    if (declared_shell_case.outcome == .sequence_stable) {
        declared_shell_case_insert = false;
        declared_shell_case_countdown = 0;
        const failure = try check(declaredShellCaseKeySequence, .{
            .examples = declared_shell_case.examples,
            .max_rejections = declared_shell_case.max_rejections,
            .max_shrinks = declared_shell_case.max_shrinks,
            .seed = declared_shell_case.seed,
        });
        if (failure) |f| {
            var reads: [8]i64 = undefined;
            const reads_len = declared_shell_case_reads_len;
            @memcpy(reads[0..reads_len], declared_shell_case_reads[0..reads_len]);
            var coins: [8]i64 = undefined;
            const coins_len = declared_shell_case_coins_len;
            @memcpy(coins[0..coins_len], declared_shell_case_coins[0..coins_len]);

            declared_shell_case_insert = true;
            declared_shell_case_countdown = 99;
            const replayed = try check(declaredShellCaseKeySequence, .{ .reproduce = f.blob });
            try std.testing.expect(replayed != null);
            try std.testing.expectEqual(reads_len + 1, declared_shell_case_reads_len);
            try std.testing.expectEqualSlices(i64, reads[0..reads_len], declared_shell_case_reads[0..reads_len]);
            try std.testing.expectEqual(declared_shell_case.lo, declared_shell_case_reads[reads_len]);
            try std.testing.expectEqualSlices(i64, coins[0..coins_len], declared_shell_case_coins[0..coins_len]);
            try std.testing.expectEqual(@as(usize, 0), replayed.?.puns);
            try std.testing.expectEqual(@as(usize, @intCast(declared_shell_case.expected[0])), replayed.?.key_misses);
        }
        return .{ .emitted = null, .handled = true };
    }
    if (declared_shell_case.outcome == .coverage or declared_shell_case.outcome == .coverage_at_least) {
        if (declared_shell_case.require_label) |label| {
            const required = [_]Coverage{.{ .label = label }};
            try std.testing.expectError(error.FailedCoverage, check(declaredShellCaseProperty, .{
                .examples = declared_shell_case.examples,
                .max_rejections = declared_shell_case.max_rejections,
                .seed = declared_shell_case.seed,
                .require = &required,
            }));
        } else {
            try std.testing.expectError(error.FailedCoverage, check(declaredShellCaseProperty, .{
                .examples = declared_shell_case.examples,
                .max_rejections = declared_shell_case.max_rejections,
                .seed = declared_shell_case.seed,
            }));
        }
        const missed = failed_coverage.?;
        const expected_label = declared_shell_case.require_label orelse switch (declared_shell_case.predicate) {
            .cover_first => "first example",
            .cover_repeats => "repeat",
            .cover_exclusive => "empty",
            else => "above threshold",
        };
        try std.testing.expectEqualStrings(expected_label, missed.label);
        if (declared_shell_case.outcome == .coverage_at_least) {
            try std.testing.expect(missed.observed >= @as(u64, @intCast(declared_shell_case.expected[0])));
        } else {
            try std.testing.expectEqual(@as(u64, @intCast(declared_shell_case.expected[0])), missed.observed);
        }
        try std.testing.expectEqual(@as(u64, @intCast(declared_shell_case.expected[1])), missed.valid);
        return .{ .emitted = null, .handled = true };
    }
    if (declared_shell_case.outcome == .flaky) {
        try std.testing.expectError(error.Flaky, check(declaredShellCaseProperty, .{
            .examples = declared_shell_case.examples,
            .max_rejections = declared_shell_case.max_rejections,
            .seed = declared_shell_case.seed,
        }));
        const reported = flaky.?;
        try std.testing.expectEqualStrings("DeclaredFailure", reported.cause);
        const message = try std.fmt.allocPrint(allocator, "{f}", .{reported});
        try std.testing.expect(std.mem.indexOf(u8, message, "flaky") != null);
        try std.testing.expect(std.mem.indexOf(u8, message, "DeclaredFailure") != null);
        return .{ .emitted = reported.blob, .handled = true };
    }
    if (declared_shell_case.reproduce) |blob| {
        case_seen_len = 0;
        const outcome = check(declaredShellCaseProperty, .{ .reproduce = blob });
        if (declared_shell_case.outcome == .passes) {
            try std.testing.expectError(error.InvalidReplay, outcome);
        } else if (declared_shell_case.outcome == .puns) {
            const failure = try outcome;
            try std.testing.expect(failure != null);
            try std.testing.expectEqual(@as(usize, @intCast(declared_shell_case.expected[0])), failure.?.puns);
        } else {
            const failure = try outcome;
            try std.testing.expect(failure != null);
            try std.testing.expectEqual(@as(usize, 1), case_seen_len);
            try std.testing.expectEqual(declared_shell_case.expected[0], case_seen[0]);
        }
        return .{ .emitted = null, .handled = true };
    }
    if (declared_shell_case.outcome == .rejects) {
        const outcome = check(declaredShellCaseProperty, .{
            .examples = declared_shell_case.examples,
            .max_rejections = declared_shell_case.max_rejections,
            .seed = declared_shell_case.seed,
        });
        if (outcome) |failure| {
            try std.testing.expect(failure == null);
        } else |err| {
            try std.testing.expect(err == error.TooManyRejections or err == error.FilterTooMuch);
        }
        return .{ .emitted = null, .handled = true };
    }
    if (declared_shell_case.outcome == .passes) {
        const failure = try check(declaredShellCaseProperty, .{
            .examples = declared_shell_case.examples,
            .max_rejections = declared_shell_case.max_rejections,
            .seed = declared_shell_case.seed,
        });
        try std.testing.expect(failure == null);
        return .{ .emitted = null, .handled = true };
    }
    const failure = try check(declaredShellCaseProperty, .{
        .examples = declared_shell_case.examples,
        .max_rejections = declared_shell_case.max_rejections,
        .seed = declared_shell_case.seed,
    });
    if (failure) |f| {
        case_seen_len = 0;
        case_lists_len = 0;
        case_texts_len = 0;
        const replayed = try check(declaredShellCaseReplay, .{ .reproduce = f.blob });
        try std.testing.expect(replayed != null);
        switch (declared_shell_case.draw_kind) {
            .integer => {
                try std.testing.expectEqual(@as(usize, 1), case_seen_len);
                try std.testing.expectEqual(declared_shell_case.expected[0], case_seen[0]);
            },
            .string => {
                try std.testing.expectEqual(@as(usize, 1), case_texts_len);
                try std.testing.expectEqualStrings(declared_shell_case.expected_text, case_texts[0]);
            },
            .collect_integer, .collect_unique_integer => {
                try std.testing.expectEqual(@as(usize, 1), case_lists_len);
                try std.testing.expectEqualSlices(i64, declared_shell_case.expected[0..declared_shell_case.expected_count], case_lists[0]);
            },
            .clone_triplet => {
                try std.testing.expectEqual(@as(usize, 3), case_seen_len);
                try std.testing.expectEqualSlices(i64, declared_shell_case.expected[0..3], case_seen[0..3]);
            },
            .duplicate_pair => {
                try std.testing.expectEqual(@as(usize, 2), case_seen_len);
                try std.testing.expectEqualSlices(i64, declared_shell_case.expected[0..2], case_seen[0..2]);
            },
            .declared_length => {
                try std.testing.expectEqual(@as(usize, 1), case_lists_len);
                try std.testing.expectEqualSlices(i64, declared_shell_case.expected[0..1], case_lists[0]);
                try std.testing.expectEqual(@as(usize, 1), case_seen_len);
                try std.testing.expectEqual(declared_shell_case.expected[1], case_seen[0]);
            },
            .cost_workload => unreachable,
            .key_digest => unreachable,
            .keyed_replay => unreachable,
            .key_sequence => unreachable,
            .trivial_span => {
                try std.testing.expectEqualSlices(i64, declared_shell_case.expected[0..4], &declared_shell_case_quad);
            },
            .descendant_chain, .raise_gate => {
                try std.testing.expectEqualSlices(i64, declared_shell_case.expected[0..declared_shell_case.expected_count], declared_shell_case_chain[0..declared_shell_case_chain_len]);
            },
            .keyed_deep_clone => {
                try std.testing.expect(core.raw_failure_decode(f.blob) != null);
                try std.testing.expectEqual(@as(usize, 1), case_seen_len);
                try std.testing.expectEqual(declared_shell_case.expected[0], case_seen[0]);
            },
            .probe_extend => unreachable,
        }
        return .{ .emitted = f.blob, .handled = true };
    }
    return .{ .emitted = null, .handled = true };
}

fn declaredShellCaseProbeExtend() !void {
    var recorded: [16]i64 = undefined;
    var recorded_len: usize = 0;
    if (!std.mem.eql(u8, declared_shell_case.expected_text, "-")) {
        var parts = std.mem.splitScalar(u8, declared_shell_case.expected_text, ',');
        while (parts.next()) |part| {
            recorded[recorded_len] = caseNumber(part);
            recorded_len += 1;
        }
    }
    const stream = core.raw_failure_decode(declared_shell_case.alphabet.?) orelse return error.InvalidReplay;
    var bare = TestCase.replaying(stream);
    var overran = false;
    for (0..declared_shell_case.min_size) |_| {
        if (bare.integer(declared_shell_case.lo, declared_shell_case.hi, 0)) |_| {
            continue;
        } else |err| {
            try std.testing.expect(err == error.ReplayOverrun);
            overran = true;
            break;
        }
    }
    try std.testing.expect(overran);

    var probe = TestCase.probe(stream, SplitMix64{ .state = declared_shell_case.seed });
    for (0..declared_shell_case.min_size) |i| {
        const value = try probe.integer(declared_shell_case.lo, declared_shell_case.hi, 0);
        if (i < recorded_len) try std.testing.expectEqual(recorded[i], value);
    }
    try std.testing.expectEqual(declared_shell_case.min_size, probe.draws.items.len);
}

var case_lists: [4][]const i64 = undefined;
var case_lists_len: usize = 0;

// Handwritten collection cases share this adapter and replay storage with the
// generated collection-case interpreter above.
const ListElement = struct {
    fn draw(_: ListElement, case: *TestCase) !i64 {
        return case.integer(case_lo, case_hi, 0);
    }
};

var case_reported: []const u8 = "";
var case_reported_len: usize = 0;

// The characters appearing more than once, as a sorted list of codepoints.
fn repeatedCodepoints(value: []const u8, out: *[16]u21) !usize {
    var found: usize = 0;
    var outer = (try std.unicode.Utf8View.init(value)).iterator();
    while (outer.nextCodepoint()) |character| {
        var count: usize = 0;
        var inner = (try std.unicode.Utf8View.init(value)).iterator();
        while (inner.nextCodepoint()) |other| {
            if (other == character) count += 1;
        }
        if (count < 2) continue;
        var already = false;
        for (out[0..found]) |seen| {
            if (seen == character) already = true;
        }
        if (already or found == out.len) continue;
        out[found] = character;
        found += 1;
    }
    std.mem.sort(u21, out[0..found], {}, std.sort.asc(u21));
    return found;
}

fn caseIdentity(value: i64) i64 {
    return value;
}

var case_texts: [4][]const u8 = undefined;
var case_texts_len: usize = 0;

// ---- coverage assertions ----

var coverage_attempts: usize = 0;

/// The mutually exclusive label family a cover_exclusive shell case declares,
/// one label per residue of the list's first element modulo ten.
const exclusive_bucket_labels = [_][]const u8{
    "bucket 0",
    "bucket 1",
    "bucket 2",
    "bucket 3",
    "bucket 4",
    "bucket 5",
    "bucket 6",
    "bucket 7",
    "bucket 8",
    "bucket 9",
};
var coverage_replayed: i64 = 0;

test "sometimes that never holds fails the run" {
    const property = struct {
        fn run(case: *TestCase) !void {
            const value = try case.integer(0, 10, 0);
            case.sometimes("value above range", value > 1000);
        }
    }.run;
    try std.testing.expectError(error.FailedCoverage, check(property, .{
        .examples = 20,
        .seed = 5,
    }));
    const missed = failed_coverage.?;
    try std.testing.expectEqualStrings("value above range", missed.label);
    try std.testing.expectEqual(@as(u64, 0), missed.observed);
    try std.testing.expectEqual(@as(u64, 20), missed.valid);
    try std.testing.expectEqual(@as(f64, 0), missed.min_percent);
    const message = std.fmt.allocPrint(allocator, "{f}", .{missed}) catch unreachable;
    try std.testing.expectEqualStrings(
        "coverage: \"value above range\" never held in 20 valid examples",
        message,
    );
}

test "sometimes that held once passes" {
    coverage_attempts = 0;
    // Deterministic whatever the RNG draws: only the first example satisfies
    // the condition, and once is enough.
    const property = struct {
        fn run(case: *TestCase) !void {
            coverage_attempts += 1;
            case.sometimes("first example", coverage_attempts == 1);
        }
    }.run;
    try std.testing.expect((try check(property, .{ .examples = 20, .seed = 5 })) == null);
}

test "declared label that never executes fails the run" {
    const property = struct {
        fn run(_: *TestCase) !void {}
    }.run;
    try std.testing.expectError(error.FailedCoverage, check(property, .{
        .examples = 10,
        .require = &.{.{ .label = "unreached branch" }},
    }));
    const missed = failed_coverage.?;
    try std.testing.expectEqualStrings("unreached branch", missed.label);
    try std.testing.expectEqual(@as(u64, 0), missed.observed);
    try std.testing.expectEqual(@as(u64, 10), missed.valid);
}

test "declared label observed at a call site passes" {
    const property = struct {
        fn run(case: *TestCase) !void {
            case.sometimes("reached", true);
        }
    }.run;
    try std.testing.expect((try check(property, .{
        .examples = 10,
        .require = &.{.{ .label = "reached" }},
    })) == null);
}

test "declared labels are checked before observed ones" {
    const property = struct {
        fn run(case: *TestCase) !void {
            case.sometimes("observed but missed", false);
        }
    }.run;
    try std.testing.expectError(error.FailedCoverage, check(property, .{
        .examples = 5,
        .require = &.{.{ .label = "declared and missed" }},
    }));
    try std.testing.expectEqualStrings("declared and missed", failed_coverage.?.label);
}

test "cover counts once per example and enforces the rate" {
    coverage_attempts = 0;
    const property = struct {
        fn run(case: *TestCase) !void {
            coverage_attempts += 1;
            // Two hits at the same call-site label in one example count once.
            try case.cover("first example", coverage_attempts == 1, 100);
            try case.cover("first example", coverage_attempts == 1, 100);
        }
    }.run;
    try std.testing.expectError(error.FailedCoverage, check(property, .{
        .examples = 4,
        .seed = 5,
    }));
    const missed = failed_coverage.?;
    try std.testing.expectEqual(@as(u64, 1), missed.observed);
    try std.testing.expectEqual(@as(u64, 4), missed.valid);
    try std.testing.expectEqual(@as(f64, 100), missed.min_percent);
    const message = std.fmt.allocPrint(allocator, "{f}", .{missed}) catch unreachable;
    try std.testing.expectEqualStrings(
        "coverage: \"first example\" held in 1 of 4 valid examples, below the required 100%",
        message,
    );
}

test "rejected examples discard coverage observations" {
    coverage_attempts = 0;
    const property = struct {
        fn run(case: *TestCase) !void {
            coverage_attempts += 1;
            // The condition holds only on attempts an assumption then rejects,
            // so a shell that commits observations from rejected examples
            // passes.
            case.sometimes("rejected attempts only", coverage_attempts % 2 == 1);
            try case.assume(coverage_attempts % 2 == 0);
        }
    }.run;
    try std.testing.expectError(error.FailedCoverage, check(property, .{
        .examples = 10,
        .seed = 5,
    }));
    try std.testing.expectEqual(@as(u64, 0), failed_coverage.?.observed);
}

test "coverage is not checked when a run finds a counterexample" {
    const property = struct {
        fn run(case: *TestCase) !void {
            case.sometimes("never held", false);
            return error.RealBug;
        }
    }.run;
    const failure = try check(property, .{ .examples = 10, .seed = 5 });
    try std.testing.expect(failure != null);
    try std.testing.expectEqualStrings("RealBug", failure.?.cause);
}

test "reproduce skips coverage verdicts" {
    const property = struct {
        fn run(case: *TestCase) !void {
            _ = try case.integer(0, 10, 0);
            return error.AlwaysFails;
        }
    }.run;
    const failure = (try check(property, .{ .examples = 5, .seed = 5 })).?;
    const replayed = try check(property, .{
        .reproduce = failure.blob,
        .require = &.{.{ .label = "impossible during replay" }},
    });
    try std.testing.expect(replayed != null);
}

test "required coverage percent is validated" {
    const property = struct {
        fn run(_: *TestCase) !void {}
    }.run;
    try std.testing.expectError(error.InvalidPercent, check(property, .{
        .examples = 1,
        .require = &.{.{ .label = "rate", .percent = 101 }},
    }));
}

test "always failure shrinks to the simplest violation" {
    const property = struct {
        fn run(case: *TestCase) !void {
            const value = try case.integer(0, 100, 0);
            try case.always("value stays small", value < 5);
        }
    }.run;
    const failure = (try check(property, .{ .examples = 100, .seed = 3 })).?;
    try std.testing.expectEqualStrings("always: \"value stays small\" did not hold", failure.cause);
    coverage_replayed = -1;
    const replay = struct {
        fn run(case: *TestCase) !void {
            const value = try case.integer(0, 100, 0);
            coverage_replayed = value;
            try case.always("value stays small", value < 5);
        }
    }.run;
    _ = (try check(replay, .{ .reproduce = failure.blob })).?;
    try std.testing.expectEqual(@as(i64, 5), coverage_replayed);
}

test "two always sites are distinct bugs" {
    // Two assertions with disjoint failing ranges. The shrinker must stay on
    // whichever bug generation found: if both call sites collapsed into one
    // origin, a search that found the 90..100 bug would accept 40..60
    // candidates as progress and report the wrong assertion's boundary.
    const property = struct {
        fn run(case: *TestCase) !void {
            const value = try case.integer(0, 100, 0);
            try case.always("mid stays out", !(40 <= value and value <= 60));
            try case.always("large stays out", value < 90);
        }
    }.run;
    const failure = (try check(property, .{ .examples = 100, .seed = 3 })).?;
    coverage_replayed = -1;
    const replay = struct {
        fn run(case: *TestCase) !void {
            const value = try case.integer(0, 100, 0);
            coverage_replayed = value;
            try case.always("mid stays out", !(40 <= value and value <= 60));
            try case.always("large stays out", value < 90);
        }
    }.run;
    _ = (try check(replay, .{ .reproduce = failure.blob })).?;
    const expected: i64 = if (std.mem.indexOf(u8, failure.cause, "mid stays out") != null) 40 else 90;
    try std.testing.expectEqual(expected, coverage_replayed);
}

test "always that holds passes and covers its label" {
    const property = struct {
        fn run(case: *TestCase) !void {
            try case.always("invariant", true);
        }
    }.run;
    try std.testing.expect((try check(property, .{
        .examples = 10,
        .require = &.{.{ .label = "invariant" }},
    })) == null);
}

test "required always site that never runs fails the run" {
    const property = struct {
        fn run(case: *TestCase) !void {
            const value = try case.integer(0, 10, 0);
            if (value > 1000) try case.always("guarded invariant", true);
        }
    }.run;
    try std.testing.expectError(error.FailedCoverage, check(property, .{
        .examples = 20,
        .seed = 5,
        .require = &.{.{ .label = "guarded invariant" }},
    }));
    try std.testing.expectEqualStrings("guarded invariant", failed_coverage.?.label);
}

test "unreachable fails with the simplest reaching input" {
    const property = struct {
        fn run(case: *TestCase) !void {
            const value = try case.integer(0, 100, 0);
            if (value > 5) try case.@"unreachable"("dead branch");
        }
    }.run;
    const failure = (try check(property, .{ .examples = 100, .seed = 3 })).?;
    try std.testing.expectEqualStrings("unreachable: \"dead branch\" was reached", failure.cause);
    coverage_replayed = -1;
    const replay = struct {
        fn run(case: *TestCase) !void {
            const value = try case.integer(0, 100, 0);
            coverage_replayed = value;
            if (value > 5) try case.@"unreachable"("dead branch");
        }
    }.run;
    _ = (try check(replay, .{ .reproduce = failure.blob })).?;
    try std.testing.expectEqual(@as(i64, 6), coverage_replayed);
}

test "unreachable that is never reached passes" {
    const property = struct {
        fn run(case: *TestCase) !void {
            const value = try case.integer(0, 10, 0);
            if (value > 1000) try case.@"unreachable"("dead branch");
        }
    }.run;
    try std.testing.expect((try check(property, .{ .examples = 20, .seed = 5 })) == null);
}

test "float shrinks and replays portably" {
    const float_one = "AAEAAAACAAAAAAAA8D8=";
    const property = struct {
        fn run(case: *TestCase) !void {
            const value = try case.float(0, 10, false, false, 0);
            if (value >= 1) return error.FloatTooLarge;
        }
    }.run;
    const failure = (try check(property, .{ .examples = 300, .seed = 1 })).?;
    try std.testing.expectEqualStrings(float_one, failure.blob);
    const replayed = (try check(property, .{ .reproduce = failure.blob })).?;
    try std.testing.expectEqualStrings("FloatTooLarge", replayed.cause);
}

// ---------- float category mixture ----------

var float_drawn: [8000]f64 = undefined;
var float_drawn_len: usize = 0;

/// Runs a passing property drawing `per_case` floats from the spec in each of
/// `examples` cases, and returns every value drawn.
fn collectFloats(
    comptime min: f64,
    comptime max: f64,
    comptime allow_nan: bool,
    comptime allow_infinity: bool,
    comptime per_case: usize,
    examples: usize,
) ![]const f64 {
    const property = struct {
        fn run(case: *TestCase) !void {
            for (0..per_case) |_| {
                const value = try case.float(min, max, allow_nan, allow_infinity, 0);
                if (float_drawn_len < float_drawn.len) {
                    float_drawn[float_drawn_len] = value;
                    float_drawn_len += 1;
                }
            }
        }
    }.run;
    float_drawn_len = 0;
    try std.testing.expect((try check(property, .{ .examples = examples, .seed = 1 })) == null);
    return float_drawn[0..float_drawn_len];
}

// Raw bit patterns essentially never land in a narrow range, so the old draw
// fell back to the bounds: floats(1000, 1001) produced only the two endpoints.
// The default draw now interpolates across the range half the time.
test "bounded floats reach the interior" {
    const narrow = try collectFloats(1000, 1001, false, false, 1, 300);
    var distinct = std.AutoHashMap(u64, void).init(std.testing.allocator);
    defer distinct.deinit();
    for (narrow) |value| {
        try std.testing.expect(value >= 1000 and value <= 1001);
        try distinct.put(@bitCast(value), {});
    }
    try std.testing.expect(distinct.count() > 100);

    const unit = try collectFloats(0, 1, false, false, 10, 600);
    var interior: usize = 0;
    for (unit) |value| {
        if (value >= 0.25 and value <= 0.75) interior += 1;
    }
    const share = @as(f64, @floatFromInt(interior)) / @as(f64, @floatFromInt(unit.len));
    try std.testing.expect(share >= 0.20);
}

test "unbounded floats still reach special values" {
    const inf = std.math.inf(f64);
    const drawn = try collectFloats(-inf, inf, true, true, 4, 500);
    var nan = false;
    var seen: [4]bool = @splat(false);
    const specials = [_]f64{ inf, -inf, 0.0, -0.0 };
    for (drawn) |value| {
        nan = nan or std.math.isNan(value);
        for (specials, 0..) |special, at| {
            if (@as(u64, @bitCast(value)) == @as(u64, @bitCast(special))) seen[at] = true;
        }
    }
    try std.testing.expect(nan);
    for (seen) |hit| try std.testing.expect(hit);

    const finite = try collectFloats(-inf, inf, false, false, 4, 500);
    var zero = false;
    for (finite) |value| {
        try std.testing.expect(std.math.isFinite(value));
        zero = zero or value == 0;
    }
    try std.testing.expect(zero);
}

// ---------- cloned streams ----------

var clone_seen: [3]i64 = .{ -1, -1, -1 };

fn cloneProperty(case: *TestCase) !void {
    const outer = try case.integer(0, 100, 0);
    const child = try case.cloneStream();
    const inner = try child.integer(0, 100, 0);
    const tail = try case.integer(0, 100, 0);
    clone_seen = .{ outer, inner, tail };
    if (inner >= 40) return error.InnerTooBig;
}

test "a cloned stream is framed inside the parent's blob and replays" {
    const failure = (try check(cloneProperty, .{ .examples = 200, .seed = 7 })).?;
    const raw = core.raw_failure_decode(failure.blob).?;
    try std.testing.expect(core.choice_stream_validate(raw));
    // Three top-level entries: the outer draw, the clone, the trailing draw.
    try std.testing.expectEqual(@as(u64, 3), core.choice_stream_count(raw));
    const offset = core.choice_offset_at(raw, 1).?;
    try std.testing.expectEqual(@as(u8, 5), raw[@intCast(offset)]);
    const inner = core.clone_inner_stream(raw, offset).?;
    try std.testing.expectEqual(@as(u64, 1), core.choice_stream_count(inner));

    clone_seen = .{ -1, -1, -1 };
    _ = (try check(cloneProperty, .{ .reproduce = failure.blob })).?;
    try std.testing.expect(clone_seen[1] >= 40);
}

test "a clone's own choices shrink to the same minimum from every seed" {
    // Without a nested pass the flat passes step over the clone as one atomic
    // entry and report whatever value generation found.
    var blob: ?[]const u8 = null;
    for ([_]u64{ 1, 2, 3, 7, 11 }) |seed| {
        const failure = (try check(cloneProperty, .{ .examples = 200, .seed = seed })).?;
        try std.testing.expectEqual([3]i64{ 0, 40, 0 }, clone_seen);
        if (blob) |first| {
            try std.testing.expectEqualStrings(first, failure.blob);
        } else {
            blob = failure.blob;
        }
    }
}

var nested_seen: [2]i64 = .{ -1, -1 };

fn nestedCloneProperty(case: *TestCase) !void {
    const child = try case.cloneStream();
    const outer = try child.integer(0, 100, 0);
    const grandchild = try child.cloneStream();
    const inner = try grandchild.integer(0, 100, 0);
    nested_seen = .{ outer, inner };
    if (outer >= 10 and inner >= 20) return error.BothTooBig;
}

test "nested clones shrink at every depth" {
    const failure = (try check(nestedCloneProperty, .{ .examples = 300, .seed = 4 })).?;
    try std.testing.expectEqual([2]i64{ 10, 20 }, nested_seen);
    nested_seen = .{ -1, -1 };
    _ = (try check(nestedCloneProperty, .{ .reproduce = failure.blob })).?;
    try std.testing.expectEqual([2]i64{ 10, 20 }, nested_seen);
}

test "replaying a non-clone entry puns to an empty child" {
    // A blob whose clone position holds an ordinary integer — the shape a
    // property that grew a clone since the blob was written produces. Upstream
    // puns it to an empty child, which overruns on its first draw.
    var stream: std.ArrayList(u8) = .empty;
    try stream.appendSlice(allocator, core.choice_list_header(2));
    try stream.appendSlice(allocator, core.serialize_integer_choice(signedBytes(3)));
    try stream.appendSlice(allocator, core.serialize_integer_choice(signedBytes(4)));
    const blob = core.raw_failure_encode(stream.items);
    const property = struct {
        fn run(case: *TestCase) !void {
            _ = try case.integer(0, 100, 0);
            const child = try case.cloneStream();
            _ = try child.integer(0, 100, 0);
        }
    }.run;
    try std.testing.expectError(error.ReplayOverrun, check(property, .{ .reproduce = blob }));
}

test "a clone's notes and costs reach the family report" {
    const property = struct {
        fn run(case: *TestCase) !void {
            const child = try case.cloneStream();
            child.note("from the clone");
            child.cost("faults", 2);
            _ = try child.integer(0, 10, 0);
            if (case.notes().len != 1) return error.NotesDidNotReachTheFamily;
            if (case.totalCost() != 2) return error.CostsDidNotReachTheFamily;
        }
    }.run;
    try std.testing.expect((try check(property, .{ .examples = 5, .seed = 1 })) == null);
}
