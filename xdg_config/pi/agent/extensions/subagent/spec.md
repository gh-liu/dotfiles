# Pi Subagent Extension Specification

- Status: Active (Milestones 1 and 2 partial)
- Updated: 2026-08-25 — render presentation is now `render/{index,shared,completion,call,result}.ts`; `render/index.ts` is the barrel. Tests are split into `test/{harness,capacity,discovery,lifecycle,notifications,rendering-integration,shutdown-cleanup,steering-interrupt}.test.ts` plus `render/index.test.ts`. Call titles color-differentiate name/model/thinking and use effective-model fallback. See `REFACTORING.md`.
- Updated: 2026-08-25 — bundled role descriptions use declarative capability hints; §4.7 owns routing pressure. Snapshots/results carry effective provider-stripped `model` and `thinking` when defined.
- Older updates: 2026-08-24 bounded handoff/details split; 2026-08-24 single prompt-catalog source and `promptSnippet`; 2026-08-24 deterministic close/auth/custom-tool/wait/tester coverage; 2026-08-24 removed declarative `skills:` prototype and restored zero-skill children; 2026-08-24 tester routing plus historical SDK migration via `createAgentSession`, RPC removal, timing plumbing, and `settings.json` subagents overrides.

## 1. Background

- Pi supplies extensions, JSON/RPC modes, SDK sessions, tools, transcripts, and lifecycle events, but no prescribed orchestration model.
- This extension is a small production subagent runtime: Codex-style control plane and identities, Claude-style fresh/fork context separation, Amp-style Agent/Thread/Executor separation and bounded handoff, and Pi star-topology work orders.

## 2. Goal

Provide a Pi extension letting a parent delegate bounded work to fresh-context Pi child sessions while the parent keeps decomposition, decisions, integration, verification, and final user-facing responsibility.

The extension must:
1. isolate child conversation context by default;
2. support one-shot and persistent controllable workers;
3. make lifecycle/resource ownership explicit;
4. restrict capabilities by declared agent definition;
5. preserve durable child transcripts while returning bounded parent results;
6. leave scheduling, write coordination, and change integration to the parent;
7. stay small enough to understand, test, and evolve.

## 3. Non-goals

The runtime does not provide: teams, DAGs, task claiming, leader election, child-to-child messaging, nested delegation beyond `maxDepth=1`, distributed/cloud/remote execution, worktree discovery, writer leases, schedules, missions, durable queues across machines, global memory, FleetView, automatic model selection/benchmarking, security claims based only on prompts/tool allowlists, or compatibility with `npm:pi-subagents` internals.

## 4. Design principles

### 4.1 Delegation is not ownership transfer

The parent owns the user outcome; a child performs one scoped unit and returns evidence. The parent integrates changes, evaluates findings, runs combined validation, and reports the final answer.

### 4.2 Fresh context by default

A child never implicitly inherits the parent transcript. The parent sends a self-contained work order with goal, scope, constraints, known decisions, evidence, validation, and return shape; the extension wraps it with canonical scope, runtime constraints, and project guidance.

### 4.3 One coordinator, leaf workers

```text
parent -> child A
       -> child B
       -> child C
```
Children cannot spawn children or message peers.

### 4.4 The parent owns write coordination

Capabilities come only from explicit tool allowlists. The extension does not add mutability flags, discover worktrees, or coordinate writes; the parent decides when agents may run and reviews/integrates workspace changes.

### 4.5 Separate identity, execution, and turns

Logical run ID, child process/session, and active model turn are distinct resources and must not substitute for each other.

### 4.6 Bounded handoff, durable evidence

The parent receives a concise structured result; complete evidence remains in the child transcript, referenced by session ID/path. Transcript references do not make runtimes recoverable after restart.

### 4.7 Routing is catalog-driven

