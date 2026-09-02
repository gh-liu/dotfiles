# Pi Subagent Extension Specification

- Status: Active
- Updated: 2026-08-31

## 1. Goal and non-goals

The extension delegates bounded tasks to fresh-context Pi SDK sessions and returns bounded handoffs. It also coordinates bounded declarative DAG workflows over those same one-shot runtimes. The parent owns graph decomposition, write coordination, handoff review, integration, final validation, and the user response. It is not a durable queue, restart-resumable supervisor, permission broker, autonomous team, or security sandbox.

## 2. Public tool contract

`subagent` has one provider-compatible root object schema and four actions:

```ts
subagent({ action: "run", agent, objective, scope?, constraints?, acceptance?, context?, cwd?, background?, exclusivePaths?, toolBudget? })
subagent({ action: "workflow", objective, nodes, background? })
subagent({ action: "get", jobId?, waitMs? })
subagent({ action: "cancel", jobId })
```

- `run` requires `agent` and `objective`. Structured fields are rendered into a self-contained work order. `background` defaults to false. Runs have no elapsed-time execution deadline; they settle naturally or through explicit cancellation, parent abort, tool-budget interruption, shutdown, or provider/controller failure.
- `exclusivePaths` (optional) lists at most 50 paths this job writes exclusively, absolute or relative to the child cwd; overlapping leases (identical, ancestor, or descendant) are rejected in-process before the run starts. `toolBudget` (optional) is a positive-integer worker-side hard tool budget; the operation aborts once its tool executions exceed the limit. Both are v1 and bounded by the parent model: the extension does not intercept parent tool calls and cannot stop `bash` (or any other writer) from touching leased paths, so single-writer still requires the parent to honor the fields.
- Foreground `run` waits for authoritative `agent_settled`, disposes the SDK session, releases its slot, and returns a handoff.
- Background `run` returns `{jobId,ref,status,agent}` after prompt acceptance. Settlement wakes the parent, then automatically disposes the session and releases its slot. Background does not imply persistence.
- `workflow` requires a workflow `objective` and 1–20 nodes. Each node requires a stable lowercase `id`, registered `agent`, and bounded `objective`; optional fields mirror structured `run` inputs plus `dependsOn` and `runOnDependencyFailure`. Workflows and nodes have no elapsed-time execution deadline. The graph must be acyclic, all dependencies must exist, and node IDs must be unique. Independent ready nodes run in parallel subject to shared runtime capacity. `dependsOn` is a barrier: a node starts only after all direct dependencies settle.
- A downstream node receives the workflow objective, its own context, and bounded structured handoffs from direct predecessors. It never receives raw child transcripts or the parent transcript. The common `scout/researcher → oracle → worker → tester/reviewer` pattern is one ordinary graph, not hard-coded coordinator behavior.
- Dependency failure skips downstream nodes by default. `runOnDependencyFailure:true` allows an explicit diagnostic/recovery node to run after failed, interrupted, or skipped dependencies settle. There are no loops, retries, dynamic node creation, recursive child delegation, peer messages, or model-authored graph mutation during execution.
- Foreground `workflow` waits for all reachable nodes and returns a bounded node snapshot. Background `workflow` returns `{workflowId,ref,status,nodes}` after graph validation and scheduler start, then emits exactly one workflow-level completion wake; internal nodes never emit background wakes. Workflow refs use a distinct monotonic `W#N` namespace.
- `get(jobId)` immediately returns current/terminal job or workflow state. Job diagnostics include effective work order, elapsed time, latest activity, recent redacted activity, and pending decision. Workflow diagnostics include every node's dependency/status/ref and terminal handoff/error. `waitMs` waits at most that long. A running record whose wait expires returns `timedOut:true` without cancellation; otherwise that field is absent. `get()` lists up to 100 most-recent jobs and workflows. Missing retained records return `status:"unknown",expired:true` rather than pretending the work settled.
- `cancel(jobId)` is idempotent for both jobs and workflows. Job cancellation derives and guards the active internal operation. Workflow cancellation aborts pending scheduling, interrupts active node runtimes, waits for graph settlement, and skips nodes that never started. Responses separate command outcome (`cancelled`) from authoritative status; unknown records return `status:"unknown",unknown:true`, while already-terminal records preserve their real status.

`jobId` is the canonical one-shot execution identity. Every runtime also receives an ergonomic runtime-local `ref` (`#N`); every workflow receives a canonical `workflowId` and `W#N` ref. Both ref sequences increase monotonically and are never reused within the loaded extension instance. `get` and `cancel` accept canonical IDs or refs; one-shot jobs additionally accept numeric `N`. Aliases are memory-only and cannot be recovered after restart. Responses include public identities when resolved, while operation IDs, process instance IDs, revisions, run IDs, and a bare `index` are implementation details absent from model-facing responses. UUID-like input is never echoed in terminal labels while resolution is pending. The registered-agent catalog is included in the tool description; there is no public list action.

## 3. Work order and handoff

