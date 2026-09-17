import { describe, expect, test, vi } from "vitest";
import { deferred, setup } from "./harness.ts";

describe("Feature: capacity is a safety invariant", () => {
  test("Scenario: capacity is reserved while child construction is pending", async () => {
    const construction = deferred<void>();
    const env = setup({ capacity: 1, beforeCreate: construction.promise });
    const first = env.execute({ task: "alpha" });
    await vi.waitFor(() => expect(env.createChild).toHaveBeenCalledOnce());

    const second = await env.execute({ task: "beta" });
    expect(second).toMatchObject({ isError: true });
    expect(env.createChild).toHaveBeenCalledOnce();

    construction.resolve();
    await vi.waitFor(() => expect(env.children).toHaveLength(1));
    env.children[0].complete("A");
    await first;
  });

  test("Scenario: capacity exhaustion fails fast", async () => {
    const env = setup({ capacity: 1 });
    const first = env.execute({ task: "alpha" });
    await vi.waitFor(() => expect(env.children).toHaveLength(1));

    const second = await env.execute({ task: "beta" });
    expect(second).toMatchObject({ isError: true });
    expect(second.content[0].text).toContain("capacity");
    expect(env.children).toHaveLength(1);

    env.children[0].complete("A");
    await first;
  });

  test("Scenario: settlement releases capacity only after disposal", async () => {
    const env = setup({ capacity: 1 });
    const disposal = deferred<void>();
    const first = env.execute({ task: "alpha" });
    await vi.waitFor(() => expect(env.children).toHaveLength(1));
    env.children[0].dispose = vi.fn(() => disposal.promise);
    env.children[0].complete("A");

    const blocked = await env.execute({ task: "too early" });
    expect(blocked.isError).toBe(true);
    expect(env.children).toHaveLength(1);
    disposal.resolve();
    await first;

    const next = env.execute({ task: "after disposal" });
    await vi.waitFor(() => expect(env.children).toHaveLength(2));
    env.children[1].complete("B");
    expect(JSON.parse((await next).content[0].text).handoff).toBe("B");
  });

  test("Scenario: cleanup failure quarantines the capacity slot", async () => {
    const env = setup({ capacity: 1 });
    const first = env.execute({ task: "useful work" });
    await vi.waitFor(() => expect(env.children).toHaveLength(1));
    env.children[0].disposeFailure = new Error("dispose uncertain");
    env.children[0].complete("USEFUL_HANDOFF_19A7");

    const completed = await first;
    expect(JSON.parse(completed.content[0].text)).toMatchObject({
      status: "completed",
      handoff: "USEFUL_HANDOFF_19A7",
      warning: expect.stringContaining("dispose uncertain"),
    });
    expect((await env.execute({ task: "must not overbook" })).isError).toBe(true);
    expect(env.children).toHaveLength(1);
  });
});
