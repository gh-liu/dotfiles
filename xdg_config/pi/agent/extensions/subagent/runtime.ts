import type { LiveUiController } from "./live-ui.ts";
import { boundText, modelSubagentHandoff } from "./output.ts";
import { normalizeProgress } from "./progress.ts";
import { stripModel } from "./protocol.ts";
import type { SubagentCompletionDetails } from "./render/index.ts";
import type {
  SubagentController,
  SubagentControllerFactory,
  SubagentProgress,
  SubagentResult,
  SubagentRunOptions,
} from "./protocol.ts";

/** Control-plane ownership: runtime/operation records, slots, transitions, and settlement. */

type RuntimeState = "starting" | "running" | "idle" | "closing" | "closed" | "crashed";
type OperationState = "running" | "completed" | "failed" | "interrupted" | "cancelled";

export interface OperationRecord {
  operationId: string;
  /** Monotonic user-facing turn number within the reusable session. */
  turn: number;
  state: OperationState;
  accepted: boolean;
  task: string;
  workOrder: SubagentRunOptions["workOrder"];
  startedAt?: number;
  finishedAt?: number;
  result?: SubagentResult;
  error?: string;
  latestProgress?: {
    summary: string;
    recentActivity: string[];
    timeline?: NonNullable<SubagentProgress["timeline"]>;
    tools?: NonNullable<SubagentProgress["tools"]>;
    phase?: SubagentProgress["phase"];
    needsDecision?: true;
    decision?: { question: string; options?: string[] };
  };
  notifyOnSettle: boolean;
  /** At-most-once guards so audit and wake never deliver twice. */
  notified?: boolean;
  audited?: boolean;
  settled: Promise<void>;
  settle(): void;
}

export interface RuntimeRecord {
  /** Session-local short index (#N) for human/model-friendly targeting. */
  index: number;
  runId: string;
  revision: number;
  nextTurnNumber: number;
  agent: SubagentRunOptions["agent"];
  cwd: string;
  parentSessionId: string;
  projectGuidance: string[];
  state: RuntimeState;
  controller?: SubagentController;
  controllerReady: Promise<SubagentController>;
  activeOperationId?: string;
  lastSettled?: OperationRecord;
  operations: Map<string, OperationRecord>;
  closePromise?: Promise<void>;
  slotReserved: boolean;
}

function deferred<T>(): {
  promise: Promise<T>;
  resolve(value: T): void;
  reject(error: unknown): void;
} {
  let resolve!: (value: T) => void;
  let reject!: (error: unknown) => void;
  const promise = new Promise<T>((next, fail) => { resolve = next; reject = fail; });
  return { promise, resolve, reject };
}

export interface RuntimeHubDeps {
  controllerFactory: SubagentControllerFactory;
  /** Maximum concurrently executing turns. Idle reusable sessions do not consume a slot. */
  maxConcurrentRuns?: number;
  /** Completion sink; the hub builds bounded details, the shell delivers them. */
  /** Returns true once Pi has queued the completion message. */
  notifySettled: (details: SubagentCompletionDetails | { batch: SubagentCompletionDetails[] }) => boolean;
  /** Optional durable human-visible settle log (appendEntry); never wakes the model. */
  logSettled?: (details: SubagentCompletionDetails) => void;
  /** Live UI controller observing runtime lifecycle for footer/widget display. */
  live: LiveUiController;
  controllerCreationTimeoutMs?: number;
  maxRetainedRuntimes?: number;
  /** Exact credential values to redact from wake/audit text before bounding. */
  credentialSecrets?: readonly string[];
}

export interface CreateRuntimeInput {
  agent: RuntimeRecord["agent"];
  cwd: string;
  parentSessionId: string;
  projectGuidance: string[];
  initialOptions: SubagentRunOptions;
}

export interface BeginOperationInput {
  operationId: string;
  task: string;
  notifyOnSettle: boolean;
  workOrder: SubagentRunOptions["workOrder"];
  signal?: AbortSignal;
  onUpdate?: (update: { content: Array<{ type: "text"; text: string }>; details: Record<string, unknown> }) => void;
}

