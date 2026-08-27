import type { LiveUiController } from "./live-ui.ts";
import { boundText } from "./output.ts";
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

export type RuntimeState = "starting" | "running" | "idle" | "closing" | "closed" | "crashed";
export type OperationState = "running" | "completed" | "failed" | "interrupted" | "cancelled";

export interface OperationRecord {
  operationId: string;
  state: OperationState;
  accepted: boolean;
  task: string;
  deadlineMs: number;
  startedAt?: number;
  finishedAt?: number;
  result?: SubagentResult;
  error?: string;
  notifyOnSettle: boolean;
  settled: Promise<void>;
  settle(): void;
}

export type RuntimeMode = "foreground" | "background-one-shot";

export interface RuntimeRecord {
  /** Session-local short index (#N) for human/model-friendly targeting. */
  index: number;
  runId: string;
  revision: number;
  agent: SubagentRunOptions["agent"];
  cwd: string;
  parentSessionId: string;
  projectGuidance: string[];
  state: RuntimeState;
  /** Foreground or asynchronously observed one-shot execution. */
  mode: RuntimeMode;
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

export const operationSnapshot = (operation: OperationRecord) => ({
  operationId: operation.operationId,
  status: operation.state,
  task: boundText(operation.task, { maxCharacters: 240, maxLines: 4 }),
  ...(operation.startedAt === undefined ? {} : { startedAt: operation.startedAt }),
  ...(operation.finishedAt === undefined ? {} : { finishedAt: operation.finishedAt }),
  ...(operation.result === undefined ? {} : {
    result: {
      ...operation.result,
      summary: boundText(operation.result.summary, { maxCharacters: 2_000, maxLines: 20 }),
    },
  }),
  ...(operation.error === undefined ? {} : {
    error: boundText(operation.error, { maxCharacters: 2_000, maxLines: 20 }),
  }),
});

export function runtimeSnapshot(runtime: RuntimeRecord) {
  return {
    runId: runtime.runId,
    revision: runtime.revision,
    mode: runtime.mode,
    index: runtime.index,
    agent: runtime.agent.name,
    ...(runtime.agent.model ? { model: stripModel(runtime.agent.model) } : {}),
    ...(runtime.agent.thinking ? { thinking: runtime.agent.thinking } : {}),
    status: runtime.state,
    ...(runtime.activeOperationId === undefined ? {} : {
      operationId: runtime.activeOperationId,
      activeOperationId: runtime.activeOperationId,
      activeOperation: operationSnapshot(runtime.operations.get(runtime.activeOperationId)!),
    }),
    ...(runtime.lastSettled === undefined ? {} : {
      lastSettledOperation: operationSnapshot(runtime.lastSettled),
    }),
    ...(runtime.controller === undefined ? {} : {
      processInstanceId: runtime.controller.processInstanceId,
      transcript: runtime.controller.transcript,
    }),
  };
}

export interface RuntimeHubDeps {
  controllerFactory: SubagentControllerFactory;
  idFactory: () => string;
  /** Maximum concurrent one-shot jobs. */
  maxConcurrentRuns?: number;
  /** Completion sink; the hub builds bounded details, the shell delivers them. */
  notifySettled: (details: SubagentCompletionDetails | { batch: SubagentCompletionDetails[] }) => void;
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
  mode: RuntimeMode;
  initialOptions: SubagentRunOptions;
}

export interface BeginOperationInput {
  operationId: string;
  task: string;
  deadlineMs: number;
  notifyOnSettle: boolean;
  workOrder: SubagentRunOptions["workOrder"];
  signal?: AbortSignal;
  onUpdate?: (update: { content: Array<{ type: "text"; text: string }>; details: Record<string, unknown> }) => void;
}

export interface RuntimeHub {
  readonly maxConcurrentRuns: number;
  get(runtimeId: string): RuntimeRecord | undefined;
  /** Resolve a canonical jobId first, then a session-local #N/N alias. */
  resolve(reference: string): RuntimeRecord | undefined;
  capacityAvailable(): boolean;
  occupiedSlots(): number;
  availableSlots(): number;
  isShuttingDown(): boolean;
  createRuntime(input: CreateRuntimeInput): RuntimeRecord;
  snapshot(runtime: RuntimeRecord): ReturnType<typeof runtimeSnapshot>;
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
    deps.notifySettled(entries.length === 1 ? entries[0] : { batch: entries });
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
    const details: SubagentCompletionDetails = {
      jobId: runtime.runId,
      ref: `#${runtime.index}`,
      agent,
      ...(model ? { model } : {}),
      ...(thinking ? { thinking } : {}),
      ...(elapsedMs === undefined ? {} : { elapsedMs }),
      task: boundText(operation.task, { maxCharacters: 240, maxLines: 4 }),
      status: result?.status ?? "failed",
      summary: boundText(
        result?.summary ?? operation.error ?? "Subagent operation failed without a result.",
        { maxCharacters: 2_000, maxLines: 20 },
      ),
      runtimeStatus: runtime.state === "running" ? "running" : runtime.state === "idle" ? "idle" : "crashed",
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
    deps.live.remove(runtime.runId);
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
    const { operationId, task, deadlineMs, notifyOnSettle, workOrder, signal, onUpdate } = input;
    let settle!: () => void;
    const operation: OperationRecord = {
      operationId,
      state: "running",
      accepted: false,
      task,
      deadlineMs,
      notifyOnSettle,
      settled: new Promise<void>((resolve) => { settle = resolve; }),
      settle: () => settle(),
    };
    runtime.operations.set(operationId, operation);
    operation.state = "running";
    operation.startedAt = Date.now();
    runtime.activeOperationId = operationId;
    transition(runtime, "running");
    deps.live.track(runtime.runId, {
      index: runtime.index,
      agent: runtime.agent.name,
      startedAt: operation.startedAt,
      deadlineMs,
      mode: runtime.mode === "foreground" ? "foreground" : "background",
    });
    // Wrap progress with operation identity and renderer-only tool lifecycle data.
    // The live UI controller always observes progress; onUpdate is forwarded only
    // when the tool caller provided a channel.
    const onProgress = (value: string | SubagentProgress) => {
      const progress = typeof value === "string" ? { summary: value } : value;
      const summary = progress.summary;
      deps.live.progress(runtime.runId, summary);
      onUpdate?.({
        content: [{ type: "text", text: summary }],
        details: {
          jobId: runtime.runId,
          ref: `#${runtime.index}`,
          agent: runtime.agent.name,
          ...(runtime.agent.model ? { model: stripModel(runtime.agent.model) } : {}),
          ...(runtime.agent.thinking ? { thinking: runtime.agent.thinking } : {}),
          status: "running",
          ...(progress.tools ? { toolProgress: progress.tools } : {}),
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
      deadlineMs,
      signal,
      onProgress,
    };
    const started = runtime.controller!.start(runOptions);
    started.result.then(
      (result) => {
        operation.result = result;
        operation.state = result.status;
        deps.live.settle(runtime.runId, result.status ?? "completed", Date.now() - (operation.startedAt ?? Date.now()));
      },
      (error) => {
        operation.error = error instanceof Error ? error.message : String(error);
        operation.state = "failed";
        deps.live.settle(runtime.runId, "failed", Date.now() - (operation.startedAt ?? Date.now()));
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
      prune();
      void started.accepted.then(() => {
        notifyOperationSettled(runtime, operation);
        if (runtime.mode === "background-one-shot") void closeRuntime(runtime).catch(() => {});
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
    createRuntime(input) {
      const controllerReady = deferred<SubagentController>();
      const runtime: RuntimeRecord = {
        index: nextRuntimeIndex++,
        runId: input.initialOptions.runId,
        revision: 0,
        agent: input.agent,
        cwd: input.cwd,
        parentSessionId: input.parentSessionId,
        projectGuidance: input.projectGuidance,
        mode: input.mode,
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
    snapshot: (runtime) => runtimeSnapshot(runtime),
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
      await Promise.allSettled([...runtimes.values()].map((runtime) => closeRuntime(runtime, true)));
    },
  };
}
