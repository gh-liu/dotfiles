import { describe, expect, test, vi } from "vitest";

import { setup } from "./harness.ts";

describe("task-oriented subagent API", () => {
  const forbidden = new Set(["operationId", "processInstanceId", "revision", "index", "runId"]);
  const expectPublic = (value: unknown): void => {
    if (!value || typeof value !== "object") return;
    for (const [key, nested] of Object.entries(value)) {
      expect(forbidden.has(key), `forbidden public key ${key}`).toBe(false);
      expectPublic(nested);
    }
  };

  test("background jobs expose only job identity and automatically dispose", async () => {
    const env = setup({ ids: ["job", "internal-operation"] });
    const started = await env.invoke({
      action: "run",
      agent: "scout",
      objective: "Inspect lifecycle",
      scope: ["runtime.ts"],
      constraints: ["Do not edit"],
      acceptance: ["Report evidence"],
      background: true,
    });

    expect(started.details).toEqual({ jobId: "job", ref: "#1", status: "running", agent: "scout" });
    expect(JSON.stringify(started.details)).not.toContain("operation");
    expect(env.fake.controllers[0].starts[0].options.workOrder).toMatchObject({
      goal: "Inspect lifecycle",
      scope: [expect.any(String), "runtime.ts"],
      constraints: expect.arrayContaining(["Do not edit"]),
      validation: ["Report evidence"],
      knownDecisions: [],
      evidence: [],
    });

    env.fake.controllers[0].settle(0, "completed", "Plain-text fallback handoff.");
    await vi.waitFor(() => expect(env.fake.controllers[0].closeCalls).toBe(1));
    const fetched = await env.invoke({ action: "get", jobId: "job" });
    expect(fetched.details).toMatchObject({
      jobId: "job",
      ref: "#1",
      status: "completed",
      handoff: { summary: "Plain-text fallback handoff." },
    });
    expect(JSON.stringify(fetched.details)).not.toContain("operationId");
    expect(JSON.stringify(fetched.details)).not.toContain("processInstanceId");
    expectPublic(started);
    expectPublic(fetched);
  });

  test("lists both identities and resolves #N, N, and exact jobId", async () => {
    const env = setup({ ids: ["1", "private-one", "canonical", "private-two"] });
    await env.invoke({ action: "run", agent: "scout", objective: "One", background: true });
    await env.invoke({ action: "run", agent: "scout", objective: "Two", background: true });

    expect((await env.invoke({ action: "get" })).details).toMatchObject({ jobs: [
      { jobId: "canonical", ref: "#2" },
      { jobId: "1", ref: "#1" },
    ] });
    expect((await env.invoke({ action: "get", jobId: "#2" })).details).toMatchObject({ jobId: "canonical", ref: "#2" });
    expect((await env.invoke({ action: "get", jobId: "2" })).details).toMatchObject({ jobId: "canonical", ref: "#2" });
    // Exact canonical identity wins over interpreting the numeric string as an alias.
    expect((await env.invoke({ action: "get", jobId: "1" })).details).toMatchObject({ jobId: "1", ref: "#1" });
    expect((await env.invoke({ action: "cancel", jobId: "#2" })).details).toMatchObject({ jobId: "canonical", ref: "#2", cancelled: true });
    await env.extension.shutdown();
  });

  test("get waits and cancel is idempotent without a caller-supplied stale guard", async () => {
    const env = setup({ ids: ["job", "private-operation"] });
    await env.invoke({ action: "run", agent: "scout", objective: "Wait", background: true });

    const waiting = env.invoke({ action: "get", jobId: "job", waitMs: 1_000 });
    env.fake.controllers[0].settle();
    expect((await waiting).details).toMatchObject({ jobId: "job", status: "completed" });
    expect((await env.invoke({ action: "cancel", jobId: "job" })).details)
      .toMatchObject({ alreadyTerminal: true, cancelled: false });
    expect((await env.invoke({ action: "cancel", jobId: "missing" })).details)
      .toEqual({ jobId: "missing", cancelled: false, alreadyTerminal: true });
  });

  test("get marks only an expired running wait as timed out", async () => {
    const env = setup({ ids: ["job", "private"] });
    await env.invoke({ action: "run", agent: "scout", objective: "Wait", background: true });
    expect((await env.invoke({ action: "get", jobId: "job" })).details).not.toHaveProperty("timedOut");
    expect((await env.invoke({ action: "get", jobId: "job", waitMs: 1 })).details)
      .toMatchObject({ jobId: "job", status: "running", timedOut: true });
    await env.extension.shutdown();
  });

  test("public progress, completion and capacity payloads expose only jobId", async () => {
    const env = setup({ ids: ["a", "pa", "b", "pb", "c", "pc"] });
    const updates: unknown[] = [];
    await env.extension.getTool().execute("call", { action: "run", agent: "scout", objective: "A", deadlineMs: 60_000, background: true }, undefined, (update) => updates.push(update), (await import("./harness.ts")).context(env.root));
    env.fake.controllers[0].starts[0].options.onProgress?.({
      summary: "working",
      tools: { earlierCount: 0, history: [{ id: "t1", summary: "read a.ts", status: "completed" }], active: [] },
    });
    expect(updates.at(-1)).toMatchObject({
      content: [{ type: "text", text: "working" }],
      details: { toolProgress: { history: [{ summary: "read a.ts", status: "completed" }] } },
    });
    await env.invoke({ action: "run", agent: "scout", objective: "B", background: true });
    await env.invoke({ action: "run", agent: "scout", objective: "C", background: true });
    const capacity = await env.invoke({ action: "run", agent: "scout", objective: "D", background: true });
    expectPublic(updates);
    expectPublic(capacity);
    env.fake.controllers[0].settle();
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(1));
    expectPublic(env.extension.messages[0].message);
    await env.extension.shutdown();
  });

  test("cancel interrupt failure still closes and releases capacity", async () => {
    const env = setup();
    const jobs = await Promise.all([1, 2, 3].map((n) => env.invoke({ action: "run", agent: "scout", objective: `Job ${n}`, background: true })));
    vi.spyOn(env.fake.controllers[0], "interrupt").mockRejectedValueOnce(new Error("interrupt RPC failed"));
    const cancelled = await env.invoke({ action: "cancel", jobId: (jobs[0].details as { jobId: string }).jobId });
    expect(cancelled).toMatchObject({ isError: true, details: { status: "failed", cancelled: false, error: "interrupt RPC failed" } });
    expect(env.fake.controllers[0].closeCalls).toBe(1);
    expect((await env.invoke({ action: "run", agent: "scout", objective: "Replacement", background: true })).isError).not.toBe(true);
    await env.extension.shutdown();
  });

  test("extracts optional Markdown handoff sections and preserves plain text fallback", async () => {
    const structured = setup({ ids: ["structured", "private"] });
    const run = structured.invoke({ action: "run", agent: "scout", objective: "Report" });
    await vi.waitFor(() => expect(structured.fake.controllers[0]?.starts).toHaveLength(1));
    structured.fake.controllers[0].settle(0, "completed", "## Summary\nDone\n## Changes\nEdited a.ts\n## Evidence\ndiff\n## Validation\ntests pass\n## Risks\nNone");
    expect((await run).content[0].text).toContain('"changes":"Edited a.ts"');

    const plain = setup({ ids: ["plain", "private"] });
    const fallback = plain.invoke({ action: "run", agent: "scout", objective: "Report" });
    await vi.waitFor(() => expect(plain.fake.controllers[0]?.starts).toHaveLength(1));
    plain.fake.controllers[0].settle(0, "completed", "ordinary text");
    expect((await fallback).content[0].text).toContain('"summary":"ordinary text"');
  });
});