export interface RuntimeHub {
  readonly maxConcurrentRuns: number;
  get(runtimeId: string): RuntimeRecord | undefined;
  /** Resolve an internal runtime ID or the public session-local #N/N alias. */
  resolve(reference: string): RuntimeRecord | undefined;
  capacityAvailable(): boolean;
  occupiedSlots(): number;
  availableSlots(): number;
  isShuttingDown(): boolean;
  /** Reserve one execution slot for an idle reusable session. */
  reserveSlot(runtime: RuntimeRecord): boolean;
  createRuntime(input: CreateRuntimeInput): RuntimeRecord;
  /** All tracked runtimes (active and idle). */
  listRuntimes(): RuntimeRecord[];
  beginOperation(runtime: RuntimeRecord, input: BeginOperationInput): Promise<OperationRecord>;
  /** Marks a runtime crashed before its close path exists (startup/acceptance failures). */
  markCrashed(runtime: RuntimeRecord): void;
  closeRuntime(runtime: RuntimeRecord, suppressNotification?: boolean): Promise<void>;
  requestShutdown(): Promise<void>;
}

export function createRuntimeHub(deps: RuntimeHubDeps): RuntimeHub {
  const maxConcurrentRuns = deps.maxConcurrentRuns ?? 3;
  const credentialSecrets = deps.credentialSecrets ?? [];
  const controllerCreationTimeoutMs = deps.controllerCreationTimeoutMs ?? 10_000;
  const maxRetainedRuntimes = deps.maxRetainedRuntimes ?? 100;
  const runtimes = new Map<string, RuntimeRecord>();
  let nextRuntimeIndex = 1;
  let occupiedSlots = 0;
  let shuttingDown = false;

  const transition = (runtime: RuntimeRecord, state: RuntimeState): void => {
    runtime.state = state;
    runtime.revision += 1;
  };

  const releaseSlot = (runtime: RuntimeRecord): void => {
    if (!runtime.slotReserved) return;
    runtime.slotReserved = false;
    occupiedSlots -= 1;
  };

  const prune = (): void => {
    for (const runtime of runtimes.values()) {
      while (runtime.operations.size > 128) {
        const stale = [...runtime.operations.values()].find(
          (operation) => operation !== runtime.lastSettled
            && operation.operationId !== runtime.activeOperationId
            && operation.state !== "running",
        );
        if (!stale) break;
        runtime.operations.delete(stale.operationId);
      }
    }
    const terminal = [...runtimes.values()].filter((runtime) =>
      (runtime.state === "closed" || runtime.state === "crashed") && !runtime.slotReserved
    );
    for (const runtime of terminal.slice(0, Math.max(0, terminal.length - maxRetainedRuntimes))) {
      runtimes.delete(runtime.runId);
    }
  };

  const pendingSettlements: SubagentCompletionDetails[] = [];
  let flushScheduled = false;
  let flushTimer: ReturnType<typeof setTimeout> | undefined;
  const flushPendingSettlements = (): void => {
    if (flushTimer !== undefined) {
      clearTimeout(flushTimer);
      flushTimer = undefined;
    }
    flushScheduled = false;
    if (pendingSettlements.length === 0) return;
    const entries = pendingSettlements.splice(0).filter((entry) => {
      const owner = runtimes.get(entry.jobId);
      return !owner || (owner.state !== "closing" && owner.state !== "closed");
    });
    if (entries.length === 0) return;
    const delivered = deps.notifySettled(entries.length === 1 ? entries[0] : { batch: entries });
    for (const entry of entries) {
      if (!delivered) deps.live.reportFailed(entry.operationId);
    }
  };
  /** Coalesce settlements that land in the same event-loop turn into one card. */
  const scheduleFlush = (): void => {
    if (flushScheduled) return;
    flushScheduled = true;
    flushTimer = setTimeout(() => {
      flushTimer = undefined;
      flushScheduled = false;
      flushPendingSettlements();
    }, 0);
  };

  const notifyOperationSettled = (runtime: RuntimeRecord, operation: OperationRecord): void => {
    if (operation.notified && operation.audited) return;
    const result = operation.result;
    const agent = runtime.agent.name.length <= 80
      ? runtime.agent.name
      : `${runtime.agent.name.slice(0, 79)}…`;
    const model = runtime.agent.model ? stripModel(runtime.agent.model) : undefined;
    const thinking = runtime.agent.thinking;
    const elapsedMs = operation.startedAt !== undefined && operation.finishedAt !== undefined
      ? operation.finishedAt - operation.startedAt
      : undefined;
    const handoff = result ? modelSubagentHandoff(result) : undefined;
    const details: SubagentCompletionDetails = {
      jobId: runtime.runId,
      operationId: operation.operationId,
      turn: operation.turn,
      ref: `#${runtime.index}`,
      agent,
      ...(model ? { model } : {}),
      ...(thinking ? { thinking } : {}),
      ...(elapsedMs === undefined ? {} : { elapsedMs }),
      task: boundText(operation.task, { maxCharacters: 240, maxLines: 4 }, [...credentialSecrets]),
      status: result?.status ?? "failed",
      ...(runtime.state === "idle" ? { sessionOpen: true } : {}),
      summary: boundText(handoff?.summary ?? operation.error ?? "Subagent operation failed without a result.",
        { maxCharacters: 2_000, maxLines: 20 }, [...credentialSecrets],
      ),
      ...(handoff?.changes ? { changes: boundText(handoff.changes, { maxCharacters: 2_000, maxLines: 20 }, [...credentialSecrets]) } : {}),
      ...(handoff?.evidence ? { evidence: boundText(handoff.evidence, { maxCharacters: 2_000, maxLines: 20 }, [...credentialSecrets]) } : {}),
      ...(handoff?.validation ? { validation: boundText(handoff.validation, { maxCharacters: 2_000, maxLines: 20 }, [...credentialSecrets]) } : {}),
      ...(handoff?.risks ? { risks: boundText(handoff.risks, { maxCharacters: 2_000, maxLines: 20 }, [...credentialSecrets]) } : {}),
      ...(result?.status !== "completed" && operation.latestProgress?.recentActivity.length
        ? { recentActivity: operation.latestProgress.recentActivity }
        : {}),
    };
    // Audit is best-effort and at-most-once; shutdown suppresses only the wake.
    if (!operation.audited) {
      operation.audited = true;
      try {
        deps.logSettled?.(details);
      } catch {
        // The settle log never affects operation state.
      }
    }
    if (!operation.notifyOnSettle || operation.notified) return;
    operation.notified = true;
    if (shuttingDown || runtime.state === "closing" || runtime.state === "closed") return;
    // Batched wake policy: successful background settlements coalesce within
    // the same event-loop turn and flush as ONE aggregated card on the next
    // macrotask (the widget is the ambient signal meanwhile). Failures,
    // timeouts, and interruptions are actionable and notify immediately,
    // carrying any earlier pending entries along so nothing notifies twice.
    pendingSettlements.push(details);
    if (details.status !== "completed") {
      flushPendingSettlements();
      return;
    }
    scheduleFlush();
  };

  const closeRuntime = (runtime: RuntimeRecord, suppressNotification = false): Promise<void> => {
    if (suppressNotification && runtime.activeOperationId) {
      const operation = runtime.operations.get(runtime.activeOperationId);
      if (operation) operation.notifyOnSettle = false;
    }
    // Suppress queued wakes owned by this session so a closed session never emits triggerTurn.
    for (let index = pendingSettlements.length - 1; index >= 0; index -= 1) {
      if (pendingSettlements[index].jobId === runtime.runId) pendingSettlements.splice(index, 1);
    }
    if (runtime.closePromise) return runtime.closePromise;
    deps.live.removeSession(runtime.runId);
    const wasCrashed = runtime.state === "crashed";
    if (!wasCrashed) transition(runtime, "closing");
    runtime.closePromise = (async () => {
      let failure: unknown;
      let interruptTimer: ReturnType<typeof setTimeout> | undefined;
      try {
        await Promise.race([
          (async () => {
            try {
              await runtime.controllerReady;
            } catch (error) {
              failure = error;
              return;
            }
            const activeOperationId = runtime.activeOperationId;
            const activeOperation = activeOperationId === undefined
              ? undefined
              : runtime.operations.get(activeOperationId);
            if (activeOperationId && activeOperation?.accepted && runtime.controller && !wasCrashed) {
              try {
                await runtime.controller!.interrupt(activeOperationId);
                await activeOperation.settled;
              } catch (error) {
                failure ??= error;
              }
            }
            try {
              await runtime.controller?.close();
            } catch (error) {
              failure ??= error;
            }
          })(),
          new Promise<void>((_resolve, reject) => {
            interruptTimer = setTimeout(() => reject(new Error("Subagent close timed out after 5s")), 5_000);
          }),
        ]);
      } catch (error) {
        failure ??= error;
        // Best-effort background close so the owned controller never leaks past the deadline.
        void runtime.controllerReady.then((controller) => controller.close().catch(() => {})).catch(() => {});
      } finally {
        if (interruptTimer) clearTimeout(interruptTimer);
      }
      if (failure) throw failure;
      if (runtime.state !== "crashed") transition(runtime, "closed");
    })().catch((error) => {
      if (runtime.state !== "crashed") transition(runtime, "crashed");
      throw error;
    }).finally(() => {
      // A timed-out close does not prove that an active turn stopped. Keep its
      // slot quarantined until authoritative settlement releases it, otherwise
      // a hung controller could make actual concurrency exceed the configured cap.
      const activeOperation = runtime.activeOperationId
        ? runtime.operations.get(runtime.activeOperationId)
        : undefined;
      if (!activeOperation || activeOperation.state !== "running") releaseSlot(runtime);
      prune();
    });
    return runtime.closePromise;
  };

  const beginOperation = async (
    runtime: RuntimeRecord,
    input: BeginOperationInput,
  ): Promise<OperationRecord> => {
    const { operationId, task, notifyOnSettle, workOrder, signal, onUpdate } = input;
    let settle!: () => void;
    const operation: OperationRecord = {
      operationId,
      turn: runtime.nextTurnNumber++,
      state: "running",
      accepted: false,
      task,
      workOrder,
      notifyOnSettle,
      settled: new Promise<void>((resolve) => { settle = resolve; }),
      settle: () => settle(),
    };
    runtime.operations.set(operationId, operation);
    operation.state = "running";
    operation.startedAt = Date.now();
    runtime.activeOperationId = operationId;
    transition(runtime, "running");
    // Wrap progress with operation identity and renderer-only tool lifecycle data.
    // The live UI controller always observes progress, including the concurrent
    // active-tool count from tools.active; onUpdate is forwarded only when the
    // tool caller provided a channel.
    const onProgress = (value: string | SubagentProgress) => {
      const normalized = normalizeProgress(value);
      operation.latestProgress = {
        summary: normalized.summary,
        recentActivity: normalized.recentActivity,
        ...(normalized.timeline ? { timeline: normalized.timeline } : {}),
        ...(normalized.phase ? { phase: normalized.phase } : {}),
        ...(normalized.tools ? { tools: normalized.tools } : {}),
        ...(normalized.needsDecision && normalized.decision ? {
          needsDecision: true as const,
          decision: normalized.decision,
        } : {}),
      };
      deps.live.progress(operationId, normalized.summary, normalized.phase, normalized.activeCount, normalized.question);
      onUpdate?.({
        content: [{ type: "text", text: normalized.summary }],
        details: {
          ref: `#${runtime.index}`,
          turn: operation.turn,
          agent: runtime.agent.name,
          ...(runtime.agent.model ? { model: runtime.agent.model } : {}),
          ...(runtime.agent.thinking ? { thinking: runtime.agent.thinking } : {}),
          status: "running",
          startedAt: operation.startedAt,
          activity: normalized.summary,
          ...(normalized.phase ? { phase: normalized.phase } : {}),
          ...(normalized.tools ? { toolProgress: normalized.tools } : {}),
          ...(normalized.timeline ? { timeline: normalized.timeline } : {}),
          ...(normalized.needsDecision && normalized.decision
            ? { needsDecision: true as const, decision: normalized.decision }
            : {}),
        },
      });
    };
    const runOptions: SubagentRunOptions = {
      cwd: runtime.cwd,
      agent: runtime.agent,
      workOrder,
      runId: runtime.runId,
      operationId,
      parentSessionId: runtime.parentSessionId,
      signal,
      onProgress,
    };
    const started = runtime.controller!.start(runOptions);
    started.result.then(
      (result) => {
        operation.result = result;
        operation.state = result.status;
        deps.live.settle(operationId, result.status ?? "completed", Date.now() - (operation.startedAt ?? Date.now()));
      },
      (error) => {
        operation.error = error instanceof Error ? error.message : String(error);
        operation.state = "failed";
        deps.live.settle(operationId, "failed", Date.now() - (operation.startedAt ?? Date.now()));
        if (runtime.state !== "closing" && runtime.state !== "closed") {
          transition(runtime, "crashed");
          void closeRuntime(runtime).catch(() => {});
        }
      },
    ).finally(() => {
      operation.finishedAt = Date.now();
      if (runtime.activeOperationId === operationId) {
        runtime.activeOperationId = undefined;
        runtime.lastSettled = operation;
        if (runtime.state === "running") transition(runtime, "idle");
      }
      operation.settle();
      releaseSlot(runtime);
      prune();
      void started.accepted.then(() => {
        notifyOperationSettled(runtime, operation);
      }).catch(() => {});
    });
    await started.accepted;
    operation.accepted = true;
    return operation;
  };

  return {
    maxConcurrentRuns,
    get: (runtimeId) => runtimes.get(runtimeId),
    resolve: (reference) => {
      const exact = runtimes.get(reference);
      if (exact) return exact;
      const match = /^(?:#)?([1-9]\d*)$/.exec(reference);
      if (!match) return undefined;
      const index = Number(match[1]);
      return Number.isSafeInteger(index)
        ? [...runtimes.values()].find((runtime) => runtime.index === index)
        : undefined;
    },
    capacityAvailable: () => occupiedSlots < maxConcurrentRuns,
    occupiedSlots: () => occupiedSlots,
    availableSlots: () => Math.max(0, maxConcurrentRuns - occupiedSlots),
    isShuttingDown: () => shuttingDown,
    reserveSlot: (runtime) => {
      if (shuttingDown || runtime.slotReserved || runtime.state !== "idle" || occupiedSlots >= maxConcurrentRuns) return false;
      runtime.slotReserved = true;
      occupiedSlots += 1;
      return true;
    },
    createRuntime(input) {
      const controllerReady = deferred<SubagentController>();
      const runtime: RuntimeRecord = {
        index: nextRuntimeIndex++,
        runId: input.initialOptions.runId,
        revision: 0,
        nextTurnNumber: 1,
        agent: input.agent,
        cwd: input.cwd,
        parentSessionId: input.parentSessionId,
        projectGuidance: input.projectGuidance,
        state: "starting",
        controllerReady: controllerReady.promise,
        operations: new Map(),
        slotReserved: true,
      };
      occupiedSlots += 1;
      runtimes.set(runtime.runId, runtime);
      let creationTimer: ReturnType<typeof setTimeout> | undefined;
      let creationExpired = false;
      const factoryPromise = Promise.resolve().then(() => deps.controllerFactory(input.initialOptions));
      const timedFactory = Promise.race([
        factoryPromise,
        new Promise<never>((_resolve, reject) => {
          creationTimer = setTimeout(() => {
            creationExpired = true;
            reject(new Error("Subagent controller creation timed out"));
          }, controllerCreationTimeoutMs);
        }),
      ]).finally(() => { if (creationTimer) clearTimeout(creationTimer); });
      void factoryPromise.then((controller) => {
        if (creationExpired) {
          void controller.close().catch(() => {});
        }
      }, () => {});
      void timedFactory.then(
        (controller) => {
          if (creationExpired) {
            void controller.close().catch(() => {});
            controllerReady.reject(new Error("Subagent controller creation timed out"));
            return;
          }
          runtime.controller = controller;
          void controller.failure.then((error) => {
            // The close path owns the outcome once closing starts; a late
            // failure must not flip a successfully closed session to crashed.
            if (runtime.state === "closed" || runtime.state === "crashed" || runtime.state === "closing" || runtime.closePromise) return;
            transition(runtime, "crashed");
            void closeRuntime(runtime).catch(() => {});
          });
          controllerReady.resolve(controller);
        },
        (error) => controllerReady.reject(error),
      );
      return runtime;
    },
    beginOperation,
    markCrashed: (runtime) => {
      if (!runtime.closePromise) transition(runtime, "crashed");
    },
    closeRuntime,
    listRuntimes: () => [...runtimes.values()],
    async requestShutdown() {
      shuttingDown = true;
      if (flushTimer !== undefined) clearTimeout(flushTimer);
      flushTimer = undefined;
      flushScheduled = false;
      pendingSettlements.length = 0;
      for (const runtime of runtimes.values()) deps.live.removeSession(runtime.runId);
      await Promise.allSettled([...runtimes.values()].map((runtime) => closeRuntime(runtime, true)));
    },
  };
}
