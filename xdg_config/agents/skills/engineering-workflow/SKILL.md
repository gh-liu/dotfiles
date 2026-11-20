---
name: engineering-workflow
description: Use when an engineering task needs investigation to define success, trace behavior across components, or choose between implementations with material trade-offs. Also use when compatibility or state changes require explicit invariants and verification. Use when consulting an existing Architecture Decision Record (ADR) or documenting a significant architectural choice in a lightweight ADR.
---

# Engineering workflow

Start from the question that currently affects the decision. When investigation changes the goal or scope of impact, revisit the relevant step and update the judgment. Apply the following practices as needed.

## Understand the problem

- Describe success as an observable outcome. Define the problem to solve, out-of-scope requirements, constraints, and invariants that must hold before and after the change.
- When a change touches architectural conventions, consult relevant active Architecture Decision Records (ADRs) first to confirm which constraints apply.
- Trace behavior from the normal entry point across callers, implementations, and configuration, checking against contracts, tests, or logs. For cross-component issues, sketch control or data flow as needed to find the boundary where behavior can be observed and tested independently.
- When multiple causes are plausible, choose the smallest experiment that distinguishes them. Inspect the deployment environment or external dependencies when necessary. Label inferences and their evidence. If ambiguity remains after investigation and would change the approach or outcome, confirm with the user.

## Choose an approach

- Compare viable options against the same acceptance criteria. Follow existing project patterns, prioritizing correctness and security, then maintainability, then performance by default.
- Confirm with the user before committing to an option that involves irreversible trade-offs or changes the agreed scope or constraints.
- Choose the smallest change that satisfies the constraints. When introducing an abstraction or splitting files, state what logic it simplifies, what reuse it serves, or what independent responsibility it isolates.
- When the rationale for a long-lived decision cannot be easily reconstructed from code, tests, or existing docs, record the trade-offs in the project's documentation. For key architectural decisions that are hard to reverse or constrain future work, write a lightweight ADR following project conventions. State the goal, the constraints and evidence shaping the choice, and why the chosen option was preferred over the alternatives actually considered.
- When a decision depends on assumptions that may change, document its applicability boundary and re-evaluation conditions. Distinguish new requirements that invalidate the approach from observable signals that only warrant investigation. If a new decision supersedes an existing ADR, link the two records bidirectionally.

### Lightweight ADR default format

> An architectural decision is essentially: `D = f(G, C, A, E)`
> - `G`: Goals
> - `C`: Constraints
> - `A`: Alternatives
> - `E`: Current Evidence
>
> Preserving the causal rationale behind a design matters more than preserving the conclusion alone.

Prefer the project's existing ADR template. When none exists, use the Markdown structure below, writing the title and body in the project's documentation language.

```markdown
# ADR-<number> <Decision Title>

Status: <Proposed | Accepted | Superseded>

## Context and constraints
<Goals to achieve, constraints shaping the choice, and current evidence>

## Decision and trade-offs
<What was chosen, why, and the trade-offs of the alternatives actually compared>

## Re-evaluation conditions
<Changes that invalidate this approach and signals worth investigating. Include thresholds and observation windows when metrics exist.>
```

## Implement and verify

- Break changes into small, independently verifiable steps. For bug fixes, reproduce the issue reliably with a regression test before verifying the fix. Use a red-green-refactor cycle where appropriate. Lock in long-term behavior with tests and express long-term constraints in code.
- Verify acceptance criteria through the entry point users actually exercise, then check the invariants identified during investigation. For example, when changing a persistence format, verify both writing new data and reading existing data.
- Match verification depth to impact and risk. When critical verification is blocked, state the reason, what the available evidence covers, and what risk remains.

## Deliver

Answer the user's original question first, then summarize the changes and verification results. Add only the trade-offs and limitations that affect review, usage, or the next decision.
