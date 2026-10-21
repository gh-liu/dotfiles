import { join } from "node:path";
import { existsSync } from "node:fs";
import {
  createAgentSession, DefaultResourceLoader, getAgentDir, ModelRuntime,
  SessionManager, SettingsManager,
  type AgentSession, type ExtensionToolContext,
} from "@earendil-works/pi-coding-agent";

export type Thinking = NonNullable<ExtensionToolContext["thinkingLevel"]>;
export interface Request { description: string; task: string; thinking?: Thinking }
export interface Activity {
  id: string;
  name: string;
  args: string;
  status: "running" | "ok" | "error" | "cancelled";
  startedAt: number;
  durationMs?: number;
}
export interface Details {
  status: "running" | "ok" | "error" | "cancelled";
  startedAt: number;
  durationMs?: number;
  sessionFile?: string;
  activity: string;
  calls: Activity[];
  omitted: number;
  running: number;
  requestedThinking?: Thinking;
  effectiveThinking?: Thinking;
}
export interface Result {
  content: { type: "text"; text: string }[];
  details: Details;
  isError?: boolean;
}

const HANDOFF = `You are a fresh, one-shot child agent. Complete only the assigned task in the shared working directory. You cannot see the parent conversation. Follow applicable project guidance and skills, but do not delegate or launch other agents. This is context isolation, not a sandbox. Do not make unrelated changes or revert other people's work.

Return a concise Markdown handoff, ideally under 1200 words or 6000 characters, and always under 24000 UTF-8 bytes. Do not return raw thinking, transcripts, or long command output. Preserve exact file paths, symbols, important errors, evidence and validation results. Distinguish verified facts from inference and unverified claims. Use this format; write (none) for empty sections:
## Goal
Outcome: Give the direct answer or achieved outcome FIRST, including whether the task is complete or blocked.
State the child task goal briefly.
## Constraints & Preferences
Only constraints that affect the outcome; do not repeat the task.
## Progress
### Done
- [x] Findings, changes and validation with evidence, not an exploration log.
### In Progress
- [ ] Unfinished work, if any.
### Blocked
Current blockers, if any.
## Key Decisions
Decisions and brief rationale.
## Next Steps
Only genuine remaining actions for the parent; (none) when complete.
## Critical Context
Essential evidence and references needed to continue. Do not duplicate other sections.`;

// Bounds apply to persisted UI metadata as well as the collapsed display.
const MAX_CALLS = 64;
const MAX_ARGS = 2048;
const MAX_HANDOFF_BYTES = 24_000;

function bounded(text: string, bytes: number): string {
  if (Buffer.byteLength(text, "utf8") <= bytes) return text;
  const suffix = "… [shortened; see child session if available]";
  return Buffer.from(text).subarray(0, bytes - Buffer.byteLength(suffix) - 3).toString("utf8") + suffix;
}

