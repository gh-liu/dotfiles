# Pi Subagent Extension Specification

- Status: Active
- Updated: 2026-08-27

## 1. Goal and non-goals

The extension delegates bounded tasks to fresh-context Pi SDK sessions and returns a bounded handoff. The parent owns decomposition, write coordination, integration, final validation, and the user response. It is not a team/DAG scheduler, durable queue, restart-resumable supervisor, permission broker, or security sandbox.

## 2. Public tool contract

`subagent` has one provider-compatible root object schema and three actions:

```ts
subagent({ action: "run", agent, objective, scope?, constraints?, acceptance?, context?, cwd?, deadlineMs, background? })
subagent({ action: "get", jobId?, waitMs? })
subagent({ action: "cancel", jobId })
```

- `run` requires `agent`, `objective`, and `deadlineMs` (1,000–3,600,000 ms). Structured fields are rendered into a self-contained work order. `background` defaults to false.
- Foreground `run` waits for authoritative `agent_settled`, disposes the SDK session, releases its slot, and returns a handoff.
- Background `run` returns `{jobId,ref,status,agent}` after prompt acceptance. Settlement wakes the parent, then automatically disposes the session and releases its slot. Background does not imply persistence.
- `get(jobId)` immediately returns current/terminal state; `waitMs` waits at most that long. A running job whose wait expires returns `timedOut:true` without cancellation; otherwise that field is absent. `get()` lists up to 100 most-recent jobs.
- `cancel(jobId)` is idempotent. The hub derives and guards the active internal operation, interrupts it, waits for authoritative settlement, and closes it. Unknown/already-terminal jobs are successful no-ops described in the response.

`jobId` is the canonical execution identity. Every runtime also receives an ergonomic session-local `ref` (`#N`). `get` and `cancel` accept the canonical jobId, `#N`, or numeric `N`; exact jobId matching takes precedence. Aliases are memory-only and cannot be recovered after restart. Responses include both identities, while operation IDs, process instance IDs, revisions, run IDs, and a bare `index` are implementation details absent from model-facing responses. The registered-agent catalog is included in the tool description; there is no public list action.

## 3. Work order and handoff

The child receives objective, scope, constraints, acceptance criteria, optional context, canonical cwd, fixed runtime constraints, and applicable `AGENTS.md` guidance. It does not inherit the parent transcript or skills.

The authoritative controller result owns status and transcript identity; task completion never depends on child JSON. Plain final assistant text is always a valid fallback summary. Model-facing handoffs contain `agent`, `status`, bounded `summary`, optional elapsed time, and transcript reference. Markdown headings `Summary`, `Changes`, `Evidence`, `Validation`, and `Risks` (levels 1–3, case-insensitive) are extracted into typed fields; absent headings retain the complete plain text as the summary fallback. The complete serialized envelope, including every extracted section, is bounded to 16,000 characters.

## 4. Job state machine and ownership

```text
starting -> running -> completed | failed | interrupted
                    \-> cancel -> interrupted
```

Internal runtime states remain `starting/running/idle/closing/closed/crashed`; internal operation settlement is authoritative and monotonic. Foreground and background are both one-shot jobs. Slots are reserved before controller creation (maximum 3), and every terminal/error/shutdown path releases them after disposal. Children are leaves (`maxDepth=1`) and cannot message peers.

## 5. Notifications and recovery

Background settlement sends a bounded follow-up wake and appends a best-effort human audit entry. Delivery failure never changes authoritative state. `get("#N")` (or canonical jobId/numeric N) is the recovery path and retains the handoff regardless of notification success. Same-turn successful settlements may be batched; actionable failures notify immediately. Pending notification timers are flushed/cleared during shutdown.

## 6. Resource retention and shutdown

Runtime/operation records are memory-only. Each runtime retains at most 128 operations and the hub retains at most 100 terminal runtimes per parent session; older records are pruned. Controller creation has a 10-second hard bound; interrupt settlement has a 5-second bound. Shutdown rejects new jobs, suppresses wakes, closes all owned sessions with bounded startup waiting, clears notification timers, disposes live UI, and releases slots.

Child JSONL transcripts under `<agent-dir>/subagent-sessions/<jobId>/` are durable evidence but are not reconnectable jobs. Transcript disk GC is intentionally outside this in-memory extension boundary; `sessionRoot` is an explicit SDK configuration seam for an external TTL/count maintenance policy.

## 7. Executor and fresh context

Production keeps the existing in-process `createAgentSession` executor, dedicated `SessionManager`, authoritative event reducer, deadlines/abort watchdogs, progress reduction, transcript, and `RuntimeHub`. Resource loading disables implicit extensions, skills, prompt templates, themes, and context files; tools are explicit per agent definition.

Fresh context is conversation isolation, **not a security sandbox**. In-process children share OS credentials and filesystem permissions. Canonical cwd containment prevents selecting a cwd outside the project root, but cwd is **not a file-access sandbox**. Tool allowlists are capability controls, not OS permissions.

`credentialRedactionEnvNames` names environment variables whose values are redacted from output; it does not allow, filter, or forward environment variables. The deprecated `authEnvAllowlist` option and `PI_SUBAGENT_AUTH_ENV_ALLOWLIST` setting remain low-cost compatibility aliases only. Redaction is best-effort and is not credential isolation.

## 8. Errors

Invalid/missing input, unknown agent, escaped cwd, capacity exhaustion, startup timeout, and provider/controller failures return bounded tool errors. Deadline/cancel outcomes follow authoritative settlement. A wait timeout is an observational non-error. Cleanup errors mark the internal runtime crashed but still release capacity. No failure fabricates a completed result.

## 9. Validation contract

Agent definitions are discovered once at startup; malformed definitions are reported, settings overrides win over parent-model inheritance, and settings defaults are the final model fallback. Catalog and prompt snippets are bounded and include every effective registered agent.

Progress summaries, completion cards, errors, and model handoffs have hard text/envelope bounds. Partial tool rows render an operation-local lifecycle snapshot: up to eight completed/failed calls (`✓`/`✗`) plus current calls with a spinner, with an earlier-call count when truncated. Tool-call IDs deduplicate updates; tool completion moves the item from active to history. Tool summaries are redacted, single-line, and bounded (including a command preview for `bash`); model text/reasoning is never tool history. This renderer-only history is isolated per tool row, works for foreground/background updates, and is discarded in favor of the terminal handoff. Countdown ownership belongs exclusively to the live widget, not partial tool rows. Public job payloads use canonical `jobId` plus session-local `ref`; internal operation, process, revision, run, and bare index fields never cross that boundary. Renderer-only details may carry `displayIndex` and `toolProgress`, but model content uses `ref` rather than a bare index.

Background notifications are at-most-once per settlement (same-turn successes may batch; failures flush immediately). Delivery is best-effort and `get(jobId)` always remains the authoritative recovery path. Controller ordering is create, accept, authoritative settle, then close/release; rejection, cancellation (including rejected interrupts), crashes, cleanup failures, and shutdown all best-effort close and release capacity.

The deterministic test map covers discovery/model selection and context budgets; schema/work orders/public projection; foreground/background rendering and timer cleanup; handoff/output bounds; notification batching/recovery/suppression; capacity reservation/release/factory rejection; controller acceptance/settlement/close ordering; concurrent/reentrant shutdown, failures, transcript preservation, deadlines, and cancellation cleanup. Required gates are strict subagent typecheck and the complete subagent Vitest suite.