- Delegation policy uses task boundaries and capabilities, not a fixed roster. Each definition's `description` is the model-facing routing contract.
- The tool description owns a bounded startup catalog; `list` refreshes discovery when definitions change or a requested name is absent.
- The Available-tools wake-word `promptSnippet` is derived by `buildWakeWordSnippet` from every effective registry entry at registration and includes names only; guidelines must not duplicate names/descriptions or become a second capability source.
- Bundled role descriptions state coverage and when-to-use hints (`Default subagent for …`, `use for …`, `never for code review`) rather than imperative delegation mandates.
- Delegate explicitly independent/fresh-eyes/second-opinion review after prerequisite writes settle; parent self-review does not satisfy independence.
- Delegate external research requiring multiple searches/sources, freshness checks, or source assessment before parent web research.
- Delegate standalone exploratory testing, dogfooding, QA, bug hunts, and browser automation to a tester role before parent browser use; children load no skills, so the role prompt embeds tool workflow.
- Bounded multi-file discovery, one high-impact unresolved decision, and separately owned implementation are strong candidates when a matching role improves isolation, quality, or parallelism.
- Simple lookups, localized edits, routine validation, and one-source factual checks remain direct parent work unless delegation is requested.
- The parent sends a self-contained work order, retains synthesis/final verification, avoids repeating successful cited read-only searches/reads except for decision-critical uncertainty, and always inspects scoped diffs plus integrated validation for write-capable handoffs.

## 5. Core concepts

### 5.1 Agent definition

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

- Definitions are Markdown with YAML frontmatter and prompt, loaded from `${PI_CODING_AGENT_DIR:-~/.pi/agent}/agents/*.md`.
- The implementation does not discover project-local definitions or compatibility paths; future project-local definitions require explicit trust/override policy.
- Parser rejects model fallbacks, executable extension declarations, non-fresh context policies, and depths other than one. Controller-owned tool-provider mappings load extensions needed for declared tools.

### 5.2 Work order

```ts
interface WorkOrder { goal: string; scope: string[]; nonGoals?: string[]; constraints: string[]; knownDecisions: Decision[]; evidence: EvidenceRef[]; validation: string[]; returnFormat: string; projectGuidance: string[]; }
interface Decision { statement: string; source: "user" | "parent" | "code" | "docs"; }
interface EvidenceRef { kind: "file" | "command" | "url"; value: string; }
```

- The tool accepts one self-contained `task`; the extension places it in `goal`, sets canonical child cwd in `scope`, adds fixed runtime constraints and project guidance, and currently leaves `knownDecisions`, `evidence`, and `validation` empty.
- Parents encode task-specific decisions/evidence/validation/return requirements in `task`; richer structured fields are future work.
- The envelope is compact JSON. Persistent runtimes receive full project guidance only on the initial operation and a continuity marker later; fresh runtimes receive full guidance every time.

### 5.3 Runtime and operation identity

- Distinct identities: `runId` (logical runtime from `start` to `close`), `operationId` (initial/later operation), `processInstanceId` (executor incarnation; SDK session has no OS PID), and `sessionId` (Pi transcript identity).
- Runtime and operation outcome are orthogonal.

```ts
type RuntimeState = "starting" | "idle" | "running" | "closing" | "closed" | "crashed";
type OperationState = "running" | "completed" | "failed" | "interrupted" | "cancelled";
interface RuntimeSnapshot { runId: string; revision: number; agent: string; model?: string; thinking?: string; status: RuntimeState; operationId?: string; activeOperationId?: string; activeOperation?: OperationSnapshot; lastSettledOperation?: OperationSnapshot; processInstanceId?: string; transcript?: { sessionId?: string; sessionPath?: string; }; }
interface OperationSnapshot { operationId: string; status: OperationState; task: string; startedAt?: number; finishedAt?: number; result?: SubagentResult; error?: string; }
```

`queued`/`cancelled-before-submit` were removed: running `follow_up` fails fast with conflict; `cancelled` remains terminal for future use. `model` is provider-stripped and `thinking` is effective thinking level when defined.

Required invariants:
- Transitions follow explicit runtime/operation state-machine edges; runtimes may alternate `idle`/`running`, operations are monotonic and never run twice.
- `waiting` is an observer action, not a state.
- `close` atomically enters `closing`, rejects new operations, and starts cleanup.
- Authoritative settlement plus successful disposal moves `closing` to `closed`; failed/timed-out abort/disposal moves to `crashed` and releases reservation.
- `interrupt` targets an expected operation and does not close the runtime.
- `interrupted` requires an accepted operation; `cancelled` currently has no producer.
- Pi turn boundaries reduce events but do not replace operation identity.

### 5.4 Current bounded handoff

