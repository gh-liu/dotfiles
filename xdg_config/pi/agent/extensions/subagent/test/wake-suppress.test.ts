import { afterEach, describe, expect, test, vi } from "vitest";

import { context, harness, registerSubagentExtension, temporaryDirectory, writeAgent } from "./harness.ts";

afterEach(() => {
  vi.useRealTimers();
});

function busyContext(root: string) {
  return { ...context(root), isIdle: () => false } as never;
}

function idleContext(root: string) {
  return { ...context(root), isIdle: () => true } as never;
}

describe("wake busy/idle routing and suppression", () => {
  test("idle parents wake immediately without deliverAs; busy parents queue as followUp", async () => {
    const { setup } = await import("./harness.ts");

    const idleEnv = setup({ ids: ["idle-job", "idle-op"] });
    await idleEnv.extension.getTool().execute(
      "call", { action: "run", agent: "scout", task: "Idle work", background: true },
      undefined, undefined, idleContext(idleEnv.root),
    );
    idleEnv.fake.controllers[0].settle();
    await vi.waitFor(() => expect(idleEnv.extension.messages).toHaveLength(1));
    expect(idleEnv.extension.messages[0].options).toEqual({ triggerTurn: true });
    await idleEnv.extension.shutdown();

    const busyEnv = setup({ ids: ["busy-job", "busy-op"] });
    await busyEnv.extension.getTool().execute(
      "call", { action: "run", agent: "scout", task: "Busy work", background: true },
      undefined, undefined, busyContext(busyEnv.root),
    );
    busyEnv.fake.controllers[0].settle();
    await vi.waitFor(() => expect(busyEnv.extension.messages).toHaveLength(1));
    // Busy delivery never steers active streaming; it queues as followUp.
    expect(busyEnv.extension.messages[0].options).toEqual({ triggerTurn: true, deliverAs: "followUp" });
    await busyEnv.extension.shutdown();
  });

  test("close suppresses the queued wake but the audit entry is still recorded", async () => {
    const { setup } = await import("./harness.ts");
    const env = setup({ ids: ["job", "private"] });
    const audits: unknown[] = [];
    vi.spyOn(env.extension.pi, "appendEntry").mockImplementation((_type: string, data?: unknown) => {
      audits.push(data);
    });
    await env.invoke({ action: "run", agent: "scout", task: "Finish", background: true });
    env.fake.controllers[0].settle();
    // Close before the batched macrotask flush so the wake must be suppressed.
    await env.invoke({ action: "close", ref: "#1" });
    await new Promise((resolve) => setTimeout(resolve, 10));
    expect(env.extension.messages).toEqual([]);
    // Audit is at-most-once and independent of wake suppression.
    expect(audits).toHaveLength(1);
    expect(audits[0]).toMatchObject({ jobId: "job", operationId: "private", turn: 1, ref: "#1", status: "completed" });
    await env.extension.shutdown();
  });

  test("repeated settlement notifies and audits at most once", async () => {
    const root = temporaryDirectory("pi-subagent-project-");
    const agents = temporaryDirectory("pi-subagent-agents-");
    writeAgent(agents);
    const extension = harness();
    const audits: unknown[] = [];
    (extension.pi.appendEntry as unknown as (...args: unknown[]) => void) = ((_type: unknown, data?: unknown) => {
      audits.push(data);
    }) as never;
    const { fakeFactory } = await import("./harness.ts");
    const fake = fakeFactory();
    const ids = ["job", "private"];
    registerSubagentExtension(extension.pi, {
      agentDirectory: agents,
      controllerFactory: fake.factory,
      idFactory: () => ids.shift()!,
    });
    const invoke = (params: Record<string, unknown>) => extension.getTool().execute(
      "call", params as never, undefined, undefined, context(root),
    );
    await invoke({ action: "run", agent: "scout", task: "Once", background: true });
    fake.controllers[0].settle();
    // A duplicate settle signal for the same operation must not double-notify.
    fake.controllers[0].settle();
    await vi.waitFor(() => expect(extension.messages).toHaveLength(1));
    await new Promise((resolve) => setTimeout(resolve, 10));
    expect(extension.messages).toHaveLength(1);
    expect(audits).toHaveLength(1);
    await extension.shutdown();
  });
});
