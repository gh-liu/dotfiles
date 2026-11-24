---
name: write-code
description: Implement, modify, or refactor production code with minimal scope while encoding invariants in types, schemas, or assertions. Use when turning an agreed design, clear requirement, or confirmed bug diagnosis into code changes, rather than when clarifying ambiguous goals, reading unfamiliar code, diagnosing an unknown root cause, or writing tests alone.
---

# Write code

Change only what the goal and constraints require. Inspect surrounding implementations, callers, and error handling before editing so new code follows established project patterns.

## Keep the diff minimal and local

- Solve the target problem without bundling unrelated cleanups, renames, or style churn. Preserve existing and parallel edits outside your scope; if they conflict with the change, report the conflict and narrow your footprint.
- When refactoring, keep observable behavior unchanged and separate structural changes from behavior changes.
- Introduce a new abstraction, wrapper, or file split only when it simplifies current logic, serves concrete existing reuse, or isolates an independent responsibility. Prefer direct inline code over indirection built for hypothetical future needs.

## Encode invariants in code

- Enforce long-term constraints with types, schemas, state transitions, or runtime assertions rather than relying on comments or caller discipline alone.
- Parse and validate untrusted or external data at system boundaries, then pass constrained types inward so internal functions do not repeat defensive checks.
- Fail explicitly when a required precondition or external operation fails instead of swallowing errors or silently substituting fallback values that mask broken state.

## Advance in coherent steps

- Break multi-part edits into small steps that keep contracts consistent. Update an interface and the in-repository callers or configurations it affects together, and preserve external contracts and persisted formats unless a breaking migration is agreed.
- If implementation reveals a broken assumption, hidden coupling, or contract conflict that invalidates the agreed approach, stop and surface the finding—keeping partial edits intact rather than silently reverting or stacking workarounds.

## Examples

**Type boundary over comment.** Instead of passing a raw `string` with `// caller must trim and lowercase` across handlers, construct a `NormalizedHandle` at input parsing and accept `NormalizedHandle` in downstream function signatures.

**Fail explicitly at boundaries.** Instead of catching a malformed timeout setting and falling back to zero, reject the invalid value at startup with the offending key and expected format.
