import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { afterEach, describe, expect, test } from "vitest";

import {
  createSdkSubagentController,
  createSdkSubagentExecutor,
  filterDeclaredCustomTools,
} from "./sdk-executor.ts";
import type { SubagentExecutionProfile, SubagentProgress, SubagentRunOptions, SubagentWorkOrder } from "./protocol.ts";

afterEach(() => {
  delete process.env.SUBAGENT_SDK_TEST_SECRET;
});

function workOrder(goal: string): SubagentWorkOrder {
  return {
    goal,
    scope: [process.cwd()],
    constraints: [],
    knownDecisions: [],
    evidence: [],
    validation: [],
    returnFormat: "Return findings.",
    projectGuidance: [],
  };
}

function profile(): SubagentExecutionProfile {
  return { name: "scout", systemPrompt: "Inspect files.", tools: ["read"] };
}

function options(overrides: Partial<SubagentRunOptions> = {}): SubagentRunOptions {
  return {
    cwd: process.cwd(),
    agent: profile(),
    workOrder: workOrder("Inspect the fixture"),
    runId: "run-sdk",
    operationId: "operation-sdk",
    parentSessionId: "parent-sdk",
    deadlineMs: 5_000,
    ...overrides,
  };
}

class FakeSession {
  sessionId = "sdk-session";
  sessionFile = "/tmp/sdk-session.jsonl";
  isStreaming = false;
  private listeners: Array<(e: any) => void> = [];
  promptCalls: Array<{ text: string; options: any }> = [];
  abortCalls = 0;
  steerCalls: string[] = [];
  disposeCalls = 0;
  promptHandler?: (text: string, options: any, emit: (e: any) => void) => Promise<void> | void;
  abortHandler?: () => Promise<void> | void;
  disposeHandler?: () => void;

  get listenerCount(): number {
    return this.listeners.length;
  }

  subscribe(listener: (e: any) => void): () => void {
    this.listeners.push(listener);
    return () => { this.listeners = this.listeners.filter((l) => l !== listener); };
  }
  emit(event: any): void {
    for (const l of [...this.listeners]) l(event);
  }
  async prompt(text: string, promptOptions: any): Promise<void> {
    this.promptCalls.push({ text, options: promptOptions });
    this.isStreaming = true;
    try {
      if (this.promptHandler) {
        await this.promptHandler(text, promptOptions, (e) => this.emit(e));
        return;
      }
      if (promptOptions?.preflightResult) promptOptions.preflightResult(true);
      this.emit({ type: "agent_start" });
      this.emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: "Fake result" }], stopReason: "stop" } });
      this.emit({ type: "agent_settled" });
    } finally {
      this.isStreaming = false;
    }
  }
  async abort(): Promise<void> {
    this.abortCalls++;
    if (this.abortHandler) {
      await this.abortHandler();
      return;
    }
    this.emit({ type: "agent_settled" });
  }
  async steer(text: string): Promise<void> {
    this.steerCalls.push(text);
  }
  dispose(): void {
    this.disposeCalls++;
    this.disposeHandler?.();
  }
}

function fakeController(initial: SubagentRunOptions, session: FakeSession, config: any = {}) {
  return createSdkSubagentController(initial, {
    createSession: async () => ({ session: session as any }),
    terminationGraceMs: 25,
    ...config,
  });
}