export async function runSubagent(
  request: Request,
  signal: AbortSignal | undefined,
  onUpdate: ((result: Result) => void) | undefined,
  ctx: Pick<ExtensionToolContext, "cwd" | "model" | "thinkingLevel" | "isProjectTrusted">,
): Promise<Result> {
  const details: Details = {
    status: "running", startedAt: Date.now(), activity: "Starting child…", calls: [], omitted: 0, running: 0,
  };
  const active = new Set<string>();
  let child: AgentSession | undefined;
  let unsubscribe: (() => void) | undefined;
  let cancelled = signal?.aborted ?? false;
  let abortPromise: Promise<void> | undefined;
  let abortError: unknown;
  const cancel = () => {
    cancelled = true;
    details.activity = "Stopping child…";
    // agent_start retries this after prompt's asynchronous preflight if the first abort was idle.
    if (child) abortPromise = child.abort().catch((error: unknown) => { abortError = error; });
  };
  const checkCancelled = () => { if (cancelled) throw new Error("Subagent cancelled."); };
  const snapshot = (): Details => ({ ...details, calls: details.calls.map((call) => ({ ...call })) });
  const update = () => onUpdate?.({ content: [], details: snapshot() });
  signal?.addEventListener("abort", cancel, { once: true });
  // Also drives Elapsed while no tokens or tool events arrive; bounded to four updates/second.
  const timer = setInterval(update, 250);
  timer.unref();
  let text = "";
  try {
    checkCancelled();
    if (!ctx.model) throw new Error("No parent model selected; refusing a fallback model.");
    const thinking = request.thinking ?? ctx.thinkingLevel;
    if (!thinking) throw new Error("No parent or requested thinking level; refusing an implicit default.");
    details.requestedThinking = thinking;
    const agentDir = getAgentDir();
    const options = { projectTrusted: ctx.isProjectTrusted() };
    const source = SettingsManager.create(ctx.cwd, agentDir, options);
    // Preserve scope/trust and survive loader.reload(), without writing user settings.
    const stored = {
      global: JSON.stringify({ ...source.getGlobalSettings(), cacheWarming: "off" }),
      project: JSON.stringify(source.getProjectSettings()),
    };
    const settings = SettingsManager.fromStorage({ withLock(scope, fn) {
      const next = fn(stored[scope]);
      if (next !== undefined) stored[scope] = next;
    } }, options);
    const loader = new DefaultResourceLoader({
      cwd: ctx.cwd, agentDir, settingsManager: settings,
      noExtensions: true, noPromptTemplates: true, noThemes: true,
      appendSystemPromptOverride: (base) => [...base, HANDOFF],
    });
    await loader.reload();
    checkCancelled();
    const runtime = await ModelRuntime.create({
      authPath: join(agentDir, "auth.json"), modelsPath: join(agentDir, "models.json"), signal,
    });
    checkCancelled();
    const model = runtime.getModel(ctx.model.provider, ctx.model.id);
    if (!model) throw new Error(`Child cannot resolve ${ctx.model.provider}/${ctx.model.id} from configured providers. Dynamic parent providers/routers are not inherited.`);
    const manager = SessionManager.create(ctx.cwd, join(agentDir, "sessions", "subagents"));
    ({ session: child } = await createAgentSession({
      cwd: ctx.cwd, agentDir, modelRuntime: runtime, model, thinkingLevel: thinking,
      settingsManager: settings, resourceLoader: loader, sessionManager: manager,
      tools: ["read", "grep", "find", "ls", "bash", "edit", "write"], excludeTools: ["subagent"],
    }));
    details.effectiveThinking = child.thinkingLevel;
    checkCancelled();
    child.setSessionName(`Subagent: ${request.description}`);
    unsubscribe = child.subscribe((event) => {
      if (event.type === "agent_start" && cancelled) cancel();
      const sessionFile = manager.getSessionFile();
      if (sessionFile && existsSync(sessionFile)) details.sessionFile = sessionFile;
      if (event.type === "message_update" && !cancelled && !active.size) {
        const type = event.assistantMessageEvent.type;
        if (type.startsWith("thinking")) details.activity = "Thinking";
        else if (type.startsWith("text")) details.activity = "Writing handoff…";
        else if (type.startsWith("toolcall")) details.activity = "Preparing tool call…";
      }
      if (event.type === "tool_execution_start") {
        active.add(event.toolCallId);
        details.running = active.size;
        const raw = JSON.stringify(event.args) ?? "";
        const suffix = "… [arguments shortened; see child session]";
        details.calls.push({
          id: event.toolCallId, name: event.toolName,
          args: raw.length > MAX_ARGS ? `${raw.slice(0, MAX_ARGS - suffix.length)}${suffix}` : raw,
          status: "running", startedAt: Date.now(),
        });
        if (details.calls.length > MAX_CALLS) {
          const completed = details.calls.findIndex((call) => call.status !== "running");
          details.calls.splice(completed < 0 ? 0 : completed, 1);
          details.omitted++;
        }
        if (!cancelled) details.activity = `Running ${active.size} tool${active.size === 1 ? "" : "s"}…`;
      }
      if (event.type === "tool_execution_end") {
        active.delete(event.toolCallId);
        details.running = active.size;
        const call = details.calls.find((item) => item.id === event.toolCallId);
        if (call) {
          call.status = cancelled ? "cancelled" : event.isError ? "error" : "ok";
          call.durationMs = event.durationMs ?? Date.now() - call.startedAt;
        }
        if (!cancelled) details.activity = active.size ? `Running ${active.size} tool${active.size === 1 ? "" : "s"}…` : "Waiting for model…";
      }
      if (event.type === "auto_retry_start" && !cancelled) details.activity = `Retrying (${event.attempt}/${event.maxAttempts})…`;
      if (event.type === "auto_retry_end" && !cancelled) details.activity = "Waiting for model…";
      if (event.type === "compaction_start" && !cancelled) details.activity = "Compacting child context…";
      if (event.type === "compaction_end" && !cancelled) details.activity = "Waiting for model…";
    });
    details.activity = "Waiting for model…";
    update();
    // prompt awaits retries, compaction and continuation, unlike a single agent_end event.
    await child.prompt(request.task);
    await child.waitForIdle();
    checkCancelled();
    // Pi removes failed/length responses from model context; the persisted branch still has them.
    const entry = child.sessionManager.getBranch().findLast((entry) => entry.type === "message" && entry.message.role === "assistant");
    const last = entry?.type === "message" ? entry.message : undefined;
    if (!last || last.role !== "assistant") throw new Error("Child ended without an assistant handoff.");
    if (last.stopReason !== "stop") throw new Error(`Child ended with ${last.stopReason}: ${last.errorMessage ?? "handoff may be incomplete"}`);
    text = child.getLastAssistantText()?.trim() ?? "";
    if (!text) throw new Error("Child returned an empty handoff.");
    if (Buffer.byteLength(text, "utf8") > MAX_HANDOFF_BYTES) {
      throw new Error(`Child handoff exceeds ${MAX_HANDOFF_BYTES} bytes; it was saved but not returned in full. Read the child session for the complete result.`);
    }
    details.status = "ok";
  } catch (error) {
    details.status = cancelled ? "cancelled" : "error";
    text = cancelled ? "Subagent cancelled." : `Subagent failed: ${bounded(error instanceof Error ? error.message : String(error), 16_000)}`;
    text += "\nThe shared working directory may contain partial changes; no rollback was performed.";
  } finally {
    signal?.removeEventListener("abort", cancel);
    // Do not return while cooperative tools are still running, even on failure.
    if (child) {
      await child.abort().catch((error: unknown) => { abortError = error; });
      await abortPromise;
      unsubscribe?.();
      child.dispose();
    }
    clearInterval(timer);
    if (abortError) {
      details.status = "error";
      text += `\nChild shutdown failed: ${bounded(String(abortError), 2000)}`;
    }
    details.durationMs = Date.now() - details.startedAt;
    details.activity = details.status === "ok" ? "Complete" : details.status === "cancelled" ? "Cancelled" : "Failed";
    details.running = 0;
    for (const call of details.calls) {
      if (call.status === "running") {
        call.status = details.status === "cancelled" ? "cancelled" : "error";
        call.durationMs = Date.now() - call.startedAt;
      }
    }
  }
  if (details.effectiveThinking && details.effectiveThinking !== details.requestedThinking) {
    text += `\nThinking adjusted by model: ${details.requestedThinking} → ${details.effectiveThinking}.`;
  }
  if (Buffer.byteLength(text) > MAX_HANDOFF_BYTES) {
    details.status = "error";
    details.activity = "Failed";
    text = `Subagent failed: returned content exceeds ${MAX_HANDOFF_BYTES} bytes.\n${bounded(text, 20_000)}`;
  }
  if (details.status !== "ok" && details.sessionFile) text += `\nChild session: ${details.sessionFile}`;
  return { content: [{ type: "text", text: bounded(text, MAX_HANDOFF_BYTES) }], details: snapshot(), isError: details.status !== "ok" };
}
