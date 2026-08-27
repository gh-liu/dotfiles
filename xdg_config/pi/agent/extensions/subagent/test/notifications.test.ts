import { describe, expect, test, vi } from "vitest";
import { setup } from "./harness.ts";

describe("subagent notifications", () => {
  test("batches successes and notification failure does not alter settled state", async () => {
    const env = setup({ ids: ["a", "pa", "b", "pb"] });
    await env.invoke({ action: "run", agent: "scout", objective: "A", background: true });
    await env.invoke({ action: "run", agent: "scout", objective: "B", background: true });
    env.fake.controllers[0].settle();
    env.fake.controllers[1].settle();
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(1));
    expect(env.extension.messages[0].message.details).toMatchObject({ batch: expect.any(Array) });
    expect(env.extension.messages[0].message.details).toMatchObject({ batch: [
      { jobId: "a", ref: "#1" },
      { jobId: "b", ref: "#2" },
    ] });
    expect(env.extension.messages[0].message.content).toContain('#1 scout · completed');
    expect(env.extension.messages[0].message.content).toContain('Use get("#1")');

    const failedDelivery = setup({ ids: ["c", "pc"] });
    vi.spyOn(failedDelivery.extension.pi, "sendMessage").mockImplementation(() => { throw new Error("unavailable"); });
    await failedDelivery.invoke({ action: "run", agent: "scout", objective: "C", background: true });
    failedDelivery.fake.controllers[0].settle();
    await vi.waitFor(async () => expect((await failedDelivery.invoke({ action: "get", jobId: "c" })).details).toMatchObject({ status: "completed" }));
  });
});
