# Pi Subagent Extension Specification

- Status: Active (Milestones 1 and 2 partial)
- Updated: 2026-08-21 — transport swapped from `pi --mode rpc` subprocess to in-process SDK sessions (`sdk-executor.ts` via `createAgentSession`); `rpc-executor.ts` retired. Same-day earlier: restored `settings.json` `subagents[agent]` overrides for effective `model`/`thinking`/`description`; catalog and `list` reflect the merged view

## 1. Background

Pi provides the primitives needed to build subagents—extensions, JSON/RPC modes,
the SDK, independent sessions, tools, and lifecycle events—but intentionally does
not prescribe one orchestration model.

This extension provides a small, production-oriented subagent runtime for Pi.
It takes the following ideas from existing systems without copying their product
surface wholesale:

- Codex: explicit agent control plane, durable identity, and separation between
  completion, interruption, waiting, and resource cleanup.
- Claude Code: explicit fresh/fork context policies and separation of tool
  capability, per-call permission, and process sandboxing.
- Amp: orthogonal Agent, Thread, and Executor concepts; keep the full child
  transcript outside the parent context and return a bounded handoff.
- Brian Kimball's Pi setup: star topology, self-contained work orders, persistent
  RPC workers, and fresh-eyes review.

## 2. Goal

Provide a Pi extension that lets a parent agent delegate bounded work to isolated
Pi child sessions while retaining responsibility for decomposition, decisions,
integration, verification, and the final user-facing result.

The extension must:

1. Keep child conversation context isolated from the parent by default.
2. Support both one-shot calls and persistent, controllable child workers.
3. Make lifecycle and resource ownership explicit.
4. Restrict child capabilities according to a declared agent definition.
5. Preserve a durable child transcript while returning only a bounded result to
   the parent model.
6. Leave scheduling, write coordination, and change integration to the parent.
7. Remain small enough to understand, test, and evolve without becoming a full
   distributed agent framework.

## 3. Non-goals

The current runtime does not provide:

- Agent teams, shared task DAGs, task claiming, or leader election.
- Child-to-child messaging.
- Nested delegation; the initial maximum depth is one.
- Distributed runners, cloud sandboxes, or remote execution.
- Worktree discovery, writer leases, or parent/child write coordination.
- Schedules, missions, durable queues across machines, or global memory.
- A full-screen FleetView or elaborate custom TUI.
- Automatic model selection or model benchmarking.
- A security claim based only on prompt instructions or tool allowlists.
- Compatibility with the internal state or configuration format of
  `npm:pi-subagents`.

## 4. Design principles

### 4.1 Delegation is not ownership transfer

The parent owns the user outcome. A child performs one scoped unit and returns
evidence. The parent still integrates changes, evaluates findings, runs combined
validation, and reports the final result.

### 4.2 Fresh context by default

A child does not implicitly inherit the parent transcript. The parent provides a
self-contained task containing the goal, scope, constraints, known decisions,
evidence, validation, and expected return shape. The extension wraps that task in
a stable work-order envelope with canonical scope, runtime constraints, and
applicable project guidance.

### 4.3 One coordinator, leaf workers

The initial topology is strictly star-shaped:

```text
parent -> child A
       -> child B
       -> child C
```

Children cannot spawn children and cannot message peers.

### 4.4 The parent owns write coordination

Agent capabilities come only from their explicit tool allowlist. The extension
does not add a separate mutability flag, discover Git worktrees, or coordinate
parent and child writes. The parent decides when agents may run, avoids
conflicting writes, and inspects and integrates resulting changes.

### 4.5 Separate identity, execution, and turns

A logical run ID, child process, child session, and active model turn are
different resources. The implementation must not use one as a substitute for
another.

### 4.6 Bounded handoff, durable evidence

The parent receives a concise structured result. The complete transcript remains
in the child session and is referenced by session ID/path for inspection. A
transcript reference does not make the runtime recoverable after restart.

### 4.7 Routing is catalog-driven

Delegation policy is expressed in terms of task boundaries and capabilities, not
a fixed roster. Each registered definition's `description` is its model-facing
routing contract. The tool description contains a bounded startup catalog built
from those definitions, and `list` refreshes discovery when definitions change
or a requested name is absent. Prompt guidelines must select from that catalog;
they must not duplicate agent names, assume a fixed count, or become a second
source of truth for role capabilities.

The parent classifies work before it starts equivalent reads or searches:

- An explicitly independent, fresh-eyes, or second-opinion review is delegated
  to a matching registered read-only role after prerequisite writes settle.
  Parent self-review does not satisfy an independence requirement.
- External research that requires multiple searches or sources, freshness
  checks, or source assessment is delegated to a matching registered read-only
  role before the parent starts its own web-research workflow.
- Bounded multi-file discovery, one specific high-impact unresolved decision,
  and separately owned implementation are strong candidates when a matching
  registered role materially improves isolation, quality, or parallelism.
- Simple lookups, localized edits, routine validation, and one-source factual
  checks remain direct parent work unless the user explicitly requests
  delegation.

