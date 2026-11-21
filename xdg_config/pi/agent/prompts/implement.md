---
description: Implement the agreed approach or review revisions with targeted tests and verifiable evidence
argument-hint: "[chosen option, review items to address, scope, or constraints]"
---

Implement the agreed approach or actionable review findings (`fix`, `remove`, `simplify`, and paired `add test` items) from the current discussion, incorporating any input below.

Chosen option, review items, scope, or extra constraints: ${@:-none}

1. **Check readiness**: Confirm the chosen approach (or which review findings to address), acceptance criteria, non-goals, constraints, and invariants are clear—consulting active ADRs when touching architectural conventions. If a choice between options, a material constraint, or a disputed review trade-off is still unresolved, stop and ask before modifying files.
2. **Implement minimally & cleanly**: Keep changes focused, production-quality, reviewable, and rollback-safe. When addressing review findings, apply agreed `fix` items and `remove` or `simplify` redundant/over-engineered factors without widening scope. Follow existing project conventions, preserve unrelated or parallel changes in the working tree, and avoid speculative abstractions or unrelated refactors. If implementation reveals an invalidated assumption that would alter the agreed approach, scope, or invariants, stop and confirm instead of working around it silently.
3. **Add discriminating verification**: For bug fixes or review counterexamples, prefer reproducing the failure with a regression test before verifying the fix. Cover paired `add test` / `unverified` gaps, and verify acceptance criteria from realistic user entry points as well as invariants and key edge cases—preferring tests that would fail if a substantive change were removed or broken. Run the relevant build, lint, and test checks.
4. **Report for review**: Summarize changed files and the reason for each substantive change, list the exact verification commands and observed results, and flag any unverified assumptions, skipped checks, or remaining risks.
5. **Boundaries**: Do not commit, push, or perform destructive git/system actions unless explicitly requested. Clearly separate observed verification results from static inferences.
