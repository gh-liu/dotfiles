# Pi sessions live evaluation

This suite starts three real Pi RPC processes against one isolated agent
directory. It verifies the `sessions` extension through the same model-facing
tool boundary used in normal Pi sessions rather than calling extension
functions directly.

The scenario performs these steps:

1. A persisted `history-source` session stores a unique marker.
2. An ephemeral `caller` invokes `sessions({ action: "search_history" })` and
   must find that real persisted session.
3. An ephemeral `responder` joins the same local IPC broker.
4. `caller` lists both active sessions, sends a one-way message, and asks a
   question.
5. `responder` inspects `pending` and replies; `caller` must receive the exact
   correlated answer.
6. `caller` starts another ask and is externally aborted; `responder` must
   remove it from `pending` and reject a late reply.

This evaluation is intentionally separate from `npm test`: it requires provider
credentials, network access, and model quota. It normally takes one to two
minutes and makes real model requests.

## Commands

Run from `xdg_config/pi/agent/extensions`:

```bash
node sessions/eval/run.mjs
```

The equivalent `bun sessions/eval/run.mjs` command is also supported. Override
the model, timeout, or artifact directory when debugging:

```bash
node sessions/eval/run.mjs \
  --model openai-codex/gpt-5.6-luna \
  --timeout 180 \
  --report /tmp/sessions-live
```

Inspect the plan without provider calls:

```bash
node sessions/eval/run.mjs --dry-run
```

Use `--keep` to preserve the isolated agent directory, persisted session, and
runtime socket. The runner deliberately creates that runtime under the short
`/tmp/pi-sess-*` prefix: macOS Unix-domain sockets have a small path-length
limit, and the normal per-user temporary directory can make a valid test fail
with `EINVAL` before IPC starts.

## Assertions and artifacts

The command fails if any required model tool call is missing, a tool or
extension returns an error, history does not contain the persisted source,
active peer/self identity is wrong, one-way delivery is not observed, or the
ask/pending/reply correlation does not return the exact marker. The cancellation
scenario expects only the cancelled ask and deliberate late reply to return
errors; any other tool or extension error fails the run.

The artifact directory contains:

- `report.json`: machine-readable checks, metadata, session IDs, and cost.
- `summary.md`: compact pass/fail table.
- `<session>.jsonl`: Pi event stream for each real process.
- `<session>.stderr.log`: process diagnostics.

Runtime state and the test session are removed by default; report artifacts are
kept for debugging.
