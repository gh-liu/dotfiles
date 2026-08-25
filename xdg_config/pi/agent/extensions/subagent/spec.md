# Pi Subagent Extension Specification

- Status: Active (Milestones 1 and 2 partial)
- Updated: 2026-08-25 — render presentation split into `render-call.ts`,
  `render-completion.ts`, `render-result.ts`, and shared helpers in
  `render-shared.ts`, with `render.ts` kept as a pure barrel so import paths
  are unchanged; `index.test.ts` split into per-contract-area
  `index-*.test.ts` files plus `index-test-utils.ts` (move-only, same test
  count). See `REFACTORING.md`.
- Updated: 2026-08-25 — bundled role descriptions follow a declarative
  capability convention: they state coverage plus when-to-use hints (e.g.
  `Default subagent for …`, `use for …`, `never for code review`) instead of
  imperative MUST-delegation mandates. Delegation pressure stays in the §4.7
  routing guidelines; per-role selection hints stay inside each definition.
  Also clarified that snapshots/results carry effective `model`/`thinking`
  where the model id is provider-stripped and fields are omitted when
  undefined.
- Updated: 2026-08-24 — settled operation responses now separate authoritative
  UI/control `details` from a compact parent-model handoff that omits machine
  IDs and execution-profile metadata. Handoff summaries and their serialized
  envelopes are capped at 16k characters; full evidence remains in the durable
  child transcript.
- Updated: 2026-08-24 — model-facing prompt contributions now have one source
  for each concern: the tool description owns the bounded `name` + `description`
  startup catalog, while `promptSnippet` carries only discovered names and a
  compact delegation reminder. Guidelines retain work-order, lifecycle,
  concurrency, and handoff contracts without repeating the catalog. A character
  budget test guards this fixed context cost.
- Updated: 2026-08-24 — bounded pre-accept close, auth-environment validation,
  exact custom-tool filtering, contained definition symlinks, action-specific
  wait validation, and tester provisioning/isolation contracts now have
  deterministic coverage; a real-Pi browser-QA scenario covers tester routing,
  source preservation, and evidence output.
- Updated: 2026-08-24 — declarative skills frontmatter (`skills:` lists) was
  prototyped and removed the same day; child sessions return to unconditional
  zero-skill construction, skill provisioning is now open decision §16 item 6,
  parents compose skill references (paths or excerpts) into work orders, and
  roles embed their tool workflows in their prompts.
- Updated: 2026-08-24 — added catalog-driven routing for standalone exploratory
  QA/browser testing: a `tester` agent definition (`agents/tester.md`, embedded
  `agent-browser` CLI knowledge because children run with no skills) plus
  parent-guidance bullets delegating such work instead of driving the parent
  browser; "routine validation direct" now means rerunning existing checks,
  not interactive app exploration. Earlier (2026-08-21): transport swapped from `pi --mode rpc` subprocess to in-process SDK sessions (`sdk-executor.ts` via `createAgentSession`); `rpc-executor.ts` retired. Same-day audit removed residual RPC-subprocess descriptions (executor rationale, component diagram, flows, cleanup, retention limits) and documented timing plumbing. Earlier: restored `settings.json` `subagents[agent]` overrides for effective `model`/`thinking`/`description`

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
  workers, and fresh-eyes review.

## 2. Goal

Provide a Pi extension that lets a parent agent delegate bounded work to
fresh-context Pi child sessions while retaining responsibility for decomposition,
decisions, integration, verification, and the final user-facing result.

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
or a requested name is absent. The Available-tools wake-word `promptSnippet` is
derived from every effective registry entry at registration
(`buildWakeWordSnippet`), but includes names only. This keeps custom and renamed
roles visible without paying for every routing description twice. Prompt
guidelines select from the catalog; they must not duplicate agent names or
descriptions, assume a fixed count, or become a second source of truth for role
capabilities.

Bundled role descriptions follow a declarative capability convention: each
states what the role covers and when to use it (e.g. `Default subagent for …`,
`use for …`, `never for code review`) rather than an imperative delegation
mandate; the routing guidelines above carry the delegation pressure.

The parent classifies work before it starts equivalent reads or searches:

- An explicitly independent, fresh-eyes, or second-opinion review is delegated
  to a matching registered read-only role after prerequisite writes settle.
  Parent self-review does not satisfy an independence requirement.
