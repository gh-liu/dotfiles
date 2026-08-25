import { randomUUID } from "node:crypto";
import { join, resolve } from "node:path";

import { getAgentDir, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

import {
  applyAgentOverrides,
  discoverUserAgents,
  formatAgentCatalog,
  loadSubagentOverrides,
  type AgentDiscovery,
} from "./agents.ts";
import { createWorkOrder, findAllowedRoot, loadProjectGuidance, resolveChildCwd } from "./context.ts";
import { createLiveUi } from "./live-ui.ts";
import { boundText, modelSubagentHandoff, serializeSubagentResult } from "./output.ts";
import { createRuntimeHub, operationSnapshot, type OperationRecord, type RuntimeRecord } from "./runtime.ts";
import { createSdkSubagentController } from "./sdk-executor.ts";
import { stripModel } from "./protocol.ts";
import {
  renderSubagentCall,
  renderSubagentCompletion,
  renderSubagentResult,
  SUBAGENT_COMPLETION_MESSAGE,
  type SubagentCompletionDetails,
  type SubagentCompletionPayload,
} from "./render.ts";
import type { SubagentControllerFactory, SubagentRunOptions } from "./protocol.ts";

export interface SubagentExtensionOptions {
  agentDirectory?: string;
  /** Additional environment variables whose values must be redacted from child output. */
  authEnvAllowlist?: readonly string[];
  controllerFactory?: SubagentControllerFactory;
  idFactory?: () => string;
  settingsPath?: string;
}

const deadline = () => Type.Optional(Type.Integer({
  minimum: 1_000,
  maximum: 3_600_000,
  description: "Required for run/start: execution deadline (1,000-3,600,000 ms)",
}));

const COMPLETION_WAKE_FIRST_LINE_MAX_CHARACTERS = 160;
const AUTH_ENV_NAME = /^[A-Z_][A-Z0-9_]*$/;
export function validateAuthEnvAllowlist(names: readonly string[] | undefined): string[] | undefined {
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

export function buildWakeWordSnippet(registry: AgentDiscovery): string {
  const names = registry.agents.map((agent) => agent.name);
  const registered = names.length > 0 ? names.join(", ") : "none";
  return boundText(
    `Delegate suitable bounded work to registered agents (${registered}); use the startup catalog directly and do not call list before a known agent. Keep simple lookups, localized edits, routine check reruns, and single-source fact checks in the parent.`,
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
  ], { description: "Lifecycle action" }),
  agent: Type.Optional(Type.String({ description: "run/start agent name" })),
  task: Type.Optional(Type.String({ minLength: 1, description: "run/start self-contained task" })),
  cwd: Type.Optional(Type.String({
    description: "run/start child cwd under the project root; defaults to parent cwd",
  })),
  id: Type.Optional(Type.String({ minLength: 1, description: "Runtime ID for lifecycle actions" })),
  mode: Type.Optional(Type.Union([
    Type.Literal("follow_up"),
    Type.Literal("steer"),
  ], { description: "Required by send" })),
  message: Type.Optional(Type.String({ minLength: 1, description: "Required by send" })),
  operationId: Type.Optional(Type.String({
    minLength: 1,
    description: "wait operation ID; omit id and operationId to join all background work",
  })),
  expectedOperationId: Type.Optional(Type.String({
    minLength: 1,
    description: "interrupt/steer operation guard",
  })),
  deadlineMs: deadline(),
  timeoutMs: Type.Optional(Type.Integer({ minimum: 1, maximum: 3_600_000, description: "Optional wait timeout" })),
});

export { loadSubagentOverrides };

