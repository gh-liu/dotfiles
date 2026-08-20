import { randomUUID } from "node:crypto";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { getAgentDir, SettingsManager, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

import { applyAgentOverrides, discoverUserAgents, type AgentDiscovery } from "./agents.ts";
import { findAllowedRoot, loadProjectGuidance, resolveChildCwd } from "./context.ts";
import { boundText } from "./output.ts";
import { assertSupportedPiVersion, createRpcSubagentController } from "./rpc-executor.ts";
import {
  renderSubagentCall,
  renderSubagentCompletion,
  renderSubagentResult,
  SUBAGENT_COMPLETION_MESSAGE,
  type SubagentCompletionDetails,
} from "./render.ts";
import type {
  SubagentController,
  SubagentControllerFactory,
  SubagentResult,
  SubagentRunOptions,
  SubagentWorkOrder,
} from "./protocol.ts";

interface SubagentExtensionOptions {
  agentDirectory?: string;
  authEnvAllowlist?: string[];
  controllerFactory?: SubagentControllerFactory;
  idFactory?: () => string;
}

type RuntimeState = "starting" | "running" | "idle" | "closing" | "closed" | "crashed";
type OperationState = "queued" | "running" | "completed" | "failed" | "interrupted" | "cancelled";

interface OperationRecord {
  operationId: string;
  state: OperationState;
  accepted: boolean;
  task: string;
  deadlineMs: number;
  queuedAt?: number;
  startedAt?: number;
  finishedAt?: number;
  result?: SubagentResult;
  error?: string;
  notifyOnSettle: boolean;
  settled: Promise<void>;
  settle(): void;
}

interface RuntimeRecord {
  runId: string;
  revision: number;
  agent: SubagentRunOptions["agent"];
  cwd: string;
  parentSessionId: string;
  projectGuidance: string[];
  state: RuntimeState;
  controller?: SubagentController;
  controllerReady: Promise<SubagentController>;
  activeOperationId?: string;
  queuedOperationId?: string;
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

const deadline = () => Type.Optional(Type.Integer({
  minimum: 1_000,
  maximum: 3_600_000,
  description: "Required by run/start: execution deadline chosen from the task's estimated duration (1,000-3,600,000 ms)",
}));

// Provider tool APIs require a root object schema; a root Type.Union serializes
// as anyOf and is rejected by DeepSeek before the model can call the tool.
const SubagentParameters = Type.Object({
  action: Type.Union([
    Type.Literal("list"),
    Type.Literal("run"),
    Type.Literal("start"),
    Type.Literal("status"),
    Type.Literal("send"),
    Type.Literal("wait"),
    Type.Literal("interrupt"),
    Type.Literal("close"),
  ], { description: "Subagent lifecycle action" }),
  agent: Type.Optional(Type.String({ description: "Required by run/start: canonical user agent name" })),
  task: Type.Optional(Type.String({ minLength: 1, description: "Required by run/start: self-contained delegated task" })),
  cwd: Type.Optional(Type.String({
    description: "Optional run/start relative child directory under the project root; omit to use the parent cwd",
  })),
  id: Type.Optional(Type.String({ minLength: 1, description: "Required by runtime lifecycle actions: runtime ID" })),
  mode: Type.Optional(Type.Union([
    Type.Literal("follow_up"),
    Type.Literal("steer"),
  ], { description: "Required by send" })),
  message: Type.Optional(Type.String({ minLength: 1, description: "Required by send" })),
  operationId: Type.Optional(Type.String({ minLength: 1, description: "Required by wait" })),
  expectedOperationId: Type.Optional(Type.String({
    minLength: 1,
    description: "Required by interrupt and steer; guards against targeting a later operation",
  })),
  deadlineMs: deadline(),
  timeoutMs: Type.Optional(Type.Integer({ minimum: 1, maximum: 3_600_000, description: "Optional wait timeout" })),
});

function getEffectiveSettings(ctx: { cwd: string; isProjectTrusted(): boolean }): unknown {
  try {
    const manager: unknown = (SettingsManager as unknown as { create: (cwd: string, agentDir: string, opts: unknown) => unknown }).create(
      ctx.cwd,
      getAgentDir(),
      { projectTrusted: ctx.isProjectTrusted() },
    );
    const m = manager as {
      settings?: unknown;
      getGlobalSettings?: () => unknown;
      getProjectSettings?: () => unknown;
    };
    if (m.settings !== undefined) return m.settings;
    const global = m.getGlobalSettings?.() ?? {};
    const project = m.getProjectSettings?.() ?? {};
    // Deep merge fallback: shallow merge objects with nested merge for subagents
    if (
      global &&
      typeof global === "object" &&
      project &&
      typeof project === "object"
    ) {
      const g = global as Record<string, unknown>;
      const p = project as Record<string, unknown>;
      const merged: Record<string, unknown> = { ...g };
      for (const [k, v] of Object.entries(p)) {
        if (
          v !== undefined &&
          typeof v === "object" &&
          !Array.isArray(v) &&
          typeof g[k] === "object" &&
          g[k] !== null &&
          !Array.isArray(g[k])
        ) {
          merged[k] = { ...(g[k] as Record<string, unknown>), ...(v as Record<string, unknown>) };
        } else if (v !== undefined) merged[k] = v;
      }
      return merged;
    }
    return {};
  } catch {
    return {};
  }
}

function getEffectiveDiscovery(
  base: AgentDiscovery,
  ctx: { cwd: string; isProjectTrusted(): boolean },
): AgentDiscovery {
  try {
    const settings = getEffectiveSettings(ctx);
    return applyAgentOverrides(base, settings);
  } catch (error) {
    console.warn(`[subagent] failed to apply settings overrides: ${error}`);
    return base;
  }
}

function formatAgentCatalog(discovery: AgentDiscovery): string {
  const agents = discovery.agents.length === 0
    ? ["none"]
    : discovery.agents.map((agent) => `${agent.name}: ${agent.description.replace(/\s+/g, " ").trim()}`);
  const invalid = discovery.errors.length === 0
    ? []
    : ["", "Invalid agent definitions:", ...discovery.errors.map((error) => `- ${error.error}`)];
  return [...agents, ...invalid].join("\n");
}

function createWorkOrder(task: string, cwd: string, projectGuidance: string[]): SubagentWorkOrder {
  return {
    goal: task,
    scope: [cwd],
    constraints: [
      "Use only the tools declared by the selected agent.",
      "Preserve unrelated existing changes and do not perform destructive shared actions.",
      "Do not delegate to another agent.",
    ],
    knownDecisions: [],
    evidence: [],
    validation: [],
    returnFormat:
      "Return a concise result with completed work or findings, evidence, validation, blockers, and residual risks.",
    projectGuidance,
  };
}

function stripModel(model: string): string {
  const slash = model.lastIndexOf("/");
  return slash === -1 ? model : model.slice(slash + 1);
}

function serializeSubagentResult(result: SubagentResult): string {
  const maxCharacters = 32_000;
  let low = 0;
  let high = Math.min(result.summary.length, maxCharacters);
  let best: string | undefined;
  while (low <= high) {
    const summaryLimit = Math.floor((low + high) / 2);
    const summary = summaryLimit === 0
      ? ""
      : boundText(result.summary, { maxCharacters: summaryLimit, maxLines: 400 });
    const serialized = JSON.stringify({ ...result, summary });
    if (serialized.length <= maxCharacters) {
      best = serialized;
      low = summaryLimit + 1;
    } else {
      high = summaryLimit - 1;
    }
  }
  if (best !== undefined) return best;
  throw new Error("Subagent result envelope exceeds the parent serialization limit");
}

export function registerSubagentExtension(pi: ExtensionAPI, options: SubagentExtensionOptions = {}): void {
  assertSupportedPiVersion();
  const agentDirectory = options.agentDirectory ?? join(getAgentDir(), "agents");
  let registry = discoverUserAgents(agentDirectory);
  const startupCatalog = boundText(formatAgentCatalog(registry), { maxCharacters: 16_000, maxLines: 200 });
  const authEnvAllowlist = options.authEnvAllowlist
    ?? process.env.PI_SUBAGENT_AUTH_ENV_ALLOWLIST?.split(",").map((name) => name.trim()).filter(Boolean);
  const rpcConfig = {
    piAgentDirectory: getAgentDir(),
    sessionRoot: join(getAgentDir(), "subagent-sessions"),
    authEnvAllowlist,
    toolProviders: {
      web_search: {
        extensionPaths: [fileURLToPath(new URL("../websearch/index.ts", import.meta.url))],
        environmentVariables: ["EXA_API_KEY"],
      },
    },
  };
  const controllerFactory = options.controllerFactory
    ?? ((initial: SubagentRunOptions) => createRpcSubagentController(initial, rpcConfig));
  const idFactory = options.idFactory ?? randomUUID;
  const runtimes = new Map<string, RuntimeRecord>();
  let occupiedSlots = 0;
  let shuttingDown = false;

  const transition = (runtime: RuntimeRecord, state: RuntimeState): void => {
    if (runtime.state === state) return;
    runtime.state = state;
    runtime.revision += 1;
  };

  const releaseSlot = (runtime: RuntimeRecord): void => {
    if (!runtime.slotReserved) return;
    runtime.slotReserved = false;
    occupiedSlots -= 1;
  };

  const operationSnapshot = (operation: OperationRecord) => ({
    operationId: operation.operationId,
    status: operation.state,
    task: boundText(operation.task, { maxCharacters: 240, maxLines: 4 }),
    ...(operation.queuedAt === undefined ? {} : { queuedAt: operation.queuedAt }),
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

  const runtimeSnapshot = (runtime: RuntimeRecord) => ({
    runId: runtime.runId,
    revision: runtime.revision,
    agent: runtime.agent.name,
    ...(runtime.agent.model ? { model: stripModel(runtime.agent.model) } : {}),
    ...(runtime.agent.thinking ? { thinking: runtime.agent.thinking } : {}),
    status: runtime.state,
    ...(runtime.activeOperationId === undefined ? {} : {
      operationId: runtime.activeOperationId,
      activeOperationId: runtime.activeOperationId,
      activeOperation: operationSnapshot(runtime.operations.get(runtime.activeOperationId)!),
    }),
    ...(runtime.queuedOperationId === undefined ? {} : {
      queuedOperation: operationSnapshot(runtime.operations.get(runtime.queuedOperationId)!),
    }),
    ...(runtime.lastSettled === undefined ? {} : {
      lastSettledOperation: operationSnapshot(runtime.lastSettled),
    }),
    ...(runtime.controller === undefined ? {} : {
      processInstanceId: runtime.controller.processInstanceId,
      transcript: runtime.controller.transcript,
    }),
  });

  const response = (details: unknown, isError = false) => {
    const serialized = JSON.stringify(details);
    const bounded = serialized.length <= 32_000
      ? serialized
      : JSON.stringify({ error: "Subagent response exceeded the parent serialization limit", truncated: true });
    return {
      content: [{ type: "text" as const, text: bounded }],
      details,
      ...(isError ? { isError: true } : {}),
    };
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
    const details: SubagentCompletionDetails = {
      runId: runtime.runId,
      operationId: operation.operationId,
      agent,
      ...(model ? { model } : {}),
      ...(thinking ? { thinking } : {}),
      task: boundText(operation.task, { maxCharacters: 240, maxLines: 4 }),
      status: result?.status ?? "failed",
      summary: boundText(
        result?.summary ?? operation.error ?? "Subagent operation failed without a result.",
        { maxCharacters: 2_000, maxLines: 20 },
      ),
      runtimeStatus: runtime.state === "running" ? "running" : runtime.state === "idle" ? "idle" : "crashed",
    };
    const availability = details.runtimeStatus === "idle"
      ? "The runtime is idle and can accept a follow-up."
      : details.runtimeStatus === "running"
        ? "The runtime is running another operation."
        : "The runtime crashed and cannot accept more work.";
    const content = boundText([
      `Subagent ${details.agent} ${details.status} operation ${details.operationId} in runtime ${details.runId}.`,
      `Task: ${details.task}`,
      `Summary: ${details.summary}`,
      availability,
    ].join("\n"), { maxCharacters: 3_000, maxLines: 24 });
    try {
      pi.sendMessage<SubagentCompletionDetails>({
        customType: SUBAGENT_COMPLETION_MESSAGE,
        content,
        display: true,
        details,
      }, { triggerTurn: true, deliverAs: "followUp" });
    } catch {
      // Notification delivery must not change authoritative operation state.
    }
  };

  const prune = (): void => {
    for (const runtime of runtimes.values()) {
      while (runtime.operations.size > 128) {
        const stale = [...runtime.operations.values()].find(
          (operation) => operation !== runtime.lastSettled
            && operation.state !== "running"
            && operation.state !== "queued",
        );
        if (!stale) break;
        runtime.operations.delete(stale.operationId);
      }
    }
    while (runtimes.size > 128) {
      const stale = [...runtimes.values()].find(
        (runtime) => runtime.state === "closed" || runtime.state === "crashed",
      );
      if (!stale) break;
      runtimes.delete(stale.runId);
    }
  };

  const closeRuntime = (runtime: RuntimeRecord, suppressNotification = false): Promise<void> => {
    if (suppressNotification && runtime.activeOperationId) {
      const operation = runtime.operations.get(runtime.activeOperationId);
      if (operation) operation.notifyOnSettle = false;
    }
    if (runtime.queuedOperationId) {
      const queued = runtime.operations.get(runtime.queuedOperationId);
      runtime.queuedOperationId = undefined;
      if (queued && queued.state === "queued") {
        queued.notifyOnSettle = false;
        queued.state = "cancelled";
        queued.error = "Subagent operation cancelled before submission because the runtime closed";
        queued.finishedAt = Date.now();
        queued.settle();
        runtime.revision += 1;
      }
    }
    if (runtime.closePromise) return runtime.closePromise;
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
    operationId: string,
    task: string,
    deadlineMs: number,
    notifyOnSettle: boolean,
    signal?: AbortSignal,
    onProgress?: (summary: string) => void,
    queuedOperation?: OperationRecord,
  ): Promise<OperationRecord> => {
    let settle!: () => void;
    const operation: OperationRecord = queuedOperation ?? {
      operationId,
      state: "running",
      accepted: false,
      task,
      deadlineMs,
      notifyOnSettle,
      settled: new Promise<void>((resolve) => { settle = resolve; }),
      settle: () => settle(),
    };
    if (!queuedOperation) runtime.operations.set(operationId, operation);
    else runtime.revision += 1;
    operation.state = "running";
    operation.startedAt = Date.now();
    runtime.activeOperationId = operationId;
    transition(runtime, "running");
    const runOptions: SubagentRunOptions = {
      cwd: runtime.cwd,
      agent: runtime.agent,
      workOrder: createWorkOrder(task, runtime.cwd, runtime.projectGuidance),
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
      },
      (error) => {
        operation.error = error instanceof Error ? error.message : String(error);
        operation.state = "failed";
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
        const queuedId = runtime.queuedOperationId;
        const queued = queuedId === undefined ? undefined : runtime.operations.get(queuedId);
        if (runtime.state === "running" && queued?.state === "queued") {
          runtime.queuedOperationId = undefined;
          void beginOperation(
            runtime,
            queued.operationId,
            queued.task,
            queued.deadlineMs,
            true,
            undefined,
            undefined,
            queued,
          ).catch(() => {});
        } else if (runtime.state === "running") transition(runtime, "idle");
      }
      operation.settle();
      prune();
      void started.accepted.then(() => notifyOperationSettled(runtime, operation)).catch(() => {});
    });
    await started.accepted;
    operation.accepted = true;
    return operation;
  };

  const operationResponse = (operation: OperationRecord, runtime?: RuntimeRecord) => {
    if (operation.result) {
      const enriched = runtime
        ? {
            ...operation.result,
            ...(runtime.agent.model ? { model: stripModel(runtime.agent.model) } : {}),
            ...(runtime.agent.thinking ? { thinking: runtime.agent.thinking } : {}),
          }
        : operation.result;
      return {
        content: [{ type: "text" as const, text: serializeSubagentResult(enriched) }],
        details: enriched,
        isError: operation.result.status === "failed",
      };
    }
    return response({ ...operationSnapshot(operation), error: operation.error ?? "Subagent operation failed" }, true);
  };

  pi.registerTool({
    name: "subagent",
    label: "Subagent",
    description:
      `Delegate bounded work to a registered user-defined Pi child with fresh isolated context and only its declared tools. Mandatory routing exceptions to direct parent work: when the user asks for an independent, fresh-eyes, or second-opinion review and a matching agent is registered, invoke it before reading or reviewing the target; parent self-review cannot satisfy independence. Likewise, delegate external research requiring multiple searches, freshness checks, or source assessment before loading a parent research workflow or making parent web searches; use this instead of chaining multiple parent web searches. Other strong uses are multi-file discovery, one specific high-impact decision, and separately owned implementation; default to delegation for implementation-class work (multi-file reads, cross-file impact analysis, batch edits, test runs, refactors) and keep only simple lookups, localized single-file edits, and routine validation direct. After a successful cited read-only handoff, synthesize it without repeating the same searches or reads; verify only decision-critical uncertainty or contradictions. Use one-shot runs by default; persistent runtimes support background completion, context-preserving follow-ups, one queued operation, and guarded steering. The parent owns task decomposition, decisions, conflict avoidance, result review, integration, and final verification.\n\n${startupCatalog}`,
    promptSnippet: "MANDATORY BEFORE any read/bash: explicitly independent/fresh-eyes/second-opinion review->reviewer (parent self-review is NOT independent); multi-source freshness/source assessment->researcher; multi-file discovery->scout; batch edits/test runs->worker; keep only single-file lookups direct; NEVER list, catalog is below",
    promptGuidelines: [
      "NEVER call subagent list — catalog is already in tool description below; use the agent name directly. Mandatory delegation before direct work: independent/fresh-eyes/second-opinion reviews (invoke the review agent before inspecting the target; parent self-review is not independent) and multi-source external research needing freshness or source assessment — NEVER run web_search yourself when researcher is available; invoke researcher first.",
      "Default to delegation for implementation-class work: multi-file reads or cross-file impact analysis, writing code, batch edits, test runs/builds, and regression fixes — especially multi-file discovery → scout, explicit implementation → worker. Do direct only simple lookups (use read, not bash) and localized single-file edits. Use a subagent when the user explicitly requests it or when a matching registered role materially improves quality, parallelism, fresh-context independence, or parent-context isolation.",
      "Before calling subagent, decompose the bounded work instead of forwarding the raw user prompt. Every task must be self-contained (the child has fresh context) and carry these labels: Outcome, Scope, Starting evidence, Known decisions, Constraints and non-goals, Acceptance criteria, Validation, and Handoff — never silently omit one. Do not delegate unresolved decomposition or synthesis that the parent still owns.",
      "Choose a registered agent whose catalog description and declared capabilities match the bounded task; treat the discovered definition as the source of truth. Use action:run for bounded one-shots with a task-appropriate deadlineMs (1,000-3,600,000 ms); use action:start only for background or follow-up work, steer only the guarded active operation, and close persistent runtimes when finished.",
      "Run at most three truly independent subagents in parallel: separate action:run calls in the same turn, never persistent runtimes merely for concurrency. Never let the parent and a write-capable subagent, or multiple write-capable subagents, edit the same files concurrently. Start dependent review or decision work only after prerequisite evidence and writes settle.",
      "Treat a subagent result as a handoff, not proof: for read-only cited work do not repeat the same searches or re-read every file — verify only decision-critical uncertainty; write-capable work requires inspecting the complete settled diff and rerunning relevant integrated validation; when a subagent did not complete normally (failed/crashed/interrupted), the parent must call subagent status to inspect the bounded error/summary of the active/last-settled operation and whether transcript.sessionPath is present, must NOT read the session file in the parent context, and if a retry is needed must pass transcript.sessionPath as Starting evidence into the retry subagent so that the retry subagent's first step reads that session file to locate the last completed step, failure point, and remaining work before continuing; produce the final synthesis yourself.",
    ],
    executionMode: "parallel",
    parameters: SubagentParameters,
    renderCall: (args, theme, context) => {
      if ((args as { action?: string }).action === "run" || (args as { action?: string }).action === "start") {
        const typed = args as { action: "run" | "start"; agent: string; model?: string; thinking?: string };
        if (typed.agent && typed.model === undefined && typed.thinking === undefined) {
          // Best-effort: resolve effective model/thinking from registry + settings overrides.
          // renderCall has no ctx, so try global+project settings via process.cwd() as fallback.
          let found = registry.agents.find((candidate) => candidate.name === typed.agent);
          if (found) {
            try {
              const effective = getEffectiveDiscovery(registry, { cwd: process.cwd(), isProjectTrusted: () => true });
              const overridden = effective.agents.find((candidate) => candidate.name === typed.agent);
              if (overridden) found = overridden;
            } catch { /* keep base registry */ }
            const enriched = {
              ...typed,
              ...(found.model ? { model: stripModel(found.model) } : {}),
              ...(found.thinking ? { thinking: found.thinking } : {}),
            };
            return renderSubagentCall(enriched as unknown as Parameters<typeof renderSubagentCall>[0], theme, context as unknown as Parameters<typeof renderSubagentCall>[2]);
          }
        }
      }
      return renderSubagentCall(args as unknown as Parameters<typeof renderSubagentCall>[0], theme, context as unknown as Parameters<typeof renderSubagentCall>[2]);
    },
    renderResult: renderSubagentResult,
    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      if (params.action === "list") {
        const base = discoverUserAgents(agentDirectory);
        registry = getEffectiveDiscovery(base, ctx as unknown as { cwd: string; isProjectTrusted(): boolean });
        const catalog = boundText(formatAgentCatalog(registry), { maxCharacters: 16_000, maxLines: 200 });
        return {
          content: [{ type: "text" as const, text: catalog }],
          details: {
            agents: registry.agents.map(({ name, description, model, thinking }) => ({
              name,
              description: boundText(description, { maxCharacters: 500, maxLines: 8 }),
              ...(model !== undefined ? { model } : {}),
              ...(thinking !== undefined ? { thinking } : {}),
            })),
            discoveryErrors: registry.errors.map(({ filePath, error }) => ({
              filePath,
              error: boundText(error, { maxCharacters: 500, maxLines: 8 }),
            })),
          },
        };
      }

      const missing = params.action === "run" || params.action === "start"
        ? (!params.agent ? "agent" : !params.task ? "task" : params.deadlineMs === undefined ? "deadlineMs" : undefined)
        : !params.id
          ? "id"
          : params.action === "send"
            ? (!params.mode ? "mode" : !params.message ? "message" : params.mode === "steer" && !params.expectedOperationId ? "expectedOperationId" : undefined)
            : params.action === "wait" && !params.operationId
              ? "operationId"
              : params.action === "interrupt" && !params.expectedOperationId
                ? "expectedOperationId"
                : undefined;
      if (missing) return response({ error: `${missing} is required for subagent ${params.action}` }, true);

      if (
        params.action === "status"
        || params.action === "send"
        || params.action === "wait"
        || params.action === "interrupt"
        || params.action === "close"
      ) {
        const runtime = runtimes.get(params.id);
        if (!runtime) return response({ error: `Unknown subagent runtime: ${params.id}` }, true);

        if (params.action === "status") return response(runtimeSnapshot(runtime));
        if (params.action === "close") {
          try {
            await closeRuntime(runtime, true);
            return response(runtimeSnapshot(runtime));
          } catch (error) {
            return response({ ...runtimeSnapshot(runtime), error: error instanceof Error ? error.message : String(error) }, true);
          }
        }
        if (params.action === "interrupt") {
          const operation = runtime.operations.get(params.expectedOperationId);
          if (
            runtime.state !== "running"
            || runtime.activeOperationId !== params.expectedOperationId
            || !operation?.accepted
          ) {
            return response({ accepted: false, conflict: true, snapshot: runtimeSnapshot(runtime) });
          }
          const accepted = await runtime.controller!.interrupt(params.expectedOperationId);
          return response({ accepted, snapshot: runtimeSnapshot(runtime) });
        }
        if (params.action === "send" && params.mode === "steer") {
          const operation = runtime.operations.get(params.expectedOperationId);
          if (
            shuttingDown
            || runtime.state !== "running"
            || runtime.activeOperationId !== params.expectedOperationId
            || !operation?.accepted
          ) {
            return response({ accepted: false, conflict: true, snapshot: runtimeSnapshot(runtime) });
          }
          try {
            const accepted = await runtime.controller!.steer(params.expectedOperationId, params.message);
            if (accepted) runtime.revision += 1;
            return response({ accepted, conflict: !accepted, snapshot: runtimeSnapshot(runtime) });
          } catch (error) {
            return response({
              accepted: false,
              snapshot: runtimeSnapshot(runtime),
              error: error instanceof Error ? error.message : String(error),
            }, true);
          }
        }
        if (params.action === "wait") {
          const operation = runtime.operations.get(params.operationId);
          if (!operation) {
            return response({ error: `Unknown operation ${params.operationId} for runtime ${runtime.runId}` }, true);
          }
          if (operation.state === "running" || operation.state === "queued") {
            if (params.timeoutMs === undefined) {
              await operation.settled;
            } else {
              let timer: ReturnType<typeof setTimeout> | undefined;
              const settled = await Promise.race([
                operation.settled.then(() => true),
                new Promise<false>((resolveTimeout) => {
                  timer = setTimeout(() => resolveTimeout(false), params.timeoutMs);
                }),
              ]);
              if (timer) clearTimeout(timer);
              if (!settled) return response({ reason: "timeout", snapshot: runtimeSnapshot(runtime) });
            }
          }
          return operationResponse(operation, runtime);
        }

        if (shuttingDown) return response({ error: "Subagent runtime is shutting down" }, true);
        if (runtime.state === "running" && runtime.queuedOperationId === undefined) {
          let settle!: () => void;
          const operationId = idFactory();
          const operation: OperationRecord = {
            operationId,
            state: "queued",
            accepted: false,
            task: params.message,
            deadlineMs: params.deadlineMs ?? 600_000,
            queuedAt: Date.now(),
            notifyOnSettle: true,
            settled: new Promise<void>((resolve) => { settle = resolve; }),
            settle: () => settle(),
          };
          runtime.operations.set(operationId, operation);
          runtime.queuedOperationId = operationId;
          runtime.revision += 1;
          return response({ ...runtimeSnapshot(runtime), operationId, queued: true });
        }
        if (runtime.state !== "idle") {
          return response({
            accepted: false,
            conflict: true,
            error: runtime.queuedOperationId ? "Runtime follow-up queue is full" : "Runtime cannot accept a follow-up",
            snapshot: runtimeSnapshot(runtime),
          }, true);
        }
        const operationId = idFactory();
        try {
          await beginOperation(
            runtime,
            operationId,
            params.message,
            params.deadlineMs ?? 600_000,
            true,
            signal,
            onUpdate
              ? (summary) => onUpdate({
                  content: [{ type: "text", text: summary }],
                  details: {
                    runId: runtime.runId,
                    operationId,
                    agent: runtime.agent.name,
                    ...(runtime.agent.model ? { model: stripModel(runtime.agent.model) } : {}),
                    ...(runtime.agent.thinking ? { thinking: runtime.agent.thinking } : {}),
                    status: "running",
                  },
                })
              : undefined,
          );
          return response({ ...runtimeSnapshot(runtime), operationId });
        } catch (error) {
          return response({ ...runtimeSnapshot(runtime), error: error instanceof Error ? error.message : String(error) }, true);
        }
      }

      if (shuttingDown) {
        return response({ error: "Subagent runtime is shutting down; new runs are rejected." }, true);
      }
      const effectiveRegistry = getEffectiveDiscovery(registry, ctx as unknown as { cwd: string; isProjectTrusted(): boolean });
      const agent = effectiveRegistry.agents.find((candidate) => candidate.name === params.agent);
      if (!agent) {
        const available = effectiveRegistry.agents.map((candidate) => candidate.name).join(", ") || "none";
        const invalid = effectiveRegistry.errors.find((error) => error.filePath.endsWith(`/${params.agent}.md`));
        return {
          content: [{
            type: "text" as const,
            text: invalid
              ? `Agent definition is invalid: ${invalid.error}`
              : `Unknown user agent: ${params.agent}. Available agents: ${available}.`,
          }],
          details: { discoveryErrors: effectiveRegistry.errors },
          isError: true,
        };
      }
      if (occupiedSlots >= 3) {
        return response({ error: "Subagent capacity unavailable: maxConcurrentRuns is 3." }, true);
      }

      const allowedRoot = findAllowedRoot(ctx.cwd);
      const cwd = resolveChildCwd(allowedRoot, resolve(ctx.cwd, params.cwd ?? "."));
      const runId = idFactory();
      const operationId = idFactory();
      const controllerReady = deferred<SubagentController>();
      const runtime: RuntimeRecord = {
        runId,
        revision: 0,
        agent,
        cwd,
        parentSessionId: ctx.sessionManager.getSessionId(),
        projectGuidance: loadProjectGuidance(allowedRoot, cwd),
        state: "starting",
        controllerReady: controllerReady.promise,
        operations: new Map(),
        slotReserved: true,
      };
      occupiedSlots += 1;
      runtimes.set(runId, runtime);

      const initialOptions: SubagentRunOptions = {
        cwd,
        agent,
        workOrder: createWorkOrder(params.task, cwd, runtime.projectGuidance),
        runId,
        operationId,
        parentSessionId: runtime.parentSessionId,
        deadlineMs: params.deadlineMs!,
        signal,
      };
      void Promise.resolve().then(() => controllerFactory(initialOptions)).then(
        (controller) => {
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
      try {
        onUpdate?.({
          content: [{ type: "text", text: "Starting isolated child…" }],
          details: {
            runId,
            operationId,
            agent: agent.name,
            ...(agent.model ? { model: stripModel(agent.model) } : {}),
            ...(agent.thinking ? { thinking: agent.thinking } : {}),
            status: "starting",
          },
        });
        runtime.controller = await runtime.controllerReady;
        if (shuttingDown || runtime.state !== "starting") {
          throw new Error("Subagent runtime closed before its initial operation was accepted");
        }
        const operation = await beginOperation(
          runtime,
          operationId,
          params.task,
          params.deadlineMs!,
          params.action === "start",
          signal,
          onUpdate
            ? (summary) => onUpdate({
                content: [{ type: "text", text: summary }],
                details: {
                  runId,
                  operationId,
                  agent: agent.name,
                  ...(agent.model ? { model: stripModel(agent.model) } : {}),
                  ...(agent.thinking ? { thinking: agent.thinking } : {}),
                  status: "running",
                },
              })
            : undefined,
        );
        if (params.action === "start") return response({ ...runtimeSnapshot(runtime), operationId });
        await operation.settled;
        await closeRuntime(runtime);
        return operationResponse(operation, runtime);
      } catch (error) {
        if (!runtime.closePromise) transition(runtime, "crashed");
        try {
          await closeRuntime(runtime, true);
        } catch {
          // The original startup/operation failure is the actionable error.
        }
        return response({
          ...runtimeSnapshot(runtime),
          error: error instanceof Error ? error.message : String(error),
        }, true);
      }
    },
  });

  pi.registerMessageRenderer<SubagentCompletionDetails>(
    SUBAGENT_COMPLETION_MESSAGE,
    renderSubagentCompletion,
  );

  pi.on("session_shutdown", async () => {
    shuttingDown = true;
    await Promise.allSettled([...runtimes.values()].map((runtime) => closeRuntime(runtime, true)));
  });
}

export default function subagentExtension(pi: ExtensionAPI): void {
  registerSubagentExtension(pi);
}