```ts
interface SubagentResult { runId: string; operationId: string; processInstanceId?: string; agent: string; model?: string; thinking?: string; status: "completed" | "failed" | "interrupted"; summary: string; transcript: { sessionId?: string; sessionPath?: string; }; }
interface ModelSubagentHandoff { index?: number; agent: string; status: "completed" | "failed" | "interrupted"; summary: string; elapsedMs?: number; transcript: SubagentResult["transcript"]; }
```

- `SubagentResult` is controller-created; controller owns IDs, agent identity, status, and transcript references, never child JSON.
- Child final assistant text is bounded to 16k/16000 characters as `summary`; parent-visible serialization is bounded by character and line count.
- Tool `details` get session-local index and effective `model`/`thinking`; parent model sees only `ModelSubagentHandoff` without machine IDs/execution-profile metadata.
- `completed` requires authoritative settled event and complete final assistant response with normal stop; missing/truncated final responses fail with bounded partial text when available.
- Startup/provider/protocol/process failures that prevent reduction return tool errors with failed operation or crashed runtime snapshot; the controller does not fabricate `SubagentResult`.
- `interrupted` requires targeted aborted settlement; late interrupts never overwrite completed outcomes. Structured files/findings/validation/blockers/risks remain Milestone 2.

## 6. Runtime architecture

### 6.1 Default executor

Production uses one in-process Pi SDK session (`createAgentSession` via `sdk-executor.ts`) per active child for independent context/transcript, steering/follow-up/abort/status/persistent sessions, lower latency, and session disposal instead of process reaping. Trade-off: no OS-process isolation; containment relies on deadlines, abort watchdogs, bounded output, and credential redaction.

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

| Component | Responsibility |
| --- | --- |
| `AgentRegistry` | discover, parse, validate, resolve definitions |
| `RuntimeRegistry` | runtime/process/session/revision state |
| `OperationRegistry` | operation IDs, tasks, deadlines, outcomes |
| `ConcurrencyController` | total child limits |
| `ChildController` | one SDK session, listeners, timers, watchdogs, disposal |
| `ResultReducer` | bounded event/final-message handoff |

Implementation may keep responsibilities together until separation removes demonstrated complexity.

### 6.3 Current implementation map

```text
Parent model / Pi tool runtime
  |
  | subagent action + tool-call AbortSignal + progress callback
  v
index.ts: model-facing tool wiring
  |-- agents.ts: discover/validate user definitions
  |-- context.ts: canonical cwd and bounded AGENTS.md materialization
  |-- runtime.ts: in-memory control plane records, revisions, capacity, lifecycle
  |-- completion message: wake parent after persistent settlement
  |-- render/{index,shared,completion,call,result}.ts: bounded presentation behind barrel render/index.ts
  |
  | SubagentRunOptions / SubagentOperation / SubagentResult
  v
sdk-executor.ts: one SdkSubagentController per in-process session
  |-- session construction: cwd, explicit tool allowlist, model/thinking, custom tools
  |-- isolated DefaultResourceLoader: noExtensions, noSkills, noPromptTemplates, noThemes, noContextFiles, explicit systemPrompt
  |-- durable SessionManager under <agent-dir>/subagent-sessions/<runId>/
  |-- event/progress reduction, prompt acceptance, agent_settled completion
  |-- abort/deadline watchdogs, fatal notification, session disposal
  v
in-process AgentSession (createAgentSession)
  +--> child session JSONL (durable transcript evidence)
```

`protocol.ts` is the control/controller contract; `output.ts` bounds/redacts. Conceptual registry/concurrency/operation/result responsibilities are cohesive inside `index.ts`, `runtime.ts`, or `sdk-executor.ts`, not separate services.

| Component | Owns | Does not own |
| --- | --- | --- |
| Tool/control plane (`runtime.ts`) | Runtime/operation records, state transitions, revisions, slots, lifecycle, settlement notification data, bounded snapshots | Model-facing action dispatch, response envelopes, session construction |
| Tool surface (`index.ts`) | Extension wiring, discovery + settings overrides, TypeBox schema, prompt guidance, action dispatch, envelopes, completion delivery, shutdown hook | State transitions, slot accounting, event reduction |
| SDK controller (`sdk-executor.ts`) | One in-process Pi session, isolation flags, event reduction, deadline/abort watchdogs, fatal notification, disposal | Multi-runtime scheduling, model-facing status policy |
| Pi child | Model turns, tool execution, transcript | Parent integration decisions, runtime registry |
| Renderer (`render/{index,shared,completion,call,result}.ts`) | Bounded visual presentation and spinner lifecycle | Authoritative state or completion decisions |

