import { randomUUID } from "node:crypto";
import { join } from "node:path";

import { getAgentDir, type ExtensionAPI, type ToolDefinition } from "@earendil-works/pi-coding-agent";
import { StringEnum } from "@earendil-works/pi-ai";
import { Type, type Static } from "typebox";

import {
  applyAgentOverrides,
  discoverUserAgents,
  formatAgentCatalog,
  loadSubagentSettings,
  resolveAgentModel,
} from "./agents.ts";
import { createWorkOrder, findAllowedRoot, loadProjectGuidance, resolveChildCwd } from "./context.ts";
import { createLiveUi } from "./live-ui.ts";
import { boundText, collectCredentialValues, modelSubagentHandoff, sanitizeOneLine } from "./output.ts";
import { createRuntimeHub, type OperationRecord, type RuntimeRecord } from "./runtime.ts";
import { createSdkSubagentController } from "./sdk-executor.ts";
import { stripModel } from "./protocol.ts";
import {
  renderSubagentCall,
  renderSubagentCompletion,
  renderSubagentResult,
  SUBAGENT_COMPLETION_MESSAGE,
  type SubagentCompletionDetails,
  type SubagentCompletionPayload,
  type SubagentRenderContext,
  type SubagentRenderResult,
} from "./render/index.ts";
import type { SubagentControllerFactory, SubagentRunOptions } from "./protocol.ts";

export interface SubagentExtensionOptions {
  agentDirectory?: string;
  /** Additional environment variables whose values must be redacted from child output. */
  credentialRedactionEnvNames?: readonly string[];
  /** @deprecated Use credentialRedactionEnvNames. Values are redacted, not allowed/forwarded. */
  authEnvAllowlist?: readonly string[];
  controllerFactory?: SubagentControllerFactory;
  controllerCreationTimeoutMs?: number;
  idFactory?: () => string;
  settingsPath?: string;
  /** Internal/test override; production defaults to settings.json subagent.sessions.enabled. */
  sessionsEnabled?: boolean;
}

function retainCallTitleDetails(
  result: SubagentRenderResult,
  context: SubagentRenderContext,
): void {
  const action = (context.args as { action?: string }).action;
  if (action !== undefined && action !== "run" && action !== "followup" && action !== "open" && action !== "send") return;
  const details = result.details && typeof result.details === "object"
    ? result.details as Record<string, unknown>
    : {};
  const model = typeof details.model === "string" ? details.model : undefined;
  const thinking = typeof details.thinking === "string" ? details.thinking : undefined;
  const turn = typeof details.turn === "number" && Number.isSafeInteger(details.turn) && details.turn > 0
    ? details.turn
    : undefined;
  let changed = false;
  if (model !== undefined && context.state.model !== model) {
    context.state.model = model;
    changed = true;
  }
  if (thinking !== undefined && context.state.thinking !== thinking) {
    context.state.thinking = thinking;
    changed = true;
  }
  if (turn !== undefined && context.state.turn !== turn) {
    context.state.turn = turn;
    changed = true;
  }
  if (!changed) return;
  queueMicrotask(() => {
    try {
      context.invalidate();
    } catch {
      // The row may have been disposed before its deferred repaint.
    }
  });
}

const COMPLETION_WAKE_FIRST_LINE_MAX_CHARACTERS = 160;
const AUTH_ENV_NAME = /^[A-Z_][A-Z0-9_]*$/;
export function validateCredentialRedactionEnvNames(names: readonly string[] | undefined): string[] | undefined {
  if (names === undefined) return undefined;
  const validated = names.map((rawName) => {
    const name = rawName.trim();
    if (!AUTH_ENV_NAME.test(name)) {
      throw new Error(`Invalid subagent auth environment variable name: ${JSON.stringify(rawName)}`);
    }
    return name;
  });
  return [...new Set(validated)];
}

/** @deprecated Use validateCredentialRedactionEnvNames. */
export const validateAuthEnvAllowlist = validateCredentialRedactionEnvNames;

