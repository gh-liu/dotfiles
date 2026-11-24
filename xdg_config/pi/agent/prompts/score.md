---
description: Compare candidate options with a decision model and provide a scored recommendation
argument-hint: "[extra requirements, constraints, or weights]"
---

Compare the candidate options from the current discussion, incorporating any extra requirements, constraints, or weights below.

Extra requirements, constraints, or weights: ${@:-none}

1. **Clarify & filter**:
   - If the candidate options, acceptance criteria, non-goals, hard constraints, or invariants are unclear, ask clarifying questions instead of inventing options.
   - Eliminate options that clearly violate hard constraints, invariants, active ADRs, or explicit non-goals without scoring them. Keep options with uncertain bounds in scoring and mark those bounds as `unverified`. If fewer than two options remain, report the result directly without model scoring.
2. **Define criteria & neutral state**:
   - Pick 3–6 task-relevant criteria that genuinely distinguish the remaining options. Keep opposing trade-offs (e.g., stronger automated protection vs. lower maintenance burden) as separate criteria instead of averaging sub-questions inside a broad bucket.
   - Write one plain, atomic `type: "score"` question per criterion on a `0–2` scale (`3` ordered levels, lowest first, higher is better). Describe each level as a concrete, self-contained engineering outcome or risk state rather than naming an option's specific mechanism.
   - Use `type: "bool"` (with concrete `true` and `false` situations) only for unresolved binary risk checks; never convert `bool` probabilities into numeric points.
   - Use one factual `state` schema across options: shared task `context` plus only that `option`'s concrete mechanism, scope, verified facts, and unverified assumptions—without pre-judged pros/cons, editorial labels, or other options' details.
3. **Score with a decision model**:
   - In `codemode`, select an available `classifier` via `models.getAvailableOfType("classifier")`, preferring stable Jev (`jev-latest` over `preview`). Confirm with the user before sending sensitive material externally (including via local proxies to upstream services) or incurring notable cost.
   - Call `models.classify()` once per option bundling all questions, verify `stopReason === "stop"` for every option, and do not rewrite questions after seeing scores to steer the result.
   - Assign each scored criterion a simple weight (defaulting to integer weights `3` = high, `2` = medium, `1` = low when unspecified) and compute `total = sum(weight * score)` out of `max = sum(weight * 2)`, rounded to one decimal place. Treat high-probability risk `bool`s (`> 0.7`) as explicit caveats and unsettled ones (`0.3–0.7`) as `unverified`.
4. **Summarize for human decision-making**:
   - **Recommendation & flip conditions**: Lead with the recommended option (`total / max`), why it wins in plain terms, and what concrete priority change or `unverified` assumption would flip the choice to the runner-up (avoid synthetic weight-ratio formulas).
   - **Comparison table**: Show one row per criterion with its weight; in each option's cell, pair `score/2` (one decimal) with a short phrase stating the matched situation (noting if split between levels or low `confidence`). Include any `bool` risk/uncertainty flags and the `total / max` row.
   - **Audit line**: Note the `provider/model` ID, any options eliminated in Step 1, and `unverified` bounds. Omit raw `questions` and `state` JSON unless the user asks to inspect the payload.
5. **Boundaries**: If no `classifier` model is available or any `models.classify()` call fails, explain why and do not fabricate scores or rank partial results. Provide a recommendation only; do not modify files or implement any option.
