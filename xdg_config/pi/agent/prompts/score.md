---
description: Compare candidate options with a decision model and provide a scored recommendation
argument-hint: "[extra requirements, constraints, or weights]"
---

Compare the candidate options from the current discussion, incorporating any extra requirements, constraints, or weights below.

Extra requirements, constraints, or weights: ${@:-none}

1. **Resolve options, clarify & filter**:
   - When options are not explicitly listed in the input, infer them from the current discussion—preferring the most recent active set of candidate options (e.g., from prior exploration or trade-off discussion), or from a design doc/ADR explicitly referenced in the discussion. If multiple unrelated option sets compete, or if the candidate options, acceptance criteria, non-goals, hard constraints, or invariants remain unclear, ask clarifying questions instead of guessing or inventing options.
   - Eliminate options that clearly violate hard constraints, invariants, active ADRs, or explicit non-goals without scoring them. Keep options with uncertain bounds in scoring as explicit unverified assumptions. If fewer than two options remain, report the result directly without model scoring.
2. **Define criteria & neutral state**:
   - Pick 3–6 task-relevant criteria that genuinely distinguish the remaining options. Keep opposing trade-offs (e.g., stronger automated protection vs. lower maintenance burden) as separate criteria instead of averaging sub-questions inside a broad bucket.
   - Write one plain, atomic `type: "score"` question per criterion on a `0–2` scale (`3` ordered levels, lowest first, higher is better). Describe each level as a concrete, self-contained engineering outcome or risk state rather than naming an option's specific mechanism.
   - Use `type: "bool"` (with concrete `true` and `false` situations) only for unresolved binary risk checks; never convert `bool` probabilities into numeric points.
   - Use one factual `state` schema across options: shared task `context` plus only that `option`'s concrete mechanism, scope, verified facts, and unverified assumptions—without pre-judged pros/cons, editorial labels, or other options' details.
3. **Score with a decision model**:
   - In `codemode`, select an available `classifier` via `models.getAvailableOfType("classifier")`, preferring stable Jev (`jev-latest` over `preview`). Confirm with the user before sending sensitive material externally (including via local proxies to upstream services) or incurring notable cost.
   - Call `models.classify()` once per option bundling all questions, verify `stopReason === "stop"` for every option, and do not rewrite questions after seeing scores to steer the result.
   - Assign each scored criterion a simple weight (defaulting to integer weights `3` = high, `2` = medium, `1` = low when unspecified) and compute `total = sum(weight * score)` out of `max = sum(weight * 2)`, rounded to one decimal place. Treat high-probability `bool` risks (`> 0.7`) as explicit caveats and unsettled ones (`0.3–0.7`) as unverified assumptions.
4. **Summarize in plain engineering terms**: Translate model outputs into clear human takeaways—do not expose classifier schema or API field names (such as `bool`, `confidence`, `state`, or raw probability cutoffs) in the prose or table:
   - **Recommendation & what could change it**: Lead with the recommended option (`total / max`), explain in plain terms why it fits best, and state what shift in priorities or unverified assumption would tip the choice to the runner-up (avoid synthetic weight-ratio formulas).
   - **Comparison table**: Show one row per criterion (with its weight) and a final `total / max` row; in each option's cell, pair `score/2` (one decimal) with a brief plain-language phrase describing the concrete situation matched (noting naturally if an option sits between two outcomes or remains uncertain). Summarize any binary risk caveats or unverified assumptions in plain prose alongside the table rather than as raw flag labels.
   - **Scoring basis**: Briefly note the decision model (`provider/model`) and any options ruled out upfront by hard constraints (and why). Omit raw `questions` and `state` JSON unless the user asks to inspect the payload.
5. **Boundaries**: If no `classifier` model is available or any `models.classify()` call fails, explain why and do not fabricate scores or rank partial results. Provide a recommendation only; do not modify files or implement any option.
