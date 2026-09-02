import { describe, expect, test, vi } from "vitest";

import { setup } from "./harness.ts";

const agents = ["scout", "researcher", "oracle", "worker", "tester", "reviewer"];
const graph = [
  { id: "local", agent: "scout", objective: "Inspect local code" },
  { id: "research", agent: "researcher", objective: "Research external behavior" },
  { id: "design", agent: "oracle", objective: "Synthesize a design", dependsOn: ["local", "research"] },
  { id: "implement", agent: "worker", objective: "Implement the design", dependsOn: ["design"] },
  { id: "test", agent: "tester", objective: "Run tests", dependsOn: ["implement"] },
  { id: "review", agent: "reviewer", objective: "Review the diff", dependsOn: ["implement"] },
];

describe("subagent workflow integration", () => {
  test("runs a generic DAG through RuntimeHub and passes bounded predecessor handoffs", async () => {
    const env = setup({ agentNames: agents });
    const execution = env.invoke({ action: "workflow", objective: "Ship the feature", nodes: graph });

    await vi.waitFor(() => expect(env.fake.controllers).toHaveLength(2));
    expect(env.fake.controllers.map((controller) => controller.starts[0].options.agent.name).sort()).toEqual(["researcher", "scout"]);
    env.fake.controllers[0].settle(0, "completed", "## Summary\nlocal evidence");
    env.fake.controllers[1].settle(0, "completed", "## Summary\nexternal evidence");

    await vi.waitFor(() => expect(env.fake.controllers).toHaveLength(3));
    const oracle = env.fake.controllers[2].starts[0].options;
    expect(oracle.agent.name).toBe("oracle");
    expect(oracle.workOrder.context).toContain("Direct predecessor handoffs");
    expect(oracle.workOrder.context).toContain("local evidence");
    expect(oracle.workOrder.context).toContain("external evidence");
    oracle.onProgress?.("designing");
    env.fake.controllers[2].settle(0, "completed", "## Summary\nchosen design");

    await vi.waitFor(() => expect(env.fake.controllers).toHaveLength(4));
    expect(env.fake.controllers[3].starts[0].options.agent.name).toBe("worker");
    expect(env.fake.controllers[3].starts[0].options.workOrder.context).toContain("chosen design");
    env.fake.controllers[3].settle(0, "completed", "## Summary\nimplementation done");

    await vi.waitFor(() => expect(env.fake.controllers).toHaveLength(6));
    expect(env.fake.controllers.slice(4).map((controller) => controller.starts[0].options.agent.name).sort()).toEqual(["reviewer", "tester"]);
    env.fake.controllers[4].settle();
    env.fake.controllers[5].settle();
    const result = await execution;

    expect(result.details).toMatchObject({
      ref: "W#1",
      status: "completed",
      nodes: graph.map((node) => expect.objectContaining({ id: node.id, agent: node.agent, status: "completed" })),
    });
    expect(env.extension.messages).toHaveLength(0);
  });

  test("background workflow has get/cancel and only one workflow-level completion wake", async () => {
    const env = setup({ agentNames: ["scout", "worker"] });
    const started = await env.invoke({
      action: "workflow",
      objective: "Background flow",
      background: true,
      nodes: [
        { id: "inspect", agent: "scout", objective: "Inspect" },
        { id: "change", agent: "worker", objective: "Change", dependsOn: ["inspect"] },
      ],
    });
    expect(started.details).toMatchObject({ ref: "W#1", status: "running", nodes: 2 });
    expect((await env.invoke({ action: "get", jobId: "W#1" })).details).toMatchObject({ status: "running" });

    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    env.fake.controllers[0].settle();
    await vi.waitFor(() => expect(env.fake.controllers).toHaveLength(2));
    env.fake.controllers[1].settle();
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(1));
    expect(env.extension.messages[0].message).toMatchObject({ details: { ref: "W#1", agent: "workflow", status: "completed" } });
    expect((await env.invoke({ action: "get", jobId: "W#1" })).details).toMatchObject({ status: "completed" });
    expect(env.extension.messages).toHaveLength(1);

    const second = await env.invoke({
      action: "workflow", objective: "Cancel flow", background: true,
      nodes: [{ id: "work", agent: "worker", objective: "Work" }],
    });
    await vi.waitFor(() => expect(env.fake.controllers[2]?.starts).toHaveLength(1));
    const cancelled = await env.invoke({ action: "cancel", jobId: (second.details as { ref: string }).ref });
    expect(cancelled.details).toMatchObject({ ref: "W#2", status: "interrupted", cancelled: true });
    expect(env.fake.controllers[2].interruptCalls).toHaveLength(1);
  });

  test("skips descendants after failure and can run an explicit failure consumer", async () => {
    const env = setup({ agentNames: ["scout", "worker", "reviewer"] });
    const execution = env.invoke({
      action: "workflow", objective: "Recover",
      nodes: [
        { id: "inspect", agent: "scout", objective: "Inspect" },
        { id: "change", agent: "worker", objective: "Change", dependsOn: ["inspect"] },
        { id: "diagnose", agent: "reviewer", objective: "Diagnose", dependsOn: ["inspect"], runOnDependencyFailure: true },
      ],
    });
    await vi.waitFor(() => expect(env.fake.controllers).toHaveLength(1));
    env.fake.controllers[0].settle(0, "failed", "inspection failed");
    await vi.waitFor(() => expect(env.fake.controllers).toHaveLength(2));
    expect(env.fake.controllers[1].starts[0].options.agent.name).toBe("reviewer");
    env.fake.controllers[1].settle();
    const result = await execution;
    expect(result.isError).toBe(true);
    expect(result.details).toMatchObject({
      status: "failed",
      nodes: [
        { id: "inspect", status: "failed" },
        { id: "change", status: "skipped" },
        { id: "diagnose", status: "completed" },
      ],
    });
  });

  test("rejects malformed graphs and unknown agents before reserving capacity", async () => {
    const env = setup();
    const result = await env.invoke({
      action: "workflow", objective: "Bad",
      nodes: [
        { id: "a", agent: "missing", objective: "A", dependsOn: ["b"] },
        { id: "b", agent: "scout", objective: "B", dependsOn: ["a"] },
      ],
    });
    expect(result).toMatchObject({ isError: true, details: { error: "Invalid subagent workflow", errors: expect.arrayContaining([
      expect.stringContaining("dependency cycle"),
      "unknown workflow agents: missing",
    ] as unknown[]) } });
    expect(env.fake.factory).not.toHaveBeenCalled();
  });

  test("waits for shared RuntimeHub capacity instead of failing the graph", async () => {
    const env = setup();
    await Promise.all(["A", "B", "C"].map((objective) => env.invoke({ action: "run", agent: "scout", objective, background: true })));
    expect(env.fake.controllers).toHaveLength(3);

    const started = await env.invoke({
      action: "workflow", objective: "Wait for capacity", background: true,
      nodes: [{ id: "inspect", agent: "scout", objective: "Inspect after a slot opens" }],
    });
    expect(started.details).toMatchObject({ ref: "W#1", status: "running" });
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(env.fake.controllers).toHaveLength(3);

    env.fake.controllers[0].settle();
    await vi.waitFor(() => expect(env.fake.controllers).toHaveLength(4));
    env.fake.controllers[3].settle();
    await vi.waitFor(async () => expect((await env.invoke({ action: "get", jobId: "W#1" })).details).toMatchObject({ status: "completed" }));
    await env.extension.shutdown();
  });
});
