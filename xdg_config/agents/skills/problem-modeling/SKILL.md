---
name: problem-modeling
description: >
  Model software engineering problems before committing to solutions. Use when requirements are ambiguous, a user proposes a solution without defining the underlying problem, system boundaries are unclear, scope is uncertain, or acceptance criteria are missing. Combines Problem Frames, Shape Up, Working Backwards, critical clarification, and Specification by Example.

---

# Problem Modeling

## Mission

Transform an ambiguous request into a clear, bounded,
and testable problem model.

The goal is not to produce documentation.
The goal is to reduce uncertainty that materially affects
the next engineering decision.

Before committing to a solution, understand:

- Why the problem matters
- What exists today
- What behavior needs to change
- What parts of the system can be changed
- What constraints must be respected
- What constitutes success or failure

Do not assume the user's proposed solution is the
actual problem.

## Operating Principles

1. **Problem before solution.**
   Distinguish the underlying problem from the proposed
   implementation. Treat proposed solutions as candidates,
   not predetermined answers.

2. **Evidence before assumptions.**
   Inspect available code, documentation, tests, and
   other evidence before drawing conclusions.
   Distinguish confirmed facts, user-reported information,
   assumptions, and hypotheses.

3. **Investigate before asking.**
   Do not ask questions that available evidence can answer.

4. **Ask only decision-changing questions.**
   Ask when different answers would materially affect
   implementation and the answer cannot be reliably
   established from available evidence.

5. **Prefer concrete scenarios.**
   Use observable examples and edge cases rather than
   abstract or overly broad questions.

6. **Use reasoned defaults.**
   For low-risk, reversible decisions, propose a reasonable
   default with its rationale instead of asking unnecessarily.
   Never silently assume critical requirements.

7. **Keep scope bounded.**
   Identify constraints, non-goals, and risks before
   exploring potentially expensive solutions.

8. **Model only as much as necessary.**
   Apply only the steps and techniques needed to resolve
   decision-relevant uncertainty. Do not force every
   framework onto every request.

9. **Prefer verifiable outcomes.**
   Express important requirements as observable behaviors,
   concrete examples, or measurable success criteria.

10. **Do not implement prematurely.**
    During explicit problem-modeling work, do not start
    implementation unless the user asks to proceed.

11. **Keep internal workflow invisible.**
    Use modeling steps, frameworks, and stopping criteria
    as internal guidance, not as a user-facing report.

    Do not expose internal process labels, checklist results,
    or framework terminology unless the user explicitly
    asks about the methodology.

    Communicate findings, decisions, and unresolved questions
    in natural, user-facing language.

---

## Workflow

The following six steps are a default reasoning sequence,
not a mandatory checklist.

Skip or combine steps when they do not add useful
information. Revisit earlier steps when new evidence
changes the understanding of the problem.

### Step 1 — Frame the Problem

Inspired by Working Backwards and engineering Design Docs.

**Core question: Why does this problem need to be solved?**

Identify:

- Current situation
- Observable pain or unmet need
- Affected users or systems
- Why now
- Consequences of doing nothing
- Desired outcome
- Observable success signals

Distinguish:

- **Problem:** What is wrong, missing, or insufficient?
- **Requirement:** What must hold true?
- **Solution:** How might the system be changed?

If the request is solution-shaped, investigate the
underlying problem without dismissing the proposal.

Example:

Request:
"Move session storage from MySQL to MongoDB."

Possible underlying problem:
"The current session storage cannot meet the required
write throughput or data-model flexibility."

This is a hypothesis, not a confirmed fact.

Do not invent the motivation or success metrics.

**Expected result:**
A concise problem statement independent of a
specific implementation.

### Step 2 — Model the World

Inspired by Michael Jackson's Problem Frames.

**Core question: What exists outside the machine,
and what can the machine actually control?**

Identify:

- Relevant environment domains
- The machine being designed or modified
- Existing external contracts and constraints
- Shared phenomena across interfaces
- Who controls relevant events or states
- Who observes relevant events or states
- Required outcomes in the environment

Distinguish:

- **Given:** Established external realities or constraints
  that the machine must accommodate.
- **Machine:** The software under our control.
- **Requirement:** The desired condition or behavior
  that the machine must help establish.

"Given" is a practical shorthand for this skill.
Do not treat all existing implementation choices
as immutable external facts.

For important interactions, ask:

1. Who initiates or controls the event?
2. Who can observe the event?
3. What information crosses the boundary?
4. What guarantees or assumptions exist?
5. What outcome must the machine ensure?

Example:

Agent --[heartbeat event]--> Monitoring Service
Monitoring Service --[status]--> Operator

The existence of heartbeat events does not itself
guarantee correct failure detection.

The requirement concerns the observable health state,
not merely the interface mechanism.

**Expected result:**
A clear understanding of the environment,
machine boundary, responsibilities, and interactions.

Use a diagram only when it improves clarity.

