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

Web search uses the `exa-search` skill and raw HTTP instead of a custom tool.
Export `EXA_API_KEY` in the environment that starts Pi. The skill is discovered
under `../skills/exa-search/`; no `websearch` extension is loaded.

## Continue after compaction

`continue` resumes the active task after compaction. It treats Pi's compaction
summary and the current worktree as primary context, consulting the persisted
session JSONL only when a decision-critical detail is missing, contradictory, or
ambiguous. This avoids routinely refilling the newly compacted context.

## Status usage

The footer counts assistant and tool-result usage, compaction and branch-summary
usage, and standalone `usage` entries such as background cache warming. All
reported input/output tokens and total costs are included, regardless of kind or
provider. Reasoning tokens are already included in output and are not added again.
Cache hit remains the latest assistant request's ratio; background usage does not
replace it. Background costs appear on the next normal snapshot refresh.

## Removed extensions

`websearch` and `subagent` were removed on 2026-10-02. Exa retrieval is covered by
the skill; the custom child-agent workflow did not justify its maintenance cost.
The subagent settings, unused named profiles, tests and evaluation runners were
removed together. Codemode is not a replacement for isolated child context.

## Complete extension list and composition

- `auth`: conservatively imports Codex OAuth credentials from macOS Keychain,
  falling back to `CODEX_HOME/auth.json`. Pi owns request-time refresh; existing
  API keys, other accounts and equal/newer credentials are preserved. See
  [authentication API boundary and synchronization policy](auth/API.md).
- `continue`: resumes after compaction from the summary and worktree, consulting history only for decision-critical gaps.
- `status`: shows activity, model, token, cost, and context state.

Use `continue` for compaction recovery. It is intentionally the only history-related extension because it uses session history only when a compaction recovery decision requires it.

## Configuration, tests, and troubleshooting

Codex uses `CODEX_HOME` (default `~/.codex`). Never document or log secrets or
auth-file contents. If Codex does not sync, check Keychain access and valid OAuth
fields/JWT expiry, then whether Pi already holds a protected credential. Deliberate
account changes require Pi login or logout followed by a new session.

Host packages are `peerDependencies`; pinned Pi 1.0.0 development copies support
local checks. Install with `npm ci --ignore-scripts`, then run `npm test`.
Focused checks are `npm run typecheck:auth` and `npm run typecheck:status`.
Vitest and TypeScript received compatible patch updates. Pi 1.0.0's published
shrinkwrap still pins vulnerable `brace-expansion@5.0.9` in the development tree;
`npm audit fix` cannot update that nested pin. Track the upstream package fix
rather than modifying the installed shrinkwrap. These development dependencies
do not update the globally installed Pi runtime.

For current/external facts, use the Exa skill with official/primary sources,
preserve URLs, and distinguish snippets from verified facts. Restart Pi after
removing extensions; active sessions may retain previously registered tools.