/** One compact model-facing title: the first task line, never the work-order body. */
function completionWakeTitle(task: string): string {
  const firstMeaningfulLine = task
    .split(/\r?\n/)
    .map((line) => line.trim())
    .find((line) => line.length > 0 && !line.startsWith("#"));
  return firstMeaningfulLine
    ?.replace(/^outcome\s*[:：]\s*/i, "")
    .replace(/\s+/g, " ")
    .trim() ?? "";
}

/** Formats the parent session's current model as `{provider}/{id}`, or undefined when unavailable or malformed. */
const mainModelOf = (model: { provider?: unknown; id?: unknown } | undefined): string | undefined =>
  model && typeof model.provider === "string" && typeof model.id === "string"
    ? `${model.provider}/${model.id}`
    : undefined;

// Provider tool APIs require a root object schema; a root Type.Union serializes
// as anyOf and is rejected by DeepSeek before the model can call the tool.
const SubagentTaskParameters = Type.Object({
  agent: Type.String({ description: "Registered role that owns this bounded task" }),
  task: Type.String({ minLength: 1, description: "Self-contained outcome, necessary context, constraints, acceptance criteria, and expected handoff" }),
});
type SubagentTaskParameters = Static<typeof SubagentTaskParameters>;

const SubagentSessionParameters = Type.Object({
  action: StringEnum(["open", "send", "get", "cancel", "close"] as const, { description: "open: start a reusable session; send: continue an idle session; get: inspect/list; cancel: stop active turn; close: release session" }),
  agent: Type.Optional(Type.String({ description: "Registered role; required only for open" })),
  task: Type.Optional(Type.String({ minLength: 1, description: "Self-contained work order for open; only the unresolved delta and next action for send" })),
  background: Type.Optional(Type.Boolean({ description: "Return after acceptance and notify on settlement; default false" })),
  ref: Type.Optional(Type.String({ minLength: 1, description: "Session-local #N; required for send/cancel/close and optional for get" })),
  waitMs: Type.Optional(Type.Integer({ minimum: 0, maximum: 3_600_000, description: "Observational wait for get only; never interrupts work" })),
});
type SubagentSessionParameters = Static<typeof SubagentSessionParameters>;
type ControlRequest = {
  action: "run" | "followup" | "get" | "cancel" | "close";
  agent?: string;
  task?: string;
  mode?: "task" | "session";
  background?: boolean;
  ref?: string;
  waitMs?: number;
};

export { loadSubagentOverrides } from "./agents.ts";

