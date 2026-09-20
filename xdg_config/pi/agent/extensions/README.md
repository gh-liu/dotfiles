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

## Subagent configuration

`subagent` is a role-free, one-shot child agent. Configure its controller policy in
Pi's normal settings rather than a separate extension file:

```json
{
  "subagent": {
    "maxConcurrentRuns": 4
  }
}
```

The default is 4. A trusted project's `.pi/settings.json` may override the global
`~/.pi/agent/settings.json` value. The value must be a positive integer. Per-call
model and thinking overrides remain in the tool's `opts`; child tools, system
prompt, nesting, credential handling, and output limits remain code-owned safety
policy. Named `worker`/`scout`/`reviewer`/`tester` profiles are not part of the
current contract; describe the required behavior and handoff directly in `task`.

## Subagent live evaluation

`node subagent/eval/run.mjs --quick` (or the equivalent `bun` command) runs real
Pi sessions against isolated fixtures to evaluate subagent routing and outcomes.
It uses provider credentials, network access, and model quota, so it is
intentionally separate from `npm test`. There is no package-script alias so the
runner is equally usable with Node.js or Bun. See
[subagent/eval/README.md](subagent/eval/README.md) for the scenario matrix, full
statistical run, report format, and baseline comparison workflow.

## Complete extension list and composition

- `auth`: syncs Codex OAuth credentials from macOS Keychain, falling back to `CODEX_HOME/auth.json`.
- `continue`: resumes after compaction from the summary and worktree, consulting history only for decision-critical gaps.
- `status`: shows activity, model, token, cost, and context state.
- `subagent`: runs independent subtasks and presents their results.
- `websearch`: provides Exa `web_search` for current or external facts.

Use `continue` for compaction recovery. It is intentionally the only history-related extension because it uses session history only when a compaction recovery decision requires it.

## Configuration, tests, and troubleshooting

Set `EXA_API_KEY` in the environment that starts Pi. Codex uses `CODEX_HOME` (default `~/.codex`). Never document or log secrets or auth-file contents. Run `npm test` in this directory; focused checks are `npm run typecheck:status` and `npm run typecheck:subagent`.

If web search is unavailable, verify `EXA_API_KEY` and the API/network response. If Codex does not sync, verify Keychain access on macOS, then verify `CODEX_HOME/auth.json` contains OAuth fields and an access-token JWT with `exp`.

For current/external facts, web search prefers official/primary sources, preserves source URLs, and distinguishes snippets from verified facts.
