# Subagent Plugin: BDD-first redesign

- Status: Implemented core; extended live-model matrix remains staged
- Date: 2026-09-17
- Scope: A clean-sheet design. The current implementation is evidence about useful behavior, not an architectural constraint.

## 1. Product statement

The plugin does one thing:

> Run one bounded task in a fresh child context and return one trustworthy final handoff to the parent.

The first version intentionally supports only synchronous, one-shot delegation:

```ts
subagent({
  task,
  opts?: {
    model?: string;
    thinking?: "off" | "minimal" | "low" | "medium" | "high" | "xhigh" | "max";
  };
})
```

Independent work runs concurrently through the host's native parallel tool calls. The plugin does not implement its own scheduler, workflow graph, reusable conversation, background queue, notification bus, or activity dashboard.

`task` describes both the outcome and the way the child should contribute, such as investigation, review, implementation, or testing. A separate `role` would duplicate that instruction and force the caller to coordinate two behavioral inputs. When `opts` is absent, the child inherits the parent model and thinking level. `opts` changes execution characteristics, not task semantics.

Tool permissions, the baseline child system prompt, depth limits, and credential policy are plugin-owned safety policy. They are configured outside the model-facing call rather than exposed through `opts`.

### Goals

- Give the child a fresh conversation, the task, the project working directory, and applicable project guidance.
- Wait for authoritative child settlement and return a bounded, sanitized handoff.
- Propagate parent cancellation and plugin shutdown without orphaning owned children.
- Never run more children than the configured capacity.
- Keep the model-facing contract small enough that a model can call it correctly without lifecycle training.
- Make all core behavior deterministic under tests without launching a real model.

### Non-goals

- Persistent child sessions or follow-up messages.
- Background execution, polling, completion wakes, or custom notifications.
- Hidden task decomposition, retries, or DAGs.
- Filesystem, process, network, or credential sandboxing.
- Model-controlled tool permissions, system prompts, depth, or credential policy.
- Parsing model-written Markdown into a supposedly reliable structured protocol.
- Showing raw reasoning or tool output to the parent.

## 2. Behavior before architecture

The following scenarios are the executable specification. Scenario names should become test names. Tests call the registered tool through the same public boundary used by Pi; they do not reach into an internal state machine unless testing a pure component.

### Feature: run one bounded task

#### Scenario: a child completes successfully

```gherkin
Given capacity is available
When the parent delegates "Inspect the codebase and find the owner of token validation"
Then exactly one child is created with a fresh conversation
And its task, effective execution options, canonical cwd, and applicable guidance are supplied
And the tool waits for authoritative child settlement
And the final handoff is returned with status "completed"
And the child is disposed exactly once
```

The expected result must assert the actual handoff text, not merely that execution did not throw.

#### Scenario: two independent calls use native parallelism

```gherkin
Given capacity is 2
When two tool calls start before either child settles
Then two children run concurrently
And each result is paired with its own call
And settling one does not alter or dispose the other
```

Use asymmetric tasks and results (`alpha → result A`, `beta → result B`) so accidental cross-wiring fails the test.

#### Scenario: a sequential call gets a fresh context

```gherkin
Given one delegated task has completed
When a second task is delegated
Then a new child is created
And no transcript, messages, or internal identifier from the first child is supplied
```

### Feature: reject invalid work before side effects

#### Scenario outline: invalid input does not start a child

```gherkin
Given no child has started
When the tool receives <input>
Then it returns an explicit input error
And no capacity is reserved
And no child is created

Examples:
  | input                         |
  | missing task                  |
  | empty task                    |
  | whitespace-only task          |
  | malformed opts                |
  | unsupported thinking level    |
  | an unsupported extra control  |
```

Schema validation should reject all malformed values before the domain use case runs.

#### Scenario: a child cwd cannot escape the project root

```gherkin
Given the requested cwd resolves through a symlink outside the allowed root
When a task is delegated
Then the request fails before child creation
And the error does not reveal unrelated filesystem contents
```

Even if cwd is not model-facing, this remains a required adapter-level contract test.

### Feature: capacity is a safety invariant

#### Scenario: capacity exhaustion fails fast

```gherkin
Given capacity is 1
And one child is running
When another task is delegated
Then the second call returns a capacity error without creating a child
And the first child keeps running
```

#### Scenario: settlement releases capacity only after ownership is safe

```gherkin
Given capacity is 1
And a child has produced a final response but disposal is still pending
When another task is delegated
Then it is not allowed to exceed the real child limit
When disposal finishes
Then the next task can acquire capacity
```

This scenario prevents the common mistake of decrementing a counter when model output arrives while the underlying child is still alive.