- External research that requires multiple searches or sources, freshness
  checks, or source assessment is delegated to a matching registered read-only
  role before the parent starts its own web-research workflow.
- Standalone exploratory testing, dogfooding, QA, bug hunts, and browser
  automation of a running application are delegated to a matching registered
  tester role before the parent drives any browser itself; child sessions load
  no skills, so such a role embeds its tool workflow in its definition prompt.
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
in `task`; independently populated structured fields are future work. The envelope
is serialized as compact JSON. A persistent runtime receives full applicable
project guidance on its initial operation; later operations in that child session
receive only a continuity marker because they retain the initial guidance. A
fresh runtime always receives full guidance again.

### 5.3 Runtime and operation identity

Display names and PIDs are not durable identities. The control plane uses the
following distinct identities:

- `runId`: a logical child runtime from `start` until `close`.
- `operationId`: the initial work order or one later delegated operation.
- `processInstanceId`: one executor incarnation of a runtime; an in-process SDK
  session has no OS PID.
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
- `close` atomically enters `closing`, rejects new operations, and starts session cleanup.
- Authoritative operation settlement followed by successful session disposal
  moves `closing` to `closed`. A failed or timed-out abort/disposal moves the
  runtime to `crashed` and still releases its reservation.
- `interrupt` targets an expected operation and does not close the runtime.
- `interrupted` is reserved for an accepted operation; `cancelled` is retained only for future use and currently has no producer.
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

interface ModelSubagentHandoff {
  index?: number;
  agent: string;
  status: "completed" | "failed" | "interrupted";
  summary: string;
  elapsedMs?: number;
  transcript: SubagentResult["transcript"];
}
```

`SubagentResult` is a controller-created envelope. The controller, never child
JSON, owns IDs, agent identity, status, and transcript references. The child's
final assistant text is bounded to 16k characters and returned as `summary`.
The control plane enriches authoritative tool `details` with the session-local
index and effective `model`/`thinking` when available. The parent model sees only
`ModelSubagentHandoff`: machine IDs and execution-profile metadata remain in
`details`, while the short index, result, elapsed time, and transcript provenance
remain available for decisions and retries. The controller does not currently
parse files, findings, validation, blockers, or risks into separate fields.
Structured claims remain Milestone 2 work.

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

The production target runs one in-process Pi SDK session (`createAgentSession`
via `sdk-executor.ts`) per active child.

Reasons:

- Independent context and session transcript.
- Steering, follow-up, abort, status, and persistent sessions are available.
- No subprocess startup latency; the platform recommends `AgentSession` over
  spawning a subprocess for Node hosts (`docs/rpc.md`).
- Simpler lifecycle: session disposal replaces process-tree reaping.

Trade-off: OS-process isolation is traded away. Containment relies on
per-operation deadlines, abort watchdogs, bounded output, and credential
redaction rather than process signals.

### 6.2 Components

```text
Parent Pi
  -> SubagentTool
  -> AgentRegistry
  -> RuntimeRegistry
  -> OperationRegistry
  -> ConcurrencyController
  -> ChildController
       -> createAgentSession (in-process)
       -> event reducer
       -> deadline/abort watchdog
       -> session disposal
  -> ResultReducer
  -> child session JSONL
```

Responsibilities:

- `AgentRegistry`: discover, parse, validate, and resolve agent definitions.
- `RuntimeRegistry`: own runtime, process, session, and revision state.
- `OperationRegistry`: own operation IDs, tasks, deadlines, and outcomes.
- `ConcurrencyController`: enforce total child limits.
- `ChildController`: own exactly one SDK session and all associated listeners,
  timers, abort watchdogs, and disposal.
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
  |-- render-* modules (barrel render.ts): bounded call, progress, and terminal-state presentation
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
| Tool/control plane (`runtime.ts`) | Runtime/operation records, state transitions, revisions, capacity slots, operation lifecycle (begin/close), settlement notifications data, bounded snapshots | Model-facing action dispatch, response envelopes, session construction |
| Tool surface (`index.ts`) | Extension wiring, agent discovery + settings overrides, TypeBox schema, prompt guidance, action dispatch, response envelopes, completion delivery, shutdown hook | State transitions, slot accounting, session event reduction |
| SDK controller (`sdk-executor.ts`) | Exactly one in-process Pi session, session construction and isolation flags, event reduction, operation deadline/abort watchdogs, fatal notification, session disposal | Multi-runtime scheduling, model-facing status policy |
| Pi child | Model turns, tool execution, session transcript | Parent integration decisions, runtime registry |
| Renderer (`render-*.ts` behind the `render.ts` barrel) | Bounded visual presentation and spinner lifecycle | Authoritative state or completion decisions |

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
 -> dispose session -> release slot -> closed
```

