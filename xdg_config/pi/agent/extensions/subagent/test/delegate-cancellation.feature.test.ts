import { describe, expect, test, vi } from "vitest";
import { setup } from "./harness.ts";

describe("Feature: cancellation and shutdown", () => {
  test("Scenario: parent cancellation interrupts only its child", async () => {
    const env = setup({ capacity: 2 });
    const alphaSignal = new AbortController();
    const betaSignal = new AbortController();
    const alpha = env.execute({ task: "alpha" }, alphaSignal.signal);
    const beta = env.execute({ task: "beta" }, betaSignal.signal);
    await vi.waitFor(() => expect(env.children).toHaveLength(2));

    alphaSignal.abort();
    env.children[1].complete("B completed");

    expect(JSON.parse((await alpha).content[0].text).status).toBe("interrupted");
    expect(JSON.parse((await beta).content[0].text).handoff).toBe("B completed");
    expect(env.children.map((child) => child.interruptCalls)).toEqual([1, 0]);
    expect(env.children.map((child) => child.disposeCalls)).toEqual([1, 1]);
  });

  test("Scenario Outline: completion and cancellation races settle once", async () => {
    for (const order of ["completion-first", "cancellation-first"] as const) {
      const env = setup();
      const signal = new AbortController();
      const delegated = env.execute({ task: order }, signal.signal);
      await vi.waitFor(() => expect(env.children).toHaveLength(1));

      if (order === "completion-first") {
        env.children[0].complete("completed first");
        signal.abort();
      } else {
        signal.abort();
        env.children[0].complete("too late");
      }

      const result = JSON.parse((await delegated).content[0].text);
      expect(result.status).toBe(order === "completion-first" ? "completed" : "interrupted");
      expect(env.children[0].disposeCalls).toBe(1);
    }
  });

  test("Scenario: shutdown rejects new work and drains owned work", async () => {
    const env = setup();
    const running = env.execute({ task: "running" });
    await vi.waitFor(() => expect(env.children).toHaveLength(1));

    await env.shutdown();
    expect((await env.execute({ task: "too late" })).isError).toBe(true);
    expect(JSON.parse((await running).content[0].text).status).toBe("interrupted");
    expect(env.children[0].interruptCalls).toBe(1);
    expect(env.children[0].disposeCalls).toBe(1);
  });
});
