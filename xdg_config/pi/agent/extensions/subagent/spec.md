# Pi Subagent Extension Specification

- Status: Draft
- Updated: 2026-08-12

## 1. Background

Pi provides the primitives needed to build subagents—extensions, JSON/RPC modes,
the SDK, independent sessions, tools, and lifecycle events—but intentionally does
not prescribe one orchestration model.

This extension will provide a small, production-oriented subagent runtime for Pi.
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

Build a Pi extension that lets a parent agent delegate bounded work to isolated
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

The initial implementation will not provide:

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
self-contained work order containing the goal, scope, constraints, known
decisions, evidence, validation, and expected return shape.

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
in the child session and is referenced by session ID/path for inspection and
later recovery where explicitly supported.

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
  fallbackModels?: string[];

  tools: string[];
  extensions?: string[];

  contextPolicy?: "fresh" | "fork";
  maxDepth?: number;
}
```

Initial definitions are Markdown files with YAML frontmatter and a Markdown
system prompt. User definitions are loaded from
`${PI_CODING_AGENT_DIR:-~/.pi/agent}/agents/*.md`. The current implementation
does not discover project-local definitions or compatibility paths. If
project-local definitions are added later, they are repository-controlled input
and require an explicit trust/override policy before becoming executable.

### 5.2 Work order

Every child invocation receives a complete work order.

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

The extension may accept a plain task string for ergonomics, but it must wrap the
string in a stable work-order envelope before sending it to the child.

### 5.3 Runtime and operation identity

Display names and PIDs are not durable identities. The control plane uses the
following distinct identities:

- `runId`: a logical child runtime from `start` until `close`.
- `operationId`: the initial work order or one later delegated operation.
- `rpcRequestId`: correlation for one JSON/RPC command only.
- `processInstanceId`: one local subprocess incarnation; a PID is only an
  observed attribute of that instance.
- `sessionId`: Pi transcript identity, which may outlive a process.
- `turnSeq`: a controller-assigned sequence for observed Pi turns; it is not a
  model-facing API identity.

Runtime lifecycle and operation outcome are orthogonal:

```ts
type RuntimeState =
  | "starting"
  | "idle"
  | "running"
  | "closing"
  | "closed"
  | "crashed"
  | "start_failed";

type OperationState =
  | "queued"
  | "running"
  | "completed"
  | "failed"
  | "interrupted"
  | "cancelled";

interface RuntimeRecord {
  runId: string;
  revision: number;
  agentName: string;
  parentSessionId: string;
  parentRunId?: string;
  depth: number;
  state: RuntimeState;

  processInstanceId?: string;
  pid?: number;
  sessionId?: string;
  sessionPath?: string;
  cwd: string;
  activeOperationId?: string;

  createdAt: string;
  startedAt?: string;
  closedAt?: string;
  error?: string;
}

interface OperationRecord {
  operationId: string;
  runId: string;
  state: OperationState;
  workOrder: WorkOrder;
  createdAt: string;
  startedAt?: string;
  settledAt?: string;
  result?: SubagentResult;
  error?: string;
}
```

Required invariants:

- Every transition follows an explicit runtime or operation state-machine edge.
  A runtime may alternate between `idle` and `running` by creating new
  operations; an operation's state is monotonic and it never runs twice.
- `waiting` is an observer action, not runtime or operation state.
- `close` atomically enters `closing`, rejects new operations, cancels queued
  operations, and starts process cleanup.
- Only authoritative process exit/close events move `closing` to `closed`.
  Unexpected exit moves the runtime to `crashed` and releases all reservations.
- `interrupt` targets an expected operation and does not close the runtime.
- A queued operation cancelled before Pi accepts it moves to `cancelled` and has
  no `SubagentResult`; `interrupted` is reserved for an accepted RPC operation.
- Pi turn boundaries are observations used to reduce events; they do not replace
  operation identity.

### 5.4 Structured handoff

```ts
interface SubagentResult {
  runId: string;
  operationId: string;
  agent: string;
  status: "completed" | "failed" | "interrupted";
  summary: string;

  filesChanged?: Claimed<FileChange[]>;
  findings?: Finding[];
  validation?: Claimed<ValidationResult[]>;
  blockers?: string[];
  residualRisks?: string[];

  transcript: {
    sessionId?: string;
    sessionPath?: string;
  };
}

interface Claimed<T> {
  value: T;
  provenance: "child_claim" | "controller_observed";
}
```

`SubagentResult` is a controller-created envelope. The controller, never child
JSON, owns IDs, agent identity, status, transcript references, process errors,
and protocol diagnostics. Child-authored summary, findings, blockers, and risks
are bounded data. Files changed and validation remain `child_claim` unless the
controller independently observes them.

`completed` requires an authoritative settled event and a complete final
assistant response with a normal stop reason. Startup, provider, protocol, or
process failures map to `failed`; missing final responses and length-truncated
responses are failed partial results. `interrupted` requires the targeted
operation to settle as aborted after an accepted interrupt. A late interrupt
never overwrites an already completed outcome. `interrupted` results are
available only from the RPC executor; JSON process cancellation is reported as
a controller cancellation without a `SubagentResult`.

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
- `OperationRegistry`: own immutable operation IDs, work orders, and outcomes.
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
rpc-executor.ts: one RpcSubagentController per process
  |-- spawn arguments and filtered environment
  |-- bounded JSONL and stderr decoding
  |-- RPC request correlation
  |-- operation-local event/progress reduction
  |-- prompt acceptance and agent_settled completion
  |-- RPC abort, watchdogs, fatal notification, and process-group cleanup
  v
pi --mode rpc --session-dir <managed-dir>
  |
  +--> child session JSONL (durable transcript evidence)
```

`protocol.ts` is the contract boundary between the control plane and controller.
`output.ts` provides shared bounding and redaction. The registry, concurrency,
operation registry, and result reducer in the conceptual diagram above are
currently cohesive responsibilities inside `index.ts` or `rpc-executor.ts`, not
separate runtime services.

Ownership is split as follows:

| Component | Owns | Does not own |
| --- | --- | --- |
| Tool/control plane (`index.ts`) | Model-facing actions, runtime/operation IDs, state transitions, revisions, capacity slots, waiters, result retention, shutdown coordination | RPC framing, child listeners, process signals |
| RPC controller (`rpc-executor.ts`) | Exactly one child process, one Pi session, stdin/stdout/stderr, RPC requests, event reduction, operation deadline/abort, fatal signal, teardown | Multi-runtime scheduling, model-facing status policy |
| Pi child | Model turns, tool execution, session transcript | Parent integration decisions, runtime registry |
| Renderer (`render.ts`) | Bounded visual presentation and spinner lifecycle | Authoritative state or completion decisions |

The controller exposes two distinct operation promises:

- `accepted`: Pi session identity is known and the `prompt` RPC command has been
  accepted. `start` and `send` return after this boundary.
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
 -> reserve runtime slot and create controller
 -> get_state -> prompt accepted
 -> wait for agent_settled -> reduce result
 -> close controller/process tree -> release slot
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

send(follow_up), only while idle
 -> create a new operationId
 -> submit prompt through the same controller
 -> prompt accepted -> return operationId
 -> agent_settled -> runtime becomes idle again -> notify parent

close
 -> closing -> interrupt accepted active operation if necessary
 -> close/reap process tree -> release slot -> closed
```

No controller queue exists in M1. A `send` while `starting`, `running`,
`closing`, `closed`, or `crashed` returns a conflict/error rather than buffering
the message.

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

The current implementation is pinned to Pi 0.84.1. The RPC controller starts Pi
with `--no-context-files` and `--no-extensions`. The parent resolves applicable
project guidance and materializes the selected text into the work-order envelope,
so the child never relies on implicit AGENTS.md inheritance. No extension is
inherited by default; each executable extension path must be explicitly trusted
and passed. The implementation pins and integration-tests a supported Pi version
before relying on CLI flags, event names, or shutdown behavior.

The child environment starts from a documented base allowlist (`HOME`, `PATH`,
`SHELL`, `TMPDIR`, `USER`, `LOGNAME`, `TERM`, and locale variables). Provider
credential environment variables are inherited only through a separate
configured authentication allowlist, which defaults to empty. Deployments must
name each additional variable explicitly; wildcard prefixes are not accepted.
Arbitrary parent environment variables are not copied. User agent definitions
are enabled by default; project-local definitions and executable extensions are
disabled unless Pi reports the project trusted and this extension policy
explicitly enables them.

This is environment filtering, not file-level credential isolation. V1 shares
the user's Pi agent directory and auth store; keeping `HOME` and exposing file
read tools means a child may access user-readable credentials. A managed agent
directory, filtered auth store, and filesystem sandbox are required before the
extension may claim credential isolation.

## 7. Tool surface

The target model-facing API is action based:

```ts
subagent({ action: "list" })
subagent({ action: "run", agent, task, ... })
subagent({ action: "start", agent, task, ... })
subagent({ action: "status", id })
subagent({ action: "send", id, mode, message })
subagent({ action: "wait", id, operationId, timeoutMs })
subagent({ action: "interrupt", id, expectedOperationId })
subagent({ action: "close", id })
```

Semantics:

- `list`: return executable agent definitions and capabilities.
- `run`: convenience operation equivalent to start, wait, and close for a
  one-shot task. It has a separate execution deadline; a wait timeout is never
  reinterpreted as that deadline.
- `start`: reserve capacity, start a persistent worker, submit its initial
  operation, and return the run and operation IDs only after RPC readiness,
  session identity, and prompt acceptance. It does not wait for completion.
- `status`: return a bounded snapshot containing a monotonic `revision`, runtime
  state, active operation ID, and last settled operation; never poll internally.
- `send(..., mode: "follow_up")`: create a new operation. An idle runtime submits
  it immediately; a running runtime accepts at most one `queued` operation and
  submits its RPC `prompt` only after the active operation authoritatively
  settles. The execution deadline starts when the RPC prompt is submitted, not
  while queued. Pi's native follow-up queue is not used because it lacks the
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
- `close`: idempotently enter `closing`, reject new input, cancel queued
  operations, terminate the process tree, release slots after authoritative
  process exit, and retain transcript and operation results. Repeated calls
  return the stored state.

The extension registers the canonical `subagent` name. Any package-provided tool
with the same name, such as `npm:pi-subagents`, must be removed or disabled in
the same Pi runtime.

### 7.1 Current implementation status

The current implementation exposes `list`, `run`, `start`, `status`, `send`,
`wait`, `interrupt`, and `close`. Lifecycle actions identify a persistent
runtime by `runId` and a turn by `operationId`. `start` keeps one RPC process,
session, and transcript warm after its initial operation. A runtime accepts
sequential idle follow-ups, one follow-up queued behind active work, and guarded
steering of its accepted active operation. `run` remains a one-shot convenience
action and closes its runtime after settlement.

Implemented today:

- Reusable RPC runtimes with prompt-acceptance and `agent_settled` boundaries.
- Idle and single-slot queued follow-up operations in the same process and session.
- Active steering with an expected-operation guard and no extra operation result.
- Runtime/operation identity, monotonic in-memory revisions, and guarded interrupts.
- RPC `abort` for operation interrupt/deadline without closing a healthy runtime.
- Fresh child context, explicit tools, filtered environment, and process cleanup.
- Durable session paths under `<agent-dir>/subagent-sessions`.
- `runId`, `operationId`, `processInstanceId`, `sessionId`, and transcript paths.
- Bounded in-memory runtime and operation tracking.
- Bounded parent completion notifications for each submitted persistent operation;
  queued operations cancelled by close or shutdown do not notify.

Optional remaining reliability work is durable history and unclean-restart
reconciliation. That work would not make a runtime resumable. Reconnect/reporting
for a live prior process requires a different transport or supervisor design and
is not implied by the current architecture. Rich structured handoffs, usage
accounting, and a more compact status UI remain Milestone 2 work.

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
- Environment variables must be selected deliberately; secrets must not appear
  in logs or parent-visible results.

### 9.3 Process cleanup

RPC cancellation and shutdown follow an idempotent escalation sequence:

1. Send RPC abort when an operation is active.
2. Wait a bounded grace period.
3. Close stdin to request RPC runtime shutdown.
4. Wait for process exit.
5. Send `SIGTERM` after the shutdown deadline.
6. Send `SIGKILL` only after a second deadline.
7. Clear timers and remove listeners on every terminal path.

The JSON executor has no command channel. Controller cancellation sends
`SIGTERM` to the owned process group, waits a bounded grace period, escalates to
`SIGKILL`, and awaits authoritative process exit. It does not claim an accepted
abort or an `interrupted` operation result.

Parent `session_shutdown` must close all owned children. Cleanup must tolerate
already-exited processes and partial startup failures. On platforms where child
tools may create descendants, the controller starts the child in a process group
or uses an equivalent tracked-process mechanism and applies escalation to the
owned process tree, not only the Pi leader PID. Unexpected exit and failed spawn
release concurrency and writer reservations immediately.

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
- Static parallel batches fail preflight rather than partially start when their
  declared capacity cannot fit.

## 11. Persistence and recovery

Each persistent child uses a dedicated Pi session JSONL file. The extension must
record enough metadata to reconnect a logical run to that transcript.

M1 also maintains a small local run ledger, written atomically, containing the
run and operation IDs, agent, parent session, session ID/path, cwd, process
instance, owner extension instance, timestamps, and last known states.
The ledger is controller metadata, not a second copy of the child transcript.

V1 persistence guarantees:

- Full child transcript survives parent context compaction.
- A settled child result can be inspected without injecting the transcript into
  the parent context.
- Closing a runtime does not delete its transcript.
- Parent extension reload or restart may report existing transcripts even though
  automatic runtime resurrection is not implemented.

Normal `session_shutdown`, including extension reload, waits for owned children
to close before the replacement instance takes ownership. After an unclean
restart, the new instance does not attach by PID: it marks prior nonterminal runs
`crashed`, retains their transcripts as possibly incomplete evidence, and
quarantines their writer keys until it verifies that the prior process instance
has exited. Full automatic process resurrection is deferred. M1 workers remain
warm after settling until explicit close; cold residency is a later capability.

## 12. Observability

Parent-model output and user-facing UI are different channels.

Parent model receives:

- Run ID and state.
- Bounded progress summary when requested.
- Final structured handoff.
- Transcript reference.

UI/details may additionally show:

- Agent name, model, and thinking level.
- Duration and turn/tool activity.
- Current operation.
- Usage/cost where Pi exposes it reliably.
- Full bounded diagnostic error.

Intermediate child reasoning must not be copied into the parent model context.
JSONL parse failures and protocol violations must be surfaced as diagnostics,
not silently discarded.

Default V1 retention limits are:

```text
maxJsonlRecordBytes = 1 MiB
maxParserBufferBytes = 1 MiB
maxRetainedStderrBytes = 64 KiB
maxProgressSummary = 16,000 characters or 200 lines
maxFinalChildText = 32,000 characters or 400 lines
maxParentSerialization = 32,000 characters or 400 lines
```

The controller continuously drains stdout and stderr; limits bound retained
memory, not pipe consumption. It decodes split UTF-8 and partial LF-delimited
records incrementally. An oversized record or non-empty malformed JSON line is a
protocol failure and closes the child. Ring buffers and reduced output are
truncated with an explicit marker; secrets are redacted before retention and
serialization. Limits are configurable downward but cannot be disabled.

## 13. Validation strategy

### Unit-level contracts

- Agent frontmatter parsing and precedence.
- Runtime and operation transitions and invalid transition rejection.
- Operation-targeted wait and interrupt race cases.
- Concurrency reservation/release.
- Bounded output and redaction.
- Partial-line and split UTF-8 JSONL decoding.
- Idempotent cleanup and timer/listener removal.
- Result-envelope provenance and outcome mapping.
- Queued-operation cancellation without a fabricated interrupted result.
- Atomic ledger writes and unclean-restart reconciliation.

### Integration contracts

- Spawn a read-only child and receive a final result.
- Stream child tool activity without polluting parent-visible output.
- Abort a targeted operation and retain the child session.
- Send an idle follow-up to a persistent worker.
- Queue one follow-up behind active work and submit it after settlement.
- Steer the expected active operation without creating a second operation.
- Close a worker and verify its process exits and slot is released.
- Preserve transcript after close.
- Parent shutdown cleans up all children.

The deterministic suite uses protocol fixtures and never calls a model. The
opt-in `npm run test:subagent:live` smoke test requires `DEEPSEEK_API_KEY` and
uses DeepSeek Flash with minimal thinking and marker-only responses. It starts
the real pinned Pi RPC CLI, steers one active operation, submits one follow-up,
and verifies process/session/transcript reuse. Keep paid-provider tests out of
the default `npm test` path so routine validation cannot incur model cost.

### Failure cases

- Invalid agent definition.
- Missing model/provider authentication.
- Child startup error before RPC ready.
- JSON-mode stdin is not closed after the work order is written.
- Malformed or oversized JSONL/event output.
- Provider failure after prompt acceptance.
- Child process exits without a final response.
- Abort during startup, active tool execution, and settled state.
- Parent reload or exit while children are running.

## 14. Evolution roadmap

### Initial phase: Contracts and one-shot vertical slice

Implement the smallest end-to-end path, initially using the official Pi JSON-mode
subagent pattern if that reduces startup complexity:

```text
pi --mode json -p --no-session \
  --no-context-files \
  --no-extensions \
  --tools <allowlist> \
  --system-prompt <agent-system-prompt>
```

The controller uses `shell: false`, writes the complete work-order envelope to
stdin, and immediately ends stdin before awaiting output. JSON mode does not use
stdin as a persistent control channel; leaving the pipe open would prevent Pi
0.84.1 from starting the prompt. Optional model, thinking, and explicitly trusted
extension arguments follow the spawn contract.

Scope:

- User agent discovery and validation; project agents remain disabled.
- One foreground `run` action.
- Fresh work-order context.
- Explicitly materialized project guidance with `--no-context-files`.
- Explicit tool allowlist.
- Validated per-agent tool allowlists, including one-shot implementation agents.
- Bounded event/progress reduction.
- Controller-created minimal result envelope and final text handoff.
- Explicit execution deadline, process-group cancellation, and cleanup.

Acceptance:

- A `scout`-style read-only child can inspect a fixture repository and return a
  bounded answer.
- A `worker`-style child receives only its declared implementation tools and can
  execute an approved change in the selected cwd.
- Process-group cancellation leaves no child process and is reported as
  controller cancellation, not an RPC `interrupted` result.
- The parent result does not contain the full event stream.
- Malformed or oversized JSONL fails without unbounded buffering.

This milestone validates prompt shape, role usefulness, event parsing, and
process ownership. Because it uses `--no-session`, it intentionally does not
provide the durable-transcript guarantee and is a development vertical slice,
not a V1 cutover candidate.

### Milestone 1: Persistent RPC runtime (partial)

The RPC executor, durable session references, basic lifecycle actions, identity
separation, concurrency limit, and `agent_settled` completion are implemented.
The remaining work is listed explicitly below.

Replace or generalize the executor around:

```text
pi --mode rpc --session-dir <managed-dir>
```

Implemented:

- RPC-backed persistent execution with durable session references.
- `start`, `status`, immediate or single-slot queued `send(..., mode:
  "follow_up")`, guarded active `send(..., mode: "steer")`, `wait`, guarded
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

### Milestone 2: Steering and rich structured handoff

Implemented:

- Active `steer` and controller-queued `follow_up` modes.

Remaining:

- Structured progress, needs-decision, and final handoff messages.
- Usage and timing accounting where reliable.
- A compact status UI.

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

### Milestone 5: Optional advanced capabilities

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

## 15. Migration and coexistence

The repository contains `pi-subagents` as an installed npm dependency, but the
current `xdg_config/pi/agent/settings.json` has `"packages": []`; installation
does not imply that the package is loaded. Verify the effective runtime before
canonical tool cutover.

During development:

- Use a distinct extension entry point and temporary tool name.
- Keep runtime state outside the tracked source directory.
- Do not interpret the package's config or artifacts as this implementation's
  state.
- Compare behavior with the installed package through black-box tests where
  useful, but do not depend on undocumented internals.

At cutover:

- Remove or disable `npm:pi-subagents` before registering the canonical tool
  name.
- Preserve agent definitions only through an explicit migration.
- Start with new run/session state rather than attempting compatibility with old
  durable runs.

## 16. Open decisions

The following deployment-specific decisions remain. They do not change the
runtime/operation contracts above, but each must be resolved before the milestone
that consumes it:

1. Before upgrading from Pi 0.84.1: compatibility policy and contract tests for
   the new Pi version.
2. Before M1: runtime ledger and transcript directories.
3. Before M2: parent notification mechanism for background completion.
4. Before enabling project agents: whether trusted-project status is sufficient
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