The control plane accepts follow-ups only while the runtime is `idle`. A `send`
while `running`, `starting`, `closing`, `closed`, or `crashed` returns a
conflict/error rather than buffering work.

#### Interrupt and deadline

```text
expected operation still active and accepted
 -> session.abort()
 -> wait for authoritative agent_settled within the watchdog window
 -> operation interrupted
 -> healthy runtime returns to idle
```

A stale operation ID is a no-op. Missing settlement within the watchdog window
(default `terminationGraceMs` = 5 s) trips a watchdog and crashes/cleans the
controller rather than leaving shutdown blocked. Direct disposal is reserved for
close and fatal failures; it is not the normal operation-interrupt path.

### 6.5 Persistence and restart boundary

Current persistence is intentionally limited:

- The Pi child session JSONL is durable transcript evidence.
- Runtime records, operation records, revisions, retained results, and capacity
  reservations exist only in the extension process memory.
- The transport is an in-process session object. After the parent Pi or extension
  process exits, the session is gone; a new extension instance cannot reconnect
  to it or safely continue, interrupt, or close the old logical runtime.

Therefore the current design provides **persistent workers within one extension
lifetime** and **durable transcripts**, but not crash-resumable or restart-durable
runtimes. An atomic ledger by itself would add durable history and unclean-restart
reconciliation only; it must not advertise the runtime as resumable. True runtime
recovery requires a reconnectable transport or an independently durable
supervisor with an explicit adoption protocol.

### 6.6 Session construction contract

Each child session must be constructed with:

- A validated cwd under an allowed root.
- An explicit model and thinking level when the agent definition provides them.
- An explicit tool allowlist.
- Explicit extension loading; inherited extensions must not be accidental.
- A dedicated session directory under `<agent-dir>/subagent-sessions/<runId>/`.

The implementation runs children as in-process SDK sessions (`createAgentSession`)
and therefore always shares the parent's Pi version — no cross-version pin is
needed. Each child session is constructed with an isolated `DefaultResourceLoader`
(`noExtensions`, `noSkills`, `noPromptTemplates`, `noThemes`, `noContextFiles`), an
explicit `systemPrompt`, the agent's tool allowlist, per-session `model`/`thinkingLevel`,
and a dedicated `SessionManager` under `<agent-dir>/subagent-sessions/<runId>/`.
Children never load skills; skill knowledge reaches a child only through its role
prompt or parent-composed work-order references (path or excerpt) — see §16 item 6.
`web_search` is provided as a session-scoped custom tool when the effective tool
allowlist declares it. Any injected custom implementation is filtered by tool
name against that same effective allowlist; undeclared custom tools are never
registered. The parent resolves applicable project guidance and
materializes the selected text into the work-order envelope, so the child never
relies on implicit AGENTS.md inheritance. No extension is inherited by default.

Because children run in-process, there is no child environment construction.
Credential values that must never appear in child output (for example
`EXA_API_KEY` when `web_search` is declared, plus names from
`PI_SUBAGENT_AUTH_ENV_ALLOWLIST`) are redacted from progress and results instead.
Names are validated against `^[A-Z_][A-Z0-9_]*$` and must not contain newlines.
User agent definitions are enabled by default; project-local definitions
remain disabled. Effective agent `model`/`thinking`/`description` may be overridden via `settings.json` `subagents[agent]` after file discovery; the startup catalog and `list` discovery both reflect the effective merged view.
Bundled settings override models only, leaving role definitions as the source of
truth for thinking: `minimal` for scout, `medium` for worker/researcher/tester,
and `high` for reviewer/oracle.

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
  operation, and return the run and operation IDs only after session readiness,
  session identity, and prompt acceptance. Its task-specific `deadlineMs` is
  required. It does not wait for completion.
- `status`: return a bounded snapshot containing a monotonic `revision`, runtime
  state, active operation ID, and last settled operation; never poll internally.
