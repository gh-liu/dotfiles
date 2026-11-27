---
description: Verify behavior with existing or new tests without changing production code
argument-hint: "[capability, behavior, or path]"
---

Test: ${@:-the capability or behavior implemented in the current session}

Strategy:
- Check whether existing tests already exercise the observable behavior under test; if so, run them instead of adding new ones.
- Add tests only for the behavior under test that is not yet covered, using the existing test setup; if it cannot exercise the behavior without extensive mocking or production changes, report the gap instead.
- Fix a faulty test; if a valid test exposes a production bug, leave it failing and report the defect.

Output:
- Report which parts of the behavior under test existing tests cover, what any new tests catch, and the results of running them.

Boundary: Modify only test files and fixtures for the behavior under test; do not add tests for unrelated behavior.
