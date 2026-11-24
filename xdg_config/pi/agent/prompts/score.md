---
description: Score and compare candidate options with a decision model
argument-hint: "[options, or extra weights/criteria]"
---

Score and compare: ${@:-the candidate options under discussion}

1. Drop options that violate hard constraints or non-goals; if fewer than two remain, report that and stop.
2. Fix independent, single-factor criteria and weights before scoring; describe every option in the same neutral format.
3. Score each option with a decision model. If none is available or any call fails, report it, leave missing scores blank, and skip totals and recommendation.
4. Otherwise tabulate weighted totals with the decision model name, recommend one option, and state what would change the ranking.

Recommend only: do not modify files or implement an option.
