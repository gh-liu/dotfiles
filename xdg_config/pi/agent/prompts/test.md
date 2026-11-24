---
description: Add or strengthen tests at the right layer without changing production code
argument-hint: "[capability, behavior, or path]"
---

Add and run tests for: ${@:-the capability or behavior implemented in the current session}

1. Use the cheapest existing test layer that observes the behavior realistically, without adding a framework. If that needs heavy mocking or a production seam, report the testability gap instead.
2. Cover key behaviors, boundaries, and error paths not already tested, asserting observable outcomes.
3. Run the tests and their checks. Fix flawed tests; keep failures that expose production bugs and report them.

Modify only test files and fixtures.