- `send(..., mode: "follow_up")`: create a new operation. An idle runtime submits
  it immediately; a running runtime returns `{ accepted:false, conflict:true }` (fail-fast, no queue). The execution deadline starts when the prompt is submitted. Pi's native follow-up queue is not used because it lacks the
  per-turn correlation required by `wait`, deadlines, and stored results.
- `send(..., mode: "steer")`: attach a control message to the active operation;
  it does not create a new operation or independent settlement. The caller must
  provide `expectedOperationId`; steering is accepted only after that operation's
  prompt is accepted and while it remains active, then maps to `session.steer`.
- `wait`: with `id` and required `operationId`, wait for one specified operation.
  If it is already settled, return its stored result immediately. With neither
  field, join all outstanding background operations. Timeout returns
  `{ reason: "timeout", snapshot }` (or partial joined results) without changing
  state or cancelling work. Multiple waiters may observe the
  same stored result.
- `interrupt`: request abort only when `expectedOperationId` is still active.
  A mismatch returns a conflict/no-op, preventing a late abort from targeting a
  later operation. The authoritative settle event determines final outcome.
- `close`: idempotently enter `closing`, reject new input, dispose the session,
  release slots after authoritative settlement, and retain transcript and
  operation results. Repeated calls return the stored state.

The extension registers the canonical `subagent` name. Any package-provided tool
with the same name, such as `npm:pi-subagents`, must be removed or disabled in
the same Pi runtime. Its provider-facing parameter schema has a single object
root with action-dependent optional fields; root-level JSON Schema unions are
not used because DeepSeek rejects them before tool invocation. The extension
validates each action's required fields before accessing runtime state.

### 7.1 Current implementation status

The current implementation exposes `list`, `run`, `start`, `status`, `send`,
`wait`, `interrupt`, and `close`. Lifecycle actions identify a persistent
runtime by `runId` and a turn by `operationId`. `start` keeps one SDK session
and transcript warm after its initial operation. A runtime accepts
sequential idle follow-ups and guarded steering of its accepted active operation (running `follow_up` returns conflict, no queue). `run` remains a one-shot convenience
action and closes its runtime after settlement.

Implemented today:

- Reusable in-process SDK runtimes with prompt-acceptance and `agent_settled` boundaries.
- Idle follow-up operations in the same controller and session (running returns conflict, no queue).
- Active steering with an expected-operation guard and no extra operation result.
- Runtime/operation identity, monotonic in-memory revisions, and guarded interrupts.
- `abort()` plus a settlement watchdog for operation interrupt/deadline without losing a healthy runtime.
- Fresh child context, explicit tools, credential redaction, and session disposal.
- Timing plumbing: partial updates carry `startedAt`/`deadlineMs`; settled results and completion notifications carry `elapsedMs`.
- Durable session paths under `<agent-dir>/subagent-sessions`.
- `runId`, `operationId`, `processInstanceId`, `sessionId`, and transcript paths.
- Bounded in-memory runtime and operation tracking enriched with effective `model`/`thinking` in snapshots and serialized results; `model` is the provider-stripped model id and fields are omitted when undefined.
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
- User agent definition symlinks are accepted only when their canonical target
  remains inside the configured user agent directory.
- Progress lines, final result text, and parent serialization must be bounded.
- Environment variables must be selected deliberately. Known credential values
  and common credential formats are redacted before retention and serialization,
  but this best-effort filter is not a credential-isolation guarantee.

### 9.3 Process cleanup

Operation cancellation and shutdown follow related but distinct idempotent paths:

- `interrupt` calls `session.abort()` and waits for authoritative
  `agent_settled`; a watchdog (`terminationGraceMs`, default 5 s) treats missing
  settlement as a fatal controller failure.
- Normal idle `close` disposes the session; closing a still-active controller
  aborts the active run first, including before prompt acceptance. Abort dispatch
  is bounded by `terminationGraceMs`; timeout still disposes the session and
  surfaces cleanup failure instead of blocking the runtime slot indefinitely.
- Every terminal path awaits settlement or disposal, clears timers, and removes
  listeners.

Parent shutdown must close all owned children. Cleanup must tolerate partial
startup failures. There is no process tree to reap; containment comes from
deadlines, watchdogs, and disposal. Unexpected session failure and failed session
creation release concurrency reservations immediately.

