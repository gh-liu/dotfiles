---
name: engineering-workflow
description: Investigate behavior across components, compare implementation options, and verify changes against explicit invariants. Use when the goal is clear enough to trace behavior, weigh material trade-offs, verify compatibility or state invariants, or consult or write a lightweight Architecture Decision Record (ADR), rather than when requirements or scope still need upfront problem modeling.
---

# Engineering workflow

Start from the question that currently affects the decision. When investigation changes the goal or scope of impact, revisit the relevant step and update the judgment. Apply the following practices as needed.

## Understand the problem

- Confirm observable acceptance criteria, out-of-scope boundaries, constraints, and invariants that must hold before and after the change. If core requirements remain ambiguous after codebase inspection, switch to problem modeling before implementing.
- When a change touches architectural conventions, consult relevant active Architecture Decision Records (ADRs) first to confirm which constraints apply.
- Trace behavior from the normal entry point across callers, implementations, and configuration, checking against contracts, tests, or logs. For cross-component issues, sketch control or data flow as needed to find the boundary where behavior can be observed and tested independently.
- When multiple causes are plausible, choose the smallest experiment that distinguishes them. Inspect the deployment environment or external dependencies when necessary. Label inferences and their evidence. If ambiguity remains after investigation and would change the approach or outcome, confirm with the user.

## Choose an approach

- Compare viable options against the same acceptance criteria. Follow existing project patterns, prioritizing correctness and security, then maintainability, then performance by default.
- Confirm with the user before committing to an option that involves irreversible trade-offs or changes the agreed scope or constraints.
- Choose the smallest change that satisfies the constraints. When introducing an abstraction or splitting files, state what logic it simplifies, what reuse it serves, or what independent responsibility it isolates.
- When the rationale for a long-lived decision cannot be reconstructed from code, tests, or existing docs, record the trade-offs in project documentation. For hard-to-reverse or constraining architectural decisions, follow `references/adr.md` to write or supersede a lightweight ADR.

## Implement and verify

- Break changes into small, independently verifiable steps. For bug fixes, reproduce the issue reliably with a failing regression test before applying the fix. Use a red-green-refactor cycle where appropriate. Lock in long-term behavior with tests, and enforce long-term constraints with types, schemas, or runtime assertions rather than comments alone.
- Verify acceptance criteria through the entry point users actually exercise, then check the invariants identified during investigation. For example, when changing a persistence format, verify both writing new data and reading existing data.
- Match verification depth to impact and risk. When critical verification is blocked, state the reason, what the available evidence covers, and what risk remains.

## Deliver

Answer the user's original question first, then summarize the changes and verification results. Add only the trade-offs and limitations that affect review, usage, or the next decision.
