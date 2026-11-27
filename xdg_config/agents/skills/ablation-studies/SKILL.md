---
name: ablation-studies
description: Design or run a matched comparison to isolate a factor's effect. Use when a component, setting, input, or training choice can be removed or replaced to measure what changes, rather than when searching for the best overall configuration or verifying general correctness.
---

# Ablation studies

Use the full system as the baseline. For each factor, start from that baseline, remove, disable, or replace the factor, and compare performance on the same task. Skip ablation when the goal is tuning for the best overall configuration rather than isolating an individual factor's effect.

## Design the comparison

Predict which outcome should change, on which inputs, and what observation would weaken the explanation. Choose a primary metric that distinguishes the competing explanations; when testing multiple factors or metrics, separate pre-specified checks from exploratory findings. For a numerical metric, set the smallest difference that would change the decision.

Keep the rest of the implementation, inputs, initial state, and evaluation identical—never bundle preprocessing, heuristics, or tuning tweaks with the factor under test. Choose the intervention that answers the question:

- **Required component:** If removal breaks the system, substitute a simpler mechanism with the same interface. The comparison measures the difference between mechanisms.
- **Trained model:** To test reliance, disable the factor during evaluation. To test whether the model can learn without it, retrain without it using the same training budget. State which hyperparameters stay fixed. If comparing performance after tuning, give both variants comparable tuning budgets.
- **Compensating factors:** To measure their combined effect, test four configurations: the full system, each factor removed separately, and both removed together.

Decide how failures count before running. Score system failures by the task metric and report their rate: a timeout is a missed deadline when measuring on-time completion. If infrastructure invalidates a measurement, record the cause and rerun the pair according to the agreed rule.

## Run matched pairs

Verify that the baseline exercises the factor and the variant bypasses or replaces it. Run both on the same examples. Before interpreting a speedup or cost reduction, check that both still meet the task requirements.

- **Stochastic runs:** Repeat across matched random seeds—and dominant nuisance sources such as data splits or input ordering when applicable—using identical settings within each pair.
- **Timing measurements:** Alternate which configuration runs first. For cold-start measurements, reset caches and other shared state before each run. For steady-state measurements, start each configuration from equivalent state and warm it up independently with the same procedure before timing.
- **Independent repeats:** Match the unit of repetition to the claim. For retraining, compute the metric over the examples in each run, then record one difference per seed pair, not one per example.

## Interpret and report

- Report both configurations' measured values, the size and direction of the difference, the conditions needed to reproduce it, and the inputs and configurations the conclusion covers. For design-only work or an experiment you could not run, report the plan and decision criteria without measured results.
- **Stochastic or noisy metrics:** Quantify uncertainty across independent pairs, for example with a confidence interval for the mean difference. Compare the interval with zero to judge direction and separately with the predefined threshold to judge practical importance (an interval of 2–8 ms saved supports a speedup but leaves open whether it reaches a 5 ms target).
- **Non-significant or diluted results:** Do not treat a non-significant result as proof of no effect without checking statistical power; when the factor only affects a subset of inputs, analyze that impacted subset to avoid diluting the signal. For deterministic behavior, report the exact difference and verify the control cases.
- **Unexpectedly large shifts:** Treat surprisingly large gains or regressions with skepticism (Twyman's law): audit instrumentation, data leakage, and variant routing for measurement bugs before concluding the factor caused the shift.

## Examples

**Does the cache reduce database reads?** Start both configurations with an empty cache and replay `A, A, B`, bypassing the cache only in the variant. Verify that responses match, then compare reads per request. If hits explain the reduction, the second `A` should need fewer reads with caching. The first `B` should miss even with caching, so it serves as a control.

**Does the reranker improve retrieval quality?** Evaluate the full pipeline and a variant with the reranker disabled on the same query set across matched seeds. Verify that latency and error rates remain acceptable, compute a confidence interval for the paired NDCG difference, and compare it against zero separately from the minimum gain required to justify deployment.

References: Ron Kohavi, Diane Tang, and Ya Xu, *Trustworthy Online Controlled Experiments*; Paul R. Cohen, *Empirical Methods for Artificial Intelligence*; Zachary C. Lipton and Jacob Steinhardt, *Troubling Trends in Machine Learning Scholarship* (ACM Queue 2019); Xavier Bouthillier et al., *Accounting for Variance in Machine Learning Benchmarks* (MLSys 2021).
