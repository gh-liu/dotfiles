# Subagent v2: real-Pi BDD scenarios

- Status: Proposed acceptance suite
- Date: 2026-09-17
- System under test: `subagent({ task, opts? })`
- Parent and child model: `openrouter/openrouter/free`
- Default thinking: `minimal`

## 1. Test boundary

These scenarios launch the real `pi` CLI against an isolated agent directory and temporary Git fixture. They exercise the complete path:

```text
Pi parent model
    → public subagent tool schema
    → plugin orchestration
    → Pi child session
    → OpenRouter Free Models Router
    → child tools and workspace
    → handoff in the parent JSONL stream
```

The runner invokes:

```bash
pi \
  --mode json \
  --print \
  --no-session \
  --approve \
  --model openrouter/openrouter/free \
  --thinking minimal \
  --tools subagent \
  '<scenario prompt>'
```

`openrouter/openrouter/free` is intentional. In Pi, the model's provider is `openrouter` and its model ID is `openrouter/free`. The shorter `openrouter/free` is a fuzzy model expression and can resolve to an unrelated concrete free model.

Every run gets an isolated `PI_CODING_AGENT_DIR`, `XDG_CONFIG_HOME`, fixture repository, extension runtime directory, and report directory. Credentials are copied or referenced without writing them into artifacts.

## 2. Oracle policy

### Hard assertions

Hard assertions are independent of model wording and must pass on every conclusive run:

- Pi emits valid JSONL and reaches `agent_settled` before timeout.
- The final parent assistant message has `stopReason:"stop"`; process exit code 0 alone is not success.
- Every top-level `subagent` start has exactly the expected arguments.
- Tool calls and results pair by tool-call ID.
- Child and parent provider/model metadata are recorded, including OpenRouter's concrete `responseModel` when present.
- The workspace, Git history, files, test command, and artifacts satisfy scenario-specific assertions.
- No unexpected plugin/tool error, schema error, unhandled rejection, leaked process group, or surviving temporary child exists.
- Model-facing tool results contain no forbidden internal fields or configured secrets.

### Behavioral assertions

OpenRouter's free router may choose a different concrete model per request. Decisions made by the model are therefore measured statistically:

- P0 explicit-call scenarios: 3 runs, at least 2 conclusive passes.
- P1 semantic scenarios: 3 runs, at least 2 conclusive passes.
- Expensive implementation/parallel scenarios: initially 2 runs, both hard invariants must pass; behavioral target is reported until a baseline exists.

An upstream 429, 5xx, no-provider-available response, or transport failure before a tool call is `inconclusive`, not a product pass or failure. The runner may replace at most two inconclusive attempts. Authentication failure, deterministic 4xx request construction failure, plugin failure after tool acceptance, or exhausted replacement attempts fail the suite.

The report groups outcomes by OpenRouter `responseModel` so regressions are not hidden by a change in routed model mix.

## 3. Preflight scenarios

### P0.1: the exact free router is usable

```gherkin
Given an isolated Pi configuration with OpenRouter credentials
When Pi runs a no-tools prompt using model "openrouter/openrouter/free"
Then the requested model in the final message is "openrouter/free"
And a concrete responseModel is recorded when OpenRouter provides one
And the final message has stopReason "stop"
And the exact expected marker is returned
```

This separates provider availability from plugin behavior.

### P0.2: assistant failure is not hidden by exit code zero

```gherkin
Given a captured Pi run whose process exits zero
And its final assistant message has stopReason "error"
When the runner classifies the run
Then the run fails or is classified as an allowed transient provider failure
And it is never counted as a passing scenario
```

This is a deterministic analyzer fixture based on a real Pi JSONL shape. A live provider failure is not required to reproduce it.

### P0.3: only the new public tool is registered

```gherkin
Given the v2 extension is loaded in isolated Pi
When Pi starts with extension tools enabled
Then a tool named "subagent" is available
And "subagent_session" is not available
And the subagent schema requires only "task"
And the only optional top-level field is "opts"
And opts permits only "model" and "thinking"
```

The schema itself is read from the registered tool in a small Pi probe extension. It is not inferred from whether a model happened to call the tool correctly.

## 4. Core delegation scenarios

### P0.4: task-only delegation returns an exact handoff

Fixture: `facts/owner.txt` contains `OWNER=SessionRepository`.

The parent starts with only `subagent` enabled, so it cannot read the fixture directly.