Controller promises: `accepted` after session identity and prompt preflight; `result` after authoritative `agent_settled` and reduction; `failure` for idle/protocol/session failure. Persistent operations produce bounded `subagent-operation-settled` custom messages; synchronous `run` does not; close/shutdown settlement is suppressed.

### 6.4 Current data flows

#### One-shot `run`

```text
run -> resolve agent/cwd/guidance/work order -> reserve slot/create SDK controller -> prompt accepted -> wait for agent_settled -> reduce result -> dispose/release -> bounded SubagentResult
```
Retained runtime is only a bounded in-memory terminal record.

#### Persistent `start` and `send(follow_up)`

```text
start -> reserve slot -> create controller/session -> submit initial operation -> accepted -> return runId + operationId -> agent_settled -> idle -> notify
send(follow_up) -> new operationId -> submit only while idle; running returns conflict -> accepted -> return operationId -> agent_settled -> idle -> notify
close -> closing -> interrupt active operation if needed -> dispose -> release slot -> closed
```

`send` while `running`, `starting`, `closing`, `closed`, or `crashed` returns conflict/error; no buffering.

#### Interrupt and deadline

```text
expected operation active and accepted -> session.abort() -> wait for agent_settled within watchdog -> operation interrupted -> healthy runtime idle
```
Stale operation ID is no-op. Missing settlement within default `terminationGraceMs=5s` crashes/cleans the controller. Direct disposal is for close/fatal failures, not normal interrupt.

### 6.5 Persistence and restart boundary

- Durable: child session JSONL transcript evidence under `<agent-dir>/subagent-sessions/<runId>/`.
- Memory-only: runtime records, operation records, `revision`, retained results, waiters, controller ownership, capacity reservations.
- In-process session objects vanish after parent Pi/extension exit; a new instance cannot reconnect, continue, interrupt, or close old logical runtimes.
- Current design gives persistent workers within one extension lifetime plus durable transcripts, not crash-resumable/restart-durable runtimes.
- An atomic ledger may add history and unclean-restart reconciliation only; true recovery needs reconnectable transport or durable supervisor with adoption protocol.

### 6.6 Session construction contract

Each child session requires validated cwd under allowed root, explicit model/thinking when defined, explicit tool allowlist, explicit extension loading, dedicated `<agent-dir>/subagent-sessions/<runId>/`, isolated `DefaultResourceLoader` flags (`noExtensions`, `noSkills`, `noPromptTemplates`, `noThemes`, `noContextFiles`), explicit `systemPrompt`, and dedicated `SessionManager`.

Children share the parent's Pi version through `createAgentSession`; no cross-version pin is needed. Children never load skills; skill knowledge arrives only via role prompt or parent-composed work-order paths/excerpts (§16 item 6). `web_search` is registered as a session-scoped custom tool only when declared; injected custom tools are filtered exactly by effective allowlist. Project guidance is materialized into the work order; no implicit AGENTS.md inheritance. Credential values such as `EXA_API_KEY` and names from `PI_SUBAGENT_AUTH_ENV_ALLOWLIST` are redacted from progress/results; env names must match `^[A-Z_][A-Z0-9_]*$` and contain no newlines. User definitions are enabled; project-local definitions remain disabled. Effective `model`/`thinking`/`description` may be overridden by `settings.json` `subagents[agent]`; `auth.json/models.json` remain parent/user stores, not isolated child credentials. Bundled settings override models only; role definitions define thinking (`minimal` scout, `medium` worker/researcher/tester, `high` reviewer/oracle). V1 must not claim credential isolation until managed agent dirs, filtered auth store, and filesystem sandbox exist.

## 7. Tool surface

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

`action` is required; provider schema is one root object and runtime validates action-specific required fields.

