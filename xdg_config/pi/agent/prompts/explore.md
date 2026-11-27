---
description: Explore candidate options and compare trade-offs without modifying code
argument-hint: "[problem or requirement]"
---

Explore candidate options for: ${@:-the problem or requirement under discussion}

Strategy:
- Derive the constraints supported by the code and its contracts.
- Identify viable options that meet those constraints, including the smallest change that works. If only one option fits, explain why instead of inventing a second.

Output:
- Lead with the constraints, then compare the options side by side on how they differ, where each could fail, and which assumptions remain unverified.

Boundary: Leave the choice to the user; do not recommend an option, modify files, or implement it.
