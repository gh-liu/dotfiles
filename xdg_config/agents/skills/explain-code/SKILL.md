---
name: explain-code
description: Explains how code behaves or what a change does at the level the reader needs. Use for code walkthroughs, system behavior questions, and explanations of diffs, commits, or fixes. A request only to trace a value, find callers, or review for defects does not need a walkthrough.
---

# Explain code

Lead with the behavior, not the implementation detail. After the first sentence, the reader should be able to say what the code does or what now behaves differently.

## Choose the level

- For a behavior question, use the level the question asks about. Explain sign-in in terms of sessions, redirects, and tokens. Explain a cookie parser in terms of headers, fields, and accepted values.
- For a change, use the level of the behavior it changes. Describe orchestration in jobs, queues, and handoffs; describe memory changes in buffers, owners, and lifetimes. Use function and component names when they identify an actor the reader needs to follow, not as a substitute for what it does.
- Go one level deeper when the mechanism explains why the behavior follows. Put that detail after the behavior, and omit further layers unless the question depends on them.

## Show the meaningful difference

- For existing behavior, pick one input or event and explain what happens to it. Include alternate paths only when they change the answer.
- For a change, compare the same case before and after. Name the consequence for a user, caller, or downstream component. If the previous behavior was simply absent, explain the new behavior without inventing a before path.
- If exact text matters, show the relevant signature, setting, or diff. If order or ownership matters more, use a short call tree or pseudocode when it makes the contrast easier to see. Keep unchanged context only where it explains the difference.

## Examples

**Lead with orchestration, not a field rename.** Child jobs now inherit the export's deadline, so page renders stop when the export times out. Previously the worker ignored the deadline because it arrived under the wrong field name.

**Name ownership, not just the symptom.** The renderer now frees the tab's frame buffer after the last callback reads it. Previously, closing the tab freed the buffer while a callback could still use it.