The parent sends a self-contained work order and retains synthesis and final
verification. After a successful cited read-only handoff, it does not repeat the
same searches or reads; it verifies only decision-critical uncertainty or
contradictions. A write-capable handoff still requires inspection of the scoped
diff and integrated validation.

## 5. Core concepts

### 5.1 Agent definition

An agent definition describes a reusable role, not a running process.

```ts
interface AgentDefinition {
  name: string;
  description: string;
  systemPrompt: string;

  model?: string;
  thinking?: string;
  tools: string[];
  contextPolicy: "fresh";
  maxDepth: 1;
}
```

Initial definitions are Markdown files with YAML frontmatter and a Markdown
system prompt. User definitions are loaded from
`${PI_CODING_AGENT_DIR:-~/.pi/agent}/agents/*.md`. The current implementation
does not discover project-local definitions or compatibility paths. If
project-local definitions are added later, they are repository-controlled input
and require an explicit trust/override policy before becoming executable.
The parser rejects model fallbacks, executable extension declarations, non-fresh
context policies, and depths other than one. Controller-owned tool-provider
mappings load any extension required to implement a declared tool.

### 5.2 Work order

Every child invocation receives the following stable envelope:

```ts
interface WorkOrder {
  goal: string;
  scope: string[];
  nonGoals?: string[];
  constraints: string[];
  knownDecisions: Decision[];
  evidence: EvidenceRef[];
  validation: string[];
  returnFormat: string;
  projectGuidance: string[];
}

interface Decision {
  statement: string;
  source: "user" | "parent" | "code" | "docs";
}

interface EvidenceRef {
  kind: "file" | "command" | "url";
  value: string;
}
```

The model-facing tool accepts one self-contained `task` string. The extension
places it in `goal`, sets `scope` to the canonical child cwd, adds fixed runtime
constraints and applicable project guidance, and currently leaves
`knownDecisions`, `evidence`, and `validation` empty. The parent therefore encodes
task-specific decisions, evidence, validation, and return requirements directly
in `task`; independently populated structured fields are future work.

### 5.3 Runtime and operation identity

Display names and PIDs are not durable identities. The control plane uses the
following distinct identities:

- `runId`: a logical child runtime from `start` until `close`.
- `operationId`: the initial work order or one later delegated operation.
- `rpcRequestId`: correlation for one JSON/RPC command only.
- `processInstanceId`: one local subprocess incarnation; a PID is only an
  observed attribute of that instance.
- `sessionId`: Pi transcript identity, which may outlive a process.

Runtime lifecycle and operation outcome are orthogonal. The current
parent-visible snapshots are:

```ts
type RuntimeState =
  | "starting"
  | "idle"
  | "running"
  | "closing"
  | "closed"
  | "crashed";

type OperationState =
  | "running"
  | "completed"
  | "failed"
  | "interrupted"
  | "cancelled";

// `queued`/`cancelled-before-submit` was removed in the idle-only simplification: `follow_up` while `running` now fails fast with conflict instead of queueing. `cancelled` remains only as a terminal state for future use.

interface RuntimeSnapshot {
  runId: string;
  revision: number;
  agent: string;
  model?: string;
  thinking?: string;
  status: RuntimeState;
  operationId?: string;
  activeOperationId?: string;
  activeOperation?: OperationSnapshot;
  lastSettledOperation?: OperationSnapshot;
  processInstanceId?: string;
  transcript?: {
    sessionId?: string;
    sessionPath?: string;
  };
}

`model` is the provider-stripped model id and `thinking` is the effective thinking level when the agent definition provides them; both are bounded and exposed in `runtimeSnapshot` and in the serialized `SubagentResult` envelope for routing diagnostics.

interface OperationSnapshot {
  operationId: string;
  status: OperationState;
  /** Bounded human-readable task context for status UI and diagnostics. */
  task: string;
  startedAt?: number;
  finishedAt?: number;
  result?: SubagentResult;
  error?: string;
}
```

The control plane additionally keeps the parent session, canonical cwd, selected
agent profile, operation task/deadline, waiters, controller ownership, and
capacity reservation in private in-memory records. Startup failures use
`crashed`; there is no separate `start_failed` state or controller-assigned turn
sequence.

Required invariants:

- Every transition follows an explicit runtime or operation state-machine edge.
  A runtime may alternate between `idle` and `running` by creating new
  operations; an operation's state is monotonic and it never runs twice.
- `waiting` is an observer action, not runtime or operation state.
- `close` atomically enters `closing`, rejects new operations, and starts process cleanup.
- Only authoritative process exit/close events move `closing` to `closed`.
  Unexpected exit moves the runtime to `crashed` and releases all reservations.
- `interrupt` targets an expected operation and does not close the runtime.
- `interrupted` is reserved for an accepted RPC operation; `cancelled` is retained only for future use and currently has no producer.
- Pi turn boundaries are observations used to reduce events; they do not replace
  operation identity.

### 5.4 Current bounded handoff

```ts
interface SubagentResult {
  runId: string;
  operationId: string;
  processInstanceId?: string;
  agent: string;
  model?: string;
  thinking?: string;
  status: "completed" | "failed" | "interrupted";
  summary: string;
  transcript: {
    sessionId?: string;
    sessionPath?: string;
  };
}

The control plane enriches the envelope with `model`/`thinking` when the effective agent definition provides them (provider prefix stripped) before parent serialization; the child never fabricates these fields.
```

