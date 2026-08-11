import { randomUUID } from "node:crypto";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { getAgentDir, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

import { discoverUserAgents, type AgentDiscovery } from "./agents.ts";
import { findAllowedRoot, loadProjectGuidance, resolveChildCwd } from "./context.ts";
import { createJsonSubagentExecutor } from "./executor.ts";
import { boundText } from "./output.ts";
import { SubagentCancellationError } from "./protocol.ts";
import type {
  SubagentExecutor,
  SubagentResult,
  SubagentWorkOrder,
} from "./protocol.ts";

interface SubagentExtensionOptions {
  agentDirectory?: string;
  authEnvAllowlist?: string[];
  execute?: SubagentExecutor;
  idFactory?: () => string;
}

interface SubagentRenderState {
  spinnerFrame?: number;
  spinnerTimer?: ReturnType<typeof setInterval>;
}

const SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

const SubagentParameters = Type.Union([
  Type.Object({
    action: Type.Literal("list", { description: "Refresh and list registered user agents" }),
  }),
  Type.Object({
    action: Type.Literal("run", { description: "Run one foreground child agent" }),
    agent: Type.String({ description: "Canonical user agent name" }),
    task: Type.String({ minLength: 1, description: "Self-contained task delegated to the child" }),
    cwd: Type.Optional(Type.String({ description: "Child cwd under the parent's canonical project root" })),
    deadlineMs: Type.Optional(
      Type.Integer({ minimum: 1_000, maximum: 3_600_000, default: 300_000, description: "Execution deadline" }),
    ),
  }),
]);

function oneLine(text: string, maxCharacters = 120): string {
  const normalized = text.replace(/\s+/g, " ").trim();
  return normalized.length <= maxCharacters
    ? normalized
    : `${normalized.slice(0, maxCharacters - 1)}…`;
}

function resultText(result: { content: Array<{ type: string; text?: string }> }): string {
  return result.content.find((part) => part.type === "text")?.text ?? "";
}

function formatAgentCatalog(discovery: AgentDiscovery): string {
  const agents = discovery.agents.length === 0
    ? ["- none"]
    : discovery.agents.map((agent) => `- ${agent.name}: ${agent.description}`);
  const invalid = discovery.errors.length === 0
    ? []
    : [
      "",
      "Invalid agent definitions:",
      ...discovery.errors.map((error) => `- ${error.error}`),
    ];
  return boundText(
    ["Available registered agents:", ...agents, ...invalid].join("\n"),
    { maxCharacters: 16_000, maxLines: 200 },
  );
}

function createWorkOrder(
  task: string,
  cwd: string,
  projectGuidance: string[],
): SubagentWorkOrder {
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
  const agentDirectory = options.agentDirectory ?? join(getAgentDir(), "agents");
  let registry = discoverUserAgents(agentDirectory);
  const startupCatalog = formatAgentCatalog(registry);
  const authEnvAllowlist =
    options.authEnvAllowlist ??
    process.env.PI_SUBAGENT_AUTH_ENV_ALLOWLIST?.split(",").map((name) => name.trim()).filter(Boolean);
  const executeChild: SubagentExecutor =
    options.execute ??
    createJsonSubagentExecutor({
      piAgentDirectory: getAgentDir(),
      authEnvAllowlist,
      toolProviders: {
        web_search: {
          extensionPaths: [fileURLToPath(new URL("../websearch/index.ts", import.meta.url))],
          environmentVariables: ["EXA_API_KEY"],
        },
      },
    });
  const idFactory = options.idFactory ?? randomUUID;
  const active = new Set<AbortController>();
  const executions = new Map<AbortController, Promise<unknown>>();
  let shuttingDown = false;

  pi.registerTool({
    name: "subagent",
    label: "Subagent",
    description:
      `Run one registered user-defined Pi child with fresh isolated context and only its declared tools. Use the canonical registered agent name in the agent parameter. The parent remains responsible for coordination, decisions, integration, and verification.\n\n${startupCatalog}`,
    promptSnippet: "List registered agents or ask one to perform a bounded task in an isolated child",
    promptGuidelines: [
      "When the user names a registered agent and asks it to perform a task, call subagent with that agent name. Also use it when the user explicitly asks for a subagent or delegation.",
      "When the user requests delegation without naming an agent, list registered agents before choosing one.",
      "Run independent evidence-gathering agents such as scout and researcher in parallel when useful. Do not include oracle in that parallel batch when its decision depends on their findings; wait for those results, summarize the evidence and proposed direction in a self-contained oracle task, then call oracle.",
      "Give worker a self-contained approved direction, avoid concurrent parent writes while it runs, and inspect its changes and validation after it completes.",
      "After explicitly creating or changing an agent definition for the user, list registered agents to refresh the in-memory registry before running it.",
    ],
    executionMode: "parallel",
    parameters: SubagentParameters,
    renderCall(args, theme) {
      if (args.action === "list") return new Text(theme.fg("accent", "refresh agents"), 0, 0);
      let text = theme.fg("accent", theme.bold(args.agent || "unknown"));
      if (args.task) text += theme.fg("dim", ` — ${oneLine(args.task)}`);
      if (args.cwd) text += theme.fg("muted", ` (${args.cwd})`);
      return new Text(text, 0, 0);
    },
    renderResult(result, { expanded, isPartial }, theme, context) {
      const details = result.details as { agent?: string; status?: string; summary?: string } | undefined;
      const output = details?.summary ?? resultText(result);
      const preview = oneLine(output, 160);
      const state = context.state as SubagentRenderState;
      let text: string;
      if (isPartial) {
        state.spinnerFrame ??= 0;
        if (!state.spinnerTimer) {
          state.spinnerTimer = setInterval(() => {
            state.spinnerFrame = ((state.spinnerFrame ?? 0) + 1) % SPINNER_FRAMES.length;
            context.invalidate();
          }, 80);
          state.spinnerTimer.unref?.();
        }
        text = theme.fg("warning", SPINNER_FRAMES[state.spinnerFrame]);
      } else if (context.isError || details?.status === "failed") {
        if (state.spinnerTimer) clearInterval(state.spinnerTimer);
        state.spinnerTimer = undefined;
        text = theme.fg("error", "✗ Failed");
      } else {
        if (state.spinnerTimer) clearInterval(state.spinnerTimer);
        state.spinnerTimer = undefined;
        text = theme.fg("success", "✓ Completed");
      }

      if (expanded && output) {
        const lines = output.split("\n");
        for (const line of lines.slice(0, 20)) text += `\n${theme.fg("dim", line)}`;
        if (lines.length > 20) text += `\n${theme.fg("muted", "… output truncated in UI")}`;
      } else if (preview) {
        text += theme.fg("dim", ` — ${preview}`);
      }
      return new Text(text, 0, 0);
    },
    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      if (shuttingDown) {
        return {
          content: [{ type: "text", text: "Subagent runtime is shutting down; new runs are rejected." }],
          details: { shuttingDown: true },
          isError: true,
        };
      }
      if (params.action === "list") {
        registry = discoverUserAgents(agentDirectory);
        return {
          content: [{ type: "text", text: formatAgentCatalog(registry) }],
          details: {
            agents: registry.agents.map(({ name, description }) => ({ name, description })),
            discoveryErrors: registry.errors,
          },
        };
      }

      const snapshot = registry;
      const agent = snapshot.agents.find((candidate) => candidate.name === params.agent);
      if (!agent) {
        const available = snapshot.agents.map((candidate) => candidate.name).join(", ") || "none";
        const invalid = snapshot.errors.find((error) => error.filePath.endsWith(`/${params.agent}.md`));
        return {
          content: [
            {
              type: "text",
              text: invalid
                ? `Agent definition is invalid: ${invalid.error}`
                : `Unknown user agent: ${params.agent}. Available agents: ${available}.`,
            },
          ],
          details: { discoveryErrors: snapshot.errors },
          isError: true,
        };
      }
      if (active.size >= 3) {
        return {
          content: [{ type: "text", text: "Subagent capacity unavailable: maxConcurrentRuns is 3." }],
          details: { activeRuns: active.size, maxConcurrentRuns: 3 },
          isError: true,
        };
      }

      const allowedRoot = findAllowedRoot(ctx.cwd);
      const requestedCwd = resolve(ctx.cwd, params.cwd ?? ".");
      const cwd = resolveChildCwd(allowedRoot, requestedCwd);
      const runId = idFactory();
      const operationId = idFactory();
      const controller = new AbortController();
      const forwardAbort = () => controller.abort();
      if (signal?.aborted) controller.abort();
      else signal?.addEventListener("abort", forwardAbort, { once: true });

      active.add(controller);
      try {
        onUpdate?.({
          content: [{ type: "text", text: "Starting isolated child…" }],
          details: { runId, operationId, agent: agent.name, status: "running" },
        });
        const execution = executeChild({
          cwd,
          agent,
          workOrder: createWorkOrder(params.task, cwd, loadProjectGuidance(allowedRoot, cwd)),
          runId,
          operationId,
          parentSessionId: ctx.sessionManager.getSessionId(),
          deadlineMs: params.deadlineMs ?? 300_000,
          signal: controller.signal,
          onProgress: onUpdate
            ? (summary) =>
                onUpdate({
                  content: [{ type: "text", text: summary }],
                  details: { runId, operationId, agent: agent.name, status: "running" },
                })
            : undefined,
        });
        executions.set(controller, execution);
        const result = await execution;
        return {
          content: [
            {
              type: "text",
              text: serializeSubagentResult(result),
            },
          ],
          details: result,
          isError: result.status === "failed",
        };
      } catch (error) {
        const cancelled = error instanceof SubagentCancellationError;
        const message = error instanceof Error ? error.message : String(error);
        return {
          content: [
            {
              type: "text",
              text: boundText(
                `${cancelled ? "Controller cancellation" : "Subagent controller failure"}: ${message}`,
                { maxCharacters: 32_000, maxLines: 400 },
              ),
            },
          ],
          details: { runId, operationId, agent: agent.name, controllerCancellation: cancelled },
          isError: true,
        };
      } finally {
        signal?.removeEventListener("abort", forwardAbort);
        active.delete(controller);
        executions.delete(controller);
      }
    },
  });

  pi.on("session_shutdown", async () => {
    shuttingDown = true;
    const ownedControllers = [...active];
    const ownedExecutions = [...executions.values()];
    for (const controller of ownedControllers) controller.abort();
    await Promise.allSettled(ownedExecutions);
  });
}

export default function subagentExtension(pi: ExtensionAPI): void {
  registerSubagentExtension(pi);
}
