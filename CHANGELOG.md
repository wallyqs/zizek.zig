# Changelog

All notable changes to the Zig package are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html) — while the version
is `0.x`, the API may change in any release.

## [0.1.0] - 2026-10-28

First release of the Zig package.

### Added

- Deterministically seeded sequential property exploration.
- Recorded `i64`, boolean, byte, IEEE-754 float, and Unicode text choices.
- Uniform narrow and swarm-biased wide integers, swarm-biased floats, and
  typed integer, float, and text generator builders.
- Variable-length `zizek.lists` whose elements shrink by deletion, plus
  `zizek.sets` and `zizek.uniqueLists` for distinct elements.
- Per-choice shrinking plus element-span and rule-span deletion.
- Portable failure blobs with exact replay, choice punning, forced-position
  accounting, and overrun detection, with punned draws counted and reported on
  the failure.
- Coverage assertions and health checks.
- State machines with initial and post-rule invariants, rejected-rule
  handling, notes, and a default budget of 50 successful steps (rejected rules
  spend an attempt, not a step), plus reusable and consumed generic pools.
- Assumption-based rejection with a configurable rejection limit.
- Runnable examples, including a ledger acceptance example and ports of
  Hypothesis's quickstart and Hegel's stack, minimum-stack, multiple-origin,
  and Die Hard examples.

### Notes

- Targets Zig 0.16, and also builds with Zig 0.17.

[0.1.0]: https://github.com/wallyqs/zizek.zig/releases/tag/v0.1.0