## 10. Concurrency requirements

Initial defaults:

```text
maxConcurrentRuns = 3
maxDepth = 1
```

Required behavior:

- Capacity is reserved before child creation to avoid partial fan-out.
- Failed session creation releases its reservation.
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
  deadline countdown on the spinner line anchored at the operation's real start.
- Elapsed duration appended to terminal result lines and expanded completion metadata.
- Full bounded diagnostic error.

Collapsed calls show up to six task lines. Collapsed results hide runtime and
operation IDs and show only user-relevant state. Expanded calls show the bounded
full task; expanded results retain bounded diagnostics and metadata but continue
to omit full runtime/operation IDs. Persistent completion wake-up text contains
exactly two lines per entry: the session-local `#N`, agent, status, optional
elapsed seconds, and a bounded title derived only from the first meaningful task
line (`Outcome:` stripped), followed by runtime guidance
(`status`/`follow-up`/`close #N`). It omits full run/operation IDs and the summary; those machine details
remain in the message `details` payload and in `status`/`wait` envelopes. The custom
completion card still shows the short agent name plus the same stripped task title
before its bounded summary; it never flattens `Scope` or the rest of the work order
into the card, so a delayed notification stays concise without losing context. While an operation is active, its partial-state branch contributes
only an animated spinner with the countdown;
the output-preview path appends the latest reduced, redacted progress summary once.
It does not repeat the agent name or a generic `Running` label. Terminal result
lines omit the agent label entirely because the call title above already carries
the full `agent · model · thinking` identity. Expanded completion cards retain
bounded multiline summaries instead of flattening them to one line; their metadata
shows runtime status and optional elapsed time without full run/operation IDs.

Intermediate child reasoning must not be copied into the parent model context.
Malformed session events must be surfaced as diagnostics, not silently discarded.

Default V1 retention limits are:

```text
maxToolArgDetailCharacters = 80 per progress detail value
maxProgressLineCharacters = 120 per reduced progress line
maxLivePreview = 160 characters on one line
maxFinalChildText = 32,000 characters or 400 lines
maxParentSerialization = 32,000 characters or 400 lines
```

There are no stdout/stderr pipes to drain; the session event stream is reduced
in place. Reduced progress one-liners use the wording `X done · working…` /
`X failed · reviewing…`, collapse `$HOME` to `~` in tool paths, and are redacted
before retention. Oversized text is truncated with an explicit marker
(`[truncated]` for bounded text and `[truncated: additional project guidance omitted]` for guidance materialization). Exact configured credential values and common
credential patterns are redacted on a best-effort basis before retention and
serialization. These limits are fixed implementation constants; a future
configuration surface may lower them but must not disable them.

### Live UI (widget)

Active runtimes are surfaced to the human operator through one transient,
display-only channel (`live-ui.ts`); it does not change what the parent model
sees. A panel docked between the transcript and the editor
(`ctx.ui.setWidget("subagent-live", …, { placement: "aboveEditor" })`) shows
one compact overview line per runtime:

`● #<index> <agent> · <elapsed> / <remaining> · <current activity>`

Each runtime also carries a session-local short index (`#1`, `#2`, …) assigned
at creation: it is shown in the live panel, completion cards, snapshots, and
its `run`/`start` tool-call title once authoritative row details arrive; every
id-taking action accepts it (e.g. `id: "#2"`) as a human/model-friendly
alternative to the full runId. The collapsed tool-call box shows a
one-line task summary title instead of the raw work-order body; expanding
reveals the full bounded task.

where the activity is the latest reduced progress summary (thinking /
tool-call / streaming wording from the executor). It is deliberately an
overview surface: no history lines, no footer status entries.

Mode visibility: background (`start`) runtimes carry an `⟨bg⟩` badge while
running and, after their operation settles, stay visible as a dim line
`○ <agent> ⟨bg⟩ · idle · holds slot` until closed — making the capacity slot
they continue to hold observable. Foreground (`run`) runtimes leave the panel
as soon as they settle. The tool description documents both modes for the
parent model: one-shot runs by default, plus the persistent lifecycle
(start → wait/status/send → close), including the idle-holds-slot caveat and
the follow-up completion card that announces settled background work.

