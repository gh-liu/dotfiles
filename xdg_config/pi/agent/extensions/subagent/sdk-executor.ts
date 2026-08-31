import { randomUUID } from "node:crypto";
import { join } from "node:path";

import { getAgentDir } from "@earendil-works/pi-coding-agent";
import { StringEnum } from "@earendil-works/pi-ai";
import { Type } from "typebox";

import { boundText, redactSecrets, SUBAGENT_HANDOFF_MAX_CHARACTERS } from "./output.ts";
import { SubagentCancellationError } from "./protocol.ts";
import type { SubagentActivityPhase, SubagentController, SubagentOperation, SubagentProgress, SubagentResult, SubagentRunOptions, SubagentTimelineEntry, SubagentToolProgressItem } from "./protocol.ts";

export interface SdkSubagentConfig {
  agentDir?: string;
  sessionRoot?: string;
  modelRuntime?: any;
  createSession?: (options: any) => Promise<{ session: any }>;
  terminationGraceMs?: number;
  customTools?: any[];
  /** Environment variable names whose values must be redacted from child output. */
  credentialEnvNames?: string[];
}

type SessionLike = {
  prompt(text: string, options?: any): Promise<void>;
  abort(): Promise<void>;
  steer(text: string): Promise<void>;
  followUp?(text: string): Promise<void>;
  dispose(): void;
  subscribe(listener: (event: any) => void): () => void;
  sessionFile?: string;
  sessionId: string;
  isStreaming?: boolean;
};

function deferred<T>(): { promise: Promise<T>; resolve: (value: T) => void; reject: (error: Error) => void } {
  let resolve!: (value: T) => void;
  let reject!: (error: Error) => void;
  const promise = new Promise<T>((next, fail) => { resolve = next; reject = fail; });
  return { promise, resolve, reject };
}

function boundedOneLine(text: string, maxCharacters: number, secrets: string[]): string {
  const normalized = redactSecrets(text, secrets).replace(/\s+/g, " ").trim();
  return normalized.length <= maxCharacters ? normalized : `${normalized.slice(0, maxCharacters - 1)}…`;
}

/** Collapse the $HOME prefix to `~` so progress paths stay short and readable. */
function collapseHome(value: string): string {
  const home = process.env.HOME;
  if (!home || home === "/") return value;
  return value.startsWith(`${home}/`) ? `~${value.slice(home.length)}` : value;
}

function safeToolProgress(record: any, secrets: string[]): string {
  const toolName = typeof record.toolName === "string" ? record.toolName : "tool";
  const args = record.args && typeof record.args === "object" && !Array.isArray(record.args) ? (record.args as Record<string, unknown>) : {};
  const values = toolName === "bash"
    ? [args.command]
    : toolName === "grep" ? [args.pattern, args.path] : [args.path];
  const detail = values
    .filter((v): v is string => typeof v === "string" && v.trim() !== "")
    .map((v) => boundedOneLine(collapseHome(v), 80, secrets))
    .join(" · ");
  return boundedOneLine(`${toolName}${detail ? ` ${detail}` : ""}`, 120, secrets);
}

function credentialValues(options: SubagentRunOptions, config: SdkSubagentConfig = {}): string[] {
  const names = [
    ...(config.credentialEnvNames ?? []),
    ...(options.agent.tools.includes("web_search") ? ["EXA_API_KEY"] : []),
  ];
  return [...new Set(names
    .map((name) => process.env[name])
    .filter((value): value is string => value !== undefined && value.length > 0))]
    .sort((a, b) => b.length - a.length);
}

function identity(
  options: SubagentRunOptions,
  processInstanceId: string,
): Pick<SubagentResult, "runId" | "operationId" | "agent" | "processInstanceId"> {
  return { runId: options.runId, operationId: options.operationId, agent: options.agent.name, processInstanceId };
}