- `list`: refresh discovery and return executable names/routing descriptions.
- `run`: one-shot start+wait+close. `deadlineMs` is required and separate from wait timeout. Omit `cwd` for parent current directory; use relative subdirectory when needed.
- `start`: reserve capacity, start persistent worker, submit initial operation, and return IDs only after readiness, session identity, and prompt acceptance. `deadlineMs` required; does not wait.
- `status`: bounded snapshot with monotonic `revision`, runtime state, active operation, and last settled operation; no internal polling.
- `send(..., mode: "follow_up")`: create operation and submit only when idle; running returns `{ accepted:false, conflict:true }` fail-fast, no queue; execution deadline starts at prompt submit.
- `send(..., mode: "steer")`: attach control message to active operation, no new operation/result; requires `expectedOperationId`, prompt accepted, operation still active; maps to `session.steer`.
- `wait`: with `id` and required `operationId`, wait for that operation or return stored result; with neither field, join all outstanding background operations. Timeout returns `{ reason: "timeout", snapshot }` or partial joined results without cancelling state. Multiple waiters may observe the same stored result.
- `interrupt`: abort only when `expectedOperationId` is still active; mismatch is conflict/no-op; authoritative settlement decides outcome.
- `close`: idempotently enter `closing`, reject input, dispose session, release slots after settlement, retain transcript/results; repeats return stored state.

Canonical tool name is `subagent`; any same-name package such as `npm:pi-subagents` must be disabled. Root-level JSON Schema unions are not used because DeepSeek rejects them.

### 7.1 Current implementation status

Implemented today:
- Actions `list`, `run`, `start`, `status`, `send`, `wait`, `interrupt`, `close`.
- Persistent runtimes by `runId`; turns by `operationId`; one SDK session/transcript warm after `start`.
- Sequential idle `follow_up`; running `follow_up` conflicts with no queue.
- Guarded active `steer`; guarded interrupts; monotonic in-memory revisions.
- Prompt-acceptance and `agent_settled` boundaries.
- `abort()` plus settlement watchdog for interrupt/deadline while preserving healthy runtime reuse.
- Fresh child contextPolicy only, explicit tools, credential redaction, session disposal.
- Timing: partial `startedAt`/`deadlineMs`; settled results/completions `elapsedMs`.
- Durable paths under `<agent-dir>/subagent-sessions` and identifiers `runId`, `operationId`, `processInstanceId`, `sessionId`.
- Bounded memory records enriched with effective provider-stripped `model`/`thinking` when defined.
- Discovery from `agents/*.md`; `settings.json` `subagents[agent]` overrides `model`, `thinking`, `description`; catalog and `list` show effective view.
- Bounded parent completion notifications and compact runtime UI with reduced live progress, short IDs, collapsed task previews, and expanded summaries.

Remaining: optional durable history/unclean-restart reconciliation without resumability; live prior-process adoption requires new transport/supervisor; rich structured handoffs, usage accounting, and needs-decision messages remain Milestone 2.

## 8. Context requirements

### 8.1 Fresh context

Fresh is the only required V1 context policy. Child receives agent system prompt, work order, selected project guidance, effective tools/runtime metadata, and files only by path/reference unless content materialization is requested. Child does not receive parent transcript, parent thinking/abandoned attempts, parent-only orchestration, unrelated tool outputs, or any implication that agent text is user approval.

### 8.2 Fork context

Fork is deferred. It must use an explicit parent session checkpoint, not mutable in-memory snapshots, and include parent session ID, checkpoint ID, copied turn number/range, context hash/provenance, and filtering rules for parent-only instructions/tool results. Forked context becomes child-owned; parent and child never share a mutable conversation object.

### 8.3 Working directory

Allowed root is parent canonical Git root or canonical current directory if no Git root. `run`/`start` omit `cwd` for parent current directory; subdirectories should be relative. The extension resolves/canonicalizes with native filesystem before containment checks, preserving casing and rejecting lexical/symlink escapes. Absolute paths are accepted only when canonicalized inside the allowed root.

## 9. Capability and security requirements

### 9.1 Capability is not permission or sandboxing

Layers are distinct: tool capability, per-call policy, process sandbox, credential scope. V1 implements explicit tool capability only and must not claim OS-level read-only/sandbox guarantees unless enforced. Tool allowlists limit model-visible capabilities but do not replace parent write coordination.

### 9.2 Trust boundaries

- Project-local definitions are repository-controlled input.
- Prompts are data and cannot grant tools/permissions.
- Executable hooks/extensions need stronger trust than Markdown.
- Child messages/reports carry provenance and cannot approve destructive/shared actions for the user.
- Cwd containment must handle canonical roots and symlink escape.
- User definition symlinks are accepted only if canonical target stays inside user agent dir.
- Progress, final text, and parent serialization are bounded.
- Environment variables are deliberate; known credentials and common formats are redacted best-effort, not isolated.

