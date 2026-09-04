import { afterEach, describe, expect, test, vi } from "vitest";

import { setup } from "./harness.ts";

afterEach(() => {
  vi.useRealTimers();
});

describe("close bounded deadline and failure race", () => {
  test("close is bounded by a single 5s deadline and releases the slot", async () => {
    vi.useFakeTimers();
    try {
      const env = setup({ ids: ["job", "private", "replacement", "replacement-op"], maxConcurrentRuns: 1 });
      await env.invoke({ action: "run", agent: "scout", task: "Hang", background: true });
      // Hang the owned controller close past any reasonable bound.
      env.fake.controllers[0].close = () => new Promise<void>(() => {});
      const closing = env.invoke({ action: "close", ref: "#1" });
      await vi.advanceTimersByTimeAsync(5_000);
      const result = await closing;
      expect(result).toMatchObject({ isError: true });
      expect(result.details).toMatchObject({ closed: false });
      expect(String((result.details as { error?: unknown }).error)).toMatch(/5s/);
      // Interrupt settled the active turn before disposal hung, so its slot is
      // safe to reuse even though close itself reached the deadline.
      expect((await env.invoke({ action: "run", agent: "scout", task: "Replacement", background: true })).isError).not.toBe(true);
      await env.extension.shutdown();
    } finally {
      vi.useRealTimers();
    }
  });

  test("a timed-out active turn keeps its slot quarantined until authoritative settlement", async () => {
    vi.useFakeTimers();
    try {
      const env = setup({
        ids: ["job", "private", "replacement", "replacement-op"],
        maxConcurrentRuns: 1,
      });
      await env.invoke({ action: "run", agent: "scout", task: "Still executing", background: true });
      env.fake.controllers[0].interrupt = () => new Promise<boolean>(() => {});
      env.fake.controllers[0].close = () => new Promise<void>(() => {});

      const closing = env.invoke({ action: "close", ref: "#1" });
      await vi.advanceTimersByTimeAsync(5_000);
      expect(await closing).toMatchObject({ isError: true });

      const whileActive = await env.invoke({ action: "run", agent: "scout", task: "Must wait", background: true });
      expect(whileActive).toMatchObject({ isError: true });
      expect(whileActive.details).toMatchObject({ occupiedSlots: 1, availableSlots: 0 });

      env.fake.controllers[0].settle();
      await vi.advanceTimersByTimeAsync(0);
      const afterSettlement = await env.invoke({ action: "run", agent: "scout", task: "Now safe", background: true });
      expect(afterSettlement).not.toMatchObject({ isError: true });
      await env.extension.shutdown();
    } finally {
      vi.useRealTimers();
    }
  });

  test("a late controller failure during closing cannot flip a closed session to crashed", async () => {
    const env = setup({ ids: ["job", "private"] });
    await env.invoke({ action: "run", agent: "scout", task: "Race", background: true });
    const closing = env.invoke({ action: "close", ref: "#1" });
    // Failure lands while the close path owns the outcome.
    env.fake.controllers[0].fail(new Error("late transport failure"));
    const result = await closing;
    expect(result.details).toMatchObject({ closed: true });
    expect((await env.invoke({ action: "get", ref: "#1" })).details).toMatchObject({
      ref: "#1",
      status: "closed",
    });
    await env.extension.shutdown();
  });
});
