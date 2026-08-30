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
`EXA_API_KEY` in the environment that starts Pi. Per-result limits are sent to
Exa, and the extension independently caps aggregate model-visible results at
24,000 characters; complete provider results remain in tool details.

## Continue after compaction

`continue` resumes the active task after compaction. It treats Pi's compaction
summary and the current worktree as primary context, consulting the persisted
session JSONL only when a decision-critical detail is missing, contradictory, or
ambiguous. This avoids routinely refilling the newly compacted context.

## Sessions

The `sessions` extension registers two history-reading tools. Call them in order:

- `sessions_search({ query, cwd?, limit? })` searches local Pi session history for
  matching messages. Use its exact `sessionId` or indexed `path` with
  `sessions_read`. It searches globally by default; `cwd` restricts results to
  that directory and its descendants. Results contain bounded metadata and
  snippets, not complete sessions.
- `sessions_read({ session, mode, cwd?, entryId?, entryLimit?, childLimit? })`
  reads a bounded view of the exact session id or path. `summary` is a bounded
  metadata/overview projection and latest-entry view, not a generated or complete
  summary. `entries` returns branch-aware conversation entries; with `entryId`,
  it follows that entry's resolved branch and can include its direct children.
  Without an explicit `cwd`, reads are restricted to the current cwd; a supplied
  cwd permits only that directory or descendants. In `entries` mode, `entryLimit`
  budgets branch entries and `childLimit` independently budgets direct child
  entries. Entry projections include `role` when available and model-visible text
  and overall output are bounded.

History capabilities are independent of active-session IPC and remain available
without any broker or runtime connection.

## Subagent live evaluation

`node subagent/eval/run.mjs --quick` (or the equivalent `bun` command) runs real
Pi sessions against isolated fixtures to evaluate subagent routing and outcomes.
It uses provider credentials, network access, and model quota, so it is
intentionally separate from `npm test`. There is no package-script alias so the
runner is equally usable with Node.js or Bun. See
[subagent/eval/README.md](subagent/eval/README.md) for the scenario matrix, full
statistical run, report format, and baseline comparison workflow.