function result(
  options: SubagentRunOptions,
  status: SubagentResult["status"],
  summary: string,
  transcript: SubagentResult["transcript"],
  secrets: string[],
  processInstanceId: string,
): SubagentResult {
  return {
    ...identity(options, processInstanceId),
    status,
    summary: boundText(summary, { maxCharacters: SUBAGENT_HANDOFF_MAX_CHARACTERS, maxLines: 400 }, secrets),
    transcript: { ...transcript },
  };
}

function makeWebSearchTool(): any {
  const WebSearchParameters = Type.Object({
    query: Type.String({ minLength: 1, description: "Natural-language web search query" }),
    numResults: Type.Optional(Type.Integer({ minimum: 1, maximum: 10, description: "Number of results" })),
    type: Type.Optional(StringEnum(["auto", "fast", "instant"] as const)),
    includeDomains: Type.Optional(Type.Array(Type.String({ minLength: 1 }), { maxItems: 100 })),
    excludeDomains: Type.Optional(Type.Array(Type.String({ minLength: 1 }), { maxItems: 100 })),
    startPublishedDate: Type.Optional(Type.String()),
    endPublishedDate: Type.Optional(Type.String()),
    content: Type.Optional(StringEnum(["highlights", "text"] as const)),
    maxCharacters: Type.Optional(Type.Integer({ minimum: 1000, maximum: 20000 })),
    fresh: Type.Optional(Type.Boolean()),
  });
  const EXA_SEARCH_URL = "https://api.exa.ai/search";
  function formatResults(query: string, results: any[]): string {
    if (results.length === 0) return `No results for "${query}".`;
    return results
      .map((r, i) => {
        const title = r.title ? `Title: ${r.title}` : "";
        const url = r.url ? `URL: ${r.url}` : "";
        const highlights = Array.isArray(r.highlights) ? r.highlights.join("\n") : r.text ?? "";
        return `Result ${i + 1}:\n${title}\n${url}\n${highlights}`.trim();
      })
      .join("\n\n");
  }
  return {
    name: "web_search",
    label: "Web Search (Exa)",
    description: "Search the web for current or precise external facts unavailable in the repository or supplied context. Prefer authoritative sources and preserve URLs. Do not use for general background knowledge or facts already available locally. Returns token-efficient highlights by default.",
    promptSnippet: "Search for current or precise external facts unavailable in local context and return cited sources",
    promptGuidelines: [
      "Use web_search only when the task depends on current or precise external information unavailable in the repository or supplied context; prefer authoritative sources and do not search for general background knowledge.",
    ],
    parameters: WebSearchParameters,
    async execute(_toolCallId: string, params: any, signal?: AbortSignal) {
      const key = process.env.EXA_API_KEY?.trim();
      if (!key) {
        return {
          content: [{ type: "text", text: "Web search is unavailable: set EXA_API_KEY in the Pi environment." }],
          details: { provider: "exa", configured: false },
          isError: true,
        };
      }
      const content = params.content ?? "highlights";
      const contents: Record<string, unknown> =
        content === "text" ? { text: { maxCharacters: params.maxCharacters ?? 4000 } } : { highlights: { maxCharacters: params.maxCharacters ?? 4000 } };
      if (params.fresh) (contents as any).maxAgeHours = 0;
      const body: any = {
        query: params.query,
        type: params.type ?? "auto",
        numResults: params.numResults ?? 5,
        ...(params.includeDomains ? { includeDomains: params.includeDomains } : {}),
        ...(params.excludeDomains ? { excludeDomains: params.excludeDomains } : {}),
        ...(params.startPublishedDate ? { startPublishedDate: params.startPublishedDate } : {}),
        ...(params.endPublishedDate ? { endPublishedDate: params.endPublishedDate } : {}),
        contents,
      };
      try {
        const response = await fetch(EXA_SEARCH_URL, {
          method: "POST",
          headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
          body: JSON.stringify(body),
          signal,
        });
        const data: any = await response.json().catch(() => ({}));
        if (!response.ok) {
          return {
            content: [{ type: "text", text: `Exa search failed (${response.status}): ${data.error || response.statusText}` }],
            details: { provider: "exa", status: response.status },
            isError: true,
          };
        }
        if (!Array.isArray(data.results)) {
          return {
            content: [{ type: "text", text: "Exa search returned an invalid response." }],
            details: { provider: "exa", requestId: data.requestId },
            isError: true,
          };
        }
        return {
          content: [{ type: "text", text: formatResults(params.query, data.results) }],
          details: { provider: "exa", requestId: data.requestId, costDollars: data.costDollars, results: data.results },
        };
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return {
          content: [{ type: "text", text: `Exa search request failed: ${message}` }],
          details: { provider: "exa" },
          isError: true,
        };
      }
    },
  };
}

