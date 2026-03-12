---
name: structured-thinking
description: Structure thinking and communication with SCQA, the Minto Pyramid, and MECE. Use when Codex needs to turn messy notes into a clear argument, analyze a problem, write or rewrite a proposal, memo, report, email, presentation, executive summary, recommendation, or decision document, or explain ideas in Chinese, English, or bilingual form with conclusion-first logic.
---

# Structured Thinking

Use this skill to turn fuzzy input into clear, conclusion-first output.

## Workflow

1. Identify the job.
   - Decide whether the user needs analysis, recommendation, explanation, persuasion, or rewrite.
   - Infer audience and language. Ask one short question only if missing context changes the structure.

2. Draft SCQA.
   - `Situation`: stable facts the audience accepts.
   - `Complication`: change, tension, gap, or risk.
   - `Question`: the governing question created by the complication.
   - `Answer`: the answer in one sentence.

3. Build the pyramid.
   - Lead with the answer.
   - Group support into 2-5 parallel buckets.
   - Use one ordering rule per level: priority, chronology, cause-effect, problem-solution, or strategic-to-tactical.
   - Push evidence and examples below the right bucket.

4. Check MECE.
   - `Mutually Exclusive`: sibling points do not overlap.
   - `Collectively Exhaustive`: the set covers the scope that matters.

5. Adapt the surface form.
   - Memo/report/email: keep conclusion first.
   - Deck/talking points: turn top-level buckets into section or slide titles.
   - Bilingual output: keep the same structure across languages unless asked to localize.

## SCQA

Use SCQA when the user gives scattered context, weak narrative, or no clear point.

Prompts:

- `Situation`: What is already true, known, or agreed?
- `Complication`: What changed, and why is the old state no longer enough?
- `Question`: What must now be decided, solved, or explained?
- `Answer`: What is the direct answer?

Rules:

- Keep `Situation` short and factual.
- Make `Complication` concrete.
- Keep `Question` singular when possible.
- Make `Answer` specific enough to serve as the top line.

Chinese template:

```text
情境（Situation）：
目前……，并且……。

冲突（Complication）：
但现在……，导致……。

问题（Question）：
因此，关键问题是：我们应该如何……？

回答（Answer）：
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

- top: answer, recommendation, or message
- middle: grouped reasons, options, workstreams, or pillars
- bottom: evidence, examples, data, or implementation detail

Sibling points must:

- answer the same parent question
- use the same type of logic
- stay at the same level of abstraction
- follow one visible ordering principle

Build it this way:

1. Write the answer in one sentence.
2. Ask: `Why is this true?` or `How should this be done?`
3. Draft 2-5 supporting buckets.
4. Rename buckets into parallel claims.
5. Add detail only after the structure is stable.

Chinese output skeleton:

```text
结论：
我建议/判断……

核心依据：
1. ……
2. ……
3. ……

支撑细节：
- 依据 1：……
- 依据 2：……
- 依据 3：……
```

English output skeleton:

```text
Recommendation:
We should ...

Why:
1. ...
2. ...
3. ...

Support:
- For point 1: ...
- For point 2: ...
- For point 3: ...
```

## Output Order

Prefer this order unless the user wants another format:

1. `Answer / Recommendation`
2. `Why this matters`
3. `Key point 1..n`
4. `Evidence / examples / next steps`

## Checks

Before finalizing, verify:

- The first sentence can stand alone as the answer.
- All sibling points answer the same parent question.
- Sibling points do not overlap.
- No important category is missing.
- Headings read as claims, not vague topics.
- Evidence sits below the argument, not beside it.

## Avoid

- Burying the answer after setup.
- Mixing facts, causes, actions, and recommendations at one level.
- Forcing exactly three points when the logic needs two or four.
- Building a clean structure around the wrong question.
