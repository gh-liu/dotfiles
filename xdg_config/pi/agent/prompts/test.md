---
description: Add or strengthen discriminating tests at the right test layer without changing production code
argument-hint: "[target, scope, or custom instructions]"
---

Design, add, and run discriminating tests for the target changes, prioritizing any `unverified` or `add test` gaps from prior review and incorporating any custom instructions below.

Target, scope, or custom instructions (if omitted or no diff target is specified, default target is uncommitted changes, or `HEAD` if the working tree is clean): ${@:-default target}

1. **Identify gaps & choose test layer**: Inspect the target diff, acceptance criteria, constraints, invariants, prior review findings, and custom instructions (if the target or expected behavior is ambiguous, ask clarifying questions instead of guessing). Based on the project's existing test setup and the change's risk boundary, choose the lowest-cost layer (unit, integration, or E2E) where each behavior can be observed realistically without excessive mocking. Do not introduce a new test framework just to force a higher layer.
2. **Write discriminating tests**: Add or update tests following existing project conventions, avoiding duplicate tests for already-verified behavior. Cover discriminating inputs, control/invariant cases, boundary/error conditions, and minimal counterexamples—asserting observable outcomes or state rather than internal implementation details, so each test fails if the substantive behavior is removed or broken.
3. **Verify & diagnose**: Run the relevant test suites (and build/lint checks for touched test files). If a test fails, distinguish a flawed test from a real defect in production code; for real production defects, keep the failing regression test and report reproduction details instead of silently weakening assertions or modifying production code.
4. **Report**: Summarize added/updated test files, the chosen test layer and rationale, what each case discriminates, exact verification commands and observed results, and any gaps that could not be verified locally.
5. **Boundaries**: Modify test files and test fixtures only; do not modify production code, commit, push, or perform destructive git/system actions unless explicitly requested. Preserve unrelated changes in the working tree, and clearly separate observed test results from static inferences.
