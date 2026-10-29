<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/zizek-zig-logo-dark.svg">
    <img src="docs/assets/zizek-zig-logo.svg" alt="Zizek.zig" width="320">
  </picture>
</p>

# Zizek for Zig

This package is the native Zig runtime for Zizek property testing, based on
[Hegel](https://hegel.dev) and
[Hypothesis](https://hypothesis.readthedocs.io/en/latest/) and keeping them
as oracle implementations. It explores generated examples, records every
choice, shrinks the first failure, and returns a failure containing a portable
reproduce blob.

More than two thirds of the core behavior is compiled from the Hegel engine
into `zizek_gen.zig`; the rest is a curated shell that aims to be idiomatic
Zig. [dev.md](dev.md) describes the split.

> ⚠️ **Status: experimental.** Behavior and the public API can still change and
> be tweaked between releases.

## Add as a dependency

The package builds with Zig 0.16 and 0.17. Fetch it into your `build.zig.zon`:

```bash
zig fetch --save git+https://github.com/wallyqs/zizek.zig#v0.1.1
```

or name a local checkout as a path dependency:

```zig
.dependencies = .{
    .zizek = .{ .path = "../zizek.zig" },
},
```

Then import its module in `build.zig`:

```zig
const zizek = b.dependency("zizek", .{
    .target = target,
    .optimize = optimize,
});
your_module.addImport("zizek", zizek.module("zizek"));
```

## Quick start

A property is a function taking a `*zizek.TestCase` and failing by returning
any Zig error:

```zig
const std = @import("std");
const zizek = @import("zizek");

fn property(case: *zizek.TestCase) !void {
    const value = try zizek.integers().minValue(-100).maxValue(100).draw(case);
    if (value >= 5) return error.TooLarge;
}

pub fn main(_: std.process.Init) !void {
    const failure = (try zizek.check(property, .{ .examples = 200, .seed = 1 })).?;
    std.debug.print("{s}\nreproduce: {s}\n", .{ failure.cause, failure.blob });

    // Runs exactly the recorded, shrunk example and fails again.
    _ = (try zizek.check(property, .{ .reproduce = failure.blob })).?;
}
```

The failure is already shrunk to the boundary, and its blob replays that
example in this package or any other Zizek package:

```text
TooLarge
reproduce: AAEAAAAACgEAAAAF
```

`check` returns `!?Failure`: `null` when every example passed, a `Failure`
when the property failed, and a returned error when the run could not deliver
a counterexample verdict (too many rejections, a health check, a missed
coverage requirement). In a test block, assert the shape you expect; pinning
the blob keeps the bug as a regression test:

```zig
test "the bound is caught and shrunk to its edge" {
    const failure = (try zizek.check(property, .{ .examples = 200, .seed = 1 })).?;
    try std.testing.expectEqualStrings("AAEAAAAACgEAAAAF", failure.blob);
}
```

## Generators

Builders such as `zizek.integers()`, `zizek.text()`, `zizek.lists`, and
`zizek.sets` compose with the combinators in `zizek.generators`, and add no
hidden choices, so a composed value shrinks and replays like a plain one:

```zig
const g = zizek.generators;

const Method = enum { get, post, delete };

fn isEven(value: i64) bool {
    return @rem(value, 2) == 0;
}

fn requestProperty(case: *zizek.TestCase) !void {
    const method = try g.sampledFrom(Method, &.{ .get, .post, .delete }).draw(case);
    const resource = try zizek.text().maxSize(8).draw(case);
    const ports = try zizek.sets(i64, zizek.integers().minValue(1).maxValue(9)).maxSize(3).draw(case);
    const retries = try g.filter(i64, zizek.integers().minValue(0).maxValue(10), isEven).draw(case);
    _ = .{ ports, retries };
    if (method == .delete and resource.len == 0) return error.DeleteNeedsAResource;
}
```

## Stateful testing

Register rules and invariants as function pointers on a plain state struct
and run them inside a property; a failure shrinks to the shortest sequence of
steps that still fails:

```zig
const Counter = struct {
    value: i64 = 0,

    fn increment(self: *Counter, case: *zizek.TestCase) !void {
        self.value += try zizek.integers().minValue(0).maxValue(10).draw(case);
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
    try zizek.stateful.run(&state, zizek.stateful.Machine(Counter){
        .rules = &.{
            .{ .name = "increment", .apply = Counter.increment },
            .{ .name = "decrement", .apply = Counter.decrement },
        },
        .invariants = &.{
            .{ .name = "nonnegative", .apply = Counter.nonnegative },
        },
    }, case);
}

// zizek.check(counterProperty, .{ .examples = 500 })
```

## Learn more

- [GUIDE.md](GUIDE.md) walks through every feature with runnable examples:
  configuration and health checks, coverage assertions, keyed draws, the
  example database, pools, memory and allocators, and more.
- [`examples/`](examples) holds runnable examples; each is listed in the
  guide.
- [dev.md](dev.md) covers the core/shell split, verification, and the
  upstream example ports.
- [CHANGELOG.md](CHANGELOG.md) records each release.

## Functionality

- Deterministically seeded sequential property exploration.
- Recorded `i64`, boolean, byte, IEEE-754 float, and Unicode text choices.
- Uniform narrow and swarm-biased wide integers, swarm-biased floats, and
  typed integer/float/text generator builders.
- Assumption-based rejection with a configurable rejection limit.
- Variable-length `zizek.lists` whose elements shrink by deletion, plus
  `zizek.sets` and `zizek.uniqueLists` for distinct elements.
- Per-choice shrinking plus element-span and rule-span deletion.
- Portable failure blobs with exact replay, choice punning, forced-position
  accounting, and overrun detection. Punned draws are counted and reported on
  the failure.
- Coverage assertions (`always`, `unreachable`, `sometimes`, `cover`), keyed
  draws, shrink costs, and targeted generation.
- An example database that stores counterexamples between runs and replays
  them before generating, in a layout the other Zizek packages share.
- State machines with initial/post-rule invariants, rejected-rule handling,
  notes, and a default budget of 50 successful steps (rejected rules spend an
  attempt, not a step).
- Reusable and consumed generic pools addressed by generated stable
  identifiers.
- A ledger acceptance example that shrinks to two account creations and one
  transfer of `1`, producing the same blob as every other package.
- Runnable ports of Hypothesis's quickstart and Hegel's stack, minimum-stack,
  multiple-origin, and Die Hard examples.
