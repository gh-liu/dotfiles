---
name: design-options
description: Formulate viable technical approaches from system constraints and compare their trade-offs, failure modes, and assumptions. Use when choosing how to solve a defined engineering problem or weighing competing designs, rather than when clarifying ambiguous requirements, diagnosing an unknown bug, or consulting or recording an Architecture Decision Record.
---

# Design options

Ground technical choices in verified system constraints before comparing candidate mechanisms. Skip multi-option comparison when only one approach satisfies the hard constraints or the change is local and easily reversible. Confirm with the user before choosing an option that introduces irreversible trade-offs or changes agreed scope or guarantees.

## Derive hard constraints

- Inspect affected code, interfaces, schemas, tests, and active architectural documentation to identify invariants that must hold.
- Separate fixed constraints—such as external protocols, compatibility guarantees, operational limits, and explicit non-goals—from local conventions that a change can safely revise.

## Shape distinct options

- Include the smallest viable change that satisfies the constraints as a baseline whenever one exists.
- Make additional candidates differ in mechanism, boundary placement, or trade-off rather than surface phrasing. Apply the end-to-end argument when placing boundaries: enforce correctness guarantees at the endpoints that hold the full context, and treat lower-layer checks or caches strictly as performance optimizations rather than substitutes for end-to-end verification. Drop options that violate hard constraints instead of padding the list; if no candidate satisfies every hard constraint, surface the conflicting constraints instead of silently relaxing one.
- For a candidate that introduces an abstraction, identify the current problem it solves and weigh that benefit against the cost of maintaining the extra layer.

## Compare trade-offs and risks

- Evaluate all viable options against the same acceptance criteria and concrete domain scenarios rather than generic "best practices" judged out of context. Follow existing project patterns and prioritize correctness and security first, then maintainability, then performance unless requirements state otherwise.
- Analyze what each option couples together—both static dependencies (shared schemas, libraries, deployment units) and dynamic coupling (synchronous vs. asynchronous communication, atomic vs. eventual consistency, orchestration vs. choreography)—along with failure behavior, partial rollout, reversibility, and operational burden.
- Surface the unverified assumptions each option depends on. When asked for a recommendation, state the preferred option with the condition or measurement that would flip the choice; when asked only to explore options, present the trade-offs neutrally without recommending one.

## Examples

**Webhook deduplication.** Require at most one job per `delivery_id` across concurrent deliveries and retries within 24 hours, even across cache eviction or worker crashes. Drop a non-atomic Redis check or a Redis-only `SET ... NX` TTL lock because races, pre-commit crashes, or eviction violate that guarantee. Compare mechanisms that satisfy the full constraint: Option A uses `INSERT ... ON CONFLICT (delivery_id) DO NOTHING` in Postgres while retaining rows for at least 24 hours (minimal baseline), whereas Option B adds a post-commit Redis lookup in front of the same Postgres constraint to shed duplicate retry storms.

**Conflicting hard constraints.** When a service requires both zero-downtime schema migration and synchronous strict foreign-key validation on a 200M-row table, report the lock-duration conflict instead of silently dropping a constraint, and present phased backfill trade-offs for the user to decide.

References: Neal Ford, Mark Richards, Pramod Sadalage, and Zhamak Dehghani, *Software Architecture: The Hard Parts*; J. H. Saltzer, D. P. Reed, and D. D. Clark, *End-to-End Arguments in System Design* (ACM TOCS 1984).
