---
name: architecture-decisions
description: Consult, draft, or supersede lightweight Architecture Decision Records (ADRs) for long-lived or constraining architectural choices. Use when checking active ADRs before changing architectural conventions, deciding whether a design choice warrants an ADR, or writing or updating an ADR, rather than when exploring or comparing candidate designs before a decision is settled, or writing general technical prose.
---

# Architecture Decision Records

Use Architecture Decision Records (ADRs) to preserve the constraints, trade-offs, and applicability limits of architectural choices whose rationale cannot be reconstructed from code or tests alone.

## Consult and scope ADRs

- When a change touches architectural boundaries, cross-cutting conventions, storage formats, or external integrations, check active ADRs first to confirm which constraints apply.
- Write an ADR only for decisions that are costly to reverse or constrain future work across components. Leave local implementation choices to code, tests, or inline comments.

## Capture trade-offs and re-evaluation triggers

- State the problem to solve, the hard constraints, and the evidence shaping the decision. Compare only the viable alternatives actually considered and explain why the chosen approach won despite its costs.
- When a decision relies on assumptions about workload, scale, team structure, or external systems, record its applicability boundary and re-evaluation conditions. Distinguish requirement changes that invalidate the decision outright from observable signals that only warrant investigation, including metric thresholds and observation windows when available.
- Edit a `Proposed` ADR in place while the decision is still open. Once an ADR is `Accepted`, do not overwrite its history; when a new decision replaces it, create a new ADR with `Supersedes: ADR-<old>` and update only the old record's status to `Superseded by ADR-<new>`.

## Format the record

Prefer the repository's existing ADR directory, numbering, language, and template. When none exists, use the Markdown structure below in the project's documentation language:

```markdown
# ADR-<number> <Decision Title>

Status: <Proposed | Accepted | Superseded by ADR-number>
Date: <YYYY-MM-DD>
Supersedes: <ADR-number, omit if none>

## Context and constraints
<Problem to solve, constraints shaping the choice, and supporting evidence>

## Decision and trade-offs
<Chosen approach, its accepted costs and consequences, why it won, and trade-offs of the alternatives compared>

## Re-evaluation conditions
<Changes that invalidate this approach, and signals or metric thresholds that trigger review>
```