#### Scenario: every failure path preserves the capacity invariant

Use a table-driven test for factory rejection, prompt rejection, protocol failure, cancellation, disposal failure, and shutdown. After each path, assert both the externally visible result and the number of owned live children. Counter-only assertions are insufficient.

### Feature: cancellation and shutdown

#### Scenario: parent cancellation interrupts only its child

```gherkin
Given task A and task B are running
When task A's parent signal is aborted
Then only child A receives interruption
And task A settles as "interrupted"
And task B can still complete normally
And both children are eventually disposed exactly once
```

#### Scenario: cancellation races with natural completion

```gherkin
Given a child is about to settle
When parent cancellation and child completion happen in either order
Then exactly one terminal result wins
And disposal happens exactly once
And capacity is not released twice
```

Run both deterministic orderings. Do not rely on timing or repeated randomized sleeps.

#### Scenario: shutdown rejects new work and drains owned work

```gherkin
Given one child is running
When plugin shutdown begins
Then new tool calls are rejected
And the running child is interrupted
And shutdown waits for bounded cleanup
And no plugin timer or owned child remains afterward
```

The production child adapter must provide bounded interruption. The domain layer should not invent a second, conflicting watchdog.

### Feature: failures remain actionable

#### Scenario outline: child execution fails

```gherkin
Given a valid task has been accepted
When <failure> occurs
Then the tool result is explicitly marked as an error
And it contains a bounded sanitized explanation
And the child is disposed exactly once
And capacity remains correct

Examples:
  | failure                    |
  | child construction fails  |
  | prompt is rejected         |
  | provider fails             |
  | protocol is malformed      |
  | no final assistant message |
```

#### Scenario: cleanup fails after useful work completed

```gherkin
Given a child has authoritatively completed with a useful handoff
When child disposal fails
Then the completed handoff is preserved
And a cleanup warning is attached
And the call is not presented as safe to retry automatically
And the capacity slot remains quarantined while the child may still be live
```

This distinguishes work failure from ownership cleanup failure and prevents duplicate implementation caused by a blind retry.

### Feature: output is safe and bounded

#### Scenario: secrets and internal identities never reach the parent model

```gherkin
Given child output contains a configured credential, session path, process id, and internal operation id
When the result is projected for the parent
Then the credential is replaced
And internal identities are absent
And ordinary source-code identifiers remain unchanged
```

Use overlapping secret values to prove longest-first replacement. Include a benign string resembling a key name to prove the sanitizer does not over-redact.

#### Scenario: oversized output has deterministic bounds

```gherkin
Given a final response exceeds both line and character limits
When the result is returned
Then it stays within both limits
And includes an explicit truncation marker
And retains the beginning of the handoff
```

Test line and character boundaries separately with asymmetric input. The expectation must be independently constructed rather than calling the production truncator.

#### Scenario: plain final text is valid

```gherkin
Given the child returns ordinary prose without prescribed headings or JSON
When it settles normally
Then that prose is accepted as the handoff
```

The child's response is untrusted prose. The plugin should not make correctness depend on a model obeying a custom serialization format.

### Feature: execution options and context resolution

#### Scenario: omitted options inherit the parent execution profile

```gherkin
Given the parent uses model "provider/parent" and thinking "medium"
When a task is delegated without opts
Then the child uses model "provider/parent" and thinking "medium"
```

#### Scenario: explicit options override only the named values

```gherkin
Given the parent uses model "provider/parent" and thinking "medium"
When a task is delegated with opts.model "provider/child"
Then the child uses model "provider/child" and thinking "medium"
And its tools, baseline prompt, depth, and credential policy remain plugin-controlled
```

Cover a thinking-only override and both overrides with asymmetric values. Reject an unresolved model before constructing a child rather than allowing an opaque SDK failure later.

#### Scenario: guidance is ordered and bounded

```gherkin
Given guidance exists at the project root and child cwd
When the child request is built
Then guidance is ordered root-to-leaf
And only applicable files are included
And individual and aggregate limits are enforced
```

### Feature: minimal rendering

#### Scenario: the invocation row is durable and non-secret

```gherkin
Given a task containing multiple lines and a credential
When the call is rendered collapsed and expanded
Then the collapsed row shows a bounded task title
And may show the effective model and thinking level as human-facing metadata
And the expanded row shows sanitized bounded task text
And a running call streams its sanitized current activity
And the expanded result shows bounded recent thinking and tool lifecycle summaries
And neither view shows transient running state after settlement
```

#### Scenario: the result distinguishes outcome without exposing reasoning