`SubagentResult` is a controller-created envelope. The controller, never child
JSON, owns IDs, agent identity, status, and transcript references. The child's
final assistant text is bounded and returned as `summary`; the controller does
not currently parse files, findings, validation, blockers, or risks into
separate fields. Structured claims and controller-observed provenance remain
Milestone 2 work.

`completed` requires an authoritative settled event and a complete final
assistant response with a normal stop reason. Missing final responses and
provider length-truncated responses produce a `failed` result containing bounded
partial text when available. Startup, provider, protocol, or process failures
that prevent normal reduction instead return a tool error with a failed
operation or crashed runtime snapshot; the controller does not fabricate a
`SubagentResult`. `interrupted` requires the targeted operation to settle as
aborted after an accepted interrupt. A late interrupt never overwrites an
already completed outcome.

The parent-visible serialization must be bounded by both character and line
count. Large reports and full event streams must not be embedded into the parent
model context.

## 6. Runtime architecture

### 6.1 Default executor

The production target uses one `pi --mode rpc` subprocess per active child.

Reasons:

- Independent context and session transcript.
- Steering, follow-up, abort, status, and persistent sessions are available.
- A child crash is isolated from the parent extension process.
- The runtime boundary is observable with ordinary process tooling.
- It avoids premature dependence on shared in-process SDK state.

The Pi SDK may be added later as an optional low-latency executor after the RPC
contract is stable and process startup is demonstrated to be a bottleneck.

### 6.2 Components

```text
Parent Pi
  -> SubagentTool
  -> AgentRegistry
  -> RuntimeRegistry
  -> OperationRegistry
  -> ConcurrencyController
  -> ChildController
       -> pi --mode rpc
       -> JSONL codec
       -> request correlation
       -> event reducer
       -> process cleanup
  -> ResultReducer
  -> child session JSONL
```

Responsibilities:

- `AgentRegistry`: discover, parse, validate, and resolve agent definitions.
- `RuntimeRegistry`: own runtime, process, session, and revision state.
- `OperationRegistry`: own operation IDs, tasks, deadlines, and outcomes.
- `ConcurrencyController`: enforce total child limits.
- `ChildController`: own exactly one process and all associated listeners,
  timers, RPC requests, and teardown.
- `ResultReducer`: turn events and the final child message into a bounded handoff.

These names describe responsibilities. Implementation may keep them together
until separation removes demonstrated complexity.

### 6.3 Current implementation map

The current implementation deliberately has two main ownership boundaries rather
than one class per responsibility:

```text
Parent model / Pi tool runtime
  |
  | subagent action + tool-call AbortSignal + progress callback
  v
index.ts: in-memory control plane
  |-- agents.ts: discover and validate user agent definitions
  |-- context.ts: canonical cwd boundary and bounded AGENTS.md materialization
  |-- RuntimeRecord map: runtime state, revision, controller, capacity ownership
  |-- OperationRecord maps: accepted/settled state and retained results
  |-- completion message: wake the parent after persistent operation settlement
  |-- render.ts: bounded call, progress, and terminal-state presentation
  |
  | SubagentRunOptions / SubagentOperation / SubagentResult
  v
sdk-executor.ts: one SdkSubagentController per in-process session
  |-- session construction (cwd, tools allowlist, model/thinking, custom tools)
  |-- isolated DefaultResourceLoader (noExtensions, noSkills, no context files, explicit systemPrompt)
  |-- durable SessionManager under <agent-dir>/subagent-sessions/<runId>/
  |-- operation-local event/progress reduction
  |-- prompt preflight acceptance and agent_settled completion
  |-- abort/deadline watchdogs, fatal notification, session disposal
  v
in-process AgentSession (createAgentSession)
  |
  +--> child session JSONL (durable transcript evidence)
```

`protocol.ts` is the contract boundary between the control plane and controller.
`output.ts` provides shared bounding and redaction. The registry, concurrency,
operation registry, and result reducer in the conceptual diagram above are
currently cohesive responsibilities inside `index.ts` or `sdk-executor.ts`, not
separate runtime services.

Ownership is split as follows:

| Component | Owns | Does not own |
| --- | --- | --- |
| Tool/control plane (`index.ts`) | Model-facing actions, runtime/operation IDs, state transitions, revisions, capacity slots, waiters, result retention, shutdown coordination | RPC framing, child listeners, process signals |
| SDK controller (`sdk-executor.ts`) | Exactly one in-process Pi session, session construction and isolation flags, event reduction, operation deadline/abort watchdogs, fatal notification, session disposal | Multi-runtime scheduling, model-facing status policy |
| Pi child | Model turns, tool execution, session transcript | Parent integration decisions, runtime registry |
| Renderer (`render.ts`) | Bounded visual presentation and spinner lifecycle | Authoritative state or completion decisions |

The controller exposes two distinct operation promises:

