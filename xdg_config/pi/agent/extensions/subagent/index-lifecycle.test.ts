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
} from "./index-test-utils.ts";

describe("subagent lifecycle", () => {
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
    expect(results[0]).toHaveProperty("runId");
    const modelResults = (JSON.parse((joined.content[0] as { text: string }).text) as {
      results: Array<Record<string, unknown>>;
    }).results;
    expect(modelResults).toHaveLength(2);
    expect(modelResults[0]).not.toHaveProperty("runId");
    expect(modelResults[0]).not.toHaveProperty("operationId");
    expect(modelResults[0]).not.toHaveProperty("processInstanceId");

    // The last settle also flushed one aggregated completion card.
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(1));
    expect(env.extension.messages[0].message.content).toContain("2 background subagents settled");
  });

  test("two follow-ups reuse one controller, process, runtime, and transcript session", async () => {
    const env = setup();
    writeFileSync(join(env.root, "AGENTS.md"), "Initial project guidance");
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
    const [initialGuidance, firstGuidance, secondGuidance] = env.fake.controllers[0].starts
      .map((call) => call.options.workOrder.projectGuidance);
    expect(initialGuidance).toEqual([
      `Guidance from ${join(realpathSync(env.root), "AGENTS.md")}:\nInitial project guidance`,
    ]);
    expect(firstGuidance).toEqual([
      "Project guidance is unchanged; continue applying the guidance from the initial work order.",
    ]);
    expect(secondGuidance).toEqual(firstGuidance);
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
