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

describe("subagent shutdown cleanup", () => {
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

  test("one-shot cleanup failure is reported instead of ordinary completion", async () => {
    const env = setup();
    const run = env.invoke({ action: "run", agent: "scout", task: "Once" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    vi.spyOn(env.fake.controllers[0], "close").mockRejectedValueOnce(new Error("Cleanup failed"));
    env.fake.controllers[0].settle();
    expect(await run).toMatchObject({ isError: true, details: { status: "crashed", error: "Cleanup failed" } });
  });

});
