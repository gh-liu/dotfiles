import { describe, expect, test, vi } from "vitest";
import { realpathSync } from "node:fs";
import { setup } from "./harness.ts";

describe("Feature: run one bounded task", () => {
  test("Scenario: a child completes successfully", async () => {
    const env = setup();

    const delegated = env.execute({ task: "Find the owner of token validation" });
    await vi.waitFor(() => expect(env.children).toHaveLength(1));
    expect(env.children[0].request).toMatchObject({
      task: "Find the owner of token validation",
      cwd: realpathSync.native(env.context.cwd),
      model: { provider: "parent-provider", id: "parent-model" },
      thinking: "medium",
    });
    env.children[0].complete("Token validation belongs to AuthService.");

    const result = await delegated;
    expect(JSON.parse(result.content[0].text)).toEqual({
      status: "completed",
      handoff: "Token validation belongs to AuthService.",
    });
    expect(env.children[0].disposeCalls).toBe(1);
  });

  test("Scenario: two independent calls use native parallelism", async () => {
    const env = setup({ capacity: 2 });

    const alpha = env.execute({ task: "alpha" });
    const beta = env.execute({ task: "beta" });
    await vi.waitFor(() => expect(env.children).toHaveLength(2));
    env.children[1].complete("result B");
    env.children[0].complete("result A");

    expect(JSON.parse((await alpha).content[0].text).handoff).toBe("result A");
    expect(JSON.parse((await beta).content[0].text).handoff).toBe("result B");
    expect(env.children.map((child) => child.disposeCalls)).toEqual([1, 1]);
  });

  test("Scenario: a sequential call gets a fresh context", async () => {
    const env = setup({ capacity: 1 });
    const first = env.execute({ task: "CHILD_ONE_A19C" });
    await vi.waitFor(() => expect(env.children).toHaveLength(1));
    env.children[0].complete("first");
    await first;

    const second = env.execute({ task: "Which markers can you see?" });
    await vi.waitFor(() => expect(env.children).toHaveLength(2));
    env.children[1].complete("none");
    await second;

    expect(env.children[1].request.task).not.toContain("CHILD_ONE_A19C");
    expect(env.children[0]).not.toBe(env.children[1]);
  });
});
