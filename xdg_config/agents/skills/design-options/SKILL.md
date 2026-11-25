---
name: design-options
description: Formulate viable technical approaches from system constraints and compare their trade-offs, failure modes, and assumptions. Use when choosing how to solve a defined engineering problem or weighing competing designs, rather than when clarifying ambiguous requirements, diagnosing an unknown bug, or consulting or recording an Architecture Decision Record.
---

# Design options

Ground technical choices in verified system constraints before comparing candidate mechanisms. Confirm with the user before choosing an option that introduces irreversible trade-offs or changes agreed scope or guarantees.

## Derive hard constraints

- Inspect affected code, interfaces, schemas, tests, and active architectural documentation to identify invariants that must hold.
- Separate fixed constraints—such as external protocols, compatibility guarantees, operational limits, and explicit non-goals—from local conventions that a change can safely revise.

## Shape distinct options

- Include the smallest viable change that satisfies the constraints as a baseline whenever one exists.
- Make additional candidates differ in mechanism, boundary placement, or trade-off rather than surface phrasing. Drop options that violate hard constraints instead of padding the list; if no candidate satisfies every hard constraint, surface the conflicting constraints instead of silently relaxing one.
- For a candidate that introduces an abstraction, identify the current problem it solves and weigh that benefit against the cost of maintaining the extra layer.

## Compare trade-offs and risks

- Evaluate all viable options against the same acceptance criteria. Follow existing project patterns and prioritize correctness and security first, then maintainability, then performance unless requirements state otherwise.
- Compare how each option behaves under failure, partial rollout, or invalid input, how easily it can be reversed, and what migration or operational burden it introduces.
- Surface the unverified assumptions each option depends on. When asked for a recommendation, state the preferred option with the condition or measurement that would flip the choice; when asked only to explore options, present the trade-offs neutrally without recommending one.

## Examples

**Baseline vs. alternative mechanism.** To deduplicate incoming webhooks, Option A adds a unique constraint on `delivery_id` in the existing Postgres table (minimal baseline, bounded by table write rate), while Option B checks a Redis key with a 24-hour TTL before enqueueing (higher throughput, but loses deduplication across Redis eviction unless backed by durable storage).

**Conflicting hard constraints.** When a service requires both zero-downtime schema migration and synchronous strict foreign-key validation on a 200M-row table, report the lock-duration conflict instead of silently dropping a constraint, and present phased backfill trade-offs for the user to decide.