export function registerSubagentExtension(pi: ExtensionAPI, options: SubagentExtensionOptions = {}): void {
  const agentDirectory = options.agentDirectory ?? join(getAgentDir(), "agents");
  const settingsPath = options.settingsPath ?? join(getAgentDir(), "settings.json");
  const loadedOverrides = loadSubagentOverrides(settingsPath);
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
  const configuredAuthEnvNames = options.authEnvAllowlist
    ?? (authEnvSetting?.trim()
      ? authEnvSetting.split(",")
      : undefined);
  const credentialEnvNames = validateAuthEnvAllowlist(configuredAuthEnvNames);
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
      const reference = typeof details.index === "number" ? `#${details.index}` : "#?";
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
      const availability = details.runtimeStatus === "idle"
        ? `  idle · status/follow-up/close ${reference}`
        : details.runtimeStatus === "running"
          ? `  running · status ${reference}`
          : `  crashed · status/close ${reference}`;
      return [
        title ? `${firstLine} — ${title}` : firstLine,
        availability,
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
        runId: details.runId,
        operationId: details.operationId,
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
  const hub = createRuntimeHub({ controllerFactory, idFactory, notifySettled, logSettled, live });
  /** Accepts a full runId or a short session-local index ("#2" / "2"). */
  const resolveRuntimeRef = (ref: string): RuntimeRecord | undefined => {
    const exact = hub.get(ref);
    if (exact) return exact;
    const parsed = /^#?(\d+)$/.exec(ref.trim());
    return parsed ? hub.listRuntimes().find((entry) => entry.index === Number(parsed[1])) : undefined;
  };
  const runtimeSnapshot = (runtime: RuntimeRecord) => hub.snapshot(runtime);
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
      ...operation.result,
      ...(runtime.agent.model ? { model: stripModel(runtime.agent.model) } : {}),
      ...(runtime.agent.thinking ? { thinking: runtime.agent.thinking } : {}),
      ...(elapsedMs === undefined ? {} : { elapsedMs }),
      // The runtime, not child-provided result data, owns this session-local index.
      index: runtime.index,
    };
  };

  const operationResponse = (operation: OperationRecord, runtime: RuntimeRecord) => {
    const enriched = settledOperationDetails(operation, runtime);
    if (enriched) {
      return {
        content: [{ type: "text" as const, text: serializeSubagentResult(enriched) }],
        details: enriched,
        isError: enriched.status === "failed",
      };
    }
    return response({
      ...operationSnapshot(operation),
      error: operation.error ?? "Subagent operation failed",
      index: runtime.index,
    }, true);
  };

  /** Join every currently-running background operation; fork-join for the background mode. */
  const joinOutstandingBackgroundOperations = async (timeoutMs?: number) => {
    const targets: Array<{ runtime: RuntimeRecord; operation: OperationRecord }> = [];
    for (const entry of hub.listRuntimes()) {
      const op = entry.activeOperationId !== undefined ? entry.operations.get(entry.activeOperationId) : undefined;
      if (entry.mode === "background" && op?.accepted && op.state === "running") {
        targets.push({ runtime: entry, operation: op });
      }
    }
    if (targets.length === 0) {
      return response({ results: [], reason: "no outstanding background operations" });
    }
    let timedOut = false;
    if (timeoutMs === undefined) {
      await Promise.all(targets.map((target) => target.operation.settled));
    } else {
      timedOut = !(await Promise.race([
        Promise.all(targets.map((target) => target.operation.settled)).then(() => true),
        new Promise<false>((resolveTimeout) => {
          setTimeout(() => resolveTimeout(false), timeoutMs);
        }),
      ]));
    }
    const settledTargets = targets
      .filter((target) => target.operation.state !== "running")
      .map((target) => ({
        response: operationResponse(target.operation, target.runtime),
        settled: settledOperationDetails(target.operation, target.runtime),
      }));
    const timeoutDetails = timedOut
      ? { partial: true, reason: "timeout reached; still-running operations are omitted" }
      : {};
    return response({
      results: settledTargets.map((target) => target.response.details),
      ...timeoutDetails,
    }, false, {
      results: settledTargets.map((target) => target.settled
        ? modelSubagentHandoff(target.settled)
        : target.response.details),
      ...timeoutDetails,
    });
  };

  pi.registerTool({
    name: "subagent",
    label: "Subagent",
    description:
      `Delegate bounded work to fresh-context registered agents; context isolation is not a security sandbox. Select by the startup catalog and call list only to refresh or diagnose it. run is one-shot; start creates a persistent runtime controlled by status/wait/send/interrupt/close, and idle runtimes retain a slot. The parent owns decomposition, write coordination, handoff review, integration, and final verification.\n\nStartup catalog:\n${startupCatalog}`,
    promptSnippet: wakeSnippet,
    promptGuidelines: [
      "Before delegating, decompose the bounded work rather than forwarding the raw user prompt. Because the child has fresh context, every task must include: Outcome, Scope, Starting evidence, Known decisions, Constraints and non-goals, Acceptance criteria, Validation, and Handoff. The parent retains unresolved decomposition and synthesis.",
      "Choose by the catalog's capabilities. Use run for one-shots and always supply a required task-appropriate deadlineMs; use start only for background or follow-up work, guard steer/interrupt with the active operation ID, and close persistent runtimes. Children load no skills, so include any needed skill path or excerpt. Run at most three independent one-shots in parallel, with no overlapping parent/child or child/child writes; wait for prerequisites before dependent work.",
      "Treat results as handoffs, not proof. For cited read-only work, verify only decision-critical uncertainty instead of repeating the same reads/searches. For writes, inspect the complete settled diff and run integrated validation. After failed/crashed/interrupted work, call status; the parent MUST NOT read transcript.sessionPath. If retrying, pass that path as Starting evidence and require the child to read it first. Produce the final synthesis yourself.",
    ],
    executionMode: "parallel",
    parameters: SubagentParameters,
    renderCall: (args, theme, context) => {
      if ((args as { action?: string }).action === "run" || (args as { action?: string }).action === "start") {
        const typed = args as { action: "run" | "start"; agent: string; model?: string; thinking?: string };
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
    renderResult: (result, renderOptions, theme, context) => renderSubagentResult(
      result as unknown as Parameters<typeof renderSubagentResult>[0],
      renderOptions,
      theme,
      context as unknown as Parameters<typeof renderSubagentResult>[3],
    ),
    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      if (ctx.hasUI) live.attach(ctx.ui);
      if (params.action === "list") {
        registry = discoverEffectiveAgents();
        const catalog = boundText(
          formatAgentCatalog(registry),
          { maxCharacters: 16_000, maxLines: 196 },
        );
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
        : !params.id && params.action !== "status" && params.action !== "wait"
          ? "id"
          : params.action === "wait" && params.id && !params.operationId
            ? "operationId"
          : params.action === "send"
            ? (!params.mode ? "mode" : !params.message ? "message" : params.mode === "steer" && !params.expectedOperationId ? "expectedOperationId" : undefined)
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
        if (!params.id) {
          // id-less forms operate across every runtime: enumerate, or join all
          // outstanding background work (fork-join for the background mode).
          if (params.action === "status") {
            return response({ runtimes: hub.listRuntimes().map((entry) => runtimeSnapshot(entry)) });
          }
          return joinOutstandingBackgroundOperations(params.timeoutMs);
        }
        const runtime = resolveRuntimeRef(params.id);
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
          const expectedOperationId = params.expectedOperationId!;
          const operation = runtime.operations.get(expectedOperationId);
          if (
            runtime.state !== "running"
            || runtime.activeOperationId !== expectedOperationId
            || !operation?.accepted
          ) {
            return response({ accepted: false, conflict: true, snapshot: runtimeSnapshot(runtime) });
          }
          const accepted = await runtime.controller!.interrupt(expectedOperationId);
          return response({ accepted, snapshot: runtimeSnapshot(runtime) });
        }
        if (params.action === "send" && params.mode === "steer") {
          const expectedOperationId = params.expectedOperationId!;
          const operation = runtime.operations.get(expectedOperationId);
          if (
            hub.isShuttingDown()
            || runtime.state !== "running"
            || runtime.activeOperationId !== expectedOperationId
            || !operation?.accepted
          ) {
            return response({ accepted: false, conflict: true, snapshot: runtimeSnapshot(runtime) });
          }
          try {
            const accepted = await runtime.controller!.steer(expectedOperationId, params.message!);
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
          const operationId = params.operationId!;
          const operation = runtime.operations.get(operationId);
          if (!operation) {
            return response({ error: `Unknown operation ${operationId} for runtime ${runtime.runId}` }, true);
          }
          if (operation.state === "running") {
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

        if (hub.isShuttingDown()) return response({ error: "Subagent runtime is shutting down" }, true);
        if (runtime.state !== "idle") {
          return response({
            accepted: false,
            conflict: true,
            error: "Runtime cannot accept a follow-up",
            snapshot: runtimeSnapshot(runtime),
          }, true);
        }
        const operationId = idFactory();
        try {
          await hub.beginOperation(runtime, {
            operationId,
            task: params.message!,
            deadlineMs: params.deadlineMs ?? 600_000,
            notifyOnSettle: true,
            signal,
            onUpdate,
          });
          return response({ ...runtimeSnapshot(runtime), operationId });
        } catch (error) {
          return response({ ...runtimeSnapshot(runtime), error: error instanceof Error ? error.message : String(error) }, true);
        }
      }

      if (hub.isShuttingDown()) {
        return response({ error: "Subagent runtime is shutting down; new runs are rejected." }, true);
      }
      const agent = registry.agents.find((candidate) => candidate.name === params.agent);
      if (!agent) {
        const available = registry.agents.map((candidate) => candidate.name).join(", ") || "none";
        const invalid = registry.errors.find((error) => error.filePath.endsWith(`/${params.agent}.md`));
        return {
          content: [{
            type: "text" as const,
            text: invalid
              ? `Agent definition is invalid: ${invalid.error}`
              : `Unknown user agent: ${params.agent}. Available agents: ${available}.`,
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
          runtimes: hub.listRuntimes().map((runtime) => ({
            index: runtime.index,
            agent: runtime.agent.name,
            status: runtime.state,
          })),
        }, true);
      }

      const allowedRoot = findAllowedRoot(ctx.cwd);
      const cwd = resolveChildCwd(allowedRoot, resolve(ctx.cwd, params.cwd ?? "."));
      const parentSessionId = ctx.sessionManager.getSessionId();
      const projectGuidance = loadProjectGuidance(allowedRoot, cwd);
      const runId = idFactory();
      const operationId = idFactory();
      const initialOptions: SubagentRunOptions = {
        cwd,
        agent,
        workOrder: createWorkOrder(params.task!, cwd, projectGuidance),
        runId,
        operationId,
        parentSessionId,
        deadlineMs: params.deadlineMs!,
        signal,
      };
      const runtime = hub.createRuntime({
        agent,
        cwd,
        parentSessionId,
        projectGuidance,
        mode: params.action === "start" ? "background" : "foreground",
        initialOptions,
      });
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
            index: runtime.index,
          },
        });
        runtime.controller = await runtime.controllerReady;
        if (hub.isShuttingDown() || runtime.state !== "starting") {
          throw new Error("Subagent runtime closed before its initial operation was accepted");
        }
        const operation = await hub.beginOperation(runtime, {
          operationId,
          task: params.task!,
          deadlineMs: params.deadlineMs!,
          notifyOnSettle: params.action === "start",
          signal,
          onUpdate,
        });
        if (params.action === "start") return response({ ...runtimeSnapshot(runtime), operationId });
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

  pi.on("session_shutdown", () => {
    live.dispose();
    return hub.requestShutdown();
  });
}

export default function subagentExtension(pi: ExtensionAPI): void {
  registerSubagentExtension(pi);
}
