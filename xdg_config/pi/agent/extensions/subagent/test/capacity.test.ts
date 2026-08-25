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

describe("subagent capacity", () => {
  test("three warm runtimes consume capacity and close releases a slot", async () => {
    const env = setup();
    const starts = await Promise.all([1, 2, 3].map((n) => env.invoke({ action: "start", agent: "scout", task: `Warm ${n}` })));
    for (const [index, started] of starts.entries()) {
      env.fake.controllers[index].settle();
      const identity = started.details as { runId: string; operationId: string };
      await env.invoke({ action: "wait", id: identity.runId, operationId: identity.operationId });
    }
    const capacityError = await env.invoke({ action: "start", agent: "scout", task: "Fourth" });
    expect(capacityError).toMatchObject({
      isError: true,
      details: {
        error: expect.stringContaining("maxConcurrentRuns is 3"),
        maxConcurrentRuns: 3,
        occupiedSlots: 3,
        availableSlots: 0,
        runtimes: [
          { index: 1, agent: "scout", status: "idle" },
          { index: 2, agent: "scout", status: "idle" },
          { index: 3, agent: "scout", status: "idle" },
        ],
      },
    });
    await env.invoke({ action: "close", id: (starts[0].details as { runId: string }).runId });
    const fourth = await env.invoke({ action: "start", agent: "scout", task: "Fourth" });
    expect(fourth.isError).not.toBe(true);
    expect(env.fake.controllers).toHaveLength(4);
    await env.extension.shutdown();
  });

});
