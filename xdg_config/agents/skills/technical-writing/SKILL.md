---
name: technical-writing
description: Produce or revise technical prose that readers use to make a decision, follow a procedure, or take over work, such as decision summaries, runbooks, incident reports, and handoffs. Use when drafting or revising structured technical documents, or when asked to improve wording, clarity, or structure, rather than for commit messages, ADRs, or diagrams.
---

# Technical writing

Before writing, identify who will read the text, what they already know, and what they need to do afterward. Put the judgment or action the reader needs most at the beginning, and add only the background required to understand it. When revising existing text, keep the document's language, original meaning, technical details, and level of certainty. For local or single-sentence edits, preserve the original length and structure instead of expanding unnecessarily.

## Organize by the reader's task

- **Making a decision.** State what needs to be decided and the recommended option first (or summarize the options neutrally if no recommendation is requested), then present the constraints, evidence, and trade-offs that shape the choice. Note which unverified conditions would change the recommendation.
- **Following a procedure.** State the preconditions first and place real risks before the corresponding step. Write steps in execution order and keep commands copyable. Explain how to verify success, how to roll back or recover state-changing steps, and where to investigate on failure.
- **Taking over work.** Lead with current status and scope of impact, followed by completed work, verification results, and remaining tasks. When blocked, state what is needed to unblock.

## Check clarity and accuracy

- Use concrete subjects and verbs, keeping subject and verb close together instead of wedging long qualifying clauses between actor and action. Express one main idea per sentence, placing familiar context or the shared topic at the start (old before new) and the key new point at the end (stress position). Break longer text into mutually exclusive sections aligned with the reader's questions, and use parallel structure for similar information.
- Use one term consistently for each concept. Preserve exact identifiers, API names, commands, and quotes. Expand abbreviations on first use when readers may not know them.
- Check every claim against available evidence, keeping the preconditions, scope, units, and exceptions that affect judgment. When revising standalone text without evidence, do not invent facts or drop uncertainty qualifiers; flag unsupported or ambiguous claims instead. Clearly separate what was observed, what is inferred, and what is recommended.

## Examples

**Troubleshooting.** "Logs show this response hit the cache. Stale cache invalidation may explain the outdated data. Retry the same request bypassing the cache and compare the two responses."

**Verification.** "The regression test for timeout retries passed. Retry behavior in production still needs verification."

References: ASD Simplified Technical English (ASD-STE100); Joseph M. Williams, *Style: Lessons in Clarity and Grace*; George D. Gopen and Judith A. Swan, *The Science of Scientific Writing* (American Scientist 1990); Barbara Minto, *The Pyramid Principle*.