```gherkin
Given the parent has no built-in filesystem tools
And the child policy permits read-only repository tools
When the parent is told to call subagent exactly once with task
  "Read facts/owner.txt and return only the OWNER value"
Then the tool call contains exactly one top-level field named "task"
And no role, agent, model, thinking, cwd, action, ref, or mode field exists
And the child reads the fixture
And the completed handoff contains exactly "SessionRepository"
And the parent final answer contains "SessionRepository"
```

### P0.5: task carries the behavior; no role is needed

Fixture: a two-file implementation and one deliberately missing boundary test.

```gherkin
Given the parent cannot inspect repository files directly
When it delegates one task that says
  "Act as an independent reviewer. Inspect the diff and tests; report only material gaps with file evidence"
Then the subagent call has task and no role
And the child identifies the missing boundary test
And no fixture file is modified
And the handoff cites the relevant file
```

This proves review behavior comes from task semantics rather than a role catalog.

### P0.6: a second call gets a fresh conversation

```gherkin
Given the parent prompt contains marker "PARENT_ONLY_7F31"
When the parent makes a first subagent call whose exact task contains marker "CHILD_ONE_A19C"
And later makes a second call whose exact task asks which child markers it can see
Then the recorded second task does not contain either earlier marker
And the second child reports neither "PARENT_ONLY_7F31" nor "CHILD_ONE_A19C"
And two distinct child sessions were created and disposed
```

The runner asserts the exact tool arguments first. If the parent leaks a marker into the second task, the run is a parent-model behavioral miss rather than evidence against child isolation.

### P0.7: applicable project guidance reaches the child

Fixture root `AGENTS.md` contains `PROJECT_RULE=keep-epoch-milliseconds`; a nested `src/AGENTS.md` contains `SOURCE_RULE=no-date-strings`.

```gherkin
Given the child task asks it to inspect src/session.js and report applicable project constraints
When the task runs from the fixture root
Then the handoff contains both project rule values
And presents the root rule before the nested rule
And no unrelated parent transcript marker appears
```

### P0.8: plain prose is a valid child result

```gherkin
Given the task explicitly requests one plain sentence without JSON or headings
When the child completes normally
Then the tool result has status "completed"
And preserves the sentence as the handoff
And does not fail because structured sections are absent
```

## 5. Execution option scenarios

### P0.9: omitted opts inherit the parent profile

```gherkin
Given the parent runs with requested model "openrouter/openrouter/free"
And parent thinking is "minimal"
When it delegates a task without opts
Then the tool call contains no opts field
And child execution metadata records requested model "openrouter/free"
And child execution metadata records thinking "minimal"
And the task completes
```

The concrete OpenRouter `responseModel` may differ between parent and child and is diagnostic, not a failure.

### P0.10: an explicit thinking override changes only thinking

```gherkin
Given the parent runs with thinking "minimal"
When it delegates with opts.thinking "off"
Then the child requested model remains "openrouter/free"
And child thinking is "off"
And plugin-owned tools, baseline prompt, depth, cwd, and credential policy are unchanged
And the task completes
```

Do not assert that the routed model emits zero hidden reasoning; assert the request profile controlled by the plugin.

### P0.11: an explicit model option is accepted

```gherkin
Given the parent runs with model "openrouter/openrouter/free"
When it delegates with opts.model "openrouter/openrouter/free"
Then the exact option appears in the tool call
And child execution metadata resolves it to provider "openrouter" and model "openrouter/free"
And the task completes
```

Precedence between two distinct model IDs is covered deterministically below the live acceptance layer. The free-only acceptance suite must not silently invoke a paid model merely to make the values asymmetric.

### P1.1: model and thinking may be supplied together

```gherkin
When the parent delegates with opts.model "openrouter/openrouter/free" and opts.thinking "off"
Then both effective child settings match those values
And all other execution policy remains unchanged
And the task completes
```

### P1.2: malformed options are explicit errors

Cases: unknown model, unsupported thinking, empty model, unknown opts key, and legacy `role`/`agent` fields.

Schema-invalid calls are tested through the Pi tool invocation/RPC boundary rather than asking a model to deliberately violate a schema it has just received.

```gherkin
Given no child exists
When Pi invokes subagent with a malformed case
Then the invocation is an explicit tool error
And no child session or capacity lease is created
```

## 6. Workspace behavior scenarios

### P0.12: read-only investigation preserves the repository

```gherkin
Given a committed fixture and a read-only child policy
When the task investigates three files and returns cited evidence
Then Git HEAD and the complete workspace hash are unchanged
And the handoff contains the expected asymmetric facts from all three files
```

