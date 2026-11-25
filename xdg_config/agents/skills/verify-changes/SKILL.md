---
name: verify-changes
description: Verify a code or configuration change through the entry point its callers use. Use when adding tests, checking a fix against the original failure, or showing that a change preserves a contract. Measuring a factor's effect alone does not establish correctness.
---

# Verify changes

Prove with independently checkable evidence that a change satisfies its acceptance criteria and preserves existing invariants. Match verification depth to the change's impact and risk.

## Exercise realistic entry points

- Verify behavior through the entry point users or external callers actually exercise instead of testing internal helpers in isolation while leaving wiring unchecked.
- Use the cheapest existing test layer that observes real behavior without adding a new test framework. Avoid heavy mocking that mirrors internal implementation details; if realistic testing requires invasive mocks or a missing production seam, report the testability gap instead.
- For configuration or schema changes, validate through the actual loader, parser, validator, or dry-run command rather than inspecting the file by eye alone.

## Check contracts, regressions, and compatibility

- Assert observable outcomes—return values, state transitions, persisted records, or externally visible effects—across normal, boundary, and error paths.
- For a reproducible bug, run the regression check before and after the fix (or against the unpatched behavior) to confirm it fails on the defect and passes with the fix. When direct reproduction is infeasible, verify the fix under conditions as close to the trigger as possible.
- Check invariants that span states or versions. When changing a persistence format, schema, or wire protocol, verify both writing new data and reading existing data.
- Keep automated tests deterministic and isolated: avoid dependence on wall-clock timing, test execution order, shared mutable state, or live external services unless explicitly verifying an integration.

## Interpret results and bound risk

- Run the project's applicable build, lint, type, and test checks, separating pre-existing failures from new regressions. Fix flawed tests, but never weaken assertions or delete checks to mask a real production defect.
- When missing credentials, dependencies, or environments block critical verification, state why it is blocked, what the executed checks cover, and what specific risk remains unverified.

## Examples

**State compatibility invariant.** After adding an optional `timezone` field to saved schedules, test both saving and loading a schedule with `timezone` set and loading a legacy fixture without `timezone` to confirm backward-compatible fallback.

**Configuration entry-point check.** After editing a routing or lint configuration file, run the tool's real validation or dry-run command against representative inputs instead of relying on syntax highlighting alone.
