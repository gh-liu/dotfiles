---
description: Isolate the root cause of a bug or failure without modifying code
argument-hint: "[bug, error, or target]"
---

Isolate the root cause of: ${@:-the bug, failing check, or unexpected behavior in the current session}

1. Use the smallest read-only check that distinguishes the remaining explanations.
2. Lead with the cause and the evidence that distinguishes it from the alternatives.
3. If the evidence is inconclusive, report what remains possible and the next check that would separate those possibilities.

Do not modify files or implement a fix.
