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

`subagent({ description, task, thinking? })` runs a bounded exploration or implementation
task synchronously in a fresh Pi session. Supply the background, scope,
constraints, acceptance criteria and evidence requirements: the child cannot see
the parent conversation. Prefer file references over pasted logs. The child shares
the working directory and may modify files; it is not a sandbox, and cancellation
does not roll back changes. Calls are sequential and model-only, not callable from
codemode. Children cannot delegate through this extension.

The child resolves the parent's model from the same agent directory's static
provider/auth configuration, retains its project trust, and
loads project guidance, SYSTEM/APPEND instructions and skills independently.
Thinking defaults to the parent's level. The calling agent may request `off`,
`minimal`, `low`, `medium`, `high`, `xhigh` or `max` for a clear task-specific
benefit; user instructions take precedence. Lower levels suit bounded, low-risk,
easily verified work, not exploration categorically. The SDK clamps unsupported
levels; the UI shows the effective level and any adjustment, which also returns
in the handoff. Missing both parent and requested levels fails explicitly.
It does not inherit parent extensions, permission hooks, runtime-only credentials,
dynamic providers or routers. An unresolved model fails rather than falling back.
Its tools are explicitly limited to read, grep, find, ls, bash, edit and write;
there is no child MCP or codemode extension. Background cache warming is disabled
using scoped in-memory settings, without modifying the user's configuration.

Only the final handoff enters the parent's model context. It follows Pi compact's
Goal (starting with Outcome), Constraints & Preferences, Progress (Done / In
Progress / Blocked), Key Decisions, Next Steps and Critical Context structure.
The child writes it directly; there is no extra summary model call. Handoffs over
24,000 UTF-8 bytes and incomplete model responses are reported as failures with a
child-session reference, never silently truncated into apparent success. Error
diagnostics are bounded too. Success means a complete handoff was returned, not
that its claims have been independently accepted; the parent must verify them.

The codemode-style tool block shows request, live activity, result and time.
Ctrl+O uses Pi's native expansion state: collapsed previews show 10 visual request
lines, up to 8 calls (running first, then recent completed) and 5 visual result
lines. Expanded views show the full
request, retained call parameters and returned handoff. Thinking is a status only.
Each finished call shows its duration; the bottom displays live Elapsed or final
Took, including failures/cancellation and restored sessions. Regions are separated
by one blank line. Child tool calls can run in parallel; activity reports the
total number still running, including calls hidden by the display/history limits.
Multiple subagent calls themselves remain sequential.

UI metadata retains up to 64 calls and 2,048 argument characters per call, with
explicit notices for evicted/shortened data. Raw tool results and thinking are not
copied into parent metadata. Full child records are persisted separately under
`<agentDir>/sessions/subagents/`; expanded output shows the path. These records can
contain sensitive tool data and are not automatically deleted. Parent session
metadata is bounded, not empty. Cancellation cooperatively aborts the child,
waits for shutdown, then disposes it; a tool ignoring cancellation can delay this.
There is no total runtime, token or cost cap in this version.

## Complete extension list and composition

- `auth`: conservatively imports Codex OAuth credentials from macOS Keychain,
  falling back to `CODEX_HOME/auth.json`. Pi owns request-time refresh; existing
  API keys, other accounts and equal/newer credentials are preserved. See
  [authentication API boundary and synchronization policy](auth/API.md).
- `status`: shows activity, model, token, cost, and context state.
- `subagent`: delegates context-heavy tasks to fresh child conversations with a
  streamed codemode-style UI and compact-style final handoff.

## Configuration, tests, and troubleshooting

Codex uses `CODEX_HOME` (default `~/.codex`). Never document or log secrets or
auth-file contents. If Codex does not sync, check Keychain access and valid OAuth
fields/JWT expiry, then whether Pi already holds a protected credential. Deliberate
account changes require Pi login or logout followed by a new session.

Host packages are `peerDependencies`; pinned Pi 1.3.0 development copies support
local checks. Install with `npm ci --ignore-scripts`, then run `npm test`.
Focused checks are `npm run typecheck:auth`, `npm run typecheck:status` and
`npm run typecheck:subagent`. `npx vitest run subagent/index.test.ts` exercises real
SDK parent/child sessions against a local HTTP fixture provider, including context
isolation, untrusted resources, cancellation, failure and output bounds. It does
not use live credentials. These development dependencies do not update the
globally installed Pi runtime.

For current/external facts, use the Exa skill with official/primary sources,
preserve URLs, and distinguish snippets from verified facts. Restart Pi after
removing extensions; active sessions may retain previously registered tools.