The child receives objective, scope, constraints, acceptance criteria, optional context, canonical cwd, fixed runtime constraints, and applicable `AGENTS.md` guidance. It does not inherit the parent transcript or skills.

The authoritative controller result owns status and transcript identity; task completion never depends on child JSON. Plain final assistant text is always a valid fallback summary. Foreground model-facing handoffs contain `jobId`, `ref`, `agent`, `status`, bounded `summary`, optional elapsed time, and transcript reference. Markdown headings `Summary`, `Changes`, `Evidence`, `Validation`, and `Risks` (levels 1–3, case-insensitive) are extracted into typed fields; absent headings retain the complete plain text as the summary fallback. The complete serialized envelope, including every extracted section, is bounded to 16,000 characters.

## 4. Job state machine and ownership

```text
starting -> running -> completed | failed | interrupted
                    \-> cancel -> interrupted
```

Internal runtime states remain `starting/running/idle/closing/closed/crashed`; internal operation settlement is authoritative and monotonic. Foreground and background are both one-shot jobs. Slots are reserved before controller creation; `settings.json` groups runtime capacity and agent overrides under `subagent`: `maxConcurrentRuns` accepts an integer from 1 through 8 (default 3 when omitted or invalid), and `subagents[agent]` supplies per-agent overrides. Every terminal/error/shutdown path releases its slot after disposal. Children are leaves (`maxDepth=1`) and cannot message peers.

Workflow node states are `pending → running → completed | failed | interrupted`, with `pending → skipped` for dependency failure, cancellation, or shutdown. Workflow state is `running → completed | failed | interrupted`. The coordinator owns only graph scheduling and bounded handoff projection; every running node still follows the existing `RuntimeHub` create/accept/settle/close lifecycle, capacity slot, exclusive lease, cancellation, progress, and live-UI path. A node never bypasses or duplicates runtime ownership.

Exclusive write leases (`exclusivePaths`) follow the same lifecycle as slots: normalized against the child cwd and acquired before controller creation, then released by the same terminal/error/shutdown close path (settle, cancel, crash, and shutdown all release). Any identical, ancestor, or descendant overlap with an active lease rejects the new run. Leases are v1 and in-process only: they are not OS file locks, they exist only for the current extension process, and they do not hard-block any writer, so a single writer still requires the parent to comply.

## 5. Notifications and recovery

Background job settlement sends a bounded follow-up wake and appends a best-effort human audit entry. The live panel first freezes the row in a reporting state; it removes the row only after Pi accepts the completion message. Delivery failure never changes authoritative state and leaves `#N · settled · reporting failed · use get` visible as a recovery affordance. Retrieving that terminal job clears the recovery row. `get("#N")` (or canonical jobId/numeric N) retains the handoff regardless of notification success. Same-turn successful job settlements may be batched; actionable failures notify immediately. A background workflow suppresses node-level wakes and sends one `W#N` wake after graph settlement. Pending notification timers are flushed/cleared during shutdown.

## 6. Resource retention and shutdown

Runtime, operation, and workflow records are memory-only. Each runtime retains at most 128 operations; the hub retains at most 100 terminal runtimes per parent session; the coordinator retains at most 100 terminal workflows. Older records are pruned. Controller creation has a 10-second hard bound; interrupt settlement has a 5-second bound. Shutdown rejects new jobs/workflows, aborts running graphs, suppresses wakes, closes all owned sessions with bounded startup waiting, clears notification timers, disposes live UI, and releases slots.

Child JSONL transcripts under `<agent-dir>/subagent-sessions/<jobId>/` are durable evidence but are not reconnectable jobs. Transcript disk GC is intentionally outside this in-memory extension boundary; `sessionRoot` is an explicit SDK configuration seam for an external TTL/count maintenance policy.

## 7. Executor and fresh context

Production keeps the existing in-process `createAgentSession` executor, dedicated `SessionManager`, authoritative event reducer, explicit-cancellation abort watchdogs, progress reduction, transcript, and `RuntimeHub`. Resource loading disables implicit extensions, skills, prompt templates, themes, and context files; tools are explicit per agent definition.

Fresh context is conversation isolation, **not a security sandbox**. In-process children share OS credentials and filesystem permissions. Canonical cwd containment prevents selecting a cwd outside the project root, but cwd is **not a file-access sandbox**. Tool allowlists are capability controls, not OS permissions.

`toolBudget` is a worker-side abort, not a CPU/time guarantee: the executor counts `tool_execution_start` events and aborts exactly once the count exceeds the budget, yielding an `interrupted` result whose diagnostic summary retains the exceeded count and the limit. A non-positive or non-integer `toolBudget` is rejected up front.

`credentialRedactionEnvNames` names environment variables whose values are redacted from output; it does not allow, filter, or forward environment variables. The deprecated `authEnvAllowlist` option and `PI_SUBAGENT_AUTH_ENV_ALLOWLIST` setting remain low-cost compatibility aliases only. Redaction is best-effort and is not credential isolation.

