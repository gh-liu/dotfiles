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

## Compaction continuation

The `continue` extension was removed because Pi 1.2.0 already schedules the next
response after between-turn compaction and retries recoverable context overflow.
`session_compact.willRetry === false` does not mean no response is scheduled;
injecting a generic follow-up can run an extra turn after the task finishes.
Continuation is owned by Pi's scheduler, not by a global compaction listener.
Manual `/compact` keeps its native behavior and does not imply task resumption.

## Herdr fork tabs

The `forks` extension was removed because its automatic tab restoration and
pane movement were not useful enough in practice. Native `/clone` and `/fork`
remain available without automatic Herdr layout changes. Existing tabs and
session files are left intact. Restart Pi to unload the removed extension.

## Status usage

The footer counts assistant and tool-result usage, compaction and branch-summary
usage, and standalone `usage` entries such as background cache warming. All
reported input/output tokens and total costs are included, regardless of kind or
provider. Reasoning tokens are already included in output and are not added again.
Cache hit remains the latest assistant request's ratio; background usage does not
replace it. Background costs appear on the next normal snapshot refresh.

The session name appears immediately after the Git branch (or the directory when
there is no branch) and refreshes on rename. Unnamed sessions omit it; long names
are truncated to 32 columns, and narrow terminals hide it before the branch.

## Removed extensions

`websearch` and `subagent` were removed on 2026-10-02. Exa retrieval is covered by
the skill; the custom child-agent workflow did not justify its maintenance cost.
The subagent settings, unused named profiles, tests and evaluation runners were
removed together. A smaller, single-task subagent was reintroduced on 2026-10-21
for context isolation, without the old profiles or orchestration framework.
Codemode is not a replacement for isolated child context.

## Subagent

`subagent({ description, task, model?, thinking? })` delegates one bounded task to
a fresh Pi session. Calls are synchronous and sequential, with a shared filesystem,
not a sandbox. See the [Subagent reference](subagent/README.md) for delegation
guidance, available tools, model/thinking overrides, handoffs, limits and cancellation.
The tool description keeps essential constraints inline and provides the reference's
absolute path for on-demand reading, following codemode's documentation pattern.

## Complete extension list and composition

- `auth`: conservatively imports Codex OAuth credentials from macOS Keychain,
  falling back to `CODEX_HOME/auth.json`. Pi owns request-time refresh; existing
  API keys, other accounts and equal/newer credentials are preserved. See
  [authentication API boundary and synchronization policy](auth/API.md).
- `status`: shows activity, model, token, cost, and context state.
- `subagent`: delegates context-heavy tasks to fresh child conversations with a
  streamed codemode-style UI and task-specific, concise final handoff.
- `sessions`: exposes `list_sessions` through codemode, not as an active model
  tool. `await tools.list_sessions({})` returns saved sessions for the current directory,
  newest modified first, as `{ id, title, path, parentSessionId? }[]`. Titles use the session name
  or fall back to the first user message. Use `read` on the absolute JSONL path
  (with `offset`/`limit` for large files); raw files include branches, not just the
  current conversation path. Explicit tool activation can override codemode exposure.
  Optional `query` matches a case-insensitive title substring (trimmed; empty
  matches all). `currentDirectoryOnly` defaults to `true`, restricting results to
  the current working directory, excluding subdirectories. Set it to `false` to
  search all projects. Both filters can be combined.
  `parentSessionId` identifies the originating session, not a message branch or
  an execution owner. It is resolved even when the parent is outside the filtered
  results, and omitted for root sessions or missing/unreadable/malformed parents.
- `mpl-render`: renders charts as PNGs from codemode by running native `mpl` code in a QuickJS sandbox. See the [chart tool README](mpl-render/README.md) for the script contract, limits, and measurements.

## Configuration, tests, and troubleshooting

Codex uses `CODEX_HOME` (default `~/.codex`). Never document or log secrets or
auth-file contents. If Codex does not sync, check Keychain access and valid OAuth
fields/JWT expiry, then whether Pi already holds a protected credential. Deliberate
account changes require Pi login or logout followed by a new session.

Each extension directory is its own package. There is no shared manifest in
this directory. Pi supplies `@earendil-works/pi-ai`,
`@earendil-works/pi-coding-agent`, and `@earendil-works/pi-tui` at runtime, so
those are `peerDependencies`; pinned Pi 1.3.0 copies plus TypeScript and Vitest
are that package's `devDependencies`. `mpl-render` keeps
`@earendil-works/pi-codemode`, `mpl`, and `rolldown` in `dependencies`:
`pi-codemode` is not one of the modules Pi maps to its own copy, and moving it
to `devDependencies` would make the extension fail to load.

With Node.js 24 or newer, install and test one extension from inside it:

```sh
npm ci
npm test
```

`npm test` typechecks that package and runs its Vitest files. For `mpl-render`,
`npm ci` builds the pinned GitHub dependency `mpl` and the `postinstall` script
bundles it for the QuickJS sandbox; `--ignore-scripts` skips both. Restart Pi
or run `/reload` to discover the chart tool after installation.
`npm test` in `subagent` exercises real SDK parent/child sessions against a
local HTTP fixture provider, including context isolation, untrusted resources,
cancellation, failure and output bounds. It does not use live credentials.
These development dependencies do not update the globally installed Pi runtime.

For current/external facts, use the Exa skill with official/primary sources,
preserve URLs, and distinguish snippets from verified facts. Restart Pi after
removing extensions; active sessions may retain previously registered tools.
