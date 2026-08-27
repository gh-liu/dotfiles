import { describe, expect, test, vi } from "vitest";

import { context, deferred, FakeController, harness, registerSubagentExtension, temporaryDirectory, writeAgent } from "./harness.ts";
import type { SubagentController } from "../protocol.ts";

describe("subagent shutdown cleanup", () => {
  test("shutdown of a permanently pending factory is bounded", async () => {
    const root = temporaryDirectory("pi-subagent-project-");
    const agents = temporaryDirectory("pi-subagent-agents-");
    writeAgent(agents);
    const extension = harness();
    registerSubagentExtension(extension.pi, {
      agentDirectory: agents,
      controllerFactory: () => new Promise(() => {}),
      controllerCreationTimeoutMs: 20,
      idFactory: (() => { const ids = ["job", "private"]; return () => ids.shift()!; })(),
    });
    const run = extension.getTool().execute("call", { action: "run", agent: "scout", objective: "Wait", deadlineMs: 30_000 }, undefined, undefined, context(root));
    await expect(extension.shutdown()).resolves.toBeUndefined();
    await expect(run).resolves.toMatchObject({ isError: true });
  });

  test("a controller resolving after creation timeout is closed exactly once", async () => {
    const root = temporaryDirectory("pi-subagent-project-");
    const agents = temporaryDirectory("pi-subagent-agents-");
    writeAgent(agents);
    const extension = harness();
    const ready = deferred<SubagentController>();
    const controller = new FakeController("late");
    registerSubagentExtension(extension.pi, {
      agentDirectory: agents,
      controllerFactory: () => ready.promise,
      controllerCreationTimeoutMs: 10,
      idFactory: (() => { const ids = ["job", "private"]; return () => ids.shift()!; })(),
    });
    const run = extension.getTool().execute("call", { action: "run", agent: "scout", objective: "Wait", deadlineMs: 30_000 }, undefined, undefined, context(root));
    await expect(run).resolves.toMatchObject({ isError: true });
    ready.resolve(controller);
    await vi.waitFor(() => expect(controller.closeCalls).toBe(1));
  });

  test("shutdown suppresses a queued background wake", async () => {
    const { setup } = await import("./harness.ts");
    const env = setup({ ids: ["job", "private"] });
    await env.invoke({ action: "run", agent: "scout", objective: "Finish", background: true });
    env.fake.controllers[0].settle();
    await env.extension.shutdown();
    await new Promise((resolve) => setTimeout(resolve, 5));
    expect(env.extension.messages).toEqual([]);
  });
});