### 9.3 Process cleanup

- `interrupt` calls `session.abort()` and waits for authoritative `agent_settled`; watchdog (`terminationGraceMs`, default 5s) treats missing settlement as fatal.
- Idle `close` disposes; active close aborts first, including pre-acceptance. Abort dispatch is bounded by `terminationGraceMs`; timeout still disposes and surfaces cleanup failure rather than blocking slots.
- Every terminal path awaits settlement/disposal, clears timers, removes listeners, and releases reservations on unexpected creation/session failure.
- Parent shutdown closes owned children; partial startup failures are tolerated. No process tree exists to reap.

## 10. Concurrency requirements

```text
maxConcurrentRuns=3
maxDepth=1
```

Capacity is reserved before child creation; failed creation releases it; idle persistent workers hold slots until closed; children may share cwd; parent avoids conflicting writes and reviews workspace state; V1 fails fast when capacity is unavailable and never queues runs.

## 11. Persistence and recovery

Each child uses a dedicated in-process Pi session with JSONL transcript under `<agent-dir>/subagent-sessions`. Full transcript survives parent compaction, settled results can be inspected without injecting transcript, and close does not delete transcript. Runtime/operation records, revisions, retained results, and capacity are memory-only records. No ledger, restart reconciliation, process adoption, or transcript-based rediscovery exists. `session_shutdown`/extension reload waits for owned children to close. Unclean restart leaves at most a possibly incomplete transcript; a new instance must not infer controllability from PID/session file. Future atomic ledger may add durable history only; reconnectability needs supervisor/transport with adoption protocol.

## 12. Observability

Parent model receives lifecycle snapshots, final bounded envelope, and transcript reference. UI/details show agent, operation context, reduced live tool activity, seconds-based deadline countdown anchored at actual start, elapsed terminal durations, expanded completion metadata, and bounded diagnostics.

Collapsed calls show up to six task lines; collapsed results hide runtime/operation IDs; expanded calls/results show bounded task/diagnostics/metadata but omit full IDs. Call titles color-differentiate name/model/thinking (thinking uses per-level theme colors, unknown levels fall back to `thinkingText`) and fall back to effective model/thinking when parent omits them. Persistent completion wake-up text has exactly two lines per entry: `#N`, agent, status, optional elapsed seconds, bounded first meaningful task title (`Outcome:` stripped), then guidance (`status`/`follow-up`/`close #N`); full IDs/summaries stay in `details` and status/wait envelopes. `SUBAGENT_COMPLETION_MESSAGE` cards show short agent name, stripped task title, bounded summary, runtime status, optional elapsed time, and no full run/operation IDs. Active partial-state contributes spinner/countdown plus latest reduced redacted progress; terminal result lines omit agent label because call title carries `agent · model · thinking`.

Intermediate child reasoning must not enter parent model context. Malformed session events surface as diagnostics.

```text
maxToolArgDetailCharacters = 80 per progress detail value
maxProgressLineCharacters = 120 per reduced progress line
maxLivePreview = 160 characters on one line
maxFinalChildText = 32,000 characters or 400 lines
maxParentSerialization = 32,000 characters or 400 lines
```

Reduced progress wording is `X done · working…` / `X failed · reviewing…`; `$HOME` collapses to `~`; redaction precedes retention. Oversized text uses explicit `[truncated]` or `[truncated: additional project guidance omitted]`. Fixed implementation constants may later be lowered by config but not disabled.

### Live UI (widget)

`live-ui.ts` provides one transient display-only widget (`ctx.ui.setWidget("subagent-live", …, { placement: "aboveEditor" })`) and does not affect parent model context. It shows one compact line per runtime: `● #<index> <agent> · <elapsed> / <remaining> · <current activity>`.

Each runtime gets session-local `#1`, `#2`, … shown in live panel, completion cards, snapshots, and `run`/`start` titles after authoritative row details; id-taking actions accept it as alias. Background `start` shows `⟨bg⟩` while running and a dim `○ <agent> ⟨bg⟩ · idle · holds slot` until close; foreground `run` disappears on settle. Data flow is sdk-executor `onProgress` → hub `beginOperation` wrapper → live controller → `setWidget`. Renders are throttled leading+trailing 250ms with 1s heartbeat while tracked; timers stop when idle. `settle`/`remove` are idempotent. Methods no-op until `attach(ctx.ui)` under `ctx.hasUI`; headless/RPC modes are untouched.

