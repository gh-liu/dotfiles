# Subagent

`subagent({ description, task, model?, thinking? })` runs a bounded exploration or implementation
task synchronously in a fresh Pi session. Supply the background, scope,
constraints, acceptance criteria and evidence requirements: the child cannot see
the parent conversation. Prefer file references over pasted logs. The child shares
the working directory and may modify files; it is not a sandbox, and cancellation
does not roll back changes. Calls are sequential and model-only, not callable from
codemode. Children cannot delegate through this extension.

## When to delegate

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

## Model, thinking and available tools

The child defaults to the parent's model. Override `model` with an exact
`provider/model-id` from the same agent directory's static provider/auth
configuration (the model ID may contain slashes). Unknown or malformed models
fail without fallback. When the selected provider/model differs from the parent's,
the UI shows it alongside Thinking and Elapsed/Took, including restored sessions;
identical models are omitted. Model metadata is not appended to the handoff.
The child retains the parent's project trust and
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

## Handoff and failures

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

## Display, session records and cancellation

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
copied into parent metadata, including expanded views (older metadata may still contain
thinking). Full child records are persisted separately under
`<agentDir>/sessions/subagents/`; expanded output shows the path. These records can
contain sensitive tool data and thinking, and are not automatically deleted. Parent session
metadata is bounded, not empty. Cancellation cooperatively aborts the child,
waits for shutdown, then disposes it; a tool ignoring cancellation can delay this.
The final tool result reports child usage from all persisted session entries, including
failed attempts, retries, tool usage and compaction summaries, once each. Pi's parent
session totals include that usage. Counts and costs depend on usage actually reported
and recorded by the SDK/provider; missing usage cannot be reconstructed. There is no
total runtime, token or cost cap in this version.
