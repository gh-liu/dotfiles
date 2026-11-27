---
description: Isolate the root cause of a bug or failure without modifying code
argument-hint: "[bug, error, or target]"
---

Diagnose: ${@:-the bug, failing check, or unexpected behavior in the current session}

Strategy:
- Use the smallest read-only check that distinguishes the remaining explanations.

Output:
- Lead with the cause and the evidence that distinguishes it from the alternatives.
- If the evidence is inconclusive, report what remains possible and the next check that would separate those possibilities.

Boundary: Read-only; do not modify files or implement a fix.
