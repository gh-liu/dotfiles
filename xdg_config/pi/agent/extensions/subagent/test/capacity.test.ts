import { describe, expect, test } from "vitest";
import { writeFileSync } from "node:fs";
import { join } from "node:path";
import { setup, temporaryDirectory } from "./harness.ts";

describe("subagent capacity", () => {
  test("honors maxConcurrentRuns from settings.json", async () => {
    const settingsPath = join(temporaryDirectory("settings-"), "settings.json");
    writeFileSync(settingsPath, JSON.stringify({ subagent: { maxConcurrentRuns: 2 } }));
    const env = setup({ settingsPath });
    const jobs = await Promise.all([1, 2].map((n) => env.invoke({ action: "run", agent: "scout", task: `Job ${n}`, background: true })));
    expect((await env.invoke({ action: "run", agent: "scout", task: "Third", background: true })).isError).toBe(true);
    expect(env.extension.getTool().description).toContain("At most 2 turns");
    await env.invoke({ action: "cancel", ref: (jobs[0].details as { ref: string }).ref });
    expect((await env.invoke({ action: "run", agent: "scout", task: "Replacement", background: true })).isError).not.toBe(true);
    await env.extension.shutdown();
  });

  test("three active jobs occupy capacity and cancellation releases a slot", async () => {
    const env = setup();
    const jobs = await Promise.all([1, 2, 3].map((n) => env.invoke({ action: "run", agent: "scout", task: `Job ${n}`, background: true })));
    expect((await env.invoke({ action: "run", agent: "scout", task: "Fourth", background: true })).isError).toBe(true);
    await env.invoke({ action: "cancel", ref: (jobs[0].details as { ref: string }).ref });
    expect((await env.invoke({ action: "run", agent: "scout", task: "Replacement", background: true })).isError).not.toBe(true);
    await env.extension.shutdown();
  });
});
