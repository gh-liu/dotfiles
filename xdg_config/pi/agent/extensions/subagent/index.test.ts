import { afterEach, describe, expect, test, vi } from "vitest";
import { mkdtempSync, mkdirSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import type {
  ExtensionAPI,
  ExtensionContext,
  MessageRenderer,
  ToolDefinition,
} from "@earendil-works/pi-coding-agent";
import { buildWakeWordSnippet, loadSubagentOverrides, registerSubagentExtension, WAKE_BINDINGS } from "./index.ts";
import { SUBAGENT_COMPLETION_MESSAGE } from "./render.ts";
import type {
  SubagentController,
  SubagentControllerFactory,
  SubagentOperation,
  SubagentResult,
  SubagentRunOptions,
} from "./protocol.ts";

const temporaryDirectories: string[] = [];

if (!("waitFor" in vi)) {
  (vi as typeof vi & { waitFor: (assertion: () => void | Promise<void>) => Promise<void> }).waitFor = async (assertion) => {
    const deadline = Date.now() + 1_000;
    let lastError: unknown;
    while (Date.now() < deadline) {
      try {
        await assertion();
        return;
      } catch (error) {
        lastError = error;
        await new Promise((resolve) => setTimeout(resolve, 5));
      }
    }
    if (lastError) throw lastError;
  };
}

afterEach(() => {
  vi.useRealTimers();
  for (const directory of temporaryDirectories.splice(0)) rmSync(directory, { recursive: true, force: true });
});

function temporaryDirectory(prefix: string): string {
  const directory = mkdtempSync(join(tmpdir(), prefix));
  temporaryDirectories.push(directory);
  return directory;
}

function writeAgent(directory: string, name = "scout", description = "Inspect files", tools = "read, grep"): void {
  mkdirSync(directory, { recursive: true });
  writeFileSync(
    join(directory, `${name}.md`),
    `---\nname: ${name}\ndescription: ${description}\ntools: [${tools}]\n---\nDo the assigned work.\n`,
  );
}

function deferred<T>() {
  let resolve!: (value: T | PromiseLike<T>) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((res, rej) => { resolve = res; reject = rej; });
  return { promise, resolve, reject };
}

interface FakeStart {
  options: SubagentRunOptions;
  accepted: ReturnType<typeof deferred<void>>;
  result: ReturnType<typeof deferred<SubagentResult>>;
}

class FakeController implements SubagentController {
  readonly starts: FakeStart[] = [];
  readonly steerCalls: Array<{ operationId: string; message: string }> = [];
  readonly interruptCalls: string[] = [];
  private readonly failureEvent = deferred<Error>();
  readonly failure = this.failureEvent.promise;
  closeCalls = 0;
  readonly transcript = { sessionId: "child-session", sessionPath: "/sessions/child.jsonl" };

  constructor(readonly processInstanceId: string, private readonly autoAccept = true) {}

  start(options: SubagentRunOptions): SubagentOperation {
    const call = { options, accepted: deferred<void>(), result: deferred<SubagentResult>() };
    this.starts.push(call);
    if (this.autoAccept) call.accepted.resolve();
    return { accepted: call.accepted.promise, result: call.result.promise };
  }

  async submit(options: SubagentRunOptions): Promise<SubagentResult> {
    const operation = this.start(options);
    await operation.accepted;
    return operation.result;
  }

  async steer(expectedOperationId: string, message: string): Promise<boolean> {
    const current = this.starts.at(-1);
    if (!current || current.options.operationId !== expectedOperationId) return false;
    this.steerCalls.push({ operationId: expectedOperationId, message });
    return true;
  }

  async interrupt(expectedOperationId: string): Promise<boolean> {
    this.interruptCalls.push(expectedOperationId);
    const current = [...this.starts].reverse().find(
      (call) => call.options.operationId === expectedOperationId,
    );
    if (!current) return false;
    current.result.resolve(this.makeResult(current, "interrupted", "Interrupted."));
    return true;
  }

  async close(): Promise<void> {
    this.closeCalls += 1;
    for (const call of this.starts) {
      call.accepted.reject(new Error("Controller closed"));
      call.result.reject(new Error("Controller closed"));
    }
  }

  accept(index = this.starts.length - 1): void { this.starts[index].accepted.resolve(); }

  settle(index = this.starts.length - 1, status: SubagentResult["status"] = "completed", summary = "Done."): void {
    const call = this.starts[index];
    call.result.resolve(this.makeResult(call, status, summary));
  }

  fail(error = new Error("Child crashed")): void { this.failureEvent.resolve(error); }

  private makeResult(call: FakeStart, status: SubagentResult["status"], summary: string): SubagentResult {
    return {
      runId: call.options.runId,
      operationId: call.options.operationId,
      processInstanceId: this.processInstanceId,
      agent: call.options.agent.name,
      status,
      summary,
      transcript: this.transcript,
    };
  }
}

function fakeFactory(autoAccept = true) {
  const controllers: FakeController[] = [];
  const factory = vi.fn<SubagentControllerFactory>(async () => {
    const controller = new FakeController(`process-${controllers.length + 1}`, autoAccept);
    controllers.push(controller);
    return controller;
  });
  return { factory, controllers };
}

function harness() {
  let tool: ToolDefinition | undefined;
  let shutdown: (() => Promise<void> | void) | undefined;
  const messages: Array<{ message: Record<string, unknown>; options?: Record<string, unknown> }> = [];
  const messageRenderers = new Map<string, MessageRenderer>();
  const pi = {
    registerTool(definition: ToolDefinition) { tool = definition; },
    registerMessageRenderer(customType: string, renderer: MessageRenderer) {
      messageRenderers.set(customType, renderer);
    },
    appendEntry(_customType: string, _data?: unknown) {},
    sendMessage(message: Record<string, unknown>, options?: Record<string, unknown>) {
      messages.push({ message, options });
    },
    on(event: string, handler: () => Promise<void> | void) {
      if (event === "session_shutdown") shutdown = handler;
    },
  } as ExtensionAPI;
  return {
    pi,
    messages,
    messageRenderers,
    getTool: () => tool!,
    shutdown: async () => { await shutdown?.(); },
  };
}

function context(cwd: string): ExtensionContext {
  return { cwd, sessionManager: { getSessionId: () => "parent-session" } } as unknown as ExtensionContext;
}

function setup(options: { autoAccept?: boolean; ids?: string[]; settingsPath?: string } = {}) {
  const root = temporaryDirectory("pi-subagent-project-");
  const agents = temporaryDirectory("pi-subagent-agents-");
  writeAgent(agents);
  const fake = fakeFactory(options.autoAccept);
  const extension = harness();
  const ids = options.ids ?? Array.from({ length: 30 }, (_, index) => `id-${index + 1}`);
  registerSubagentExtension(extension.pi, {
    agentDirectory: agents,
    controllerFactory: fake.factory,
    idFactory: () => ids.shift()!,
    settingsPath: options.settingsPath ?? join(temporaryDirectory("pi-subagent-settings-"), "missing.json"),
  });
  const invoke = (params: Record<string, unknown>) => extension.getTool().execute(
    "tool-call",
    ((params.action === "run" || params.action === "start") && params.deadlineMs === undefined
      ? { ...params, deadlineMs: 600_000 }
      : params) as never,
    undefined, undefined, context(root),
  );
  return { root, agents, fake, extension, invoke };
}

async function startIdle(env: ReturnType<typeof setup>) {
  const started = await env.invoke({ action: "start", agent: "scout", task: "Initial" });
  const identity = started.details as { runId: string; operationId: string; revision: number };
  env.fake.controllers[0].settle(0);
  await env.invoke({ action: "wait", id: identity.runId, operationId: identity.operationId });
  return identity;
}

describe("subagent settings overrides", () => {
  test("loads missing settings as no overrides and malformed JSON as a collected error", () => {
    expect(loadSubagentOverrides(join(temporaryDirectory("pi-subagent-settings-"), "missing.json"))).toEqual({ errors: [] });

    const settingsPath = join(temporaryDirectory("pi-subagent-settings-"), "settings.json");
    writeFileSync(settingsPath, "{");

    const loaded = loadSubagentOverrides(settingsPath);
    expect(loaded.overrides).toBeUndefined();
    expect(loaded.errors).toHaveLength(1);
    expect(loaded.errors[0].filePath).toBe("settings.json:subagents");
  });
});

describe("subagent tool", () => {
  test("layout contract: call/result summaries stay one-line and transcript paths elide", async () => {
    const env = setup();
    const tool = env.extension.getTool();
    const theme = { fg: (_color: string, text: string) => text, bold: (text: string) => text };
    const renderCallLayout = (args: Record<string, unknown>, expanded: boolean) =>
      tool.renderCall!(args as never, theme, { args: {}, isError: false, state: {}, expanded, invalidate: vi.fn() } as never)
        .render(200).map((line) => line.trimEnd());
    const renderResultLayout = (args: Record<string, unknown>, details: Record<string, unknown>, expanded: boolean) =>
      tool.renderResult!(
        { content: [{ type: "text", text: "" }], details },
        { expanded, isPartial: false }, theme,
        { args, isError: false, state: {}, invalidate: vi.fn() } as never,
      ).render(200).map((line) => line.trimEnd());

    const task = "Outcome: Summarize settings\n\nConstraints: read-only; skim only.";
    const home = process.env.HOME ?? "";
    const sessionPath = `${home}/tools/dotfiles/xdg_config/pi/agent/subagent-sessions/${"r".repeat(40)}/2026-08-22T02-33-38-543Z_deadbeef.jsonl`;
    const resultDetails = {
      runId: "r".repeat(40),
      operationId: "o".repeat(40),
      agent: "scout",
      status: "completed",
      summary: "ok",
      elapsedMs: 12_000,
      transcript: { sessionPath },
    };

    // Collapsed call: a single line — label, optional bg marker, one-line title.
    const collapsedCall = renderCallLayout({ action: "start", agent: "scout", task }, false);
    expect(collapsedCall).toHaveLength(1);
    expect(collapsedCall[0]).toContain("scout");
    expect(collapsedCall[0]).toContain("· bg");
    expect(collapsedCall[0]).toContain("— Summarize settings");
    expect(collapsedCall[0]).not.toContain("Constraints");

    // Expanded call: title, cwd, and deadline share ONE bounded line; body follows.
    const expandedCall = renderCallLayout(
      { action: "start", agent: "scout", task, cwd: `${home}/tools/dotfiles`, deadlineMs: 240_000 }, true,
    );
    expect(expandedCall[0]).toContain("— Summarize settings");
    expect(expandedCall[0]).toContain("~/tools/dotfiles");
    expect(expandedCall[0]).toContain("240s");
    expect(expandedCall[0].length).toBeLessThanOrEqual(140);
    expect(expandedCall.slice(1).join("\n")).toContain("Constraints: read-only; skim only.");

    // Expanded result: no run/operation UUIDs; transcript on its own elided line.
    const expandedResult = renderResultLayout({ action: "close", id: "#1" }, resultDetails, true);
    expect(expandedResult.join("\n")).not.toContain("run " + "r".repeat(8));
    expect(expandedResult.join("\n")).not.toContain("/Users/");
    const transcriptLines = expandedResult.filter((line) => line.trimStart().startsWith("transcript "));
    expect(transcriptLines).toHaveLength(1);
    // Head keeps the collapsed-home directory prefix, tail keeps the filename.
    expect(transcriptLines[0]).toMatch(/^\s*transcript ~\/tools\/dotfiles\/.*….*deadbeef\.jsonl$/);
    expect(transcriptLines[0].length).toBeLessThanOrEqual(120);

    // Collapsed close result renders empty (the card carries the state).
    const closedCollapsed = renderResultLayout({ action: "close", id: "#1" }, { ...resultDetails, status: "closed" }, false);
    expect(closedCollapsed.filter((line) => line.length > 0)).toHaveLength(0);
  });

  test("hydrates run/start titles only after authoritative row-local index details", async () => {
    const tool = setup().extension.getTool();
    const theme = { fg: (_color: string, text: string) => text, bold: (text: string) => text };
    const args = { action: "run", agent: "scout", task: "Inspect", cwd: "/workspace", deadlineMs: 60_000 };
    const renderCall = (state: Record<string, unknown>, expanded = false) =>
      tool.renderCall!(args as never, theme, {
        args,
        isError: false,
        state,
        expanded,
        invalidate: vi.fn(),
      } as never).render(200).map((line) => line.trimEnd()).join("\n");
    const renderResult = (
      state: Record<string, unknown>,
      details: Record<string, unknown>,
      isPartial: boolean,
      invalidate: () => void,
    ) => tool.renderResult!(
      { content: [], details },
      { expanded: false, isPartial },
      theme,
      { args, isError: false, state, invalidate } as never,
    );

    const state: Record<string, unknown> = {};
    const invalidate = vi.fn();
    // The first call render cannot reserve or invent an index.
    expect(renderCall(state)).not.toContain("#1");
    expect(state).not.toHaveProperty("runtimeIndex");

    // Initial, partial, and final updates all share this row state, but schedule
    // only the one repaint that makes the call title pick up its index.
    renderResult(state, { index: 1, status: "starting" }, false, invalidate);
    renderResult(state, { index: 1, status: "running" }, true, invalidate);
    renderResult(state, { index: 1, status: "completed" }, false, invalidate);
    expect(invalidate).not.toHaveBeenCalled();
    await Promise.resolve();
    expect(invalidate).toHaveBeenCalledOnce();
    expect(renderCall(state)).toContain("#1 scout");
    expect(renderCall(state, true)).toContain("#1 scout");
    expect(state).toMatchObject({ runtimeIndex: 1, runtimeIndexInvalidateQueued: false });

    // Persisted final rows restore both a direct index and a snapshot-only index.
    const directState: Record<string, unknown> = {};
    const directInvalidate = vi.fn();
    renderResult(directState, { index: 8, status: "completed", summary: "Done" }, false, directInvalidate);
    await Promise.resolve();
    expect(directInvalidate).toHaveBeenCalledOnce();
    expect(renderCall(directState)).toContain("#8 scout");

    const snapshotState: Record<string, unknown> = {};
    const snapshotInvalidate = vi.fn();
    renderResult(snapshotState, { snapshot: { index: 9, status: "completed", summary: "Done" } }, false, snapshotInvalidate);
    await Promise.resolve();
    expect(snapshotInvalidate).toHaveBeenCalledOnce();
    expect(renderCall(snapshotState)).toContain("#9 scout");

    const disposedState: Record<string, unknown> = {};
    const disposedInvalidate = vi.fn(() => { throw new Error("row disposed"); });
    renderResult(disposedState, { index: 10, status: "completed" }, false, disposedInvalidate);
    await Promise.resolve();
    expect(disposedInvalidate).toHaveBeenCalledOnce();
  });

  test("keeps rendered runtime indexes isolated, immutable, and valid", async () => {
    const tool = setup().extension.getTool();
    const theme = { fg: (_color: string, text: string) => text, bold: (text: string) => text };
    const args = { action: "start", agent: "scout", task: "Inspect" };
    const renderCall = (state: Record<string, unknown>) =>
      tool.renderCall!(args as never, theme, {
        args,
        isError: false,
        state,
        invalidate: vi.fn(),
      } as never).render(200).map((line) => line.trimEnd()).join("\n");
    const renderResult = (
      state: Record<string, unknown>,
      details: Record<string, unknown>,
      invalidate: () => void,
    ) => tool.renderResult!(
      { content: [], details },
      { expanded: false, isPartial: false },
      theme,
      { args, isError: false, state, invalidate } as never,
    );

    const invalidState: Record<string, unknown> = {};
    const invalidInvalidate = vi.fn();
    for (const index of [0, -1, 1.5, Number.POSITIVE_INFINITY, Number.MAX_SAFE_INTEGER + 1, "2"]) {
      renderResult(invalidState, { index, status: "completed" }, invalidInvalidate);
    }
    await Promise.resolve();
    expect(invalidState).not.toHaveProperty("runtimeIndex");
    expect(invalidInvalidate).not.toHaveBeenCalled();
    expect(renderCall(invalidState)).not.toContain("#");

    const firstState: Record<string, unknown> = {};
    const secondState: Record<string, unknown> = {};
    const firstInvalidate = vi.fn();
    const secondInvalidate = vi.fn();
    // Direct valid details win over a conflicting snapshot; an invalid direct
    // field falls back to the persisted snapshot index for another row.
    renderResult(firstState, { index: 3, snapshot: { index: 30, status: "completed" } }, firstInvalidate);
    renderResult(secondState, { index: 0, snapshot: { index: 4, status: "completed" } }, secondInvalidate);
    renderResult(firstState, { index: 5, status: "completed" }, firstInvalidate);
    await Promise.resolve();
    expect(firstInvalidate).toHaveBeenCalledOnce();
    expect(secondInvalidate).toHaveBeenCalledOnce();
    expect(firstState).toMatchObject({ runtimeIndex: 3, runtimeIndexInvalidateQueued: false });
    expect(secondState).toMatchObject({ runtimeIndex: 4, runtimeIndexInvalidateQueued: false });
    expect(renderCall(firstState)).toContain("#3 scout");
    expect(renderCall(secondState)).toContain("#4 scout");

    // Absent, invalid, and conflicting later values leave the established index
    // untouched and cannot trigger another recursive repaint.
    renderResult(firstState, { status: "completed" }, firstInvalidate);
    renderResult(firstState, { index: -6, snapshot: { index: 6, status: "completed" } }, firstInvalidate);
    renderResult(firstState, { index: 7, status: "completed" }, firstInvalidate);
    await Promise.resolve();
    expect(firstState).toMatchObject({ runtimeIndex: 3, runtimeIndexInvalidateQueued: false });
    expect(firstInvalidate).toHaveBeenCalledOnce();
  });

  test("renders human-facing call targets without undefined or full UUIDs", () => {
    const tool = setup().extension.getTool();
    const theme = { fg: (_color: string, text: string) => text, bold: (text: string) => text };
    const renderCall = (args: Record<string, unknown>, expanded = true) =>
      tool.renderCall!(args as never, theme, { args: {}, isError: false, state: {}, expanded, invalidate: vi.fn() } as never)
        .render(200).map((line) => line.trimEnd()).join("\n");
    const runId = "12345678-1234-4123-8123-123456789abc";
    const operationId = "abcdef12-1234-4123-8123-123456789abc";

    expect(renderCall({ action: "wait", operationId })).toBe("◷ wait · all bg");
    expect(renderCall({ action: "wait", id: "#7", operationId })).toBe("◷ wait · #7");
    expect(renderCall({ action: "status" })).toBe("● status · all runtimes");
    expect(renderCall({ action: "status", id: "#7" })).toBe("● status · #7");

    const uuidBackedCalls = [
      renderCall({ action: "wait", id: runId, operationId }),
      renderCall({ action: "status", id: runId }),
      renderCall({ action: "close", id: runId }),
      renderCall({ action: "interrupt", id: runId, expectedOperationId: operationId }),
      renderCall({ action: "send", id: runId, mode: "steer", message: "Redirect", expectedOperationId: operationId }),
    ];
    expect(uuidBackedCalls.map((rendered) => rendered.split("\n")[0])).toEqual([
      "◷ wait · 12345678",
      "● status · 12345678",
      "close · 12345678",
      "■ interrupt · 12345678",
      "↪ steer · 12345678",
    ]);
    for (const rendered of uuidBackedCalls) {
      expect(rendered).toContain("12345678");
      expect(rendered).not.toContain(runId);
      expect(rendered).not.toContain(operationId);
    }
  });

  test("publishes a provider-compatible root object schema and validates action fields", async () => {
    const env = setup();
    expect(env.extension.getTool().parameters).toMatchObject({ type: "object" });
    expect(env.extension.getTool().parameters).not.toHaveProperty("anyOf");
    expect((env.extension.getTool().parameters as { properties: { deadlineMs: object } }).properties.deadlineMs)
      .not.toHaveProperty("default");
    expect(await env.invoke({ action: "run" })).toMatchObject({
      isError: true,
      details: { error: "agent is required for subagent run" },
    });
    expect(await env.extension.getTool().execute(
      "tool-call",
      { action: "run", agent: "scout", task: "Inspect" } as never,
      undefined,
      undefined,
      context(env.root),
    )).toMatchObject({
      isError: true,
      details: { error: "deadlineMs is required for subagent run" },
    });
    expect(await env.invoke({ action: "send", id: "runtime", mode: "steer", message: "redirect" })).toMatchObject({
      isError: true,
      details: { error: "expectedOperationId is required for subagent send" },
    });
  });

  test("discovers agents and builds a canonical, guided work order with declared tools", async () => {
    const env = setup({ ids: ["run-fixed", "operation-fixed"] });
    writeFileSync(join(env.root, "AGENTS.md"), "Project guidance");
    const running = env.invoke({ action: "run", agent: "scout", task: "Find auth", deadlineMs: 1_000 });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    const options = env.fake.controllers[0].starts[0].options;
    const canonicalRoot = realpathSync(env.root);
    expect(env.extension.getTool().description).toContain("scout: Inspect files");
    expect(env.extension.getTool().description).toContain("startup catalog");
    expect(env.extension.getTool().description).toContain("call list only when the catalog may be stale");
    expect(env.extension.getTool().description).toContain("parent owns task decomposition");
    expect(env.extension.getTool().description).toContain("without repeating the same searches or reads");
    expect(env.extension.getTool().description).not.toContain("NEVER list");
    expect(env.extension.getTool().description).not.toContain("MANDATORY BEFORE any read/bash");
    expect(env.extension.getTool().promptSnippet).toContain("Classify by task boundary");
    expect(env.extension.getTool().promptSnippet).toContain("single-file lookups");
    expect(env.extension.getTool().promptSnippet).toContain("routine re-runs");
    expect(env.extension.getTool().promptSnippet).toContain("default to startup catalog");
    expect(env.extension.getTool().promptSnippet).toContain("multi-file discovery->scout");
    expect(env.extension.getTool().promptSnippet).not.toContain("NEVER list");
    expect(env.extension.getTool().promptGuidelines).toEqual(expect.arrayContaining([
      expect.stringContaining("startup catalog"),
      expect.stringContaining("call list only when the catalog may be stale"),
      expect.stringContaining("Classify by task boundary"),
      expect.stringContaining("single-file lookups"),
      expect.stringContaining("catalog description and declared capabilities"),
      expect.stringContaining("decompose the bounded work instead of forwarding the raw user prompt"),
      expect.stringContaining("the child has fresh context"),
      expect.stringContaining("Outcome, Scope, Starting evidence"),
      expect.stringContaining("action:run for bounded one-shots"),
      expect.stringContaining("deadlineMs"),
      expect.stringContaining("separate action:run calls in the same turn"),
      expect.stringContaining("Treat a subagent result as a handoff, not proof"),
      expect.stringContaining("do not repeat the same searches"),
    ]));
    expect(options).toMatchObject({
      cwd: canonicalRoot,
      runId: "run-fixed",
      operationId: "operation-fixed",
      parentSessionId: "parent-session",
      agent: { name: "scout", tools: ["read", "grep"] },
      workOrder: {
        goal: "Find auth",
        scope: [canonicalRoot],
        constraints: expect.arrayContaining(["Do not delegate to another agent."]),
        returnFormat: expect.stringContaining("concise result"),
        projectGuidance: [`Guidance from ${join(canonicalRoot, "AGENTS.md")}:\nProject guidance`],
      },
    });
    env.fake.controllers[0].settle(0, "completed", "Located auth.");
    const settledRun = await running;
    expect(settledRun.details).toMatchObject({ status: "completed", summary: "Located auth." });
    expect((settledRun.details as { elapsedMs?: unknown }).elapsedMs).toBeTypeOf("number");
    expect(env.fake.controllers[0].closeCalls).toBe(1);
  });

  test("applies startup settings overrides to catalog list and spawn options", async () => {
    const settingsPath = join(temporaryDirectory("pi-subagent-settings-"), "settings.json");
    writeFileSync(settingsPath, JSON.stringify({
      subagents: {
        scout: {
          model: "settings/model",
          thinking: "xhigh",
          description: "Settings description",
        },
      },
    }));
    const env = setup({ ids: ["run-fixed", "operation-fixed"], settingsPath });

    expect(env.extension.getTool().description).toContain("scout: Settings description");
    const listed = await env.invoke({ action: "list" });
    expect((listed.content[0] as { text: string }).text).toContain("scout: Settings description");
    expect(listed.details).toMatchObject({
      agents: [{ name: "scout", description: "Settings description", model: "settings/model", thinking: "xhigh" }],
    });

    const run = env.invoke({ action: "run", agent: "scout", task: "Inspect" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    expect(env.fake.controllers[0].starts[0].options.agent).toMatchObject({
      name: "scout",
      model: "settings/model",
      thinking: "xhigh",
      description: "Settings description",
    });
    env.fake.controllers[0].settle();
    await run;
  });

  test("reapplies startup settings overrides after list rediscovers agents", async () => {
    const settingsPath = join(temporaryDirectory("pi-subagent-settings-"), "settings.json");
    writeFileSync(settingsPath, JSON.stringify({ subagents: { reviewer: { description: "Settings review", thinking: "high" } } }));
    const env = setup({ settingsPath });
    writeAgent(env.agents, "reviewer", "File review");

    const listed = await env.invoke({ action: "list" });

    expect((listed.content[0] as { text: string }).text).toContain("reviewer: Settings review");
    expect(listed.details).toMatchObject({
      agents: expect.arrayContaining([
        expect.objectContaining({ name: "reviewer", description: "Settings review", thinking: "high" }),
      ]),
    });
  });

  test("refreshes registry only on list and reports unknown agents without creating a controller", async () => {
    const env = setup();
    writeAgent(env.agents, "reviewer", "Review code");
    expect((await env.invoke({ action: "run", agent: "reviewer", task: "Review" })).isError).toBe(true);
    const listed = await env.invoke({ action: "list" });
    expect((listed.content[0] as { text: string }).text).toContain("reviewer: Review code");
    const run = env.invoke({ action: "run", agent: "reviewer", task: "Review" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    env.fake.controllers[0].settle();
    await run;
    const missing = await env.invoke({ action: "run", agent: "missing", task: "Nope" });
    expect(missing.isError).toBe(true);
    expect((missing.content[0] as { text: string }).text).toContain("Available agents: reviewer, scout");
    expect(env.fake.factory).toHaveBeenCalledOnce();
  });

  test("bounds escaped result serialization", async () => {
    const env = setup();
    const run = env.invoke({ action: "run", agent: "scout", task: "Inspect" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    env.fake.controllers[0].settle(0, "completed", "\\".repeat(32_000));
    const result = await run;
    const serialized = (result.content[0] as { text: string }).text;
    expect(serialized.length).toBeLessThanOrEqual(32_000);
    expect(JSON.parse(serialized)).toMatchObject({ status: "completed" });
  });

  test("render UI distinguishes calls, running, timeout, interruption, completion, and registry", async () => {
    const env = setup();
    const tool = env.extension.getTool();
    const theme = { fg: (_color: string, text: string) => text, bold: (text: string) => text };
    const render = (args: Record<string, unknown>, details: Record<string, unknown>, partial = false) =>
      tool.renderResult!(
        { content: [{ type: "text", text: JSON.stringify(details) }], details },
        { expanded: false, isPartial: partial }, theme,
        { args, isError: false, state: {}, invalidate: vi.fn() },
      ).render(200).join("\n");
    const call = tool.renderCall!(
      { action: "run", agent: "scout", task: "one\ntwo\nthree\nfour\nfive\nsix\nseven" }, theme,
      { args: {}, isError: false, state: {}, invalidate: vi.fn() } as never,
    ).render(200).join("\n");
    // Collapsed: one-line summary title only, no task body.
    expect(call).toContain("scout");
    expect(call).toContain("— one");
    expect(call).not.toContain("two");
    expect(call).not.toContain("seven");
    const expandedCall = tool.renderCall!(
      { action: "run", agent: "scout", task: "one\ntwo\nthree" }, theme,
      { args: {}, isError: false, state: {}, expanded: true, invalidate: vi.fn() } as never,
    ).render(200).join("\n");
    expect(expandedCall).toContain("two");
    expect(expandedCall).toContain("three");
    const partialState = {};
    const partial = tool.renderResult!(
      { content: [{ type: "text", text: "grep completed; continuing…" }], details: {
        runId: "runtime", operationId: "operation", agent: "scout", status: "running",
      } },
      { expanded: false, isPartial: true }, theme,
      { args: { action: "run", agent: "scout", task: "Inspect" }, isError: false, state: partialState, invalidate: vi.fn() },
    ).render(200).join("\n");
    expect(partial.split("\n").map((l) => l.trimEnd()).join("\n").trim()).toBe("⠋ — grep completed; continuing…");
    expect(partial.match(/grep completed; continuing…/g)).toHaveLength(1);
    expect(partial).not.toContain("Running");
    const countdownState = {};
    const countdown = tool.renderResult!(
      { content: [{ type: "text", text: "working" }], details: {
        runId: "runtime", operationId: "operation", agent: "scout", status: "running",
      } },
      { expanded: false, isPartial: true }, theme,
      { args: { action: "run", agent: "scout", task: "Inspect", deadlineMs: 90_000 }, isError: false, state: countdownState, invalidate: vi.fn() },
    ).render(200).join("\n");
    expect(countdown).toMatch(/⠋ \d{2,3}s — working/);
    const followUpCountdown = tool.renderResult!(
      { content: [{ type: "text", text: "working" }], details: { runId: "r", operationId: "o", status: "running" } },
      { expanded: false, isPartial: true }, theme,
      { args: { action: "send", id: "r", mode: "follow_up", message: "Next", deadlineMs: 45_000 }, isError: false, state: {}, invalidate: vi.fn() },
    ).render(200).join("\n");
    expect(followUpCountdown).toMatch(/⠋ 4\ds — working/);
    const expiredState: Record<string, unknown> = { startedAt: Date.now() - 120_000 };
    const expired = tool.renderResult!(
      { content: [{ type: "text", text: "working" }], details: { status: "running" } },
      { expanded: false, isPartial: true }, theme,
      { args: { action: "run", agent: "scout", task: "Inspect", deadlineMs: 90_000 }, isError: false, state: expiredState, invalidate: vi.fn() },
    ).render(200).join("\n");
    expect(expired).toContain("⠋ 0s");
    const authoritativeState: Record<string, unknown> = {};
    const authoritative = tool.renderResult!(
      { content: [{ type: "text", text: "working" }], details: { status: "running", startedAt: Date.now() - 120_000 } },
      { expanded: false, isPartial: true }, theme,
      { args: { action: "run", agent: "scout", task: "Inspect", deadlineMs: 90_000 }, isError: false, state: authoritativeState, invalidate: vi.fn() },
    ).render(200).join("\n");
    expect(authoritative).toContain("⠋ 0s");
    const terminalState: Record<string, unknown> = {};
    tool.renderResult!(
      { content: [], details: { status: "running" } },
      { expanded: false, isPartial: true }, theme,
      { args: { action: "run", agent: "scout", task: "T" }, isError: false, state: terminalState, invalidate: vi.fn() },
    );
    expect(terminalState.spinnerTimer).toBeDefined();
    tool.renderResult!(
      { content: [{ type: "text", text: "ok" }], details: { status: "completed" } },
      { expanded: false, isPartial: false }, theme,
      { args: { action: "run", agent: "scout", task: "T" }, isError: false, state: terminalState, invalidate: vi.fn() },
    );
    expect(terminalState.spinnerTimer).toBeUndefined();
    tool.renderResult!(
      { content: [{ type: "text", text: "done" }], details: { status: "completed" } },
      { expanded: false, isPartial: false }, theme,
      { args: { action: "run", agent: "scout", task: "Inspect" }, isError: false, state: partialState, invalidate: vi.fn() },
    );
    expect(render({ action: "status", id: "runtime-123456789" }, {
      runId: "runtime-123456789",
      agent: "scout",
      status: "running",
      activeOperationId: "operation-123456789",
    })).toContain("● running");
    expect(render({ action: "run" }, {
      runId: "runtime-123456789", operationId: "operation-123456789", agent: "scout", status: "completed", summary: "Done",
    }).split("\n").map((l) => l.trimEnd()).join("\n").trimEnd()).toBe("✓ completed\nDone");
    expect(render({ action: "run" }, { status: "completed", summary: "Done", elapsedMs: 45_000 })).toContain("✓ completed · 45s");
    const expandedStatus = tool.renderResult!(
      { content: [{ type: "text", text: "" }], details: {
        runId: "runtime-123456789",
        agent: "scout",
        status: "running",
        activeOperationId: "operation-123456789",
      } },
      { expanded: true, isPartial: false }, theme,
      { args: { action: "status", id: "runtime-123456789" }, isError: false, state: {}, invalidate: vi.fn() },
    ).render(200).map((line) => line.trimEnd()).join("\n");
    // run/operation UUIDs are no longer displayed.
    expect(expandedStatus).not.toContain("runtime-123456789");
    expect(expandedStatus).not.toContain("operation-123456789");
    expect(expandedStatus).toContain("● running");
    expect(render({ action: "wait", id: "runtime", operationId: "operation" }, {
      reason: "timeout", snapshot: { status: "running", agent: "scout" },
    })).toContain("still running");
    expect(render({ action: "interrupt" }, { accepted: true })).toContain("Interrupt requested");
    expect(render({ action: "send", mode: "steer" }, { accepted: true })).toContain("Steering sent");
    expect(render({ action: "run" }, { status: "interrupted", summary: "Stopped" })).toContain("Interrupted");
    expect(render({ action: "run" }, { status: "completed", summary: "Done" })).toContain("completed");
    const listed = await env.invoke({ action: "list" });
    expect(tool.renderResult!(listed, { expanded: false, isPartial: false }, theme, {
      args: { action: "list" }, isError: false, state: {}, invalidate: vi.fn(),
    }).render(200).join("\n")).toContain("Registered agents");
  });

  test("plumbs the authoritative runtime index through updates and final response branches", async () => {
    const successEnv = setup({ ids: ["success-runtime", "success-operation"] });
    const updates: unknown[] = [];
    const success = successEnv.extension.getTool().execute(
      "tool-call",
      { action: "run", agent: "scout", task: "Inspect", deadlineMs: 60_000 } as never,
      undefined,
      (update) => { updates.push(update); },
      context(successEnv.root),
    );
    await vi.waitFor(() => expect(successEnv.fake.controllers[0]?.starts).toHaveLength(1));
    expect((updates[0] as { details: Record<string, unknown> }).details).toMatchObject({
      index: 1,
      status: "starting",
    });
    successEnv.fake.controllers[0].starts[0].options.onProgress?.("Inspecting files");
    expect((updates.at(-1) as { details: Record<string, unknown> }).details).toMatchObject({
      index: 1,
      status: "running",
    });
    // A child result cannot replace the runtime-owned session-local index.
    successEnv.fake.controllers[0].starts[0].result.resolve({
      runId: "success-runtime",
      operationId: "success-operation",
      processInstanceId: "process-1",
      agent: "scout",
      status: "completed",
      summary: "Done.",
      transcript: { sessionId: "child-session", sessionPath: "/sessions/child.jsonl" },
      index: 999,
    } as SubagentResult & { index: number });
    expect(await success).toMatchObject({
      isError: false,
      details: { index: 1, status: "completed" },
    });

    const failedEnv = setup({ ids: ["failed-runtime", "failed-operation"] });
    const failed = failedEnv.invoke({ action: "run", agent: "scout", task: "Fail" });
    await vi.waitFor(() => expect(failedEnv.fake.controllers[0]?.starts).toHaveLength(1));
    failedEnv.fake.controllers[0].settle(0, "failed", "Child failed.");
    expect(await failed).toMatchObject({
      isError: true,
      details: { index: 1, status: "failed" },
    });

    const crashEnv = setup({ ids: ["crash-runtime", "crash-operation"] });
    const crashed = crashEnv.invoke({ action: "run", agent: "scout", task: "Crash" });
    await vi.waitFor(() => expect(crashEnv.fake.controllers[0]?.starts).toHaveLength(1));
    crashEnv.fake.controllers[0].starts[0].result.reject(new Error("Child crashed"));
    expect(await crashed).toMatchObject({
      isError: true,
      details: { index: 1, status: "failed", error: "Child crashed" },
    });

    const startupEnv = setup({ ids: ["startup-runtime", "startup-operation"] });
    startupEnv.fake.factory.mockRejectedValueOnce(new Error("Startup crashed"));
    expect(await startupEnv.invoke({ action: "run", agent: "scout", task: "Start" })).toMatchObject({
      isError: true,
      details: { index: 1, status: "crashed", error: "Startup crashed" },
    });
  });

  test("start resolves only after acceptance, independently of settlement, then becomes idle", async () => {
    const env = setup({ autoAccept: false, ids: ["runtime", "operation"] });
    let resolved = false;
    const start = env.invoke({ action: "start", agent: "scout", task: "Inspect" }).then((value) => {
      resolved = true;
      return value;
    });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    await Promise.resolve();
    expect(resolved).toBe(false);
    env.fake.controllers[0].accept();
    const started = await start;
    expect(started.details).toMatchObject({ runId: "runtime", operationId: "operation", status: "running" });
    env.fake.controllers[0].settle();
    const waited = await env.invoke({ action: "wait", id: "runtime", operationId: "operation" });
    expect(waited.details).toMatchObject({ status: "completed" });
    expect((await env.invoke({ action: "status", id: "runtime" })).details).toMatchObject({ status: "idle" });
  });

  test("notifies the parent with compact structured and follow-up titles", async () => {
    const runId = "11111111-1111-4111-8111-111111111111";
    const operationId = "22222222-2222-4222-8222-222222222222";
    const task = [
      "# Delegated work",
      "Outcome: Inspect the subagent runtime lifecycle",
      "Scope: xdg_config/pi/agent/extensions/subagent",
      "Starting evidence: the old wake included the full work order.",
    ].join("\n");
    const env = setup({ ids: [runId, operationId, "follow-up", "interrupted"] });
    const started = await env.invoke({ action: "start", agent: "scout", task });
    env.fake.controllers[0].settle(0, "completed", "Located auth.\nWith supporting evidence.");
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(1));
    expect(env.extension.messages[0]).toMatchObject({
      message: {
        customType: SUBAGENT_COMPLETION_MESSAGE,
        display: true,
        content: expect.stringMatching(
          /^#1 scout · completed · \d+s — Inspect the subagent runtime lifecycle\n  idle · status\/follow-up\/close #1$/,
        ),
        details: {
          runId,
          operationId,
          agent: "scout",
          task,
          status: "completed",
          summary: "Located auth.\nWith supporting evidence.",
          runtimeStatus: "idle",
        },
      },
      options: { triggerTurn: true, deliverAs: "followUp" },
    });
    const wakeContent = env.extension.messages[0].message.content as string;
    expect(wakeContent.split("\n")).toHaveLength(2);
    expect(wakeContent).not.toContain("Outcome:");
    expect(wakeContent).not.toContain("Scope:");
    expect(wakeContent).not.toContain("Starting evidence:");
    expect(wakeContent).not.toContain(runId);
    expect(wakeContent).not.toContain(operationId);
    expect(wakeContent).not.toContain("Located auth.");

    const follow = await env.invoke({
      action: "send",
      id: (started.details as { runId: string }).runId,
      mode: "follow_up",
      message: "  Check   tests  \nScope: not part of the title",
    });
    env.fake.controllers[0].settle(1, "failed", "No complete final response.");
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(2));
    expect(env.extension.messages[1].message).toMatchObject({
      content: expect.stringMatching(
        /^#1 scout · failed · \d+s — Check tests\n  idle · status\/follow-up\/close #1$/,
      ),
      details: { operationId: (follow.details as { operationId: string }).operationId, status: "failed" },
    });

    const next = await env.invoke({ action: "send", id: runId, mode: "follow_up", message: "Wait" });
    await env.invoke({
      action: "interrupt",
      id: runId,
      expectedOperationId: (next.details as { operationId: string }).operationId,
    });
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(3));
    expect(env.extension.messages[2].message).toMatchObject({
      content: expect.stringMatching(
        /^#1 scout · interrupted · \d+s — Wait\n  idle · status\/follow-up\/close #1$/,
      ),
      details: { status: "interrupted" },
    });

    const renderer = env.extension.messageRenderers.get(SUBAGENT_COMPLETION_MESSAGE)!;
    const completionMessage = {
      role: "custom" as const,
      timestamp: Date.now(),
      ...(env.extension.messages[0].message as never),
    };
    const collapsed = renderer(
      completionMessage,
      { expanded: false, outputPad: 0 },
      { fg: (_color: string, text: string) => text, bold: (text: string) => text, bg: (_color: string, text: string) => text } as never,
    )!.render(240).map((line) => line.trimEnd()).join("\n");
    expect(collapsed).toContain("✓ completed · scout (#1) · Inspect the subagent runtime lifecycle");
    expect(collapsed).not.toContain("Outcome:");
    expect(collapsed).not.toContain("Scope:");

    const rendered = renderer(
      completionMessage,
      { expanded: true, outputPad: 0 },
      { fg: (_color: string, text: string) => text, bold: (text: string) => text, bg: (_color: string, text: string) => text } as never,
    )!.render(240).map((line) => line.trimEnd()).join("\n");
    expect(rendered).toContain("✓ completed · scout (#1)");
    expect(rendered).toContain("task: Inspect the subagent runtime lifecycle");
    expect(rendered).not.toContain("Outcome:");
    expect(rendered).not.toContain("Scope:");
    expect(rendered).toContain("Located auth.\n  With supporting evidence.");
    expect(rendered).toMatch(/  runtime idle · \d+s/);
    expect(rendered).not.toContain(runId);
    expect(rendered).not.toContain(operationId);
  });

  test("omits the completion title when the task has no meaningful non-heading line", async () => {
    const env = setup();
    await env.invoke({ action: "start", agent: "scout", task: "\n# Work order\n   " });
    env.fake.controllers[0].settle(0, "completed", "Done.");
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(1));

    const wakeContent = env.extension.messages[0].message.content as string;
    expect(wakeContent).toMatch(/^#1 scout · completed · \d+s\n  idle · status\/follow-up\/close #1$/);
    expect(wakeContent).not.toContain("—");
    expect(wakeContent.split("\n")).toHaveLength(2);
  });

  test("batches background settlements into one card when the last one finishes", async () => {
    const env = setup({ ids: ["bg-a", "op-a", "bg-b", "op-b"] });
    await env.invoke({ action: "start", agent: "scout", task: "First" });
    await env.invoke({ action: "start", agent: "scout", task: "Second" });

    env.fake.controllers[0].settle(0, "completed", "Alpha report.");
    expect(env.extension.messages).toHaveLength(0); // sibling still running: stay silent

    env.fake.controllers[1].settle(0, "completed", "Beta report.");
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(1));
    const payload = env.extension.messages[0].message.details as { batch?: unknown[] };
    expect(payload.batch).toHaveLength(2);
    const blocks = (env.extension.messages[0].message.content as string).split("\n\n");
    expect(blocks).toHaveLength(3);
    expect(blocks[0]).toBe("2 background subagents settled:");
    expect(blocks[1]).toMatch(/^#1 scout · completed · \d+s — First\n  idle · status\/follow-up\/close #1$/);
    expect(blocks[2]).toMatch(/^#2 scout · completed · \d+s — Second\n  idle · status\/follow-up\/close #2$/);
  });

  test("failures notify immediately while successful siblings stay pending", async () => {
    const env = setup({ ids: ["bg-a", "op-a", "bg-b", "op-b"] });
    await env.invoke({ action: "start", agent: "scout", task: "First" });
    await env.invoke({ action: "start", agent: "scout", task: "Second" });

    env.fake.controllers[1].settle(0, "failed", "Boom.");
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(1));
    expect(env.extension.messages[0].message.details).toMatchObject({ status: "failed" });

    env.fake.controllers[0].settle(0, "completed", "Alpha.");
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(2));
    expect(env.extension.messages[1].message.details).toMatchObject({ status: "completed" });
  });

  test("targets runtimes by short session-local index", async () => {
    const env = setup({ ids: ["bg-a", "op-a"] });
    await env.invoke({ action: "start", agent: "scout", task: "First" });

    const listed = await env.invoke({ action: "status" });
    expect((listed.details as { runtimes: Array<{ index: number }> }).runtimes[0].index).toBe(1);

    const byHash = await env.invoke({ action: "status", id: "#1" });
    expect((byHash.details as { runId: string }).runId).toBe("bg-a");
    const byPlain = await env.invoke({ action: "status", id: "1" });
    expect((byPlain.details as { runId: string }).runId).toBe("bg-a");

    const closed = await env.invoke({ action: "close", id: "#1" });
    expect(closed.details).toMatchObject({ index: 1, status: "closed" });
  });

  test("status without an id enumerates every runtime with its mode", async () => {
    const env = setup({ ids: ["bg-a", "op-a", "bg-b", "op-b"] });
    await env.invoke({ action: "start", agent: "scout", task: "First" });
    await env.invoke({ action: "start", agent: "scout", task: "Second" });

    const listed = await env.invoke({ action: "status" });
    const runtimes = (listed.details as { runtimes: Array<{ mode: string; status: string }> }).runtimes;
    expect(runtimes).toHaveLength(2);
    expect(runtimes.every((entry) => entry.mode === "background" && entry.status === "running")).toBe(true);
  });

  test("wait without an operationId joins all outstanding background work", async () => {
    const env = setup({ ids: ["bg-a", "op-a", "bg-b", "op-b"] });
    await env.invoke({ action: "start", agent: "scout", task: "First" });
    await env.invoke({ action: "start", agent: "scout", task: "Second" });

    const join = env.invoke({ action: "wait", timeoutMs: 10_000 });
    await new Promise((resolveSleep) => setTimeout(resolveSleep, 25));
    env.fake.controllers[0].settle(0, "completed", "Alpha report.");
    env.fake.controllers[1].settle(0, "completed", "Beta report.");
    const joined = await join;
    const results = (joined.details as { results: Array<{ status: string; summary: string }> }).results;
    expect(results).toHaveLength(2);
    expect(results.map((result) => result.summary)).toEqual(expect.arrayContaining(["Alpha report.", "Beta report."]));

    // The last settle also flushed one aggregated completion card.
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(1));
    expect(env.extension.messages[0].message.content).toContain("2 background subagents settled");
  });

  test("does not notify for one-shot runs or operations settled by close and shutdown", async () => {
    const runEnv = setup();
    const run = runEnv.invoke({ action: "run", agent: "scout", task: "Once" });
    await vi.waitFor(() => expect(runEnv.fake.controllers[0]?.starts).toHaveLength(1));
    runEnv.fake.controllers[0].settle();
    await run;
    expect(runEnv.extension.messages).toEqual([]);

    const closeEnv = setup();
    const active = await closeEnv.invoke({ action: "start", agent: "scout", task: "Wait" });
    await closeEnv.invoke({ action: "close", id: (active.details as { runId: string }).runId });
    await Promise.resolve();
    expect(closeEnv.extension.messages).toEqual([]);

    const shutdownEnv = setup();
    await shutdownEnv.invoke({ action: "start", agent: "scout", task: "Wait" });
    await shutdownEnv.extension.shutdown();
    await Promise.resolve();
    expect(shutdownEnv.extension.messages).toEqual([]);
  });

  test("pre-acceptance interrupt conflicts and close finishes as closed", async () => {
    const env = setup({ autoAccept: false, ids: ["runtime", "operation"] });
    const starting = env.invoke({ action: "start", agent: "scout", task: "Inspect" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    expect((await env.invoke({
      action: "interrupt",
      id: "runtime",
      expectedOperationId: "operation",
    })).details).toMatchObject({ accepted: false, conflict: true });
    expect(env.fake.controllers[0].interruptCalls).toEqual([]);
    expect((await env.invoke({ action: "close", id: "runtime" })).details).toMatchObject({ status: "closed" });
    expect(await starting).toMatchObject({ isError: true });
  });

  test("start and send retain their operation IDs when settlement wins the acceptance race", async () => {
    const env = setup({ autoAccept: false, ids: ["runtime", "initial", "follow-up"] });
    const starting = env.invoke({ action: "start", agent: "scout", task: "Initial" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    env.fake.controllers[0].settle(0);
    await Promise.resolve();
    expect(env.extension.messages).toEqual([]);
    env.fake.controllers[0].accept(0);
    expect((await starting).details).toMatchObject({
      runId: "runtime",
      operationId: "initial",
      status: "idle",
    });
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(1));

    const sending = env.invoke({ action: "send", id: "runtime", mode: "follow_up", message: "Again" });
    await vi.waitFor(() => expect(env.fake.controllers[0].starts).toHaveLength(2));
    env.fake.controllers[0].settle(1);
    await Promise.resolve();
    expect(env.extension.messages).toHaveLength(1);
    env.fake.controllers[0].accept(1);
    expect((await sending).details).toMatchObject({
      runId: "runtime",
      operationId: "follow-up",
      status: "idle",
    });
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(2));
  });

  test("does not notify when acceptance rejects after result settlement", async () => {
    const env = setup({ autoAccept: false });
    const starting = env.invoke({ action: "start", agent: "scout", task: "Initial" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    env.fake.controllers[0].settle();
    env.fake.controllers[0].starts[0].accepted.reject(new Error("Prompt rejected"));
    expect(await starting).toMatchObject({ isError: true });
    await Promise.resolve();
    expect(env.extension.messages).toEqual([]);
  });

  test("two follow-ups reuse one controller, process, runtime, and transcript session", async () => {
    const env = setup();
    const initial = await startIdle(env);
    const first = await env.invoke({ action: "send", id: initial.runId, mode: "follow_up", message: "First" });
    const firstId = (first.details as { operationId: string }).operationId;
    env.fake.controllers[0].settle(1);
    await env.invoke({ action: "wait", id: initial.runId, operationId: firstId });
    const second = await env.invoke({ action: "send", id: initial.runId, mode: "follow_up", message: "Second" });
    const secondId = (second.details as { operationId: string }).operationId;
    expect(env.fake.factory).toHaveBeenCalledOnce();
    expect(env.fake.controllers[0].starts.map((call) => call.options.runId)).toEqual([initial.runId, initial.runId, initial.runId]);
    expect(env.fake.controllers[0].starts.map((call) => call.options.workOrder.goal)).toEqual(["Initial", "First", "Second"]);
    expect(second.details).toMatchObject({ processInstanceId: "process-1", transcript: { sessionId: "child-session" } });
    env.fake.controllers[0].settle(2);
    await env.invoke({ action: "wait", id: initial.runId, operationId: secondId });
  });

  test("follow_up while running fails fast without queueing (idle-only)", async () => {
    const env = setup({ ids: ["runtime", "initial", "queued"] });
    const started = await env.invoke({ action: "start", agent: "scout", task: "Wait" });
    const { runId, operationId } = started.details as { runId: string; operationId: string };
    const queued = await env.invoke({ action: "send", id: runId, mode: "follow_up", message: "Next" });
    expect(queued).toMatchObject({ isError: true, details: { accepted: false, conflict: true } });
    expect(queued.details).toMatchObject({ error: expect.stringContaining("cannot accept") });
    expect(env.fake.controllers[0].starts).toHaveLength(1);
    const timeout = await env.invoke({ action: "wait", id: runId, operationId, timeoutMs: 1 });
    expect(timeout.details).toMatchObject({ reason: "timeout", snapshot: { status: "running" } });
    env.fake.controllers[0].settle();
    await env.invoke({ action: "wait", id: runId, operationId });
    const afterIdle = await env.invoke({ action: "send", id: runId, mode: "follow_up", message: "After idle" });
    expect(afterIdle.details).toMatchObject({ operationId: expect.any(String) });
    expect(env.fake.controllers[0].starts).toHaveLength(2);
    expect(env.fake.controllers[0].starts[1].options).toMatchObject({ workOrder: { goal: "After idle" } });
  });

  test("steers only the expected accepted active operation without creating a turn", async () => {
    const env = setup({ ids: ["runtime", "operation"] });
    const started = await env.invoke({ action: "start", agent: "scout", task: "Inspect" });
    const { runId, operationId, revision } = started.details as { runId: string; operationId: string; revision: number };
    const stale = await env.invoke({
      action: "send", id: runId, mode: "steer", expectedOperationId: "stale", message: "Stop searching docs",
    });
    expect(stale.details).toMatchObject({ accepted: false, conflict: true });
    const steered = await env.invoke({
      action: "send", id: runId, mode: "steer", expectedOperationId: operationId, message: "Focus on tests",
    });
    expect(steered.details).toMatchObject({ accepted: true, snapshot: { activeOperationId: operationId } });
    expect(env.fake.controllers[0].steerCalls).toEqual([{ operationId, message: "Focus on tests" }]);
    expect(env.fake.controllers[0].starts).toHaveLength(1);
    expect((steered.details as { snapshot: { revision: number } }).snapshot.revision).toBeGreaterThan(revision);
    env.fake.controllers[0].settle();
    await env.invoke({ action: "wait", id: runId, operationId });
    expect((await env.invoke({
      action: "send", id: runId, mode: "steer", expectedOperationId: operationId, message: "Late",
    })).details).toMatchObject({ accepted: false, conflict: true });
  });

  test("interrupt settles active operation and follow_up can be sent after idle", async () => {
    const env = setup({ ids: ["runtime", "active", "follow"] });
    const started = await env.invoke({ action: "start", agent: "scout", task: "Wait" });
    const before = await env.invoke({ action: "send", id: "runtime", mode: "follow_up", message: "Recover" });
    expect(before).toMatchObject({ isError: true, details: { conflict: true } });
    await env.invoke({ action: "interrupt", id: "runtime", expectedOperationId: "active" });
    await vi.waitFor(() => expect(env.fake.controllers[0].starts).toHaveLength(1));
    expect((await env.invoke({ action: "status", id: "runtime" })).details).toMatchObject({
      lastSettledOperation: { operationId: "active", status: "interrupted" },
    });
    const follow = await env.invoke({ action: "send", id: "runtime", mode: "follow_up", message: "Recover after" });
    expect(follow.details).toMatchObject({ operationId: "follow" });
    expect(env.fake.controllers[0].starts).toHaveLength(2);
    expect((started.details as { runId: string }).runId).toBe("runtime");
  });

  test("close does not create queued work and remains idle-only", async () => {
    const env = setup({ ids: ["runtime", "active"] });
    await env.invoke({ action: "start", agent: "scout", task: "Wait" });
    const attempt = await env.invoke({ action: "send", id: "runtime", mode: "follow_up", message: "Never queued" });
    expect(attempt).toMatchObject({ isError: true });
    const closing = await env.invoke({ action: "close", id: "runtime" });
    expect(closing.details).toMatchObject({ status: "closed" });
    expect(env.fake.controllers[0].starts).toHaveLength(1);
    expect(env.extension.messages).toEqual([]);
  });

  test("controller crash fails active work", async () => {
    const env = setup({ ids: ["runtime", "active"] });
    await env.invoke({ action: "start", agent: "scout", task: "Wait" });
    const attempt = await env.invoke({ action: "send", id: "runtime", mode: "follow_up", message: "Never queued" });
    expect(attempt).toMatchObject({ isError: true });
    env.fake.controllers[0].fail(new Error("Process exited"));
    await vi.waitFor(() => expect(env.fake.controllers[0].closeCalls).toBe(1));
    expect((await env.invoke({ action: "wait", id: "runtime", operationId: "active" })).details)
      .toMatchObject({ status: "failed" });
    expect((await env.invoke({ action: "status", id: "runtime" })).details)
      .toMatchObject({ status: "crashed" });
  });

  test("shutdown and multiple waiters observe the same active result", async () => {
    const env = setup({ ids: ["runtime", "active"] });
    await env.invoke({ action: "start", agent: "scout", task: "Wait" });
    const waiters = [
      env.invoke({ action: "wait", id: "runtime", operationId: "active" }),
      env.invoke({ action: "wait", id: "runtime", operationId: "active" }),
    ];
    await env.extension.shutdown();
    const results = await Promise.all(waiters);
    expect(results.map((result) => (result.details as { status: string }).status))
      .toEqual(["interrupted", "interrupted"]);
    expect(env.fake.controllers[0].starts).toHaveLength(1);
    expect(env.extension.messages).toEqual([]);
  });

  test("a rejected steer leaves the active runtime healthy", async () => {
    const env = setup({ ids: ["runtime", "active"] });
    await env.invoke({ action: "start", agent: "scout", task: "Wait" });
    vi.spyOn(env.fake.controllers[0], "steer").mockRejectedValueOnce(new Error("Steer rejected"));
    const rejected = await env.invoke({
      action: "send",
      id: "runtime",
      mode: "steer",
      expectedOperationId: "active",
      message: "Change direction",
    });
    expect(rejected).toMatchObject({
      isError: true,
      details: { accepted: false, error: "Steer rejected", snapshot: { status: "running" } },
    });
    env.fake.controllers[0].settle();
    expect((await env.invoke({ action: "wait", id: "runtime", operationId: "active" })).details)
      .toMatchObject({ status: "completed" });
  });

  test("interrupt settles the current operation authoritatively, then runtime is idle", async () => {
    const env = setup();
    const started = await env.invoke({ action: "start", agent: "scout", task: "Wait" });
    const { runId, operationId } = started.details as { runId: string; operationId: string };
    expect((await env.invoke({ action: "interrupt", id: runId, expectedOperationId: operationId })).details)
      .toMatchObject({ accepted: true });
    const waited = await env.invoke({ action: "wait", id: runId, operationId });
    expect(waited.details).toMatchObject({ status: "interrupted" });
    expect((await env.invoke({ action: "status", id: runId })).details).toMatchObject({ status: "idle" });
  });

  test("stale interrupt cannot affect a newer operation", async () => {
    const env = setup();
    const initial = await startIdle(env);
    const follow = await env.invoke({ action: "send", id: initial.runId, mode: "follow_up", message: "New" });
    const currentId = (follow.details as { operationId: string }).operationId;
    const stale = await env.invoke({ action: "interrupt", id: initial.runId, expectedOperationId: initial.operationId });
    expect(stale.details).toMatchObject({ accepted: false, conflict: true, snapshot: { activeOperationId: currentId } });
    expect(env.fake.controllers[0].interruptCalls).toEqual([]);
    env.fake.controllers[0].settle(1);
    await env.invoke({ action: "wait", id: initial.runId, operationId: currentId });
  });

  test("close handles idle and active runtimes and is idempotent", async () => {
    const idleEnv = setup();
    const idle = await startIdle(idleEnv);
    expect((await idleEnv.invoke({ action: "close", id: idle.runId })).details).toMatchObject({ status: "closed" });
    await idleEnv.invoke({ action: "close", id: idle.runId });
    expect(idleEnv.fake.controllers[0].closeCalls).toBe(1);

    const activeEnv = setup();
    const active = await activeEnv.invoke({ action: "start", agent: "scout", task: "Wait" });
    const activeIdentity = active.details as { runId: string; operationId: string };
    expect((await activeEnv.invoke({ action: "close", id: activeIdentity.runId })).details).toMatchObject({ status: "closed" });
    expect(activeEnv.fake.controllers[0].interruptCalls).toEqual([activeIdentity.operationId]);
    expect(activeEnv.fake.controllers[0].closeCalls).toBe(1);
  });

  test("one-shot run closes its runtime", async () => {
    const env = setup();
    const run = env.invoke({ action: "run", agent: "scout", task: "Once" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    env.fake.controllers[0].settle();
    expect((await run).details).toMatchObject({ status: "completed" });
    expect(env.fake.controllers[0].closeCalls).toBe(1);
  });

  test("shutdown closes persistent and foreground runtimes and rejects new runs", async () => {
    const env = setup();
    const persistent = await env.invoke({ action: "start", agent: "scout", task: "Persistent" });
    const foreground = env.invoke({ action: "run", agent: "scout", task: "Foreground" });
    await vi.waitFor(() => {
      expect(env.fake.controllers).toHaveLength(2);
      expect(env.fake.controllers[1].starts).toHaveLength(1);
    });
    await env.extension.shutdown();
    expect(env.fake.controllers.map((controller) => controller.closeCalls)).toEqual([1, 1]);
    expect(await foreground).toMatchObject({ details: { status: "interrupted" } });
    expect((await env.invoke({ action: "run", agent: "scout", task: "Late" })).isError).toBe(true);
    expect((await env.invoke({ action: "send", id: (persistent.details as { runId: string }).runId, mode: "follow_up", message: "Late" })).isError).toBe(true);
    expect(env.fake.factory).toHaveBeenCalledTimes(2);
  });

  test("shutdown waits for controller creation and prevents a late initial operation", async () => {
    const root = temporaryDirectory("pi-subagent-project-");
    const agents = temporaryDirectory("pi-subagent-agents-");
    writeAgent(agents);
    const extension = harness();
    const ready = deferred<SubagentController>();
    const controller = new FakeController("late-process");
    registerSubagentExtension(extension.pi, {
      agentDirectory: agents,
      controllerFactory: () => ready.promise,
      idFactory: (() => {
        const ids = ["late-runtime", "late-operation"];
        return () => ids.shift()!;
      })(),
    });
    const starting = extension.getTool().execute(
      "tool-call",
      { action: "start", agent: "scout", task: "Must not start", deadlineMs: 30_000 },
      undefined,
      undefined,
      context(root),
    );
    await Promise.resolve();
    let shutdownFinished = false;
    const shutdown = extension.shutdown().then(() => { shutdownFinished = true; });
    await Promise.resolve();
    expect(shutdownFinished).toBe(false);
    ready.resolve(controller);
    await shutdown;
    expect(controller.starts).toHaveLength(0);
    expect(controller.closeCalls).toBe(1);
    expect(await starting).toMatchObject({ isError: true });
  });

  test("reentrant shutdown from the starting update owns the eventual controller", async () => {
    const root = temporaryDirectory("pi-subagent-project-");
    const agents = temporaryDirectory("pi-subagent-agents-");
    writeAgent(agents);
    const extension = harness();
    const controller = new FakeController("reentrant-process");
    registerSubagentExtension(extension.pi, {
      agentDirectory: agents,
      controllerFactory: async () => controller,
      idFactory: (() => {
        const ids = ["reentrant-runtime", "reentrant-operation"];
        return () => ids.shift()!;
      })(),
    });
    let shutdown: Promise<void> | undefined;
    const starting = extension.getTool().execute(
      "tool-call",
      { action: "start", agent: "scout", task: "Must not start", deadlineMs: 30_000 },
      undefined,
      () => { shutdown ??= extension.shutdown(); },
      context(root),
    );
    await shutdown;
    expect(controller.starts).toHaveLength(0);
    expect(controller.closeCalls).toBe(1);
    expect(await starting).toMatchObject({ isError: true });
  });

  test("close still cleans up and releases capacity when interrupt fails", async () => {
    const env = setup();
    const starts = await Promise.all([1, 2, 3].map((n) =>
      env.invoke({ action: "start", agent: "scout", task: `Active ${n}` })));
    const first = starts[0].details as { runId: string };
    vi.spyOn(env.fake.controllers[0], "interrupt").mockRejectedValueOnce(new Error("Abort RPC failed"));
    const closed = await env.invoke({ action: "close", id: first.runId });
    expect(closed).toMatchObject({ isError: true, details: { status: "crashed", error: "Abort RPC failed" } });
    expect(env.fake.controllers[0].closeCalls).toBe(1);
    const replacement = await env.invoke({ action: "start", agent: "scout", task: "Replacement" });
    expect(replacement.isError).not.toBe(true);
    await env.extension.shutdown();
  });

  test("an idle controller failure crashes, cleans up, and releases its slot", async () => {
    const env = setup();
    const starts = await Promise.all([1, 2, 3].map((n) =>
      env.invoke({ action: "start", agent: "scout", task: `Warm ${n}` })));
    for (const [index, started] of starts.entries()) {
      env.fake.controllers[index].settle();
      const identity = started.details as { runId: string; operationId: string };
      await env.invoke({ action: "wait", id: identity.runId, operationId: identity.operationId });
    }
    env.fake.controllers[0].fail();
    await vi.waitFor(() => expect(env.fake.controllers[0].closeCalls).toBe(1));
    expect((await env.invoke({
      action: "status",
      id: (starts[0].details as { runId: string }).runId,
    })).details).toMatchObject({ status: "crashed" });
    expect((await env.invoke({ action: "start", agent: "scout", task: "Replacement" })).isError).not.toBe(true);
    await env.extension.shutdown();
  });

  test("an accepted active controller crash sends one failed notification", async () => {
    const env = setup();
    const started = await env.invoke({ action: "start", agent: "scout", task: "Crash" });
    env.fake.controllers[0].fail(new Error("Process exited"));
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(1));
    expect(env.extension.messages[0].message).toMatchObject({
      details: {
        runId: (started.details as { runId: string }).runId,
        status: "failed",
        summary: "Controller closed",
        runtimeStatus: "crashed",
      },
    });
    await Promise.resolve();
    expect(env.extension.messages).toHaveLength(1);
  });

  test("controller failure during explicit close remains notification-suppressed", async () => {
    const env = setup();
    const started = await env.invoke({ action: "start", agent: "scout", task: "Close" });
    const controller = env.fake.controllers[0];
    vi.spyOn(controller, "interrupt").mockImplementationOnce(async (operationId) => {
      controller.fail(new Error("Failed while closing"));
      return FakeController.prototype.interrupt.call(controller, operationId);
    });
    await env.invoke({ action: "close", id: (started.details as { runId: string }).runId });
    await Promise.resolve();
    expect(env.extension.messages).toEqual([]);
  });

  test("notification delivery failure cannot change operation state", async () => {
    const env = setup();
    vi.spyOn(env.extension.pi, "sendMessage").mockImplementation(() => { throw new Error("UI unavailable"); });
    const started = await env.invoke({ action: "start", agent: "scout", task: "Finish" });
    const identity = started.details as { runId: string; operationId: string };
    env.fake.controllers[0].settle();
    const waited = await env.invoke({ action: "wait", id: identity.runId, operationId: identity.operationId });
    expect(waited.details).toMatchObject({ status: "completed" });
    expect((await env.invoke({ action: "status", id: identity.runId })).details).toMatchObject({ status: "idle" });
  });

  test("bounds completion message and collapsed agent label", async () => {
    const root = temporaryDirectory("pi-subagent-project-");
    const agents = temporaryDirectory("pi-subagent-agents-");
    const agentName = `a${"b".repeat(399)}`;
    mkdirSync(agents, { recursive: true });
    writeFileSync(
      join(agents, "long-name.md"),
      `---\nname: ${agentName}\ndescription: Inspect files\ntools: [read]\n---\nInspect.\n`,
    );
    const fake = fakeFactory();
    const extension = harness();
    registerSubagentExtension(extension.pi, {
      agentDirectory: agents,
      controllerFactory: fake.factory,
      idFactory: (() => {
        const ids = ["runtime", "operation"];
        return () => ids.shift()!;
      })(),
    });
    const started = await extension.getTool().execute(
      "tool-call",
      { action: "start", agent: agentName, task: `Inspect ${"t".repeat(400)}\nScope: ignored`, deadlineMs: 30_000 },
      undefined,
      undefined,
      context(root),
    );
    fake.controllers[0].settle(0, "completed", "x".repeat(10_000));
    await vi.waitFor(() => expect(extension.messages).toHaveLength(1));
    const sent = extension.messages[0].message;
    const wakeContent = sent.content as string;
    const wakeLines = wakeContent.split("\n");
    expect(wakeLines).toHaveLength(2);
    expect(wakeLines[0]).toMatch(/^#1 ab+… · completed · \d+s — Inspect t+…$/);
    expect(wakeLines[0].length).toBeLessThanOrEqual(160);
    expect(wakeLines[1]).toBe("  idle · status/follow-up/close #1");
    expect(wakeContent).not.toContain("Scope:");
    expect(wakeContent).not.toContain("x".repeat(20));
    expect(wakeContent).not.toContain("runtime");
    expect(wakeContent).not.toContain("operation");
    expect((sent.details as { agent: string }).agent.length).toBeLessThanOrEqual(80);
    expect(started.details).toMatchObject({ runId: "runtime", operationId: "operation" });

    const renderer = extension.messageRenderers.get(SUBAGENT_COMPLETION_MESSAGE)!;
    const collapsed = renderer(
      { role: "custom", timestamp: Date.now(), ...(sent as never) },
      { expanded: false, outputPad: 0 },
      { fg: (_color: string, text: string) => text, bold: (text: string) => text, bg: (_color: string, text: string) => text } as never,
    )!.render(500).map((line) => line.trimEnd()).join("\n");
    expect(collapsed.length).toBeLessThanOrEqual(430);
    expect(collapsed).not.toContain("run runtime");

    const expanded = renderer(
      { role: "custom", timestamp: Date.now(), ...(sent as never) },
      { expanded: true, outputPad: 0 },
      { fg: (_color: string, text: string) => text, bold: (text: string) => text, bg: (_color: string, text: string) => text } as never,
    )!.render(500).map((line) => line.trimEnd()).join("\n");
    expect(expanded).toContain("[truncated]");
    expect(expanded.length).toBeLessThan(3_000);
    expect(expanded).toContain("runtime idle");
    expect(expanded).not.toContain("run runtime");
    expect(expanded).not.toContain("operation operation");
  });

  test("one-shot cleanup failure is reported instead of ordinary completion", async () => {
    const env = setup();
    const run = env.invoke({ action: "run", agent: "scout", task: "Once" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    vi.spyOn(env.fake.controllers[0], "close").mockRejectedValueOnce(new Error("Cleanup failed"));
    env.fake.controllers[0].settle();
    expect(await run).toMatchObject({ isError: true, details: { status: "crashed", error: "Cleanup failed" } });
  });

  test("three warm runtimes consume capacity and close releases a slot", async () => {
    const env = setup();
    const starts = await Promise.all([1, 2, 3].map((n) => env.invoke({ action: "start", agent: "scout", task: `Warm ${n}` })));
    for (const [index, started] of starts.entries()) {
      env.fake.controllers[index].settle();
      const identity = started.details as { runId: string; operationId: string };
      await env.invoke({ action: "wait", id: identity.runId, operationId: identity.operationId });
    }
    expect((await env.invoke({ action: "start", agent: "scout", task: "Fourth" })).isError).toBe(true);
    await env.invoke({ action: "close", id: (starts[0].details as { runId: string }).runId });
    const fourth = await env.invoke({ action: "start", agent: "scout", task: "Fourth" });
    expect(fourth.isError).not.toBe(true);
    expect(env.fake.controllers).toHaveLength(4);
    await env.extension.shutdown();
  });

  test("runtime revision increases monotonically across lifecycle transitions", async () => {
    const env = setup();
    const started = await env.invoke({ action: "start", agent: "scout", task: "Initial" });
    const identity = started.details as { runId: string; operationId: string; revision: number };
    const revisions = [identity.revision];
    env.fake.controllers[0].settle();
    await env.invoke({ action: "wait", id: identity.runId, operationId: identity.operationId });
    revisions.push(((await env.invoke({ action: "status", id: identity.runId })).details as { revision: number }).revision);
    const follow = await env.invoke({ action: "send", id: identity.runId, mode: "follow_up", message: "Again" });
    revisions.push((follow.details as { revision: number }).revision);
    env.fake.controllers[0].settle(1);
    await env.invoke({ action: "wait", id: identity.runId, operationId: (follow.details as { operationId: string }).operationId });
    revisions.push(((await env.invoke({ action: "status", id: identity.runId })).details as { revision: number }).revision);
    revisions.push(((await env.invoke({ action: "close", id: identity.runId })).details as { revision: number }).revision);
    expect(revisions).toEqual([...revisions].sort((a, b) => a - b));
    expect(new Set(revisions).size).toBe(revisions.length);
  });

  test("buildWakeWordSnippet omits absent roles when only scout is present", () => {
    const registry = { agents: [{ name: "scout" } as never], errors: [] };
    const snippet = buildWakeWordSnippet(registry);
    expect(snippet).toContain("multi-file discovery->scout");
    expect(snippet).not.toContain("->reviewer");
    expect(snippet).not.toContain("->researcher");
    expect(snippet).not.toContain("->tester");
    expect(snippet).not.toContain("->oracle");
    expect(snippet).not.toContain("->worker");
    expect(snippet).toContain("single-file lookups");
    expect(snippet).toContain("startup catalog");
  });

  test("buildWakeWordSnippet includes oracle when present and keeps stable order", () => {
    const registry = {
      agents: [
        { name: "worker" },
        { name: "oracle" },
        { name: "scout" },
        { name: "reviewer" },
        { name: "researcher" },
        { name: "tester" },
      ] as never[],
      errors: [],
    };
    const snippet = buildWakeWordSnippet(registry);
    expect(snippet).toContain("->oracle");
    expect(snippet).toContain("high-impact unresolved decision->oracle");
    const order = WAKE_BINDINGS.map((binding) => binding.role).filter((role) => snippet.includes(`->${role}`));
    expect(order).toEqual(["reviewer", "researcher", "tester", "scout", "oracle", "worker"]);
  });

  test("dynamic snippet contains no unknown role names", () => {
    const registry = {
      agents: [{ name: "scout" }, { name: "worker" }] as never[],
      errors: [],
    };
    const snippet = buildWakeWordSnippet(registry);
    const arrowRoles = [...snippet.matchAll(/->([a-z-]+)/g)].map((m) => m[1]);
    const allowed = new Set(WAKE_BINDINGS.map((b) => b.role));
    for (const role of arrowRoles) {
      expect(allowed.has(role as never)).toBe(true);
    }
    expect(arrowRoles).toEqual(expect.arrayContaining(["scout", "worker"]));
  });

  test("registered tool snippet and guidelines reflect list and direct-exception contract", async () => {
    const agents = temporaryDirectory("pi-subagent-agents-");
    writeAgent(agents, "scout", "Scout", "read, grep");
    writeAgent(agents, "oracle", "Oracle", "read, grep");
    const extension = harness();
    registerSubagentExtension(extension.pi, {
      agentDirectory: agents,
      controllerFactory: fakeFactory().factory,
      idFactory: () => "id",
      settingsPath: join(temporaryDirectory("pi-subagent-settings-"), "missing.json"),
    });
    const tool = extension.getTool();
    expect(tool.promptSnippet).toContain("->scout");
    expect(tool.promptSnippet).toContain("->oracle");
    expect(tool.promptSnippet).toContain("call list only if catalog may be stale");
    expect(tool.promptSnippet).toContain("single-source factual checks direct");
    expect(tool.promptSnippet).not.toContain("NEVER list");
    expect(tool.promptSnippet).not.toContain("BEFORE any read/bash");
    expect(tool.description).toContain("startup catalog");
    expect(tool.description).toContain("call list only when the catalog may be stale");
    expect(tool.description).toContain("single-file lookups");
    expect(tool.description).not.toContain("NEVER list");
    expect(tool.promptGuidelines.join("\n")).toContain("startup catalog");
    expect(tool.promptGuidelines.join("\n")).toContain("Classify by task boundary");
    expect(tool.promptGuidelines.join("\n")).toContain("single-source factual");
    expect(tool.promptGuidelines.join("\n")).not.toContain("NEVER call subagent list");
    expect(tool.promptGuidelines.join("\n")).not.toContain("BEFORE any read/bash");
  });
});
