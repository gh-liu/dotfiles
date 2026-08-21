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
import { loadSubagentOverrides, registerSubagentExtension } from "./index.ts";
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
    expect(env.extension.getTool().description).toContain("instead of chaining multiple parent web searches");
    expect(env.extension.getTool().description).toContain("before loading a parent research workflow or making parent web searches");
    expect(env.extension.getTool().description).toContain("without repeating the same searches or reads");
    expect(env.extension.getTool().description).toContain("parent self-review cannot satisfy independence");
    expect(env.extension.getTool().promptSnippet).toContain("MANDATORY BEFORE any read/bash");
    expect(env.extension.getTool().promptGuidelines).toEqual(expect.arrayContaining([
      expect.stringContaining("Mandatory delegation before direct work"),
      expect.stringContaining("Default to delegation for implementation-class work"),
      expect.stringContaining("catalog description and declared capabilities"),
      expect.stringContaining("multi-source external research"),
      expect.stringContaining("web_search"),
      expect.stringContaining("parent self-review is not independent"),
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
    expect((await running).details).toMatchObject({ status: "completed", summary: "Located auth." });
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
    expect(call).toContain("scout");
    expect(call).toContain("…");
    expect(call).not.toContain("seven");
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
    expect(countdown).toMatch(/⠋ 1m\d{2}s — working/);
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
    expect(expandedStatus).toContain("run runtime-123456789 · active operation-123456789");
    expect(render({ action: "wait", id: "runtime", operationId: "operation" }, {
      reason: "timeout", snapshot: { status: "running", agent: "scout" },
    })).toContain("still running");
    expect(render({ action: "interrupt" }, { accepted: true })).toContain("Interrupt requested");
    expect(render({ action: "send", id: "runtime", mode: "follow_up" }, {
      status: "running", queued: true, operationId: "queued-operation",
    })).toContain("Follow-up queued");
    expect(render({ action: "send", mode: "steer" }, { accepted: true })).toContain("Steering sent");
    expect(render({ action: "run" }, { status: "interrupted", summary: "Stopped" })).toContain("Interrupted");
    expect(render({ action: "run" }, { status: "completed", summary: "Done" })).toContain("completed");
    const listed = await env.invoke({ action: "list" });
    expect(tool.renderResult!(listed, { expanded: false, isPartial: false }, theme, {
      args: { action: "list" }, isError: false, state: {}, invalidate: vi.fn(),
    }).render(200).join("\n")).toContain("Registered agents");
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

  test("notifies the parent when persistent operations settle and renders a bounded status", async () => {
    const env = setup({ ids: ["runtime", "initial", "follow-up", "interrupted"] });
    const started = await env.invoke({ action: "start", agent: "scout", task: "Initial" });
    env.fake.controllers[0].settle(0, "completed", "Located auth.\nWith supporting evidence.");
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(1));
    expect(env.extension.messages[0]).toMatchObject({
      message: {
        customType: SUBAGENT_COMPLETION_MESSAGE,
        display: true,
        content: expect.stringContaining("Subagent scout completed operation initial in runtime runtime"),
        details: {
          runId: "runtime",
          operationId: "initial",
          agent: "scout",
          status: "completed",
          summary: "Located auth.\nWith supporting evidence.",
          runtimeStatus: "idle",
        },
      },
      options: { triggerTurn: true, deliverAs: "followUp" },
    });

    const follow = await env.invoke({
      action: "send",
      id: (started.details as { runId: string }).runId,
      mode: "follow_up",
      message: "Check tests",
    });
    env.fake.controllers[0].settle(1, "failed", "No complete final response.");
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(2));
    expect(env.extension.messages[1].message).toMatchObject({
      details: { operationId: (follow.details as { operationId: string }).operationId, status: "failed" },
    });

    const next = await env.invoke({ action: "send", id: "runtime", mode: "follow_up", message: "Wait" });
    await env.invoke({
      action: "interrupt",
      id: "runtime",
      expectedOperationId: (next.details as { operationId: string }).operationId,
    });
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(3));
    expect(env.extension.messages[2].message).toMatchObject({ details: { status: "interrupted" } });

    const renderer = env.extension.messageRenderers.get(SUBAGENT_COMPLETION_MESSAGE)!;
    const rendered = renderer(
      {
        role: "custom",
        timestamp: Date.now(),
        ...(env.extension.messages[0].message as never),
      },
      { expanded: true, outputPad: 0 },
      { fg: (_color: string, text: string) => text, bold: (text: string) => text, bg: (_color: string, text: string) => text } as never,
    )!.render(240).map((line) => line.trimEnd()).join("\n");
    expect(rendered).toContain("✓ completed · scout\n  task: Initial\n  Located auth.\n  With supporting evidence.");
    expect(rendered).toContain("run runtime · operation initial · runtime idle");
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
      { action: "start", agent: agentName, task: "Inspect", deadlineMs: 30_000 },
      undefined,
      undefined,
      context(root),
    );
    fake.controllers[0].settle(0, "completed", "x".repeat(10_000));
    await vi.waitFor(() => expect(extension.messages).toHaveLength(1));
    const sent = extension.messages[0].message;
    expect((sent.content as string).length).toBeLessThanOrEqual(3_000);
    expect((sent.details as { agent: string }).agent.length).toBeLessThanOrEqual(80);
    expect(started.details).toMatchObject({ runId: "runtime", operationId: "operation" });

    const renderer = extension.messageRenderers.get(SUBAGENT_COMPLETION_MESSAGE)!;
    const collapsed = renderer(
      { role: "custom", timestamp: Date.now(), ...(sent as never) },
      { expanded: false, outputPad: 0 },
      { fg: (_color: string, text: string) => text, bold: (text: string) => text, bg: (_color: string, text: string) => text } as never,
    )!.render(500).map((line) => line.trimEnd()).join("\n");
    expect(collapsed.length).toBeLessThanOrEqual(380);
    expect(collapsed).not.toContain("run runtime");
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
});