### Step 3 — Shape the Scope

Inspired by Basecamp's Shape Up.

**Core question: How much are we willing to invest,
and what must remain outside the solution?**

Identify when relevant:

- **Appetite:** Acceptable investment or complexity budget
- **In scope:** Problems the change must address
- **Out of scope:** Problems deliberately excluded
- **No-gos:** Changes or outcomes that are unacceptable
- **Rabbit holes:** Risks or unknowns that could consume
  disproportionate effort
- **Must-preserve behavior:** Existing guarantees that
  cannot be broken without an explicit decision

Appetite is a constraint on the solution,
not a prediction of implementation duration.

Do not invent an appetite if none has been provided.

For rabbit holes:

- Identify the uncertainty
- Explain its potential impact
- Investigate, contain, simplify, or explicitly defer it

Do not treat identifying a risk as resolving it.

If the proposed scope exceeds the appetite:

1. Preserve the core outcome.
2. Identify optional work.
3. Consider simpler alternatives.
4. Make the trade-offs explicit.

**Expected result:**
A bounded problem with explicit constraints,
non-goals, and material risks.

### Step 4 — Resolve Critical Uncertainty

Inspired by high-signal AI-agent brainstorming.

**Core question: Which unanswered questions
would actually change the next decision?**

For each uncertainty:

1. **Can available evidence answer it?**
   If yes, investigate instead of asking.

2. **Would different answers materially change
   architecture, behavior, interfaces, data semantics,
   or testing?**
   If no, choose a documented reasonable default.

3. **Is choosing incorrectly costly, unsafe,
   or difficult to reverse?**
   If yes, clarify explicitly or propose validation.

4. **Can a focused experiment resolve it?**
   If yes, consider the experiment rather than
   prolonged speculation.

Ask concrete, scenario-based questions.

Bad:
"What consistency do you need?"

Better:
"A write succeeds, but the read replica is two
seconds behind. Should the next read wait,
return stale data, or fail?"

Prefer one high-impact question at a time.
Avoid exhaustive questionnaires.

#### Anti-goals

Identify unacceptable outcomes even if the
main feature technically works.

Examples:

- Queries become faster but data is silently lost.
- Throughput improves but infrastructure cost
  increases beyond the acceptable budget.
- Migration succeeds but existing clients break.
- The feature works normally but cannot recover
  from a routine downstream failure.

Distinguish confirmed anti-goals from
proposed ones requiring validation.

#### Stopping Rule

Stop clarifying when:

- Remaining unknowns do not materially affect
  the next decision.
- Safe and reversible defaults exist.
- Remaining uncertainty has an explicit
  validation or investigation plan.

Do not claim a blocking uncertainty is resolved
when it is not.

**Expected result:**
Resolved decisions, documented assumptions,
and a small number of genuinely important open questions.

### Step 5 — Specify by Example

Inspired by Specification by Example and BDD.

**Core question: What observable behavior proves
that the problem has been solved?**

For important behaviors, use concrete examples.

Prefer:

- A normal scenario
- A boundary scenario
- A negative or failure scenario

The number of examples should match the complexity
of the requirement. Do not force exactly three.

Use Given / When / Then when helpful.

Example:

Given an existing valid session
When the storage implementation is migrated
Then the session remains usable
And the client does not need to log in again

Consider relevant edge cases:

- Empty or invalid input
- Maximum size
- Timeout
- Retry
- Duplicate events
- Concurrent requests
- Partial failure
- Stale data
- Authorization failure
- Recovery after interruption

Select only cases relevant to the problem.

#### Invariants

Identify properties that must continue to hold.

Examples:

- An acknowledged write must not disappear.
- A user cannot access another tenant's data.
- Duplicate delivery must not create duplicate
  business effects.

#### Measurable Outcomes

Prefer observable criteria over vague adjectives.

Weak:
"The query should be fast."

Better:
"Under the agreed workload, query p95 latency
must remain below the agreed threshold."

If the threshold or workload is not established,
mark it as unresolved instead of inventing values.

**Expected result:**
Concrete, testable examples and invariants that
can guide implementation and verification.

### Step 6 — Challenge the Model

**Core question: What might be wrong with
our current understanding of the problem?**

Check:

- Are we solving a symptom rather than a cause?
- Have we confused a preferred technology with a goal?
- Have we assumed a root cause without evidence?
- Have we ignored relevant external stakeholders?
- Are stated constraints genuinely immutable?
- Could a simpler solution achieve the same outcome?
- Are important requirements observable and testable?
- Could the proposed approach violate an anti-goal?
- What evidence would invalidate our assumptions?

Revise the model when necessary.

Do not expand into exhaustive analysis unless
material uncertainty justifies it.

**Expected result:**
A coherent, evidence-aware problem model suitable
for the next engineering decision.

---

## Output Policy

Prefer the smallest output that preserves the
understanding needed for the next step.

### Default: Conversational Output

Respond directly in the conversation.

