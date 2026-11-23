---
description: Compare candidate options with a decision model and provide a scored recommendation
argument-hint: "[extra requirements, constraints, or weights]"
---

Compare the candidate options from the current discussion, incorporating any extra requirements, constraints, or weights below.

Extra requirements, constraints, or weights: ${@:-none}

1. **Clarify candidates**: If the candidate options, acceptance criteria, non-goals, hard constraints, invariants, or relevant active ADRs are unclear, ask clarifying questions instead of inventing options.
2. **Filter by hard constraints, non-goals & invariants**: Eliminate options that clearly violate hard constraints, invariants, active ADRs, or explicit non-goals (do not score them), and mark uncertain bounds as `unverified` (keep those options in scoring with a caveat). If fewer than two options remain, report the result directly without model scoring.
3. **Score with a decision model**:
   - In `codemode`, discover available `classifier` models via `models.getAvailableOfType("classifier")`, preferring stable Jev (e.g., `jev-latest` over `preview`; note the chosen provider/model when multiple endpoints exist).
   - Before calling `models.classify()`, confirm with the user if `state` sends sensitive material externally (treat local proxies/bridges forwarding to upstream services as external) or if call volume incurs notable cost.
   - Select only task-relevant evaluation dimensions (starting from applicable ones in `correctness`, `security`, `maintainability`, `performance`, plus task-specific dimensions). For each dimension, define one or more atomic, concrete, observable `type: "score"` (or `type: "bool"`) questions—avoiding broad umbrella judgments, compound `and`/`or` criteria, and prompt preambles—oriented so higher scores mean better (inverting `1 - probability` in code for risk `bool`s), with ordered `criteria` levels (lowest first) written as concrete, self-contained situations.
   - Score each remaining option independently in one `models.classify()` call per option bundling all questions, using an identical structured `state` schema across options (shared task `context` plus fixed per-`option` fields such as `mechanism`, `scope`, `verified_facts`, `known_risks`, and `unverified_assumptions`—avoiding editorial adjectives or other options' details).
   - Verify `stopReason === "stop"` for every option before ranking. Normalize each `score` to `[0, 1]` (`score / (criteria.length - 1)`; `bool` `probability` is already `[0, 1]`), average sub-questions within a dimension when decomposed, and compute weighted totals in code using normalized weights summing to 1 (unless specified, use default relative weights `correctness: 3`, `security: 3`, `maintainability: 2`, `performance: 1` for applicable dimensions plus explicit weights for task-specific dimensions, and compute an equal-weight sensitivity check).
4. **Report transparently**: Lead with the recommended option and what would flip the choice (e.g., `unverified` bounds, weight sensitivity vs. equal weights, or low-`confidence` `score` / near-`0.5` `bool` answers indicating uncertainty). Include `provider/model` ID, questions, level definitions, normalized weights, each option's raw and normalized per-criterion scores, `confidence` (for `score`; or `probability` for `bool`), weighted and equal-weight totals, and the supporting `state` passed to the model. Mark unsupported claims as `unverified`.
5. **Boundaries**: If no `classifier` model is available or any `models.classify()` call fails, explain why and do not fabricate scores or rank partial results. Provide a recommendation only; do not modify files or implement any option.
