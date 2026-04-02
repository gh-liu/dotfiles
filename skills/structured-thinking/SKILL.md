---
name: structured-thinking
description: Use when the user wants clearer structure, stronger logic, or conclusion-first communication. Best for organizing messy notes, clarifying recommendations, diagnosing problems, or rewriting content into structured proposals, memos, reports, or decision documents.
---

# Structured Thinking

Make the logic clear, defensible, and easy to act on.

## When To Use

Trigger when:

- The user gives scattered notes, partial context, or a weak draft.
- The output must persuade, recommend, explain, or support a decision.
- The user asks for "more structured", "more logical", "more concise", or "conclusion first".

Do not force for: literal transcription, freeform brainstorming, verbatim rewrites that must preserve original order.

## Core Job

1. Find the real question.
2. Answer it in one sentence.
3. Group support into 2–5 parallel buckets.
4. Place evidence under the right bucket.
5. Remove anything that does not help the answer land.

If you cannot state the answer in one sentence, the structure is not ready.

## Workflow

### Step 1 — Route

Read the input, then pick a path:

| Signal | Path |
|---|---|
| Short question, a few sentences | **Lightweight** — answer + reasons + next step |
| Has context but logic is scattered | **SCQA** to find the narrative, then **Pyramid** to present |
| Needs layered argument or multi-point support | **Pyramid** directly |
| Content exists but structure is weak | **Rewrite** — fix order before polishing sentences |

Identify the job type (`recommendation`, `analysis`, `plan`, `explanation`, `rewrite`) and infer audience and language.

### Step 2 — Build

Ask at most one clarifying question, only if missing context would materially change the answer.

1. Distill one governing question.
2. Write the answer in one sentence.
3. Choose one organizing logic:
   - `Why` — reasons, diagnosis, drivers
   - `How` — plan, workstreams, actions
   - `Which` — options, evaluation, recommendation
   - `What` — explanation, synthesis, summary
4. Build sibling buckets. Put evidence under the right bucket.
5. Rewrite headings until they read as claims (see examples below).

If the input is chaotic, do the structure work silently. Only expose SCQA or pyramid labels when they help the user.

### Step 3 — Verify (Quality Gate)

Before finalizing, check:

- The first sentence can stand alone as the answer.
- All sibling points answer the same parent question and do not materially overlap.
- No important category is missing for the decision at hand.
- The structure matches the real ask: `why`, `how`, `which`, or `what`.
- The draft still works if the reader only scans the headings and first sentence.

If any check fails, go back to the governing question and rebuild.

## Rules

1. **Lead with the answer.** Never bury it after setup or background.
2. **Headings are claims, not topics.**
   - Before: `背景`, `Analysis`, `Considerations`
   - After: `延迟主要来自数据库查询`, `Migrating to Redis cuts P99 latency by 40%`
3. **Siblings must be parallel** — same logical type, same abstraction level, one ordering rule.
4. **Evidence lives below the argument**, not beside it.
5. **Compress background aggressively.** Keep `Situation` factual and short.
6. **Use 2–5 buckets.** Fewer is often stronger. Do not force three when two or four is the right number.
7. **Do not invent categories for MECE completeness.** Real logic beats symmetry.
8. **Do not over-structure a short answer** that only needs one paragraph.
9. **Mirror the user's language** unless asked otherwise. For bilingual output, preserve the same argument structure across both languages.
10. **End with a next step, implication, or trade-off** when useful.

## SCQA

Use when the input has context but no clear narrative. SCQA is a thinking tool — expose the labels only when they help the user.

- **Situation** — what is already true or accepted (keep short, factual)
- **Complication** — what changed or creates tension (make concrete)
- **Question** — what must be decided or explained (keep singular, make it point to a real decision)
- **Answer** — the direct answer in one sentence

中文结构：情境 → 冲突 → 问题 → 回答

## Pyramid

Present in three layers:

- **Top**: answer, recommendation, or message
- **Middle**: reasons, options, workstreams (2–5 siblings)
- **Bottom**: evidence, examples, data, implementation detail

Sibling points must answer the same parent question and follow one ordering principle:

| Ordering | Pattern |
|---|---|
| Priority | most important → least |
| Chronology | before → during → after |
| Cause-effect | drivers → impact → implication |
| Problem-solution | issue → fix → result |
| Decision | options → criteria → recommendation |

## Output Shapes

Pick the smallest structure that fits:

| Type | Shape |
|---|---|
| **Recommendation** | recommendation → why it matters → 2–4 reasons → next steps or trade-offs |
| **Analysis** | answer/diagnosis → key drivers → evidence → implication |
| **Plan** | objective → workstreams/phases → sequencing → risks/dependencies |
| **Rewrite** | preserve meaning; improve order before polishing sentences; compress repetition; move background below the point it supports |

## Lightweight Pattern

For short chat replies:

```text
结论 / Answer:
一句话先说清楚。

核心理由 / Why:
1. ...
2. ...

下一步 / Next step:
如有必要，补一句行动建议或 caveat。
```
