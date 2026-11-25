---
description: Review changes for correctness, necessity, simpler alternatives, and test gaps
argument-hint: "[changes, git ref, or path]"
---

Review: ${@:-the code changes made in the current session}

1. Check correctness, contract and edge-case safety, hidden coupling, and whether tests would catch regressions.
2. Reason from first principles: identify the underlying contract, invariants, and constraints before accepting assumptions or implementation details.
3. Question necessity: for each substantive change, ask what breaks if it is removed or replaced with a simpler mechanism.
4. Lead with the overall judgment, then list actionable findings by severity with location, a concrete scenario, and a fix.

Read-only: do not modify files or run auto-fixers.
