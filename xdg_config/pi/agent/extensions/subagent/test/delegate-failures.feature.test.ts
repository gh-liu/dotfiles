import { describe, expect, test, vi } from "vitest";
import { setup } from "./harness.ts";

describe("Feature: failures remain actionable", () => {
  test("Scenario: child construction failure is explicit and releases capacity", async () => {
    const failed = setup({ capacity: 1, createFailure: new Error("factory unavailable") });
    const result = await failed.execute({ task: "inspect" });
    expect(result).toMatchObject({ isError: true });
    expect(result.content[0].text).toContain("factory unavailable");
    expect(failed.children).toHaveLength(0);

    const healthy = setup({ capacity: 1 });
    const delegated = healthy.execute({ task: "next" });
    await vi.waitFor(() => expect(healthy.children).toHaveLength(1));
    healthy.children[0].complete("ok");
    expect(JSON.parse((await delegated).content[0].text).handoff).toBe("ok");
  });

  test.each([
    ["provider failed", "upstream unavailable"],
    ["protocol malformed", "Child did not produce a complete final response."],
  ])("Scenario Outline: %s is an explicit child failure", async (_case, message) => {
    const env = setup();
    const delegated = env.execute({ task: "inspect" });
    await vi.waitFor(() => expect(env.children).toHaveLength(1));
    env.children[0].fail(message);

    const result = await delegated;
    expect(result.isError).toBe(true);
    expect(JSON.parse(result.content[0].text)).toEqual({ status: "failed", error: message });
    expect(env.children[0].disposeCalls).toBe(1);
  });
});
