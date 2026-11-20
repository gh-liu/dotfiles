---
description: Review changes via ablation analysis to verify necessity, causal impact, and simpler alternatives
argument-hint: "[target or focus, e.g. staged, HEAD~1..HEAD, path, or PR]"
---

Review ${@:-the current uncommitted changes (or the latest commit if the working tree is clean)} using an ablation-study approach. Treat the full change set as the baseline and test what actually changes when each substantive factor is removed, disabled, or replaced.

1. **Inspect scope & baseline**: Determine the exact diff/target and its stated goal, invariants, and constraints. If the target or intent is ambiguous, ask clarifying questions instead of guessing.
2. **Decompose into factors**: Break the diff into substantive change units (branches, guards, state/cache/concurrency logic, abstractions, config/parameters, fallbacks, optimizations). Skip purely mechanical formatting or renames unless they hide behavioral changes.
3. **Ablate each factor** (holding the rest of the baseline fixed):
   - **Intervention**: Ask what happens if the factor is removed or disabled. If removal breaks compilation or core contracts (a required component), substitute the simplest mechanism with the same interface.
   - **Discriminating inputs & controls**: Identify the concrete inputs/states where behavior, invariants, or performance should change under ablation—and control cases that should stay unchanged.
   - **Compensating factors**: Check whether pairs of changes mask each other's bugs, duplicate checks, or rely on hidden coupling (compare removing each separately vs. together).
   - **Evidence check**: Check whether existing tests actually fail under the ablation (distinguishing baseline from variant). Flag claims with no discriminating test as `unverified`.
4. **Report findings**:
   - **Verdict & scope**: Reviewed target, overall recommendation, and any unverified assumptions.
   - **Ablation summary**: For each substantive factor, report `file:line`, intervention (`remove` / `disable` / `substitute`), predicted effect & discriminating input, evidence status (`verified` by test/command vs. `inferred`), and disposition (`keep` / `remove` / `simplify` / `add test` / `fix`).
   - **Prioritized issues**: Group concrete findings by severity—defects/regressions, unnecessary or redundant changes, over-engineered mechanisms with simpler substitutes, hidden coupling/compensating behavior, and missing discriminating tests. Provide minimal counterexamples or concrete test cases where relevant.
5. **Boundaries**: Review only; do not modify files or leave changes in the working tree. You may run read-only checks/tests to verify claims, and clearly separate observed facts from static inferences.
