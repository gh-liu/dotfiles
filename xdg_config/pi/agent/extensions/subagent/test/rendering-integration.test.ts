import { describe, expect, test, vi } from "vitest";
import { mkdirSync, realpathSync, writeFileSync } from "node:fs";
import { join } from "node:path";

import {
  buildWakeWordSnippet,
  loadSubagentOverrides,
  SUBAGENT_COMPLETION_MESSAGE,
  registerSubagentExtension,
  validateAuthEnvAllowlist,
  temporaryDirectory,
  writeAgent,
  deferred,
  FakeController,
  fakeFactory,
  harness,
  context,
  setup,
  startIdle,
} from "./harness.ts";

describe("subagent rendering", () => {
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
    const deadlineSchema = (env.extension.getTool().parameters as {
      properties: { deadlineMs: { description?: string } };
    }).properties.deadlineMs;
    expect(deadlineSchema).not.toHaveProperty("default");
    expect(deadlineSchema.description).toContain("Required for run/start");
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
    expect(await env.invoke({ action: "wait", id: "runtime" })).toMatchObject({
      isError: true,
      details: { error: "operationId is required for subagent wait" },
    });
  });

  test("bounds and compacts model-facing result serialization while preserving authoritative details", async () => {
    const env = setup();
    const run = env.invoke({ action: "run", agent: "scout", task: "Inspect" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    env.fake.controllers[0].settle(0, "completed", "\\".repeat(32_000));
    const result = await run;
    const serialized = (result.content[0] as { text: string }).text;
    expect(serialized.length).toBeLessThanOrEqual(16_000);
    const modelHandoff = JSON.parse(serialized) as Record<string, unknown>;
    expect(modelHandoff).toMatchObject({ index: 1, agent: "scout", status: "completed" });
    expect(modelHandoff).not.toHaveProperty("runId");
    expect(modelHandoff).not.toHaveProperty("operationId");
    expect(modelHandoff).not.toHaveProperty("processInstanceId");
    expect(result.details).toMatchObject({
      runId: expect.any(String),
      operationId: expect.any(String),
      processInstanceId: "process-1",
      status: "completed",
    });
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

});