export function registerSubagentExtension(pi: ExtensionAPI, options: SubagentExtensionOptions = {}): void {
  const agentDirectory = options.agentDirectory ?? join(getAgentDir(), "agents");
  const settingsPath = options.settingsPath ?? join(getAgentDir(), "settings.json");
  const settings = loadSubagentSettings(settingsPath);
  const loadedOverrides = { overrides: settings.overrides, maxConcurrentRuns: settings.maxConcurrentRuns, errors: settings.errors };
  const settingsDefaults = settings.defaults;
  const discoverEffectiveAgents = () => {
    const discovery = discoverUserAgents(agentDirectory);
    return applyAgentOverrides({
      agents: discovery.agents,
      errors: [...discovery.errors, ...loadedOverrides.errors],
    }, loadedOverrides.overrides);
  };
  let registry = discoverEffectiveAgents();
  const startupCatalog = boundText(formatAgentCatalog(registry), { maxCharacters: 16_000, maxLines: 200 });
  const authEnvSetting = process.env.PI_SUBAGENT_AUTH_ENV_ALLOWLIST;
  const configuredAuthEnvNames = options.credentialRedactionEnvNames ?? options.authEnvAllowlist
    ?? (authEnvSetting?.trim()
      ? authEnvSetting.split(",")
      : undefined);
  const credentialEnvNames = validateCredentialRedactionEnvNames(configuredAuthEnvNames);
  const sdkConfig = {
    agentDir: getAgentDir(),
    sessionRoot: join(getAgentDir(), "subagent-sessions"),
    ...(credentialEnvNames && credentialEnvNames.length > 0 ? { credentialEnvNames } : {}),
  };
  const controllerFactory = options.controllerFactory
    ?? ((initial: SubagentRunOptions) => createSdkSubagentController(initial, sdkConfig));
  const idFactory = options.idFactory ?? randomUUID;
  const credentialSecrets = collectCredentialValues(credentialEnvNames ?? []);
  const boundedError = (error: unknown): string => boundText(
    error instanceof Error ? error.message : String(error),
    { maxCharacters: 2_000, maxLines: 20 },
    credentialSecrets,
  );
  let parentIdle: (() => boolean) | undefined;
  const notifySettled = (payload: SubagentCompletionPayload): boolean => {
    const entries = "batch" in payload ? payload.batch : [payload];
    const blocks = entries.map((details) => {
      const reference = details.ref;
      const elapsed = typeof details.elapsedMs === "number"
        ? ` · ${Math.max(0, Math.ceil(details.elapsedMs / 1000))}s`
        : "";
      const firstLine = `${reference} ${details.agent} · ${details.status}${elapsed}`;
      const rawTitle = sanitizeOneLine(completionWakeTitle(details.task), COMPLETION_WAKE_FIRST_LINE_MAX_CHARACTERS, credentialSecrets);
      const titleBudget = COMPLETION_WAKE_FIRST_LINE_MAX_CHARACTERS - firstLine.length - " — ".length;
      const title = !rawTitle || titleBudget < 2
        ? ""
        : rawTitle.length <= titleBudget
          ? rawTitle
          : `${rawTitle.slice(0, titleBudget - 1)}…`;
      return [
        title ? `${firstLine} — ${title}` : firstLine,
        `  Use get(${JSON.stringify(details.ref)}) to retrieve the result.`,
      ].join("\n");
    });
    const header = entries.length > 1 ? `${entries.length} background subagents settled:\n\n` : "";
    const content = boundText(header + blocks.join("\n\n"), { maxCharacters: 16_000, maxLines: 96 }, credentialSecrets);
    // Busy/idle split: idle parents wake immediately; busy parents queue as
    // followUp. Steer is never used so wakes cannot hijack active streaming.
    let idle = true;
    try {
      idle = parentIdle?.() ?? true;
    } catch {
      idle = true;
    }
    try {
      pi.sendMessage<SubagentCompletionPayload>({
        customType: SUBAGENT_COMPLETION_MESSAGE,
        content,
        display: true,
        details: payload,
      }, idle ? { triggerTurn: true } : { triggerTurn: true, deliverAs: "followUp" });
      return true;
    } catch {
      // Notification delivery must not change authoritative operation state.
      return false;
    }
  };
  const logSettled = (details: SubagentCompletionDetails): void => {
    try {
      // Durable human-visible audit trail; never rendered into the model context.
      pi.appendEntry("subagent-settle-log", {
        jobId: details.jobId,
        operationId: details.operationId,
        turn: details.turn,
        ref: details.ref,
        agent: details.agent,
        status: details.status,
        elapsedMs: details.elapsedMs ?? null,
        taskPrefix: boundText(details.task, { maxCharacters: 120, maxLines: 1 }, credentialSecrets),
      });
    } catch {
      // The settle log is best-effort; never affect operation state.
    }
  };
  const live = createLiveUi();
  const hub = createRuntimeHub({
    controllerFactory,
    maxConcurrentRuns: loadedOverrides.maxConcurrentRuns ?? 3,
    notifySettled,
    logSettled,
    live,
    credentialSecrets,
    ...(options.controllerCreationTimeoutMs === undefined ? {} : {
      controllerCreationTimeoutMs: options.controllerCreationTimeoutMs,
    }),
  });
  const closeRuntime = (runtime: RuntimeRecord, suppressNotification = false): Promise<void> =>
    hub.closeRuntime(runtime, suppressNotification);
  const internalModelKeys = new Set([
    "displayIndex", "index", "jobId", "operationId", "processInstanceId",
    "revision", "runId", "timeline", "toolProgress", "transcript", "turn",
  ]);
  const modelProjection = (value: unknown): unknown => {
    if (Array.isArray(value)) return value.map(modelProjection);
    if (!value || typeof value !== "object") return value;
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .filter(([key]) => !internalModelKeys.has(key))
        .map(([key, entry]) => [
          key,
          key === "model" && typeof entry === "string" ? stripModel(entry) : modelProjection(entry),
        ]),
    );
  };
  const response = (details: unknown, isError = false, modelDetails: unknown = details) => {
    const serialized = JSON.stringify(modelProjection(modelDetails));
    const bounded = serialized.length <= 32_000
      ? serialized
      : JSON.stringify({ error: "Subagent response exceeded the parent serialization limit", truncated: true });
    return {
      content: [{ type: "text" as const, text: bounded }],
      details,
      ...(isError ? { isError: true } : {}),
    };
  };

  const turnDetails = (operation: OperationRecord, runtime: RuntimeRecord, exposeRef = true) => {
    const elapsedMs = operation.startedAt === undefined
      ? undefined
      : (operation.finishedAt ?? Date.now()) - operation.startedAt;
    if (!operation.result) {
      return {
        turnStatus: operation.state,
        ...(elapsedMs === undefined ? {} : { elapsedMs }),
        ...(operation.error ? { error: boundText(operation.error, { maxCharacters: 2_000, maxLines: 20 }, credentialSecrets) } : {}),
      };
    }
    // Redact before bounding so no credential material reaches the parent context.
    const handoff = modelSubagentHandoff({
      ...(exposeRef ? { ref: `#${runtime.index}` } : {}),
      agent: operation.result.agent,
      status: operation.result.status,
      summary: boundText(operation.result.summary, { maxCharacters: 16_000, maxLines: 400 }, credentialSecrets),
      ...(elapsedMs === undefined ? {} : { elapsedMs }),
    });
    const { status: turnStatus, ...result } = handoff;
    return { turnStatus, ...result };
  };

  const publicSession = (runtime: RuntimeRecord) => {
    const operation = runtime.activeOperationId
      ? runtime.operations.get(runtime.activeOperationId)
      : runtime.lastSettled;
    return {
      ref: `#${runtime.index}`,
      status: runtime.state,
      agent: runtime.agent.name,
      ...(runtime.agent.model ? { model: runtime.agent.model } : {}),
      ...(runtime.agent.thinking ? { thinking: runtime.agent.thinking } : {}),
      ...(operation ? {
        turn: operation.turn,
        task: boundText(operation.task, { maxCharacters: 2_000, maxLines: 20 }, credentialSecrets),
        ...turnDetails(operation, runtime),
        ...(operation.latestProgress ? {
          activity: operation.latestProgress.summary,
          recentActivity: operation.latestProgress.recentActivity,
          ...(operation.latestProgress.timeline ? { timeline: operation.latestProgress.timeline } : {}),
          ...(operation.latestProgress.tools ? { toolProgress: operation.latestProgress.tools } : {}),
        } : {}),
      } : {}),
    };
  };
  const publicSessionSummary = (runtime: RuntimeRecord) => ({
    ref: `#${runtime.index}`,
    status: runtime.state,
    agent: runtime.agent.name,
  });

  const operationResponse = (operation: OperationRecord, runtime: RuntimeRecord) => {
    const details = publicSession(runtime);
    return response(details, operation.state === "failed");
  };

  const taskResponse = (operation: OperationRecord, runtime: RuntimeRecord, cleanupError?: string) => {
    const turn = turnDetails(operation, runtime, false);
    const details = {
      mode: "task",
      status: cleanupError ? "crashed" : "closed",
      agent: runtime.agent.name,
      task: boundText(operation.task, { maxCharacters: 2_000, maxLines: 20 }, credentialSecrets),
      ...(runtime.agent.model ? { model: runtime.agent.model } : {}),
      ...(runtime.agent.thinking ? { thinking: runtime.agent.thinking } : {}),
      ...turn,
      ...(operation.latestProgress ? {
        activity: operation.latestProgress.summary,
        recentActivity: operation.latestProgress.recentActivity,
        ...(operation.latestProgress.timeline ? { timeline: operation.latestProgress.timeline } : {}),
        ...(operation.latestProgress.tools ? { toolProgress: operation.latestProgress.tools } : {}),
      } : {}),
      ...(cleanupError ? { cleanupError } : {}),
    };
    const { turnStatus, ...handoff } = turn;
    return response(details, operation.state === "failed" || cleanupError !== undefined, {
      agent: runtime.agent.name,
      status: cleanupError ? "failed" : turnStatus,
      ...handoff,
      ...(cleanupError ? { cleanupError } : {}),
    });
  };

  const sessionTool: ToolDefinition = {
    name: "subagent_session",
    label: "Subagent Session",
    description:
      `Advanced reusable child conversations. open starts a session, send continues preserved context, get inspects, cancel stops the active turn, and close releases it. Use only when later turns materially benefit from the same child context. At most ${hub.maxConcurrentRuns} turns execute concurrently.\n\nRegistered roles:\n${startupCatalog}`,
    executionMode: "parallel",
    renderShell: "self",
    parameters: SubagentSessionParameters,
    renderCall: (args, theme, context) => {
      const input = args as Record<string, unknown>;
      const redactedArgs = typeof (args as { task?: unknown }).task === "string"
        ? { ...input, task: boundText((args as { task: string }).task, { maxCharacters: 8_000, maxLines: 40 }, credentialSecrets) }
        : input;
      const publicAction = (redactedArgs as { action?: string }).action;
      const action = publicAction === "open" ? "run" : publicAction === "send" ? "followup" : publicAction;
      const renderArgs = { ...redactedArgs, action };
      if (action === "run" || action === "followup") {
        const typed = renderArgs as { action: "run" | "followup"; agent?: string; ref?: string; model?: string; thinking?: string };
        const found = action === "run"
          ? registry.agents.find((candidate) => candidate.name === typed.agent)
          : typed.ref ? hub.resolve(typed.ref)?.agent : undefined;
        if (found) {
          const enriched = {
            ...typed,
            mode: "session" as const,
            agent: found.name,
            ...(found.model ? { model: found.model } : {}),
            ...(found.thinking ? { thinking: found.thinking } : {}),
          };
          return renderSubagentCall(enriched as unknown as Parameters<typeof renderSubagentCall>[0], theme, context as unknown as Parameters<typeof renderSubagentCall>[2]);
        }
      }
      return renderSubagentCall(renderArgs as unknown as Parameters<typeof renderSubagentCall>[0], theme, context as unknown as Parameters<typeof renderSubagentCall>[2]);
    },
    renderResult: (result, renderOptions, theme, context) => {
      const typedResult = result as unknown as Parameters<typeof renderSubagentResult>[0];
      const typedContext = context as unknown as Parameters<typeof renderSubagentResult>[3];
      retainCallTitleDetails(typedResult, typedContext);
      return renderSubagentResult(
        typedResult,
        renderOptions,
        theme,
        typedContext,
      );
    },
    async execute(_toolCallId, input, signal, onUpdate, ctx) {
      if (ctx.hasUI) live.attach(ctx.ui);
      const idleProbe = ctx.isIdle?.bind(ctx);
      if (idleProbe) parentIdle = idleProbe;
      const rawRequest = input as SubagentSessionParameters | ControlRequest;
      const request: ControlRequest = rawRequest.action === "open"
        ? { ...rawRequest, action: "run", mode: "session" }
        : rawRequest.action === "send"
          ? { ...rawRequest, action: "followup", mode: "session" }
          : rawRequest as ControlRequest;
      if (request.action === "get") {
        if (!request.ref) return response({ sessions: hub.listRuntimes().filter((runtime) => runtime.reusable).slice(-100).reverse().map(publicSessionSummary) });
        const runtime = hub.resolve(request.ref);
        if (!runtime) return response({ ref: request.ref, status: "unknown", unknown: true, error: "Subagent session is unknown or expired." }, true);
        const operation = runtime.activeOperationId ? runtime.operations.get(runtime.activeOperationId) : runtime.lastSettled;
        if (operation?.state === "running" && request.waitMs !== undefined && request.waitMs > 0) {
          let timedOut = false;
          let timer: ReturnType<typeof setTimeout> | undefined;
          await Promise.race([
            operation.settled,
            new Promise<void>((resolveTimeout) => { timer = setTimeout(() => { timedOut = true; resolveTimeout(); }, request.waitMs); }),
          ]);
          if (timer) clearTimeout(timer);
          if (timedOut && operation.state === "running") return response({ ...publicSession(runtime), timedOut: true });
        }
        if (operation && operation.state !== "running") live.remove(operation.operationId);
        return response(publicSession(runtime));
      }
      if (request.action === "cancel") {
        if (!request.ref) return response({ error: "ref is required for subagent cancel" }, true);
        const runtime = hub.resolve(request.ref);
        if (!runtime) return response({ ref: request.ref, status: "unknown", cancelled: false, unknown: true, error: `Subagent session is unknown or expired: ${request.ref}.` }, true);
        const operation = runtime.activeOperationId ? runtime.operations.get(runtime.activeOperationId) : undefined;
        if (!operation || operation.state !== "running" || !operation.accepted) {
          return response({ ...publicSession(runtime), cancelled: false, alreadyIdle: runtime.state === "idle" });
        }
        try {
          const accepted = await runtime.controller!.interrupt(operation.operationId);
          if (accepted) await operation.settled;
          return response({ ...publicSession(runtime), cancelled: accepted });
        } catch (error) {
          await closeRuntime(runtime, true).catch(() => {});
          return response({ ref: `#${runtime.index}`, agent: runtime.agent.name, status: "crashed", cancelled: false, error: boundedError(error) }, true);
        }
      }
      if (request.action === "close") {
        if (!request.ref) return response({ error: "ref is required for subagent close" }, true);
        const runtime = hub.resolve(request.ref);
        if (!runtime) return response({ ref: request.ref, status: "unknown", closed: false, unknown: true, error: `Subagent session is unknown or expired: ${request.ref}.` }, true);
        try {
          await closeRuntime(runtime, true);
          return response({ ...publicSessionSummary(runtime), closed: true });
        } catch (error) {
          return response({ ...publicSessionSummary(runtime), closed: false, error: boundedError(error) }, true);
        }
      }

      const executeTurn = async (
        runtime: RuntimeRecord,
        task: string,
        background: boolean,
        runSignal: AbortSignal | undefined,
        runOnUpdate: typeof onUpdate,
        initial: boolean,
        reusable: boolean,
        initialOperationId?: string,
      ) => {
        const operationId = initialOperationId ?? idFactory();
        const workOrder = createWorkOrder(task, runtime.cwd, initial ? runtime.projectGuidance : []);
        try {
        runOnUpdate?.({
          content: [{ type: "text", text: initial
            ? `Starting subagent ${reusable ? "session" : "task"}…`
            : "Continuing subagent session…" }],
          details: {
            ...(reusable ? { ref: `#${runtime.index}` } : {}),
            mode: reusable ? "session" : "task",
            turn: runtime.nextTurnNumber,
            agent: runtime.agent.name,
            ...(runtime.agent.model ? { model: runtime.agent.model } : {}),
            ...(runtime.agent.thinking ? { thinking: runtime.agent.thinking } : {}),
            status: "starting",
          },
        });
        if (initial) {
          runtime.controller = await runtime.controllerReady;
          if (hub.isShuttingDown() || runtime.state !== "starting") {
            throw new Error("Subagent session closed before its initial turn was accepted");
          }
        }
        const operation = await hub.beginOperation(runtime, {
          operationId,
          task,
          notifyOnSettle: background,
          exposeRef: reusable,
          workOrder,
          signal: runSignal,
          onUpdate: runOnUpdate,
        });
        if (background) {
          // The widget starts only after prompt acceptance. Progress received
          // during startup is retained on the operation and hydrated here.
          // An operation that already settled is delivered only as a card.
          if (operation.state === "running") {
            live.track(operation.operationId, {
              index: runtime.index,
              agent: runtime.agent.name,
              turn: operation.turn,
              startedAt: operation.startedAt ?? Date.now(),
              runId: runtime.runId,
              // Redact before display so credential material never reaches the
              // widget; single source with the wake/audit path via credentialSecrets.
              task: boundText(task, { maxCharacters: 500, maxLines: 5 }, credentialSecrets),
            });
            const latest = operation.latestProgress;
            if (latest) {
              live.progress(
                operation.operationId,
                latest.summary,
                latest.phase,
                latest.tools?.active.length,
              );
            }
          }
          return response(publicSession(runtime));
        }
        await operation.settled;
        if (reusable) return operationResponse(operation, runtime);
        try {
          await closeRuntime(runtime);
          return taskResponse(operation, runtime);
        } catch (error) {
          return taskResponse(operation, runtime, boundedError(error));
        }
      } catch (error) {
        hub.markCrashed(runtime);
        try {
          await closeRuntime(runtime, true);
        } catch {
          // The original startup/operation failure is the actionable error.
        }
        return response({
          ...(reusable ? { ref: `#${runtime.index}` } : {}),
          mode: reusable ? "session" : "task",
          agent: runtime.agent.name,
          status: "crashed",
          error: boundedError(error),
        }, true);
      }
      };

      if (request.action === "followup") {
        const label = rawRequest.action === "send" ? "send" : "followup";
        if (!request.ref) return response({ error: `ref is required for subagent session ${label}` }, true);
        if (!request.task) return response({ error: `task is required for subagent session ${label}` }, true);
        const runtime = hub.resolve(request.ref);
        if (!runtime) return response({ ref: request.ref, status: "unknown", unknown: true, error: "Subagent session is unknown or expired." }, true);
        if (runtime.state !== "idle") return response({ ...publicSession(runtime), error: `Subagent session is ${runtime.state}; ${label} requires idle.` }, true);
        if (!hub.reserveSlot(runtime)) return response({ error: `Subagent capacity unavailable: maxConcurrentRuns is ${hub.maxConcurrentRuns}.`, ...publicSession(runtime) }, true);
        return executeTurn(runtime, request.task, request.background === true, signal, onUpdate, false, true);
      }

      const runLabel = rawRequest.action === "open" ? "session open" : "task";
      if (!request.agent) return response({ error: `agent is required for subagent ${runLabel}` }, true);
      if (!request.task) return response({ error: `task is required for subagent ${runLabel}` }, true);
      const mode = request.mode ?? "task";
      if (mode === "task" && request.background === true) {
        return response({ error: "background requires mode=session; task mode returns one final result and auto-closes" }, true);
      }
      if (hub.isShuttingDown()) return response({ error: "Subagent runtime is shutting down; new sessions are rejected." }, true);
      if (!hub.capacityAvailable()) {
        return response({
          error: `Subagent capacity unavailable: maxConcurrentRuns is ${hub.maxConcurrentRuns}.`,
          maxConcurrentRuns: hub.maxConcurrentRuns,
          occupiedSlots: hub.occupiedSlots(),
          availableSlots: hub.availableSlots(),
          sessions: hub.listRuntimes().filter((runtime) => runtime.reusable).slice(-100).map(publicSessionSummary),
        }, true);
      }
      const openSessions = hub.listRuntimes().filter((runtime) => runtime.reusable && runtime.state !== "closed" && runtime.state !== "crashed");
      if (openSessions.length >= 100) return response({ error: "Subagent session limit reached; close an idle session before starting another." }, true);
      const agent = registry.agents.find((candidate) => candidate.name === request.agent);
      if (!agent) {
        const available = registry.agents.map((candidate) => candidate.name).join(", ") || "none";
        const invalid = registry.errors.find((error) => error.filePath.endsWith(`/${request.agent}.md`));
        return response({
          error: invalid ? `Agent definition is invalid: ${invalid.error}` : `Unknown agent: ${request.agent}. Available agents: ${available}.`,
        }, true);
      }
      let cwd: string;
      let projectGuidance: string[];
      try {
        const allowedRoot = findAllowedRoot(ctx.cwd);
        cwd = resolveChildCwd(allowedRoot, ctx.cwd);
        projectGuidance = loadProjectGuidance(allowedRoot, cwd);
      } catch (error) {
        return response({ error: boundText(error instanceof Error ? error.message : String(error), { maxCharacters: 2_000, maxLines: 20 }) }, true);
      }
      const runtimeAgent = agent.model ? agent : (() => {
        const model = resolveAgentModel(agent, settingsDefaults, mainModelOf(ctx.model));
        return model ? { ...agent, model } : agent;
      })();
      const runId = idFactory();
      const operationId = idFactory();
      const parentSessionId = ctx.sessionManager.getSessionId();
      const initialOptions: SubagentRunOptions = {
        cwd,
        agent: runtimeAgent,
        workOrder: createWorkOrder(request.task, cwd, projectGuidance),
        runId,
        operationId,
        parentSessionId,
        signal,
      };
      const runtime = hub.createRuntime({ reusable: mode === "session", agent: runtimeAgent, cwd, parentSessionId, projectGuidance, initialOptions });
      return executeTurn(runtime, request.task, request.background === true, signal, onUpdate, true, mode === "session", operationId);
    },
  };

  pi.registerTool({
    name: "subagent",
    label: "Subagent",
    description:
      `Run one bounded task in fresh isolated context and return its final handoff. Use only for independently owned parallel work, substantial context isolation, explicit independent review, or separate exploratory/browser QA. Work directly on coherent implementation, routine self-review, exact lookups, and serial steps. Parallel calls express independent tasks.\n\nRegistered roles:\n${startupCatalog}`,
    executionMode: "parallel",
    renderShell: "self",
    parameters: SubagentTaskParameters,
    renderCall: (args, theme, context) => {
      const typed = args as unknown as SubagentTaskParameters;
      const found = registry.agents.find((candidate) => candidate.name === typed.agent);
      const enriched = {
        action: "run" as const,
        ...typed,
        task: boundText(typed.task, { maxCharacters: 8_000, maxLines: 40 }, credentialSecrets),
        ...(found?.model ? { model: found.model } : {}),
        ...(found?.thinking ? { thinking: found.thinking } : {}),
      };
      return renderSubagentCall(enriched, theme, context as unknown as Parameters<typeof renderSubagentCall>[2]);
    },
    renderResult: sessionTool.renderResult,
    async execute(toolCallId, input, signal, onUpdate, ctx) {
      const task = input as SubagentTaskParameters;
      if (!task.agent) return response({ error: "agent is required for subagent task" }, true);
      if (!task.task) return response({ error: "task is required for subagent task" }, true);
      return sessionTool.execute(toolCallId, {
        action: "run",
        mode: "task",
        agent: task.agent,
        task: task.task,
      } as never, signal, onUpdate, ctx);
    },
  });
  if (options.sessionsEnabled ?? settings.sessionsEnabled) pi.registerTool(sessionTool);

  // Live error propagation: agent-core derives the serialized
  // toolResult.isError only from a thrown execute() error ("Signaling errors"
  // in docs/extensions.md), so an isError flag on a returned value is dropped
  // before it reaches the parent transcript. Throwing would lose structured
  // recovery details, so error branches return details.error or a failed turn
  // status and this handler re-asserts the flag on the live pipeline. Normal
  // handoffs and idempotent repeats remain successful.
  pi.on("tool_result", (event) => {
    if ((event.toolName !== "subagent" && event.toolName !== "subagent_session") || event.isError) return undefined;
    const details = event.details as { error?: unknown; cleanupError?: unknown; turnStatus?: unknown } | undefined;
    if (!details || typeof details !== "object") return undefined;
    if (typeof details.error !== "string" && typeof details.cleanupError !== "string" && details.turnStatus !== "failed") return undefined;
    return { isError: true };
  });

  pi.registerMessageRenderer<SubagentCompletionPayload>(
    SUBAGENT_COMPLETION_MESSAGE,
    renderSubagentCompletion,
  );

  pi.on("message_start", (event) => {
    const message = event.message;
    if (message.role !== "custom" || message.customType !== SUBAGENT_COMPLETION_MESSAGE) return;
    const payload = message.details as SubagentCompletionPayload | undefined;
    if (!payload) return;
    const entries = "batch" in payload ? payload.batch : [payload];
    for (const entry of entries) {
      if (typeof entry.operationId === "string") live.remove(entry.operationId);
    }
  });

  pi.on("session_shutdown", async () => {
    live.dispose();
    await hub.requestShutdown();
  });
}

export default function subagentExtension(pi: ExtensionAPI): void {
  registerSubagentExtension(pi);
}
