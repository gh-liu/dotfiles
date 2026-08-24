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
import { boundText, serializeSubagentResult } from "./output.ts";
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

const COMPLETION_WAKE_FIRST_LINE_MAX_CHARACTERS = 160;

export const WAKE_BINDINGS = [
  { role: "reviewer", hint: "independent/fresh-eyes/second-opinion review" },
  { role: "researcher", hint: "multi-source freshness/source-assessment research" },
  { role: "tester", hint: "exploratory QA/browser testing" },
  { role: "scout", hint: "multi-file discovery" },
  { role: "oracle", hint: "high-impact unresolved decision" },
  { role: "worker", hint: "batch/settled-spec implementation" },
] as const;

export function buildWakeWordSnippet(registry: AgentDiscovery): string {
  const present = new Set(registry.agents.map((agent) => agent.name));
  const parts = WAKE_BINDINGS.filter((binding) => present.has(binding.role)).map(
    (binding) => `${binding.hint}->${binding.role}`,
  );
  const routing = parts.length > 0 ? `${parts.join("; ")}; ` : "";
  return `Classify by task boundary before equivalent parent read/search/browser: ${routing}keep single-file lookups, localized single-file edits, routine re-runs of existing checks, single-source factual checks direct; default to startup catalog, call list only if catalog may be stale, no suitable role, or diagnosis needed`;
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
  const wakeSnippet = buildWakeWordSnippet(registry);
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

  const operationResponse = (operation: OperationRecord, runtime: RuntimeRecord) => {
    if (operation.result) {
      const elapsedMs = operation.startedAt !== undefined && operation.finishedAt !== undefined
        ? operation.finishedAt - operation.startedAt
        : undefined;
      const enriched = {
        ...operation.result,
        ...(runtime.agent.model ? { model: stripModel(runtime.agent.model) } : {}),
        ...(runtime.agent.thinking ? { thinking: runtime.agent.thinking } : {}),
        ...(elapsedMs === undefined ? {} : { elapsedMs }),
        // The runtime, not child-provided result data, owns this session-local index.
        index: runtime.index,
      };
      return {
        content: [{ type: "text" as const, text: serializeSubagentResult(enriched) }],
        details: enriched,
        isError: operation.result.status === "failed",
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
    const results = targets
      .filter((target) => target.operation.state !== "running")
      .map((target) => operationResponse(target.operation, target.runtime).details);
    return response({
      results,
      ...(timedOut ? { partial: true, reason: "timeout reached; still-running operations are omitted" } : {}),
    });
  };

  pi.registerTool({
    name: "subagent",
    label: "Subagent",
    description:
      `Delegate bounded work to a registered child with fresh isolated context and only its declared tools. Each agent's description in the catalog below is its routing contract; the wake snippet lists current delegations for the registry. Classify by task boundary before doing equivalent parent reads, searches, or browser work. Keep single-file lookups, localized single-file edits, routine re-runs of existing checks (not exploratory app testing), and single-source factual checks direct. After a successful cited read-only handoff, synthesize without repeating the same searches or reads; verify only decision-critical uncertainty or contradictions. The parent owns task decomposition, conflict avoidance, result review, integration, and final verification. Use one-shot run by default; use start for background, then status/wait/send/close — an open runtime retains its slot while idle and settled background work announces via a follow-up card. status without id lists all runtimes; wait without operationId joins outstanding background work. Default to the startup catalog; call list only when the catalog may be stale, no suitable role matches, or diagnosis is needed.\n\n${startupCatalog}`,
    promptSnippet: wakeSnippet,
    promptGuidelines: [
      "Default to the startup catalog in the tool description — the wake snippet reflects the current registry, not a fixed roster; call list only when the catalog may be stale, no suitable role matches, or you need to diagnose discovery.",
      "Classify by task boundary before doing equivalent parent reads, searches, or browser automation: keep single-file lookups (use read, not bash), localized single-file edits, routine re-runs of existing checks or test suites, and single-source factual checks direct; otherwise consider delegation when a matching registered role materially improves quality, parallelism, fresh-context independence, or parent-context isolation.",
      "Before calling subagent, decompose the bounded work instead of forwarding the raw user prompt. Every task must be self-contained (the child has fresh context) and carry these labels: Outcome, Scope, Starting evidence, Known decisions, Constraints and non-goals, Acceptance criteria, Validation, and Handoff — never silently omit one. Do not delegate unresolved decomposition or synthesis that the parent still owns.",
      "Choose a registered agent whose catalog description and declared capabilities match the bounded task; treat the discovered definition as the source of truth. Use action:run for bounded one-shots with a task-appropriate deadlineMs (1,000-3,600,000 ms); use action:start only for background or follow-up work, steer only the guarded active operation, and close persistent runtimes when finished. Child sessions never load skills; when one needs a skill's knowledge, put the skill file path (e.g. ~/.pi/agent/skills/<name>/SKILL.md) or the needed excerpt directly in the task text.",
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
      if (ctx.hasUI) live.attach(ctx.ui);
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
        : !params.id && params.action !== "status" && params.action !== "wait"
          ? "id"
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

  pi.on("session_shutdown", () => {
    live.dispose();
    return hub.requestShutdown();
  });
}

export default function subagentExtension(pi: ExtensionAPI): void {
  registerSubagentExtension(pi);
}