## 8. Errors

Invalid/missing input, malformed/cyclic graphs, unknown agents, escaped cwd, one-shot capacity exhaustion, startup timeout, and provider/controller failures return bounded tool errors. A validated workflow waits for shared capacity instead of failing merely because another job currently occupies a slot. Cancellation follows authoritative settlement. A wait timeout is an observational non-error and never interrupts work. Cleanup errors mark the internal runtime crashed but still release capacity. No failure fabricates a completed result.

## 9. Validation contract

Agent definitions are discovered once at startup; malformed definitions are reported, settings overrides win over parent-model inheritance, and settings defaults are the final model fallback. Catalog and prompt snippets are bounded and include every effective registered agent.

Progress summaries, completion cards, errors, and model handoffs have hard text/envelope bounds. Foreground and background activity has one transient owner: the above-editor activity center. It starts before controller creation, orders decision requests ahead of ordinary work, and renders a job-level spinner, `#N`, agent, elapsed time, up to two objective lines on wide terminals (one when compact), and only the latest activity. Completed thinking remains the generic `✓ Thinking` activity; raw reasoning never renders. Narrow layouts preserve the actionable ref and decision/recovery instruction before optional metadata. With more than three tracked jobs the center switches to dense two-line rows, omits ordinary activity, shows at most five priority-sorted jobs, and reports the overflow with a `get` affordance. Tool rows are durable invocation records with the effective ref once known; partial rows only point to the activity center and never duplicate its timeline or spinner. Foreground terminal handoffs remain tool results. Background terminal handoffs are result-first completion cards: summary is visible by default, internal identifiers stay hidden, `#N` is a low-priority recovery affordance, and Objective/Summary/Changes/Evidence/Validation/Risks appear on expansion. Failed/interrupted cards retain the newest eight redacted activity summaries. `get #N` is the bounded running/detail diagnostic view. Tool-call IDs deduplicate updates; tool completion moves the item from active to history. Tool summaries are redacted, single-line, and bounded (including a command preview for `bash`); model text/reasoning is never tool history.

Activity is also retained as a bounded, event-ordered `timeline` for executor observability and diagnostics. It is an ordered array interleaving tool calls and thinking segments in the order they occur: tool entries carry `{kind:"tool", id, summary, status}` (appended when the call completes, `status` `completed`/`failed`), and thinking entries carry `{kind:"thinking", text}`. Consecutive thinking deltas merge into a single segment that is flushed only at a boundary (next tool execution or message end), preserving ordering without an entry per delta. The live timeline keeps only the newest 24 entries. The activity center renders only the current bounded projection rather than duplicating history in the tool row. Active reasoning is `Thinking…`; a flushed segment is `✓ Thinking`; raw reasoning text never reaches the UI. A sanitized projection may cross into `get` diagnostics or failed/interrupted completion cards as the literal `Thinking` marker alongside redacted tool summaries; it is never authoritative result content. Public job payloads use canonical `jobId` plus runtime-local `ref`; internal operation, process, revision, run, and bare index fields never cross that boundary. Renderer-only details may carry `displayIndex` and `toolProgress`, but model content uses `ref` rather than a bare index.

The controller/runtime progress seam accepts an optional bounded decision request (`needsDecision: true` plus `decision {question, options?}`) and forwards it into live update `details` only when it carries a non-empty `question`; the question is redacted/bounded like other progress text, options are trimmed, bounded, and capped at eight, and an all-invalid or absent option list emits no `options` key. Empty or invalid payloads never pollute the public details. The production SDK event reducer does not currently originate decision requests, so this is an internal transport seam rather than an end-to-end child capability. Decision handling (fork, pause/steer, permission/review flows) is not implemented. usage/timing accounting is explicitly out of scope / not required and is not a claimed, promised, or pending item.

Background notifications are at-most-once per settlement (same-turn successes may batch; failures flush immediately). Delivery is best-effort and `get(jobId)` always remains the authoritative recovery path. Controller ordering is create, accept, authoritative settle, then close/release; rejection, cancellation (including rejected interrupts), crashes, cleanup failures, and shutdown all best-effort close and release capacity.

The deterministic test map covers discovery/model selection and context budgets; schema/work orders/public projection; foreground/background rendering and timer cleanup; handoff/output bounds; notification batching/recovery/suppression; capacity reservation/release/factory rejection; controller acceptance/settlement/close ordering; concurrent/reentrant shutdown, failures, transcript preservation, unbounded elapsed execution, and cancellation cleanup; exclusivePaths lease acquisition, overlap rejection (identical/ancestor/descendant), sibling/absolute-path acceptance, and release on settle/cancel/crash; toolBudget abort-once/within-budget/non-positive rejection; and workflow validation, parallel roots, dependency barriers, structured predecessor handoffs, fan-out, shared-runtime execution, failure skipping/consumption, background get/cancel, and single workflow-level notification. Required gates are strict subagent typecheck and the complete subagent Vitest suite.
