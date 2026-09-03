import type { LiveUiController } from "./live-ui.ts";
import { boundText, modelSubagentHandoff } from "./output.ts";
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
    const entries = pendingSettlements.splice(0);
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
    if (
      !operation.notifyOnSettle
      || shuttingDown
      || runtime.state === "closing"
      || runtime.state === "closed"
    ) return;
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
      task: boundText(operation.task, { maxCharacters: 240, maxLines: 4 }),
      status: result?.status ?? "failed",
      ...(runtime.state === "idle" ? { sessionOpen: true } : {}),
      summary: boundText(handoff?.summary ?? operation.error ?? "Subagent operation failed without a result.",
        { maxCharacters: 2_000, maxLines: 20 },
      ),
      ...(handoff?.changes ? { changes: boundText(handoff.changes, { maxCharacters: 2_000, maxLines: 20 }) } : {}),
      ...(handoff?.evidence ? { evidence: boundText(handoff.evidence, { maxCharacters: 2_000, maxLines: 20 }) } : {}),
      ...(handoff?.validation ? { validation: boundText(handoff.validation, { maxCharacters: 2_000, maxLines: 20 }) } : {}),
      ...(handoff?.risks ? { risks: boundText(handoff.risks, { maxCharacters: 2_000, maxLines: 20 }) } : {}),
      ...(result?.status !== "completed" && operation.latestProgress?.recentActivity.length
        ? { recentActivity: operation.latestProgress.recentActivity }
        : {}),
    };
    // Batched wake policy: successful background settlements coalesce within
    // the same event-loop turn and flush as ONE aggregated card on the next
    // macrotask (the widget is the ambient signal meanwhile). Failures,
    // timeouts, and interruptions are actionable and notify immediately,
    // carrying any earlier pending entries along so nothing notifies twice.
    deps.logSettled?.(details);
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
    if (runtime.closePromise) return runtime.closePromise;
    deps.live.removeSession(runtime.runId);
    const wasCrashed = runtime.state === "crashed";
    if (!wasCrashed) transition(runtime, "closing");
    runtime.closePromise = (async () => {
      let failure: unknown;
      try {
        await runtime.controllerReady;
      } catch (error) {
        failure = error;
      }
      const activeOperationId = runtime.activeOperationId;
      const activeOperation = activeOperationId === undefined
        ? undefined
        : runtime.operations.get(activeOperationId);
      if (activeOperationId && activeOperation?.accepted && runtime.controller && !wasCrashed) {
        try {
          let timer: ReturnType<typeof setTimeout> | undefined;
          const stopped = await Promise.race([
            (async () => {
              await runtime.controller!.interrupt(activeOperationId);
              await activeOperation.settled;
              return true;
            })(),
            new Promise<false>((resolveTimeout) => {
              timer = setTimeout(() => resolveTimeout(false), 5_000);
            }),
          ]);
          if (timer) clearTimeout(timer);
          if (!stopped) failure ??= new Error("Subagent operation did not settle after interrupt");
        } catch (error) {
          failure ??= error;
        }
      }
      try {
        await runtime.controller?.close();
      } catch (error) {
        failure ??= error;
      }
      if (failure) throw failure;
      if (runtime.state !== "crashed") transition(runtime, "closed");
    })().catch((error) => {
      transition(runtime, "crashed");
      throw error;
    }).finally(() => {
      releaseSlot(runtime);
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
      const progress = typeof value === "string" ? { summary: value } : value;
      const summary = progress.summary;
      // Forward a bounded decision only when the child explicitly signals
      // needsDecision with a non-empty question; empty/invalid payloads never
      // pollute public update details.
      const question = progress.needsDecision === true && progress.decision
        && typeof progress.decision.question === "string"
        ? progress.decision.question.trim()
        : "";
      // Bounded, non-empty option list; all-invalid input yields no options key.
      const decisionOptions = Array.isArray(progress.decision?.options)
        ? progress.decision.options
            .filter((option) => typeof option === "string" && option.trim() !== "")
            .map((option) => boundText(option, { maxCharacters: 200, maxLines: 1 }))
            .slice(0, 8)
        : [];
      const recentActivity = (progress.timeline ?? [])
        .slice(-8)
        .flatMap((entry) => entry.kind === "thinking"
          ? ["✓ Thinking"]
          : [`${entry.status === "failed" ? "✗" : "✓"} ${boundText(entry.summary, { maxCharacters: 160, maxLines: 1 })}`]);
      operation.latestProgress = {
        summary: boundText(summary, { maxCharacters: 240, maxLines: 1 }),
        recentActivity,
        ...(progress.timeline ? { timeline: progress.timeline.map((entry) => ({ ...entry })) } : {}),
        ...(progress.phase ? { phase: { ...progress.phase } } : {}),
        ...(progress.tools ? {
          tools: {
            earlierCount: progress.tools.earlierCount,
            history: progress.tools.history.map((entry) => ({ ...entry })),
            active: progress.tools.active.map((entry) => ({ ...entry })),
          },
        } : {}),
        ...(question ? {
          needsDecision: true,
          decision: {
            question: boundText(question, { maxCharacters: 240, maxLines: 1 }),
            ...(decisionOptions.length > 0 ? { options: decisionOptions } : {}),
          },
        } : {}),
      };
      deps.live.progress(operationId, summary, progress.phase, progress.tools?.active.length, question || undefined);
      onUpdate?.({
        content: [{ type: "text", text: summary }],
        details: {
          ref: `#${runtime.index}`,
          turn: operation.turn,
          agent: runtime.agent.name,
          ...(runtime.agent.model ? { model: runtime.agent.model } : {}),
          ...(runtime.agent.thinking ? { thinking: runtime.agent.thinking } : {}),
          status: "running",
          startedAt: operation.startedAt,
          activity: boundText(summary, { maxCharacters: 240, maxLines: 1 }),
          ...(progress.phase ? { phase: progress.phase } : {}),
          ...(progress.tools ? { toolProgress: progress.tools } : {}),
          ...(progress.timeline ? { timeline: progress.timeline } : {}),
          ...(question && progress.decision
            ? {
                needsDecision: true,
                decision: {
                  question: boundText(question, { maxCharacters: 240, maxLines: 1 }),
                  ...(decisionOptions.length > 0 ? { options: decisionOptions } : {}),
                },
              }
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
            if (runtime.state === "closed") return;
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