- `accepted`: Pi session identity is known and the session `prompt` preflight has
  been accepted. `start` and `send` return after this boundary.
- `result`: the operation has reached authoritative `agent_settled` and the
  controller has reduced the final assistant message into `SubagentResult`.

The controller also exposes `failure`, which lets the control plane observe an
idle child process or protocol failure instead of discovering it only on the next
operation.

Persistent operations additionally produce a bounded `subagent-operation-settled`
custom message after settlement. Pi delivers it as a parent `followUp` when the
parent is streaming, or starts a new parent turn when idle. Synchronous `run`
operations do not notify because their tool result already carries the outcome;
close/shutdown-driven settlement is suppressed to avoid duplicate or teardown
noise.

### 6.4 Current data flows

#### One-shot `run`

```text
run
 -> resolve agent, cwd, guidance, work order
 -> reserve runtime slot and create controller (in-process session)
 -> prompt preflight accepted
 -> wait for agent_settled -> reduce result
 -> close controller/dispose session -> release slot
 -> return bounded SubagentResult
```

The runtime is retained only as a bounded in-memory terminal record; it is not a
warm worker after `run` returns.

#### Persistent `start` and `send(follow_up)`

```text
start
 -> reserve slot -> create one controller/process/session
 -> submit initial operation -> prompt accepted -> return runId + operationId
 -> agent_settled -> runtime becomes idle -> notify parent

send(follow_up)
 -> create a new operationId
 -> submit immediately while idle; a running runtime returns a conflict
 -> prompt accepted -> return operationId
 -> agent_settled -> runtime becomes idle again -> notify parent

close
 -> closing -> interrupt accepted active operation if necessary
 -> close/reap process tree -> release slot -> closed
```

The control plane accepts follow-ups only while the runtime is `idle`. A `send`
while `running`, `starting`, `closing`, `closed`, or `crashed` returns a
conflict/error rather than buffering work.

#### Interrupt and deadline

```text
expected operation still active and accepted
 -> RPC abort
 -> wait for both abort response and authoritative agent_settled
 -> operation interrupted
 -> healthy runtime returns to idle
```

A stale operation ID is a no-op. Missing abort response or settlement trips a
watchdog and crashes/cleans the controller rather than leaving shutdown blocked.
Direct process termination is reserved for close, fatal process/protocol failure,
or abort-watchdog escalation; it is not the normal operation-interrupt path.

### 6.5 Persistence and restart boundary

Current persistence is intentionally limited:

- The Pi child session JSONL is durable transcript evidence.
- Runtime records, operation records, revisions, retained results, and capacity
  reservations exist only in the extension process memory.
- The RPC transport is the spawned child's stdin/stdout pair. After the parent Pi
  or extension process exits, a new extension instance cannot reconnect to that
  transport or safely continue, interrupt, or close the old logical runtime.

Therefore the current design provides **persistent workers within one extension
lifetime** and **durable transcripts**, but not crash-resumable or restart-durable
runtimes. An atomic ledger by itself would add durable history and unclean-restart
reconciliation only; it must not advertise the runtime as resumable. True runtime
recovery requires a reconnectable transport or an independently durable
supervisor with an explicit adoption protocol.

### 6.6 Spawn contract

The child process must be started with:

- `shell: false`.
- A validated cwd under an allowed root.
- An explicit model and thinking level when the agent definition provides them.
- An explicit tool allowlist.
- Explicit extension loading; inherited extensions must not be accidental.
- A controlled child session directory for persistent/RPC execution.
- A deliberately constructed environment rather than an unexplained copy of all
  parent secrets.
- A child marker containing run ID, parent session ID, and depth.

The implementation runs children as in-process SDK sessions (`createAgentSession`)
and therefore always shares the parent's Pi version — no cross-version pin is
needed. Each child session is constructed with an isolated `DefaultResourceLoader`
(`noExtensions`, `noSkills`, `noPromptTemplates`, `noThemes`, `noContextFiles`), an
explicit `systemPrompt`, the agent's tool allowlist, per-session `model`/`thinkingLevel`,
and a dedicated `SessionManager` under `<agent-dir>/subagent-sessions/<runId>/`.
`web_search` is provided as a session-scoped custom tool when the effective tool
allowlist declares it. The parent resolves applicable project guidance and
materializes the selected text into the work-order envelope, so the child never
relies on implicit AGENTS.md inheritance. No extension is inherited by default.

Because children run in-process, there is no child environment construction.
Credential values that must never appear in child output (for example
`EXA_API_KEY` when `web_search` is declared, plus names from
`PI_SUBAGENT_AUTH_ENV_ALLOWLIST`) are redacted from progress and results instead.
Names are validated against `^[A-Z_][A-Z0-9_]*$` and must not contain newlines.
User agent definitions are enabled by default; project-local definitions
remain disabled. Effective agent `model`/`thinking`/`description` may be overridden via `settings.json` `subagents[agent]` after file discovery; the startup catalog and `list` discovery both reflect the effective merged view.