/** Keep injected implementations inside the agent definition's declared tool boundary. */
export function filterDeclaredCustomTools(declaredTools: readonly string[], customTools: readonly any[] = []): any[] {
  const declared = new Set(declaredTools);
  return customTools.filter(
    (tool) => tool && typeof tool === "object" && typeof tool.name === "string" && declared.has(tool.name),
  );
}

export type SdkSubagentController = SubagentController;

export async function createSdkSubagentController(
  initial: SubagentRunOptions,
  config: SdkSubagentConfig = {},
): Promise<SdkSubagentController> {
  if (config.terminationGraceMs !== undefined && (!Number.isSafeInteger(config.terminationGraceMs) || config.terminationGraceMs <= 0)) {
    throw new Error("terminationGraceMs must be a positive integer");
  }
  if (initial.signal?.aborted) throw new SubagentCancellationError("Subagent run cancelled before process creation");
  const processInstanceId = randomUUID();
  const agentDir = config.agentDir ?? getAgentDir();
  const sessionRoot = config.sessionRoot ?? join(agentDir, "subagent-sessions");
  const sessionDir = join(sessionRoot, initial.runId);
  const sessionPlan = {
    cwd: initial.cwd,
    agentDir,
    model: initial.agent.model,
    thinkingLevel: initial.agent.thinking,
    tools: initial.agent.tools,
    agent: initial.agent,
    sessionRoot,
    sessionDir,
    systemPrompt: initial.agent.systemPrompt,
    noExtensions: true,
    noSkills: true,
    noPromptTemplates: true,
    noThemes: true,
    noContextFiles: true,
  };
  let session: SessionLike;
  // Resolve session via injected factory or real SDK
  if (config.createSession) {
    const created = await config.createSession(sessionPlan);
    session = created.session as SessionLike;
    if (initial.signal?.aborted) throw new SubagentCancellationError("Subagent run cancelled before process creation");
  } else {
    if (initial.signal?.aborted) throw new SubagentCancellationError("Subagent run cancelled before process creation");
    // Real SDK path
    const thinkingLevel = initial.agent.thinking as any;
    let modelInstance: any = undefined;
    if (initial.agent.model) {
      const slash = initial.agent.model.lastIndexOf("/");
      if (slash !== -1) {
        const provider = initial.agent.model.slice(0, slash);
        const id = initial.agent.model.slice(slash + 1);
        let runtime = config.modelRuntime;
        if (!runtime) {
          try {
            const { ModelRuntime } = await import("@earendil-works/pi-coding-agent");
            runtime = await (ModelRuntime as any).create({
              authPath: join(agentDir, "auth.json"),
              modelsPath: join(agentDir, "models.json"),
              refreshOnCreate: false,
            });
          } catch {
            runtime = undefined;
          }
        }
        if (runtime) {
          try { modelInstance = runtime.getModel(provider, id); } catch {}
        }
      }
    }
    const { DefaultResourceLoader, SessionManager, createAgentSession } = await import("@earendil-works/pi-coding-agent");
    const loader = new DefaultResourceLoader({
      cwd: sessionPlan.cwd,
      agentDir: sessionPlan.agentDir,
      systemPrompt: sessionPlan.systemPrompt,
      noExtensions: sessionPlan.noExtensions,
      noSkills: sessionPlan.noSkills,
      noPromptTemplates: sessionPlan.noPromptTemplates,
      noThemes: sessionPlan.noThemes,
      noContextFiles: sessionPlan.noContextFiles,
    } as any);
    await (loader as any).reload();
    const customTools = filterDeclaredCustomTools(initial.agent.tools, config.customTools);
    if (initial.agent.tools.includes("web_search") && !customTools.some((tool) => tool.name === "web_search")) {
      customTools.unshift(makeWebSearchTool());
    }
    const manager = (SessionManager as any).create(sessionPlan.cwd, sessionPlan.sessionDir);
    if (initial.signal?.aborted) throw new SubagentCancellationError("Subagent run cancelled before process creation");
    const created = await (createAgentSession as any)({
      cwd: sessionPlan.cwd,
      agentDir: sessionPlan.agentDir,
      model: modelInstance,
      thinkingLevel,
      tools: sessionPlan.tools,
      customTools,
      resourceLoader: loader,
      sessionManager: manager,
    });
    session = created.session as SessionLike;
  }

  let transcript: SubagentResult["transcript"] | undefined;
  try {
    transcript = { sessionId: (session as any).sessionId, sessionPath: (session as any).sessionFile };
    if (!transcript.sessionId) transcript = undefined;
  } catch {
    transcript = undefined;
  }
  // Fallback if sessionFile not yet known but sessionManager has it
  if (!transcript || !transcript.sessionPath) {
    try {
      const mgr = (session as any).sessionManager;
      if (mgr) transcript = { sessionId: mgr.getSessionId?.() ?? (session as any).sessionId, sessionPath: mgr.getSessionFile?.() ?? (session as any).sessionFile };
    } catch {}
  }
  transcript ??= {};

  let closed = false;
  let closing: Promise<void> | undefined;
  let active = false;
  let activeAccepted = false;
  let activeOperationId: string | undefined;
  let abortActive: ((message: string) => Promise<boolean>) | undefined;
  let fatal: Error | undefined;
  const controllerFailure = deferred<Error>();
  let finalized = false;
  let currentUnsubscribe: (() => void) | undefined;
  let activeTerminal: ReturnType<typeof deferred<never>> | undefined;

  const baseSecrets = credentialValues(initial, config);
  // Snapshot the accepted runtime profile so later caller-side mutation of the
  // original options object cannot silently bypass the identity check.
  const initialProfile = { ...initial.agent, tools: [...initial.agent.tools] };
  let activeSettled: Promise<void> | undefined;
  let activeCancellation: Promise<void> | undefined;

  const finalize = (): void => {
    if (finalized) return;
    finalized = true;
    try { currentUnsubscribe?.(); } catch {}
  };

  const close = (): Promise<void> => {
    if (closing) return closing;
    closed = true;
    if (active) {
      const error = new Error("SDK subagent controller closed during active operation");
      activeTerminal?.reject(error);
    }
    closing = (async () => {
      let closeFailure: unknown;
      if (active && activeOperationId) {
        let timer: ReturnType<typeof setTimeout> | undefined;
        try {
          const aborted = await Promise.race([
            session.abort().then(() => true),
            new Promise<false>((resolveTimeout) => {
              timer = setTimeout(() => resolveTimeout(false), config.terminationGraceMs ?? 5_000);
            }),
          ]);
          if (!aborted) closeFailure = new Error("SDK abort did not finish during close");
        } catch (error) {
          closeFailure = error;
        } finally {
          if (timer) clearTimeout(timer);
        }
        // Wait briefly for settlement if watchdog allows
        if (activeTerminal) {
          try { await Promise.race([activeTerminal.promise.catch(() => {}), new Promise((r) => setTimeout(r, 500))]); } catch {}
        }
      }
      try { session.dispose(); } catch (error) { closeFailure ??= error; }
      finalize();
      if (fatal) throw fatal;
      if (closeFailure) throw closeFailure;
    })().finally(finalize);
    return closing;
  };

  // Observe fatal failures outside operations - if session throws unexpectedly, surface as failure
  // We keep failure promise pending until fatal occurs; tests expect failure rejected on explicit fail().

  return {
    processInstanceId,
    get transcript() { return { ...(transcript ?? {}) }; },
    failure: controllerFailure.promise,
    start(options): SubagentOperation {
      const accepted = deferred<void>();
      let operationBegan = false;
      const resultPromise = (async (): Promise<SubagentResult> => {
        if (closed) throw new Error("SDK subagent controller is closed");
        if (active) throw new Error("SDK subagent controller already has an active operation");
        if (fatal) throw fatal;
        const identityMismatch =
          options.runId !== initial.runId ||
          options.parentSessionId !== initial.parentSessionId ||
          options.cwd !== initial.cwd ||
          options.agent.name !== initialProfile.name ||
          options.agent.systemPrompt !== initialProfile.systemPrompt ||
          options.agent.model !== initialProfile.model ||
          options.agent.thinking !== initialProfile.thinking ||
          options.agent.tools.length !== initialProfile.tools.length ||
          options.agent.tools.some((tool, index) => tool !== initialProfile.tools[index]);
        if (identityMismatch) throw new Error("SDK subagent runtime identity does not match controller");
        if (!Number.isSafeInteger(options.deadlineMs) || options.deadlineMs <= 0) throw new Error("deadlineMs must be a positive integer");
        if (options.signal?.aborted) throw new SubagentCancellationError("Subagent run cancelled before submission");
        active = true;
        operationBegan = true;
        activeOperationId = options.operationId;
        const terminal = deferred<never>();
        terminal.promise.catch(() => {});
        activeTerminal = terminal;
        const secrets = credentialValues(options, config);
        let finalText: { text: string; stopReason?: string; error?: string } | undefined;
        const settled = deferred<void>();
        activeSettled = settled.promise;
        let authoritativeSettled = false;
        let abortWatchdog: NodeJS.Timeout | undefined;
        const clearAbortWatchdog = (): void => {
          if (abortWatchdog) { clearTimeout(abortWatchdog); abortWatchdog = undefined; }
        };
        const activeTools = new Map<string, SubagentToolProgressItem>();
        const toolHistory: SubagentToolProgressItem[] = [];
        const timeline: SubagentTimelineEntry[] = [];
        const MAX_TIMELINE = 24;
        let thinkingBuffer = "";
        let earlierToolCount = 0;
        let lastProgress = "";
        const boundTimeline = (): void => {
          // Keep only the newest slice so the live view stays compact and bounded.
          if (timeline.length > MAX_TIMELINE) timeline.splice(0, timeline.length - MAX_TIMELINE);
        };
        // Consecutive thinking deltas are merged into one segment and flushed only at
        // a boundary (next tool execution or message end) so the timeline preserves
        // ordering without emitting a new entry per delta. Flushing also emits a
        // settled `phase` so the widget stops showing the stale "Thinking…".
        const flushThinking = (): void => {
          const content = thinkingBuffer.trim();
          if (content) {
            timeline.push({ kind: "thinking", text: boundedOneLine(content, 200, secrets) });
            boundTimeline();
            // The segment is now a settled timeline entry: signal the boundary so
            // both renderers move from the live spinner to the completed marker.
            report("Thinking", { includeTools: true, phase: { kind: "thinking", status: "completed" } });
          }
          thinkingBuffer = "";
        };
        const report = (text: string, reportOptions: { includeTools?: boolean; phase?: SubagentActivityPhase } = {}): void => {
          const { includeTools = false, phase } = reportOptions;
          const bounded = boundedOneLine(text, 160, secrets);
          const progress: SubagentProgress = {
            summary: bounded,
            ...(phase ? { phase } : {}),
            ...(includeTools || toolHistory.length > 0 || activeTools.size > 0 ? {
              tools: {
                earlierCount: earlierToolCount,
                history: toolHistory.map((item) => ({ ...item })),
                active: [...activeTools.values()].map((item) => ({ ...item })),
              },
            } : {}),
            ...(timeline.length > 0 ? { timeline: timeline.map((entry) => ({ ...entry })) } : {}),
          };
          const key = JSON.stringify(progress);
          if (key !== lastProgress) {
            lastProgress = key;
            options.onProgress?.(progress);
          }
        };
        const listener = (event: any): void => {
          try {
            if (event.type === "agent_start") report("Child started; waiting for model…");
            else if (event.type === "message_update") {
              const type = event.assistantMessageEvent?.type as string | undefined;
              if (type?.startsWith("thinking")) {
                const assistantEvent = event.assistantMessageEvent as { delta?: unknown; content?: unknown } | undefined;
                if (type === "thinking_start") thinkingBuffer = "";
                const delta = typeof assistantEvent?.delta === "string" ? assistantEvent.delta : "";
                const content = typeof assistantEvent?.content === "string" ? assistantEvent.content : "";
                // Accumulate deltas into one segment; the authoritative endpoint content
                // is used when no deltas were surfaced by the SDK.
                if (delta) thinkingBuffer += delta;
                else if (content && !thinkingBuffer) thinkingBuffer = content;
                report("Thinking…", { phase: { kind: "thinking", status: "running" } });
              } else if (type?.startsWith("toolcall")) report("Preparing tool call…");
              else if (type?.startsWith("text")) report("Writing response…");
            } else if (event.type === "tool_execution_start") {
              // Any reasoning produced before this tool call becomes a timeline segment.
              flushThinking();
              const label = safeToolProgress(event, secrets);
              const id = typeof event.toolCallId === "string" ? event.toolCallId : `anonymous-${activeTools.size}`;
              activeTools.set(id, { id, summary: label, status: "running" });
              report(label.endsWith("…") ? label : `${label}…`, { includeTools: true, phase: { kind: "tool", status: "running" } });
            } else if (event.type === "tool_execution_end") {
              const id = typeof event.toolCallId === "string" ? event.toolCallId : `ended-${toolHistory.length}`;
              const activeItem = activeTools.get(id);
              const label = activeItem?.summary ?? safeToolProgress(event, secrets);
              activeTools.delete(id);
              const status: SubagentToolProgressItem["status"] = event.isError ? "failed" : "completed";
              const item = { id, summary: label, status };
              toolHistory.push(item);
              timeline.push({ kind: "tool", ...item });
              boundTimeline();
              if (toolHistory.length > 8) {
                earlierToolCount += toolHistory.length - 8;
                toolHistory.splice(0, toolHistory.length - 8);
              }
              report(event.isError ? `${label} failed · reviewing…` : `${label} done · working…`, { includeTools: true, phase: { kind: "tool", status: event.isError ? "failed" : "completed" } });
            } else if (event.type === "message_end" && event.message?.role === "assistant") {
              flushThinking();
              const text = (event.message.content ?? []).filter((p: any) => p.type === "text" && typeof p.text === "string").map((p: any) => p.text as string).join("\n");
              finalText = { text: boundText(text, { maxCharacters: SUBAGENT_HANDOFF_MAX_CHARACTERS, maxLines: 400 }, secrets), stopReason: event.message.stopReason, error: event.message.errorMessage };
              if (event.message.stopReason === "stop") report("Finalizing response…");
            } else if (event.type === "agent_settled") {
              flushThinking();
              authoritativeSettled = true;
              settled.resolve();
              clearAbortWatchdog();
            }
          } catch (e) {
            // Listener errors should not crash controller; treat as fatal?
            const err = e instanceof Error ? e : new Error(String(e));
            if (!fatal) { fatal = err; controllerFailure.resolve(err); terminal.reject(err); }
          }
        };
        currentUnsubscribe = session.subscribe(listener);
        let interrupted: SubagentCancellationError | undefined;
        const cancel = async (error: SubagentCancellationError): Promise<boolean> => {
          if (interrupted || authoritativeSettled || activeOperationId !== options.operationId) return false;
          interrupted = error;
          if (!activeAccepted) {
            try { accepted.reject(error); } catch {}
          }
          abortWatchdog = setTimeout(() => {
            const watchdogError = new Error("SDK abort did not reach authoritative settlement");
            if (!fatal) { fatal = watchdogError; controllerFailure.resolve(watchdogError); }
            terminal.reject(watchdogError);
          }, config.terminationGraceMs ?? 5_000);
          // Dispatch the abort; settlement is observed via the agent_settled event,
          // bounded by the watchdog above. Never await abort unboundedly.
          activeCancellation = session.abort().then(() => {}, (abortError) => {
            const err = abortError instanceof Error ? abortError : new Error(String(abortError));
            if (!fatal) { fatal = err; controllerFailure.resolve(err); }
            terminal.reject(err);
          });
          return true;
        };
        const onAbort = (): void => {
          void cancel(new SubagentCancellationError("Subagent run cancelled by controller")).catch(() => {});
        };
        let deadline: NodeJS.Timeout | undefined;
        // Prepare abort handling before prompt
        // Also need to handle session failure during prompt via terminal
        try {
          // Refresh transcript if needed after session creation (might have been undefined)
          if (!transcript?.sessionId || !transcript?.sessionPath) {
            try {
              const t: any = { sessionId: (session as any).sessionId, sessionPath: (session as any).sessionFile };
              if (t.sessionId) transcript = t;
            } catch {}
          }
          // Check aborted before prompt
          if (options.signal?.aborted) throw new SubagentCancellationError("Subagent run cancelled before submission");
          // Register abort listener before prompt
          options.signal?.addEventListener("abort", onAbort, { once: true });
          // Prepare prompt with preflight
          const promptText = ["Execute this work order exactly as provided. Return only the requested handoff.", JSON.stringify(options.workOrder)].join("\n\n");
          let preflightResolved = false;
          const promptPromise = session.prompt(promptText, {
            preflightResult: (success: boolean) => {
              if (preflightResolved) return;
              preflightResolved = true;
              if (success) {
                activeAccepted = true;
                accepted.resolve();
                abortActive = (message) => cancel(new SubagentCancellationError(message));
                deadline = setTimeout(() => {
                  void cancel(new SubagentCancellationError(`Subagent execution deadline exceeded (${options.deadlineMs} ms)`)).catch(() => {});
                }, options.deadlineMs);
                if (options.signal?.aborted) onAbort();
              } else {
                accepted.reject(new Error("SDK prompt preflight failed"));
              }
            },
          });
          // Surface prompt failures (transport/contract errors) through the terminal.
          void promptPromise.catch((error) => {
            const err = error instanceof Error ? error : new Error(String(error));
            if (!fatal) { fatal = err; controllerFailure.resolve(err); }
            terminal.reject(err);
          });
          // The authoritative agent_settled event settles the operation; the terminal
          // (fatal/cancel watchdog) is the only other exit.
          await Promise.race([settled.promise, terminal.promise]);
          // Do not resolve the result before the in-flight abort() call has returned.
          await activeCancellation?.catch(() => {});
          if (fatal) throw fatal;
          if (interrupted) {
            if (!activeAccepted) throw interrupted;
            return result(options as any, "interrupted", interrupted.message, transcript ?? {}, secrets, processInstanceId);
          }
          const complete = finalText?.stopReason === "stop" && finalText.text.trim() !== "";
          return result(options as any, complete ? "completed" : "failed", finalText?.error || finalText?.text || "Child did not produce a complete final assistant response.", transcript ?? {}, secrets, processInstanceId);
        } catch (error) {
          const failure = error instanceof Error ? error : new Error(String(error));
          try { accepted.reject(failure); } catch {}
          if (operationBegan && !closed) {
            if (!fatal) { fatal = failure; try { controllerFailure.resolve(failure); } catch {} try { terminal.reject(failure); } catch {} }
          }
          throw failure;
        } finally {
          if (deadline) clearTimeout(deadline);
          if (abortWatchdog) clearTimeout(abortWatchdog);
          options.signal?.removeEventListener("abort", onAbort);
          try { currentUnsubscribe?.(); } catch {}
          currentUnsubscribe = undefined;
          if (activeTerminal === terminal) activeTerminal = undefined;
          if (activeSettled === settled.promise) activeSettled = undefined;
          activeCancellation = undefined;
          active = false;
          activeAccepted = false;
          if (activeOperationId === options.operationId) activeOperationId = undefined;
          abortActive = undefined;
        }
      })();
      accepted.promise.catch(() => {});
      void resultPromise.catch((error) => { try { accepted.reject(error instanceof Error ? error : new Error(String(error))); } catch {} });
      return { accepted: accepted.promise, result: resultPromise };
    },
    async steer(expectedOperationId, message): Promise<boolean> {
      if (activeOperationId !== expectedOperationId || !active || !activeAccepted) return false;
      try {
        await session.steer(message);
        return true;
      } catch {
        return false;
      }
    },
    async interrupt(expectedOperationId): Promise<boolean> {
      if (activeOperationId !== expectedOperationId || !abortActive) return false;
      const ok = await abortActive("Subagent operation interrupted by controller");
      if (!ok) return false;
      // Spec parity: interrupt resolves only after both the abort dispatch and the
      // authoritative agent_settled event, bounded by the termination-grace watchdog.
      const grace = config.terminationGraceMs ?? 5_000;
      await Promise.race([
        activeSettled?.catch(() => {}) ?? Promise.resolve(),
        new Promise<never>((_, reject) => setTimeout(() => reject(new Error("SDK abort did not reach authoritative settlement")), grace)),
      ]);
      await activeCancellation?.catch(() => {});
      return true;
    },
    submit(this: SubagentController, options: SubagentRunOptions): Promise<SubagentResult> {
      return this.start(options).result;
    },
    close,
  };
}