describe("one-shot SDK executor", () => {
  test("reuses one controller sequentially and rejects invalid submit timing", async () => {
    const session = new FakeSession();
    session.sessionId = "reused-session";
    session.sessionFile = "/tmp/reused.jsonl";
    let promptCount = 0;
    session.promptHandler = async (_text, opts, emit) => {
      promptCount++;
      if (opts?.preflightResult) opts.preflightResult(true);
      const goal = JSON.parse(_text.split("\n\n")[1]).goal;
      emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: goal }], stopReason: "stop" } });
      emit({ type: "agent_settled" });
    };
    const firstOptions = options({ operationId: "operation-1", workOrder: workOrder("first") });
    const controller = await fakeController(firstOptions, session);
    const firstPending = controller.submit(firstOptions);
    await expect(controller.submit({ ...firstOptions, operationId: "concurrent" })).rejects.toThrow("active operation");
    const first = await firstPending;
    await expect(controller.submit({
      ...firstOptions,
      operationId: "mismatched",
      agent: { ...firstOptions.agent, tools: ["grep"] },
    })).rejects.toThrow("runtime identity");
    const second = await controller.submit({ ...firstOptions, operationId: "operation-2", workOrder: workOrder("second") });
    expect(first.summary).toBe("first");
    expect(second.summary).toBe("second");
    expect(second.operationId).toBe("operation-2");
    expect(first.processInstanceId).toBe(second.processInstanceId);
    expect(first.transcript).toEqual(second.transcript);
    first.transcript.sessionId = "mutated-by-caller";
    expect(second.transcript.sessionId).toBe("reused-session");
    const snapshot = controller.transcript as { sessionId?: string };
    snapshot.sessionId = "mutated-snapshot";
    expect(controller.transcript.sessionId).toBe("reused-session");
    firstOptions.agent.tools.push("grep");
    await expect(controller.submit({ ...firstOptions, operationId: "mutated-profile" })).rejects.toThrow("runtime identity");
    await controller.close();
    expect(session.disposeCalls).toBe(1);
    expect(promptCount).toBe(2);
    const rejected = controller.start(firstOptions);
    await expect(rejected.accepted).rejects.toThrow("closed");
    await expect(rejected.result).rejects.toThrow("closed");
  });

  test("close cancels an unaccepted active operation and remains idempotent", async () => {
    const session = new FakeSession();
    session.promptHandler = async (_text, opts) => {
      if (opts?.preflightResult) opts.preflightResult(true);
      // never settle, keep streaming
      await new Promise(() => {});
    };
    const runOptions = options();
    const controller = await fakeController(runOptions, session);
    const pending = controller.submit(runOptions);
    await new Promise((r) => setTimeout(r, 20));
    const firstClose = controller.close();
    expect(controller.close()).toBe(firstClose);
    await expect(pending).rejects.toThrow("closed during active operation");
    await expect(firstClose).resolves.toBeUndefined();
  });

  test("bounds close when abort hangs before prompt acceptance and still disposes", async () => {
    const session = new FakeSession();
    session.promptHandler = async () => {
      // Never report preflight acceptance or authoritative settlement.
      await new Promise(() => {});
    };
    session.abortHandler = async () => {
      await new Promise(() => {});
    };
    const runOptions = options();
    const controller = await fakeController(runOptions, session);
    const operation = controller.start(runOptions);
    while (session.promptCalls.length === 0) await new Promise((resolve) => setTimeout(resolve, 1));

    const close = controller.close();

    await expect(operation.accepted).rejects.toThrow("closed during active operation");
    await expect(operation.result).rejects.toThrow("closed during active operation");
    await expect(close).rejects.toThrow("SDK abort did not finish during close");
    expect(session.abortCalls).toBe(1);
    expect(session.disposeCalls).toBe(1);
  });

  test("filters injected custom tools to names declared by the agent", () => {
    const readOverride = { name: "read" };
    const webSearch = { name: "web_search" };
    const undeclared = { name: "shell_escape" };
    expect(filterDeclaredCustomTools(["read", "web_search"], [undeclared, webSearch, {}, readOverride]))
      .toEqual([webSearch, readOverride]);
  });

  test("surfaces session disposal failure", async () => {
    const session = new FakeSession();
    session.disposeHandler = () => { throw new Error("Dispose failed"); };
    const controller = await fakeController(options(), session);

    await expect(controller.close()).rejects.toThrow("Dispose failed");
    expect(session.disposeCalls).toBe(1);
  });

  test("performs prompt and returns the session reference", async () => {
    const session = new FakeSession();
    session.sessionId = "session-sdk-1";
    session.sessionFile = "/tmp/session-sdk-1.jsonl";
    session.promptHandler = async (text, opts, emit) => {
      if (opts?.preflightResult) opts.preflightResult(true);
      // Echo the full prompt back so the test can assert the delegated work-order shape.
      emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: JSON.stringify({ goal: text }) }], stopReason: "stop" } });
      emit({ type: "agent_settled" });
    };
    const runOptions = options();
    const result = await createSdkSubagentExecutor({
      createSession: async () => ({ session: session as any }),
    })(runOptions);
    expect(result.status).toBe("completed");
    expect(result.processInstanceId).toMatch(/^[0-9a-f-]{36}$/);
    const summary = JSON.parse(result.summary);
    const serializedWorkOrder = summary.goal.split("\n\n", 2)[1];
    expect(serializedWorkOrder).toBe(JSON.stringify(runOptions.workOrder));
    expect(serializedWorkOrder).not.toContain("\n");
    const delegatedWorkOrder = JSON.parse(serializedWorkOrder);
    expect(delegatedWorkOrder.goal).toBe("Inspect the fixture");
    expect(result.transcript.sessionId).toBe("session-sdk-1");
    expect(result.transcript.sessionPath).toBe("/tmp/session-sdk-1.jsonl");
  });

  test("passes the explicit runtime profile and dedicated session root to session construction", async () => {
    const session = new FakeSession();
    const createdWith: any[] = [];
    const runOptions = options({
      cwd: "/workspace/project",
      runId: "run-construction",
      agent: {
        ...profile(),
        model: "openrouter/stealth/ox-alpha",
        thinking: "minimal",
        tools: ["read", "grep"],
      },
    });
    const controller = await createSdkSubagentController(runOptions, {
      agentDir: "/pi-agent",
      createSession: async (sessionOptions) => {
        createdWith.push(sessionOptions);
        return { session: session as any };
      },
    });
    expect(createdWith).toEqual([{
      cwd: "/workspace/project",
      agentDir: "/pi-agent",
      model: "openrouter/stealth/ox-alpha",
      thinkingLevel: "minimal",
      tools: ["read", "grep"],
      agent: runOptions.agent,
      sessionRoot: "/pi-agent/subagent-sessions",
      sessionDir: "/pi-agent/subagent-sessions/run-construction",
      systemPrompt: "Inspect files.",
      noExtensions: true,
      noSkills: true,
      noPromptTemplates: true,
      noThemes: true,
      noContextFiles: true,
    }]);
    await controller.close();
  });

  test("fails when the final assistant message is not a normal stop", async () => {
    const session = new FakeSession();
    session.promptHandler = async (_text, opts, emit) => {
      if (opts?.preflightResult) opts.preflightResult(true);
      emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: "partial" }], stopReason: "length" } });
      emit({ type: "agent_settled" });
    };
    const result = await createSdkSubagentExecutor({ createSession: async () => ({ session: session as any }) })(options());
    expect(result.status).toBe("failed");
    expect(result.summary).toBe("partial");
  });

  test("fails with a diagnostic when authoritative settlement has no final assistant response", async () => {
    const session = new FakeSession();
    session.promptHandler = async (_text, opts, emit) => {
      opts?.preflightResult?.(true);
      emit({ type: "agent_settled" });
    };
    const result = await createSdkSubagentExecutor({
      createSession: async () => ({ session: session as any }),
    })(options());
    expect(result).toMatchObject({
      status: "failed",
      summary: "Child did not produce a complete final assistant response.",
    });
  });

  test("surfaces malformed session events and removes the listener", async () => {
    const session = new FakeSession();
    session.promptHandler = async (_text, opts, emit) => {
      opts?.preflightResult?.(true);
      emit(null);
    };
    const result = await createSdkSubagentExecutor({
      createSession: async () => ({ session: session as any }),
    })(options());
    expect(result.status).toBe("failed");
    expect(result.summary).toMatch(/(?:null|type)/i);
    expect(session.listenerCount).toBe(0);
    expect(session.disposeCalls).toBe(1);
  });

  test("keeps transcript evidence readable after controller close", async () => {
    const directory = mkdtempSync(join(tmpdir(), "pi-subagent-transcript-"));
    const sessionPath = join(directory, "session.jsonl");
    writeFileSync(sessionPath, '{"type":"session"}\n');
    const session = new FakeSession();
    session.sessionFile = sessionPath;
    try {
      const runOptions = options();
      const controller = await fakeController(runOptions, session);
      await expect(controller.submit(runOptions)).resolves.toMatchObject({ status: "completed" });
      await controller.close();
      expect(existsSync(sessionPath)).toBe(true);
      expect(readFileSync(sessionPath, "utf8")).toBe('{"type":"session"}\n');
      expect(session.listenerCount).toBe(0);
    } finally {
      rmSync(directory, { recursive: true, force: true });
    }
  });

  test("maps provider authentication failure during session creation to a bounded failed result", async () => {
    const result = await createSdkSubagentExecutor({
      createSession: async () => { throw new Error("No API key found for openrouter"); },
    })(options({ agent: { ...profile(), model: "openrouter/stealth/ox-alpha" } }));
    expect(result).toMatchObject({
      runId: "run-sdk",
      operationId: "operation-sdk",
      agent: "scout",
      status: "failed",
      summary: "No API key found for openrouter",
      transcript: {},
    });
  });

  test("preserves transcript evidence when submission fails after preflight", async () => {
    const session = new FakeSession();
    session.promptHandler = async (_text, opts, emit) => {
      if (opts?.preflightResult) opts.preflightResult(true);
      // Simulate prompt failure after preflight
      throw new Error("prompt failed");
    };
    const result = await createSdkSubagentExecutor({ createSession: async () => ({ session: session as any }) })(options());
    expect(result.status).toBe("failed");
    expect(result.summary).toContain("prompt failed");
    expect(result.transcript.sessionId).toBe("sdk-session");
  });

  test("fails on preflight rejection", async () => {
    const session = new FakeSession();
    session.promptHandler = async (_text, opts) => {
      if (opts?.preflightResult) opts.preflightResult(false);
      throw new Error("preflight failed");
    };
    const result = await createSdkSubagentExecutor({ createSession: async () => ({ session: session as any }) })(options());
    expect(result.status).toBe("failed");
  });

  test("reduces model and tool events to bounded redacted progress", async () => {
    const session = new FakeSession();
    session.promptHandler = async (_text, opts, emit) => {
      if (opts?.preflightResult) opts.preflightResult(true);
      emit({ type: "agent_start" });
      emit({ type: "message_update", assistantMessageEvent: { type: "thinking_delta" } });
      emit({ type: "message_update", assistantMessageEvent: { type: "toolcall_start" } });
      emit({ type: "tool_execution_start", toolCallId: "tool-1", toolName: "read", args: { path: "token=sdk-secret-" + "x".repeat(300) } });
      emit({ type: "tool_execution_update", toolCallId: "tool-1", toolName: "read", partialResult: {} });
      emit({ type: "tool_execution_end", toolCallId: "tool-1", toolName: "read", isError: false, result: {} });
      emit({ type: "message_update", assistantMessageEvent: { type: "text_delta" } });
      emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: "Final answer" }], stopReason: "stop" } });
      emit({ type: "agent_settled" });
    };
    process.env.SUBAGENT_SDK_TEST_SECRET = "sdk-secret";
    const progress: SubagentProgress[] = [];
    const runOptions = options({ onProgress: (value) => progress.push(typeof value === "string" ? { summary: value } : value) });
    const controller = await fakeController(runOptions, session, { credentialEnvNames: ["SUBAGENT_SDK_TEST_SECRET"] });
    const op = controller.start(runOptions);
    await op.accepted;
    await op.result;
    expect(progress.slice(0, 3).map((entry) => entry.summary)).toEqual([
      "Child started; waiting for model…",
      "Thinking…",
      "Preparing tool call…",
    ]);
    expect(progress[3].summary).toMatch(/^read token=\[REDACTED\]-x+…$/);
    expect(progress[3].tools?.active).toHaveLength(1);
    expect(progress[4].summary).toContain("done · working…");
    expect(progress[4].tools).toMatchObject({ history: [{ status: "completed" }], active: [] });
    expect(progress.slice(-2).map((entry) => entry.summary)).toEqual(["Writing response…", "Finalizing response…"]);
    expect(JSON.stringify(progress)).not.toContain("sdk-secret");
    expect(progress.every((entry) => entry.summary.length <= 161)).toBe(true);
    await controller.close();
  });

  test("tracks bounded deduplicated tool lifecycle with failures and bash previews", async () => {
    const session = new FakeSession();
    session.promptHandler = async (_text, opts, emit) => {
      opts?.preflightResult?.(true);
      for (let index = 0; index < 10; index++) {
        const start = { type: "tool_execution_start", toolCallId: `tool-${index}`, toolName: index === 9 ? "bash" : "read", args: index === 9 ? { command: "printf 'recognizable command'" } : { path: `/tmp/${index}` } };
        emit(start);
        if (index === 0) emit(start); // repeated SDK update must not duplicate the active call
        emit({ type: "tool_execution_update", toolCallId: `tool-${index}` });
        emit({ ...start, type: "tool_execution_end", isError: index === 1 });
      }
      emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: "Done" }], stopReason: "stop" } });
      emit({ type: "agent_settled" });
    };
    const progress: SubagentProgress[] = [];
    const runOptions = options({ onProgress: (value) => progress.push(typeof value === "string" ? { summary: value } : value) });
    const controller = await fakeController(runOptions, session);
    await controller.submit(runOptions);
    const tools = progress.at(-1)?.tools;
    expect(tools).toMatchObject({ earlierCount: 2 });
    expect(tools?.history).toHaveLength(8);
    expect(progress.flatMap((entry) => entry.tools?.history ?? []).some((item) => item.status === "failed")).toBe(true);
    expect(tools?.history.at(-1)?.summary).toContain("bash printf 'recognizable command'");
    expect(progress.filter((entry) => entry.tools?.active.some((item) => item.id === "tool-0"))).toHaveLength(1);
    await controller.close();
  });

  test("preserves thinking as an ordered merged timeline between tool calls", async () => {
    const session = new FakeSession();
    session.promptHandler = async (_text, opts, emit) => {
      opts?.preflightResult?.(true);
      // Tool call A
      emit({ type: "tool_execution_start", toolCallId: "a", toolName: "read", args: { path: "a.ts" } });
      emit({ type: "tool_execution_end", toolCallId: "a", toolName: "read", isError: false });
      // Thinking between A and B: several consecutive deltas must merge into ONE segment
      emit({ type: "message_update", assistantMessageEvent: { type: "thinking_delta", delta: "we should ", partial: {} } });
      emit({ type: "message_update", assistantMessageEvent: { type: "thinking_delta", delta: "inspect the ", partial: {} } });
      emit({ type: "message_update", assistantMessageEvent: { type: "thinking_delta", delta: "schema first.", partial: {} } });
      // Tool call B
      emit({ type: "tool_execution_start", toolCallId: "b", toolName: "grep", args: { pattern: "schema", path: "src" } });
      emit({ type: "tool_execution_end", toolCallId: "b", toolName: "grep", isError: false });
      // Trailing thinking after the last tool call, flushed at message end
      emit({ type: "message_update", assistantMessageEvent: { type: "thinking_delta", delta: "the schema proves the fix.", partial: {} } });
      emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: "Conclusion" }], stopReason: "stop" } });
      emit({ type: "agent_settled" });
    };
    const progress: SubagentProgress[] = [];
    const runOptions = options({ onProgress: (value) => progress.push(typeof value === "string" ? { summary: value } : value) });
    const controller = await fakeController(runOptions, session);
    await controller.submit(runOptions);
    const timeline = progress.at(-1)?.timeline;
    expect(timeline).toEqual([
      { kind: "tool", id: "a", summary: "read a.ts", status: "completed" },
      { kind: "thinking", text: "we should inspect the schema first." },
      { kind: "tool", id: "b", summary: "grep schema · src", status: "completed" },
      { kind: "thinking", text: "the schema proves the fix." },
    ]);
    // The partial timeline (while B is active, before it finishes) already carries the
    // merged thinking segment between A and B, merged into one entry rather than three.
    const partialWhileB = progress.find((entry) =>
      entry.tools?.active.some((item) => item.id === "b")
      && entry.timeline?.some((item) => item.kind === "thinking"),
    );
    expect(partialWhileB).toBeDefined();
    expect(partialWhileB!.timeline!.filter((entry) => entry.kind === "thinking")).toEqual([
      { kind: "thinking", text: "we should inspect the schema first." },
    ]);
    await controller.close();
  });

  test("aborts an accepted operation authoritatively and reuses the runtime", async () => {
    const session = new FakeSession();
    let operation = 0;
    session.promptHandler = async (_text, opts, emit) => {
      operation++;
      if (opts?.preflightResult) opts.preflightResult(true);
      if (operation === 2) {
        emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: "Still reusable" }], stopReason: "stop" } });
        emit({ type: "agent_settled" });
      } else {
        // first operation stays pending until abort
        await new Promise(() => {});
      }
    };
    session.abortHandler = async () => {
      // Settle slightly later than the interrupt dispatch so the test can observe
      // that interrupt waits for authoritative settlement before resolving.
      await new Promise((r) => setTimeout(r, 10));
      session.emit({ type: "agent_settled" });
    };
    const firstOptions = options({ operationId: "operation-interrupted" });
    const controller = await fakeController(firstOptions, session);
    const first = controller.start(firstOptions);
    await first.accepted;
    expect(await controller.interrupt("stale-operation")).toBe(false);
    let resultSettled = false;
    void first.result.then(() => { resultSettled = true; });
    const interrupt = controller.interrupt(firstOptions.operationId);
    await new Promise((r) => setTimeout(r, 5));
    expect(resultSettled).toBe(false);
    expect(await interrupt).toBe(true);
    expect(resultSettled).toBe(true);
    await expect(first.result).resolves.toMatchObject({ status: "interrupted" });
    const second = await controller.submit({ ...firstOptions, operationId: "operation-reused" });
    expect(second).toMatchObject({ status: "completed", summary: "Still reusable" });
    expect(second.processInstanceId).toBe(controller.processInstanceId);
    await controller.close();
  });

  test("steers only the expected accepted active operation", async () => {
    const session = new FakeSession();
    session.promptHandler = async (_text, opts, emit) => {
      // Delay preflight so the "too early" steer below lands before acceptance.
      await new Promise((r) => setTimeout(r, 10));
      if (opts?.preflightResult) opts.preflightResult(true);
      // keep pending for steer
      await new Promise(() => {});
    };
    const runOptions = options({ operationId: "operation-steered" });
    const controller = await fakeController(runOptions, session);
    const operation = controller.start(runOptions);
    expect(await controller.steer(runOptions.operationId, "too early")).toBe(false);
    await operation.accepted;
    expect(await controller.steer("stale-operation", "wrong turn")).toBe(false);
    expect(await controller.steer(runOptions.operationId, "Focus on tests")).toBe(true);
    expect(session.steerCalls).toEqual(["Focus on tests"]);
    // Make it settle with steered text
    session.emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: "Focus on tests" }], stopReason: "stop" } });
    session.emit({ type: "agent_settled" });
    await expect(operation.result).resolves.toMatchObject({ status: "completed", summary: "Focus on tests" });
    expect(await controller.steer(runOptions.operationId, "too late")).toBe(false);
    await controller.close();
  });

  test("deadline aborts the operation without killing the reusable runtime", async () => {
    const session = new FakeSession();
    let operation = 0;
    session.promptHandler = async (_text, opts, emit) => {
      operation++;
      if (opts?.preflightResult) opts.preflightResult(true);
      if (operation === 2) {
        emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: "After deadline" }], stopReason: "stop" } });
        emit({ type: "agent_settled" });
      } else {
        await new Promise(() => {});
      }
    };
    session.abortHandler = async () => {
      session.emit({ type: "agent_settled" });
    };
    const firstOptions = options({ operationId: "operation-deadline", deadlineMs: 20 });
    const controller = await fakeController(firstOptions, session);
    await expect(controller.submit(firstOptions)).resolves.toMatchObject({
      status: "interrupted",
      summary: "Subagent execution deadline exceeded (20 ms)",
    });
    await expect(controller.submit({ ...firstOptions, operationId: "operation-after-deadline", deadlineMs: 1000 })).resolves.toMatchObject({ status: "completed", summary: "After deadline" });
    await controller.close();
  });

  test("startup abort before prompt", async () => {
    const session = new FakeSession();
    const controller = await fakeController(options(), session);
    const ac = new AbortController();
    ac.abort();
    const op = controller.start(options({ signal: ac.signal }));
    await expect(op.accepted).rejects.toThrow("cancelled");
    await expect(op.result).rejects.toThrow("cancelled");
    await controller.close();
  });

  test("signal abort during prompt", async () => {
    const session = new FakeSession();
    session.promptHandler = async (_text, opts, emit) => {
      if (opts?.preflightResult) opts.preflightResult(true);
      await new Promise(() => {}); // never settle until abort
    };
    session.abortHandler = async () => { session.emit({ type: "agent_settled" }); };
    const ac = new AbortController();
    const controller = await fakeController(options(), session);
    const op = controller.start(options({ signal: ac.signal }));
    await op.accepted;
    ac.abort();
    await expect(op.result).resolves.toMatchObject({ status: "interrupted" });
    await controller.close();
  });

  test("abort watchdog fails a nonresponsive child instead of hanging", async () => {
    const session = new FakeSession();
    session.promptHandler = async (_text, opts) => {
      if (opts?.preflightResult) opts.preflightResult(true);
      await new Promise(() => {});
    };
    session.abortHandler = async () => {
      // deliberately not emitting settled
      await new Promise(() => {});
    };
    const runOptions = options();
    const controller = await fakeController(runOptions, session);
    const operation = controller.start(runOptions);
    await operation.accepted;
    await expect(controller.interrupt(runOptions.operationId)).rejects.toThrow("SDK abort did not reach authoritative settlement");
    await expect(operation.result).rejects.toThrow("SDK abort did not reach authoritative settlement");
    await expect(controller.close()).rejects.toThrow("SDK abort did not reach authoritative settlement");
  });

  test("bounded summary truncates large output", async () => {
    const session = new FakeSession();
    const large = "x".repeat(50_000);
    session.promptHandler = async (_text, opts, emit) => {
      if (opts?.preflightResult) opts.preflightResult(true);
      emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: large }], stopReason: "stop" } });
      emit({ type: "agent_settled" });
    };
    const result = await createSdkSubagentExecutor({ createSession: async () => ({ session: session as any }) })(options());
    expect(result.summary.length).toBeLessThanOrEqual(16_000);
    expect(result.status).toBe("completed");
  });
});
