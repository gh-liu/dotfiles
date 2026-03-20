---
name: structured-thinking
description: Use when the user wants clearer structure, stronger logic, or conclusion-first communication: organizing messy notes, clarifying a recommendation, diagnosing a problem, or rewriting content into a proposal, memo, report, email, presentation, executive summary, or decision document in Chinese, English, or bilingual form. Best for requests like "make this more structured", "more logical", "more executive", "summarize the key points", or "rewrite this with clear reasoning".
---

# Structured Thinking

Use this skill when the job is not just to write, but to make the logic clear, defensible, and easy to act on.

## When To Use

Trigger this skill when:

- The user gives scattered notes, partial context, or a weak draft.
- The output must persuade, recommend, explain, or support a decision.
- The user asks for "more structured", "more logical", "more executive", "more concise", or "conclusion first".
- The same argument must work in Chinese, English, or bilingual form.

Do not force this skill for:

- literal transcription
- freeform brainstorming without convergence
- stream-of-consciousness writing
- verbatim rewrites that must preserve the original order

## Core Job

The job is to:

1. find the real question
2. answer it in one sentence
3. group support into parallel buckets
4. place evidence under the right bucket
5. remove anything that does not help the answer land

If you cannot state the answer in one sentence yet, the structure is not ready.

## Execution Protocol

Follow this default protocol unless the user asks for another format:

1. Identify the job type: `recommendation`, `analysis`, `plan`, `explanation`, or `rewrite`.
2. Infer audience, language, and decision horizon.
3. Ask at most one short clarifying question only if missing context would materially change the structure or answer.
4. Distill the material into one governing question.
5. Write the answer in one sentence.
6. Choose one organizing logic:
   - `Why`: reasons, diagnosis, drivers, rationale
   - `How`: plan, workstreams, actions, implementation
   - `Which`: options, evaluation, recommendation
   - `What`: explanation, synthesis, summary
7. Build 2-5 sibling buckets using the same logical type.
8. Put examples, data, caveats, and implementation detail under the right bucket.
9. Rewrite headings until they read as claims.
10. Adapt the surface format to the user's requested form.

If the input is chaotic, do the structure work silently first. Only expose SCQA or pyramid labels when they help the user.

## MUST

- Lead with the answer, recommendation, or diagnosis.
- Find the governing question before polishing wording.
- Keep sibling points at the same level of abstraction.
- Use one visible ordering rule per level.
- Make headings carry meaning on their own.
- Keep evidence below the argument, not beside it.
- Mirror the user's language unless asked otherwise.
- Preserve the same argument structure across both languages for bilingual output.

## SHOULD

- Default the audience to a smart business or technical reader when unspecified.
- Rename vague headings like `Background`, `Overview`, `Considerations`, or `Misc` into claim-style headings.
- Compress background aggressively.
- Keep `Situation` factual and short.
- Use 2-5 buckets; fewer is often stronger than more.
- End with a next step, implication, or trade-off when useful.

## AVOID

- Burying the answer after setup.
- Listing topics instead of making claims.
- Mixing causes, actions, risks, and facts at one level.
- Forcing exactly three points when the logic needs two or four.
- Treating MECE as a requirement to invent artificial categories.
- Over-structuring a short answer that only needs one paragraph.
- Hiding weak reasoning behind polished wording.

## SCQA

Use SCQA when the input has context but no clear narrative.

Definitions:

- `Situation`: what is already true or accepted
- `Complication`: what changed, what creates tension, or what no longer works
- `Question`: what must now be decided, solved, or explained
- `Answer`: the direct answer in one sentence

Rules:

- Keep `Situation` short and factual.
- Make `Complication` concrete.
- Keep `Question` singular when possible.
- Make `Answer` specific enough to serve as the top line.
- If `Situation` gets long, move detail into support.
- If `Question` sounds generic, rewrite it until it points to a real decision or explanation target.

Chinese template:

```text
情境：
目前……，并且……。

冲突：
但现在……，导致……。

问题：
因此，关键问题是：我们应该如何……？

回答：
建议……，因为……
```

English template:

```text
Situation:
Today, ...

Complication:
However, ...

Question:
So the key question is: How should we ...?

Answer:
We should ..., because ...
```

## Pyramid

Use the Minto Pyramid to present:

- top: answer, recommendation, message
- middle: reasons, options, workstreams, pillars
- bottom: evidence, examples, data, implementation detail

Sibling points must:

- answer the same parent question
- use the same type of logic
- stay at the same level of abstraction
- follow one ordering principle
- read like parallel claims, not a bag of topics

Useful ordering rules:

- `Priority`: most important -> least important
- `Chronology`: before -> during -> after
- `Cause-effect`: drivers -> impact -> implication
- `Problem-solution`: issue -> fix -> result
- `Decision`: options -> criteria -> recommendation
- `Strategic-to-tactical`: direction -> plan -> execution

## Output Modes

Pick the smallest structure that fits the job.

### Recommendation

Use for proposals and decisions.

Default shape:

1. recommendation
2. why this matters
3. 2-4 reasons
4. next steps or trade-offs

### Analysis

Use for diagnosis and explanation.

Default shape:

1. answer or diagnosis
2. key drivers or causes
3. evidence
4. implication

### Plan

Use for action and execution.

Default shape:

1. objective
2. workstreams or phases
3. sequencing
4. risks or dependencies

### Rewrite

Use when the content exists but the logic is weak.

Default behavior:

- preserve meaning unless the user asks for reframing
- improve order before polishing sentences
- compress repetition
- move background below the point it supports

## Quality Gate

Before finalizing, verify:

- The first sentence can stand alone as the answer.
- All sibling points answer the same parent question.
- Sibling points do not materially overlap.
- No important category is missing for the decision at hand.
- The structure matches the real ask: `why`, `how`, `which`, or `what`.
- The draft still works if the reader only scans the headings and first sentence.

## Lightweight Pattern

For short chat replies, this is usually enough:

```text
结论 / Answer:
一句话先说清楚。

核心理由 / Why:
1. ...
2. ...
3. ...

下一步 / Next step:
如有必要，补一句行动建议或 caveat。
```