## 13. Validation strategy

Deterministic tests own protocol, state, race, failure, rendering, and schema contracts. Paid evaluator owns model behavior only; probabilistic routing is not a substitute for deterministic lifecycle assertions. `npm test` runs strict TypeScript for production subagent sources and protocol fixtures; paid-provider coverage stays in `subagent/eval/`.

### Unit-level contracts

- Agent frontmatter parsing, validation, deterministic discovery.
- Runtime/operation transitions and invalid transition rejection.
- Operation-targeted wait/interrupt races.
- Concurrency reservation/release.
- Bounded output/redaction.
- Provider-compatible root-object schema and action-specific validation.
- Single startup catalog, all-registry wake word, model-facing context budget, capability routing.
- Native cwd canonicalization, containment, symlink escape.
- Idempotent cleanup and timer/listener removal.
- Result-envelope ownership/outcome mapping.
- Fail-fast running `follow_up` without fabricated result.

### Integration contracts

- Start read-only child and receive final result.
- Stream child activity without parent-visible pollution.
- Abort targeted operation and retain session.
- Send idle follow-up; running returns conflict.
- Steer expected active operation without second result.
- Close worker and release slot/dispose session.
- Preserve transcript after close.
- Parent shutdown cleans children.

Current capability-to-test map:

| Capability contract | Deterministic coverage | Real-Pi coverage |
| --- | --- | --- |
| Agent parsing, explicit/custom tools, fresh-only context, contained definition symlinks, discovery, overrides, single catalog, all-registry name wake word, model-facing context budget | `agents.test.ts`, `sdk-executor.test.ts`, `test/discovery.test.ts` | role-selection and work-order scenarios |
| Cwd/root containment, symlink escape, bounded project guidance | `context.test.ts` | isolated fixture workspaces |
| Explicit SDK session profile, durable transcript reference, result ownership | `sdk-executor.test.ts` | all delegated scenarios |
| One-shot run, persistent start/status/wait/follow-up/close | `test/lifecycle.test.ts`, `test/shutdown-cleanup.test.ts`, `sdk-executor.test.ts` | `persistent-follow-up` |
| Accepted-operation steering and guarded interrupt/reuse | `test/steering-interrupt.test.ts`, `sdk-executor.test.ts` | `steer-active-operation`, `interrupt-and-reuse` |
| Idle-only input, wait timeout, late-control races, monotonic revisions | `test/lifecycle.test.ts`, `test/steering-interrupt.test.ts` | persistent lifecycle scenarios |
| Capacity reservation/release and fail-fast fourth run | `test/capacity.test.ts`, `eval/analyze.test.ts` | `capacity-exhaustion` |
| Deadlines, interrupt and pre-accept close watchdogs, startup/provider/final-response failures | `sdk-executor.test.ts` | provider failures fail every eval run |
| Transcript preservation, idempotent cleanup, shutdown | `sdk-executor.test.ts`, `test/shutdown-cleanup.test.ts` | persistent lifecycle scenarios |
| Bounded/redacted progress, results, notifications | `output.test.ts`, `sdk-executor.test.ts`, `test/notifications.test.ts`, `test/rendering-integration.test.ts` | JSONL report inspection |
| Every call/result/completion renderer branch and live panel state | `render/index.test.ts`, `live-ui.test.ts` | `eval/ui-gallery.mjs` plus interactive runs |
| Parent routing, parallel evidence, staged roles, handoff consumption and verification | `eval/analyze.test.ts` | `eval/scenarios.mjs` |
| Tester provisioning policy, context-isolation wording, browser routing, source preservation, evidence artifacts | `agents.test.ts` | `browser-qa` |

Routing quality evaluator:

```text
node subagent/eval/run.mjs --quick
bun subagent/eval/run.mjs --quick
node subagent/eval/run.mjs
```

It uses isolated temp Git fixtures/Pi dirs, measures direct-work false positives, role selection, redundant parent work, implementation outcomes, ordered role composition, and lifecycle use. Deterministic execution/tool/schema failures fail; probabilistic thresholds warn in quick mode and fail in full mode. Reports keep JSONL and summaries; details live in `eval/README.md`.

### Failure cases

