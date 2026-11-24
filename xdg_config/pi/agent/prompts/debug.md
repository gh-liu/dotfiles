---
description: Isolate the root cause of a bug or failure without modifying code
argument-hint: "[bug, error, or target]"
---

Isolate the root cause of: ${@:-the bug, failing check, or unexpected behavior in the current session}

1. Pin down expected behavior, actual behavior, and trigger from evidence.
2. Distinguish competing hypotheses with the smallest discriminating check; trace the first divergence from expected behavior.
3. Lead with the confirmed root cause (or narrowed hypotheses if blocked), then what was ruled out.

Do not modify files or implement a fix.
