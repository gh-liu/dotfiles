import { describe, expect, test, vi } from "vitest";

import { context, setup } from "./harness.ts";

describe("subagent tasks and reusable sessions", () => {
  const forbidden = new Set(["jobId", "operationId", "processInstanceId", "revision", "index", "runId", "transcript"]);
  const expectPublic = (value: unknown): void => {
    if (!value || typeof value !== "object") return;
    for (const [key, nested] of Object.entries(value)) {
      expect(forbidden.has(key), `forbidden public key ${key}`).toBe(false);
      expectPublic(nested);
    }
  };

  test("keeps the default task contract small and the session control plane separate", () => {
    const env = setup();
    const task = env.extension.getTool() as unknown as { description: string; promptSnippet?: string; promptGuidelines?: string[] };
    const session = env.extension.getTool("subagent_session") as unknown as { description: string };
    expect(task.description).toContain("Run one bounded task");
    expect(task.description).toContain("Work directly on coherent implementation");
    expect(task.promptSnippet).toBeUndefined();
    expect(task.promptGuidelines).toBeUndefined();
    expect(session.description).toContain("Advanced reusable child conversations");
    expect(session.description).toContain("open starts a session");
  });

  test("run defaults to a one-shot task without exposing a reusable ref", async () => {
    const env = setup({ ids: ["task-runtime", "task-operation"] });
    const running = env.extension.getTool().execute(
      "call",
      { agent: "scout", task: "Inspect once" } as never,
      undefined, undefined, context(env.root),
    );
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    env.fake.controllers[0].settle(0, "completed", "One-shot handoff.");
    const result = await running;

    expect(result.details).toMatchObject({ mode: "task", status: "closed", turnStatus: "completed", summary: "One-shot handoff." });
    expect(result.details).not.toHaveProperty("turn");
    expect(result.details).not.toHaveProperty("ref");
    expect(env.fake.controllers[0].closeCalls).toBe(1);
    expect((await env.invoke({ action: "get" })).details).toEqual({ sessions: [] });
    expect((await env.invoke({ action: "send", ref: "#1", task: "Cannot continue" })).isError).toBe(true);
    expectPublic(result);
  });

  test("task schema exposes only agent and task", () => {
    const env = setup({ sessionsEnabled: false });
    const schema = JSON.parse(JSON.stringify(env.extension.getTool().parameters)) as {
      properties: Record<string, unknown>;
      required: string[];
    };
    expect(Object.keys(schema.properties)).toEqual(["agent", "task"]);
    expect(schema.required).toEqual(["agent", "task"]);
    expect(env.extension.getTool("subagent_session")).toBeUndefined();
  });

  test("task cleanup failure remains an explicit live error without losing the handoff", async () => {
    const env = setup({ ids: ["task-runtime", "task-operation"] });
    const running = env.invokeLive({ agent: "scout", task: "Inspect once" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    env.fake.controllers[0].close = async () => { throw new Error("cleanup unavailable"); };
    env.fake.controllers[0].settle(0, "completed", "Useful handoff.");
    const result = await running;

    expect(result).toMatchObject({
      isError: true,
      details: { mode: "task", status: "crashed", turnStatus: "completed", summary: "Useful handoff.", cleanupError: "cleanup unavailable" },
    });
    expect(result.details).not.toHaveProperty("ref");
  });

  test("foreground run leaves an idle reusable session", async () => {
    const env = setup({ ids: ["session", "turn"] });
    const running = env.invoke({ action: "open", agent: "scout", task: "Inspect lifecycle" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    env.fake.controllers[0].settle(0, "completed", "Plain-text handoff.");
    const result = await running;

    expect(result.details).toMatchObject({ ref: "#1", turn: 1, agent: "scout", status: "idle", turnStatus: "completed", summary: "Plain-text handoff." });
    expect(env.fake.controllers[0].closeCalls).toBe(0);
    expect(env.fake.controllers[0].starts[0].options.workOrder.task).toBe("Inspect lifecycle");
    expectPublic(result);
  });

  test("followup reuses the same controller and conversation", async () => {
    const env = setup({ ids: ["session", "first", "second"] });
    const first = env.invoke({ action: "open", agent: "scout", task: "Inspect" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    env.fake.controllers[0].settle(0, "completed", "Found the seam.");
    await first;

    const second = env.invoke({ action: "send", ref: "#1", task: "Check the tests too" });
    await vi.waitFor(() => expect(env.fake.controllers[0].starts).toHaveLength(2));
    expect(env.fake.controllers).toHaveLength(1);
    expect(env.fake.controllers[0].starts[1].options.workOrder.task).toBe("Check the tests too");
    env.fake.controllers[0].settle(1, "completed", "Tests checked.");
    await expect(second).resolves.toMatchObject({ details: { ref: "#1", turn: 2, status: "idle", summary: "Tests checked." } });
  });

  test("background turn notifies and remains reusable", async () => {
    const env = setup({ ids: ["session", "first", "second"] });
    expect((await env.invoke({ action: "open", agent: "scout", task: "Inspect", background: true })).details)
      .toMatchObject({ ref: "#1", status: "running" });
    env.fake.controllers[0].settle(0, "completed", "Done.");
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(1));
    expect((await env.invoke({ action: "get", ref: "#1" })).details)
      .toMatchObject({ ref: "#1", status: "idle", turnStatus: "completed", summary: "Done." });
    expect(env.fake.controllers[0].closeCalls).toBe(0);
  });

  test("cancel stops only the active turn and permits a followup", async () => {
    const env = setup({ ids: ["session", "first", "second"] });
    await env.invoke({ action: "open", agent: "scout", task: "Long task", background: true });
    expect((await env.invoke({ action: "cancel", ref: "#1" })).details)
      .toMatchObject({ ref: "#1", status: "idle", turnStatus: "interrupted", cancelled: true });
    expect(env.fake.controllers[0].closeCalls).toBe(0);

    const followup = env.invoke({ action: "send", ref: "#1", task: "Try a smaller scope" });
    await vi.waitFor(() => expect(env.fake.controllers[0].starts).toHaveLength(2));
    env.fake.controllers[0].settle(1);
    await followup;
  });

  test("close releases a session and is idempotent", async () => {
    const env = setup({ ids: ["session", "turn"] });
    const run = env.invoke({ action: "open", agent: "scout", task: "Inspect" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    env.fake.controllers[0].settle();
    await run;
    expect((await env.invoke({ action: "close", ref: "#1" })).details).toMatchObject({ ref: "#1", status: "closed", closed: true });
    expect((await env.invoke({ action: "close", ref: "#1" })).details).toMatchObject({ status: "closed", closed: true });
    expect(env.fake.controllers[0].closeCalls).toBe(1);
    expect((await env.invoke({ action: "send", ref: "#1", task: "Too late" })).isError).toBe(true);
  });

  test("get without a ref lists compact session summaries", async () => {
    const env = setup({ ids: ["session", "turn"] });
    const run = env.invoke({ action: "open", agent: "scout", task: "A deliberately verbose task" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    env.fake.controllers[0].settle(0, "completed", "A deliberately verbose result");
    await run;

    const result = await env.invoke({ action: "get" });
    expect(result.details).toEqual({ sessions: [{ ref: "#1", status: "idle", agent: "scout" }] });
    expect(result.content[0]?.text).not.toContain("deliberately verbose");
  });

  test("idle sessions release execution capacity", async () => {
    const env = setup({ maxConcurrentRuns: 1, ids: ["one", "one-turn", "two", "two-turn"] });
    const first = env.invoke({ action: "open", agent: "scout", task: "One" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    env.fake.controllers[0].settle();
    await first;
    expect((await env.invoke({ action: "open", agent: "scout", task: "Two", background: true })).isError).not.toBe(true);
    expect(env.fake.controllers).toHaveLength(2);
    await env.extension.shutdown();
  });

  test("get wait is observational and exposes bounded progress", async () => {
    const env = setup({ ids: ["session", "turn"] });
    await env.extension.getTool("subagent_session").execute("call", { action: "open", agent: "scout", task: "Inspect", background: true }, undefined, undefined, context(env.root));
    env.fake.controllers[0].starts[0].options.onProgress?.({
      summary: "reading runtime",
      tools: {
        earlierCount: 0,
        history: [],
        active: [{ id: "active-read", summary: "read runtime.ts" }],
      },
      timeline: [{ kind: "tool", id: "read", summary: "read runtime.ts", status: "completed" }],
    });
    expect((await env.invoke({ action: "get", ref: "#1", waitMs: 1 })).details)
      .toMatchObject({
        status: "running", timedOut: true, activity: "reading runtime",
        toolProgress: { active: [{ id: "active-read", summary: "read runtime.ts" }] },
      });
    expect(env.fake.controllers[0].interruptCalls).toHaveLength(0);
    await env.extension.shutdown();
  });

  test("extracts structured handoff sections without transcript identities", async () => {
    const env = setup({ ids: ["session", "turn"] });
    const run = env.invoke({ action: "open", agent: "scout", task: "Report" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    env.fake.controllers[0].settle(0, "completed", "## Summary\nDone\n## Changes\nEdited a.ts\n## Validation\ntests pass");
    const result = await run;
    expect(result.details).toMatchObject({ ref: "#1", status: "idle", summary: "Done", changes: "Edited a.ts", validation: "tests pass" });
    expectPublic(result);
  });

  test("omits renderer timelines and internal tool IDs from model-facing results", async () => {
    const env = setup({ ids: ["session", "turn"] });
    const run = env.extension.getTool().execute(
      "call", { agent: "scout", task: "Inspect auth" } as never,
      undefined, undefined, context(env.root),
    );
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    env.fake.controllers[0].starts[0].options.onProgress?.({
      summary: "read auth.ts",
      timeline: [
        { kind: "thinking", text: "private chain of thought" },
        { kind: "tool", id: "secret-tool-call", summary: "read auth.ts", status: "completed" },
      ],
    });
    env.fake.controllers[0].settle(0, "completed", "Done");
    const result = await run;

    expect(result.details).toMatchObject({ timeline: expect.any(Array) });
    const modelText = result.content[0]?.text ?? "";
    expect(JSON.parse(modelText)).toMatchObject({ agent: "scout", status: "completed", summary: "Done" });
    expect(modelText).not.toContain('"mode"');
    expect(modelText).not.toContain('"turnStatus"');
    expect(modelText).not.toContain("timeline");
    expect(modelText).not.toContain("private chain of thought");
    expect(modelText).not.toContain("secret-tool-call");
    expect(modelText).not.toContain('"turn"');
  });
});
