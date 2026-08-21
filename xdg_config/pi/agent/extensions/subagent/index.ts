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
import { boundText, serializeSubagentResult } from "./output.ts";
import { createRuntimeHub, operationSnapshot, type RuntimeRecord } from "./runtime.ts";
import { createSdkSubagentController } from "./sdk-executor.ts";
import { stripModel } from "./protocol.ts";
import {
  renderSubagentCall,
  renderSubagentCompletion,
  renderSubagentResult,
  SUBAGENT_COMPLETION_MESSAGE,
  type SubagentCompletionDetails,
} from "./render.ts";
import type { SubagentControllerFactory, SubagentRunOptions } from "./protocol.ts";

interface SubagentExtensionOptions {
  agentDirectory?: string;
  controllerFactory?: SubagentControllerFactory;
  idFactory?: () => string;
  settingsPath?: string;
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
  const credentialEnvNames = options.authEnvAllowlist
    ?? process.env.PI_SUBAGENT_AUTH_ENV_ALLOWLIST?.split(",").map((name) => name.trim()).filter(Boolean);
  const sdkConfig = {
    agentDir: getAgentDir(),
    sessionRoot: join(getAgentDir(), "subagent-sessions"),
    ...(credentialEnvNames && credentialEnvNames.length > 0 ? { credentialEnvNames } : {}),
  };
  const controllerFactory = options.controllerFactory
    ?? ((initial: SubagentRunOptions) => createSdkSubagentController(initial, sdkConfig));
  const idFactory = options.idFactory ?? randomUUID;
  const notifySettled = (details: SubagentCompletionDetails): void => {
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
  const hub = createRuntimeHub({ controllerFactory, idFactory, notifySettled });
  const runtimeSnapshot = (runtime: RuntimeRecord) => hub.snapshot(runtime);
  const closeRuntime = (runtime: RuntimeRecord, suppressNotification = false): Promise<void> =>
    hub.closeRuntime(runtime, suppressNotification);
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

  const operationResponse = (operation: OperationRecord, runtime?: RuntimeRecord) => {
    if (operation.result) {
      const elapsedMs = operation.startedAt !== undefined && operation.finishedAt !== undefined
        ? operation.finishedAt - operation.startedAt
        : undefined;
      const enriched = {
        ...operation.result,
        ...(runtime?.agent.model ? { model: stripModel(runtime.agent.model) } : {}),
        ...(runtime?.agent.thinking ? { thinking: runtime.agent.thinking } : {}),
        ...(elapsedMs === undefined ? {} : { elapsedMs }),
      };
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
      `Delegate bounded work to a registered user-defined Pi child with fresh isolated context and only its declared tools. Mandatory routing exceptions to direct parent work: when the user asks for an independent, fresh-eyes, or second-opinion review and a matching agent is registered, invoke it before reading or reviewing the target; parent self-review cannot satisfy independence. Likewise, delegate external research requiring multiple searches, freshness checks, or source assessment before loading a parent research workflow or making parent web searches; use this instead of chaining multiple parent web searches. Other strong uses are multi-file discovery, one specific high-impact decision, and separately owned implementation; default to delegation for implementation-class work (multi-file reads, cross-file impact analysis, batch edits, test runs, refactors) and keep only simple lookups, localized single-file edits, and routine validation direct. After a successful cited read-only handoff, synthesize it without repeating the same searches or reads; verify only decision-critical uncertainty or contradictions. Use one-shot runs by default; persistent runtimes support background completion, context-preserving follow-ups while idle, and guarded steering. The parent owns task decomposition, decisions, conflict avoidance, result review, integration, and final verification.\n\n${startupCatalog}`,
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
    renderResult: renderSubagentResult,
    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      if (params.action === "list") {
        registry = discoverEffectiveAgents();
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
        const runtime = hub.get(params.id);
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
            hub.isShuttingDown()
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
            task: params.message,
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
        return response({ error: "Subagent capacity unavailable: maxConcurrentRuns is 3." }, true);
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
        workOrder: createWorkOrder(params.task, cwd, projectGuidance),
        runId,
        operationId,
        parentSessionId,
        deadlineMs: params.deadlineMs!,
        signal,
      };
      const runtime = hub.createRuntime({ agent, cwd, parentSessionId, projectGuidance, initialOptions });
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
        if (hub.isShuttingDown() || runtime.state !== "starting") {
          throw new Error("Subagent runtime closed before its initial operation was accepted");
        }
        const operation = await hub.beginOperation(runtime, {
          operationId,
          task: params.task,
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

  pi.on("session_shutdown", () => hub.requestShutdown());
}

export default function subagentExtension(pi: ExtensionAPI): void {
  registerSubagentExtension(pi);
}
