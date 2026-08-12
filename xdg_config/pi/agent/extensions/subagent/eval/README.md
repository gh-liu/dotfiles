# Pi subagent live evaluation

This suite runs the real `pi` CLI against isolated temporary Git repositories.
It measures whether the parent uses the subagent tool at the intended boundary,
which role it selects, how roles compose, and whether delegated implementation
actually produces a valid result.

It is deliberately **not** part of `npm test`: it needs provider credentials and
network access, takes several minutes, and incurs real model/search cost.

## What it executes and expects

| Scenario | Expected behavior | Full repeats |
| --- | --- | ---: |
| `simple-lookup` | Parent reads one file; no subagent | 3 |
| `local-discovery` | `scout` maps the multi-file lifecycle | 3 |
| `external-research` | `researcher`; no duplicate parent `web_search` | 3 |
| `independent-review` | `reviewer` finds the missing default-TTL regression | 1 |
| `small-coherent-implementation` | Parent implements directly; fixture tests pass | 1 |
| `explicit-worker` | `worker` implements; fixture tests pass | 1 |
| `high-impact-decision` | `oracle` resolves a compatibility judgment | 3 |
| `combo-implementation-review` | `scout → worker → reviewer`; tests pass | 1 |
| `combo-evidence-decision` | `scout` + `researcher` evidence before `oracle` | 1 |
| `persistent-follow-up` | `start → wait → send(follow_up) → wait → close` | 1 |

The fixture contains an intentional seconds-versus-milliseconds bug and a
`plan.md`. Every run gets its own copy, so concurrent writing scenarios cannot
race and no evaluation prompt can modify this dotfiles repository. The runner
also builds an isolated temporary Pi agent directory: it uses the current
agents, extensions, skills, settings, and credentials, while keeping runtime
state and child transcripts out of the real agent directory.

## Commands

Run these commands from `xdg_config/pi/agent/extensions`. The examples use
Node.js; replace `node` with `bun` to use Bun instead.

Run the full statistical and composition matrix. Behavioral thresholds are
strict in this mode:

```bash
node subagent/eval/run.mjs
```

Run the six core scenarios once. Deterministic failures still fail the command;
single-sample routing misses are warnings:

```bash
node subagent/eval/run.mjs --quick
```

Target one behavior while tuning a description or guideline:

```bash
node subagent/eval/run.mjs --scenario external-research --repeat 3
node subagent/eval/run.mjs --scenario combo-implementation-review
```

Inspect the plan without making provider calls:

```bash
node subagent/eval/run.mjs --dry-run
```

Useful controls:

```bash
node subagent/eval/run.mjs \
  --model openai-codex/gpt-5.6-luna \
  --jobs 2 \
  --timeout 300 \
  --report /tmp/subagent-after
```

Compare a run with a saved result:

```bash
node subagent/eval/run.mjs \
  --baseline /tmp/subagent-before/report.json \
  --report /tmp/subagent-after
```

Use `--strict` to enforce behavioral thresholds in quick/custom runs,
`--no-strict` to report them as warnings, and `--keep` to preserve fixture
repositories for debugging. `--help` lists all options.

Before invoking models the runner checks `pi --version` and
`pi auth check --model <model>`.

## Assertions and reports

Deterministic invariants always fail the command:

- Pi exits successfully before the timeout and emits valid JSONL.
- Every subagent call includes `action`; no failed subagent invocation or schema
  error is hidden by a successful retry.
- Explicit delegation/composition and persistent lifecycle orders are honored.
- Read-only scenarios do not alter files or Git history.
- Implementation changes are limited to `src/session.js` and
  `test/session.test.js`, produce a clean diff, and pass fixture tests.

Implicit model routing is probabilistic. Full mode enforces each scenario's
target rate (normally 2/3 for positive implicit routing and 3/3 for avoiding a
simple-task false positive). Quick mode reports a miss as a warning unless
`--strict` is set.

The artifact directory contains:

- `report.json`: machine-readable metadata, calls, rates, parent costs, outcomes,
  and optional baseline deltas. Child-model cost is not exposed in the parent
  JSONL stream.
- `summary.md`: a human-readable matrix and failure details.
- `<scenario>-<repeat>.jsonl`: raw parent Pi event stream.
- `<scenario>-<repeat>.stderr.log`: diagnostics from that Pi process.

Fixture repositories, the isolated Pi config, runtime files, and child
transcripts are removed by default. Use `--keep` to preserve them.

The analyzer only counts top-level `tool_execution_start` events. Tool names
quoted inside a child handoff are not mistaken for duplicate parent work.
