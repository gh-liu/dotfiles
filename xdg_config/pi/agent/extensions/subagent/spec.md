# Pi Subagent Extension Specification

- Status: Active
- Updated: 2026-09-10

## 1. Product model

The extension provides isolated Pi execution for bounded delegated work. Its default surface is a one-shot task tool; reusable sessions are an advanced, separately registered surface. Its public model is:

> one bounded task by default; one reusable conversation only for an intentional workstream

The parent delegates only when context isolation, independent review, exploratory QA, or parallel ownership has a concrete benefit. A coherent implementation, routine self-review, exact lookup, trivial edit, or serial handoff stays in the parent. `subagent` returns one final handoff and disposes its controller. Reusable workstreams require the opt-in `subagent_session` tool; the parent sends only unresolved gaps, new evidence, and the next expected action to the same `#N`, then closes it after acceptance. Independent tasks run in parallel through Pi's native parallel tool calls. The extension is not a workflow engine, durable queue, permission broker, autonomous team, or security sandbox.

The bundled roles are intentionally small:

- `scout`: read-only local and web investigation
- `reviewer`: read-only review, expert judgment, and tradeoff resolution
- `worker`: implementation and focused validation
- `tester`: verification and browser QA

## 2. Public tool contract

The default `subagent` tool has two required fields and no lifecycle controls:

```ts
subagent({ agent, task })
```

- It creates fresh child context, executes one foreground turn, waits for authoritative settlement, returns the final handoff without a ref, and closes the controller.
- It has no `action`, `mode`, `background`, `ref`, or `waitMs`. Independent one-shot tasks run concurrently through parallel tool calls.
- Routing policy has one source of truth in `AGENTS.md`. The tool description states its operational boundary and role catalog; it does not inject duplicate prompt snippets or guidelines.

When `settings.json` contains `subagent.sessions.enabled:true`, the extension additionally registers the advanced control plane:

```ts
subagent_session({ action: "open", agent, task, background? })
subagent_session({ action: "send", ref, task, background? })
subagent_session({ action: "get", ref?, waitMs? })
subagent_session({ action: "cancel", ref })
subagent_session({ action: "close", ref })
```

- `open` creates a reusable session and exposes `#N`; `send` starts another turn in an idle session while preserving conversation and controller.
- Background execution is session-only. It returns after acceptance and sends an at-most-once completion wake after settlement.
- `get(ref)` returns the current session and latest-turn projection. `get()` lists only each retained session's ref, agent, and state so a large catalog cannot flood model context. `waitMs` is observational: expiry returns `timedOut:true` and never interrupts work. The parent does not poll with repeated `get` calls; it relies on completion wakes, or uses one bounded `get` wait when explicit waiting is necessary.
- `cancel` stops only an accepted active turn. The session becomes idle and can receive another `send`. `get`/`cancel`/`close` on an unknown or expired ref return `isError:true` with `unknown:true`; repeats on a known idle/closed session stay idempotent successes.
- `close` interrupts active work if necessary, destroys the controller, removes live UI, releases the session, and returns only its ref, agent, and terminal state. It is idempotent for a resolved session. Close is bounded by a single 5-second deadline covering controller readiness, interruption, and controller disposal; on timeout the session reports `crashed` and disposal continues best-effort in the background. A timed-out active turn keeps its capacity slot quarantined until authoritative settlement, so actual execution can never exceed `maxConcurrentRuns`; a timeout with no active turn releases its slot immediately.
- Turns have no elapsed execution deadline. They settle naturally, through explicit cancel/close, parent abort, shutdown, or provider/controller failure.
- Independent work is expressed as parallel `subagent` calls. Sequencing and handoff composition remain visible in the parent rather than hidden in a DAG API.

Only `subagent_session` exposes a session-local `#N`. One-shot tasks expose no ref. UUIDs, operation IDs, tool-call IDs, transcript paths, revisions, process IDs, renderer timelines, and bare indexes are internal. Session refs increase monotonically and are never reused while the extension instance is loaded; they are memory-only and cannot reconnect after restart.

## 3. Task, context, and result

`task` is plain text. It should contain only information the fresh child needs: desired outcome, relevant paths/evidence, constraints, and expected result. There are no public structured prompt fields. Applicable project guidance is appended internally on the initial turn; session sends rely on the preserved conversation and current task.

