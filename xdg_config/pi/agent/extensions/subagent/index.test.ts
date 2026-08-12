import { afterEach, describe, expect, test, vi } from "vitest";
import { mkdtempSync, mkdirSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import type { ExtensionAPI, ExtensionContext, ToolDefinition } from "@earendil-works/pi-coding-agent";
import { registerSubagentExtension } from "./index.ts";
import { SubagentCancellationError } from "./protocol.ts";
import type { SubagentExecutor, SubagentResult } from "./protocol.ts";

const temporaryDirectories: string[] = [];

afterEach(() => {
  vi.useRealTimers();
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

function temporaryDirectory(prefix: string): string {
  const directory = mkdtempSync(join(tmpdir(), prefix));
  temporaryDirectories.push(directory);
  return directory;
}

function writeScout(directory: string): void {
  mkdirSync(directory, { recursive: true });
  writeFileSync(
    join(directory, "scout.md"),
    "---\nname: scout\ndescription: Inspect files\ntools: [read, grep]\n---\nInspect without changes.\n",
  );
}

function writeReviewer(directory: string): void {
  mkdirSync(directory, { recursive: true });
  writeFileSync(
    join(directory, "reviewer.md"),
    "---\nname: reviewer\ndescription: Review code for correctness\ntools: [read, grep]\n---\nReview without changes.\n",
  );
}

function writeWorker(directory: string): void {
  mkdirSync(directory, { recursive: true });
  writeFileSync(
    join(directory, "worker.md"),
    "---\nname: worker\ndescription: Implement approved changes\ntools: [read, edit, write, bash]\n---\nImplement and validate.\n",
  );
}

function harness() {
  let tool: ToolDefinition | undefined;
  let shutdown: (() => Promise<void> | void) | undefined;
  const pi = {
    registerTool(definition: ToolDefinition) {
      tool = definition;
    },
    on(event: string, handler: () => Promise<void> | void) {
      if (event === "session_shutdown") shutdown = handler;
    },
  } as ExtensionAPI;
  return { pi, getTool: () => tool!, shutdown: () => shutdown?.() };
}

function context(cwd: string): ExtensionContext {
  return {
    cwd,
    sessionManager: { getSessionId: () => "parent-session" },
  } as unknown as ExtensionContext;
}

describe("subagent tool", () => {
  test("discovers a user agent and returns the bounded controller result", async () => {
    const root = temporaryDirectory("pi-subagent-project-");
    const agents = temporaryDirectory("pi-subagent-agents-");
    writeScout(agents);
    writeFileSync(join(root, "AGENTS.md"), "Project guidance");
    const execute = vi.fn<SubagentExecutor>(async (options) => ({
      runId: options.runId,
      operationId: options.operationId,
      agent: options.agent.name,
      status: "completed" as const,
      summary: "Located auth.",
      transcript: {},
    }));
    const extension = harness();
    registerSubagentExtension(extension.pi, {
      agentDirectory: agents,
      authEnvAllowlist: ["TEST_PROVIDER_TOKEN"],
      execute,
      idFactory: (() => {
        const ids = ["run-fixed", "operation-fixed"];
        return () => ids.shift()!;
      })(),
    });

    const updates: string[] = [];
    const result = await extension.getTool().execute(
      "tool-call",
      { action: "run", agent: "scout", task: "Find auth", deadlineMs: 1_000 },
      undefined,
      (update) => updates.push((update.content[0] as { text: string }).text),
      context(root),
    );

    expect(extension.getTool().name).toBe("subagent");
    expect(extension.getTool().description).toContain("scout: Inspect files");
    expect(extension.getTool().promptGuidelines).toEqual([
      "When the user names a registered agent and asks it to perform a task, call subagent with that agent name. Also use it when the user explicitly asks for a subagent or delegation.",
      "When the user requests delegation without naming an agent, list registered agents before choosing one.",
      "Run independent evidence-gathering agents such as scout and researcher in parallel when useful. Do not include oracle in that parallel batch when its decision depends on their findings; wait for those results, summarize the evidence and proposed direction in a self-contained oracle task, then call oracle.",
      "Give worker a self-contained approved direction, avoid concurrent parent writes while it runs, and inspect its changes and validation after it completes.",
      "After explicitly creating or changing an agent definition for the user, list registered agents to refresh the in-memory registry before running it.",
    ]);
    expect(execute).toHaveBeenCalledOnce();
    const canonicalRoot = realpathSync(root);
    expect(execute.mock.calls[0][0]).toMatchObject({
      cwd: canonicalRoot,
      runId: "run-fixed",
      operationId: "operation-fixed",
      parentSessionId: "parent-session",
      workOrder: {
        goal: "Find auth",
        constraints: [
          "Use only the tools declared by the selected agent.",
          "Preserve unrelated existing changes and do not perform destructive shared actions.",
          "Do not delegate to another agent.",
        ],
        projectGuidance: [`Guidance from ${join(canonicalRoot, "AGENTS.md")}:\nProject guidance`],
      },
    });
    expect(JSON.parse((result.content[0] as { text: string }).text)).toMatchObject({
      status: "completed",
      summary: "Located auth.",
    });
    expect(updates[0]).toBe("Starting isolated child…");
  });

  test("delegates implementation using only the worker's declared tools", async () => {
    const root = temporaryDirectory("pi-subagent-project-");
    const agents = temporaryDirectory("pi-subagent-agents-");
    writeWorker(agents);
    const execute = vi.fn<SubagentExecutor>(async (options) => ({
      runId: options.runId,
      operationId: options.operationId,
      agent: options.agent.name,
      status: "completed",
      summary: "Implemented.",
      transcript: {},
    }));
    const extension = harness();
    registerSubagentExtension(extension.pi, { agentDirectory: agents, execute });

    await extension.getTool().execute(
      "tool-call",
      { action: "run", agent: "worker", task: "Apply the approved change" },
      undefined,
      undefined,
      context(root),
    );

    expect(execute.mock.calls[0][0]).toMatchObject({
      agent: { name: "worker", tools: ["read", "edit", "write", "bash"] },
      workOrder: {
        constraints: [
          "Use only the tools declared by the selected agent.",
          "Preserve unrelated existing changes and do not perform destructive shared actions.",
          "Do not delegate to another agent.",
        ],
        returnFormat:
          "Return a concise result with completed work or findings, evidence, validation, blockers, and residual risks.",
      },
    });
  });

  test("refreshes the agent registry only when listing agents", async () => {
    const root = temporaryDirectory("pi-subagent-project-");
    const agents = temporaryDirectory("pi-subagent-agents-");
    writeScout(agents);
    const execute = vi.fn<SubagentExecutor>(async (options) => ({
      runId: options.runId,
      operationId: options.operationId,
      agent: options.agent.name,
      status: "completed",
      summary: "Reviewed.",
      transcript: {},
    }));
    const extension = harness();
    registerSubagentExtension(extension.pi, { agentDirectory: agents, execute });
    writeReviewer(agents);

    const stale = await extension.getTool().execute(
      "tool-call",
      { action: "run", agent: "reviewer", task: "Review" },
      undefined,
      undefined,
      context(root),
    );
    const listed = await extension.getTool().execute(
      "tool-call",
      { action: "list" },
      undefined,
      undefined,
      context(root),
    );
    const refreshed = await extension.getTool().execute(
      "tool-call",
      { action: "run", agent: "reviewer", task: "Review" },
      undefined,
      undefined,
      context(root),
    );

    expect(stale.isError).toBe(true);
    expect((listed.content[0] as { text: string }).text).toContain("reviewer: Review code for correctness");
    expect(refreshed.isError).toBe(false);
    expect(execute).toHaveBeenCalledOnce();
  });

  test("renders every refreshed agent as name and description", async () => {
    const root = temporaryDirectory("pi-subagent-project-");
    const agents = temporaryDirectory("pi-subagent-agents-");
    mkdirSync(agents, { recursive: true });
    for (let index = 0; index < 25; index += 1) {
      const name = `agent-${String(index).padStart(2, "0")}`;
      writeFileSync(
        join(agents, `${name}.md`),
        `---\nname: ${name}\ndescription: Agent ${index}\ntools: [read]\n---\nInspect files.\n`,
      );
    }
    const extension = harness();
    registerSubagentExtension(extension.pi, { agentDirectory: agents, execute: vi.fn<SubagentExecutor>() });
    const tool = extension.getTool();
    const args = { action: "list" } as const;
    const result = await tool.execute("tool-call", args, undefined, undefined, context(root));
    const theme = {
      fg: (_color: string, text: string) => text,
      bold: (text: string) => text,
    };
    const rendered = tool.renderResult!(
      result,
      { expanded: false, isPartial: false },
      theme,
      { args, isError: false, state: {}, invalidate: vi.fn() },
    ).render(200).join("\n");
    const output = (result.content[0] as { text: string }).text;

    expect(output.split("\n")).toHaveLength(25);
    expect(output).toContain("agent-00: Agent 0");
    expect(output).toContain("agent-24: Agent 24");
    expect(output).not.toContain("Available registered agents");
    expect(rendered).toContain("agent-00: Agent 0");
    expect(rendered).toContain("agent-24: Agent 24");
    expect(rendered).toContain("Registered agents");
    expect(rendered).not.toContain("Completed");
    expect(rendered).not.toContain("output truncated in UI");
  });

  test("returns a bounded JSON envelope for escaped executor output", async () => {
    const root = temporaryDirectory("pi-subagent-project-");
    const agents = temporaryDirectory("pi-subagent-agents-");
    writeScout(agents);
    const execute: SubagentExecutor = async (options) => ({
      runId: options.runId,
      operationId: options.operationId,
      agent: options.agent.name,
      status: "completed",
      summary: "\\".repeat(32_000),
      transcript: {},
    });
    const extension = harness();
    registerSubagentExtension(extension.pi, { agentDirectory: agents, execute });

    const result = await extension.getTool().execute(
      "tool-call",
      { action: "run", agent: "scout", task: "Inspect" },
      undefined,
      undefined,
      context(root),
    );
    const serialized = (result.content[0] as { text: string }).text;

    expect(serialized.length).toBeLessThanOrEqual(32_000);
    expect(JSON.parse(serialized)).toMatchObject({ status: "completed" });
  });

  test("renders a bounded multiline task and visible running/completed status", () => {
    vi.useFakeTimers();
    const extension = harness();
    registerSubagentExtension(extension.pi);
    const tool = extension.getTool();
    const theme = {
      fg: (_color: string, text: string) => text,
      bold: (text: string) => text,
    };
    const args = {
      action: "run",
      agent: "scout",
      task: [
        "Inspect authentication.",
        "1) Find the entry point.",
        "2) Explain the request flow.",
        "3) Cite code evidence.",
      ].join("\n"),
    };
    const renderContext = {
      args,
      isError: false,
      state: {},
      invalidate: vi.fn(),
    };

    const call = tool.renderCall!(args, theme, renderContext).render(200).join("\n");
    const expandedCall = tool.renderCall!(
      args,
      theme,
      { ...renderContext, expanded: true },
    ).render(200).join("\n");
    const running = tool.renderResult!(
      {
        content: [{ type: "text", text: "Reading auth files" }],
        details: { agent: "scout", status: "running" },
      },
      { expanded: false, isPartial: true },
      theme,
      renderContext,
    ).render(200).join("\n");
    vi.advanceTimersByTime(80);
    const nextFrame = tool.renderResult!(
      {
        content: [{ type: "text", text: "Reading auth files" }],
        details: { agent: "scout", status: "running" },
      },
      { expanded: false, isPartial: true },
      theme,
      renderContext,
    ).render(200).join("\n");
    const completed = tool.renderResult!(
      {
        content: [{ type: "text", text: "result envelope" }],
        details: { agent: "scout", status: "completed", summary: "Located auth." },
      },
      { expanded: false, isPartial: false },
      theme,
      renderContext,
    ).render(200).join("\n");

    expect(call).toContain("scout");
    expect(call).toContain("  Inspect authentication.");
    expect(call).toContain("  2) Explain the request flow.");
    expect(call).not.toContain("3) Cite code evidence.");
    expect(call).toContain("…");
    expect(expandedCall).toContain("  3) Cite code evidence.");
    expect(call).not.toContain("subagent");
    expect(running).toContain("⠋ — Reading auth files");
    expect(running).not.toContain("Running");
    expect(running).not.toContain("scout");
    expect(renderContext.invalidate).toHaveBeenCalledOnce();
    expect(nextFrame).toContain("⠙ — Reading auth files");
    expect(completed).toContain("✓ Completed — Located auth.");
    expect(completed).not.toContain("scout");
  });

  test("renders lifecycle actions without reporting running or interrupted work as completed", () => {
    const extension = harness();
    registerSubagentExtension(extension.pi);
    const tool = extension.getTool();
    const theme = {
      fg: (_color: string, text: string) => text,
      bold: (text: string) => text,
    };
    const render = (
      args: Record<string, unknown>,
      details: Record<string, unknown>,
      isError = false,
    ) => tool.renderResult!(
      { content: [{ type: "text", text: JSON.stringify(details) }], details },
      { expanded: false, isPartial: false },
      theme,
      { args, isError, state: {}, invalidate: vi.fn() },
    ).render(200).join("\n").trimEnd();

    expect(render(
      { action: "start", agent: "scout", task: "Inspect" },
      { status: "running", operationId: "operation-1" },
    )).toBe("↗ Started");
    expect(render(
      { action: "status", operationId: "operation-1" },
      { status: "running" },
    )).toBe("● Running");
    expect(render(
      { action: "wait", operationId: "operation-1", timeoutMs: 1 },
      { reason: "timeout", snapshot: { status: "running" } },
    )).toBe("◷ Still running");
    expect(render(
      { action: "interrupt", operationId: "operation-1" },
      { accepted: true, snapshot: { status: "running" } },
    )).toBe("■ Interrupt requested");
    expect(render(
      { action: "interrupt", operationId: "missing" },
      { operationId: "missing" },
      true,
    )).toContain("✗ Failed");
    expect(render(
      { action: "run", agent: "scout", task: "Inspect" },
      { status: "interrupted", summary: "Cancelled." },
    )).toContain("■ Interrupted — Cancelled.");
  });

  test("reports unknown agents without starting a process", async () => {
    const root = temporaryDirectory("pi-subagent-project-");
    const agents = temporaryDirectory("pi-subagent-agents-");
    writeScout(agents);
    const execute = vi.fn<SubagentExecutor>();
    const extension = harness();
    registerSubagentExtension(extension.pi, { agentDirectory: agents, execute });

    const result = await extension.getTool().execute(
      "tool-call",
      { action: "run", agent: "missing", task: "Find auth" },
      undefined,
      undefined,
      context(root),
    );

    expect(result.isError).toBe(true);
    expect((result.content[0] as { text: string }).text).toContain("Available agents: scout");
    expect(execute).not.toHaveBeenCalled();
  });

  test("starts background work, reports status, and waits without changing state on timeout", async () => {
    const root = temporaryDirectory("pi-subagent-project-");
    const agents = temporaryDirectory("pi-subagent-agents-");
    writeScout(agents);
    let release!: (result: SubagentResult) => void;
    const execute = vi.fn<SubagentExecutor>(
      (options) => new Promise((resolve) => {
        release = () => resolve({
          runId: options.runId,
          operationId: options.operationId,
          agent: options.agent.name,
          status: "completed",
          summary: "Finished.",
          transcript: {},
        });
      }),
    );
    const extension = harness();
    registerSubagentExtension(extension.pi, { agentDirectory: agents, execute });

    const started = await extension.getTool().execute(
      "tool-call",
      { action: "start", agent: "scout", task: "Inspect" },
      undefined,
      undefined,
      context(root),
    );
    const identity = JSON.parse((started.content[0] as { text: string }).text) as { operationId: string; runId: string };
    expect(identity).toMatchObject({ operationId: expect.any(String), runId: expect.any(String) });
    expect(execute).toHaveBeenCalledOnce();

    const running = await extension.getTool().execute(
      "tool-call",
      { action: "status", operationId: identity.operationId },
      undefined,
      undefined,
      context(root),
    );
    expect(running.details).toMatchObject({
      operationId: identity.operationId,
      runId: identity.runId,
      status: "running",
    });

    const timedOut = await extension.getTool().execute(
      "tool-call",
      { action: "wait", operationId: identity.operationId, timeoutMs: 1 },
      undefined,
      undefined,
      context(root),
    );
    expect(timedOut.details).toMatchObject({ reason: "timeout", snapshot: { status: "running" } });
    expect((await extension.getTool().execute(
      "tool-call",
      { action: "status", operationId: identity.operationId },
      undefined,
      undefined,
      context(root),
    )).details).toMatchObject({ status: "running" });

    release({
      runId: identity.runId,
      operationId: identity.operationId,
      agent: "scout",
      status: "completed",
      summary: "Finished.",
      transcript: {},
    });
    const waited = await extension.getTool().execute(
      "tool-call",
      { action: "wait", operationId: identity.operationId },
      undefined,
      undefined,
      context(root),
    );
    expect(waited.details).toMatchObject({ status: "completed", summary: "Finished." });
  });

  test("interrupts an operation and close is idempotent while awaiting shutdown", async () => {
    const root = temporaryDirectory("pi-subagent-project-");
    const agents = temporaryDirectory("pi-subagent-agents-");
    writeScout(agents);
    let observedSignal: AbortSignal | undefined;
    const execute = vi.fn<SubagentExecutor>(
      (options) => new Promise((_resolve, reject) => {
        observedSignal = options.signal;
        options.signal?.addEventListener(
          "abort",
          () => reject(new SubagentCancellationError("cancelled by interrupt")),
          { once: true },
        );
      }),
    );
    const extension = harness();
    registerSubagentExtension(extension.pi, { agentDirectory: agents, execute });
    const started = await extension.getTool().execute(
      "tool-call",
      { action: "start", agent: "scout", task: "Wait" },
      undefined,
      undefined,
      context(root),
    );
    const { operationId } = JSON.parse((started.content[0] as { text: string }).text) as { operationId: string };

    const interrupted = await extension.getTool().execute(
      "tool-call",
      { action: "interrupt", operationId },
      undefined,
      undefined,
      context(root),
    );
    expect(interrupted.details).toMatchObject({ accepted: true });
    expect(observedSignal?.aborted).toBe(true);
    await extension.getTool().execute("tool-call", { action: "close" }, undefined, undefined, context(root));
    const repeated = await extension.getTool().execute("tool-call", { action: "close" }, undefined, undefined, context(root));
    expect(repeated.details).toEqual({ status: "closed" });
  });

  test("parent shutdown cancels and awaits owned children", async () => {
    const root = temporaryDirectory("pi-subagent-project-");
    const agents = temporaryDirectory("pi-subagent-agents-");
    writeScout(agents);
    let observedSignal: AbortSignal | undefined;
    const execute = vi.fn<SubagentExecutor>(
      (options) =>
        new Promise((_resolve, reject) => {
          observedSignal = options.signal;
          options.signal?.addEventListener(
            "abort",
            () => reject(new SubagentCancellationError("cancelled by shutdown")),
            { once: true },
          );
        }),
    );
    const extension = harness();
    registerSubagentExtension(extension.pi, { agentDirectory: agents, execute });

    const running = extension.getTool().execute(
      "tool-call",
      { action: "run", agent: "scout", task: "Wait" },
      undefined,
      undefined,
      context(root),
    );
    await vi.waitFor(() => expect(observedSignal).toBeDefined());
    await extension.shutdown();

    expect(observedSignal?.aborted).toBe(true);
    await expect(running).resolves.toMatchObject({ isError: true });
  });

  test("reserves at most three concurrent child slots", async () => {
    const root = temporaryDirectory("pi-subagent-project-");
    const agents = temporaryDirectory("pi-subagent-agents-");
    writeScout(agents);
    const execute = vi.fn<SubagentExecutor>(
      (options) =>
        new Promise((_resolve, reject) => {
          options.signal?.addEventListener(
            "abort",
            () => reject(new SubagentCancellationError("cancelled by shutdown")),
            { once: true },
          );
        }),
    );
    const extension = harness();
    registerSubagentExtension(extension.pi, { agentDirectory: agents, execute });
    const run = () =>
      extension.getTool().execute(
        "tool-call",
        { action: "run", agent: "scout", task: "Wait" },
        undefined,
        undefined,
        context(root),
      );

    const running = [run(), run(), run()];
    await vi.waitFor(() => expect(execute).toHaveBeenCalledTimes(3));
    const rejected = await run();

    expect(rejected.isError).toBe(true);
    expect((rejected.content[0] as { text: string }).text).toContain("maxConcurrentRuns is 3");
    expect(execute).toHaveBeenCalledTimes(3);
    await extension.shutdown();
    await Promise.all(running);
  });

  test("rejects new runs after shutdown starts", async () => {
    const root = temporaryDirectory("pi-subagent-project-");
    const agents = temporaryDirectory("pi-subagent-agents-");
    writeScout(agents);
    const execute = vi.fn<SubagentExecutor>();
    const extension = harness();
    registerSubagentExtension(extension.pi, { agentDirectory: agents, execute });

    await extension.shutdown();
    const result = await extension.getTool().execute(
      "tool-call",
      { action: "run", agent: "scout", task: "Inspect" },
      undefined,
      undefined,
      context(root),
    );

    expect(result.isError).toBe(true);
    expect((result.content[0] as { text: string }).text).toContain("shutting down");
    expect(execute).not.toHaveBeenCalled();
  });
});
