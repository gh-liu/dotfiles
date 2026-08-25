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

describe("subagent steering interrupt", () => {
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

});