Children do not inherit the parent transcript, skills, prompt templates, themes, context files, or extensions. Their tool allowlist comes from the selected agent definition. They are leaves (`maxDepth=1`) and cannot delegate or message peers.

The child prompt is natural language, never a serialized JSON envelope: task objective, working-directory constraint, instructions, initial-turn project guidance, and the expected Summary/Changes/Evidence/Validation/Risks handoff format. The agent definition travels in the session `systemPrompt`; guidance is rendered as prompt prose. `SubagentWorkOrder` remains the internal envelope; only the rendering layer changed.

The production entrypoint discovers only user-scope agents (`~/.pi/agent/agents`). Project-local agents are explicitly unsupported: there is no model-facing scope parameter, no project-trust bypass, and no confirm escape hatch. Programmatic directory, settings, controller, timeout, and ID overrides are internal dependency-injection seams for deterministic tests, not product scope. A child cwd outside the allowed root is rejected.

Authoritative controller settlement owns turn status; completion never depends on child JSON. Plain final assistant text is a valid summary. Markdown sections named Summary, Changes, Evidence, Validation, and Risks are projected when present. Model-facing envelopes and displayed text, including startup, cancellation, and close errors, are bounded and redact configured credential values. Renderer details may retain a bounded activity timeline, but a recursive model projection strips that timeline and every internal identity before serialization. Tool activity does not replace preceding thinking entries: thinking is flushed into the ordered timeline at tool boundaries. The timeline retains the newest 24 activity entries by design, and its earlier-activity count includes only tool calls no longer visible in that timeline.

## 4. Lifecycle and capacity

```text
task:     starting ─▶ running ─▶ settled ─▶ closed

session:  starting ─▶ running ─▶ idle ─▶ running ─▶ idle ─▶ closed
                         │                    │
                         ├─ cancel ─▶ idle    └─ child result (completed/failed/interrupted) ─▶ idle
                         └─ controller/provider/protocol failure ──────────────────────────▶ crashed
             startup/cleanup failure ─────────────────────────────────────────────────────▶ crashed
```

A capacity slot is reserved before controller creation and held only while a turn is starting or running. A one-shot task closes immediately after settlement; session settlement releases the slot without closing its controller. Idle sessions preserve context but consume no execution capacity. `maxConcurrentRuns` is configurable from 1 through 8 and defaults to 3. At most 100 open reusable sessions and 128 operations per session are retained in memory.

Controller creation has a bounded startup timeout so a provider that never constructs a controller cannot leak capacity. Explicit interruption has a bounded settlement watchdog. Neither bound is an execution deadline. Operation pruning never evicts the active operation or the last settled record, and the settle audit always carries `operationId`/`turn`/`ref`.

Structured control-plane failures carry `details.error`; a child-settled foreground failure carries `turnStatus:"failed"`. Both surface as `isError:true` in direct and live tool-result pipelines, covering invalid parameters, unknown agents or refs, unavailable capacity, startup/controller failures, and failed foreground turns while preserving recovery details for the parent.

All error, cancel, close, crash, and shutdown paths best-effort close owned resources and release held slots. Shutdown rejects new work, suppresses wakes (never the audit trail), closes all sessions, clears timers, and disposes live UI. A controller failure that lands while the close path owns the session is ignored so a successfully closed session can never flip to `crashed`.

## 5. Notifications and UI

Default tasks have one visual owner: their transcript tool row updates from current sanitized activity to the final handoff. Opt-in sessions additionally support background turns and the activity center. Transcript rows use colored status glyphs rather than full-width status backgrounds. Expanding a foreground row reveals the bounded mixed timeline. The expanded activity region distinguishes active thinking as `✦ Thinking` from settled thinking as `✓ Thinking`, and renders earlier-count, thinking, completed/failed tools, and active tools at one consistent indentation level. Raw reasoning, tool-call IDs, and tool output are never rendered.

