---
name: problem-modeling
description: Model ambiguous software engineering problems before committing to a solution. Use when requirements or system boundaries are unclear, a user proposes a solution without defining the underlying problem, scope is uncertain, or acceptance criteria are missing.
---

# Problem modeling

Turn an ambiguous or solution-shaped request into a clear, bounded, and testable problem model before starting implementation. Inspect available code, documentation, and tests before asking questions, and separate confirmed facts, user-reported context, assumptions, and hypotheses. Apply only the modeling depth needed to resolve uncertainty that materially affects the next engineering decision. Do not implement code during explicit problem-modeling work unless the user asks to proceed.

## Frame the problem

- Distinguish the **problem** (what is wrong, missing, or insufficient), the **requirement** (what condition must hold), and the **solution** (how the system might change).
- Identify the current situation, observable pain, affected users or systems, consequences of doing nothing, and observable success signals without inventing motivations or metrics.
- When a request is solution-shaped, reconstruct the underlying problem as a testable hypothesis without dismissing the proposal. For example, `"Move session storage from MySQL to MongoDB"` may reflect a hypothesis that current storage cannot meet write throughput or schema flexibility requirements.

## Model the world and boundaries

- Separate **given** external realities and contracts from the **machine** under our control and the **requirement** the machine must help establish in the environment. Do not treat every existing implementation choice as an immutable external constraint.
- For key interactions across boundaries, identify who initiates or controls an event, who observes it, what information crosses the interface, what guarantees hold, and what outcome the machine must ensure. For example, in `Agent --[heartbeat event]--> Monitoring Service --[status]--> Operator`, heartbeat events are an interface mechanism, whereas accurate failure detection is the requirement. Use a diagram only when it improves clarity.

## Shape the scope

- Define what is in scope, out of scope, unacceptable (**no-gos** and **anti-goals**, such as faster queries that silently lose data or migrations that break existing clients), and existing guarantees that must be preserved.
- Treat any stated **appetite** (investment or complexity budget) as a constraint on the solution rather than a duration forecast. Do not invent an appetite if none was provided.
- Expose **rabbit holes** (unknowns that could consume disproportionate effort), explain their impact, and investigate, contain, simplify, or explicitly defer them rather than treating identification as resolution. When scope exceeds appetite, preserve the core outcome, cut optional work, or propose simpler alternatives with explicit trade-offs.

## Resolve critical uncertainty

- For each unknown, check available evidence first. Ask the user only when available evidence cannot settle the question and different answers would materially change architecture, behavior, interfaces, data semantics, or testing, or when choosing wrong is costly or hard to reverse.
- For low-risk, reversible decisions, propose a reasonable default with its rationale instead of asking unnecessarily. Never silently assume critical requirements.
- Ask one high-impact, concrete scenario question at a time instead of abstract or exhaustive questionnaires. For example, instead of `"What consistency do you need?"`, ask `"A write succeeds, but the read replica is two seconds behind. Should the next read wait, return stale data, or fail?"`

## Specify verifiable outcomes and challenge the model

- Express important requirements through concrete scenarios (selecting relevant normal, boundary, and failure cases, using `Given / When / Then` when helpful), invariants that must continue to hold (such as tenant isolation or idempotent delivery), and measurable criteria instead of vague adjectives (`"fast"`, `"scalable"`). Mark unestablished thresholds or workloads as unresolved rather than inventing numbers.
- Before finishing, challenge the model: check whether it addresses a symptom instead of a cause, confuses a preferred technology with a goal, assumes an unverified root cause, overlooks an anti-goal, or misses a simpler alternative. Stop modeling when remaining unknowns have safe defaults or an explicit validation plan and the next action no longer depends on invented critical requirements.

## Communicate the model

- Respond directly in natural, user-facing language with only the elements that add value: the problem to solve, relevant system boundaries, constraints and anti-goals, decisions made, open assumptions or questions, concrete acceptance scenarios, and the recommended next action.
- Keep internal workflow invisible. Never expose process labels (`Step 1`, `Stopping Criteria`, `Completion Gate`, framework names, or checklist scores) as response headings unless the user explicitly asks about the methodology.
- Create or modify files only when the user requests them, project conventions require documentation, or durable handoff demands it. When persistence is needed, prefer updating an existing document or writing one consolidated file rather than splitting into mandatory `problem.md` or `acceptance.md` files.