Invalid agent definition; missing auth; startup error before acceptance; malformed/oversized events; provider failure after acceptance; no final response; abort during startup/tool execution/settled state; parent reload/exit while children run.

## 14. Evolution roadmap

### Superseded exploration: JSON one-shot vertical slice

Historical only: JSON-mode one-shot explored prompt shape, allowlists, bounded parsing, deadlines, and process cleanup. Current tree has no JSON executor; in-process SDK now provides one-shot `run` and persistent lifecycle with durable transcripts.

### Milestone 1: Persistent runtime (partial; transport renamed)

Historical RPC/process-tree notes are superseded by in-process `createAgentSession` in `sdk-executor.ts`.

Implemented: SDK-backed persistent execution, durable session references, `start`/`status`/idle-only `send(..., mode: "follow_up")`/guarded `send(..., mode: "steer")`/`wait`/guarded `interrupt`/idempotent `close`, prompt acceptance vs settlement, abort watchdogs, separate identities, revisions, capacity, fatal-session observation, and `agent_settled` completion.

Remaining: optional atomic history and unclean-restart reconciliation without resumability; live process adoption needs reconnectable transport or durable supervisor.

Acceptance: multiple turns in one session; `wait` timeout leaves running; late `interrupt` cannot stop later operation; `interrupt` preserves transcript; `close` releases slot/disposes SDK session; closed transcript is inspectable but not resumable.

### Milestone 2: Steering and rich structured handoff (partial)

Implemented: active `steer`, idle-only `follow_up`, compact status/progress UI with collapsed/expanded presentations.

Remaining: structured progress, needs-decision, final handoff messages, and reliable usage/timing accounting.

Acceptance: parent can redirect at next model boundary; follow-up runs only after current generation settles; final result includes files, validation, blockers, risks, transcript provenance without transcript replay.

### Milestone 3: Explicit fork context

Add parent checkpoint selection, full/last-N policies, parent-only instruction filtering, provenance/hash, and fork depth enforcement.

Acceptance: reproducible persisted parent checkpoint; histories diverge after spawn; fork does not broaden tools, permissions, or secrets.

### Milestone 4: Optional advanced capabilities

Consider only after need: lower-latency SDK/in-process refinements, runtime pool/cold residency, permission arbiter for `ask`, child watchdog/reviewer integration, remote executor abstraction, and specialist profiles. Teams, peer messaging, shared DAGs, schedules, and missions require a separate coordination-plane specification.

## 15. Coexistence

Canonical `subagent` may collide with installed/cached packages; verify effective Pi settings and tool registry. Any package registering `subagent`, including `npm:pi-subagents`, must be disabled. This extension does not interpret or migrate other package configuration, transcripts, or runtime state.

## 16. Open decisions

1. Open — before tightening isolation: decide whether in-process sessions are sufficient or OS-sandboxed transport is required for untrusted workloads.
2. Open — before optional durable history: choose ledger location, retention, and unclean-restart reconciliation policy.
3. Open — before project agents: decide whether trusted-project status is enough or extension-specific confirmation is required in interactive and non-interactive modes.
4. Resolved — completion notifications/enumeration: background successes coalesce only within the same event-loop turn into one aggregated card (`details.batch`); failures/timeouts/interruptions notify immediately and include pending entries so each operation notifies once. Wake text is two bounded lines per entry with `#N`, status, title, and `status`/`follow-up`/`close #N`; full UUIDs/summaries stay in `details`, `status`, or `wait`; `appendEntry("subagent-settle-log", …)` records every settle durably for humans outside model context. `status` without id enumerates runtimes; `wait` without operationId joins outstanding background operations with bounded timeout/partial results.
5. Resolved — topology: children are fresh-context in-process sessions with no peer channels; parent is sole router/hub-and-spoke. P2P mailboxes/local-socket tools are rejected because handoffs need distillation, capacity is only 3, and debugging cost is high; cheap relay passes sibling transcript paths when the next hop has Read. DAG/workflow formats remain deferred.
6. Resolved — declarative child skill provisioning is rejected for now. Wildcard `*`, scalar `skills: all`, and dynamic parent grants drift from auditable definition-time capability; baseline is unconditional zero-skill construction (`noSkills`), role prompts embed workflows, and parents compose skill knowledge into work orders as paths/excerpts. Minimal explicit-list frontmatter was prototyped and removed on 2026-08-24; reconsider only on demonstrated drift/demand.

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
