# Zizek for Zig — feature guide

A walkthrough of every feature the Zig runner currently supports, with
runnable examples for each. See [README.md](README.md) for installation and
[dev.md](dev.md) for the core/shell architecture; this guide is about *using*
the API.

New to Zizek? [A worked example](#a-worked-example-splitting-a-bill) at the
end finds one real bug end to end; the rest of this guide is the reference
tour.

## Properties and `zizek.check`

A property is a function taking a `*zizek.TestCase` and failing by returning
any Zig error. Zig has no recoverable panic, so a returned error is the one
way a property fails; the error's name becomes the failure's reported cause
and its bug identity.

```zig
const std = @import("std");
const zizek = @import("zizek");

fn property(case: *zizek.TestCase) !void {
    const value = try zizek.integers().minValue(-100).maxValue(100).draw(case);
    if (value >= 5) return error.ValueTooLarge;
}

pub fn main(_: std.process.Init) !void {
    const failure = (try zizek.check(property, .{
        .examples = 200,
        .seed = 1,
    })).?;
    std.debug.print("{s}\nreproduce: {s}\n", .{ failure.cause, failure.blob });
}
```

`zizek.check(property, config)` takes any function-like value for the
property — a function, a pointer, or a bound `struct { fn ... }.run` — and a
`Config` struct literal:

| Field | Default | Meaning |
|-------|---------|---------|
| `.examples` | 100 | Valid (non-rejected) examples to run before declaring success. |
| `.max_rejections` | 458 | Initial rejection allowance; each valid example earns 100 more. |
| `.max_shrinks` | 500 | Accepted shrink candidates before the search stops. Zero disables the cap. |
| `.max_stall` | 200 | Consecutive rejected candidates before the search stops. Zero disables the cap. |
| `.suppress_filter_too_much` | `false` | Disable the early excessive-filtering health check. |
| `.suppress_data_too_large` | `false` | Disable the early choice-budget-overrun health check. |
| `.suppress_large_base_example` | `false` | Allow an all-simplest input that uses more than half the choice budget. |
| `.suppress_too_slow` | `false` | Disable the one-second cumulative generator-time health check. |
| `.seed` | 0 | Seed for random exploration. Repeats a search on one machine; portable reproduction uses blobs instead. |
| `.require` | `&.{}` | `Coverage` labels the completed run must have covered. See [Coverage assertions](#coverage-assertions). |
| `.database` | `null` | Where counterexamples are stored and replayed between runs. See [The example database](#the-example-database). |
| `.database_key` | `null` | The portable name a property's stored counterexamples are filed under. |
| `.reproduce` | `null` | A failure blob. When set, `check` replays exactly that example and runs nothing else. |

Note the seed's default: `0`, not "random". A bare `zizek.check(property, .{})`
explores the same examples on every run and every machine — what the dynamic
packages spell `derandomize` is this package's resting state. Pass a varying
`.seed` when you want each run to explore fresh ground.

### The verdict is a value

Where the dynamic packages split the outcome across two entry points — Ruby's
`Zizek.check` raises and `Zizek.run` returns a result — Zig's error unions
express both at once. `check` returns `!?Failure`:

- **`null`** — every example passed (and every coverage requirement held);
- **a `Failure`** — a property failed; the failure is already shrunk and
  carries a reproduce blob;
- **a returned error** — the run could not deliver a verdict, or delivered a
  non-counterexample one:
  - `error.TooManyRejections` — assumptions rejected too many examples;
  - `error.FilterTooMuch`, `error.DataTooLarge`, `error.LargeBaseExample`,
    `error.TooSlow` — a health check tripped (see
    [Shrinking and health checks](#shrinking-and-health-checks));
  - `error.FailedCoverage` — a coverage requirement was missed; details in
    `zizek.shell.failed_coverage`;
  - `error.Flaky` — a property failed, then did not fail the same way when
    that example was replayed; the original error name and the unshrunk
    example's blob are in `zizek.shell.flaky`;
  - `error.InvalidReplay` / `error.ReplayOverrun` — a reproduce blob is
    malformed, does not fail, or ends before the property stops drawing.

So the idiomatic test asserts the shape it expects:

```zig
test "the property holds" {
    try std.testing.expect((try zizek.check(property, .{ .examples = 500 })) == null);
}

test "the known bug is still caught" {
    const failure = (try zizek.check(property, .{ .examples = 500, .seed = 1 })).?;
    try std.testing.expectEqualStrings("ValueTooLarge", failure.cause);
}
```

### The `Failure` struct

```zig
pub const Failure = struct {
    blob: []const u8,          // portable base64 reproduce blob
    cause: []const u8,         // the error name, or the always/unreachable message
    examples_run: usize,
    rejections: usize,
    notes: []const []const u8, // notes recorded on the *minimal* example
    puns: usize,               // replayed draws that could not use their recorded value
    key_misses: usize,         // keyed draws whose name the blob did not carry
    cost: u64,                 // what the reported example spent; see Shrink costs
};
```

A Zig error is a bare value with no payload, which shapes two corners of this
API: the failure's `cause` is the error *name* (or, for `always` /
`unreachable`, the label-carrying assertion message), and the details behind
`error.FailedCoverage` are parked in the module-level
`zizek.shell.failed_coverage` rather than attached to the error.

## Repeating a search versus replaying an example

Two different things, worth keeping apart:

- The **blob** replays one recorded example. It is portable: the same blob
  replays in the Go, Python, Ruby, Rust, TypeScript, Java, C++, and Clojure
  packages. This is what a failure report is for.
- The **seed** repeats the whole search — the same examples in the same order
  — but only in this language and this version.

Because `Config.seed` defaults to `0`, a suite is derandomized unless it says
otherwise; there is no separate `derandomize` switch to reach for.

## Shrinking and health checks

Shrinking uses an adaptive binary-search schedule. `.max_shrinks` defaults to
500 accepted candidates and `.max_stall` to 200 consecutive rejected
executions; zero disables the corresponding cap. The rejection budget starts
at `.max_rejections = 458` and grows by 100 after each valid example.

The health checks catch a run that is not testing what it appears to:

- Fifty early rejections before ten valid examples return
  `error.FilterTooMuch` unless `.suppress_filter_too_much = true`.
- Random examples may realize 8,192 choices; twenty early budget overruns
  return `error.DataTooLarge` unless `.suppress_data_too_large = true`.
- `check` first runs an all-simplest input as a normal attempt. If it is
  valid and uses more than 4,096 choices, or overruns, it returns
  `error.LargeBaseExample` unless `.suppress_large_base_example = true`.
- During the first ten valid attempts, `check` accumulates monotonic time
  spent inside built-in generator `.draw(case)` calls. More than one
  cumulative second returns `error.TooSlow` unless
  `.suppress_too_slow = true`.

## Low-level draws

`TestCase` exposes the recorded primitive choices directly:

```zig
const value = try case.integer(0, 100, 0);        // min, max, shrink target
const flag = try case.boolean();                  // shrinks toward false
const biased = try case.weighted(0.9);            // boolean, true 90% of the time
const payload = try case.bytes(1, 4);             // 1..4 bytes, shrinks shortlex
const name = try case.string(1, 8, null);         // 1..8 characters, full Unicode
const ratio = try case.float(0.0, 1.0, false, false, 0); // min, max, nan?, inf?, smallest nonzero
```

Every draw is recorded, which is what makes shrinking and blob replay work.
Narrow integer ranges (fewer than 256 values) are drawn uniformly, so a draw
that indexes a list picks every option equally often. Wide ranges use a
per-case swarm: the generated core supplies candidates such as the interval
endpoints and values near zero, so bugs at boundaries (like `1` in
`0..1_000_000`) are found reliably. The weight on `weighted`
biases generation only — the choice is recorded as an ordinary boolean, so a
blob replays the same whatever probability produced it.

## Generator builders

The typed builders under `zizek.generators` wrap the same draws with
configuration. Anything with a `draw(case)` method is a generator — the
combinators are generic over that shape at comptime rather than over a trait —
and each configuration call returns a new value, so builders can be shared
and reused freely:

```zig
const value = try zizek.integers().minValue(0).maxValue(100).draw(case);
const size = try zizek.floats().minValue(0.0).maxValue(1.0).draw(case);
const word = try zizek.text().minSize(1).maxSize(8).draw(case);
const packet = try zizek.lists(i64, zizek.integers().minValue(0).maxValue(255))
    .minSize(1)
    .maxSize(12)
    .draw(case);
```

- `zizek.integers()` — full-range 64-bit signed integers until bounded with
  `.minValue(n)` / `.maxValue(n)`; `.shrinkTowards(n)` moves the shrink
  destination.
- `zizek.floats()` — IEEE-754 doubles with portable shrinking. `.allowNaN(true)`
  and `.allowInfinity(true)` are off unless asked for: a property that has an
  opinion about them should say so. `.smallestNonzeroMagnitude(x)` excludes
  the interval `(0, x)`.
- `zizek.text()` — text over an alphabet, by default every Unicode scalar
  value. `.minSize` / `.maxSize` are lengths **in characters** (the value is
  UTF-8 bytes, so its byte length is only an upper bound). Values shrink
  shortlex towards `"0"`, then the digits and uppercase letters, so a minimal
  failing string is one you can retype. Narrow the characters with
  `.alphabet(try zizek.alphabet("abc"))` or
  `.alphabet(zizek.alphabetRange(0x20, 0x7E))`.
- `zizek.lists(T, element)` — a variable-length slice. Each element is
  recorded as its own span, so the shrinker deletes whole elements — including
  ones in the middle — before it simplifies the values inside them.
- `zizek.sets(T, element)` and
  `zizek.uniqueLists(T, K, element, key)` — the same sequence with
  a distinctness constraint, judged on the whole value or on a projection. A
  value that repeats one already drawn costs the *element*, not the example:
  its choices are discarded and another candidate is drawn. Asking for more
  distinct values than the element generator can produce rejects the example
  rather than looping. Zig has no value-semantics set type, so a set is a
  slice of pairwise-distinct elements — which is also the shape the shrinker
  can delete elements from — and there is no map generator for the same
  reason.
- `zizek.generators.booleans()`,
  `zizek.generators.weightedBooleans(probability)`, and
  `zizek.generators.binary()` (with `.minSize` / `.maxSize`) — booleans
  shrinking towards `false` and byte strings shrinking shortlex.

### The catalogue combinators

`zizek.generators` also carries the composition vocabulary. Zig's generics are
comptime parameters, so where a dynamic package infers types, this package
names them:

```zig
const g = zizek.generators;

// Always one value, recording no choice.
const origin = g.just(i64, 0);

// The optional stands in for the dynamic packages' none().
const missing = g.none(u32);

// One of a fixed slice, one recorded integer, shrinking towards the first.
const method = try g.sampledFrom(Method, &[_]Method{ .get, .post, .delete }).draw(case);

// Two generators drawn in order, paired. Zig has no variadic type
// parameters, so wider tuples nest pairs.
const request = try g.pair(
    i64,
    bool,
    zizek.integers().minValue(0).maxValue(9),
    g.booleans(),
).draw(case);
_ = request.first;
_ = request.second;
```

`oneOf` draws from one of several generators, shrinking towards the first.
Its branches live in a slice, so they must share one type — give them a
common struct with a tag rather than two different generator types:

```zig
const Branch = struct {
    wide: bool,

    pub fn draw(self: @This(), case: *zizek.TestCase) !i64 {
        if (!self.wide) return 0;
        return case.integer(1, 9, 0);
    }
};
const branches = [_]Branch{ .{ .wide = false }, .{ .wide = true } };
const extra = try zizek.generators.oneOf(i64, &branches).draw(case);
```

`map`, `filter`, and `flatMap` take the transform as a comptime parameter, so
the result type is known without naming a closure type:

```zig
fn double(value: i64) i64 {
    return value * 2;
}
fn isEven(value: i64) bool {
    return @rem(value, 2) == 0;
}

const doubled = try g.map(i64, zizek.integers().minValue(0).maxValue(10), double).draw(case);
const evens = try g.filter(i64, zizek.integers().minValue(0).maxValue(20), isEven).draw(case);
```

A `filter` whose predicate rejects a bounded number of attempts in a row
rejects the *example* (an assumption, not a failure), so an unsatisfiable
filter surfaces as `error.TooManyRejections` or `error.FilterTooMuch` rather
than a hang.

`flatMap` builds the next generator from each drawn value — monadic bind. The
transform must return one comptime-known generator type, so the inner
generator is a struct holding the drawn value rather than a closure:

```zig
const Inner = struct {
    scale: i64,

    pub fn draw(self: @This(), case: *zizek.TestCase) !i64 {
        return zizek.integers()
            .minValue(self.scale * 10)
            .maxValue(self.scale * 10 + 100)
            .draw(case);
    }
};
fn scaled(value: i64) Inner {
    return .{ .scale = value };
}

const value = try zizek.generators.flatMap(
    i64,
    zizek.integers().minValue(0).maxValue(3),
    scaled,
).draw(case);
```

Both draws share one `flat_map` span, so the shrinker can delete or simplify
the unit together, and the inner draws replay by the ordinary prefix rules.
The blob a `flatMap` failure pins is identical in every package that has the
combinator.

None of the wrappers records a choice of its own — only `sampledFrom` and
`oneOf` do, and each records exactly one integer — so composing them leaves
the reproduce blob byte-compatible with the other packages.

### Composing with `composite`

Use `composite` when later values depend on earlier draws. Zig already hands
the test case to a property, so the natural spelling takes it directly:

```zig
const Window = struct { low: i64, high: i64 };

const windows = zizek.generators.composite(Window, struct {
    fn draw(case: *zizek.TestCase) !Window {
        const low = try zizek.integers().minValue(0).maxValue(100).draw(case);
        const high = try zizek.integers().minValue(low).maxValue(100).draw(case);
        return .{ .low = low, .high = high };
    }
}.draw);

const window = try windows.draw(case);
```

Combinators record only the choices made by their source generators, so a
composed value still shrinks and replays as an ordinary portable choice
stream. Collection elements occupy structural spans, so the shrinker deletes
whole elements before simplifying the values that remain:

```zig
const octet = zizek.integers().minValue(0).maxValue(255);
const packet = try zizek.lists(i64, octet).minSize(1).maxSize(12).draw(case);
const ports = try zizek.sets(i64, octet).minSize(1).maxSize(5).draw(case);
```

### Shrink targets

By default integers shrink toward 0 (clamped into the interval). With
`.shrinkTowards`, the reported counterexample is the failing value closest to
your target rather than the smallest one:

```zig
const value = try zizek.integers()
    .minValue(-1000)
    .maxValue(1000)
    .shrinkTowards(500)
    .draw(case);
// if the property fails for value > 700, the failure shrinks to exactly 701
```

An explicit target outside the interval clamps to the nearer bound — a
cross-language rule this package pins with a shared blob fixture.

## Assumptions

`try case.assume(condition)` rejects the current example when the condition
is false. Rejection is control flow, not failure: `check` keeps generating
until it has run `examples` valid examples or exceeds the adaptive rejection
budget `max_rejections + 100 * valid`, at which point it returns
`error.TooManyRejections`.

```zig
const value = try case.integer(0, 100, 0);
try case.assume(@rem(value, 2) == 0); // odd draws are discarded, not failed
```

Shrinking respects assumptions too: a shrink candidate that gets rejected is
skipped, so the shrunk counterexample always satisfies every assumption.

## Coverage assertions

Four calls, split by what they judge. `always` and `@"unreachable"` judge the
current example; `sometimes` and `cover` judge the completed run.

```zig
fn clampProperty(case: *zizek.TestCase) !void {
    const value = try case.integer(0, 1000, 0);
    const clamped = std.math.clamp(value, 0, 100);

    // Per example: ordinary failures that shrink and replay.
    try case.always("clamped into range", clamped >= 0 and clamped <= 100);
    if (clamped > value) try case.@"unreachable"("clamp raised the value");

    // Per run: a verdict on the whole run, not on this example.
    case.sometimes("saturated at the ceiling", clamped == 100);
    try case.cover("left below the ceiling", clamped < 100, 10);
}
```

- `try case.always(label, condition)` fails the current example when the
  condition does not hold, as `error.AlwaysFailed`; the failure's `cause`
  carries the labelled message, and it shrinks and replays like any other
  failure, with the label as part of the bug's identity. A `clamp` that
  forgets its ceiling shrinks to the smallest value that escapes it, `101`:

  ```text
  cause: always: "clamped into range" did not hold
  blob:  AAEAAAAACgEAAABl
  ```

- `try case.@"unreachable"(label)` fails the example that reaches it at all
  (`error.UnreachableReached`), so the shrunk counterexample is the simplest
  input reaching the branch. (`unreachable` is a Zig keyword, hence the
  quoted name.)
- `case.sometimes(label, condition)` fails a *completed run* in which the
  condition never held — the vacuous pass. A false condition never fails the
  example it appears in; it is the only call in the family that cannot fail,
  so it needs no `try`. The missed run reads:

  ```text
  coverage: "saturated at the ceiling" never held in 200 valid examples
  ```

- `try case.cover(label, condition, percent)` is the same assertion with a
  required rate over the run's valid examples. A label counts once per
  example however many times its call site runs, and observations from
  rejected or overrun examples are discarded with the rest of the example.

A call site registers its label the first time it runs, so a `sometimes`
placed *inside* a branch is silent about the run that never enters the branch
at all. Declare those labels up front instead:

```zig
_ = try zizek.check(clampProperty, .{
    .examples = 200,
    .require = &.{
        .{ .label = "clamped into range" },              // the site must be reached
        .{ .label = "saturated at the ceiling", .percent = 5 }, // ... in 5% of examples
    },
});
```

A holding `always` also counts as covering its label, which is what separates
this `always` from Antithesis's: the bare call permits a site that never runs
("always or unreachable"), and listing the label in `Config.require`
additionally demands the run reach it.

A missed requirement is reported as `error.FailedCoverage`, with the label and
counters in `zizek.shell.failed_coverage`:

```zig
if (zizek.check(clampProperty, .{ .examples = 200 })) |failure| {
    _ = failure; // a real counterexample, or null when the run passed
} else |err| switch (err) {
    error.FailedCoverage => {
        const missed = zizek.shell.failed_coverage.?;
        std.debug.print("{f}\n", .{missed}); // label, observed, valid, min_percent
    },
    else => return err,
}
```

There is no counterexample, so there is no blob and nothing to shrink — the
failure is the *absence* of an example; the same seed reproduces the identical
verdict. A run that finds a real counterexample reports that instead, and
reproduce mode skips coverage entirely. The verdict is compiled from
`ir/lifecycle.zir`, so every language agrees on it.

## Notes

`case.note(message)` attaches a diagnostic line to the current example. Notes
are collected per example and reported on the shrunk failure in
`failure.notes` — so they describe the *minimal* example, not the noisy first
one. The message is duplicated into the package allocator, so a
`std.fmt.allocPrint` message is the usual spelling:

```zig
case.note(std.fmt.allocPrint(
    zizek.shell.allocator,
    "transfer {d} from \"{s}\" to \"{s}\"",
    .{ amount, from, to },
) catch unreachable);
```

## Failures, blobs, and replay

A shrunk failure carries a portable, base64 reproduce blob:

```zig
if (try zizek.check(property, .{ .examples = 200, .seed = 1 })) |failure| {
    // Replays exactly the recorded choices — nothing is random.
    _ = try zizek.check(property, .{ .reproduce = failure.blob });
}
```

Blobs encode the recorded choice sequence, not the RNG seed, so they replay
bit-exactly across machines *and languages*: a blob printed by the Zig runner
replays in all eight other packages (the shared fixture `AAEAAAAACgEAAAAF`
replays the integer `5` in every test suite, and the ledger and Die Hard
examples pin cross-language blob fixtures of their own).

Replay is defensive:

- a structurally invalid blob — or one whose property does not fail — returns
  `error.InvalidReplay`;
- a blob that ends before the property stops drawing returns
  `error.ReplayOverrun`;
- a choice of the wrong kind (or out of range) puns to the requested draw's
  unit value instead of failing, so replay stays deterministic while you edit
  the property.

A pun keeps the replay running, but it means the values you get back are not
the ones the blob recorded — and nothing in the values themselves says so.
Every replay therefore counts its puns: `failure.puns` reports how many.
Treat a non-zero count as "this blob no longer reproduces what it recorded",
not as a hard error.

## Keyed draws

Positional replay gives a draw its meaning from how many draws came before
it, which is exactly right until the property changes shape: insert one new
draw and every recorded choice after it answers the wrong question. A keyed
draw is addressed by a *name* instead, so a blob keeps meaning what it
recorded while the property around it evolves:

```zig
const timeout = try case.integerKeyed(1, 30, 0, zizek.key(&.{.{ .text = "timeout" }}));
const retries = try case.integerKeyed(0, 9, 0, zizek.key(&.{.{ .text = "retries" }}));
```

- `zizek.key(parts)` names a decision made at most once per example. Parts
  are `KeyPart` values — `.{ .text = "..." }` or `.{ .int = n }` — hashed by
  the compiled encoding (`ir/keys.zir`), so the same name means the same
  entry in every language package.
- `case.nextKey(parts)` appends an execution-local ordinal, counted *within
  that name*, for a decision made repeatedly —
  `case.nextKey(&.{ .{ .text = "read" }, .{ .int = connection } })` numbers
  that connection's reads independently of every other sequence.

Every primitive draw has a keyed variant: `integerKeyed`, `booleanKeyed`,
`weightedKeyed`, `bytesKeyed`, `stringKeyed`, and `floatKeyed`.

On replay a keyed draw looks its name up wherever it sits in the stream, and
the positional cursor steps over keyed entries, so the two addressing modes
never shift each other. A name the blob does not carry means the property
changed, not that the blob is malformed: the draw uses its simplest value,
and the failure counts and reports the miss (`failure.key_misses`) instead of
erroring.

Here a connection is chosen once, and each of its reads is numbered by
`nextKey` within that connection's own sequence:

```zig
const connection = try case.integerKeyed(1, 4, 0, zizek.key(&.{
    .{ .text = "connection" },
}));
for (0..3) |_| {
    const payload = try case.bytesKeyed(0, 16, case.nextKey(&.{
        .{ .text = "read" },
        .{ .int = connection },
    }));
    case.note(try std.fmt.allocPrint(zizek.shell.allocator, "read {d} bytes", .{payload.len}));
}
```

## The example database

Set `.database` and a failure outlives the run that found it:

```zig
var examples = zizek.DirectoryDatabase.init(".zizek/examples");
const failure = try zizek.check(property, .{
    .database = examples.database(),
    .database_key = "split_is_exact",
});
```

The next run replays every stored entry for that key *before* it generates
anything, so a bug found yesterday reproduces on the first attempt. An entry
that no longer reproduces — because the bug was fixed — is deleted on the
replay that failed to reproduce it, so the directory keeps itself current.
Replays count as attempts but not toward `.examples`, the coverage verdict, or
the health checks, and a `.reproduce` run touches the database not at all.
Every operation is best-effort: an unwritable directory never fails a test
that would otherwise pass.

The database is off until asked for. `zizek.InMemoryDatabase` keeps entries
for the life of the process, and `zizek.DirectoryDatabase.initDir(dir)` uses
an already-open directory, which the caller keeps owning. Any type with
`fetch`, `save`, and `delete` methods becomes a `zizek.Database` through
`zizek.Database.init(&value)`.

What makes it more than a cache is the layout: raw choice streams, filed under
a hash the IR computes, which the other Zizek packages with a database write
identically. A counterexample another language's suite found replays here
out of one checked-in directory, provided both name the property the same with
`.database_key`. Left unset, the key is the property's Zig type name, which
no other language can reproduce and which two properties declared with the
same signature and an explicit error set share — so name it.

## Shrink costs

The shrinker's default order answers "what is the simplest *input* that
fails". A fault-injecting property usually wants a different question
answered first: "how few *faults* suffice?" Under the default order, turning
one injected fault off is worth exactly as much as making one integer a
little smaller, so the search may keep four faults because the stream around
them happens to be shorter.

`case.cost(label, amount)` declares what an example spent:

```zig
if (try case.booleanKeyed(case.nextKey(&.{.{ .text = "inject" }}))) {
    case.cost("reorder", 1); // this example spent one fault
    reorder(queue);
}
```

The shrinker then orders candidates by **total cost first** — a candidate
injecting one fewer fault wins even when its choice stream is longer — with
the ordinary stream order as the tiebreak, so a property that never calls
`cost` shrinks exactly as before. The failure reports the total on
`failure.cost`, and `case.costOf(label)` / `case.totalCost()` read the
breakdown inside the run.

## Targeted generation

`cost` orders shrinking after a failure; `target` steers generation toward
one. A property records one finite score per label per example:

```zig
const value = try case.integer(0, 100_000, 0);
case.target(@floatFromInt(value));
if (value >= 99_990) return error.Overflowed;
```

The run keeps the best-scoring valid example per label and, on a schedule,
hill-climbs its recorded choices — so a failing band at the far end of the
scored quantity is found in a fraction of the examples random search needs. A
failing climb trial shrinks and reports like any other counterexample, and
nothing new enters the blob. Target several quantities by naming them:
`case.targetLabelled(score, "depth")` — each label may be observed at most
once per example, and every score must be finite.

## Structural spans (advanced)

Framework-level code can group choices into labelled ranges so the shrinker
can delete whole semantic units at once:

```zig
_ = case.startSpan("stateful.rule");
// ... draws ...
case.stopSpan(false); // or case.stopSpan(true) for a discarded attempt
```

The state-machine runner uses spans for each rule, and `zizek.lists` uses one
per element, which is why a 40-step failing run shrinks to the three or six
steps that matter and a 30-element list shrinks to the one element that does.
Spans are also what generation-phase *mutation* copies: after ten valid
examples, discovery may duplicate one same-label span into another, which is
how two independent 64-bit draws come out equal often enough to find equality
bugs. `case.spans()` returns the recorded `ChoiceSpan` values for
inspection. Most tests never call these directly.

A custom generator exposes the same structure by wrapping each unit in a
span. Close it as discarded when a draw inside it errors, so a rejected or
overrun draw does not leave the span open:

```zig
var values: [2]i64 = undefined;
for (&values) |*value| {
    _ = case.startSpan("operand");
    value.* = case.integer(std.math.minInt(i64), std.math.maxInt(i64), 0) catch |err| {
        case.stopSpan(true);
        return err;
    };
    case.stopSpan(false);
}
if (values[0] == values[1] and values[0] != 0) return error.EqualNonzeroOperands;
```

Mutation participates only in discovery: the reported counterexample remains
a normal portable choice stream, and normal shrinking minimizes it.

## Cloned streams (advanced)

`try case.cloneStream()` returns a child test case that draws from a stream
of its own, occupying one choice position in the parent's. The child's draws
neither shift nor are shifted by the parent's, its stream is framed inside
the parent's blob with the engine's wire format, and the shrinker descends
into it with the same schedule — which is what makes it the seam a
concurrent runner would use, though today the child is drawn from
sequentially. Notes, costs, coverage, and the choice budget all belong to the
family rather than to one stream.

## Stateful testing

Declare rules and invariants as `stateful.Rule(State)` values — a name and a
function pointer taking the state and the test case — and hand them to
`stateful.run` inside a property. The state is an ordinary struct built fresh
per example, so shrink candidates and replays each get their own:

```zig
const Counter = struct {
    value: i64 = 0,

    fn increment(self: *Counter, case: *zizek.TestCase) !void {
        const amount = try zizek.integers().minValue(0).maxValue(10).draw(case);
        self.value += amount;
    }

    fn decrement(self: *Counter, case: *zizek.TestCase) !void {
        try case.assume(self.value > 0); // a precondition
        self.value -= 1;
    }

    fn nonnegative(self: *Counter, _: *zizek.TestCase) !void {
        if (self.value < 0) return error.Negative;
    }
};

fn counterProperty(case: *zizek.TestCase) !void {
    var state = Counter{};
    const rules = [_]zizek.stateful.Rule(Counter){
        .{ .name = "increment", .apply = Counter.increment },
        .{ .name = "decrement", .apply = Counter.decrement },
    };
    const invariants = [_]zizek.stateful.Rule(Counter){
        .{ .name = "nonnegative", .apply = Counter.nonnegative },
    };
    try zizek.stateful.run(&state, zizek.stateful.Machine(Counter){
        .rules = &rules,
        .invariants = &invariants,
    }, case);
}

// zizek.check(counterProperty, .{ .examples = 500 })
```

`run` checks every invariant once before the first rule, then draws a capped
number of steps (at most `stateful.default_step_count`, 50; use
`stateful.runSteps(&state, machine, case, 200)` for another bound), picks a
rule per step, and re-checks every invariant after each successful rule. A
rule that calls `try case.assume(false)` is recorded as rejected and skipped
without failing the run — a precondition rather than a rejection of the whole
example; it spends an attempt, not a step. Each rule invocation is its own
structural span, so the shrinker deletes whole commands and swaps adjacent
ones before it simplifies the arguments inside them: a six-step failure
minimizes to the shortest sequence that still fails.

The choice stream this records is identical to the one Ruby's `Machine`
class macros or Go's registered rules record, so a blob from any of them
replays here.

### Pools

`stateful.Pool(T)` holds values produced by earlier rules behind portable
choices, so shrinking and replay stay deterministic even though the values
are arbitrary Zig values — connections, accounts, handles:

```zig
var accounts = zizek.stateful.Pool([]const u8).init(case);
try accounts.add(case, "a");

const account = try accounts.reusable(case); // stays in the pool
const closed = try accounts.consumed(case);  // removed from the pool
```

Adding is itself a *draw*: the value's identity is a recorded stable
identifier, not a host-side counter, which is what lets the shrinker delete
an earlier addition without renumbering what every later draw refers to.
Drawing from an empty pool rejects the current rule attempt (via `assume`),
so rules that need prerequisites simply retry on another step.

Pools are execution-local. Construct and populate them inside the property so
discovery, shrinking, and replay rebuild the same values in the same order.
The complete acceptance example is [examples/ledger.zig](examples/ledger.zig)
— it shrinks to the same portable three-step reproduce blob as every other
package.

## Using it from `zig build test`

Zig's native test blocks are this package's test-framework integration: a
property is a `test` that asserts the verdict's shape, and `zig build test`
(or `zig test`) runs it with the toolchain's own reporters. The examples
under [examples/](examples/) keep their expected outcomes as test blocks next
to `main`, which is the shape a real suite takes:

```zig
test "the split is exact" {
    try std.testing.expect((try zizek.check(splitProperty, .{ .examples = 500 })) == null);
}

test "the known bug shrinks to its portable blob" {
    const failure = (try zizek.check(buggyProperty, .{ .examples = 500, .seed = 23 })).?;
    try std.testing.expectEqualStrings("AAIAAAAACgEAAAABAAoBAAAAAg==", failure.blob);
}
```

Pinning the blob string in the test does double duty: it is a regression test
for the bug *and* a cross-language fixture any other package's suite can
replay.

## Memory

Nothing in the shell or the generated core frees: every function returns an
owned slice, memory is reclaimed at process exit, and a `Failure`, its blob,
and its notes outlive the `check` that produced them. That makes *which*
allocator the package uses a load-bearing choice rather than a detail: with
one allocation per page, 20,000 examples drawing a list and some text
measured 5.4 GB and 26 seconds; packing them instead, the same run is 41 MB
and 0.17 seconds.

The package allocator defaults to `std.heap.smp_allocator`, which packs.
`zizek.setAllocator` points the shell, its state machines, and the generated
core somewhere else:

```zig
var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
defer arena.deinit();
zizek.setAllocator(arena.allocator());
```

An arena is the useful case for a long-running caller: reset it *between*
runs and resident memory stops tracking how many examples have executed. What
is not safe is resetting one mid-run, or before you are done with a returned
`Failure`, since its blob and notes are allocated from it.

## What the Zig package does not have

Relative to the Ruby package, in the order a Ruby user would miss them:

- **No named draws.** `Failure` has no `values` field and draws take no
  `name:`; the `Falsifying example:` line is spelled with `case.note` and the
  error name instead. Naming records no choice in any package, so blobs are
  unaffected.
- **No settings profiles.** `Config` is a plain struct — build shared
  configurations as ordinary Zig constants and struct update syntax
  (`.{ .examples = 5_000 }`, `base` merged by hand) rather than a process
  registry. There is no `derandomize` flag because a fixed seed is already
  the default.
- **No `example()` convenience** on generators, and no map/`hashes`
  generator or variadic `tuples` (nest `pair`, or write a `composite`).
- **`check` is also `run`.** There is no separate raising entry point; the
  optional-plus-error return already carries the verdict as a value.

And relative to every package: property failures must be representable as
returned Zig errors (no payload beyond the name), and alphabets selected by
Unicode *category* are not built in.

## A worked example: splitting a bill

A helper divides a bill, in cents, among a group of people. Integer division
discards the remainder, so `101` cents between two people comes out as
`{ 50, 50 }`:

```zig
fn splitBill(total_cents: i64, people: i64) []const i64 {
    const shares = zizek.shell.allocator.alloc(i64, @intCast(people)) catch unreachable;
    @memset(shares, @divTrunc(total_cents, people));
    return shares;
}
```

The property checks the invariant rather than examples: one share per person,
the shares sum to the total, and no two differ by more than a cent. Building
it from a comptime function parameter runs the same property against more
than one implementation:

```zig
fn allocationProperty(comptime allocate: fn (i64, i64) []const i64) fn (*zizek.TestCase) anyerror!void {
    return struct {
        fn property(case: *zizek.TestCase) !void {
            const total = try zizek.integers().minValue(0).maxValue(1_000_000).draw(case);
            const people = try zizek.integers().minValue(1).maxValue(100).draw(case);

            const shares = allocate(total, people);
            case.note(std.fmt.allocPrint(
                zizek.shell.allocator,
                "allocated {d} cents among {d} people as {any}",
                .{ total, people, shares },
            ) catch unreachable);

            if (shares.len != @as(usize, @intCast(people))) return error.WrongNumberOfShares;
            var sum: i64 = 0;
            for (shares) |share| sum += share;
            if (sum != total) return error.MoneyLostOrCreated;
            const spread = std.mem.max(i64, shares) - std.mem.min(i64, shares);
            if (spread > 1) return error.SharesDifferByMoreThanOneCent;
        }
    }.property;
}

const failure = (try zizek.check(allocationProperty(splitBill), .{
    .examples = 500,
    .seed = 23,
})).?;
std.debug.print("{s}\n", .{failure.cause});
for (failure.notes) |note| std.debug.print("  {s}\n", .{note});
std.debug.print("reproduce: {s}\n", .{failure.blob});
```

The failure shrinks to the smallest boundary case, and the note is the one
recorded on that minimal example, not on the noisy first one:

```text
MoneyLostOrCreated
  allocated 1 cents among 2 people as { 0, 0 }
reproduce: AAIAAAAACgEAAAABAAoBAAAAAg==
```

The Go, Python, Ruby, and TypeScript packages shrink the same bug to the same
blob. Handing out the remaining cents one at a time fixes it, and the same
property then passes:

```zig
fn splitBillExactly(total_cents: i64, people: i64) []const i64 {
    const base = @divTrunc(total_cents, people);
    const remainder: usize = @intCast(@rem(total_cents, people));
    const shares = zizek.shell.allocator.alloc(i64, @intCast(people)) catch unreachable;
    for (shares, 0..) |*share, index| share.* = base + @intFromBool(index < remainder);
    return shares;
}

// zizek.check(allocationProperty(splitBillExactly), .{ .examples = 1_000, .seed = 23 })
// returns null.
```

## Runnable examples

Build and run from the package root:

| Example | Features | Run |
|---------|----------|-----|
| [`examples/hypothesis_quickstart.zig`](examples/hypothesis_quickstart.zig) | bounded integers, boundary shrinking, blob replay | `zig build run-hypothesis-quickstart` |
| [`examples/min_stack.zig`](examples/min_stack.zig) | unbounded integers, span mutation finding equal draws, structural shrinking | `zig build run-min-stack` |
| [`examples/stack.zig`](examples/stack.zig) | a passing state-machine model with a rejected rule precondition | `zig build run-stack` |
| [`examples/multi.zig`](examples/multi.zig) | shrinking preserves the discovered failure origin | `zig build run-multi` |
| [`examples/die_hard.zig`](examples/die_hard.zig) | state-machine search, generation-phase mutation, cross-language blob | `zig build run-die-hard` |
| [`examples/ledger.zig`](examples/ledger.zig) | full stateful slice: pools, text, invariants, cross-language blob fixture | `zig build && ./zig-out/bin/zizek-ledger` |

Each example is deterministic, asserts its own expected outcome in a `test`
block, and prints the shrunk failure with its reproduce blob.
