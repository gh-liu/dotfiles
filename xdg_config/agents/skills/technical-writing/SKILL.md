---
name: technical-writing
description: Draft or revise technical prose that readers use to make a decision, follow a procedure, or take over work, such as design notes, runbooks, incident reports, and handoffs. Use when writing decision or operational documents, or when someone explicitly asks to improve wording, clarity, or structure, even for a single sentence.
---

# Technical writing

Before writing, identify who will read the text, what they already know, and what they need to do afterward. Put the judgment or action the reader needs most at the beginning, and add only the background required to understand it. When revising existing text, preserve the original meaning, technical details, and level of certainty. For local or single-sentence edits, preserve the original length and structure instead of expanding unnecessarily.

## Organize by the reader's task

- **Making a decision.** State what needs to be decided and the recommended option first, then present the constraints, evidence, and trade-offs that shape the choice. Note which unverified conditions would change the recommendation.
- **Following a procedure.** State the preconditions first and place real risks before the corresponding step. Write steps in execution order and keep commands copyable. Explain how to verify success and where to investigate on failure.
- **Taking over work.** Lead with current status and scope of impact, followed by completed work, verification results, and remaining tasks. When blocked, state what is needed to unblock.

## Review checklist

- Use concrete subjects and verbs to make clear who did what. Express one main idea per sentence. Break longer text into sections aligned with the reader's questions, and use parallel structure for similar information.
- Use one term consistently for each concept. Preserve exact identifiers, API names, commands, and quotes. Expand abbreviations on first use when readers may not know them.
- Check every claim against evidence, keeping the preconditions, scope, units, and exceptions that affect judgment. Clearly separate what was observed, what is inferred, and what is recommended.

For example, a troubleshooting note might read: "Logs show this response hit the cache. Stale cache invalidation may explain the outdated data. Retry the same request bypassing the cache and compare the two responses." A verification report might read: "The regression test for timeout retries passed. Retry behavior in production still needs verification."

Clarity principles are adapted from ASD Simplified Technical English (ASD-STE100).
