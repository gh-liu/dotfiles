import type { Model } from "@earendil-works/pi-ai";
import {
  getAgentDir,
  SettingsManager,
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

import { canonicalCwd, loadApplicableGuidance } from "./context.ts";
import { bound, redact, safeText } from "./output.ts";
import { createSdkChildFactory } from "./sdk-runner.ts";

export const THINKING_LEVELS = ["off", "minimal", "low", "medium", "high", "xhigh", "max"] as const;
export type ThinkingLevel = (typeof THINKING_LEVELS)[number];

export interface ChildRequest {
  task: string;
  cwd: string;
  guidance: string[];
  model: Model<any>;
  thinking: ThinkingLevel;
}

export type ChildResult =
  | { status: "completed"; handoff: string }
  | { status: "failed" | "interrupted"; error: string };

export interface ChildHandle {
  readonly result: Promise<ChildResult>;
  interrupt(): Promise<void>;
  dispose(): Promise<void>;
}

export type ChildFactory = (request: ChildRequest) => Promise<ChildHandle>;

export type ParentResult =
  | { status: "completed"; handoff: string; warning?: string }
  | { status: "failed" | "interrupted"; error: string };

interface RegisterOptions {
  capacity?: number;
  childFactory?: ChildFactory;
  credentialValues?: () => string[];
  allowedRoot?: string;
}

interface SubagentSettings {
  maxConcurrentRuns?: unknown;
}

interface SettingsWithSubagent {
  subagent?: unknown;
}

const DEFAULT_CAPACITY = 4;

function subagentSettings(value: unknown): SubagentSettings | undefined {
  if (value === undefined) return undefined;
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("subagent settings must be an object");
  }
  return value as SubagentSettings;
}

export function resolveConfiguredCapacity(
  globalSettings: SettingsWithSubagent,
  projectSettings: SettingsWithSubagent,
  projectTrusted: boolean,
): number {
  const global = subagentSettings(globalSettings.subagent);
  const project = projectTrusted ? subagentSettings(projectSettings.subagent) : undefined;
  const value = project?.maxConcurrentRuns ?? global?.maxConcurrentRuns ?? DEFAULT_CAPACITY;
  if (!Number.isInteger(value) || (value as number) < 1) {
    throw new Error("subagent.maxConcurrentRuns must be a positive integer");
  }
  return value as number;
}

function configuredCapacity(ctx: ExtensionContext): number {
  const projectTrusted = ctx.isProjectTrusted();
  const settings = SettingsManager.create(ctx.cwd, getAgentDir(), { projectTrusted });
  return resolveConfiguredCapacity(
    settings.getGlobalSettings() as SettingsWithSubagent,
    settings.getProjectSettings() as SettingsWithSubagent,
    projectTrusted,
  );
}

const SubagentParameters = Type.Object({
  task: Type.String({ minLength: 1, description: "Complete task and expected handoff for a fresh child context" }),
  opts: Type.Optional(Type.Object({
    model: Type.Optional(Type.String({ minLength: 1, description: "Optional provider/model override" })),
    thinking: Type.Optional(Type.Union(THINKING_LEVELS.map((level) => Type.Literal(level)), {
      description: "Optional child thinking-level override",
    })),
  }, { additionalProperties: false })),
}, { additionalProperties: false });

function errorResult(error: string, credentials: readonly string[]) {
  const result: ParentResult = { status: "failed", error: safeText(error, credentials) };
  return {
    content: [{ type: "text" as const, text: JSON.stringify(result) }],
    details: result,
    isError: true,
  };
}

