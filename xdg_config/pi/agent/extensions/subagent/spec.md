# Pi Subagent Extension Specification

- Status: Active
- Updated: 2026-09-02

## 1. Product model

The extension provides reusable, isolated Pi sessions for bounded delegated work. Its public model is:

> one agent, one task, one visible lifecycle, reusable conversation

The parent decides whether to delegate, starts independent sessions in parallel when useful, supplies prior handoffs in later tasks when coordinating agents, inspects changes, integrates results, validates the whole outcome, and answers the user. The extension is not a workflow engine, durable queue, permission broker, autonomous team, or security sandbox.

The bundled roles are intentionally small:

- `scout`: read-only local and web investigation
- `reviewer`: read-only review, expert judgment, and tradeoff resolution
- `worker`: implementation and focused validation
- `tester`: verification and browser QA

## 2. Public tool contract

`subagent` has five actions and one public identity, the session-local `#N` ref:

```ts
subagent({ action: "run", agent, task, background? })
subagent({ action: "followup", ref, task, background? })
subagent({ action: "get", ref?, waitMs? })
subagent({ action: "cancel", ref })
subagent({ action: "close", ref })
```

- `run` creates a fresh session for a registered agent and starts its first turn.
- `followup` starts another turn in an idle session, preserving its conversation and controller.
- Foreground turns wait for authoritative settlement. Background turns return after acceptance and send an at-most-once completion wake after settlement.
- `get(ref)` returns the current session and latest-turn projection. `get()` lists only each retained session's ref, agent, and state so a large catalog cannot flood model context. `waitMs` is observational: expiry returns `timedOut:true` and never interrupts work.
- `cancel` stops only an accepted active turn. The session becomes idle and can receive another followup.
- `close` interrupts active work if necessary, destroys the controller, removes live UI, releases the session, and returns only its ref, agent, and terminal state. It is idempotent for a resolved session.
- Turns have no elapsed execution deadline. They settle naturally, through explicit cancel/close, parent abort, shutdown, or provider/controller failure.
- Independent work is expressed as parallel `run` calls. Sequencing and handoff composition remain visible in the parent rather than hidden in a DAG API.

Only `#N` crosses the model-facing boundary. UUIDs, operation IDs, tool-call IDs, transcript paths, revisions, process IDs, renderer timelines, and bare indexes are internal. Refs increase monotonically and are never reused while the extension instance is loaded; they are memory-only and cannot reconnect after restart.

## 3. Task, context, and result

`task` is plain text. It should contain only information the fresh child needs: desired outcome, relevant paths/evidence, constraints, and expected result. There are no public structured prompt fields. Applicable project guidance is appended internally on the initial turn; followups rely on the preserved conversation and current task.

Children do not inherit the parent transcript, skills, prompt templates, themes, context files, or extensions. Their tool allowlist comes from the selected agent definition. They are leaves (`maxDepth=1`) and cannot delegate or message peers.

Authoritative controller settlement owns turn status; completion never depends on child JSON. Plain final assistant text is a valid summary. Markdown sections named Summary, Changes, Evidence, Validation, and Risks are projected when present. Model-facing envelopes and displayed text are bounded and redact configured credential values. Renderer details may retain a bounded activity timeline, but a recursive model projection strips that timeline and every internal identity before serialization.

## 4. Lifecycle and capacity

```text
session:  starting ─▶ running ─▶ idle ─▶ running ─▶ idle ─▶ closed
                         │                    │
                         └─ cancel ─▶ idle    └─ failure ─▶ idle
             startup/cleanup failure ─────────────────────▶ crashed
```

A capacity slot is reserved before controller creation and held only while a turn is starting or running. Settlement releases the slot without closing the session. Idle sessions preserve context but consume no execution capacity. `maxConcurrentRuns` is configurable from 1 through 8 and defaults to 3. At most 100 open sessions and 128 operations per session are retained in memory.

Controller creation has a bounded startup timeout so a provider that never constructs a controller cannot leak capacity. Explicit interruption has a bounded settlement watchdog. Neither bound is an execution deadline.

All error, cancel, close, crash, and shutdown paths best-effort close owned resources and release held slots. Shutdown rejects new work, suppresses wakes, closes all sessions, clears timers, and disposes live UI.

## 5. Notifications and UI

Foreground and background turns have separate visual owners. A foreground tool result shows the current bounded activity plus the complete retained lifecycle: completed thinking segments as `✓ Thinking`, completed/failed tools in chronological order, and every currently active tool. Raw reasoning, tool-call IDs, and tool output are never rendered.

The above-editor activity center owns only accepted background turns after their tool call returns. Rows are keyed internally by operation, although only `#N` is displayed, so an older completion and a newer followup in the same session cannot overwrite each other. Each row shows its ref, agent, elapsed time, bounded task, and latest sanitized activity. A background settlement remains `result ready · awaiting card · get #N` until Pi emits `message_start` for that exact completion card; queuing `sendMessage` is not treated as delivery acknowledgement. Delivery failure leaves a recoverable `card failed · get #N` row. Dense and narrow layouts prioritize refs, decisions, and recovery instructions.

Foreground settlement returns a result-first handoff in the tool result. Completion cards also show the result first. Both show `session open · follow-up or close` only when the runtime is truly idle; closed or crashed sessions are unavailable. A card acknowledgement removes only its operation row, never another turn sharing the same public ref.

Tool invocation rows are durable records. Collapsed rows show the actual agent or action plus task title; expanded rows show the bounded task. A followup resolves and displays the session's registered agent rather than a generic action label.

## 6. Isolation and credentials

Fresh context is conversation isolation, not a security sandbox. In-process children share OS credentials and filesystem permissions. Canonical cwd containment fixes the child working directory to the project boundary, but it is not filesystem isolation. Tool allowlists are capability guidance, not OS permissions.

`credentialRedactionEnvNames` names environment values to redact from output; it does not control environment forwarding. The deprecated `authEnvAllowlist` option and `PI_SUBAGENT_AUTH_ENV_ALLOWLIST` setting remain compatibility aliases. Redaction is best-effort and is not credential isolation.

## 7. Validation contract

Deterministic tests cover agent discovery/model selection, fresh context construction, bounded handoffs, foreground and background turns, session reuse, cancellation followed by reuse, close idempotence, compact session listing, idle capacity release, capacity exhaustion, notifications and recovery, UI projections, startup/controller failures, unbounded turn duration, concurrent shutdown, redaction, and the absence of internal IDs and renderer timelines in model-facing payloads.

Required gates are strict TypeScript checks and the complete Vitest suite. A low-cost real Pi smoke test should cover `run → followup` on the same ref → `close` before release when provider credentials are available.