Assert running, completed, failed, and interrupted renderings. Running details may contain only bounded semantic thinking state and selected tool names, paths, patterns, or commands. Ensure raw thinking text, tool-call IDs, complete tool-call payloads, and child tool output are absent. The transcript tool row is the activity surface; there is no separate activity center.

## 3. Architecture derived from the scenarios

```text
Pi tool adapter
    │ validates schema and maps tool errors
    ▼
DelegateTask use case
    ├── ExecutionProfileResolver
    ├── ContextBuilder
    ├── CapacityLimiter
    ├── ChildRunner
    └── ResultProjector
             │
             ▼
       bounded parent handoff
```

### Domain use case

`DelegateTask` owns the complete one-shot transaction:

```text
validate → resolve profile/context → acquire lease → run child → project result → dispose → release lease
```

It has no knowledge of Pi renderers, SDK events, widgets, messages, transcript paths, or configuration file syntax.

### Ports

```ts
interface ExecutionProfileResolver {
  resolve(parent: ParentExecutionProfile, opts?: SubagentOptions): ChildExecutionProfile;
}

interface ContextBuilder {
  build(cwd: string, task: string): Promise<ChildContext>;
}

interface CapacityLimiter {
  tryAcquire(): CapacityLease | undefined;
}

interface CapacityLease {
  release(): void;
  quarantine(): void;
}

interface ChildRunner {
  run(request: ChildRequest, signal: AbortSignal): Promise<ChildRun>;
}

interface ChildRun {
  result: ChildResult;
  dispose(): Promise<void>;
}

interface ResultProjector {
  success(result: ChildResult, warning?: string): ParentResult;
  failure(error: unknown): ParentResult;
}
```

Exact interfaces may change during red-green-refactor. The important seams are child execution, capacity ownership, context construction, and output projection. Time, IDs, filesystem access, and SDK construction are injected only where tests require deterministic control.

### State model

```text
requested ─▶ reserved ─▶ starting ─▶ running ─▶ settled ─▶ disposing ─▶ done
                 │           │          │            │
                 └───────────┴──────────┴────────────┴──▶ failed/interrupted
```

Externally, only `completed`, `failed`, and `interrupted` matter. Internal intermediate states should not be stored in a general-purpose mutable runtime registry. One tool invocation owns one local transaction. This removes reference resolution, operation maps, pruning, notification acknowledgement, and cross-turn races.

### Public result

The model-facing result is deliberately small:

```ts
type ParentResult =
  | { status: "completed"; handoff: string; warning?: string }
  | { status: "failed"; error: string }
  | { status: "interrupted"; error: string };
```

No run ID, operation ID, process ID, transcript path, turn, ref, mode, timeline, raw usage, or child reasoning is public. Diagnostic identities may go to a human-only log if Pi provides one, but must not share the model projection.

## 4. Test design

### Test layers

1. **Real-Pi BDD acceptance tests** — launch the real `pi` CLI with `openrouter/openrouter/free`, invoke the public tool through a parent model, and assert JSONL, workspace, provider, and process outcomes. These own user-visible behavior.
2. **Pi invocation probes** — invoke the registered tool through Pi's RPC/probe boundary for schema-invalid cases and precise cancellation that a language model cannot emit reliably.
3. **Deterministic lifecycle contracts** — control a fake `ChildRunner` only for races, hangs, cleanup failures, and exact capacity ownership that a remote provider cannot reproduce on demand.
4. **Pure component tests** — option resolution, canonical path containment, guidance ordering/bounds, sanitization, and output bounds.
5. **SDK adapter contract tests** — run the real adapter against a deterministic fake SDK event source. Verify event reduction, authoritative settlement, abort, and disposal.
6. **Renderer tests** — small semantic assertions for collapsed, expanded, success, failure, and interruption states. Avoid broad snapshots.

The complete real-Pi matrix, oracle policy, fixture requirements, and smoke/core/extended sets are specified in [`eval/bdd-v2.md`](eval/bdd-v2.md). Provider-dependent tests do not replace deterministic fault tests, and deterministic tests do not claim end-to-end coverage.

### Fixture rules

- Use a scenario harness with domain vocabulary: `givenParentProfile`, `givenCapacity`, `delegate`, `childAccepted`, `childCompleted`, `cancelParent`, `shutdown`.
- The fake child tracks real ownership (`created`, `running`, `disposed`) independently from the capacity counter.
- Deferred promises control ordering; fake timers control explicit time boundaries. No arbitrary sleeps.
- Every concurrency test uses unique tasks, results, and child identities.
- Every failure assertion also checks child disposal and capacity ownership.
- Public-boundary tests inspect both the tool result and the model-facing serialized content.
- Tests assert absence of internal fields recursively rather than checking only a few known IDs.