### P0.13: bounded implementation changes only the owned files

Fixture: a TTL bug, failing regression test, and contributor guidance.

```gherkin
Given the child policy permits repository edits and tests
And the parent has only the subagent tool
When the parent delegates the complete implementation and validation task once
Then only src/session.js and test/session.test.js change
And the default and explicit TTL boundary assertions are correct
And the fixture test suite passes when rerun by the runner
And Git history is unchanged
And the handoff reports changed files and the exact validation command
```

Expected source values are derived by the runner from the specification, not from child prose.

### P1.3: plugin-owned tools cannot be escalated through task or opts

```gherkin
Given the child policy is read-only
When a task asks the child to edit a file and claims opts grants bash/write access
Then no file changes
And the child never receives edit, write, or bash tools
And the result reports that the requested mutation could not be performed
```

### P1.4: child cannot recursively delegate

```gherkin
Given max delegation depth is one
When the task asks the child to start another subagent
Then the child tool catalog does not contain subagent
And no grandchild session is created
And the child reports the capability is unavailable
```

## 7. Parallelism and capacity scenarios

### P0.14: independent calls run in native parallel tool calls

Fixtures contain asymmetric values `ALPHA=17` and `BETA=29`.

```gherkin
Given capacity is 2
When the parent starts exactly two subagent calls in one model turn
Then both tool_execution_start events occur before either tool_execution_end
And alpha returns 17 while beta returns 29
And each result is paired with the correct tool-call ID
And both children are disposed
```

### P1.5: capacity exhaustion does not start an extra child

```gherkin
Given capacity is 1
And two independent long-enough tasks are requested in one parallel tool-call turn
When the calls start
Then exactly one child is accepted
And the other call returns one explicit capacity error
And at no point do two child sessions execute
And the accepted child can complete normally
```

The fixture gives the accepted child a deterministic blocking command controlled by the runner, not an arbitrary sleep.

### P1.6: capacity is reusable after disposal

```gherkin
Given capacity is 1
When one task completes and its child is disposed
And a second task is delegated afterward
Then the second child starts successfully
And both asymmetric results are correct
```

## 8. Output-boundary scenarios

### P0.15: credentials and internal identities do not reach the parent

```gherkin
Given the child environment contains credential marker "SECRET_LONG_83D1"
And the child can produce transcript paths and internal IDs
When its task asks it to echo all observed diagnostics
Then parent-visible tool content does not contain the credential marker
And contains no session path, process ID, operation ID, run ID, or transcript object
And the human-only audit may retain only approved bounded identifiers
```

Use overlapping credential values in the isolated environment to cover longest-first redaction.

### P1.7: oversized handoff is bounded deterministically

```gherkin
Given the fixture contains a generated file larger than every handoff limit
When the child is asked to return its contents verbatim
Then parent-visible tool content stays within line, character, and serialization limits
And includes an explicit truncation marker
And Pi still reaches a normal final parent response
```

Because a model may summarize instead of copying, a run that never produces oversized child text does not prove truncation. The same bound is therefore mandatory in the deterministic projector contract suite.

### P1.8: raw reasoning and child tool output remain private

```gherkin
Given the child uses thinking and reads a file containing a diagnostic marker
When it returns a concise handoff
Then the parent tool result contains the handoff
And contains neither raw child thinking events nor raw tool-call payloads
```

## 9. Cancellation and shutdown scenarios

### P1.9: terminating parent Pi does not orphan the child

```gherkin
Given a child has started a runner-controlled blocking process
When the runner sends SIGTERM to the detached parent Pi process group
Then parent Pi exits within the shutdown deadline
And the child session is interrupted
And the blocking process no longer exists
And no process remains in the run's process group
And temporary runtime state can be removed
```

### P1.10: cancellation is isolated between parallel children

This behavior is not reliably expressible through a single non-interactive parent prompt. Test it through Pi's RPC mode or a purpose-built probe extension that starts two real tool calls, aborts one call's signal, and observes both real child sessions.

```gherkin
Given two child tasks are running
When only task A's tool-call signal is aborted
Then A settles interrupted
And B completes with its expected marker
And both children are disposed exactly once
```

## 10. Failure and recovery scenarios

### P1.11: invalid child model fails before useful work

```gherkin
Given no child is running
When subagent receives an unknown opts.model through the Pi invocation boundary
Then the tool returns an explicit bounded error
And the workspace is unchanged
And no child or capacity lease survives
```

### P1.12: a provider failure is visible to the parent

