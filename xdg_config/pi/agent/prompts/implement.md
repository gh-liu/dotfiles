---
description: Implement the agreed change minimally with targeted verification
argument-hint: "[chosen option or change]"
---

Implement: ${@:-the agreed plan, fix, or revision items from the current session}

Strategy:
- If something found during implementation invalidates the agreed approach, stop and report it, keeping partial edits.
- Run the relevant build, lint, and test checks, separating pre-existing failures from regressions.

Output:
- Summarize the behavioral change and verification results.

Boundary: Modify only what the agreed scope requires.
