---
name: failure-diagnosis
description: Distinguish competing causes of a failure using observable evidence. Use when a test fails, a regression appears, or runtime behavior diverges from expectations and the cause is still unknown, rather than when implementing a fix for an already confirmed cause.
---

# Failure diagnosis

Pin down why observed behavior diverges from expected behavior before proposing or implementing a fix. If primary evidence already confirms the cause, skip further diagnosis and move to fixing and verifying. Start with read-only checks; if the evidence leaves several hypotheses open, identify what to observe and which outcome would rule out each hypothesis, using temporary instrumentation only when needed and within the task's scope.

## Pin down the failure

- Record the expected behavior, the actual behavior, and the concrete input, state, or event sequence that triggers the mismatch.
- Reproduce the failure when feasible and simplify to a minimal failure-inducing input so follow-up checks have a clean baseline. Comparing state differences between a passing run and a failing run isolates the exact variables driving the cause-effect chain. When direct reproduction is unavailable, collect primary evidence from logs, stack traces, metrics, or persisted state instead of guessing from an error message alone.

## Trace to the first divergence

- Separate the visible failure from the first infected state and the underlying defect that created it. Observe actual runtime state before theorizing—never guess past what you can inspect. Follow the triggering path from a known-good boundary to the earliest point where actual state violates the contract, bisecting execution or input space (divide and conquer) when the path is large.
- Check configuration, persisted state, build artifacts, deployment environment, and external dependencies whenever application code alone does not explain the observation.
- For regressions with a known-good revision and a repeatable check, narrow the introducing commit range before inspecting individual changes in detail.

## Falsify competing hypotheses

- List the plausible causes consistent with all current evidence. Choose the smallest discriminating check—such as a targeted read-only probe, query, log inspection, or existing test—whose outcome rules out at least one candidate explanation, and change only one variable at a time when probing so you know what shifted the outcome.
- Update the candidate list after each check. Keep observed facts distinct from inferences, and discard explanations contradicted by evidence rather than patching them with unverified assumptions. For intermittent or timing-sensitive failures, treat a single non-reproducing run as inconclusive rather than falsification.

## Report the diagnosis

- Verify that the confirmed cause accounts for all observed symptoms, not just one. Lead with that root cause and trace the causal chain from the underlying defect to each symptom, citing exact code, configuration, or log locations. If a blocker prevents confirmation, state the remaining candidate causes and the check needed to separate them.
- Summarize which alternative explanations were ruled out and note the trigger condition a later regression check should exercise.

## Examples

**Symptom vs. first divergence.** Checkout throws `NullPointerException` while formatting the receipt. Tracing the order backward shows `discountRule` becomes `null` during cart deserialization when an expired coupon is present, making deserialization the first divergence.

**Minimal discriminating check.** Two hypotheses explain 502 errors after a deploy: upstream timeout or a missing TLS CA bundle. Inspecting one proxy error log entry distinguishes `upstream timed out` from `x509: certificate signed by unknown authority` before reading application code.

References: Andreas Zeller, *Why Programs Fail* and *Isolating Cause-Effect Chains from Computer Programs* (FSE 2002); David J. Agans, *Debugging: The 9 Indispensable Rules for Finding Even the Most Elusive Software and Hardware Problems*.
