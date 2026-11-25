---
name: read-code
description: Trace code from a concrete input to an observable result. Use when explaining unfamiliar behavior, checking which callers a diff affects, or tracing a value during diagnosis or review. A lookup answered by one definition does not need a walkthrough.
---

# Read code

Start with the behavior the reader wants to understand. If the question concerns a small, self-contained piece of code or diff, read it in order and check only the surrounding code needed to answer the question. For unfamiliar behavior or a change spread across several places, use the passes below.

## Map one execution path

Pick one concrete input or event, usually the case the reader asked about or a successful case for the feature. Find where it enters the system and follow it until it produces an observable result. Identify which functions hand work to which others. On this first pass, a tentative label such as "loads the saved order" is enough to move past a helper. Open its implementation whenever the explanation depends on its exact behavior, side effects, or edge cases. Do not present an uninspected helper's behavior as verified fact. Inspect it first, or note that you left it uninspected.

## Follow one thread at a time

Choose a function or value that matters to the question. For a function, find its callers and check what they pass in and how they handle its result or errors. For a value, follow where it originates, where it changes, and who consumes it. Search across the repository, including unchanged code outside a diff. An unchanged caller can explain the consequence of a changed return value. When direct call sites do not appear, check indirect links such as interface implementations, callbacks, event handlers, or configuration. Note any dispatch path you cannot verify statically.

Keep each pass focused. For example, if a retry now returns a cached result, follow that result to the caller that decides what response to send. Queue scheduling can wait unless it affects that decision. Start another pass when a different caller, branch, or piece of data could change the explanation.

## Check for gaps

Once you can explain the behavior, verify what your passes may have missed and revise the explanation when you find a discrepancy:

- **With a diff:** Read the substantive hunks in order, skipping generated files, lockfiles, or purely mechanical edits unless relevant. Trace any hunk your explanation does not account for through its callers or consumers.
- **Without a diff:** Check the traced path against a concrete call site or test case. Look for preconditions, state setup, failure branches, or assertions that contradict or complicate your explanation.

## Explain the behavior

Answer the reader's question directly in terms of the input and outcome—or, for a diff, what behavior changes and which callers depend on it—rather than narrating your reading passes. Point to the few source locations the reader can inspect to check the explanation. If a conclusion depends on a product assumption, identify it. For example, two records may briefly disagree. Whether that matters depends on who can observe the mismatch and what guarantee they rely on.

Adapted from Sean Goedecke's [How to read code](https://www.seangoedecke.com/how-to-read-code/).