The in-process transport trades OS-process isolation for the platform-recommended
embedding model (`docs/rpc.md` explicitly recommends `AgentSession` over spawning
a subprocess for Node hosts). A runaway child can no longer be killed via process
signals; containment relies on per-operation deadlines, abort watchdogs, and
session disposal. V1 shares the user's Pi agent directory and auth store; a
managed agent directory, filtered auth store, and filesystem sandbox are still
required before the extension may claim credential isolation.

## 7. Tool surface

The current model-facing API is action based:

```ts
subagent({ action: "list" })
subagent({ action: "run", agent, task, deadlineMs, ... })
subagent({ action: "start", agent, task, deadlineMs, ... })
subagent({ action: "status", id })
subagent({ action: "send", id, mode, message })
subagent({ action: "wait", id, operationId, timeoutMs })
subagent({ action: "interrupt", id, expectedOperationId })
subagent({ action: "close", id })
```

`action` is required on every call. The provider-facing schema remains one root
object; the implementation enforces action-specific required fields at runtime.

Semantics:

- `list`: refresh discovery and return executable agent names and routing
  descriptions. The startup catalog already covers the normal selection path.
- `run`: convenience operation equivalent to start, wait, and close for a
  one-shot task. `deadlineMs` is required: estimate the task duration and add
  reasonable headroom for model and tool latency instead of relying on a fixed
  default. It has a separate execution deadline; a wait timeout is never
  reinterpreted as that deadline. Omit `cwd` to use the parent's current
  directory; specify it only for a project subdirectory, preferably as a
  relative path.
- `start`: reserve capacity, start a persistent worker, submit its initial
  operation, and return the run and operation IDs only after RPC readiness,
  session identity, and prompt acceptance. Its task-specific `deadlineMs` is
  required. It does not wait for completion.
- `status`: return a bounded snapshot containing a monotonic `revision`, runtime
  state, active operation ID, and last settled operation; never poll internally.
- `send(..., mode: "follow_up")`: create a new operation. An idle runtime submits
  it immediately; a running runtime returns `{ accepted:false, conflict:true }` (fail-fast, no queue). The execution deadline starts when the RPC prompt is submitted. Pi's native follow-up queue is not used because it lacks the
  per-turn correlation required by `wait`, deadlines, and stored results.
- `send(..., mode: "steer")`: attach a control message to the active operation;
  it does not create a new operation or independent settlement. The caller must
  provide `expectedOperationId`; steering is accepted only after that operation's
  prompt is accepted and while it remains active, then maps to RPC `steer`.
- `wait`: wait for one specified operation. If it is already settled, return its
  stored result immediately. Timeout returns `{ reason: "timeout", snapshot }`
  without changing state or cancelling work. Multiple waiters may observe the
  same stored result.
- `interrupt`: request abort only when `expectedOperationId` is still active.
  A mismatch returns a conflict/no-op, preventing a late abort from targeting a
  later operation. The authoritative settle event determines final outcome.
- `close`: idempotently enter `closing`, reject new input, terminate the process tree, release slots after authoritative
  process exit, and retain transcript and operation results. Repeated calls
  return the stored state.

The extension registers the canonical `subagent` name. Any package-provided tool
with the same name, such as `npm:pi-subagents`, must be removed or disabled in
the same Pi runtime. Its provider-facing parameter schema has a single object
root with action-dependent optional fields; root-level JSON Schema unions are
not used because DeepSeek rejects them before tool invocation. The extension
validates each action's required fields before accessing runtime state.

### 7.1 Current implementation status

The current implementation exposes `list`, `run`, `start`, `status`, `send`,
`wait`, `interrupt`, and `close`. Lifecycle actions identify a persistent
runtime by `runId` and a turn by `operationId`. `start` keeps one RPC process,
session, and transcript warm after its initial operation. A runtime accepts
sequential idle follow-ups and guarded steering of its accepted active operation (running `follow_up` returns conflict, no queue). `run` remains a one-shot convenience
action and closes its runtime after settlement.

Implemented today:

- Reusable RPC runtimes with prompt-acceptance and `agent_settled` boundaries.
- Idle follow-up operations in the same process and session (running returns conflict, no queue).
- Active steering with an expected-operation guard and no extra operation result.
- Runtime/operation identity, monotonic in-memory revisions, and guarded interrupts.
- RPC `abort` for operation interrupt/deadline without closing a healthy runtime.
- Fresh child context, explicit tools, filtered environment, and process cleanup.
- Durable session paths under `<agent-dir>/subagent-sessions`.
- `runId`, `operationId`, `processInstanceId`, `sessionId`, and transcript paths.
- Bounded in-memory runtime and operation tracking enriched with effective `model`/`thinking` (stripped) in snapshots and serialized results.
- Discovery starts from `agents/*.md`; `settings.json` `subagents[agent]` may override `model`, `thinking`, and `description` per provided field, and catalog plus `list` reflect the effective merged view.
- Bounded parent completion notifications for each submitted persistent operation.
- Compact runtime UI with bounded task previews, reduced live progress, short
  collapsed identifiers, and full expanded completion summaries.

Optional remaining reliability work is durable history and unclean-restart
reconciliation. That work would not make a runtime resumable. Reconnect/reporting
for a live prior process requires a different transport or supervisor design and
is not implied by the current architecture. Rich structured handoffs, usage
accounting, and needs-decision messages remain Milestone 2 work.

