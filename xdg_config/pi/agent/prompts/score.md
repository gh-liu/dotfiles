---
description: Compare candidate options with a decision model and provide a scored recommendation
argument-hint: "[extra requirements, constraints, or weights]"
---

Compare the candidate options from the current discussion. Additional requirements: ${@:-none}.

1. If the candidate options or hard constraints are unclear, ask clarifying questions instead of inventing options.
2. Check hard constraints first: eliminate options that clearly fail them (do not score them), and mark uncertain ones as "unverified".
3. Use `codemode` to score the remaining options with an available decision model (preferring `classifier` models such as Jev) on the same criteria and scale. Confirm before sending sensitive material externally or incurring notable cost.
4. In the recommendation, include the model ID, criteria, scale definitions, weights (equal by default), each option's scores and confidence, and the supporting source text or data. Mark unsupported claims as "unverified".
5. If model scores cannot be obtained, explain why and do not fabricate scores. Provide a recommendation only; do not implement any option.