### Suggested feature-oriented files

```text
test/
├── delegate-success.feature.test.ts
├── delegate-validation.feature.test.ts
├── delegate-capacity.feature.test.ts
├── delegate-cancellation.feature.test.ts
├── delegate-failures.feature.test.ts
├── delegate-output.feature.test.ts
├── options-context.feature.test.ts
├── shutdown.feature.test.ts
├── sdk-runner.contract.test.ts
└── rendering.feature.test.ts
```

The tests use `describe/it` with Given/When/Then helper names; adding a Gherkin parser would add ceremony without improving executable behavior.

### Invariants checked after every scenario

The harness should expose one shared `thenOwnershipIsConsistent()` assertion:

- active capacity leases equal owned children that may still execute;
- no child is disposed more than once;
- no settled invocation can settle again;
- no result belongs to another invocation;
- no rejected request created a child;
- parent-visible output is bounded, sanitized, and free of internal identity;
- after shutdown, new work is rejected and owned resources are drained or explicitly quarantined.

Property-based tests are worthwhile only for two pure boundaries: arbitrary path containment and arbitrary output bounding/redaction. Stateful concurrency is clearer as a small set of deterministic interleavings.

## 5. Red-green implementation order

Each slice begins with one failing public behavior and ends with the narrowest implementation that passes:

1. Register the one-required-field tool and complete one successful fake child task.
2. Reject malformed tasks and options before child creation.
3. Add fresh context, canonical cwd containment, and bounded guidance.
4. Add explicit child failure mapping and authoritative settlement.
5. Add parent cancellation and deterministic completion/cancel races.
6. Add capacity leases and parallel-call isolation.
7. Add sanitization, internal-field removal, and output bounds.
8. Add bounded shutdown and cleanup-failure quarantine.
9. Add minimal transcript rendering.
10. Add the SDK adapter contract suite, then the real-Pi smoke set with `openrouter/openrouter/free`.

Do not build session reuse, background notification, or an activity dashboard speculatively. If usage later proves one of them necessary, introduce it as a separate feature with its own BDD contract and preferably a separate tool, rather than expanding the core transaction into a workflow engine.

## 6. Acceptance gates

- Strict TypeScript passes.
- All deterministic tests pass under real and fake timers where applicable.
- Tests leave no unhandled rejection, timer, listener, temporary directory, or owned child.
- Mutation or deliberate fault checks demonstrate that tests fail for at least: cross-wired parallel results, early capacity release, double disposal, missing sanitization, cancellation of the wrong child, and acceptance of a non-authoritative final message.
- The real-Pi smoke set passes with `openrouter/openrouter/free`; provider-transient attempts are reported separately and never counted as product passes.

## 7. Implemented executable coverage

The first implementation contains 38 deterministic BDD/contract cases grouped by feature rather than internal module:

| Area | Executable behavior |
| --- | --- |
| Public API and validation | `task` is the only required field; `opts` permits only `model` and `thinking`; legacy/extra controls, blank tasks, malformed opts, unknown models, and unsupported thinking fail before child creation |
| One-shot isolation | successful handoff, asymmetric parallel result pairing, and a fresh child for every sequential call |
| Profile and context | parent model/thinking inheritance, independent overrides, canonical cwd containment, ordered applicable `AGENTS.md`, per-file and aggregate guidance bounds |
| Capacity ownership | fast rejection at capacity, reservation during child construction, no release before disposal, reuse after safe disposal, and quarantine after uncertain cleanup |
| Cancellation and shutdown | per-call cancellation isolation, both completion/cancel orderings, one terminal result, idempotent disposal, shutdown rejection and draining |
| Failure semantics | construction/provider/protocol failures are explicit, bounded errors; successful work survives cleanup failure with a no-auto-retry warning |
| Parent output boundary | plain prose accepted, credentials and internal identities redacted, line/character limits and truncation marker enforced |
| SDK adapter | plugin-controlled tool set and system context, authoritative `agent_settled`, final assistant extraction, incomplete-response rejection, idempotent abort/dispose |
| Rendering | bounded sanitized call rows and distinct completed/failed/interrupted results without reasoning or internal IDs |

The provider-backed smoke is repeatable from `xdg_config/pi/agent/extensions`:

```bash
node subagent/eval/smoke.mjs
```

It launches real Pi with `openrouter/openrouter/free`, permits only `subagent` in the parent, asserts the exact task-only arguments, reads an asymmetric fixture through the child, requires final `stopReason:"stop"`, and verifies the exact handoff. The larger P0/P1 live matrix in [`eval/bdd-v2.md`](eval/bdd-v2.md) remains the staged acceptance plan rather than being falsely represented as implemented.
