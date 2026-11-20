---
description: Add or strengthen discriminating tests at the right test layer without changing production code
---

Design, add, and run tests for the current uncommitted changes (or the latest commit if the working tree is clean), prioritizing any `unverified` or `add test` gaps from prior review.

1. **Identify gaps & choose test layer**: Inspect the target diff, acceptance criteria, invariants, and prior review findings. Based on the project's existing test setup and the change's risk boundary, choose the lowest-cost layer (unit, integration, or E2E) where each behavior can be observed realistically without excessive mocking. Do not introduce a new test framework just to force a higher layer.
2. **Write discriminating tests**: Add or update tests following existing project conventions. Cover acceptance criteria, invariants, boundary/error cases, and minimal counterexamples—ensuring each new test would fail if the corresponding substantive behavior were removed or broken.
3. **Verify & diagnose**: Run the relevant test suites (and build/lint checks for touched test files). If a test fails, distinguish a flawed test from a real defect in production code; report defects with reproduction details instead of silently weakening assertions or modifying production code.
4. **Report**: Summarize added/updated test files, the chosen test layer and rationale, what each case discriminates, exact verification commands and observed results, and any gaps that could not be verified locally.
5. **Boundaries**: Modify test files and test fixtures only; do not modify production code, commit, or push unless explicitly requested. Preserve unrelated changes in the working tree.