## 8. Context requirements

### 8.1 Fresh context

Fresh is the only required V1 context policy.

The child receives:

- Its agent system prompt.
- The work order.
- Explicitly selected project guidance.
- Its effective tools and runtime metadata.
- Files only by path/reference unless content materialization is explicitly
  requested.

The child does not receive:

- The complete parent transcript.
- Parent thinking or abandoned attempts.
- Parent-only orchestration instructions.
- Unrelated tool outputs.
- An implication that an agent-authored statement is user approval.

### 8.2 Fork context

Fork is deferred. When added, it must use an explicit parent session checkpoint,
not a best-effort snapshot of mutable in-memory messages.

Fork metadata must include:

- Parent session ID.
- Parent entry/checkpoint ID.
- Number or range of copied turns.
- Context hash or equivalent provenance.
- Filtering rules applied to parent-only instructions and tool results.

Forked context becomes child-owned after spawn; parent and child never share a
mutable conversation object.

### 8.3 Working directory

The parent session's canonical Git root is the allowed root, or its canonical
current directory when no Git root exists. `run` and `start` omit `cwd` for the
parent's current directory. A child that must enter a project subdirectory uses
that relative subdirectory rather than copying the absolute cwd shown by the
system.

The extension resolves and canonicalizes the result with the native filesystem
implementation before checking containment. This preserves on-disk casing on
case-insensitive filesystems and rejects lexical or symlink escapes. An absolute
path is not needed for model calls and is accepted only if canonicalization still
places it inside the allowed root.

## 9. Capability and security requirements

### 9.1 Capability is not permission or sandboxing

The design treats these as separate layers:

1. Tool capability: which tools the child model can see.
2. Tool-call policy: whether a specific call is allowed, denied, or delegated to
   an arbiter.
3. Process sandbox: which files, network resources, and processes an allowed
   command can actually access.
4. Credential scope: which secrets are present in the child environment.

V1 must implement explicit tool capability. It must not claim OS-level read-only
or sandbox guarantees unless such enforcement is actually present.

An agent receives exactly its declared and validated tools. A tool allowlist
limits model-visible capabilities but is not an OS-level sandbox or a substitute
for parent coordination.

### 9.2 Trust boundaries

- Project-local agent definitions are repository-controlled input.
- Agent prompts are data and cannot grant themselves tools or permissions.
- Executable hooks/extensions require a stronger trust decision than Markdown
  instructions.
- Child messages and final reports carry agent provenance and cannot approve
  destructive/shared actions on behalf of the user.
- The cwd must be canonicalized and checked against allowed roots, including
  symlink escape.
- stdout, stderr, progress, and final result sizes must be bounded.
- Environment variables must be selected deliberately. Known credential values
  and common credential formats are redacted before retention and serialization,
  but this best-effort filter is not a credential-isolation guarantee.

### 9.3 Process cleanup

RPC operation cancellation and process shutdown follow related but distinct
idempotent paths:

- `interrupt` sends RPC `abort` and waits for both the abort response and
  authoritative `agent_settled`; a watchdog treats missing acknowledgement or
  settlement as a fatal controller failure.
- Normal idle `close` ends stdin and waits for process exit.
- Closing a still-active or unhealthy controller sends `SIGTERM` to the owned
  process group, waits a bounded grace period, and escalates to `SIGKILL` only if
  the process tree remains alive.
- Every terminal path awaits authoritative process exit/tree cleanup, clears
  timers, and removes listeners.

Parent `session_shutdown` must close all owned children. Cleanup must tolerate
already-exited processes and partial startup failures. On platforms where child
tools may create descendants, the controller starts the child in a process group
or uses an equivalent tracked-process mechanism and applies escalation to the
owned process tree, not only the Pi leader PID. Unexpected exit and failed spawn
release concurrency reservations immediately.

## 10. Concurrency requirements

Initial defaults:

```text
maxConcurrentRuns = 3
maxDepth = 1
```

Required behavior:

- Capacity is reserved before child creation to avoid partial fan-out.
- Failed spawn releases its reservation.
- Idle persistent workers retain their slot until closed.
- Children may share cwd. The parent is responsible for avoiding conflicting
  writes and for reviewing the resulting workspace state.
- V1 fails fast when child capacity is unavailable; it does not queue runs. A
  parent may retry after observing status or completion.

## 11. Persistence and recovery

Each child runs as a dedicated in-process Pi session with a JSONL transcript under
`<agent-dir>/subagent-sessions`. Current persistence guarantees are limited to
transcript evidence:

- Full child transcript survives parent context compaction.
- A settled child result can be inspected without injecting the transcript into
  the parent context.
- Closing a runtime does not delete its transcript.

Runtime records, operation records, revisions, retained results, and capacity
reservations are in memory only. There is no current run ledger, restart
reconciliation, process adoption, or action that rediscovers a prior runtime from
its transcript. Normal `session_shutdown`, including extension reload, waits for
owned children to close. An unclean restart may leave only a possibly incomplete
transcript as evidence; a new extension instance must not infer that the old
runtime is controllable from its PID or session file.

