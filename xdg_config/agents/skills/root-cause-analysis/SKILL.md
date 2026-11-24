---
name: root-cause-analysis
description: Isolate the root cause of bugs, test failures, regressions, or unexpected runtime behavior from observable evidence. Use when observed behavior diverges from expectations and the cause is unknown, rather than when explaining working code, modeling ambiguous requirements, isolating a chosen factor's effect, or implementing a fix.
---

# Root-cause analysis

Pin down why observed behavior diverges from expected behavior before proposing or implementing a fix. Do not apply speculative fixes while the cause remains unconfirmed; prefer read-only checks, and ask before adding temporary instrumentation when read-only evidence cannot separate the remaining hypotheses.

## Pin down the failure

- Record the expected behavior, the actual behavior, and the concrete input, state, or event sequence that triggers the mismatch.
- Reproduce the failure when feasible so follow-up checks have a reliable baseline. When direct reproduction is unavailable, collect primary evidence from logs, stack traces, metrics, or persisted state instead of guessing from an error message alone.

## Trace to the first divergence

- Separate where the error surfaces from where execution or data first went wrong. Follow the triggering path from a known-good boundary to the earliest point where actual state violates the contract.
- Check configuration, persisted state, build artifacts, deployment environment, and external dependencies whenever application code alone does not explain the observation.
- For regressions with a known-good revision and a repeatable check, narrow the introducing commit range before inspecting individual changes in detail.

## Falsify competing hypotheses

- List the plausible causes consistent with all current evidence. Choose the smallest discriminating check—such as a targeted read-only probe, query, log inspection, or existing test—whose outcome rules out at least one candidate explanation.
- Update the candidate list after each check. Keep observed facts distinct from inferences, and discard explanations contradicted by evidence rather than patching them with unverified assumptions. For intermittent or timing-sensitive failures, treat a single non-reproducing run as inconclusive rather than falsification.

## Report the diagnosis

- Verify that the confirmed cause accounts for all observed symptoms, not just one. Lead with that root cause and trace the causal chain from the underlying defect to each symptom, citing exact code, configuration, or log locations. If a blocker prevents confirmation, state the remaining candidate causes and the check needed to separate them.
- Summarize which alternative explanations were ruled out and note the trigger condition a later regression check should exercise.

## Examples

**Symptom vs. first divergence.** Checkout throws `NullPointerException` while formatting the receipt. Tracing the order backward shows `discountRule` becomes `null` during cart deserialization when an expired coupon is present, making deserialization the first divergence.

**Minimal discriminating check.** Two hypotheses explain 502 errors after a deploy: upstream timeout or a missing TLS CA bundle. Inspecting one proxy error log entry distinguishes `upstream timed out` from `x509: certificate signed by unknown authority` before reading application code.
