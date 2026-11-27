---
name: code-reading
description: Trace code from a concrete input to an observable result and explain how it behaves or what a change does at the right level. Use when giving code walkthroughs, answering system behavior questions, checking which callers a diff affects, or explaining diffs, commits, or fixes, rather than for single-definition lookups or defect-only reviews.
---

# Code reading

Trace the code before explaining it, then lead with the behavior rather than implementation detail or reading steps. If the question concerns a small, self-contained piece of code or diff, read it in order and check only the surrounding code needed to answer. For unfamiliar behavior or a change spread across several places, use the passes below.

## Map one execution path

Pick one concrete input or event—usually the case asked about or a primary success path—and follow it from entry to observable result. Identify which functions hand work to which others. On this first pass, a tentative label such as "loads the saved order" is enough to move past a helper; open its implementation whenever the answer depends on its exact behavior, side effects, or edge cases, and never present an uninspected helper as verified fact.

## Follow one thread at a time

Choose one function or value that matters to the question. For a function, inspect callers, arguments, return handling, and errors; for a value, trace where it originates, changes, and is consumed—including unchanged callers outside a diff. When direct call sites do not appear, check indirect links such as interface implementations, callbacks, event handlers, or configuration, and note any dispatch path you cannot verify statically. Keep each pass focused, starting another pass only when a different caller, branch, or piece of data could change the explanation.

## Check for gaps

Once you can explain the behavior, verify what your passes may have missed and revise the explanation if you find a discrepancy:

- **With a diff:** Read substantive hunks in order, skipping generated files, lockfiles, or mechanical edits unless relevant. Trace any unaccounted hunk through its callers or consumers.
- **Without a diff:** Check the traced path against a concrete call site or test case for preconditions, state setup, failure branches, or assertions that contradict or complicate your explanation.

## Explain at the right level

After the first sentence, the reader should be able to say what the code does or what now behaves differently. Answer directly rather than narrating your reading passes, point to the few source locations that verify the claim, and flag any product assumption the conclusion depends on.

- **Match the reader's level:** Explain sign-in in sessions, redirects, and tokens, or a cookie parser in headers, fields, and accepted values. For changes, describe orchestration in jobs, queues, and handoffs, or memory in buffers, owners, and lifetimes. Use function or component names to identify an actor to follow, not as a substitute for what it does. Put deeper mechanism details after the behavior, and omit further layers unless the question depends on them.
- **Show the meaningful difference:** For existing behavior, trace one input or event and include alternate paths only when they change the answer. For a change, compare the same case before and after and name the consequence for users, callers, or downstream components (if the behavior was previously absent, do not invent a before path). Show an exact signature, setting, diff, or short call tree when exact text, order, or ownership matters, keeping unchanged context only where it explains the difference.

## Examples

**Lead with orchestration, not a field rename.** Child jobs now inherit the export's deadline, so page renders stop when the export times out. Previously the worker ignored the deadline because it arrived under the wrong field name.

**Name ownership, not just the symptom.** The renderer now frees the tab's frame buffer after the last callback reads it. Previously, closing the tab freed the buffer while a callback could still use it.

Adapted from Sean Goedecke's [How to read code](https://www.seangoedecke.com/how-to-read-code/).
