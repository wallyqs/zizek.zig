# Zizek for Zig: development notes

How the package is laid out and checked, for working on it rather than using
it. The [README](README.md) covers installation and the basics, and
[GUIDE.md](GUIDE.md) every feature.

## Core and shell

- `zizek.zig` is the public module root: `@import("zizek")` exposes the
  re-exports listed there, plus the `core`, `shell`, `generators`, and
  `stateful` namespaces.
- `zizek_gen.zig` is generated from ZizekIR and owns deterministic choice
  indexing, boundary candidates, structural rewrites, stateful helpers,
  serialization, replay, the health-check and generation-schedule rules, and
  the shrink search's decisions: which request to make next, the candidate
  schedule, the cursor arithmetic, and the accept rule. It is pure — plain
  data in, plain data out, with no state beyond the allocator it is handed, no
  randomness, no I/O, and no error returns. Do not edit it.
- `shell.zig` owns every effect: random exploration, the clock, invoking the
  property, notes, the example database, and failure mapping — including
  deriving the opaque bug-origin token (the error name, or the label-carrying
  assertion message for `always`/`unreachable`) that the generated accept rule
  compares. It also drives the generation, search, and shrink loops, holding
  their cursors and schedules, and asks the core for each decision. That loop
  is written again in every language package; the shared conformance tables
  are what keep the packages in agreement.
- `generators.zig` contains the typed builders and combinators.
- `stateful.zig` owns Zig values, invokes rules and invariants, and carries
  the pools.
- `shellcases_gen_test.zig`, `drawops_gen_test.zig`, and
  `databasecases_gen_test.zig` are generated readers for the shared
  conformance tables. Like `zizek_gen.zig`, they are not edited by hand.
  `shell.zig` imports them by module name, and only the test build in
  `build.zig` provides those modules: Zig loads every file named in an
  `@import` path even from test-only code, but resolves a module name only
  when it is used. So the public module never loads them, and they are left
  out of the `.paths` in `build.zig.zon`.
- `examples/` holds the runnable native and upstream-port examples;
  `examples/ledger.zig` is the end-to-end acceptance example.

## Verify

From the package root:

```bash
zig build test
```

This runs the package's own tests, the shared shell and database conformance
tables, and every example's `test` block. The test build embeds those shared
tables, which live outside this package, so the suite runs only in the Zizek
source tree; a dependent build, or a checkout of the package on its own, uses
the public module, which never resolves them.

The native tests cover discovery, shrinking, replay, assumptions, punning,
spans, pools, scheduling, the example database, and the shared ledger failure.
The emitted core is additionally compared with 104,540 Rust-reference vectors
across 196 kinds.

## Memory

Every function in `zizek_gen.zig` returns an owned slice and frees nothing.
They are pure, so a caller keeping a result must outlive the call and one
discarding it has no hook to free on; `shell.zig` follows suit. Memory is
reclaimed when the process exits, or when a caller installs an arena and
resets it between runs. `zizek.setAllocator` sets both `shell.allocator` and
`core.allocator`, so the shell, its state machines, and the generated core
always share one allocator; the default is `std.heap.smp_allocator`.

That makes the allocator load-bearing: with one allocation per page, 20,000
examples drawing a list and some text measured 5.4 GB and 26 seconds, against
41 MB and 0.17 seconds when packed. `generators.zig` carries a test that runs
5,000 examples and fails if resident memory passes 192 MB. It runs on Linux
only, where `maxrss` is comparable. It is not a performance target; it is the
gap between packing allocations and spending a page on each, which for that
workload is an order of magnitude. The regression it guards against reached
5.4 GB in a real run and surfaced only as an out-of-memory kill elsewhere,
because nothing was watching memory.

## Example database layout

`DirectoryDatabase` stores the **raw choice stream**, not the base64 blob, in
`<root>/<key digest>/<stream digest>`, with both digests the sixteen-hex-digit
FNV-1a hash `ir/keys.zir` already computes for keyed draws
(`zizek.databaseDigest`). A `.name` file beside the entries records the
property's name for a human; anything that is not a sixteen-hex-digit name is
ignored. Writes are atomic, and an emptied key directory is removed with its
`.name`. That is what makes the directory portable: the other packages with a
database write the same layout, so a counterexample found by one replays in
the others.

Stored entries replay shortest first, before generation. An entry that no
longer parses is deleted along with ones that no longer reproduce; a
reproducing entry is shrunk again, and the shrunk stream replaces it.

## Upstream example ports

The package carries runnable ports of the examples used to compare Zizek with
Hypothesis and Hegel:

- [`examples/hypothesis_quickstart.zig`](examples/hypothesis_quickstart.zig)
  ports Hypothesis's introductory bounded-integer property. It shrinks
  `value >= 50` to exactly `50` and replays the portable blob.
- [`examples/min_stack.zig`](examples/min_stack.zig) ports Hegel's
  deliberately broken minimum stack. It draws unbounded integers and shrinks
  the duplicate-minimum bug to `push(0), push(0), pop`. Finding the two equal
  integers exercises generation-phase span mutation; structural shrinking
  then removes every unrelated operation.
- [`examples/stack.zig`](examples/stack.zig) ports Hegel's passing stack
  model, with a rule whose precondition may reject an operation without
  rejecting the whole example.
- [`examples/die_hard.zig`](examples/die_hard.zig) ports Hegel's water-jug
  state machine and exercises generation-phase span mutation. It discovers the
  classic six-step solution within 2,000 examples and pins the same portable
  blob as the Go, Ruby, and Rust ports; it also replays the older uncompressed
  Zizek blob and a zlib-framed blob for the same solution.
- [`examples/multi.zig`](examples/multi.zig) ports Hegel's two-assertion
  example. It verifies that shrinking preserves the failure origin selected
  during discovery instead of switching to the other assertion.
- [`examples/ledger.zig`](examples/ledger.zig) is the Hegel ledger port: two
  account creations followed by the buggy transfer of `1`, with the same
  portable three-step blob used by the Go, Python, Ruby, and Rust packages.

Run them from the package root:

```bash
zig build run-hypothesis-quickstart
zig build run-min-stack
zig build run-stack
zig build run-die-hard
zig build run-multi
zig build && ./zig-out/bin/zizek-ledger
```