Data flow: sdk-executor `onProgress` summaries → the always-built wrapper in
the hub's `beginOperation` (which feeds the live controller unconditionally and
forwards to the tool's `onUpdate` only when provided) → the live controller →
`setWidget`. Renders are throttled (leading + trailing 250 ms) with a 1 s
heartbeat while any runtime is tracked so elapsed/countdown stay fresh; all
timers stop when idle. `settle`/`remove` are idempotent and drop the runtime
from the panel immediately (final state remains visible in the persistent tool
result box, which survives replay). Every method is a no-op until
`attach(ctx.ui)` runs under `ctx.hasUI`, keeping headless (-p) and RPC modes
untouched. Footer status lines were tried and deliberately dropped in favor of
this single overview surface; an overlay view for on-demand full logs remains
a deferred idea.

## 13. Validation strategy

### Unit-level contracts

- Agent frontmatter parsing, validation, and deterministic discovery.
- Runtime and operation transitions and invalid transition rejection.
- Operation-targeted wait and interrupt race cases.
- Concurrency reservation/release.
- Bounded output and redaction.
- Provider-compatible root-object schema and action-specific validation.
- Single startup catalog, all-registry name wake word, model-facing context
  budget, and capability-driven routing guidance.
- Native cwd canonicalization, project-root containment, and symlink escape.
- Idempotent cleanup and timer/listener removal.
- Result-envelope ownership and outcome mapping.
- Fail-fast on running follow_up (no queue) without a fabricated result.

### Integration contracts

- Start a read-only child and receive a final result.
- Stream child tool activity without polluting parent-visible output.
- Abort a targeted operation and retain the child session.
- Send an idle follow-up to a persistent worker (running returns conflict).
- Steer the expected active operation without creating a second operation.
- Close a worker and verify its session is disposed and slot is released.
- Preserve transcript after close.
- Parent shutdown cleans up all children.

The default `npm test` first runs strict TypeScript checking for production
subagent sources, then uses protocol fixtures without calling a model.
Paid-provider coverage lives in `subagent/eval/` and must stay outside routine
validation.

Current capability-to-test map:

| Capability contract | Deterministic coverage | Real-Pi coverage |
| --- | --- | --- |
| Agent parsing, explicit/custom tools, fresh-only context, contained definition symlinks, discovery, overrides, single catalog, all-registry name wake word, model-facing context budget | `agents.test.ts`, `sdk-executor.test.ts`, `index-discovery.test.ts` | role-selection and work-order scenarios |
| Cwd/root containment, symlink escape, bounded project guidance | `context.test.ts` | isolated fixture workspaces |
| Explicit SDK session profile, durable transcript reference, result ownership | `sdk-executor.test.ts` | all delegated scenarios |
| One-shot run, persistent start/status/wait/follow-up/close | `index-lifecycle.test.ts`, `index-shutdown-cleanup.test.ts`, `sdk-executor.test.ts` | `persistent-follow-up` |
| Accepted-operation steering and guarded interrupt/reuse | `index-steering-interrupt.test.ts`, `sdk-executor.test.ts` | `steer-active-operation`, `interrupt-and-reuse` |
| Idle-only input, wait timeout, late-control races, monotonic revisions | `index-lifecycle.test.ts`, `index-steering-interrupt.test.ts` | persistent lifecycle scenarios |
| Capacity reservation/release and fail-fast fourth run | `index-capacity.test.ts`, `eval/analyze.test.ts` | `capacity-exhaustion` |
| Deadlines, interrupt and pre-accept close watchdogs, startup/provider/final-response failures | `sdk-executor.test.ts` | provider failures fail every eval run |
| Transcript preservation, idempotent cleanup, shutdown | `sdk-executor.test.ts`, `index-shutdown-cleanup.test.ts` | persistent lifecycle scenarios |
| Bounded/redacted progress, results, notifications | `output.test.ts`, `sdk-executor.test.ts`, `index-notifications.test.ts`, `index-rendering.test.ts` | JSONL report inspection |
| Every call/result/completion renderer branch and live panel state | `render.test.ts`, `live-ui.test.ts` | `eval/ui-gallery.mjs` plus interactive runs |
| Parent routing, parallel evidence, staged roles, handoff consumption and verification | `eval/analyze.test.ts` | `eval/scenarios.mjs` |
| Tester provisioning policy, context-isolation wording, browser routing, source preservation, evidence artifacts | `agents.test.ts` | `browser-qa` |