export function createSdkSubagentExecutor(config: SdkSubagentConfig = {}): (options: SubagentRunOptions) => Promise<SubagentResult> {
  return async (options) => {
    let controller: SdkSubagentController;
    try {
      controller = await createSdkSubagentController(options, config);
    } catch (error) {
      if (error instanceof SubagentCancellationError) throw error;
      const secrets = credentialValues(options, config);
      return result(options as any, "failed", error instanceof Error ? error.message : String(error), {}, secrets, randomUUID());
    }
    let value: SubagentResult;
    try {
      const op = controller.start(options);
      await op.accepted;
      value = await op.result;
    } catch (error) {
      const operationMessage = error instanceof Error ? error.message : String(error);
      let cleanupMessage: string | undefined;
      try { await controller.close(); } catch (cleanupError) {
        const message = cleanupError instanceof Error ? cleanupError.message : String(cleanupError);
        if (message !== operationMessage) cleanupMessage = message;
      }
      const summary = cleanupMessage ? `${operationMessage}\n\nChild cleanup failed: ${cleanupMessage}` : operationMessage;
      if (error instanceof SubagentCancellationError) throw new SubagentCancellationError(summary);
      return result(options as any, "failed", summary, controller.transcript, credentialValues(options, config), controller.processInstanceId);
    }
    try {
      await controller.close();
    } catch (error) {
      return result(options as any, "failed", `Child cleanup failed: ${error instanceof Error ? error.message : String(error)}`, value.transcript, credentialValues(options, config), controller.processInstanceId);
    }
    if (value.status === "interrupted") throw new SubagentCancellationError(value.summary);
    return value;
  };
}
