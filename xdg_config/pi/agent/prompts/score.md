---
description: Compare candidate options with a decision model and provide a scored recommendation
argument-hint: "[extra requirements, constraints, or weights]"
---

Compare the candidate options from the current discussion, incorporating any extra requirements, constraints, or weights below.

Extra requirements, constraints, or weights: ${@:-none}

1. **Clarify candidates**: If the candidate options, hard constraints, or invariants are unclear, ask clarifying questions instead of inventing options.
2. **Filter by hard constraints & invariants**: Eliminate options that clearly violate hard constraints or invariants (such as non-negotiable safety, security, or compatibility bounds; do not score them), and mark uncertain bounds as `unverified` (keep those options in scoring with a caveat). If fewer than two options remain, report the result directly without model scoring.
3. **Score with a decision model**:
   - In `codemode`, discover available `classifier` models via `models.getAvailableOfType("classifier")` (preferring Jev).
   - Before calling `models.classify()`, confirm with the user if the `state` sends sensitive material externally or if call volume incurs notable cost.
   - Define one atomic, plain `type: "score"` question per criterion (avoid compound `and`/`or` criteria and prompt preambles; unless specified, default to `correctness`, `security`, `maintainability`, and `performance`, plus task-specific criteria), with ordered `criteria` levels (lowest first) each written as a concrete, self-contained situation.
   - Score each remaining option independently via `models.classify()` using the same questions and a structured `state` (shared task `context` plus only that candidate `option`'s concrete mechanism, scope, and verified facts—avoiding editorial adjectives or other options' details). Verify `stopReason === "stop"`, normalize each score to `[0, 1]` (`score / (criteria.length - 1)`), and compute weighted totals in code (defaulting to weights ordered `correctness` & `security` > `maintainability` > `performance` unless specified).
4. **Report transparently**: Lead with the recommended option and what would flip the choice (e.g., `unverified` constraints or weight sensitivity). Include `provider/model` ID, criteria, level definitions, weights, each option's raw and normalized per-criterion scores, `confidence`, and weighted total, plus the supporting `state` passed to the model. Mark unsupported claims as `unverified`.
5. **Boundaries**: If no `classifier` model is available or `models.classify()` fails, explain why and do not fabricate scores. Provide a recommendation only; do not modify files or implement any option.
