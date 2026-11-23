---
name: problem-modeling
description: Model ambiguous software engineering problems before committing to a solution. Use when requirements, scope, system boundaries, or acceptance criteria are unclear, or when a user proposes a solution without defining the underlying problem, rather than when the goal is clear enough to investigate and implement directly.
---

# Problem modeling

Turn an ambiguous or solution-shaped request into a clear, bounded, and testable problem model before starting implementation. Inspect available code, documentation, and tests before asking questions. Separate confirmed facts, user-reported context, assumptions, and hypotheses, and never invent unstated motivations, budgets, workloads, or thresholds. Apply only the depth needed to unblock the next engineering decision. Do not modify code until key requirements and acceptance criteria are agreed, or the user explicitly asks to proceed.

## Frame the problem

- Distinguish the problem (what is wrong or missing), the requirement (what condition must hold), and the solution (how the system might change).
- State the current situation, observable pain, affected users or systems, consequences of doing nothing, and observable success signals.
- When a request is solution-shaped, reconstruct the underlying problem as a testable hypothesis without dismissing the proposal. For example, `"Move session storage from MySQL to MongoDB"` may reflect a hypothesis that current storage cannot meet write throughput or schema flexibility needs.

## Model boundaries and interactions

- Separate external realities and contracts from the system under our control and the requirement it must establish. Do not treat every existing implementation choice as an immutable external constraint.
- For key boundary interactions, identify who initiates an event, who observes it, what crosses the interface, and what guarantees hold. For example, in `Agent --[heartbeat event]--> Monitoring Service --[status]--> Operator`, heartbeat events are the interface mechanism, while accurate failure detection is the requirement. Use a diagram only when it improves clarity.

## Shape the scope

- Define what is in scope, what is out of scope, what is unacceptable (anti-goals such as silent data loss or breaking existing clients), and which existing guarantees must hold.
- Treat any stated appetite (time or complexity budget) as a constraint on scope rather than an estimate. When scope exceeds that budget, preserve the core outcome, cut optional work, or propose simpler alternatives with explicit trade-offs.
- Identify high-risk unknowns (rabbit holes) that could consume disproportionate effort. Explain their impact and decide whether to investigate, contain, simplify, or explicitly defer them.

## Resolve critical uncertainty

- Ask the user only when available evidence cannot settle an unknown and choosing wrong would change architecture, interfaces, data semantics, or testing, or be costly to reverse.
- For low-risk, reversible decisions, propose a reasonable default with its rationale instead of asking. Never silently assume critical requirements.
- During clarification, ask one high-impact, concrete scenario question at a time instead of an abstract or exhaustive questionnaire. For example, instead of `"What consistency do you need?"`, ask `"A write succeeds, but the read replica is two seconds behind. Should the next read wait, return stale data, or fail?"`

## Specify verifiable outcomes

- Express key requirements as concrete scenarios covering relevant normal, boundary, and failure cases, using `Given / When / Then` when helpful.
- State the invariants that must hold (such as tenant isolation or idempotent delivery) and use measurable criteria instead of vague adjectives (`"fast"`, `"scalable"`). Mark unestablished thresholds or workloads as unresolved.

## Challenge the model

- Before concluding, check whether the model treats a symptom as a cause, confuses a technology choice with a goal, or assumes an unverified root cause. Verify that it covers key anti-goals and does not miss a simpler alternative.
- Stop modeling once remaining unknowns have safe defaults or an explicit validation plan and the next action no longer depends on unverified critical assumptions.

## Communicate the model

- Once blocking questions are settled, respond in natural, user-facing language with only the elements that help the next decision. Include the relevant subset of: problem statement, system boundaries, constraints and anti-goals, decisions made, acceptance scenarios, remaining non-blocking assumptions, and the recommended next action.
- Keep internal workflow invisible. Never expose process labels (`Step 1`, `Stopping Criteria`, `Completion Gate`, framework names, or checklist scores) as response headings unless the user explicitly asks about the methodology.
- Create or modify files only when the user requests them, project conventions require documentation, or durable handoff demands it. When persistence is needed, prefer updating an existing document or writing one consolidated file rather than splitting into mandatory `problem.md` or `acceptance.md` files.
