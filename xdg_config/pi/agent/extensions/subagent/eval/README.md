# Pi subagent live evaluation

This suite runs the real `pi` CLI against isolated temporary Git repositories.
It measures whether the parent delegates at the intended boundary, selects one
of the four bundled roles, composes sessions visibly, reuses a session through
followup, consumes handoffs, and verifies delegated implementation.

It is deliberately **not** part of `npm test`: it needs provider credentials and
network access, takes several minutes, and incurs real model/search cost.

## What it executes and expects

| Scenario | Expected behavior | Full repeats |
| --- | --- | ---: |
| `simple-lookup` | Parent reads one file; no subagent | 3 |
| `local-discovery` | `scout` maps the multi-file lifecycle | 3 |
| `external-research` | `scout` handles source-heavy web research; no duplicate parent `web_search` | 3 |
| `independent-review` | `reviewer` finds the missing default-TTL regression | 1 |
| `expert-judgment` | `reviewer` resolves a bounded compatibility tradeoff | 1 |
| `browser-qa` | `tester` launches the fixture app, exercises browser flows, preserves source, and saves screenshot evidence | 1 |
| `implementation` | `worker` implements; parent inspects the diff and reruns tests | 1 |
| `parallel-investigation` | Independent `scout` + `reviewer` sessions start before either settles | 1 |
| `staged-delivery` | Parent visibly composes `scout → worker → reviewer` | 1 |
| `persistent-followup` | One `#N` supports `run → followup → get → close` | 1 |
| `background-recovery` | Background result is recovered with `get` and then closed | 1 |
| `capacity-exhaustion` | Five active turns fill configured capacity; the sixth fails fast | 1 |

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

Run the core scenarios once. Deterministic failures still fail the command;
single-sample routing misses are warnings:

```bash
node subagent/eval/run.mjs --quick
```

Target one behavior while tuning a description or guideline:

```bash
node subagent/eval/run.mjs --scenario external-research --repeat 3
node subagent/eval/run.mjs --scenario persistent-followup
```

Inspect the plan without making provider calls:

```bash
node subagent/eval/run.mjs --dry-run
```

Useful controls:

```bash
node subagent/eval/run.mjs \
  --model opencode-go/muse-spark-1.2-contributor \
  --subagent-model opencode-go/muse-spark-1.2-contributor \
  --subagent-thinking minimal \
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
`pi auth check --model <model>`. When `--subagent-model` is supplied, it also
checks that model and overrides every child only in the temporary isolated
`settings.json`; `--subagent-thinking` does the same for child thinking. The
user's settings remain unchanged.

## UI state gallery

Render the production call, progress, terminal-result, completion-card, and
live-widget components with deterministic fixture states:

```bash
npx -y node@22 --experimental-strip-types subagent/eval/ui-gallery.mjs all
npx -y node@22 --experimental-strip-types subagent/eval/ui-gallery.mjs calls
npx -y node@22 --experimental-strip-types subagent/eval/ui-gallery.mjs progress
npx -y node@22 --experimental-strip-types subagent/eval/ui-gallery.mjs terminal
npx -y node@22 --experimental-strip-types subagent/eval/ui-gallery.mjs completions
```

The gallery is intentionally provider-free: deterministic fixtures make rare
crash, cancellation, race, and mixed-batch states reviewable without spending
tokens or waiting for a model to reproduce them. Real-Pi runs remain responsible
for verifying the integrated interactive TUI and provider path.

## Assertions and reports

Deterministic invariants always fail the command:

- Pi exits successfully before the timeout and emits valid JSONL.
- Pi leaves no child process group behind; the runner reports a hard failure and
  terminates the group if a delegated temporary server or browser is orphaned.
- Every subagent call includes `action`; no failed subagent invocation or schema
  error is hidden by a successful retry. A scenario may consume only an exact,
  counted expected error (currently the sixth-call capacity rejection); every
  unmatched error remains fatal.
- Explicit delegation, parent-visible composition, parallel starts, and reusable
  session action orders are honored.
- Tasks contain enough plain-text context for fresh sessions without requiring a
  public structured work-order schema.
- Parent verification of writing handoffs happens after the worker settles and
  includes both complete-diff inspection and an integrated test rerun.
- Read-only scenarios do not alter files or Git history.
- Browser-QA scenarios may write only required evidence under `.artifacts/` and
  must leave source, configuration, fixtures, and Git history unchanged.
- Implementation changes are limited to `src/session.js` and
  `test/session.test.js`, produce a clean diff, and pass fixture tests.

Implicit model routing is probabilistic. Full mode enforces each scenario's
target rate (normally 2/3 for positive implicit routing and 3/3 for avoiding a
simple-task false positive). The parallel scenario additionally checks that both
calls begin before the first subagent settles. Quick mode reports a miss as a
warning unless `--strict` is set.

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
quoted inside a child handoff are not mistaken for duplicate parent work. It
pairs parent subagent starts and settlements by tool-call ID before checking
post-handoff verification, so pre-delegation commands cannot satisfy those
assertions.