The deterministic suite owns protocol, state, race, failure, and renderer
contracts. The paid evaluator owns model behavior only; a probabilistic routing
scenario is not a substitute for a deterministic lifecycle assertion.

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
- Child startup error before acceptance.
- Malformed or oversized event output.
- Provider failure after prompt acceptance.
- Session ends without a final response.
- Abort during startup, active tool execution, and settled state.
- Parent reload or exit while children are running.

## 14. Evolution roadmap

### Superseded exploration: JSON one-shot vertical slice

The initial design considered Pi JSON mode as a short-lived way to validate
prompt shape, tool allowlists, bounded event parsing, deadlines, and process-tree
cleanup. The current source tree has no JSON executor: the in-process SDK
controller now
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
- Sequential operations in one controller/session, with prompt acceptance separate
  from authoritative operation settlement.
- Operation interrupt and deadline through `session.abort()` with a settlement
  watchdog, leaving a healthy runtime reusable after `agent_settled`.
- Separate run, operation, process-instance, and session identities.
- Monotonic in-memory runtime revisions, concurrency limits, fatal-session
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
- `close` releases the slot and disposes the SDK session.
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
4. Resolved — completion-notification policy and multi-runtime enumeration.
   Former open question: per-operation immediate cards caused a card storm when
   several background runtimes finished together, and live/idle runtimes were
   not enumerable by the model. Adopted design:
   - Batched wake: successful background settlements coalesce within the same
     event-loop turn (microtask-drain via a zero-delay macrotask) and flush as
     ONE aggregated card (`details.batch`); failures/timeouts/interruptions
     notify immediately and carry earlier pending entries along so each
     operation notifies exactly once. A single background task degenerates to
     an immediate card — no mode switch needed.
   - Model-facing wake-up text uses exactly two bounded lines per entry: `#N`,
     agent, status, optional elapsed seconds, and the first meaningful task title
     (`Outcome:` stripped), then actionable runtime guidance using
     `status`/`follow-up`/`close #N`. Full UUIDs and summaries stay
     in `details`; harvest through `status #N` (or `wait` when an operation ID is
     already available), with transcript metadata available through either path.
     `appendEntry("subagent-settle-log", …)` records every settle durably for humans
     without entering model context.
   - Enumeration/join primitives: `status` without an id returns snapshots of
     ALL runtimes; `wait` without an operationId joins every outstanding
     background operation (bounded by `timeoutMs`, partial results on timeout)
     — restoring fork-join semantics for the background mode.
   No time-based partial flush is used: only settlements arriving in the same
   event-loop turn coalesce; staggered successes notify separately.
5. Resolved — inter-subagent communication topology. Children are fresh-context
   in-process sessions with no peer channels; the parent acts as the sole router
   (hub-and-spoke): harvest an envelope, distill it, and feed the next hop via
   a work order or `send`. Direct peer-to-peer (mailbox files or a local-socket
   `message_peer` tool registered into child sessions) is rejected for now:
   handoffs need intelligence (distill/filter), capacity is 3 slots so relay
   cost is negligible, and P2P turns debugging into distributed-systems work.
   Cheap relay optimization adopted: pass sibling transcript paths (already in
   every envelope/card) instead of content when the next hop has Read access.
   Declarative workflow formats are deferred until a genuinely repetitive
   multi-stage pipeline emerges from manual orchestration; do not build a DAG
   engine speculatively.
6. Open — declarative skill provisioning for child sessions (frontmatter
   `skills:` lists). Rejected three shapes: a `*` wildcard element (effective
   capability silently tracks ambient `skills/` directory contents, breaking
   fail-fast, dedupe/limit validation, and auditability), a `skills: all`
   scalar (same drift behind explicit syntax), and a dynamic parent-to-child
   skill grant unioned with definition-time declarations (a second capability
   source competing with the definition). Adopted baseline: child sessions are
   built unconditionally zero-skill (`noSkills`); role prompts embed their tool
   workflows, and parents compose undeclared skill knowledge into work orders
   as path references or excerpts (children hold read tools; skill bodies are
   user-dir input, same trust tier per §9.2). A minimal explicit-list
   frontmatter was prototyped and removed on 2026-08-24 for lack of
   demonstrated demand. Reconsider when a second role needs a non-stub skill
   body or embedded-prompt duplication starts drifting from canonical SKILL.md
   files.

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
