# extensions

https://pi.dev/docs/latest/extensions

## Archiving branches (native label workflow)

A custom `archive` extension (branch archiving via physical session-file rewriting,
~2,400 LOC) was removed on 2026-08-22: it had never been used on a real session, and
its only advantage over native capabilities — hiding branches from `/tree` — did not
justify rewriting the session JSONL behind pi's back.

The replacement workflow uses native features only:

- Mark a dead branch as archived: open `/tree`, select the branch root, press
  Shift+L and enter `[archived]`.
- Labels are persisted as append-only `label` entries in the session file with
  latest-wins resolution; setting another label (or an empty one) on the same entry
  supersedes or clears the mark, so archive/restore is fully reversible.
- Ctrl+O filter modes apply as usual (`labeled-only` is a bookmarks view that shows
  only labeled entries). Note there is no filter mode that *hides* labeled branches;
  fold state is ephemeral UI state and not persisted.
- If accidentally navigating into an archived branch becomes annoying, a ~50-line
  extension can restore a guard: a `session_before_tree` handler that walks
  `parentEntry.parentId` ancestry from `event.preparation.targetId`, checks for a
  resolved `[archived]` label via `ctx.sessionManager.getLabel()`, and returns
  `{ cancel: true }`.

## Web search

`websearch` registers a local `web_search` tool backed by the Exa Search API. Export
`EXA_API_KEY` in the environment that starts Pi.

## Sessions

The `sessions` extension registers two tools:

- `sessions`: search local Pi session history with `search_history`, or list active
  Pi sessions connected through the local Unix-domain-socket transport with `list`.
- `session_message`: communicate with an active session using `send`, `ask`,
  `reply`, `pending`, or `cancel`.

History search remains available when local IPC is unavailable. Active-session
operations require the target session to have this extension loaded and connected.
The active-session transport uses a private Unix-domain socket under
`$PI_CODING_AGENT_DIR/runtime` on macOS and Linux; Windows is not supported.

`node sessions/eval/run.mjs` starts real isolated Pi processes and validates
history search plus active `list`, `send`, `ask`, `pending`, `reply`, and `cancel`
behavior.
It uses provider credentials and model quota, so it is intentionally separate
from `npm test`. See [sessions/eval/README.md](sessions/eval/README.md) for usage,
assertions, and artifacts.

## Subagent live evaluation

`node subagent/eval/run.mjs --quick` (or the equivalent `bun` command) runs real
Pi sessions against isolated fixtures to evaluate subagent routing and outcomes.
It uses provider credentials, network access, and model quota, so it is
intentionally separate from `npm test`. There is no package-script alias so the
runner is equally usable with Node.js or Bun. See
[subagent/eval/README.md](subagent/eval/README.md) for the scenario matrix, full
statistical run, report format, and baseline comparison workflow.