An optional future atomic ledger may provide durable history and unclean-restart
reconciliation, but it would not make a runtime resumable. Reconnection requires
a durable supervisor or reconnectable transport with an explicit adoption
protocol. M1 workers remain warm after settling until explicit close; cold
residency is a later capability.

## 12. Observability

Parent-model output and user-facing UI are different channels.

Parent model receives:

- Run, operation, and state snapshots from lifecycle actions.
- Final bounded result envelope.
- Transcript reference.

Current UI/details additionally show:

- Agent name and current operation context.
- Reduced tool activity while an operation is running, with a live seconds-based
  deadline countdown on the spinner line.
- Full bounded diagnostic error.

Collapsed calls show up to six task lines. Collapsed results hide runtime and
operation IDs and show only user-relevant state. Expanded calls and results show
the bounded full task and full IDs. Persistent completion cards show the short
agent name plus the task before the summary, so a delayed notification remains
understandable without replaying the original call. While an operation is active,
its partial-state branch contributes only an animated spinner with the countdown;
the output-preview path appends the latest reduced, redacted progress summary once.
It does not repeat the agent name or a generic `Running` label. Terminal result
lines omit the agent label entirely because the call title above already carries
the full `agent · model · thinking` identity. Expanded completion notifications
retain bounded multiline summaries instead of flattening them to one line.

Intermediate child reasoning must not be copied into the parent model context.
JSONL parse failures and protocol violations must be surfaced as diagnostics,
not silently discarded.

Default V1 retention limits are:

```text
maxJsonlRecordBytes = 1 MiB
maxParserBufferBytes = 1 MiB
maxRetainedStderrBytes = 64 KiB
maxLiveProgress = 160 characters on one line
maxFinalChildText = 32,000 characters or 400 lines
maxParentSerialization = 32,000 characters or 400 lines
```

The controller continuously drains stdout and stderr; limits bound retained
memory, not pipe consumption. It decodes split UTF-8 and partial LF-delimited
records incrementally. An oversized record or non-empty malformed JSON line is a
protocol failure and closes the child. Ring buffers and reduced output are
truncated with an explicit marker (`[truncated]` for text, `[truncated]\n` for stderr ring, `[truncated oversized stderr line]\n` for oversized stderr lines, and `[truncated: additional project guidance omitted]` for guidance materialization). Exact configured credential values and common
credential patterns are redacted on a best-effort basis before retention and
serialization. These limits are fixed implementation constants; a future
configuration surface may lower them but must not disable them.

## 13. Validation strategy

### Unit-level contracts

- Agent frontmatter parsing, validation, and deterministic discovery.
- Runtime and operation transitions and invalid transition rejection.
- Operation-targeted wait and interrupt race cases.
- Concurrency reservation/release.
- Bounded output and redaction.
- Provider-compatible root-object schema and action-specific validation.
- Startup catalog and capability-driven routing guidance.
- Native cwd canonicalization, project-root containment, and symlink escape.
- Partial-line and split UTF-8 JSONL decoding.
- Idempotent cleanup and timer/listener removal.
- Result-envelope ownership and outcome mapping.
- Fail-fast on running follow_up (no queue) without a fabricated result.

### Integration contracts

- Spawn a read-only child and receive a final result.
- Stream child tool activity without polluting parent-visible output.
- Abort a targeted operation and retain the child session.
- Send an idle follow-up to a persistent worker (running returns conflict).
- Steer the expected active operation without creating a second operation.
- Close a worker and verify its process exits and slot is released.
- Preserve transcript after close.
- Parent shutdown cleans up all children.

The default `npm test` suite uses protocol fixtures and does not call a model; the
gated `subagent/live.test.ts` provider smoke remains skipped unless explicitly
enabled. Paid-provider tests must stay outside routine validation.

Routing quality is validated separately with the real-Pi behavioral evaluator:

```text
node subagent/eval/run.mjs --quick
bun subagent/eval/run.mjs --quick
node subagent/eval/run.mjs
```

It runs isolated temporary Git fixtures and Pi agent directories, then measures
direct-work false positives, registered-role selection, redundant parent work,
implementation outcomes, ordered role composition, and persistent lifecycle
use. Deterministic execution/tool/schema failures always fail; probabilistic
routing thresholds are warnings in quick mode and enforced by the full run.
Reports preserve per-run JSONL plus machine- and human-readable summaries. The
scenario matrix, exact assertions, options, and baseline workflow live in
`eval/README.md`; the evaluator is intentionally invoked directly with Node.js
or Bun rather than through a package-script alias.

### Failure cases

- Invalid agent definition.
- Missing model/provider authentication.
- Child startup error before RPC ready.
- Malformed or oversized JSONL/event output.
- Provider failure after prompt acceptance.
- Child process exits without a final response.
- Abort during startup, active tool execution, and settled state.
- Parent reload or exit while children are running.

## 14. Evolution roadmap

### Superseded exploration: JSON one-shot vertical slice

