import { randomUUID } from "node:crypto";
import { join, resolve } from "node:path";

import { getAgentDir, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type, type Static } from "typebox";

import {
  applyAgentOverrides,
  discoverUserAgents,
  formatAgentCatalog,
  loadSettingsDefaults,
  loadSubagentOverrides,
  resolveAgentModel,
  type AgentDiscovery,
} from "./agents.ts";
import { createWorkOrder, findAllowedRoot, loadProjectGuidance, resolveChildCwd } from "./context.ts";
import { createLiveUi } from "./live-ui.ts";
import { boundText, modelSubagentHandoff, serializeSubagentResult } from "./output.ts";
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
}

function retainCallTitleDetails(
  result: SubagentRenderResult,
  context: SubagentRenderContext,
): void {
  if (context.args.action !== "run") return;
  const details = result.details && typeof result.details === "object"
    ? result.details as Record<string, unknown>
    : {};
  const model = typeof details.model === "string" ? details.model : undefined;
  const thinking = typeof details.thinking === "string" ? details.thinking : undefined;
  let changed = false;
  if (model !== undefined && context.state.model !== model) {
    context.state.model = model;
    changed = true;
  }
  if (thinking !== undefined && context.state.thinking !== thinking) {
    context.state.thinking = thinking;
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

const deadline = () => Type.Optional(Type.Integer({
  minimum: 1_000,
  maximum: 3_600_000,
  description: "Required for run: execution deadline (1,000-3,600,000 ms)",
}));

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

export function buildWakeWordSnippet(registry: AgentDiscovery): string {
  const names = registry.agents.map((agent) => agent.name);
  const registered = names.length > 0 ? names.join(", ") : "none";
  return boundText(
    `Prefer delegation to registered agents (${registered}) using the startup catalog, especially for multi-file discovery, implementation, independent review, browser QA, and multi-source research. Keep only exact lookups, one-source fact checks, and command reruns requiring no investigation in the parent. The parent owns decomposition, coordination, integration, and final verification.`,
    { maxCharacters: 1_000, maxLines: 1 },
  );
}

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
const SubagentParameters = Type.Object({
  action: Type.Union([
    Type.Literal("run"),
    Type.Literal("get"),
    Type.Literal("cancel"),
  ], { description: "Task action" }),
  agent: Type.Optional(Type.String({ description: "run agent name" })),
  objective: Type.Optional(Type.String({ minLength: 1, description: "run objective" })),
  scope: Type.Optional(Type.Array(Type.String())),
  constraints: Type.Optional(Type.Array(Type.String())),
  acceptance: Type.Optional(Type.Array(Type.String())),
  context: Type.Optional(Type.String()),
  background: Type.Optional(Type.Boolean({ description: "Return a jobId immediately; default false" })),
  cwd: Type.Optional(Type.String({
    description: "run child cwd under the project root; defaults to parent cwd",
  })),
  jobId: Type.Optional(Type.String({ minLength: 1, description: "Canonical jobId, session-local #N alias, or numeric N for get/cancel; omit for recent jobs" })),
  deadlineMs: deadline(),
  waitMs: Type.Optional(Type.Integer({ minimum: 0, maximum: 3_600_000, description: "Maximum get wait" })),
});
type SubagentParameters = Static<typeof SubagentParameters>;

export { loadSubagentOverrides };

export function registerSubagentExtension(pi: ExtensionAPI, options: SubagentExtensionOptions = {}): void {
  const agentDirectory = options.agentDirectory ?? join(getAgentDir(), "agents");
  const settingsPath = options.settingsPath ?? join(getAgentDir(), "settings.json");
  const loadedOverrides = loadSubagentOverrides(settingsPath);
  const settingsDefaults = loadSettingsDefaults(settingsPath);
  const discoverEffectiveAgents = () => {
    const discovery = discoverUserAgents(agentDirectory);
    return applyAgentOverrides({
      agents: discovery.agents,
      errors: [...discovery.errors, ...loadedOverrides.errors],
    }, loadedOverrides.overrides);
  };
  let registry = discoverEffectiveAgents();
  const startupCatalog = boundText(formatAgentCatalog(registry), { maxCharacters: 16_000, maxLines: 200 });
  const wakeSnippet = buildWakeWordSnippet(registry);
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
  const notifySettled = (payload: SubagentCompletionPayload): void => {
    const entries = "batch" in payload ? payload.batch : [payload];
    const blocks = entries.map((details) => {
      const reference = details.ref;
      const elapsed = typeof details.elapsedMs === "number"
        ? ` · ${Math.max(0, Math.ceil(details.elapsedMs / 1000))}s`
        : "";
      const firstLine = `${reference} ${details.agent} · ${details.status}${elapsed}`;
      const rawTitle = completionWakeTitle(details.task);
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
    const content = boundText(header + blocks.join("\n\n"), { maxCharacters: 16_000, maxLines: 96 });
    try {
      pi.sendMessage<SubagentCompletionPayload>({
        customType: SUBAGENT_COMPLETION_MESSAGE,
        content,
        display: true,
        details: payload,
      }, { triggerTurn: true, deliverAs: "followUp" });
    } catch {
      // Notification delivery must not change authoritative operation state.
    }
  };
  const logSettled = (details: SubagentCompletionDetails): void => {
    try {
      // Durable human-visible audit trail; never rendered into the model context.
      pi.appendEntry("subagent-settle-log", {
        jobId: details.jobId,
        agent: details.agent,
        status: details.status,
        elapsedMs: details.elapsedMs ?? null,
        taskPrefix: boundText(details.task, { maxCharacters: 120, maxLines: 1 }),
      });
    } catch {
      // The settle log is best-effort; never affect operation state.
    }
  };
  const live = createLiveUi();
  const hub = createRuntimeHub({
    controllerFactory,
    idFactory,
    notifySettled,
    logSettled,
    live,
    ...(options.controllerCreationTimeoutMs === undefined ? {} : {
      controllerCreationTimeoutMs: options.controllerCreationTimeoutMs,
    }),
  });
  const closeRuntime = (runtime: RuntimeRecord, suppressNotification = false): Promise<void> =>
    hub.closeRuntime(runtime, suppressNotification);
  const response = (details: unknown, isError = false, modelDetails: unknown = details) => {
    const serialized = JSON.stringify(modelDetails);
    const bounded = serialized.length <= 32_000
      ? serialized
      : JSON.stringify({ error: "Subagent response exceeded the parent serialization limit", truncated: true });
    return {
      content: [{ type: "text" as const, text: bounded }],
      details,
      ...(isError ? { isError: true } : {}),
    };
  };

  const settledOperationDetails = (operation: OperationRecord, runtime: RuntimeRecord) => {
    if (!operation.result) return undefined;
    const elapsedMs = operation.startedAt !== undefined && operation.finishedAt !== undefined
      ? operation.finishedAt - operation.startedAt
      : undefined;
    return {
      agent: operation.result.agent,
      status: operation.result.status,
      summary: operation.result.summary,
      transcript: operation.result.transcript,
      ...(runtime.agent.model ? { model: stripModel(runtime.agent.model) } : {}),
      ...(runtime.agent.thinking ? { thinking: runtime.agent.thinking } : {}),
      ...(elapsedMs === undefined ? {} : { elapsedMs }),
    };
  };

  const operationResponse = (operation: OperationRecord, runtime: RuntimeRecord) => {
    const enriched = settledOperationDetails(operation, runtime);
    if (enriched) {
      const handoff = modelSubagentHandoff(enriched);
      return {
        content: [{ type: "text" as const, text: serializeSubagentResult(enriched) }],
        details: { ...handoff, ref: `#${runtime.index}` },
        isError: enriched.status === "failed",
      };
    }
    return response({ jobId: runtime.runId, status: "failed", error: operation.error ?? "Subagent operation failed" }, true);
  };

  pi.registerTool({
    name: "subagent",
    label: "Subagent",
    description:
      `Delegate bounded work to fresh-context registered agents. Fresh context is not a security sandbox, and cwd is not a filesystem sandbox. run executes foreground or background; get reads/waits for jobs; cancel is idempotent. get/cancel accept canonical jobId, session-local #N, or numeric N (exact jobId wins). The parent owns decomposition, write coordination, handoff review, integration, and final verification.\n\nstartup catalog:\n${startupCatalog}`,
    promptSnippet: wakeSnippet,
    promptGuidelines: [
      "Before delegating, decompose the bounded work rather than forwarding the raw user prompt. Because the child has fresh context, every task must include: Outcome, Scope, Starting evidence, Known decisions, Constraints and non-goals, Acceptance criteria, Validation, and Handoff. The parent retains unresolved decomposition and synthesis.",
      "Choose by the catalog's capabilities. Use run with a task-appropriate deadlineMs; set background only for independent work and recover its result with get. Children load no skills, so include any needed skill path or excerpt. Run at most three independent jobs in parallel, with no overlapping writes.",
      "Treat results as handoffs, not proof. For cited read-only work, verify only decision-critical uncertainty instead of repeating the same reads/searches. For writes, inspect the complete settled diff and run integrated validation. Recover completed/failed/crashed/interrupted background outcomes with get(\"#N\") (get/cancel also accept numeric N or canonical jobId; aliases are session-local). The parent MUST NOT read transcript.sessionPath. If retrying, pass that path as Starting evidence and require the child to read it first. Produce the final synthesis yourself.",
    ],
    executionMode: "parallel",
    parameters: SubagentParameters,
    renderCall: (args, theme, context) => {
      if ((args as { action?: string }).action === "run") {
        const typed = args as { action: "run"; agent: string; model?: string; thinking?: string };
        if (typed.agent && typed.model === undefined && typed.thinking === undefined) {
          const found = registry.agents.find((candidate) => candidate.name === typed.agent);
          if (found) {
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
      const request = input as SubagentParameters;
      const publicJob = (runtime: RuntimeRecord) => {
        const operation = runtime.lastSettled
          ?? (runtime.activeOperationId ? runtime.operations.get(runtime.activeOperationId) : undefined);
        return {
          jobId: runtime.runId,
          ref: `#${runtime.index}`,
          status: operation?.state ?? (runtime.state === "crashed" ? "failed" : "running"),
          agent: runtime.agent.name,
          ...(operation?.result ? { handoff: modelSubagentHandoff(operation.result) } : {}),
          ...(operation?.error ? { error: boundText(operation.error, { maxCharacters: 2_000, maxLines: 20 }) } : {}),
        };
      };
      if (request.action === "get") {
        if (!request.jobId) {
          return response({ jobs: hub.listRuntimes().slice(-100).reverse().map(publicJob) });
        }
        const runtime = hub.resolve(request.jobId);
        if (!runtime) return response({ error: `Unknown subagent job: ${request.jobId}` }, true);
        const operation = runtime.activeOperationId ? runtime.operations.get(runtime.activeOperationId) : runtime.lastSettled;
        if (operation?.state === "running" && request.waitMs !== undefined && request.waitMs > 0) {
          let timedOut = false;
          let timer: ReturnType<typeof setTimeout> | undefined;
          await Promise.race([
            operation.settled,
            new Promise<void>((resolveTimeout) => { timer = setTimeout(() => { timedOut = true; resolveTimeout(); }, request.waitMs); }),
          ]);
          if (timer) clearTimeout(timer);
          if (timedOut && operation.state === "running") return response({ ...publicJob(runtime), timedOut: true });
        }
        return response(publicJob(runtime));
      }
      if (request.action === "cancel") {
        if (!request.jobId) return response({ error: "jobId is required for subagent cancel" }, true);
        const runtime = hub.resolve(request.jobId);
        if (!runtime) return response({ jobId: request.jobId, cancelled: false, alreadyTerminal: true });
        const operation = runtime.activeOperationId ? runtime.operations.get(runtime.activeOperationId) : undefined;
        if (!operation || operation.state !== "running" || !operation.accepted) {
          return response({ ...publicJob(runtime), cancelled: false, alreadyTerminal: true });
        }
        try {
          const accepted = await runtime.controller!.interrupt(operation.operationId);
          if (accepted) await operation.settled;
          await closeRuntime(runtime, true);
          return response({ ...publicJob(runtime), cancelled: accepted });
        } catch (error) {
          await closeRuntime(runtime, true).catch(() => {});
          return response({ jobId: runtime.runId, ref: `#${runtime.index}`, status: "failed", cancelled: false, error: boundText(error instanceof Error ? error.message : String(error), { maxCharacters: 2_000, maxLines: 20 }) }, true);
        }
      }
      if (!request.agent) return response({ error: "agent is required for subagent run" }, true);
      if (!request.objective) return response({ error: "objective is required for subagent run" }, true);
      if (request.deadlineMs === undefined) return response({ error: "deadlineMs is required for subagent run" }, true);
      if (hub.isShuttingDown()) {
        return response({ error: "Subagent runtime is shutting down; new runs are rejected." }, true);
      }
      const agent = registry.agents.find((candidate) => candidate.name === request.agent);
      if (!agent) {
        const available = registry.agents.map((candidate) => candidate.name).join(", ") || "none";
        const invalid = registry.errors.find((error) => error.filePath.endsWith(`/${request.agent}.md`));
        return {
          content: [{
            type: "text" as const,
            text: invalid
              ? `Agent definition is invalid: ${invalid.error}`
              : `Unknown user agent: ${request.agent}. Available agents: ${available}.`,
          }],
          details: { discoveryErrors: registry.errors },
          isError: true,
        };
      }
      if (!hub.capacityAvailable()) {
        return response({
          error: "Subagent capacity unavailable: maxConcurrentRuns is 3.",
          maxConcurrentRuns: hub.maxConcurrentRuns,
          occupiedSlots: hub.occupiedSlots(),
          availableSlots: hub.availableSlots(),
          jobs: hub.listRuntimes().slice(-100).map(publicJob),
        }, true);
      }

      const allowedRoot = findAllowedRoot(ctx.cwd);
      const cwd = resolveChildCwd(allowedRoot, resolve(ctx.cwd, request.cwd ?? "."));
      const parentSessionId = ctx.sessionManager.getSessionId();
      const projectGuidance = loadProjectGuidance(allowedRoot, cwd);
      const runtimeAgent = agent.model ? agent : (() => {
        const model = resolveAgentModel(agent, settingsDefaults, mainModelOf(ctx.model));
        return model ? { ...agent, model } : agent;
      })();
      const runId = idFactory();
      const operationId = idFactory();
      const initialOptions: SubagentRunOptions = {
        cwd,
        agent: runtimeAgent,
        workOrder: createWorkOrder({
          objective: request.objective,
          scope: request.scope,
          constraints: request.constraints,
          acceptance: request.acceptance,
          context: request.context,
        }, cwd, projectGuidance),
        runId,
        operationId,
        parentSessionId,
        deadlineMs: request.deadlineMs,
        signal,
      };
      const runtime = hub.createRuntime({
        agent: runtimeAgent,
        cwd,
        parentSessionId,
        projectGuidance,
        mode: request.background === true ? "background-one-shot" : "foreground",
        initialOptions,
      });
      try {
        onUpdate?.({
          content: [{ type: "text", text: "Starting isolated child…" }],
          details: {
            jobId: runId,
            ref: `#${runtime.index}`,
            agent: runtimeAgent.name,
            ...(runtimeAgent.model ? { model: stripModel(runtimeAgent.model) } : {}),
            ...(runtimeAgent.thinking ? { thinking: runtimeAgent.thinking } : {}),
            status: "starting",
          },
        });
        runtime.controller = await runtime.controllerReady;
        if (hub.isShuttingDown() || runtime.state !== "starting") {
          throw new Error("Subagent runtime closed before its initial operation was accepted");
        }
        const operation = await hub.beginOperation(runtime, {
          operationId,
          task: request.objective,
          deadlineMs: request.deadlineMs,
          notifyOnSettle: request.background === true,
          workOrder: initialOptions.workOrder,
          signal,
          onUpdate,
        });
        if (request.background === true) return response({ jobId: runId, ref: `#${runtime.index}`, status: "running", agent: runtimeAgent.name });
        await operation.settled;
        await closeRuntime(runtime);
        return operationResponse(operation, runtime);
      } catch (error) {
        hub.markCrashed(runtime);
        try {
          await closeRuntime(runtime, true);
        } catch {
          // The original startup/operation failure is the actionable error.
        }
        return response({ jobId: runId, status: "failed", error: error instanceof Error ? error.message : String(error) }, true);
      }
    },
  });

  pi.registerMessageRenderer<SubagentCompletionDetails>(
    SUBAGENT_COMPLETION_MESSAGE,
    renderSubagentCompletion,
  );

  pi.on("session_shutdown", () => {
    live.dispose();
    return hub.requestShutdown();
  });
}

export default function subagentExtension(pi: ExtensionAPI): void {
  registerSubagentExtension(pi);
}
