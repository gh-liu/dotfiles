---
description: Add or strengthen tests at the right layer without changing production code
argument-hint: "[capability, behavior, or path]"
---

Add and run tests for: ${@:-the capability or behavior implemented in the current session}

1. Cover observable behavior not already tested. Use the existing test setup; if it cannot exercise the behavior without extensive mocking or production changes, report the gap instead.
2. Fix a faulty test; if a valid test exposes a production bug, leave it failing and report the defect.
3. Report what the new coverage catches and the results of running it.

Modify only test files and fixtures.
