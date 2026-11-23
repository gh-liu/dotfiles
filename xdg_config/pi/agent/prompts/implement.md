---
description: Implement the agreed approach or review revisions with targeted tests and verifiable evidence
argument-hint: "[chosen option, review items to address, scope, or constraints]"
---

Implement the agreed approach or actionable review findings (`fix`, `remove`, `simplify`, and paired `add test` / `unverified` items, including omissions) from the current discussion, incorporating any input below.

Chosen option, review items, scope, or extra constraints: ${@:-none}

1. **Check readiness**: Confirm the chosen approach (or review findings to address), acceptance criteria, non-goals, constraints, and invariants are clear—consulting active ADRs when touching architectural conventions. When invoked after a review without narrowing scope, clear undisputed defects (`fix`) and paired test gaps may proceed, but stop and ask before modifying files if an option choice, material constraint, or subjective review trade-off (e.g., opinionated `simplify` or `remove`) is still unresolved.
2. **Implement minimally & cleanly**: Keep changes focused, production-quality, reviewable, and rollback-safe. When addressing review findings, apply agreed `fix`, `remove`, and `simplify` items without widening scope. Follow existing project conventions, preserve unrelated or parallel changes in the working tree, and avoid speculative abstractions or unrelated refactors. If implementation reveals an invalidated assumption that would alter the agreed approach, scope, or invariants, stop and confirm instead of working around it silently—reporting any files already modified and leaving them intact rather than reverting silently.
3. **Add discriminating verification**: For bug fixes or review counterexamples, prefer reproducing the failure with a regression test (or using any failing regression test already in the working tree) before verifying the fix. Cover paired `add test` / `unverified` gaps, and verify acceptance criteria from realistic user entry points as well as invariants and key edge cases—preferring tests that would fail if a substantive change were removed or broken. Run the relevant build, lint, and test checks (or equivalent concrete checks when no test suite applies), distinguishing pre-existing unrelated failures from regressions.
4. **Report for review**: Summarize changed files and the reason for each substantive change, list the exact verification commands and observed results, and flag any unverified assumptions, pre-existing failures, skipped checks, or remaining risks.
5. **Boundaries**: Do not commit, push, or perform destructive git/system actions unless explicitly requested. Clearly separate observed verification results from static inferences.
