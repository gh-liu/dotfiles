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

`herdr-fork` handles successful native `/clone` and `/fork` transitions through
`session_start` with `reason: "fork"`. In a Herdr-managed interactive Pi, it
creates an unfocused temporary tab named `Restoring Pi` and resumes
`previousSessionFile` there. The current layout stays intact while Herdr waits
for an interactive-ready Pi. Only then does it move the restored pane beside
the current pane and immediately move the current Pi into a focused new tab.
Moving out the restored pane automatically closes the temporary tab. A split
is visible only between the two moves, not throughout Pi startup; the overall
command still waits for restoration. The old tab retains its ID, position and
other panes; the forked Pi retains its process and `/fork` editor draft. The
restored old session uses a new Pi process, not the old terminal's scrollback or
ephemeral UI state. Restored Pi uses its normal startup configuration.

The new tab is named `<original tab name> · fork`, with ` 2`, ` 3`, etc. added
on collisions within the workspace. Purely numeric labels are treated as
default names: use the current Pi session name, or `Pi` when unnamed. Herdr's
generated numeric label can differ from its stable tab number; manually chosen
purely numeric labels use the same fallback. Both native
commands use the `fork` suffix because `session_start` does not identify which
command caused the transition. The original tab's label is never changed.

Herdr 0.9.5 does not support cross-tab `pane swap`: it exits successfully with
`changed: false, reason: "cross_tab"`. Background restoration followed by two
moves avoids that limitation and never rewrites session JSONL. Resolve the
caller with `pane current --current`; inherited tab IDs become stale after the
first move.

Startup, resume, reload, cancelled forks and non-TUI/non-Herdr runs leave the
layout alone. A new shell's explicit pre-launch `agent_pane_busy` rejection is
retried for up to five seconds; ambiguous failures and timeouts are never retried.
On startup or move failure, the forked session stays active and a warning is
shown. Any created pane is left intact because a timed-out command
may already have started Pi; inspect it before closing or retrying. No session
files are deleted. Run `npm run typecheck:herdr-fork` for its type check or
`npm test` for the full extension suite. Existing Pi instances need `/reload`
once to discover the extension.

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

Delegate by outcome, not merely because a task is complex: use the child when
investigation, diagnosis, scoped implementation or verification will produce
large intermediate context but a concise, reviewable handoff. The solution need
not be known before delegation. Keep simple lookups, small edits, frequent
back-and-forth and work requiring the parent's raw reasoning context or exclusive
tools in the parent. Do not repeat a delegated investigation. Each call is fresh;
there is no follow-up/resume API or background parallel work for the parent.
Supply a self-contained brief with relevant facts and references, scope/non-goals,
read-only or write boundaries, user constraints/approvals, acceptance checks and
required evidence. The child chooses its approach unless a method is required.

The child resolves the parent's model from the same agent directory's static
provider/auth configuration, retains its project trust, and
loads project guidance, SYSTEM/APPEND instructions and skills independently.
Thinking defaults to the parent's level. The calling agent may request `off`,
`minimal`, `low`, `medium`, `high`, `xhigh` or `max` for a clear task-specific
benefit; user instructions take precedence. Lower levels suit bounded, low-risk,
easily verified work, not exploration categorically. The SDK clamps unsupported
levels; the UI metadata records the requested/effective levels and displays any
adjustment without appending it to the result body. Missing both parent and
requested levels fails explicitly.
It does not inherit parent extensions, permission hooks, runtime-only credentials,
dynamic providers or routers. An unresolved model fails rather than falling back.
Its tools are explicitly limited to read, write, edit, bash and codemode.
The SDK's codemode extension is initialized independently for each child and can
call the child's file and shell tools, but does not inherit parent MCP tools.
Search and directory listing use bash rather than separate grep/find/ls tools.
Background cache warming is disabled
using scoped in-memory settings, without modifying the user's configuration.
The shell environment and filesystem are shared; installed commands can still
access the network through bash. Tool isolation is not network isolation, and
delegation must never bypass required approvals. Independently loaded skills may
require tools unavailable to this child.

Only the final handoff enters the parent's model context. Specify the expected
deliverable and, when important, its format/detail in `task`: a direct answer,
findings list, comparison table, change report or strict JSON. The task's requested
format takes precedence; no runtime annotations are appended to successful output.
Without a format request, the default is a concise, outcome-first handoff with
necessary evidence, validation results, uncertainties and genuine remaining work.
Empty sections are omitted. Pi compact-style continuation summaries remain an
option when useful, not a mandatory template. The child writes the result
directly; there is no extra summary model call or output-schema validator.
Callers must validate structured output before using it. Handoffs over
24,000 UTF-8 bytes and incomplete model responses are reported as failures with a
child-session reference, never silently truncated into apparent success. Error
diagnostics are bounded too; failures return diagnostic text, not necessarily the
requested output format. Success means a complete handoff was returned, not
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
  streamed codemode-style UI and task-specific, concise final handoff.
- `herdr-fork`: opens native clones/forks in a new Herdr tab while restoring the
  previous session in the original tab.

## Configuration, tests, and troubleshooting

Codex uses `CODEX_HOME` (default `~/.codex`). Never document or log secrets or
auth-file contents. If Codex does not sync, check Keychain access and valid OAuth
fields/JWT expiry, then whether Pi already holds a protected credential. Deliberate
account changes require Pi login or logout followed by a new session.

Host packages are `peerDependencies`; pinned Pi 1.3.0 development copies support
local checks. Install with `npm ci --ignore-scripts`, then run `npm test`.
Focused checks are `npm run typecheck:auth`, `npm run typecheck:status`,
`npm run typecheck:subagent` and `npm run typecheck:herdr-fork`.
`npx vitest run subagent/index.test.ts` exercises real
SDK parent/child sessions against a local HTTP fixture provider, including context
isolation, untrusted resources, cancellation, failure and output bounds. It does
not use live credentials. These development dependencies do not update the
globally installed Pi runtime.

For current/external facts, use the Exa skill with official/primary sources,
preserve URLs, and distinguish snippets from verified facts. Restart Pi after
removing extensions; active sessions may retain previously registered tools.
