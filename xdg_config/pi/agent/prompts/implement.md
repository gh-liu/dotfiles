---
description: Implement the agreed approach or review revisions with targeted tests and verifiable evidence
argument-hint: "[chosen option, review items to address, scope, or constraints]"
---

Implement the agreed approach or actionable review findings (defects, missed paths/edge cases, agreed simplifications or removals, and missing test coverage) from the current discussion, incorporating any input below.

Chosen option, review items, scope, or extra constraints: ${@:-none}

1. **Check readiness**: Confirm the chosen approach (or review findings to address), acceptance criteria, non-goals, constraints, and invariants are clear—consulting active ADRs when touching architectural conventions. When invoked after a review without narrowing scope, clear undisputed defects and missing test coverage may proceed, but stop and ask before modifying files if an approach choice, material constraint, or subjective trade-off (such as a debatable simplification or removal) is still unresolved.
2. **Implement minimally & cleanly**: Keep changes focused, production-quality, reviewable, and rollback-safe. Address the agreed scope without widening into unrelated refactors or speculative abstractions, follow existing project conventions, and preserve unrelated or parallel changes in the working tree. If implementation reveals an invalidated assumption that would alter the agreed approach, scope, or invariants, stop and confirm instead of working around it silently—reporting any files already modified and leaving them intact rather than reverting silently.
3. **Add discriminating verification**: For bug fixes or concrete counterexamples, prefer reproducing the failure with a regression test (or using any failing regression test already in the working tree) before verifying the fix. Cover untested behaviors, acceptance criteria from realistic entry points, invariants, and key edge cases with tests that would fail if a substantive change were removed or broken. Run the relevant build, lint, and test checks (or equivalent concrete checks when no test suite applies), distinguishing pre-existing unrelated failures from regressions.
4. **Report in plain engineering terms**: Lead with a clear, human-readable summary of what behavior changed and why (avoiding internal prompt or workflow labels), then list the touched files, exact verification commands with observed results, and any remaining unverified assumptions, pre-existing failures, skipped checks, or risks.
5. **Boundaries**: Do not commit, push, or perform destructive git/system actions unless explicitly requested. Clearly separate observed verification results from static inferences.
