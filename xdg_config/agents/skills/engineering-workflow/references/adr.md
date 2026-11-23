# Lightweight Architecture Decision Records (ADRs)

Write an ADR for key architectural decisions that are hard to reverse or constrain future work. State the goal, the constraints and evidence shaping the choice, and why the chosen option was preferred over the alternatives actually considered.

When a decision depends on assumptions that may change, document its applicability boundary and re-evaluation conditions. Distinguish new requirements that invalidate the approach from observable signals that only warrant investigation. If a new decision supersedes an existing ADR, link the two records bidirectionally.

## Default format

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
