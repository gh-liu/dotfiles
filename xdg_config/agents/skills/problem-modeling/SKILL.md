---
name: problem-modeling
description: >
  Model ambiguous software engineering problems before implementation. Use when requirements are unclear, a user proposes a solution without defining the problem, scope is uncertain, or acceptance criteria are missing. Combines Problem Frames, Shape Up, Working Backwards, critical clarification, and Specification by Example.

---

# Problem Modeling

## Mission

Transform an ambiguous request into a bounded,
testable problem specification.

Do not start implementation before understanding:
- Why the problem matters
- What exists today
- What behavior must change
- What cannot change
- What constitutes success or failure

Do not assume the user's proposed solution is the
actual problem.

## Operating Principles

1. Separate observations, assumptions, requirements,
   and proposed solutions.
2. Inspect available code and documents before asking.
3. Ask only questions whose answers materially affect
   implementation and cannot be resolved from evidence.
4. Prefer concrete scenarios over abstract questions.
5. Propose reasonable defaults with explicit rationale.
6. Never silently turn assumptions into confirmed facts.
7. Stop exploring when remaining uncertainty no longer
   materially affects the next decision.
8. Do not implement code during this skill unless
   explicitly instructed to proceed.

## Workflow

### Step 1 — Frame the Problem

Inspired by Working Backwards and Design Docs.

Identify:
- Current situation
- Observable pain
- Affected users or systems
- Why now
- Consequences of doing nothing
- Desired outcome
- Observable success signals

Distinguish:
- Problem: what is wrong or missing
- Requirement: what must hold
- Solution: how we might change the system

If the request is solution-shaped, reconstruct the
underlying problem without dismissing the proposal.

### Step 2 — Model the World

Inspired by Michael Jackson's Problem Frames.

Identify:
- Relevant environment domains
- Existing contracts and invariants
- External actors and systems
- Machine boundary: what we can change
- Shared phenomena and interfaces
- Who controls each relevant event or state
- Who can observe each outcome

Represent important interactions as:

Domain A --[event/state]--> Machine
Machine --[event/state]--> Domain B

Distinguish external facts from assumed constraints.
Do not confuse current implementation with immutable
reality.

### Step 3 — Shape the Scope

Inspired by Shape Up.

Capture:
- Appetite: acceptable investment or complexity
- In scope
- Out of scope
- No-gos: explicitly forbidden changes
- Rabbit holes: risks that could consume the budget
- Potential cuts if scope exceeds appetite

Appetite is a constraint on the solution, not a
forecast of how long implementation will take.

### Step 4 — Resolve Critical Uncertainty

Inspired by agent-oriented brainstorming.

For each uncertainty:

1. Can the repository or documentation answer it?
   If yes, investigate rather than ask.

2. Would different answers change the architecture,
   behavior, data model, interfaces, or testing?
   If no, choose a documented default.

3. Is it a blocking decision?
   If yes, ask one concrete question.

Prefer scenario-based questions.

Bad:
"What consistency do you need?"

Better:
"If a write succeeds but the read replica is 2 seconds
behind, should the next read wait, return stale data,
or fail?"

Define anti-goals:
- Outcomes considered failures even when the feature works
- Unacceptable risks
- Regressions that must not occur

### Step 5 — Specify by Example

Inspired by Specification by Example and BDD.

For each important behavior, provide:
- Normal example
- Boundary example
- Counterexample or failure example

Use Given / When / Then when appropriate.

Define:
- Inputs
- Preconditions
- Expected outputs
- Invariants
- Error behavior
- Measurable success criteria

Mark unknown targets as TBD rather than inventing
latency, reliability, or capacity requirements.

### Step 6 — Challenge the Model

Before finalizing, check:

- Are we solving a symptom rather than a cause?
- Did we confuse a preferred technology with a goal?
- Did we ignore an external stakeholder?
- Is a stated constraint actually negotiable?
- Could a simpler solution satisfy the same goal?
- Does each critical requirement have a test?
- Can the proposed solution meet the anti-goals?
- What evidence would invalidate this model?

Revise if necessary.

## Deliverables

Produce two artifacts:

1. problem.md
   - Problem statement
   - Context and evidence
   - World and boundary model
   - Goals and anti-goals
   - Appetite, scope and no-gos
   - Assumptions and open decisions
   - Candidate approaches and trade-offs

2. acceptance.md
   - Scenarios
   - Preconditions
   - Expected behavior
   - Edge cases
   - Invariants
   - Measurable acceptance criteria

Label statements as:
- Confirmed
- Assumed
- Proposed
- Unresolved

## Completion Gate

The skill is complete when:

- The problem is stated without prescribing a solution.
- System boundaries and controllable parts are clear.
- Critical constraints and anti-goals are explicit.
- Blocking uncertainties are resolved or documented.
- Important behaviors have concrete examples.
- A planning or implementation agent can identify
  the next action without guessing critical requirements.

If the gate is not met, report unresolved questions
instead of claiming the specification is complete.

## Handoff

Summarize:
- Problem to solve
- Constraints to preserve
- Decisions made
- Decisions still open
- Acceptance tests
- Recommended next step

Never silently proceed to implementation.
