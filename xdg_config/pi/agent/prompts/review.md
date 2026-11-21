---
description: Review changes via ablation analysis to verify necessity, causal impact, and simpler alternatives
argument-hint: "[target or focus, e.g. staged, HEAD~1..HEAD, path, or PR]"
---

Review the target changes using an ablation-study approach. Treat the full change set as the baseline and evaluate what actually changes when each substantive factor is removed, disabled, or replaced.

Target or focus (if omitted or only a focus is given, default target is uncommitted changes, or `HEAD` if the working tree is clean): ${@:-default target}

1. **Inspect scope & baseline**: Determine the exact diff/target, taking acceptance criteria, non-goals, constraints, and invariants from the diff, project docs/ADRs, and explicit user agreements. Verify baseline adequacy strictly from code, callers/entry points, and test evidence rather than prior implementation claims—checking for omissions (missed symmetrical paths, unhandled edge cases, or broken callers outside the diff). If the target or intent is ambiguous, ask clarifying questions instead of guessing.
2. **Decompose into factors**: Break the diff into substantive change units (branches, guards, state/cache/concurrency logic, abstractions, config/parameters, fallbacks, optimizations). Skip purely mechanical formatting or renames unless they hide behavioral changes. For large diffs, prioritize high-risk or high-complexity factors.
3. **Ablate each factor** (holding the rest of the baseline fixed):
   - **Intervention**: Ask what happens if the factor is removed or disabled. If removal breaks compilation or core contracts (a required component), substitute the simplest mechanism with the same interface.
   - **Discriminating inputs & controls**: Identify the concrete inputs/states where behavior, invariants, or performance should change under ablation—and control cases that should stay unchanged.
   - **Compensating factors**: Check whether pairs of changes mask each other's bugs, duplicate checks, or rely on hidden coupling (compare intervening on each separately vs. together against the baseline).
   - **Evidence check**: Inspect existing tests (and run read-only baseline checks/tests when helpful) to assess whether any test distinguishes the baseline from the ablated variant. Mark test backing as `verified` when a discriminating test (whose assertions would fail under the ablation) is executed and passes on the baseline, `inferred` when such a discriminating test exists in code but was not executed locally, and `unverified` when no test would fail under the ablation.
4. **Report findings**:
   - **Verdict & scope**: Reviewed target, overall recommendation, and any unverified assumptions.
   - **Ablation summary**: For each substantive factor, report `file:line`, intervention (`remove` / `disable` / `substitute`), predicted effect & discriminating input, evidence status (`verified` / `inferred` / `unverified`), and disposition (`keep` / `remove` / `simplify` / `add test` / `fix`).
   - **Prioritized issues**: Group concrete findings by severity—defects/regressions (including omissions), unnecessary or redundant changes, over-engineered mechanisms with simpler substitutes, hidden coupling/compensating behavior, and missing discriminating tests. Provide minimal counterexamples or concrete test cases where relevant.
5. **Boundaries**: Review only; do not modify files, leave changes in the working tree, or perform destructive git/system actions. Perform ablations via static counterfactual analysis plus read-only baseline checks/tests (do not edit files to run mutated variants unless explicitly asked), and clearly separate observed facts from static inferences.