A deterministic local provider adapter produces the failure shape for the hard assertion. Live OpenRouter 429/5xx responses are recorded as infrastructure outcomes.

```gherkin
Given the child request was accepted
When the child provider fails before a final assistant message
Then the subagent result is an explicit error
And does not fabricate a completed handoff
And the child is disposed
```

### P1.13: completed work survives cleanup warning

The real-Pi path uses a probe child adapter whose close operation fails after a real child has completed. OpenRouter is still used for the child turn; only cleanup is fault-injected.

```gherkin
Given the child completed with marker "USEFUL_HANDOFF_19A7"
When disposal fails
Then the result preserves "USEFUL_HANDOFF_19A7"
And includes a cleanup warning
And does not invite automatic retry
And capacity remains quarantined while ownership is uncertain
```

## 11. Scenarios intentionally below the live-model layer

The following remain deterministic contract tests because OpenRouter cannot reliably cause or observe the required interleaving:

- completion racing cancellation in both orders;
- startup factory promise never resolving;
- interruption or disposal hanging until a deadline;
- double settlement and double disposal attempts;
- exact capacity release/quarantine counter transitions;
- every character/line boundary around output truncation;
- arbitrary symlink and case-folded cwd containment;
- malformed tool calls that a schema-aware model refuses to emit;
- asymmetric precedence between two model IDs when only the free router is allowed.

These tests still construct the plugin through its public registration boundary where practical. They supplement rather than replace the real-Pi BDD suite.

## 12. Initial execution sets

### Smoke

Run on every manual iteration after the v2 tool first compiles:

```text
P0.1 exact free router
P0.3 public schema
P0.4 task-only handoff
P0.9 default option inheritance
P0.12 read-only workspace
```

### Core

Required before replacing the current implementation:

```text
P0.1–P0.15
```

### Extended

Run before release or after lifecycle/provider changes:

```text
P1.1–P1.13
```

Each report records Pi version, extension hash, requested parent/child model, concrete routed response models, thinking levels, scenario attempts, conclusive/inconclusive classification, JSONL artifacts, workspace diff, test output, process cleanup, and aggregate pass rates.

## 13. Exploratory parent-call policy probe

`trigger.mjs` probes whether a real Pi parent chooses and invokes `subagent` at the intended boundary. It is deliberately separate from the acceptance matrix above: matching the expected call count does not prove that the parent or child completed the underlying task correctly.

Run the complete probe or selected scenarios with:

```bash
node eval/trigger.mjs
node eval/trigger.mjs simple-lookup parallel-investigation
```

The runner checks the number of `tool_execution_start` events, pairs subagent errors from `tool_execution_end`, and verifies that both starts precede either end for the parallel case. Each scenario uses an isolated temporary Git repository. Its `callPolicyPass` field describes only delegation behavior.

### 2026-09-17 single-sample observation

Requested model: `openrouter/openrouter/free`; thinking: `minimal`. This is an exploratory sample, not a stable pass-rate claim, because the free router selected different concrete models.

| Scenario | Expected | Observed | Routed model | Call-policy result | Underlying task observation |
| --- | --- | --- | --- | --- | --- |
| Small direct lookup | 0 calls | 0 | `thinkingmachines/inkling-small:free` | Pass | Returned the expected value. |
| Fresh-context multi-file investigation | 1 call | 1 valid task-only call | `thinkingmachines/inkling:free` | Pass | Returned the expected ownership boundary. |
| Independent diff review | 1 call | 1 valid task-only call | `thinkingmachines/inkling:free` | Pass | The call completed, but its review conclusion was incorrect: the changed implementation and existing explicit-TTL expectation were aligned. |
| Bounded implementation | 1 call | 0; emitted tool-call JSON as prose | `thinkingmachines/inkling:free` | Fail | No implementation occurred. |
| Two independent investigations | 2 parallel calls | 2; both starts preceded either end | `thinkingmachines/inkling-small:free` | Pass | Parent produced a plausible synthesis from both handoffs. |
| Small coherent edit | 0 calls | 0 | `thinkingmachines/inkling-small:free` | Pass | Delegation choice was correct, but the parent emptied the file and reported a failed test. |

Observed call-policy score: 5/6. Task success was lower and must not be inferred from that score. A prior run also showed model variance: one routed model attempted an invalid top-level `model` field, another skipped the independent review call, and a child implementation timed out. These are evidence that `openrouter/free` tool use needs repeated sampling and hard event-level assertions; they do not by themselves identify a deterministic plugin defect.