function validate(params: unknown): string | undefined {
  if (!params || typeof params !== "object" || Array.isArray(params)) return "parameters must be an object";
  const value = params as Record<string, unknown>;
  for (const key of Object.keys(value)) {
    if (key !== "task" && key !== "opts") return `unsupported field: ${key}`;
  }
  if (!("task" in value)) return "task is required";
  if (typeof value.task !== "string" || !value.task.trim()) return "task must not be empty";
  if (value.opts === undefined) return undefined;
  if (!value.opts || typeof value.opts !== "object" || Array.isArray(value.opts)) return "opts must be an object";
  const opts = value.opts as Record<string, unknown>;
  for (const key of Object.keys(opts)) {
    if (key !== "model" && key !== "thinking") return `unsupported opts field: ${key}`;
  }
  if (opts.model !== undefined && (typeof opts.model !== "string" || !opts.model.trim())) {
    return "model must not be empty";
  }
  if (opts.thinking !== undefined && !THINKING_LEVELS.includes(opts.thinking as ThinkingLevel)) {
    return `unsupported thinking level: ${String(opts.thinking)}`;
  }
  return undefined;
}

function splitModel(value: string): { provider: string; id: string } | undefined {
  const slash = value.indexOf("/");
  if (slash <= 0 || slash === value.length - 1) return undefined;
  return { provider: value.slice(0, slash), id: value.slice(slash + 1) };
}

function resolveRequest(
  params: { task: string; opts?: { model?: string; thinking?: ThinkingLevel } },
  ctx: ExtensionContext,
  allowedRoot?: string,
): ChildRequest {
  const requestedModel = params.opts?.model;
  let model = ctx.model;
  if (requestedModel) {
    const parsed = splitModel(requestedModel);
    model = parsed ? ctx.modelRegistry.find(parsed.provider, parsed.id) : undefined;
    if (!model) throw new Error(`unknown model: ${requestedModel}`);
  }
  if (!model) throw new Error("No parent model is available to inherit.");
  const thinking = params.opts?.thinking ?? ctx.thinkingLevel ?? "medium";
  const cwd = canonicalCwd(allowedRoot ?? ctx.cwd, ctx.cwd);
  return {
    task: params.task.trim(),
    cwd,
    guidance: loadApplicableGuidance(cwd),
    model,
    thinking,
  };
}

function project(result: ChildResult, credentials: readonly string[]): ParentResult {
  if (result.status === "completed") {
    return { status: "completed", handoff: bound(redact(result.handoff, credentials)) };
  }
  return { status: result.status, error: safeText(result.error, credentials) };
}

function environmentCredentialValues(): string[] {
  return Object.entries(process.env)
    .filter(([name, value]) =>
      value !== undefined
      && value.length >= 6
      && /(?:API_?KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL)/iu.test(name))
    .map(([, value]) => value!)
    .sort((left, right) => right.length - left.length);
}

