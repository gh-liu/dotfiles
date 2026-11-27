---
name: code-writing
description: Implement, modify, or refactor production code with minimal scope while encoding invariants in types, schemas, or assertions. Use when turning an agreed design, clear requirement, or confirmed bug diagnosis into code changes, rather than when clarifying ambiguous goals, reading unfamiliar code, diagnosing an unknown root cause, or writing tests alone.
---

# Code writing

Change only what the goal and constraints require. Confirm that the requirement, design, or root cause is settled first—stop to clarify or diagnose if not. Before editing, inspect surrounding implementations, callers, and error handling so new code follows established project patterns.

## Keep the diff minimal and local

- Solve the target problem without bundling unrelated cleanups, renames, or style churn. Preserve existing and parallel edits outside your scope; if they conflict with the change, report the conflict and narrow your footprint.
- When refactoring, keep observable behavior unchanged and separate structural changes from behavior changes.
- Before extracting a helper or module, identify the caller it simplifies, the call sites that share the logic, or the distinct responsibility it will own. Decompose modules around design decisions likely to change (data representations, external formats, policies) rather than chronological execution steps, and favor deep modules—simple interfaces that hide substantial complexity and pull edge cases downward—over shallow pass-through wrappers that leak internal details. If no abstraction earns its interface cost, keep the code inline.

## Encode invariants in code

- Enforce long-term constraints with types, schemas, state transitions, or runtime assertions rather than relying on comments or caller discipline alone.
- Parse and validate untrusted or external data at system boundaries, then pass constrained types inward so internal functions do not repeat defensive checks.
- Design operations so harmless edge cases need no special-case error handling where domain semantics allow, while failing explicitly when a required precondition or external operation fails instead of swallowing errors or silently substituting fallback values that mask broken state.
- Reserve comments for non-obvious rationale and interface invariants that the code and types cannot express; never restate what the code already says.

## Advance in coherent steps

- Break multi-part edits into small steps that keep contracts consistent. Update an interface and the in-repository callers or configurations it affects together, and preserve external contracts and persisted formats unless a breaking migration is agreed.
- If implementation reveals a broken assumption, hidden coupling, or contract conflict that invalidates the agreed approach, stop and surface the finding—keeping partial edits intact rather than silently reverting or stacking workarounds.

## Examples

**Type boundary over comment.** Instead of passing a raw `string` with `// caller must trim and lowercase` across handlers, construct a `NormalizedHandle` at input parsing and accept `NormalizedHandle` in downstream function signatures.

**Fail explicitly at boundaries.** Instead of catching a malformed timeout setting and falling back to zero, reject the invalid value at startup with the offending key and expected format.

References: John Ousterhout, *A Philosophy of Software Design*; Kent Beck, *Tidy First?*; David L. Parnas, *On the Criteria To Be Used in Decomposing Systems into Modules* (CACM 1972).