The above-editor activity center owns only accepted background turns after their tool call returns. It is a compact session dashboard headed by running/ready counts, with at most one row per reusable session: accepting a newer turn replaces any unacknowledged older-turn row for that `#N`. Rows are keyed internally by operation and display the session's `#N`, agent, monotonic `turn N`, elapsed time, one bounded task line, and only the latest sanitized activity. It shows at most four sessions; recovery failures and ready results sort before active work, and overflow points to `get`. A settled latest operation remains `ready · get #N` until Pi emits `message_start` for that exact completion card; queuing `sendMessage` is not treated as delivery acknowledgement. Late acknowledgements for superseded operations cannot remove the current row. Delivery failure leaves a recoverable `delivery failed · get #N` row. Narrow layouts retain identity, task, and recovery instructions while dropping the activity line below 40 columns.

Wake routing follows parent busyness: background completion wakes are custom messages with `customType: "subagent-operation-settled"` (exported in code as `SUBAGENT_COMPLETION_MESSAGE`, the single source of truth). Idle parents receive `sendMessage({ triggerTurn: true })` immediately, while busy parents receive the same wake queued as `deliverAs: "followUp"`. `steer` is never used. Auditing (`subagent-settle-log` with `jobId`/`operationId`/`turn`/`ref`/`agent`/`status`) and waking are tracked separately with per-operation at-most-once guards: shutdown and close suppress queued wakes but never the audit. Closing a session drops its queued wakes so a closed session never emits `triggerTurn`. Event-driven widget updates are throttled to 100 ms (leading + trailing, bursts coalesce); the elapsed-time/spinner repaint clock stays at 250 ms.

Foreground settlement returns a result-first handoff in the tool result. A one-shot task shows only its outcome, duration, and handoff; it has no ref, turn, mode, or reuse footer in the model-facing result, and its controller is already closed. A session turn also has an actionable `send #N or close #N` footer. Background completion cards exist only for sessions and have no adjacent invocation row, so their header shows `#N`, agent, turn, operation lineage (`initial` or `follow-up`), outcome, and duration exactly once; follow-up cards use a `↳` continuation marker. Collapsed cards show one bounded `task` line before the result so repeated or generic failure summaries remain distinguishable, and normalize the stock controller interruption reason to `controller stopped this turn`. A true multi-operation notification is headed by `Subagents · N turns settled`. Session cards expose reuse actions only when the runtime is truly idle and mark closed or crashed sessions unavailable; a crashed result suggests starting a new role session. A card acknowledgement removes only its operation row, never another turn sharing the same public ref.

Tool invocation rows are durable, background-free records. Collapsed rows show the actual agent, full `provider/model`, thinking-level value colored with Pi's matching thinking-level theme color, and task title. Default task rows never acquire a session ref or display lifecycle mode. An expanded task row shows only the bounded task. Session `send` uses a `↳` continuation marker, resolves the session's registered agent rather than a generic action label, and shows its turn once authoritative progress arrives.

## 6. Isolation and credentials

Fresh context is conversation isolation, not a security sandbox. In-process children share OS credentials and filesystem permissions. Canonical cwd containment fixes the child working directory to the project boundary, but it is not filesystem isolation. Tool allowlists are capability guidance, not OS permissions.

`credentialRedactionEnvNames` names environment values to redact from output; it does not control environment forwarding. The deprecated `authEnvAllowlist` option and `PI_SUBAGENT_AUTH_ENV_ALLOWLIST` setting remain compatibility aliases. Redaction is best-effort and is not credential isolation.

## 7. Validation contract

Deterministic tests cover the two-field task schema, default absence of the session tool, one-shot execution and automatic cleanup, opt-in session execution, agent discovery/model selection, fresh context construction, bounded handoffs, foreground and background session turns, session reuse, cancellation followed by reuse, close idempotence, compact session listing, idle capacity release, capacity exhaustion, consistent live error signaling, notifications and recovery, UI projections, startup/controller failures, unbounded turn duration, concurrent shutdown, redaction, and the absence of internal IDs and renderer timelines in model-facing payloads. Live evaluations use prompts that do not name `subagent` or a bundled role when measuring implicit tool and role selection; scenarios that specifically exercise lifecycle action sequences may remain explicit.

Required gates are strict TypeScript checks and the complete Vitest suite. Low-cost real Pi smoke tests should verify both conservative routing (simple parent-owned work does not delegate) and one bounded task handoff when provider credentials are available. Session lifecycle evals explicitly enable `subagent.sessions.enabled` in their isolated config.
