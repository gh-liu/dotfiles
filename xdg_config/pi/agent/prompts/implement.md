---
description: Implement the agreed approach with targeted tests and verifiable evidence
argument-hint: "[chosen option, scope, or extra constraints]"
---

Implement the agreed approach from the current discussion (chosen option, scope, or extra constraints: ${@:-none}).

1. **Check readiness**: Confirm the chosen approach, target scope, invariants, non-goals, and acceptance criteria are clear. If the choice between options or a material constraint is still unresolved, stop and ask before modifying files.
2. **Implement minimally & cleanly**: Keep changes focused, production-quality, reviewable, and rollback-safe. Follow existing project conventions, preserve unrelated or parallel changes in the working tree, and avoid speculative abstractions or unrelated refactors.
3. **Add discriminating verification**: For bug fixes, prefer reproducing the failure with a regression test before verifying the fix. Verify acceptance criteria from realistic user entry points as well as invariants and key edge cases—preferring tests that would fail if a substantive change were removed or broken. Run the relevant build, lint, and test checks.
4. **Report for review**: Summarize changed files and the reason for each substantive change, list the exact verification commands and observed results, and flag any unverified assumptions, skipped checks, or remaining risks.
5. **Boundaries**: Do not commit, push, or perform destructive git/system actions unless explicitly requested. Clearly separate observed verification results from static inferences.