The initial design considered Pi JSON mode as a short-lived way to validate
prompt shape, tool allowlists, bounded event parsing, deadlines, and process-tree
cleanup. The current source tree has no JSON executor: the RPC controller now
provides both one-shot `run` and persistent lifecycle behavior with durable
transcripts. JSON-mode stdin and cancellation semantics are therefore historical
design context, not current contracts or remaining implementation work.

### Milestone 1: Persistent runtime (partial; transport renamed)

Historical note: sections below were written for the retired `pi --mode rpc`
subprocess transport; references to RPC framing, process trees, and queued
follow-ups describe superseded designs. The in-process SDK executor
(`sdk-executor.ts`) now provides the same lifecycle contract.

The SDK executor, durable session references, basic lifecycle actions, identity
separation, concurrency limit, and `agent_settled` completion are implemented.
The remaining work is listed explicitly below.

The current executor runs:

```text
in-process createAgentSession (no subprocess)
```

Implemented:

- SDK-backed persistent execution with durable session references.
- `start`, `status`, idle-only `send(..., mode: "follow_up")` (running returns a
  conflict), guarded active `send(..., mode: "steer")`, `wait`, guarded
  `interrupt`, and idempotent targeted `close` actions.
- Sequential operations in one process/session, with prompt acceptance separate
  from authoritative operation settlement.
- Operation interrupt and deadline through RPC `abort`, leaving a healthy runtime
  reusable after `agent_settled`.
- Separate run, operation, process-instance, and session identities.
- Monotonic in-memory runtime revisions, concurrency limits, fatal-process
  observation, and `agent_settled`-based completion.

Remaining:

- Optional atomic local history and unclean-restart reconciliation, explicitly
  without a resumability claim.
- A separate reconnectable transport or durable-supervisor design before live
  process adoption after extension restart can be supported.

Acceptance:

- A child can complete multiple turns in the same session.
- `wait` timeout leaves it running.
- A late `interrupt` cannot stop a later operation.
- `interrupt` stops the targeted operation without deleting the transcript.
- `close` releases the slot and exits the process.
- A closed transcript can be inspected but is not advertised as resumable.

### Milestone 2: Steering and rich structured handoff (partial)

Implemented:

- Active `steer` and idle-only `follow_up` modes.
- Compact status/progress UI with collapsed and expanded presentations.

Remaining:

- Structured progress, needs-decision, and final handoff messages.
- Usage and timing accounting where reliable.

Acceptance:

- Parent can redirect a running child at the next model boundary.
- Follow-up input runs only after the current generation settles.
- Final result includes files, validation, blockers, risks, and transcript
  provenance without requiring transcript replay.

### Milestone 3: Explicit fork context

Add:

- Parent session checkpoint selection.
- Full or last-N-turn fork policies.
- Filtering of parent-only orchestration instructions.
- Context provenance and hash.
- Fork depth enforcement.

Acceptance:

- Child starts from a reproducible persisted parent checkpoint.
- Parent and child histories diverge independently after spawn.
- Fork does not silently broaden tools, permissions, or secrets.

### Milestone 4: Optional advanced capabilities

Consider only after observed need:

- SDK/in-process executor for lower startup latency.
- Runtime pool or cold residency.
- Permission arbiter for `ask` rules.
- Child watchdog/reviewer integration.
- Remote executor abstraction.
- Additional specialist profiles.

Agent teams, peer messaging, shared task graphs, schedules, and missions require a
separate specification because they introduce a coordination plane rather than
incrementally extending delegated execution.

## 15. Coexistence

The canonical `subagent` name may collide with a third-party package even when
that package is merely installed or cached. Installation does not imply that the
package is loaded; verify the effective Pi settings and tool registry. Any other
package that registers `subagent`, such as `npm:pi-subagents`, must be disabled in
the same runtime. This extension does not interpret or migrate another package's
configuration, transcripts, or runtime state.

## 16. Open decisions

The following deployment-specific decisions remain. They do not change the
runtime/operation contracts above, but each must be resolved before the milestone
that consumes it:

1. Before tightening child isolation: decide whether in-process sessions are
   sufficient or an OS-sandboxed transport is required for untrusted workloads.
2. Before optional durable history: ledger location, retention, and unclean-
   restart reconciliation policy.
3. Before enabling project agents: whether trusted-project status is sufficient
   or a second extension-specific confirmation is required in interactive and
   non-interactive modes.

## 17. References

- Codex multi-agent documentation:
  https://developers.openai.com/codex/multi-agent
- Codex agent control implementation:
  https://github.com/openai/codex/tree/main/codex-rs/core/src/agent
- Claude Code subagents:
  https://code.claude.com/docs/en/sub-agents
- Claude Code agent teams:
  https://code.claude.com/docs/en/agent-teams
- Claude Code permissions:
  https://code.claude.com/docs/en/permissions
- Amp Owner's Manual:
  https://ampcode.com/manual
- Amp Plugin API:
  https://ampcode.com/manual/plugin-api
- Pi RPC documentation:
  https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/rpc.md
- Pi session format:
  https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/session-format.md
- Pi official subagent example:
  https://github.com/earendil-works/pi/tree/main/packages/coding-agent/examples/extensions/subagent
