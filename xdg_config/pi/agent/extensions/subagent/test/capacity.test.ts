import { describe, expect, test } from "vitest";
import { setup } from "./harness.ts";

describe("subagent capacity", () => {
  test("three active jobs occupy capacity and cancellation releases a slot", async () => {
    const env = setup();
    const jobs = await Promise.all([1, 2, 3].map((n) => env.invoke({ action: "run", agent: "scout", objective: `Job ${n}`, background: true })));
    expect((await env.invoke({ action: "run", agent: "scout", objective: "Fourth", background: true })).isError).toBe(true);
    await env.invoke({ action: "cancel", jobId: (jobs[0].details as { jobId: string }).jobId });
    expect((await env.invoke({ action: "run", agent: "scout", objective: "Replacement", background: true })).isError).not.toBe(true);
    await env.extension.shutdown();
  });
});
