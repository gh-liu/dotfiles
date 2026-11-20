---
description: Compare candidate options with a decision model and provide a scored recommendation
argument-hint: "[extra requirements, constraints, or weights]"
---

Compare the candidate options from the current discussion. Additional requirements: ${@:-none}.

1. If the candidate options or hard constraints are unclear, ask clarifying questions instead of inventing options.
2. Check hard constraints first: eliminate options that clearly fail them (do not score them), and mark uncertain constraints as `unverified` (keep those options in scoring with a caveat). If fewer than two options remain, report the result directly without model scoring.
3. Use `codemode` to discover available `classifier` models via `models.getAvailableOfType("classifier")` (preferring Jev). Score each remaining option independently with `models.classify()` using the same criteria, scale, and comparable evidence state, then compute weighted totals in code. Confirm before sending sensitive material externally or incurring notable cost.
4. In the recommendation, include the model ID, criteria, scale definitions, weights (equal by default), each option's per-criterion scores, confidence, and weighted total, plus the supporting source text or data passed to the model. Mark unsupported claims as `unverified`.
5. If no `classifier` model is available or model scores cannot be obtained, explain why and do not fabricate scores. Provide a recommendation only; do not implement any option.