export function registerSubagentExtension(pi: ExtensionAPI, options: RegisterOptions = {}): void {
  if (options.capacity !== undefined && (!Number.isInteger(options.capacity) || options.capacity < 1)) {
    throw new Error("Subagent capacity must be a positive integer.");
  }
  const childFactory = options.childFactory ?? createSdkChildFactory();
  const credentialValues = options.credentialValues ?? environmentCredentialValues;
  const owned = new Set<ChildHandle>();
  const activeCalls = new Set<Promise<void>>();
  let occupied = 0;
  let shuttingDown = false;

  pi.registerTool({
    name: "subagent",
    label: "Subagent",
    description: "Run one bounded task in a fresh child context and return its final handoff. Put investigation, review, implementation, or testing behavior directly in task. opts may override only model and thinking.",
    promptSnippet: "Delegate one bounded task to a fresh child context and wait for its final handoff",
    executionMode: "parallel",
    parameters: SubagentParameters,
    async execute(_toolCallId, rawParams, signal, _onUpdate, ctx) {
      const credentials = credentialValues();
      const validationError = validate(rawParams);
      if (validationError) return errorResult(validationError, credentials);
      if (shuttingDown) return errorResult("Subagent plugin is shutting down.", credentials);
      let capacity: number;
      try {
        capacity = options.capacity ?? configuredCapacity(ctx);
      } catch (error) {
        return errorResult(error instanceof Error ? error.message : String(error), credentials);
      }
      if (occupied >= capacity) {
        return errorResult(`Subagent capacity unavailable: ${occupied}/${capacity} children are owned.`, credentials);
      }

      let request: ChildRequest;
      try {
        request = resolveRequest(rawParams, ctx, options.allowedRoot);
      } catch (error) {
        return errorResult(error instanceof Error ? error.message : String(error), credentials);
      }

      occupied += 1;
      let completeCall!: () => void;
      const callDone = new Promise<void>((resolve) => { completeCall = resolve; });
      activeCalls.add(callDone);
      let child: ChildHandle;
      try {
        child = await childFactory(request);
      } catch (error) {
        occupied -= 1;
        completeCall();
        activeCalls.delete(callDone);
        return errorResult(error instanceof Error ? error.message : String(error), credentials);
      }
      owned.add(child);
      if (shuttingDown) void child.interrupt().catch(() => {});

      let removeAbortListener = () => {};
      if (signal) {
        const abort = () => { void child.interrupt().catch(() => {}); };
        if (signal.aborted) abort();
        else {
          signal.addEventListener("abort", abort, { once: true });
          removeAbortListener = () => signal.removeEventListener("abort", abort);
        }
      }

      let parentResult: ParentResult;
      let cleanupError: string | undefined;
      try {
        parentResult = project(await child.result, credentials);
      } catch (error) {
        parentResult = { status: "failed", error: safeText(error, credentials) };
      } finally {
        removeAbortListener();
        try {
          await child.dispose();
          owned.delete(child);
          occupied -= 1;
        } catch (error) {
          cleanupError = safeText(error, credentials);
        }
        completeCall();
        activeCalls.delete(callDone);
      }

      if (cleanupError) {
        const warning = `Child cleanup failed; ownership is uncertain and this work must not be retried automatically: ${cleanupError}`;
        if (parentResult.status === "completed") parentResult = { ...parentResult, warning };
        else parentResult = { ...parentResult, error: `${parentResult.error}\n${warning}` };
      }
      return {
        content: [{ type: "text" as const, text: JSON.stringify(parentResult) }],
        details: parentResult,
        ...(parentResult.status === "failed" ? { isError: true } : {}),
      };
    },
    renderCall(args, theme, context) {
      const credentials = credentialValues();
      const task = safeText(args.task, credentials).replace(/\s+/gu, " ");
      const summary = task.length > 120 ? `${task.slice(0, 119)}…` : task;
      const metadata = [args.opts?.model, args.opts?.thinking].filter(Boolean).join(" · ");
      const header = `${theme.fg("toolTitle", theme.bold("subagent"))}${metadata ? ` · ${metadata}` : ""} — ${summary}`;
      if (!context.expanded) return new Text(header, 0, 0);
      return new Text(`${header}\n\n${safeText(args.task, credentials)}`, 0, 0);
    },
    renderResult(result, _renderOptions, theme) {
      const details = result.details as ParentResult | undefined;
      if (!details) return new Text(theme.fg("error", "failed — invalid subagent result"), 0, 0);
      const marker = details.status === "completed" ? "✓" : details.status === "interrupted" ? "■" : "✗";
      const color = details.status === "completed" ? "success" : details.status === "interrupted" ? "warning" : "error";
      const body = details.status === "completed" ? details.handoff : details.error;
      return new Text(`${theme.fg(color, `${marker} ${details.status}`)}${body ? `\n${body}` : ""}`, 0, 0);
    },
  });

  pi.on("session_shutdown", async () => {
    shuttingDown = true;
    await Promise.allSettled([...owned].map((child) => child.interrupt()));
    await Promise.allSettled([...activeCalls]);
    await Promise.allSettled([...owned].map(async (child) => {
      await child.dispose();
      owned.delete(child);
    }));
  });
}

export default function subagentExtension(pi: ExtensionAPI): void {
  registerSubagentExtension(pi);
}
