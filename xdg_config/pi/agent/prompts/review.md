---
description: Review changes via ablation analysis to verify necessity, causal impact, and simpler alternatives
argument-hint: "[target or focus, e.g. staged, HEAD~1..HEAD, path, or PR]"
---

Review the target changes using an ablation-study approach. Treat the full target as the baseline and evaluate what actually changes when each substantive factor is removed, disabled, replaced, or restored.

Target or focus: ${@:-none}

1. **Resolve target & inspect baseline**:
   - If the input specifies a target (diff, commit range, PR, or file/directory path), review that target (if a committed file or directory path has no uncommitted diff, treat its current contents as the baseline).
   - If the input is omitted or only specifies a focus, infer the target heuristically using the current discussion and git state (`git status`/diff/branch):
     - If the active discussion focus and uncommitted working-tree changes point to different tasks, treat this as ambiguous and stop to ask which target to review.
     - Otherwise, prefer the active target established in the discussion (e.g., changes just implemented or a specific path/PR/range being discussed) when consistent with the working tree (isolating unrelated dirty changes).
     - Otherwise, if there are uncommitted changes (staged, unstaged, or relevant untracked files), review them—flagging and excluding unrelated dirty changes (and confirming first if staged and unstaged changes clearly belong to separate tasks).
     - Otherwise (clean working tree), if on a non-default branch with unmerged commits relative to the default branch (`merge-base..HEAD`), review those branch commits—confirming scope first if the branch is very large or spans multiple unrelated topics.
     - Otherwise (clean working tree on the default branch, or no divergence), fall back to `HEAD`.
   - Take acceptance criteria, non-goals, constraints, and invariants from the target, project docs/ADRs, and explicit user agreements. Verify baseline adequacy strictly from code, callers/entry points, and test evidence rather than prior implementation claims—checking for omissions (missed symmetrical paths, unhandled edge cases, or broken callers outside the diff). If the target or intent remains ambiguous, ask clarifying questions instead of guessing.
2. **Decompose into factors**: Break the diff (or baseline file/module) into substantive units (branches, guards, deletions, state/cache/concurrency logic, abstractions, config/parameters, fallbacks, optimizations). Skip purely mechanical formatting or renames unless they hide behavioral changes. For large targets, prioritize high-risk or high-complexity factors.
3. **Ablate each factor** (holding the rest of the baseline fixed):
   - **Intervention**: Ask what happens if the factor is removed, disabled, restored (when the diff deletes existing logic), or—if required for compilation or core contracts—replaced with the simplest mechanism sharing the same interface.
   - **Discriminating inputs & controls**: Identify the concrete inputs or states where behavior, invariants, or performance changes under that intervention, and control cases that stay unchanged.
   - **Compensating factors**: Check whether pairs of changes mask each other's bugs, duplicate checks, or rely on hidden coupling (comparing intervening on each separately vs. together against the baseline).
   - **Test & runtime evidence**: Inspect existing tests (and run read-only baseline checks/tests when helpful, without leaving dirty artifacts) to see whether passing tests would actually fail under the intervention, whether any relevant baseline check already fails, whether tests exist in code but were not run locally, or whether the behavior has no test coverage.
4. **Report in plain engineering terms**: Keep factor-by-factor ablation as your internal analytical method—write the review for a human engineer in clear, direct prose without per-factor ablation logs, custom taxonomy/enum tags, or workflow jargon:
   - **Overall judgment & scope**: Lead with a clear takeaway (whether the change is ready, needs fixes, or needs tests), what target was reviewed (noting any inferred scope or excluded unrelated changes), what checks/tests were run, and any unverified assumptions.
   - **Actionable findings *(ordered by severity)***: Report only issues that warrant action—defects or regressions, missed symmetrical paths/callers outside the diff, changes that have no real effect when removed, overly complex mechanisms where a simpler alternative achieves the same behavior, hidden coupling where one change masks another, and important behaviors that could break without failing any test. For each finding, cite `file:line`, explain plainly what goes wrong (or why it can be simplified/removed) using a concrete input or scenario, and state the recommended fix, simplification, removal, or test to add. If no issues are found, say so clearly.
   - **What holds up *(briefly)***: In a few plain sentences, note the core parts of the change that proved necessary and backed by tests (mentioning if coverage was only inspected statically), without dumping an item-by-item table of healthy code.
5. **Boundaries**: Review only; do not modify files, leave changes in the working tree, or perform destructive git/system actions. Perform ablations via static counterfactual analysis plus read-only baseline checks/tests (do not edit files to run mutated variants unless explicitly asked), and clearly separate observed facts from static inferences.
