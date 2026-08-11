import { afterEach, describe, expect, test, vi } from "vitest";
import { mkdtempSync, mkdirSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import type { ExtensionAPI, ExtensionContext, ToolDefinition } from "@earendil-works/pi-coding-agent";
import { registerSubagentExtension } from "./index.ts";
import { SubagentCancellationError } from "./protocol.ts";
import type { SubagentExecutor } from "./protocol.ts";

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

  test("renders the delegated task and visible running/completed status", () => {
    vi.useFakeTimers();
    const extension = harness();
    registerSubagentExtension(extension.pi);
    const tool = extension.getTool();
    const theme = {
      fg: (_color: string, text: string) => text,
      bold: (text: string) => text,
    };
    const args = { action: "run", agent: "scout", task: "Inspect authentication" };
    const renderContext = {
      args,
      isError: false,
      state: {},
      invalidate: vi.fn(),
    };

    const call = tool.renderCall!(args, theme, renderContext).render(200).join("\n");
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

    expect(call).toContain("scout — Inspect authentication");
    expect(call).not.toContain("subagent");
    expect(running).toContain("⠋ — Reading auth files");
    expect(running).not.toContain("Running");
    expect(running).not.toContain("scout");
    expect(renderContext.invalidate).toHaveBeenCalledOnce();
    expect(nextFrame).toContain("⠙ — Reading auth files");
    expect(completed).toContain("✓ Completed — Located auth.");
    expect(completed).not.toContain("scout");
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
