# Subagent

`subagent({ description, task, model?, thinking? })` delegates a bounded task to a fresh Pi session and returns a single handoff. Only the parent model can call it (`exposure: "model-only"`).

## Parameters

| Parameter | Required | Rules & defaults |
| --- | :---: | --- |
| `description` | Yes | Short task title shown in the UI (1–160 chars, non-empty). |
| `task` | Yes | Self-contained brief (non-empty). The child cannot see the parent conversation or prior calls. |
| `model` | No | Defaults to the parent's model. Override with an exact `provider/model-id` from the agent directory's static provider/auth config (the model ID may contain slashes). Unknown, malformed, or unresolved models fail without fallback. |
| `thinking` | No | Defaults to the parent's level. Accepts `off`, `minimal`, `low`, `medium`, `high`, `xhigh`, or `max`. User instructions take precedence; lower levels suit bounded, low-risk, easily verified work (not exploration categorically). The SDK clamps unsupported levels; missing both parent and requested levels fails explicitly. |

## When to delegate

- **Delegate** when investigation, diagnosis, scoped implementation, or verification will produce large intermediate context but a concise, reviewable handoff. The solution need not be known up front.
- **Keep in parent** for simple lookups, small edits, frequent back-and-forth, or work requiring the parent's raw reasoning context or exclusive tools (MCP, parent extensions, dynamic providers).
- **Do not duplicate** a delegated investigation in the parent.

## Writing the `task` brief

Supply everything the child needs in one prompt, and let the child choose its method unless a specific approach is required:

- **Goal & context**: relevant facts, exact file paths, and symbols.
- **Scope & non-goals**: what is in bounds and what to leave untouched.
- **Write boundaries**: explicitly state read-only or allowed write paths; require preserving unrelated changes and avoid overlapping writes across parallel calls.
- **User constraints & approvals**: carry required constraints and approvals into `task`.
- **Verification & deliverable**: acceptance checks, required evidence, and desired output format (direct answer, findings list, comparison table, change report, strict JSON, or Pi compact-style summary when useful).

## Child environment and limits

- **Execution model**: Synchronous and one-shot. Multiple `subagent` calls in the same assistant turn run in parallel; each gets its own tool block, activity stream, and child session file. There is no follow-up/resume API, cross-turn background work, nested delegation, or total runtime/token/cost cap.
- **Available tools**: Explicitly limited to `read`, `write`, `edit`, `bash`, and `codemode` (each child initializes its own SDK `codemode` over those file/shell tools). Search and directory listing use `bash` rather than separate `grep`/`find`/`ls` tools.
- **Inherited**: Working directory, filesystem, shell environment (installed commands can still access the network through `bash`), and project trust. The child loads project guidance, `SYSTEM`/`APPEND_SYSTEM.md`, and skills independently. Background cache warming is disabled via scoped in-memory settings without modifying user configuration.
- **Not inherited**: Parent conversation, parent extensions, MCP tools, permission hooks, runtime-only credentials, and dynamic providers or routers (including extension-registered classifier or image models not in static config). Independently loaded guidance or skills may mention unavailable tools or hooks; the child's handoff prompt warns about this explicitly.
- **Safety**: Context isolation is not a filesystem or network sandbox. File modifications persist after cancellation, and delegation must never bypass required approvals.

## Handoff and failures

- **What returns**: Only the final handoff enters the parent's context. A format requested in `task` takes precedence, with no runtime annotations appended on success. Without a format request, the child returns a concise, outcome-first handoff with evidence, validation results, uncertainties, and genuine remaining work (omitting empty sections).
- **No hidden post-processing**: The child writes the handoff directly—there is no extra summary model call or output-schema validator. Validate structured output before consuming it.
- **Size and failure semantics**: Handoffs over `24,000` UTF-8 bytes and incomplete model responses fail with a child-session reference rather than silently truncating into apparent success. Error diagnostics are bounded and return diagnostic text, not necessarily the requested output format.
- **Verification**: A successful return means a complete handoff was produced, not that its claims are verified; the parent must check evidence and changes before relying on them.

## UI, persistence, and cancellation

- **Display (`Ctrl+O`)**: Uses Pi's codemode-style tool block with request, live activity, result, and `Elapsed`/`Took` (including failures, cancellation, and restored sessions), separated by blank lines. Collapsed view shows 10 visual request lines, up to 8 calls (running first, then recent completed), and 5 visual result lines; expanded view shows full request, retained parameters, live-updating thinking text, and full handoff. The child model is shown alongside `Thinking` and `Elapsed`/`Took` only when it differs from the parent; model and thinking adjustments stay in UI metadata and are not appended to the handoff. Child tool calls can run in parallel; activity reports total running calls, including any hidden by display/history limits.
- **Metadata retention**: UI metadata keeps up to `64` calls (`2,048` argument characters per call) and `4 KiB` of UTF-8 thinking text per segment without splitting characters (`256 KiB` ceiling across 64 activities, vs. Pi's `50 KiB` / `2,000`-line general output limit), marking eviction and truncation explicitly. Raw tool results are not copied into parent metadata; thinking is UI metadata rather than part of the handoff, and older status-only records cannot recover unretained text.
- **Session files**: Full child sessions persist under `<agentDir>/sessions/subagents/` (path shown in expanded output). They can contain sensitive tool data and thinking, and are not automatically deleted.
- **Cancellation & usage**: Cancellation cooperatively aborts the child, waits for shutdown, and disposes it; a tool ignoring cancellation can delay shutdown. The final tool result rolls up child usage from all persisted session entries (including failed attempts, retries, tool usage, and compaction summaries, counted once each) into parent session totals, subject to what the SDK/provider reports.

## Tests

Run `npm test` from this directory after `npm ci`. Tests run real SDK parent and child sessions against a local HTTP fixture provider, covering context isolation, untrusted resources, cancellation, failure, and output limits without live credentials.