Include only relevant information, typically:

- Problem statement
- Desired outcome
- Relevant system boundaries
- Constraints and anti-goals
- Critical assumptions or unresolved questions
- Concrete acceptance scenarios
- Recommended next step

Omit sections that add no value.

Do not explain all five methodologies unless
the user requests methodological detail.

### User-Facing Language

Internal instructions are not output templates.

Do not use internal process labels as response headings,
including:

- Stopping Criteria
- Stopping Criteria Assessment
- Step 1 / Step 2
- Workflow Status
- Modeling Phase
- Framework Applied
- Anti-pattern Check

Do not translate these labels into user-facing headings
or substitute equivalent process-oriented labels in
another language.

Do not report internal checklist scores, completion
percentages, or framework execution status.

Instead, communicate actual findings and their
implications in natural language.

Bad:
"Stopping criteria: 4/5 checks passed."

Good:
"The problem and major constraints are clear, but
the consistency requirement during failure recovery
still needs clarification because it affects the design."

Bad:
"Step 4 — Resolve Critical Uncertainty"

Good:
"One important question remains: should the system
return stale data or wait for a fresh result?"

Bad:
"Problem Frames and Shape Up analysis completed."

Good:
"The storage implementation can change, but existing
API contracts and session expiration behavior must
remain compatible."

Use plain, precise language.

Technical terminology is appropriate when it helps
explain the problem, but not merely to demonstrate
that a framework was applied.

When the user explicitly asks about methodology,
framework application, or stopping criteria,
explain them directly.

### Optional: Persistent Documentation

Create or modify files only when:

- The user explicitly requests files.
- Existing project conventions require documentation.
- Durable handoff to another agent or team is needed.
- The model is too large for a practical conversation.

When persistence is needed:

1. Prefer updating an existing relevant document.
2. Otherwise prefer one consolidated document.
3. Split into multiple files only when size,
   ownership, or maintenance justifies it.

Do not require `problem.md` or `acceptance.md`.

File creation is not a completion criterion.

### Handoff

When the modeling work is complete, communicate:

- The problem to solve
- The constraints to preserve
- Decisions already made
- Important unresolved assumptions
- The behavior that will demonstrate success
- The recommended next action

If implementation is the next step, provide
enough information for an implementation agent
to proceed without inventing critical requirements.

Do not silently proceed to implementation
during an explicitly modeling-only request.

---

## Stopping Criteria

Stop modeling when:

1. **The underlying problem is sufficiently understood.**
   The actual problem is distinguishable from
   a proposed solution.

2. **The relevant boundaries and constraints are clear.**
   The machine's responsibilities, external constraints,
   and important trade-offs are understood well enough
   for the next decision.

3. **No unresolved uncertainty blocks the next decision.**
   Remaining unknowns are non-blocking, have safe defaults,
   or have an explicit validation plan.

4. **Important outcomes can be verified.**
   Expected behavior can be checked through concrete
   examples, invariants, or observable success signals.

5. **The next action is clear.**
   The next engineering decision or investigation
   does not depend on invented critical requirements.

These are internal reasoning guidelines,
not a checklist to report to the user.

Evaluate them silently.

Do not announce stopping-criteria assessments,
scores, or other process-oriented results.

Do not force unnecessary analysis to satisfy
every criterion.

If a critical uncertainty remains, explain
its practical impact and ask a focused question
or recommend a targeted investigation.

Stop when further modeling is unlikely to
materially improve the next decision.

---

## Anti-patterns

### 1. Solution Anchoring

Treating the user's proposed technology as
the underlying requirement.

Instead:
Investigate the outcome the technology
is intended to achieve.

### 2. Premature Architecture

Designing components before understanding
the problem and external constraints.

Instead:
Establish required behavior and boundaries first.

### 3. False Certainty

Presenting assumptions or causal hypotheses
as confirmed facts.

Instead:
Distinguish evidence, assumptions, and unknowns.

### 4. Questionnaire Overload

Asking every potentially relevant question.

Instead:
Ask only questions that materially affect
the next decision.

### 5. Documentation Theater

Generating comprehensive documents without
improving problem understanding.

Instead:
Produce the smallest useful output.

### 6. Untestable Requirements

Using vague terms such as fast, scalable,
reliable, or easy without observable meaning.

Instead:
Identify measurable outcomes or concrete scenarios.

### 7. Over-modeling

Applying every framework to a simple request.

Instead:
Use the minimum modeling effort required
to make the next decision responsibly.

---

## Final Principle

Problem modeling is not about eliminating
every uncertainty.

It is about establishing enough understanding
to make the next engineering decision well.

Prefer:

- Problems over premature solutions
- Evidence over unsupported assumptions
- Boundaries over uncontrolled scope
- Concrete examples over vague requirements
- Critical questions over exhaustive questionnaires
- Decision readiness over document completeness

Stop when additional modeling is unlikely
to materially improve the next decision.
